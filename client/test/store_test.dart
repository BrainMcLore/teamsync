import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/store.dart';

void main() {
  late Directory directory;
  late Store store;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('teamsync_test_');
    store = Store('${directory.path}/test.sqlite');
  });
  tearDown(() {
    store.close();
    directory.deleteSync(recursive: true);
  });
  test(
    'persistent workflow, versions, restore, language and demo metadata',
    () {
      final team = store.createTeam('Команда');
      final member = store.addMember(team, 'Player', 'player', 'IGL');
      final map = store.addMap(team, 'de_mirage');
      final strategy = store.createStrategy(map, 'Выход A', 'T');
      store.saveStrategy(strategy, 'Smoke CT', [
        {'type': 'smoke', 'x': 0.5, 'y': 0.4},
      ], 1);
      expect(store.versions(strategy).length, 2);
      final task = store.createTask(
        team,
        'Изучить выход',
        'Practice',
        member: member,
        strategyId: strategy,
      );
      store.transitionTask(task, 'submitted');
      store.transitionTask(task, 'approved');
      store.setSetting('language', 'en');
      store.addDemo(team, 'match.dem', 'local.dem', 100);
      store.close();
      store = Store('${directory.path}/test.sqlite');
      expect(store.setting('language'), 'en');
      expect(store.tasks(team).single['status'], 'approved');
      expect(store.strategy(strategy)['version'], 2);
      expect(
        jsonDecode(store.strategy(strategy)['objects'] as String),
        hasLength(1),
      );
      expect(store.demos(team), hasLength(1));
      store.restoreVersion(strategy, 1);
      expect(store.strategy(strategy)['version'], 3);
      expect(store.strategy(strategy)['notes'], '');
      expect(store.versions(strategy), hasLength(3));
    },
  );
  test('reject foreign team links and invalid task transitions', () {
    final a = store.createTeam('A'), b = store.createTeam('B');
    final member = store.addMember(b, 'B', 'player', 'IGL');
    final map = store.addMap(b, 'Dust II');
    final strategy = store.createStrategy(map, 'B execute', 'CT');
    expect(
      () => store.createTask(a, 'Wrong', '', member: member),
      throwsA(isA<DomainError>()),
    );
    expect(
      () => store.createTask(a, 'Wrong', '', strategyId: strategy),
      throwsA(isA<DomainError>()),
    );
    final task = store.createTask(a, 'Task', '');
    expect(
      () => store.transitionTask(task, 'approved'),
      throwsA(isA<DomainError>()),
    );
    expect(store.tasks(a).single['status'], 'todo');
  });
  test('stale versions rejected without losing history', () {
    final team = store.createTeam('A'), map = store.addMap(team, 'Ancient');
    final id = store.createStrategy(map, 'B', 'T');
    store.saveStrategy(id, 'first', [], 1);
    expect(
      () => store.saveStrategy(id, 'stale', [], 1),
      throwsA(isA<DomainError>()),
    );
    expect(store.strategy(id)['notes'], 'first');
    expect(store.versions(id), hasLength(2));
  });
  test('empty names and invalid roles are rejected', () {
    expect(() => store.createTeam('   '), throwsA(isA<DomainError>()));
    final id = store.createTeam('A');
    expect(
      () => store.addMember(id, 'B', 'admin', 'IGL'),
      throwsA(isA<DomainError>()),
    );
    expect(store.members(id), isEmpty);
  });
}
