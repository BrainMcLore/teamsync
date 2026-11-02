import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/offline_package.dart';
import 'package:teamsync/data/playbook.dart';
import 'package:teamsync/data/utilities.dart';
import 'package:teamsync/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Store store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('teamsync_export_');
    store = Store(':memory:');
  });
  tearDown(() {
    store.close();
    dir.deleteSync(recursive: true);
  });
  test('offline package round trip keeps links and approval without replacing original', () async {
    final team = store.createTeam('LAN Команда');
    final member = store.addMember(team, 'Rifle', 'player', 'Entry');
    final map = store.addMap(team, 'Mirage');

    final strategy = store.createStrategy(map, 'Выход A', 'T');
    UtilityLibrary(store).save(team, map, 'Смок CT', 'T', 'Инструкция', {
      'grenade': 'smoke',
      'strategy_ids': [strategy],
      'source_url': 'https://youtu.be/example?t=12',
      'screenshot_paths': [File('test/fixtures/radar.png').absolute.path],
      'video_path': File('test/fixtures/own_clip.mp4').absolute.path,
    });
    store.saveStrategy(strategy, 'Smoke CT', [
      {'type': 'smoke', 'x': 0.3, 'y': 0.4},
    ], 1);
    final task = store.createTask(
      team,
      'Смок',
      'Practice',
      member: member,
      strategyId: strategy,
    );
    store.transitionTask(task, 'submitted');
    store.transitionTask(task, 'approved');
    final bytes = OfflinePackage.export(store, team, 'en');
    final clone = await OfflinePackage.restore(store, dir, bytes);
    expect(store.teams, hasLength(2));
    expect(clone, isNot(team));
    final clip =
        jsonDecode(
              UtilityLibrary(store).list(clone).single['details'] as String,
            )['video_path']
            as String;
    expect(
      await File(clip).readAsBytes(),
      await File('test/fixtures/own_clip.mp4').readAsBytes(),
    );
    expect(
      UtilityLibrary(store).list(clone).single['map_id'],
      store.maps(clone).single['id'],
    );
    expect(UtilityLibrary(store).list(clone).single['notes'], 'Инструкция');
    final screenshot =
        (jsonDecode(
                      UtilityLibrary(store).list(clone).single['details']
                          as String,
                    )['screenshot_paths']
                    as List)
                .single
            as String;
    expect(screenshot, isNot(File('test/fixtures/radar.png').absolute.path));
    expect(
      await File(screenshot).readAsBytes(),
      await File('test/fixtures/radar.png').readAsBytes(),
    );
    expect(
      jsonDecode(
        UtilityLibrary(store).list(clone).single['details'] as String,
      )['strategy_ids'],
      [store.strategies(clone).single['id']],
    );
    expect(store.tasks(clone).single['member_name'], 'Rifle');
    expect(store.tasks(clone).single['strategy_title'], 'Выход A');
    expect(store.tasks(clone).single['status'], 'approved');
    expect(store.strategies(clone).single['version'], 2);
    expect(store.tasks(team).single['id'], task);
  });
  test('malformed package rolls back all imported database rows', () async {
    final team = store.createTeam('A'), map = store.addMap(team, 'Mirage');
    store.createStrategy(map, 'A', 'T');
    final data = jsonDecode(
      utf8.decode(OfflinePackage.export(store, team, 'ru')),
    ) as Map;
    (data['strategies'] as List).first['objects'] =
        '[{"type":"arrow","x":0.1,"y":0.2}]';
    await expectLater(
      OfflinePackage.restore(store, dir, utf8.encode(jsonEncode(data))),
      throwsA(isA<DomainError>()),
    );
    expect(store.teams, hasLength(1));
    expect(store.maps(team), hasLength(1));
  });
  test(
    'offline import never accepts a caller supplied local media path',
    () async {
      final team = store.createTeam('Own clips'),
          map = store.addMap(team, 'Mirage');
      UtilityLibrary(store)
          .save(team, map, 'Smoke', 'T', 'Instruction', {'grenade': 'smoke'});
      final data = jsonDecode(
        utf8.decode(OfflinePackage.export(store, team, 'en')),
      ) as Map;
      final utility = (data['utilities'] as List).single as Map;
      final details = jsonDecode(utility['details'] as String) as Map;
      details['video_path'] = File('test/fixtures/own_clip.mp4').absolute.path;
      utility['details'] = jsonEncode(details);
      await expectLater(
        OfflinePackage.restore(store, dir, utf8.encode(jsonEncode(data))),
        throwsA(isA<DomainError>()),
      );
      expect(store.teams, hasLength(1));
      expect(File('test/fixtures/own_clip.mp4').existsSync(), isTrue);
    },
  );
  test(
    'strategy history round trip remaps IDs and restores old content',
    () async {
      final team = store.createTeam('History');
      final map = store.addMap(team, 'Mirage');
      final id = store.createStrategy(map, 'A', 'T');
      store.saveStrategy(id, 'Revision two', [], 1);
      final before = store.versions(id);
      final clone = await OfflinePackage.restore(
        store,
        dir,
        OfflinePackage.export(store, team, 'en'),
      );
      final restored = store.strategies(clone).single['id'] as String;
      final versions = store.versions(restored);
      expect(versions.map((v) => v['version']).toList(), [2, 1]);
      expect(
        versions.map((v) => v['created_at']).toList(),
        before.map((v) => v['created_at']).toList(),
      );
      for (final row in versions) {
        final payload = jsonDecode(row['payload'] as String) as Map;
        expect(payload['id'], restored);
        expect(payload['map_id'], store.maps(clone).single['id']);
      }
      store.restoreVersion(restored, 1);
      expect(store.strategy(restored)['notes'], '');
      expect(store.strategy(restored)['version'], 3);
      expect(store.strategy(id)['notes'], 'Revision two');
    },
  );

  test('legacy packages restore without claiming a full history', () async {
    final team = store.createTeam('Legacy');
    store.createStrategy(store.addMap(team, 'Mirage'), 'A', 'T');
    final data = jsonDecode(
      utf8.decode(OfflinePackage.export(store, team, 'en')),
    ) as Map;
    data['schema'] = 1;
    data.remove('strategy_history');
    final clone = await OfflinePackage.restore(
      store,
      dir,
      utf8.encode(jsonEncode(data)),
    );
    expect(
      store.versions(store.strategies(clone).single['id'] as String),
      hasLength(1),
    );
  });

  test(
    'corrupt history rolls back rows and newly created radar files',
    () async {
      final team = store.createTeam('Invalid history');
      final map = store.addMap(team, 'Mirage');
      store.mapImage(map, File('test/fixtures/radar.png').absolute.path);
      store.createStrategy(map, 'A', 'T');
      final bytes = OfflinePackage.export(store, team, 'en');
      for (final mutation in ['duplicate', 'future', 'missing', 'path']) {
        final data = jsonDecode(utf8.decode(bytes)) as Map;
        final history = data['strategy_history'] as List;
        if (mutation == 'duplicate') {
          history.add(Map.from(history.single as Map));
        }
        if (mutation == 'future') history.single['version'] = 99;
        if (mutation == 'missing') history.clear();
        if (mutation == 'path') {
          history.single['snapshot']['image_path'] = '/tmp/forged';
        }
        await expectLater(
          OfflinePackage.restore(store, dir, utf8.encode(jsonEncode(data))),
          throwsA(isA<DomainError>()),
        );
        expect(store.teams, hasLength(1));
        expect(
          await dir.list(recursive: true).where((e) => e is File).toList(),
          isEmpty,
        );
      }
    },
  );

  test('generate real Cyrillic PDF in both languages', () async {
    final team = store.createTeam('Пятёрка'),
        map = store.addMap(team, 'Mirage');
    final id = store.createStrategy(map, 'Выход на точку A', 'T');
    store.saveStrategy(
      id,
      'Синхронный выход через коннектор. Дым на CT.',
      [],
      1,
    );
    for (final language in ['ru', 'en']) {
      final l = await AppLocalizations.delegate.load(Locale(language));
      final bytes = await Playbook.generate(store, team, l);
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
      final output = File('../artifacts/verification/playbook-$language.pdf');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes);
    }
  });
}
