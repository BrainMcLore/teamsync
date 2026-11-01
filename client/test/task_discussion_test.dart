import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/task_discussion.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/task_discussion_dialog.dart';

class DiscussionApi extends AccountClient {
  DiscussionApi() : super('https://fixture.example');
  final saved = <String, Map<String, dynamic>>{};
  bool loseAck = false, offline = false;
  Completer<Map<String, dynamic>>? held;
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
  }) async {
    if (offline) throw DomainError('offline');
    if (held != null) return held!.future;
    if (method == 'POST') {
      final value = saved.putIfAbsent(
        body!['id'] as String,
        () => {
          ...body,
          'author_id': 'alice',
          'author_name': 'Alice',
          'created': 123,
        },
      );
      if (loseAck) {
        loseAck = false;
        throw DomainError('offline');
      }
      return value;
    }
    return {'items': saved.values.toList(), 'next': null};
  }
}

(Store, String, String) fixture() {
  final store = Store(':memory:'), team = Store.uuid.v4();
  store.createTeam('unused');
  final task = 'task';
  store.setSetting(
    'account_team_$team',
    jsonEncode({
      'server': 'https://fixture.example',
      'team': 'remote-team',
      'user': 'alice',
    }),
  );
  store.setSetting(
    'account_identity',
    jsonEncode(['https://fixture.example', 'alice']),
  );
  store.setSetting(
    'tactical_sync_$team',
    jsonEncode({
      'entries': {
        'task:$task': {'version': 1, 'remote': 'remote-task'},
      },
    }),
  );
  return (store, team, task);
}

void main() {
  test('offline outbox survives reopening and lost acknowledgements without duplicate comments', () async {
    final (store, team, task) = fixture();
    addTearDown(store.close);
    final api = DiscussionApi()..loseAck = true;
    var discussion = TaskDiscussion(
      store,
      team,
      task,
      clientFactory: (_) => api,
    );
    discussion.enqueue('  Timing correction  ');
    final id = discussion.pending().single['id'];
    await expectLater(discussion.flush(), throwsA(isA<DomainError>()));
    discussion = TaskDiscussion(store, team, task, clientFactory: (_) => api);
    expect(discussion.pending().single['id'], id);
    await discussion.flush();
    expect(api.saved.length, 1);
    expect(discussion.pending(), isEmpty);
    expect(discussion.cached().single['text'], 'Timing correction');
    await discussion.comments();
    api.offline = true;
    await expectLater(discussion.comments(), throwsA(isA<DomainError>()));
    expect(discussion.cached().single['author_name'], 'Alice');
    store.setSetting('shared_role_$team', 'viewer');
    expect(() => discussion.enqueue('No'), throwsA(isA<DomainError>()));
  });
  test('late response cannot write cache or remove an old account outbox after identity changes', () async {
    final (store, team, task) = fixture();
    addTearDown(store.close);
    final api = DiscussionApi()..held = Completer<Map<String, dynamic>>();
    final discussion = TaskDiscussion(
      store,
      team,
      task,
      clientFactory: (_) => api,
    );
    discussion.enqueue('Keep on Alice account');
    final key = discussion.queueKey;
    final pending = discussion.flush();
    await Future<void>.delayed(Duration.zero);
    store.setSetting(
      'account_identity',
      jsonEncode(['https://fixture.example', 'bob']),
    );
    api.held!.complete({'id': 'id', 'text': 'Wrong account', 'created': 123});
    await expectLater(pending, throwsA(isA<DomainError>()));
    expect(jsonDecode(store.setting(key)!) as List, hasLength(1));
    expect(store.setting(discussion.cacheKey), isNull);
    expect(() => discussion.cached(), throwsA(isA<DomainError>()));
    expect(() => discussion.pending(), throwsA(isA<DomainError>()));
  });
  test(
    'refresh retains older loaded comments within a bounded offline cache',
    () async {
      final (store, team, task) = fixture();
      addTearDown(store.close);
      final api = DiscussionApi();
      final discussion = TaskDiscussion(
        store,
        team,
        task,
        clientFactory: (_) => api,
      );
      discussion.remember([
        for (var i = 0; i < 220; i++)
          {'id': 'old-$i', 'text': 'Old', 'created': i},
      ]);
      api.saved['new'] = {'id': 'new', 'text': 'New', 'created': 300};
      await discussion.comments();
      expect(discussion.cached(), hasLength(200));
      expect(discussion.cached().first['id'], 'new');
      expect(discussion.cached().any((r) => r['id'] == 'old-219'), isTrue);
    },
  );
  for (final lang in ['ru', 'en']) {
    testWidgets('discussion fits 320px with offline pending comments $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (store, team, task) = fixture();
      addTearDown(store.close);
      final api = DiscussionApi()..offline = true;
      final discussion = TaskDiscussion(
        store,
        team,
        task,
        clientFactory: (_) => api,
      );
      discussion.enqueue('Saved message');
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TaskDiscussionDialog(discussion: discussion)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
