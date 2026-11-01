import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
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
      store.transitionTask(task, 'in_progress');
      expect(store.tasks(team).single['status'], 'in_progress');
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
  test(
    'returning a task requires a review comment and preserves it on restart',
    () {
      final team = store.createTeam('Review');
      final task = store.createTask(team, 'Dry run', '');
      store.transitionTask(task, 'in_progress');
      store.transitionTask(task, 'submitted');
      expect(
        () => store.transitionTask(task, 'todo'),
        throwsA(isA<DomainError>()),
      );
      expect(store.tasks(team).single['status'], 'submitted');
      store.transitionTask(task, 'todo', reason: 'Repeat the flash timing');
      store.close();
      store = Store('${directory.path}/test.sqlite');
      expect(
        store.tasks(team).single['review_reason'],
        'Repeat the flash timing',
      );
      store.transitionTask(task, 'in_progress');
      expect(
        store.tasks(team).single['review_reason'],
        'Repeat the flash timing',
      );
    },
  );
  test('v5 task migration preserves assignments and a durable queue', () {
    final team = store.createTeam('Existing');
    final member = store.addMember(team, 'Alice', 'player', 'IGL');
    final task = store.createTask(
      team,
      'Existing task',
      'Keep these notes',
      member: member,
    );
    store.setSetting('tactical_sync_$team', '{"outbox":{"op":{}}}');
    store.close();
    final old = sqlite3.open('${directory.path}/test.sqlite');
    old.execute('''CREATE TABLE tasks_old(id TEXT PRIMARY KEY,team_id TEXT NOT NULL REFERENCES teams(id),strategy_id TEXT REFERENCES strategies(id),member_id TEXT REFERENCES members(id),title TEXT NOT NULL,notes TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('todo','submitted','approved')),updated_at TEXT NOT NULL);
INSERT INTO tasks_old SELECT id,team_id,strategy_id,member_id,title,notes,status,updated_at FROM tasks;
DROP TABLE tasks; ALTER TABLE tasks_old RENAME TO tasks;
CREATE INDEX tasks_team ON tasks(team_id); PRAGMA user_version=5;''');
    old.close();
    store = Store('${directory.path}/test.sqlite');
    expect(store.tasks(team).single['member_id'], member);
    expect(store.tasks(team).single['notes'], 'Keep these notes');
    expect(store.setting('tactical_sync_$team'), '{"outbox":{"op":{}}}');
    expect(
      directory.listSync().any((f) => f.path.contains('.pre-v6-')),
      isTrue,
    );
    store.transitionTask(task, 'in_progress');
    expect(store.tasks(team).single['status'], 'in_progress');
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
