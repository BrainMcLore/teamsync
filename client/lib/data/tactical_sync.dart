import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'account.dart';
import 'account_roster.dart';
import 'files.dart';
import 'store.dart';
import 'utilities.dart';
import 'own_video.dart';
import 'utility_skills.dart';

/// Durable outbox + optimistic versions. No network operation runs in a SQLite
/// transaction. A lost acknowledgement reuses the exact operation and payload.
class TacticalSync {
  final Store store;
  final LocalFiles files;
  final AccountClient Function(String)? clientFactory;
  bool running = false;
  bool deferred = false;
  int conflicts = 0, uploaded = 0, downloaded = 0;
  final unlinkedTasks = <String>{};
  TacticalSync(this.store, this.files, {this.clientFactory});
  late AccountClient api;
  late String team, local, key;
  late Map<String, dynamic> state, entries, outbox;
  bool writable = false, playerSubmission = false, blockedByRole = false;
  late String accountUser;
  final Map<String, (int, int, String)> _hashCache = {};

  String hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  Map<String, dynamic> canonical(String kind, Map value) {
    if (kind == 'utility') {
      final details = Map<String, dynamic>.from(value['utility'] as Map);
      return {
        'title': value['title'],
        'notes': value['notes'] ?? '',
        'map_id': value['map_id'],
        'side': value['side'],
        'utility': {
          for (final key in [
            'grenade',
            'start',
            'target',
            'throw_type',
            'author',
            'verified_at',
            'map_revision',
          ])
            key: details[key] ?? '',
          'source_url': details['source_url'],
          'video_id': details['video_id'],
          'training_revision': details['training_revision'] ?? 1,
          'review_reason': details['review_reason'] ?? '',
          'image_ids': List<String>.from(details['image_ids'] as List? ?? []),
          'strategy_ids': List<String>.from(
            details['strategy_ids'] as List? ?? [],
          ),
        },
      };
    }
    if (kind == 'task') {
      return {
        'title': value['title'],
        'notes': value['notes'] ?? '',
        'strategy_id': value['strategy_id'],
        'assignee_user_id': value['assignee_user_id'],
        'status': value['status'] ?? 'todo',
        'task_review_reason': value['task_review_reason'] ?? '',
        'task_type': value['task_type'] ?? 'general',
        'task_due_at': value['task_due_at'],
        'task_criteria': value['task_criteria'] ?? '',
      };
    }
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
  Map<String, String> get rosterIds {
    final binding = jsonDecode(store.setting('account_team_$local')!) as Map;
    final namespace = sha256
        .convert(
          utf8.encode(
            '${binding['server']}/${binding['user']}/${binding['team']}',
          ),
        )
        .toString();
    final snapshot =
        jsonDecode(store.setting('account_roster_$namespace') ?? '{}') as Map;
    return Map<String, String>.from(snapshot['members'] as Map? ?? {});
  }

  List<RecordData> records(String kind) => switch (kind) {
    'map' => store.maps(local),
    'task' => store.tasks(local),
    'utility' => UtilityLibrary(store).list(local),
    _ => store.strategies(local),
  };

  void assertActiveAccount() {
    if (store.setting('account_signed_out') == '1') {
      throw DomainError('unauthorized');
    }
    final active = store.setting('account_identity');
    if (active != null &&
        active != jsonEncode([api.base.toString(), accountUser])) {
      throw DomainError('syncAccountMismatch');
    }
  }

  String get path => '/api/v1/teams/$team';

  Future<void> run(String localTeam, {required String conflictLabel}) async {
    if (running) return;
    final binding = store.setting('account_team_$localTeam');
    if (binding == null) return;
    running = true;
    deferred = false;
    blockedByRole = false;
    unlinkedTasks.clear();
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
      accountUser = config['user'] as String;
      assertActiveAccount();
      await api.loadToken();
      if (api.token == null) throw DomainError('unauthorized');
      final me = await api.request('GET', '/api/v1/me');
      accountUser = me['id'] as String;
      if (me['id'] != config['user']) throw DomainError('syncAccountMismatch');
      assertActiveAccount();
      String? role;
      final roster = <dynamic>[];
      for (var offset = 0; ; offset += 100) {
        assertActiveAccount();
        final rows =
            (await api.request(
                  'GET',
                  '$path/members?offset=$offset&limit=100',
                ))['items']
                as List;
        roster.addAll(rows);
        for (final r in rows) {
          if (r['id'] == me['id']) role = r['role'] as String;
        }
        if (rows.length < 100) break;
      }
      if (role == null) throw DomainError('forbidden');
      assertActiveAccount();
      saveAccountRoster(
        store,
        api.base.toString(),
        me['id'] as String,
        {
          'id': team,
          'name': store.teams.singleWhere((t) => t['id'] == local)['name'],
          'role': role,
        },
        roster,
        localTeam: local,
        select: false,
      );
      store.setSetting('shared_role_$local', role);
      writable = ['owner', 'captain', 'coach'].contains(role);
      playerSubmission = role == 'player';
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
      await flush();
      for (var attempt = 0; attempt < 2; attempt++) {
        await pull(conflictLabel);
        await queueChanges();
        final conflict = await flush();
        deferred = conflict;
        if (!conflict) break;
      }
      if (UtilityLibrary(store).list(local).isNotEmpty) {
        final skills = SkillSync(
          SkillStore(store, local),
          api,
          path,
          accountUser,
          assertActiveAccount,
        );
        await skills.run();
        blockedByRole = blockedByRole || skills.blocked;
        deferred = deferred || skills.pending;
        conflicts += skills.conflicts;
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
      assertActiveAccount();
      final operation = outbox[id] as Map<String, dynamic>;
      final request = operation['request'] as Map;
      final payload = request['payload'] as Map;
      if (!writable &&
          !(playerSubmission &&
              request['kind'] == 'task' &&
              payload['assignee_user_id'] == accountUser &&
              ['in_progress', 'submitted'].contains(payload['status']))) {
        blockedByRole = true;
        continue;
      }

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
        if (e.code == 'forbidden') {
          blockedByRole = true;
          if (writable) {
            writable = false;
            playerSubmission = false;
            store.setSetting('shared_role_$local', 'viewer');
            return false;
          }
          continue;
        }
        if (e.code != 'version_conflict') rethrow;
        outbox.remove(id);
        persist();
        conflict = true;
      }
    }
    return conflict;
  }

  Future<void> queueChanges() async {
    for (final kind in ['map', 'strategy', 'utility', 'task']) {
      for (final row in records(kind)) {
        final id = row['id'] as String;
        // Preserve legacy assignments locally without blocking unrelated data.
        if (kind == 'task' &&
            row['member_id'] != null &&
            !rosterIds.values.contains(row['member_id'])) {
          unlinkedTasks.add(id);
          continue;
        }
        final e = entry(kind, id);
        final payload = await localPayload(kind, row, uploadMedia: writable);
        final fingerprint = hash(payload);
        if (e['hash'] == fingerprint) continue;
        if (!writable &&
            !(playerSubmission &&
                kind == 'task' &&
                e['version'] != 0 &&
                row['member_id'] ==
                    store.setting('shared_user_member_$local') &&
                ['in_progress', 'submitted'].contains(row['status']))) {
          final seededMap =
              kind == 'map' &&
              e['version'] == 0 &&
              row['catalog_id'] != null &&
              payload['image_id'] == null &&
              payload['lower_image_id'] == null &&
              files.catalog?.find(row['catalog_id'] as String)?['name'] ==
                  row['name'];
          if (!seededMap) blockedByRole = true;
          continue;
        }
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

  Future<String?> assetId(
    String? filename, {
    required bool upload,
    bool video = false,
  }) async {
    if (filename == null) return null;
    final file = File(filename);
    final paths = Map<String, dynamic>.from(state['asset_paths'] as Map? ?? {});
    final rootPath = files.root.absolute.uri
        .normalizePath()
        .toFilePath()
        .replaceAll(RegExp(r'[\\/]+$'), '');
    final ownPath = file.absolute.uri.normalizePath().toFilePath();
    final cached = RegExp(r'([0-9a-f]{64})\.(?:radar|mp4)$')
        .firstMatch(ownPath)
        ?.group(1);
    if (!await file.exists()) {
      final previous = paths[filename] as String? ?? cached;
      if (previous == null ||
          !ownPath.startsWith('$rootPath${Platform.pathSeparator}')) {
        throw DomainError('fileMissing');
      }
      try {
        final restored = await downloadAsset(previous, video: video);
        if (restored != null && !await file.exists()) {
          await file.parent.create(recursive: true);
          await File(restored).copy(file.path);
        }
      } on DomainError catch (e) {
        if (e.code == 'not_found') throw DomainError('fileMissing');
        rethrow;
      }
    }
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
    if (cached != null &&
        id != cached &&
        ownPath.startsWith('$rootPath${Platform.pathSeparator}')) {
      final restored = await downloadAsset(cached, video: video);
      if (restored != null &&
          !await FileSystemEntity.identical(restored, filename)) {
        await File(restored).copy(filename);
      }
      _hashCache.remove(filename);
      return assetId(filename, upload: upload, video: video);
    }
    if (paths[filename] != id) {
      paths[filename] = id;
      state['asset_paths'] = paths;
      persist();
    }
    final sent = List<String>.from(state['media'] as List? ?? []);
    if (upload && !sent.contains(id)) {
      bytes ??= await file.readAsBytes();
      if (video) {
        OwnVideo.validate(bytes);
      } else {
        await LocalFiles.validateRadar(bytes);
      }
      assertActiveAccount();
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
    if (kind == 'utility') {
      final details = Map<String, dynamic>.from(
        jsonDecode(row['details'] as String) as Map,
      );
      details['video_id'] = await assetId(
        details['video_path'] as String?,
        upload: uploadMedia,
        video: true,
      );
      details['image_ids'] = [
        for (final file in details['screenshot_paths'] as List? ?? [])
          await assetId(file as String, upload: uploadMedia),
      ];
      details['strategy_ids'] = [
        for (final id in details['strategy_ids'] as List? ?? [])
          entry('strategy', id as String)['remote'],
      ];
      return canonical(kind, {
        'title': row['title'],
        'notes': row['notes'],
        'side': row['side'],
        'map_id': entry('map', row['map_id'] as String)['remote'],
        'utility': details,
      });
    }
    if (kind == 'task') {
      final assignee = rosterIds.entries
          .where((e) => e.value == row['member_id'])
          .firstOrNull
          ?.key;
      if (row['member_id'] != null && assignee == null) {
        throw DomainError('invalid_link');
      }
      return canonical(kind, {
        'title': row['title'],
        'notes': row['notes'],
        'status': row['status'],
        'task_review_reason': row['review_reason'] ?? '',
        'task_type': row['task_type'] ?? 'general',
        'task_due_at': row['due_at'],
        'task_criteria': row['criteria'] ?? '',
        'strategy_id': row['strategy_id'] == null
            ? null
            : entry('strategy', row['strategy_id'] as String)['remote'],
        'assignee_user_id': assignee,
      });
    }
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
          : await assetId(primary, upload: uploadMedia),
      'lower_image_id': lower == lowerDefault
          ? null
          : await assetId(lower, upload: uploadMedia),
    });
  }

  Future<String?> downloadAsset(String? id, {bool video = false}) async {
    if (id == null) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
      throw DomainError('invalidImage');
    }
    final target = File(
      video
          ? '${files.root.path}/media/sync-videos/$team/$id.mp4'
          : '${files.root.path}/sync-media/$team/$id.radar',
    );
    if (await target.exists()) {
      if (sha256.convert(await target.readAsBytes()).toString() == id) {
        return target.path;
      }
    }
    assertActiveAccount();
    final bytes = await api.media('GET', '$path/media/$id');
    if (sha256.convert(bytes).toString() != id) {
      throw DomainError('invalidImage');
    }
    if (video) {
      OwnVideo.validate(bytes);
    } else {
      await LocalFiles.validateRadar(bytes);
    }
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
      assertActiveAccount();
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
          ([
            'map',
            'strategy',
            'utility',
            'task',
          ].indexOf(a['kind'] as String)).compareTo(
            ['map', 'strategy', 'utility', 'task'].indexOf(b['kind'] as String),
          ),
    );
    for (final document in documents) {
      final kind = document['kind'] as String;
      if (!['map', 'strategy', 'utility', 'task'].contains(kind)) continue;
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
      var currentDirty = false;
      if (e != null) {
        final rows = records(kind);
        current = rows.where((r) => r['id'] == e!['local']).firstOrNull;
        if (current != null &&
            kind == 'utility' &&
            store.editingUtilities.contains(e['local'])) {
          continue;
        }
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
          currentDirty = dirty;
          if (dirty && e['version'] == document['version']) continue;
          if (dirty &&
              ((e['version'] as int) > 0 ||
                  outbox.containsKey('$kind:${e['local']}')) &&
              kind == 'strategy') {
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
      if (kind == 'utility') {
        final parent = byRemote(payload['map_id'] as String);
        if (parent == null) throw DomainError('invalid_link');
        final details = Map<String, dynamic>.from(payload['utility'] as Map);
        details['screenshot_paths'] = [
          for (final image in details['image_ids'] as List? ?? [])
            await downloadAsset(image as String),
        ];
        details.remove('image_ids');
        details['video_path'] = await downloadAsset(
          details.remove('video_id') as String?,
          video: true,
        );

        details['strategy_ids'] = [
          for (final remote in details['strategy_ids'] as List? ?? [])
            byRemote(remote as String)?['local'] ??
                (throw DomainError('invalid_link')),
        ];
        if (current != null &&
            (store.editingUtilities.contains(current['id']) ||
                jsonEncode(
                      records(kind)
                          .where((r) => r['id'] == current!['id'])
                          .firstOrNull,
                    ) !=
                    jsonEncode(current))) {
          continue;
        }
        store.applyingSync = true;
        try {
          final library = UtilityLibrary(store);
          if (current != null &&
              e != null &&
              e['version'] != document['version'] &&
              currentDirty) {
            final title = current['title'] as String;
            library.save(
              local,
              current['map_id'] as String,
              '${title.substring(0, title.length.clamp(0, 75))} · $conflictLabel',
              current['side'] as String,
              current['notes'] as String,
              Map<String, dynamic>.from(
                jsonDecode(current['details'] as String) as Map,
              ),
            );
            conflicts++;
          }
          final id = library.save(
            local,
            parent['local'] as String,
            payload['title'] as String,
            payload['side'] as String,
            payload['notes'] as String,
            details,
            id: current?['id'] as String?,
          );
          e ??= entry(kind, id, remote: document['id'] as String);
        } finally {
          store.applyingSync = false;
        }
      } else if (kind == 'task') {
        store.applyingSync = true;
        try {
          final parent = payload['strategy_id'] == null
              ? null
              : byRemote(payload['strategy_id'] as String);
          if (payload['strategy_id'] != null && parent == null) {
            throw DomainError('invalid_link');
          }
          final member = rosterIds[payload['assignee_user_id']];
          if (current != null &&
              e != null &&
              e['version'] != document['version'] &&
              currentDirty) {
            final copy = store.createTask(
              local,
              '${(current['title'] as String).substring(0, (current['title'] as String).length.clamp(0, 75))} · $conflictLabel',
              current['notes'] as String,
              member: current['member_id'] as String?,
              strategyId: current['strategy_id'] as String?,
              taskType: current['task_type'] as String? ?? 'general',
              dueAt: DateTime.tryParse(current['due_at'] as String? ?? ''),
              criteria: current['criteria'] as String? ?? '',
            );
            store.db.execute(
              'UPDATE tasks SET status=?,review_reason=? WHERE id=?',
              [current['status'], current['review_reason'], copy],
            );
            conflicts++;
          }
          final id =
              current?['id'] as String? ??
              store.createTask(
                local,
                payload['title'] as String,
                payload['notes'] as String,
                member: member,
                strategyId: parent?['local'] as String?,
              );
          store.db.execute(
            'UPDATE tasks SET title=?,notes=?,status=?,member_id=?,strategy_id=?,updated_at=?,review_reason=?,task_type=?,due_at=?,criteria=? WHERE id=?',
            [
              payload['title'],
              payload['notes'],
              payload['status'],
              member,
              parent?['local'],
              store.now,
              payload['task_review_reason'] ?? '',
              payload['task_type'] ?? 'general',
              payload['task_due_at'],
              payload['task_criteria'] ?? '',
              id,
            ],
          );
          e ??= entry(kind, id, remote: document['id'] as String);
        } finally {
          store.applyingSync = false;
        }
      } else if (kind == 'map') {
        final primary = await downloadAsset(payload['image_id'] as String?);
        final lower = await downloadAsset(payload['lower_image_id'] as String?);
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
      if (kind == 'strategy' || kind == 'task' || kind == 'utility') {
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
