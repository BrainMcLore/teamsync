import 'dart:convert';

import 'account.dart';
import 'store.dart';
import 'task_history.dart';

/// Per-account cache and durable, explicitly retried comment outbox.
class TaskDiscussion extends TaskHistory {
  TaskDiscussion(super.store, super.team, super.task, {super.clientFactory});
  @override
  String get cacheKey => 'discussion_${super.cacheKey}';
  String get queueKey => '${cacheKey}_outbox';
  bool get canPost => store.setting('shared_role_$team') != 'viewer';
  List<Map<String, dynamic>> pending() {
    assertActive();
    return (jsonDecode(store.setting(queueKey) ?? '[]') as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  void enqueue(String text) {
    assertActive();
    if (!canPost) throw DomainError('forbidden');
    text = text.trim();
    if (text.isEmpty || text.length > 5000) throw DomainError('limit');
    final rows = pending();
    if (rows.length >= 50) throw DomainError('limit');
    rows.add({
      'id': Store.uuid.v4(),
      'text': text,
      'created': DateTime.now().millisecondsSinceEpoch / 1000,
    });
    store.setSetting(queueKey, jsonEncode(rows));
  }

  String get endpoint {
    assertActive();
    final state =
        jsonDecode(store.setting('tactical_sync_$team') ?? '{}') as Map;
    final entry = (state['entries'] as Map? ?? {})['task:$task'] as Map?;
    if (entry == null || entry['version'] == 0) {
      throw DomainError('discussionNotSynced');
    }
    return '/api/v1/teams/${binding['team']}/documents/${entry['remote']}/comments';
  }

  Future<AccountClient> client() async {
    assertActive();
    final api =
        clientFactory?.call(binding['server'] as String) ??
        AccountClient(binding['server'] as String);
    await api.loadToken();
    assertActive();
    return api;
  }

  void remember(List<Map<String, dynamic>> rows, {bool reset = false}) {
    assertActive();
    final unique = <Object?, Map<String, dynamic>>{
      for (final row in [
        ...(reset ? <Map<String, dynamic>>[] : cached()),
        ...rows,
      ])
        row['id']: row,
    };
    final sorted = unique.values.toList()
      ..sort((a, b) {
        final time = (b['created'] as num).compareTo(a['created'] as num);
        return time == 0
            ? (b['id'] as String).compareTo(a['id'] as String)
            : time;
      });
    store.setSetting(cacheKey, jsonEncode(sorted.take(200).toList()));
  }

  Future<void> flush() async {
    final rows = pending();
    if (rows.isEmpty) return;
    final path = endpoint, api = await client();
    for (final row in rows) {
      assertActive();
      final saved = await api.request(
        'POST',
        path,
        body: {'id': row['id'], 'text': row['text']},
      );
      assertActive();
      remember([saved]);
      store.setSetting(
        queueKey,
        jsonEncode(pending().where((r) => r['id'] != row['id']).toList()),
      );
    }
  }

  Future<({List<Map<String, dynamic>> items, String? next})> comments({
    String? before,
  }) async {
    final path = endpoint, api = await client();
    final result = await api.request(
      'GET',
      '$path?limit=50${before == null ? '' : '&before=${Uri.encodeQueryComponent(before)}'}',
    );
    assertActive();
    final rows = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    remember(rows);
    return (items: rows, next: result['next'] as String?);
  }
}
