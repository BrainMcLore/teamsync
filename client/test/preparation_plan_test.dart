import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/preparation_plan.dart';
import 'package:teamsync/data/store.dart';

class FailingStore extends Store {
  bool fail = false;
  int writes = 0;
  FailingStore() : super(':memory:');
  @override
  String createTask(
    String team,
    String title,
    String notes, {
    String? member,
    String? strategyId,
    String taskType = 'general',
    DateTime? dueAt,
    String criteria = '',
  }) {
    if (fail && ++writes == 2) throw DomainError('injected_failure');
    return super.createTask(
      team,
      title,
      notes,
      member: member,
      strategyId: strategyId,
      taskType: taskType,
      dueAt: dueAt,
      criteria: criteria,
    );
  }
}

class Fixture {
  final Store store;
  final String remote = Store.uuid.v4();
  late final String team, map;
  late final List<String> strategies, members;
  Fixture(this.store) {
    team = saveAccountRoster(
      store,
      'https://fixture.example',
      'alice',
      {'id': remote, 'name': 'Team', 'role': 'owner'},
      [
        {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
        {'id': 'bob', 'name': 'Bob', 'role': 'player'},
      ],
    );
    map = store.addMap(team, 'Mirage');
    strategies = [
      store.createStrategy(map, 'A execute', 'T'),
      store.createStrategy(map, 'B retake', 'CT'),
    ];
    members = accountAssignableMembers(
      store,
      team,
    ).map((r) => r['id'] as String).toList();
  }
  PreparationPlan get plan => PreparationPlan(store, team, map);
  List<String> create(
    PreparationPlan plan, {
    Map<String, Set<String>>? assignments,
  }) => plan.create(
    strategies: strategies.toSet(),
    members: members.toSet(),
    type: 'dry_run',
    dueAt: DateTime.parse('2026-11-02T18:30:00+02:00'),
    criteria: 'Check timings together',
    assignments: assignments,
  );
}

void main() {
  test(
    'map preparation creates personal plans with per-tactic distribution',
    () {
      final store = Store(':memory:');
      addTearDown(store.close);
      final f = Fixture(store);
      final ids = f.create(
        f.plan,
        assignments: {
          f.strategies[0]: f.members.toSet(),
          f.strategies[1]: {f.members[1]},
        },
      );
      expect(ids, hasLength(3));
      final rows = store.tasks(f.team);
      expect(
        rows.map((r) => '${r['strategy_id']}/${r['member_id']}').toSet(),
        hasLength(3),
      );
      for (final row in rows) {
        expect(row['task_type'], 'dry_run');
        expect(row['status'], 'todo');
        expect(row['criteria'], 'Check timings together');
        expect(
          DateTime.parse(row['due_at'] as String),
          DateTime.utc(2026, 11, 2, 16, 30),
        );
      }
    },
  );
  test('a failed preparation batch rolls back every generated assignment', () {
    final store = FailingStore();
    addTearDown(store.close);
    final f = Fixture(store);
    store.fail = true;
    expect(() => f.create(f.plan), throwsA(isA<DomainError>()));
    expect(store.tasks(f.team), isEmpty);
    expect(store.strategies(f.team), hasLength(2));
    expect(store.members(f.team), hasLength(2));
  });
  test(
    'preparation rejects a stale account, changed roster and foreign tactics',
    () {
      final store = Store(':memory:');
      addTearDown(store.close);
      final f = Fixture(store), plan = f.plan;
      rememberAccountIdentity(store, 'https://fixture.example', 'bob');
      expect(
        () => f.create(plan),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'syncAccountMismatch',
          ),
        ),
      );
      rememberAccountIdentity(store, 'https://fixture.example', 'alice');
      final other = store.addMap(f.team, 'Nuke'),
          foreign = store.createStrategy(other, 'Different map', 'CT');
      expect(
        () => plan.create(
          strategies: {foreign},
          members: f.members.toSet(),
          type: 'retake',
          dueAt: DateTime.utc(2026, 11, 2),
          criteria: 'Check positions',
        ),
        throwsA(isA<DomainError>()),
      );
      store.setSetting('shared_role_${f.team}', 'player');
      expect(
        () => f.create(plan),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'readOnlyTeam'),
        ),
      );
      saveAccountRoster(
        store,
        'https://fixture.example',
        'alice',
        {'id': f.remote, 'name': 'Team', 'role': 'owner'},
        [
          {'id': 'alice', 'name': 'Alice', 'role': 'owner'},
        ],
        select: false,
      );
      expect(
        () => f.create(plan),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 'crossTeam')),
      );
      expect(store.tasks(f.team), isEmpty);
    },
  );
}
