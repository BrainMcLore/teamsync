import 'dart:convert';

import 'account_roster.dart';
import 'store.dart';

/// A preparation batch is committed entirely, or not at all.
class PreparationPlan {
  final Store store;
  final String team, map;
  final String? binding, identity;
  PreparationPlan(this.store, this.team, this.map)
    : binding = store.setting('account_team_$team'),
      identity = store.setting('account_identity');
  static const types = ['tactic', 'dry_run', 'execute', 'retake'];
  List<String> create({
    required Set<String> strategies,
    required Set<String> members,
    required String type,
    required DateTime dueAt,
    required String criteria,
    Map<String, Set<String>>? assignments,
  }) {
    if (binding == null ||
        identity == null ||
        store.setting('account_signed_out') == '1' ||
        binding != store.setting('account_team_$team') ||
        identity != store.setting('account_identity')) {
      throw DomainError('syncAccountMismatch');
    }
    final account = jsonDecode(binding!) as Map;
    if (identity != jsonEncode([account['server'], account['user']])) {
      throw DomainError('syncAccountMismatch');
    }
    if (!store.canEditTeam(team)) throw DomainError('readOnlyTeam');
    if (strategies.isEmpty ||
        members.isEmpty ||
        criteria.trim().isEmpty ||
        !types.contains(type)) {
      throw DomainError('invalidText');
    }
    if (strategies.length > 100 || members.length > 100) {
      throw DomainError('limit');
    }
    if (assignments != null &&
        (assignments.length != strategies.length ||
            assignments.keys.any((id) => !strategies.contains(id)))) {
      throw DomainError('invalidPlan');
    }
    final distribution = {
      for (final id in strategies) id: assignments?[id] ?? members,
    };
    if (distribution.values.any((ids) => ids.isEmpty)) {
      throw DomainError('invalidPlan');
    }
    if (distribution.values.any(
      (ids) => ids.any((id) => !members.contains(id)),
    )) {
      throw DomainError('crossTeam');
    }
    if (distribution.values.fold<int>(0, (sum, ids) => sum + ids.length) > 500) {
      throw DomainError('limit');
    }
    if (store.rows('SELECT id FROM maps WHERE id=? AND team_id=?', [
      map,
      team,
    ]).isEmpty) {
      throw DomainError('crossTeam');
    }
    final allowed = {
      for (final r in store.strategies(team).where((s) => s['map_id'] == map))
        r['id']: r,
    };
    final accounts = accountAssignableMembers(
      store,
      team,
    ).map((m) => m['id']).toSet();
    if (strategies.any((id) => !allowed.containsKey(id)) ||
        members.any((id) => !accounts.contains(id))) {
      throw DomainError('crossTeam');
    }
    store.validateTaskPlan(type, dueAt, criteria);
    return store.transaction(
      () => [
        for (final strategy in strategies)
          for (final member in distribution[strategy]!)
            store.createTask(
              team,
              allowed[strategy]!['title'] as String,
              '',
              member: member,
              strategyId: strategy,
              taskType: type,
              dueAt: dueAt,
              criteria: criteria,
            ),
      ],
    );
  }
}
