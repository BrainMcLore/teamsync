import 'dart:convert';

import 'account.dart';
import 'store.dart';

/// History is scoped to the same account binding as the task's sync queue.
class TaskHistory {
  final Store store;
  final String team, task;
  final AccountClient Function(String)? clientFactory;
  final Map binding;
  TaskHistory(this.store, this.team, this.task, {this.clientFactory})
    : binding = jsonDecode(store.setting('account_team_$team')!) as Map;
  void assertActive() {
    if (store.setting('account_team_$team') != jsonEncode(binding) ||
        store.setting('account_signed_out') == '1' ||
        store.setting('account_identity') !=
            jsonEncode([binding['server'], binding['user']])) {
      throw DomainError('syncAccountMismatch');
    }
  }

  String get cacheKey =>
      'task_history_${jsonEncode([binding['server'], binding['user'], binding['team'], task])}';
  List<Map<String, dynamic>> cached() {
    assertActive();
    return (jsonDecode(store.setting(cacheKey) ?? '[]') as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> page(int offset) async {
    assertActive();
    final state =
        jsonDecode(store.setting('tactical_sync_$team') ?? '{}') as Map;
    final entry = (state['entries'] as Map? ?? {})['task:$task'] as Map?;
    if (entry == null || entry['version'] == 0) return [];
    final api =
        clientFactory?.call(binding['server'] as String) ??
        AccountClient(binding['server'] as String);
    await api.loadToken();
    assertActive();
    final result = await api.request(
      'GET',
      '/api/v1/teams/${binding['team']}/documents/${entry['remote']}/versions?offset=$offset&limit=50',
    );
    assertActive();
    final rows = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    // Keep a bounded offline snapshot. Pagination is ordered newest first.
    final previous = offset == 0 ? <Map<String, dynamic>>[] : cached();
    final unique = <Object?, Map<String, dynamic>>{
      for (final row in [...previous, ...rows]) row['version']: row,
    };
    final saved = unique.values.toList()
      ..sort((a, b) => (b['version'] as int).compareTo(a['version'] as int));
    store.setSetting(cacheKey, jsonEncode(saved.take(500).toList()));
    return rows;
  }
}
