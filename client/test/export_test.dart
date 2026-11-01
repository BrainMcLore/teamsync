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
    expect(
      UtilityLibrary(store).list(clone).single['map_id'],
      store.maps(clone).single['id'],
    );
    expect(UtilityLibrary(store).list(clone).single['notes'], 'Инструкция');
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
