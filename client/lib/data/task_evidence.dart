import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'files.dart';
import 'own_video.dart';
import 'store.dart';
import 'task_discussion.dart';

class TaskEvidence extends TaskDiscussion {
  final LocalFiles files;
  TaskEvidence(
    super.store,
    super.team,
    super.task,
    this.files, {
    super.clientFactory,
  });
  @override
  String get cacheKey => 'evidence_${super.cacheKey}';
  @override
  String get endpoint =>
      super.endpoint.replaceFirst(RegExp(r'/comments$'), '/evidence');
  @override
  bool get canPost {
    final assignment = store
        .tasks(team)
        .where((t) => t['id'] == task)
        .firstOrNull;
    if (assignment == null || assignment['status'] == 'approved') return false;
    final role = store.setting('shared_role_$team');
    return ['owner', 'captain', 'coach'].contains(role) ||
        role == 'player' &&
            assignment['member_id'] != null &&
            assignment['member_id'] ==
                store.setting('shared_user_member_$team');
  }

  static Future<String> validate(Uint8List bytes) async {
    if (bytes.length > OwnVideo.limit) throw DomainError('limit');
    if (bytes.length >= 8 &&
        ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp') {
      OwnVideo.validate(bytes);
      return 'mp4';
    }
    final png =
        bytes.length > 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length > 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) throw DomainError('invalidImage');
    await LocalFiles.validateRadar(bytes);
    return png ? 'png' : 'jpg';
  }

  Future<void> saveFile(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.${Store.uuid.v4()}.partial');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(target.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<void> enqueueFile(String filename) async {
    assertActive();
    if (!canPost) throw DomainError('forbidden');
    if (pending().length >= 10) throw DomainError('limit');
    final source = File(filename);
    if (await source.length() > OwnVideo.limit) throw DomainError('limit');
    final bytes = await source.readAsBytes();
    final extension = await validate(bytes);
    final hash = sha256.convert(bytes).toString();
    final target = File('${files.root.path}/media/evidence/$hash.$extension');
    await saveFile(target, bytes);
    assertActive();
    if (!canPost) throw DomainError('forbidden');
    final rows = pending();
    if (rows.length >= 10) throw DomainError('limit');
    rows.add({
      'id': Store.uuid.v4(),
      'path': target.path,
      'media_id': hash,
      'mime': extension == 'mp4'
          ? 'video/mp4'
          : extension == 'png'
          ? 'image/png'
          : 'image/jpeg',
      'created': DateTime.now().millisecondsSinceEpoch / 1000,
    });
    store.setSetting(queueKey, jsonEncode(rows));
  }

  void discardPending(String id) {
    assertActive();
    store.setSetting(
      queueKey,
      jsonEncode(pending().where((r) => r['id'] != id).toList()),
    );
  }

  @override
  Future<void> flush() async {
    final rows = pending();
    if (rows.isEmpty) return;
    final path = endpoint, api = await client();
    for (final row in rows) {
      assertActive();
      final file = File(row['path'] as String);
      if (!await file.exists()) throw DomainError('fileMissing');
      if (await file.length() > OwnVideo.limit) throw DomainError('limit');
      final bytes = await file.readAsBytes();
      if (sha256.convert(bytes).toString() != row['media_id']) {
        throw DomainError('invalid_media');
      }
      await validate(bytes);
      assertActive();
      final response = await api.media(
        'PUT',
        '$path/media/${row['id']}',
        bytes: bytes,
      );
      assertActive();
      final saved = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response)) as Map,
      );
      if (saved['media_id'] != row['media_id'] ||
          saved['id'] != row['id'] ||
          saved['mime'] != row['mime'] ||
          saved['size'] != bytes.length ||
          saved['author_id'] != binding['user']) {
        throw DomainError('invalid_media');
      }
      remember([saved]);
      store.setSetting(
        queueKey,
        jsonEncode(pending().where((r) => r['id'] != row['id']).toList()),
      );
    }
  }

  Future<File> openFile(Map row) async {
    assertActive();
    final id = row['media_id'] as String;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
      throw DomainError('invalid_media');
    }
    final extension = switch (row['mime']) {
      'video/mp4' => 'mp4',
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      _ => throw DomainError('invalid_media'),
    };
    final target = File('${files.root.path}/media/evidence/$id.$extension');
    if (await target.exists() && await target.length() <= OwnVideo.limit) {
      final bytes = await target.readAsBytes();
      if (sha256.convert(bytes).toString() == id) {
        await validate(bytes);
        assertActive();
        return target;
      }
    }
    final path = endpoint, api = await client();
    final bytes = await api.media('GET', '$path/media/${row['id']}');
    assertActive();
    if (sha256.convert(bytes).toString() != id) {
      throw DomainError('invalid_media');
    }
    await validate(bytes);
    await saveFile(target, bytes);
    assertActive();
    return target;
  }
}
