import 'dart:convert';

import 'account.dart';
import 'account_scope.dart';
import 'store.dart';

class TeamSchedule extends TeamAccountScope {
  final AccountClient Function(String)? clientFactory;
  TeamSchedule(super.store, super.team, {this.clientFactory});
  String get key =>
      'schedule_${jsonEncode([binding['server'], binding['user'], binding['team']])}';
  String get path => '/api/v1/teams/${binding['team']}/events';
  bool get manager => [
    'owner',
    'captain',
    'coach',
  ].contains(store.setting('shared_role_$team'));
  bool get viewer => store.setting('shared_role_$team') == 'viewer';
  List<Map<String, dynamic>> read(String suffix) {
    assertActive();
    return (jsonDecode(store.setting('$key$suffix') ?? '[]') as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  void save(String suffix, List<Map<String, dynamic>> rows) {
    assertActive();
    store.setSetting('$key$suffix', jsonEncode(rows));
  }

  List<Map<String, dynamic>> cached() => read('_events');
  List<Map<String, dynamic>> pending() => read('_queue');
  List<Map<String, dynamic>> cachedPeople(String event) =>
      read('_people_$event');
  List<Map<String, dynamic>> cachedHistory(String event) =>
      read('_history_$event');
  Future<AccountClient> client() async {
    assertActive();
    final api =
        clientFactory?.call(binding['server'] as String) ??
        AccountClient(binding['server'] as String);
    await api.loadToken();
    assertActive();
    return api;
  }

  void merge(
    String suffix,
    List<Map<String, dynamic>> rows,
    String identity,
    int limit,
  ) {
    final unique = <Object?, Map<String, dynamic>>{
      for (final row in [...rows, ...read(suffix)]) row[identity]: row,
    };
    for (final row in rows) {
      final old = unique[row[identity]];
      if (old != null &&
          old['version'] is num &&
          row['version'] is num &&
          (old['version'] as num) > (row['version'] as num)) {
        continue;
      }
      unique[row[identity]] = row;
    }
    save(suffix, unique.values.take(limit).toList());
  }

  void enqueue(
    String event,
    Map<String, dynamic> body,
    String label, {
    String? target,
  }) {
    assertActive();
    if (viewer ||
        target == null && !manager ||
        target != null && body['attendance'] != null && !manager ||
        target != null && body['rsvp'] != null && target != binding['user']) {
      throw DomainError('forbidden');
    }
    final queue = pending();
    if (queue.length >= 50) throw DomainError('limit');
    queue.add({
      'event': event,
      'target': target,
      'label': label,
      'body': {...body, 'operation_id': Store.uuid.v4()},
    });
    save('_queue', queue);
  }

  void discard(String operation) {
    save(
      '_queue',
      pending()
          .where((r) => (r['body'] as Map)['operation_id'] != operation)
          .toList(),
    );
  }

  Future<void> flush() async {
    final queue = pending();
    if (queue.isEmpty) return;
    final api = await client();
    for (final operation in queue) {
      if (operation['error'] != null) continue;
      assertActive();
      final id = (operation['body'] as Map)['operation_id'];
      final event = operation['event'] as String,
          target = operation['target'] as String?;
      try {
        final result = await api.request(
          'POST',
          '$path/$event${target == null ? '' : '/participation/$target'}',
          body: Map<String, dynamic>.from(operation['body'] as Map),
        );
        assertActive();
        if (target == null) {
          merge('_events', [result], 'id', 200);
        } else {
          final old = cachedPeople(event)
              .where((r) => r['user_id'] == target)
              .firstOrNull;
          if (old != null) {
            merge(
              '_people_$event',
              [
                {...old, ...result},
              ],
              'user_id',
              500,
            );
          }
        }
        discard(id as String);
      } on DomainError catch (error) {
        assertActive();
        if (![
          'version_conflict',
          'operation_conflict',
          'forbidden',
          'not_found',
          'event_cancelled',
          'event_not_started',
          'attendance_time_locked',
          'attendance_reason_required',
          'limit',
          'invalid_text',
          'validation_error',
          'invalid_link',
        ].contains(error.code)) {
          rethrow;
        }
        final current = pending();
        for (final row in current) {
          if ((row['body'] as Map)['operation_id'] == id) {
            row['error'] = error.code;
          }
        }
        save('_queue', current);
      }
    }
  }

  Future<({List<Map<String, dynamic>> items, int? next})> list(
    DateTime from,
    DateTime until, {
    int offset = 0,
  }) async {
    final api = await client();
    final query = Uri(
      queryParameters: {
        'from_at': from.toUtc().toIso8601String(),
        'until_at': until.toUtc().toIso8601String(),
        'offset': '$offset',
        'limit': '50',
      },
    ).query;
    final result = await api.request('GET', '$path?$query');
    assertActive();
    final rows = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    merge('_events', rows, 'id', 200);
    return (items: rows, next: result['next'] as int?);
  }

  Future<
    ({Map<String, dynamic> event, List<Map<String, dynamic>> people, int? next})
  >
  people(String event, {int offset = 0}) async {
    final api = await client();
    final result = await api.request(
      'GET',
      '$path/$event/participation?offset=$offset&limit=50',
    );
    assertActive();
    final row = Map<String, dynamic>.from(result['event'] as Map);
    final rows = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    merge('_events', [row], 'id', 200);
    merge('_people_$event', rows, 'user_id', 500);
    return (event: row, people: rows, next: result['next'] as int?);
  }

  Future<List<Map<String, dynamic>>> history(
    String event, {
    int offset = 0,
  }) async {
    final api = await client();
    final result = await api.request(
      'GET',
      '$path/$event/history?offset=$offset&limit=50',
    );
    assertActive();
    final rows = (result['items'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    merge('_history_$event', rows, 'id', 200);
    return rows;
  }
}
