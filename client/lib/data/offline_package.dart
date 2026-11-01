import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'store.dart';
import 'files.dart';
import 'utilities.dart';
import 'own_video.dart';

/// Bounded JSON format: never extracts caller-supplied paths or archives.
class OfflinePackage {
  static const limit = 100 * 1024 * 1024;
  static Uint8List export(Store store, String team, String locale) {
    final maps = store
        .maps(team)
        .map((m) => Map<String, Object?>.from(m))
        .toList();
    var total = 0;
    for (final map in maps) {
      for (final field in [
        ('image_path', 'image'),
        ('lower_image_path', 'lower_image'),
      ]) {
        final path = map.remove(field.$1) as String?;
        if (path != null) {
          final file = File(path);
          if (!file.existsSync()) throw DomainError('fileMissing');
          total += file.lengthSync();
          if (total > limit ~/ 2) throw DomainError('packageError');
          map[field.$2] = base64Encode(file.readAsBytesSync());
        }
      }
    }
    final utilities = UtilityLibrary(store)
        .list(team)
        .map((u) => Map<String, Object?>.from(u))
        .toList();
    for (final utility in utilities) {
      final details = Map<String, dynamic>.from(
        jsonDecode(utility['details'] as String) as Map,
      );
      final images = <String>[];
      for (final path in details.remove('screenshot_paths') as List? ?? []) {
        final file = File(path as String);
        if (!file.existsSync()) throw DomainError('fileMissing');
        total += file.lengthSync();
        if (total > limit ~/ 2) throw DomainError('packageError');
        images.add(base64Encode(file.readAsBytesSync()));
      }
      details['screenshot_images'] = images;
      final clip = details.remove('video_path') as String?;
      if (clip != null) {
        final file = File(clip);
        if (!file.existsSync()) throw DomainError('fileMissing');
        total += file.lengthSync();
        if (total > limit ~/ 2) throw DomainError('packageError');
        final bytes = file.readAsBytesSync();
        OwnVideo.validate(bytes);
        details['video_bytes'] = base64Encode(bytes);
      }

      utility['details'] = jsonEncode(details);
    }
    final value = {
      'format': 'teamsync-offline',
      'schema': 1,
      'locale': locale,
      'exported_at': store.now,
      'team': store.teams.singleWhere((e) => e['id'] == team),
      'members': store.members(team),
      'maps': maps,
      'strategies': store
          .strategies(team)
          .map(
            (e) => Map<String, Object?>.from(e)
              ..remove('image_path')
              ..remove('primary_image_path')
              ..remove('lower_image_path'),
          )
          .toList(),
      'tasks': store.tasks(team),
      'utilities': utilities,
      'excluded': [
        'demo_files',
        'external_videos',
        'strategy_history',
        'online_permissions',
      ],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    if (bytes.length > limit) throw DomainError('packageError');
    return bytes;
  }

  static Future<String> restore(
    Store store,
    Directory root,
    Uint8List bytes,
  ) async {
    final created = <File>[];
    try {
      if (bytes.length > limit) throw DomainError('packageError');
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (data['format'] != 'teamsync-offline' || data['schema'] != 1) {
        throw DomainError('packageError');
      }
      final maps = data['maps'] as List,
          members = data['members'] as List,
          strategies = data['strategies'] as List,
          tasks = data['tasks'] as List,
          utilities = data['utilities'] as List? ?? [];
      if (maps.length > 100 ||
          members.length > 100 ||
          strategies.length > 500 ||
          tasks.length > 5000 ||
          utilities.length > 5000) {
        throw DomainError('packageError');
      }
      final images = <String, String>{};
      for (final raw in maps) {
        final map = raw as Map<String, dynamic>;
        for (final field in ['image', 'lower_image']) {
          if (map[field] != null) {
            final image = base64Decode(map[field] as String);
            if (image.length > 20 * 1024 * 1024 || image.length < 8) {
              throw DomainError('packageError');
            }
            final png =
                image[0] == 137 &&
                image[1] == 80 &&
                image[2] == 78 &&
                image[3] == 71;
            final jpg = image[0] == 255 && image[1] == 216 && image[2] == 255;
            if (!png && !jpg) throw DomainError('packageError');
            await LocalFiles.validateRadar(image);
            final file = File(
              '${root.path}/media/${Store.uuid.v4()}.${png ? 'png' : 'jpg'}',
            );
            await file.parent.create(recursive: true);
            created.add(file);
            await file.writeAsBytes(image, flush: true);
            images['${map['id']}:$field'] = file.path;
          }
        }
      }
      for (final raw in utilities) {
        final utility = raw as Map;
        final details = Map<String, dynamic>.from(
          jsonDecode(utility['details'] as String) as Map,
        );
        if (details.containsKey('screenshot_paths') ||
            details.containsKey('video_path')) {
          throw DomainError('packageError');
        }
        final images = details.remove('screenshot_images') as List? ?? [];
        if (images.length > 10) throw DomainError('packageError');
        final paths = <String>[];
        for (final encoded in images) {
          final image = base64Decode(encoded as String);
          if (image.length < 8 || image.length > 20 * 1024 * 1024) {
            throw DomainError('packageError');
          }
          final png =
              image[0] == 137 &&
              image[1] == 80 &&
              image[2] == 78 &&
              image[3] == 71;
          final jpg = image[0] == 255 && image[1] == 216 && image[2] == 255;
          if (!png && !jpg) throw DomainError('packageError');
          await LocalFiles.validateRadar(image);
          final file = File(
            '${root.path}/media/${Store.uuid.v4()}.${png ? 'png' : 'jpg'}',
          );
          await file.parent.create(recursive: true);
          created.add(file);
          await file.writeAsBytes(image, flush: true);
          paths.add(file.path);
        }
        details['screenshot_paths'] = paths;
        final clip = details.remove('video_bytes') as String?;
        if (clip != null) {
          final video = await OwnVideo.importBytes(
            LocalFiles(root),
            base64Decode(clip),
          );
          created.add(File(video));
          details['video_path'] = video;
        }

        utility['details'] = jsonEncode(details);
      }
      return store.transaction<String>(() {
        final team = store.createTeam((data['team'] as Map)['name'] as String);
        final memberIds = <String, String>{},
            mapIds = <String, String>{},
            strategyIds = <String, String>{};
        for (final raw in members) {
          final m = raw as Map;
          final old = m['id'] as String;
          if (memberIds.containsKey(old)) throw DomainError('packageError');
          memberIds[old] = store.addMember(
            team,
            m['name'] as String,
            m['role'] as String,
            m['game_role'] as String,
          );
        }
        for (final raw in maps) {
          final m = raw as Map;
          final old = m['id'] as String;
          if (mapIds.containsKey(old)) throw DomainError('packageError');
          final id = store.addMap(team, m['name'] as String);
          mapIds[old] = id;
          if (images['$old:image'] != null) {
            store.mapImage(id, images['$old:image']!);
          }
          store.db.execute(
            'UPDATE maps SET catalog_id=?,lower_image_path=? WHERE id=?',
            [m['catalog_id'], images['$old:lower_image'], id],
          );
        }
        for (final raw in strategies) {
          final s = raw as Map;
          final old = s['id'] as String;
          if (strategyIds.containsKey(old)) throw DomainError('packageError');
          final map = mapIds[s['map_id']];
          if (map == null) throw DomainError('packageError');
          final id = Store.uuid.v4();
          strategyIds[old] = id;
          final notes = s['notes'] as String;
          final objects = (jsonDecode(s['objects'] as String) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          store.validateStrategy(notes, objects);
          final version = s['version'] as int;
          if (version < 1) throw DomainError('packageError');
          if (!['default', 'lower'].contains(s['level'] ?? 'default')) {
            throw DomainError('packageError');
          }
          store.db.execute(
            'INSERT INTO strategies(id,map_id,title,side,notes,objects,version,updated_at,level) VALUES(?,?,?,?,?,?,?,?,?)',
            [
              id,
              map,
              store.requiredText(s['title'] as String),
              s['side'],
              notes,
              jsonEncode(objects),
              version,
              store.now,
              s['level'] ?? 'default',
            ],
          );
          final snapshot = store.rows('SELECT * FROM strategies WHERE id=?', [
            id,
          ]).single;
          store.db.execute('INSERT INTO strategy_versions VALUES(?,?,?,?,?)', [
            Store.uuid.v4(),
            id,
            version,
            jsonEncode(snapshot),
            store.now,
          ]);
        }
        for (final raw in utilities) {
          final utility = raw as Map;
          final map = mapIds[utility['map_id']];
          if (map == null) throw DomainError('packageError');
          final details = Map<String, dynamic>.from(
            jsonDecode(utility['details'] as String) as Map,
          );
          details['strategy_ids'] = [
            for (final id in details['strategy_ids'] as List? ?? [])
              strategyIds[id] ?? (throw DomainError('packageError')),
          ];
          UtilityLibrary(store).save(
            team,
            map,
            utility['title'] as String,
            utility['side'] as String,
            utility['notes'] as String,
            details,
          );
        }
        for (final raw in tasks) {
          final t = raw as Map;
          if (t['member_id'] != null &&
                  !memberIds.containsKey(t['member_id']) ||
              t['strategy_id'] != null &&
                  !strategyIds.containsKey(t['strategy_id'])) {
            throw DomainError('packageError');
          }
          final id = store.createTask(
            team,
            t['title'] as String,
            t['notes'] as String,
            member: memberIds[t['member_id']],
            strategyId: strategyIds[t['strategy_id']],
          );
          final status = t['status'];
          if (![
            'todo',
            'in_progress',
            'submitted',
            'approved',
          ].contains(status)) {
            throw DomainError('packageError');
          }
          final reason = t['review_reason'] ?? '';
          if (reason is! String || reason.length > 2000) {
            throw DomainError('packageError');
          }
          store.db.execute('UPDATE tasks SET review_reason=? WHERE id=?', [
            reason,
            id,
          ]);
          if (status != 'todo') {
            store.transitionTask(
              id,
              status == 'in_progress' ? 'in_progress' : 'submitted',
            );
            if (status == 'approved') store.transitionTask(id, 'approved');
          }
        }
        return team;
      });
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      throw DomainError('packageError');
    }
  }
}
