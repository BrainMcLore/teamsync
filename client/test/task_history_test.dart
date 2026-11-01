import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/task_history.dart';

class HistoryAccount extends AccountClient {
  final Completer<Map<String, dynamic>> response;
  HistoryAccount(this.response) : super('https://fixture.example');
  @override
  Future<void> loadToken() async {
    token = 'fixture';
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorize = true,
  }) => response.future;
}

void main() {
  test('task history is cached offline and a switched account cannot receive an old response', () async {
    final store = Store(':memory:');
    addTearDown(store.close);
    final team = store.createTeam('History'),
        task = store.createTask(team, 'Review', '');
    final binding = {
      'server': 'https://fixture.example',
      'team': 'remote-team',
      'user': 'alice',
    };
    store.setSetting('account_team_$team', jsonEncode(binding));
    store.setSetting(
      'account_identity',
      jsonEncode([binding['server'], 'alice']),
    );
    store.setSetting(
      'tactical_sync_$team',
      jsonEncode({
        'entries': {
          'task:$task': {'remote': 'remote-task', 'version': 1},
        },
      }),
    );
    final first = Completer<Map<String, dynamic>>();
    final history = TaskHistory(
      store,
      team,
      task,
      clientFactory: (_) => HistoryAccount(first),
    );
    final fetch = history.page(0);
    first.complete({
      'items': [
        {
          'version': 1,
          'payload': {
            'status': 'submitted',
            'task_review_reason': 'Repeat flash',
          },
          'author_id': 'alice',
          'created': 123,
        },
      ],
    });
    expect(await fetch, hasLength(1));
    expect(
      history.cached().single['payload']['task_review_reason'],
      'Repeat flash',
    );
    final delayed = Completer<Map<String, dynamic>>();
    final old = TaskHistory(
      store,
      team,
      task,
      clientFactory: (_) => HistoryAccount(delayed),
    );
    final pending = old.page(0);
    await Future<void>.delayed(Duration.zero);
    store.setSetting(
      'account_team_$team',
      jsonEncode({...binding, 'user': 'bob'}),
    );
    store.setSetting(
      'account_identity',
      jsonEncode([binding['server'], 'bob']),
    );
    delayed.complete({
      'items': [
        {'version': 2},
      ],
    });
    await expectLater(pending, throwsA(isA<DomainError>()));
    expect(() => history.cached(), throwsA(isA<DomainError>()));
    final bob = TaskHistory(store, team, task);
    expect(bob.cached(), isEmpty);
    store.setSetting('account_team_$team', jsonEncode(binding));
    store.setSetting(
      'account_identity',
      jsonEncode([binding['server'], 'alice']),
    );
    expect(history.cached().single['version'], 1);
  });
}
