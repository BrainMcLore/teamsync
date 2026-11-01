import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'account.dart';
import 'files.dart';
import 'store.dart';

/// Durable outbox + optimistic versions. No network operation runs in a SQLite
/// transaction. A lost acknowledgement reuses the exact operation and payload.
class TacticalSync {
  final Store store;
  final LocalFiles files;
  final AccountClient Function(String)? clientFactory;
  bool running = false;
  bool deferred = false;
  int conflicts = 0, uploaded = 0, downloaded = 0;
  TacticalSync(this.store, this.files, {this.clientFactory});
  late AccountClient api;
  late String team, local, key;
  late Map<String, dynamic> state, entries, outbox;
  bool writable = false;
  final Map<String, (int, int, String)> _hashCache = {};

  String hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  Map<String, dynamic> canonical(String kind, Map value) {
    if (kind == 'map') {
      return {
        'title': value['title'],
        'catalog_id': value['catalog_id'],
        'image_id': value['image_id'],
        'lower_image_id': value['lower_image_id'],
      };
    }
    return {
      'title': value['title'],
      'notes': value['notes'] ?? '',
      'map_id': value['map_id'],
      'side': value['side'],
      'level': value['level'] ?? 'default',
      'objects': [
        for (final raw in value['objects'] as List? ?? [])
          {
            'type': raw['type'],
            'x': (raw['x'] as num).toDouble(),
            'y': (raw['y'] as num).toDouble(),
            if (raw['type'] == 'arrow')
              ...'x2,y2'
                  .split(',')
                  .fold<Map<String, dynamic>>(
                    {},
                    (m, k) => m..[k] = (raw[k] as num).toDouble(),
                  ),
          },
      ],
    };
  }

  void persist() {
    state['entries'] = entries;
    state['outbox'] = outbox;
    store.setSetting(key, jsonEncode(state));
  }

  Map<String, dynamic> entry(String kind, String id, {String? remote}) {
    final value = entries.putIfAbsent(
      '$kind:$id',
      () => {
        'kind': kind,
        'local': id,
        'remote':
            remote ??
            Store.uuid.v5(
              '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
              '${api.base}/$team/$kind/$id',
            ),
        'version': 0,
        'hash': '',
      },
    );
    return value as Map<String, dynamic>;
  }

  Map<String, dynamic>? byRemote(String remote) => entries.values
      .cast<Map<String, dynamic>>()
      .where((r) => r['remote'] == remote)
      .firstOrNull;
  String get path => '/api/v1/teams/$team';

  Future<void> run(String localTeam, {required String conflictLabel}) async {
    if (running) return;
    final binding = store.setting('account_team_$localTeam');
    if (binding == null) return;
    running = true;
    deferred = false;
    conflicts = 0;
    uploaded = 0;
    downloaded = 0;
    try {
      final config = jsonDecode(binding) as Map;
      local = localTeam;
      team = config['team'] as String;
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(team)) {
        throw DomainError('invalid_link');
      }
      api =
          clientFactory?.call(config['server'] as String) ??
          AccountClient(config['server'] as String);
      await api.loadToken();
      if (api.token == null) throw DomainError('unauthorized');
      final me = await api.request('GET', '/api/v1/me');
      if (me['id'] != config['user']) throw DomainError('syncAccountMismatch');
      String? role;
      for (var offset = 0; ; offset += 100) {
        final rows =
            (await api.request(
                  'GET',
                  '$path/members?offset=$offset&limit=100',
                ))['items']
                as List;
        for (final r in rows) {
          if (r['id'] == me['id']) role = r['role'] as String;
        }
        if (rows.length < 100) break;
      }
      if (role == null) throw DomainError('forbidden');
      store.setSetting('shared_role_$local', role);
      writable = ['owner', 'captain', 'coach'].contains(role);
      files.catalog?.ensureTeam(store, local);
      key = 'tactical_sync_$local';
      state = jsonDecode(store.setting(key) ?? '{}') as Map<String, dynamic>;
      entries = Map<String, dynamic>.from(state['entries'] as Map? ?? {});
      outbox = Map<String, dynamic>.from(state['outbox'] as Map? ?? {});
      for (final map in store.maps(local)) {
        final catalog = map['catalog_id'] as String?;
        entry(
          'map',
          map['id'] as String,
          remote: catalog == null
              ? null
              : Store.uuid.v5(
                  '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
                  '${api.base}/$team/map/$catalog',
                ),
        );
      }
      persist();
      if (writable) await flush();
      for (var attempt = 0; attempt < 2; attempt++) {
        await pull(conflictLabel);
        if (!writable) break;
        await queueChanges();
        final conflict = await flush();
        deferred = conflict;
        if (!conflict) break;
      }
      store.setSetting(
        'tactical_sync_time_$local',
        DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      running = false;
    }
  }

  Future<bool> flush() async {
    var conflict = false;
    for (final id in outbox.keys.toList()) {
      final operation = outbox[id] as Map<String, dynamic>;
      try {
        final result = await api.request(
          'POST',
          '$path/documents',
          body: Map<String, dynamic>.from(operation['request'] as Map),
        );
        final row = entries[id] as Map<String, dynamic>;
        row['version'] = result['version'];
        row['hash'] = operation['hash'];
        outbox.remove(id);
        persist();
        uploaded++;
      } on DomainError catch (e) {
        if (e.code != 'version_conflict') rethrow;
        outbox.remove(id);
        persist();
        conflict = true;
      }
    }
    return conflict;
  }

  Future<void> queueChanges() async {
    for (final kind in ['map', 'strategy']) {
      final rows = kind == 'map' ? store.maps(local) : store.strategies(local);
      for (final row in rows) {
        final id = row['id'] as String;
        final e = entry(kind, id);
        final payload = await localPayload(kind, row, uploadMedia: true);
        final fingerprint = hash(payload);
        if (e['hash'] == fingerprint) continue;
        final index = '$kind:$id';
        if (outbox.containsKey(index)) continue;
        outbox[index] = {
          'hash': fingerprint,
          'request': {
            'operation_id': Store.uuid.v4(),
            'document_id': e['remote'],
            'expected_version': e['version'],
            'kind': kind,
            'payload': payload,
          },
        };
        persist();
      }
    }
  }

  Future<String?> imageId(String? filename, {required bool upload}) async {
    if (filename == null) return null;
    final file = File(filename);
    if (!await file.exists()) throw DomainError('fileMissing');
    final stat = await file.stat();
    if (stat.size > 20 * 1024 * 1024) throw DomainError('limit');
    final cache = _hashCache[filename];
    Uint8List? bytes;
    var id =
        cache != null &&
            cache.$1 == stat.modified.millisecondsSinceEpoch &&
            cache.$2 == stat.size
        ? cache.$3
        : null;
    if (id == null) {
      bytes = await file.readAsBytes();
      id = sha256.convert(bytes).toString();
      _hashCache[filename] = (
        stat.modified.millisecondsSinceEpoch,
        stat.size,
        id,
      );
    }
    final sent = List<String>.from(state['media'] as List? ?? []);
    if (upload && !sent.contains(id)) {
      bytes ??= await file.readAsBytes();
      await LocalFiles.validateRadar(bytes);
      await api.media('PUT', '$path/media/$id', bytes: bytes);
      sent.add(id);
      state['media'] = sent;
      persist();
    }
    return id;
  }

  Future<Map<String, dynamic>> localPayload(
    String kind,
    Map row, {
    bool uploadMedia = false,
  }) async {
    if (kind == 'strategy') {
      final parent = entry('map', row['map_id'] as String);
      return canonical(kind, {
        'title': row['title'],
        'notes': row['notes'],
        'objects': jsonDecode(row['objects'] as String),
        'map_id': parent['remote'],
        'side': row['side'],
        'level': row['level'],
      });
    }
    final catalog = row['catalog_id'] as String?;
    final descriptor = catalog == null ? null : files.catalog?.find(catalog);
    final primary = row['image_path'] as String?,
        lower = row['lower_image_path'] as String?;
    final primaryDefault = descriptor == null
        ? null
        : files.catalog!.radar(descriptor);
    final lowerDefault =
        descriptor == null || (descriptor['levels'] as List).length < 2
        ? null
        : files.catalog!.radar(descriptor, 'lower');
    return canonical(kind, {
      'title': row['name'],
      'catalog_id': catalog,
      'image_id': primary == primaryDefault
          ? null
          : await imageId(primary, upload: uploadMedia),
      'lower_image_id': lower == lowerDefault
          ? null
          : await imageId(lower, upload: uploadMedia),
    });
  }

  Future<String?> downloadImage(String? id) async {
    if (id == null) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
      throw DomainError('invalidImage');
    }
    final target = File('${files.root.path}/sync-media/$team/$id.radar');
    if (await target.exists()) {
      if (sha256.convert(await target.readAsBytes()).toString() == id) {
        return target.path;
      }
    }
    final bytes = await api.media('GET', '$path/media/$id');
    if (sha256.convert(bytes).toString() != id) {
      throw DomainError('invalidImage');
    }
    await LocalFiles.validateRadar(bytes);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    final sent = List<String>.from(state['media'] as List? ?? []);
    if (!sent.contains(id)) sent.add(id);
    state['media'] = sent;
    return target.path;
  }

  Future<void> pull(String conflictLabel) async {
    final documents = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 5) {
      final rows =
          (await api.request(
                'GET',
                '$path/documents?offset=$offset&limit=5',
              ))['items']
              as List;
      documents.addAll(rows.map((r) => Map<String, dynamic>.from(r as Map)));
      if (rows.length < 5) break;
    }
    documents.sort(
      (a, b) =>
          (a['kind'] == 'map' ? 0 : 1).compareTo(b['kind'] == 'map' ? 0 : 1),
    );
    for (final document in documents) {
      final kind = document['kind'] as String;
      if (!['map', 'strategy'].contains(kind)) continue;
      final payload = canonical(kind, Map.from(document['payload'] as Map));
      var e = byRemote(document['id'] as String);
      if (e == null && kind == 'map') {
        final catalog = payload['catalog_id'];
        final match = store
            .maps(local)
            .where((m) => catalog != null && m['catalog_id'] == catalog)
            .firstOrNull;
        if (match != null) {
          e = entry(kind, match['id'] as String);
          e['remote'] = document['id'];
        }
      }
      RecordData? current;
      if (e != null) {
        final records = kind == 'map'
            ? store.maps(local)
            : store.strategies(local);
        current = records.where((r) => r['id'] == e!['local']).firstOrNull;
        if (current != null &&
            kind == 'strategy' &&
            store.editingStrategies.contains(e['local'])) {
          continue;
        }
        if (current != null) {
          final fingerprint = hash(await localPayload(kind, current));
          if (fingerprint == hash(payload)) {
            e['version'] = document['version'];
            e['hash'] = fingerprint;
            persist();
            continue;
          }
          final dirty = fingerprint != e['hash'];
          if (dirty && e['version'] == document['version']) continue;
          if (dirty && (e['version'] as int) > 0 && kind == 'strategy') {
            store.applyingSync = true;
            try {
              final title = current['title'] as String;
              final copy = store.createStrategy(
                current['map_id'] as String,
                '${title.substring(0, title.length > 75 ? 75 : title.length)} · $conflictLabel',
                current['side'] as String,
                level: current['level'] as String,
              );
              store.saveStrategy(
                copy,
                current['notes'] as String,
                (jsonDecode(current['objects'] as String) as List)
                    .map((r) => Map<String, dynamic>.from(r as Map))
                    .toList(),
                1,
              );
              conflicts++;
            } finally {
              store.applyingSync = false;
            }
          }
        }
      }
      if (kind == 'map') {
        final primary = await downloadImage(payload['image_id'] as String?);
        final lower = await downloadImage(payload['lower_image_id'] as String?);
        final id =
            current?['id'] as String? ??
            store.addMap(local, payload['title'] as String);
        store.db.execute(
          'UPDATE maps SET name=?,catalog_id=?,image_path=?,lower_image_path=? WHERE id=?',
          [payload['title'], payload['catalog_id'], primary, lower, id],
        );
        files.catalog?.ensureTeam(store, local);
        e ??= entry(kind, id, remote: document['id'] as String);
      } else {
        final map = byRemote(payload['map_id'] as String);
        if (map == null) throw DomainError('invalid_link');
        store.applyingSync = true;
        try {
          final id =
              current?['id'] as String? ??
              store.createStrategy(
                map['local'] as String,
                payload['title'] as String,
                payload['side'] as String,
                level: payload['level'] as String,
              );
          store.db.execute(
            'UPDATE strategies SET title=?,map_id=?,side=? WHERE id=?',
            [payload['title'], map['local'], payload['side'], id],
          );
          store.saveStrategy(
            id,
            payload['notes'] as String,
            (payload['objects'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList(),
            store.strategy(id)['version'] as int,
            level: payload['level'] as String,
          );
          e ??= entry(kind, id, remote: document['id'] as String);
        } finally {
          store.applyingSync = false;
        }
      }
      e['version'] = document['version'];
      e['hash'] = hash(payload);
      persist();
      downloaded++;
      if (kind == 'strategy') {
        store.notifyRemoteTactical(e['local'] as String);
      } else {
        for (final row
            in store
                .strategies(local)
                .where((r) => r['map_id'] == e!['local'])) {
          store.notifyRemoteTactical(row['id'] as String);
        }
      }
    }
  }
}
