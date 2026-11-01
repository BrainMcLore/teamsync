import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/tactical_sync.dart';
import 'package:teamsync/data/utilities.dart';
import 'package:teamsync/ui/workspace.dart';
import 'package:teamsync/ui/editor.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/l10n/app_localizations.dart';

class SharedFixture {
  final documents = <String, Map<String, dynamic>>{},
      operations = <String, Map<String, dynamic>>{};
  final images = <String, Uint8List>{};
  final roles = <String, String>{'alice': 'owner', 'bob': 'coach'};
  bool loseAck = false;
  void Function(String user, String method)? checkMedia;
}

class SyncAccount extends AccountClient {
  final SharedFixture server;
  final String user;
  SyncAccount(this.server, this.user) : super('https://fixture.example');
  @override
  Future<void> loadToken() async {
    token = 'fixture';
  }

  @override
  Future<Uint8List> media(
    String method,
    String path, {
    Uint8List? bytes,
  }) async {
    server.checkMedia?.call(user, method);
    final id = path.split('/').last;
    if (method == 'PUT') {
      server.images[id] = bytes!;
      return Uint8List(0);
    }
    return server.images[id]!;
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorize = true,
  }) async {
    if (path == '/api/v1/me') return {'id': user};
    if (path.contains('/members?')) {
      if (!server.roles.containsKey(user)) throw DomainError('not_found');
      return {
        'items': [
          for (final r in server.roles.entries)
            {'id': r.key, 'role': r.value, 'name': r.key},
        ],
      };
    }
    if (method == 'GET' && path.contains('/documents?')) {
      final uri = Uri.parse(path),
          offset = int.parse(Uri.parse(path).queryParameters['offset']!);
      final rows = server.documents.values.toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      return {
        'items': rows
            .skip(offset)
            .take(int.parse(uri.queryParameters['limit']!))
            .toList(),
      };
    }
    if (method == 'POST' && path.endsWith('/documents')) {
      if (!['owner', 'coach', 'captain'].contains(server.roles[user]) &&
          !(server.roles[user] == 'player' &&
              body?['kind'] == 'task' &&
              (body?['payload'] as Map)['assignee_user_id'] == user &&
              (body?['payload'] as Map)['status'] == 'submitted')) {
        throw DomainError('forbidden');
      }
      final op = body!['operation_id'] as String;
      if (server.operations.containsKey(op)) return server.operations[op]!;
      final id = body['document_id'] as String, old = server.documents[id];
      if ((old?['version'] ?? 0) != body['expected_version']) {
        throw DomainError('version_conflict');
      }
      final version = (body['expected_version'] as int) + 1;
      server.documents[id] = {
        'id': id,
        'kind': body['kind'],
        'version': version,
        'payload': jsonDecode(jsonEncode(body['payload'])),
      };
      final response = {'id': id, 'version': version};
      server.operations[op] = response;
      if (server.loseAck) {
        server.loseAck = false;
        throw const SocketException('simulated lost acknowledgement');
      }
      return response;
    }
    throw StateError('$method $path');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'training assignments sync with stable account and tactic links',
    () async {
      final root = Directory.systemTemp.createTempSync('teamsync_training_');
      final a = Store(':memory:'),
          b = Store(':memory:'),
          server = SharedFixture();
      addTearDown(() {
        a.close();
        b.close();
        root.deleteSync(recursive: true);
      });
      final team = {'id': Store.uuid.v4(), 'name': 'Training', 'role': 'owner'};
      final roster = [
        {'id': 'alice', 'name': 'Captain', 'role': 'owner'},
        {'id': 'bob', 'name': 'Player', 'role': 'coach'},
      ];
      final ta = saveAccountRoster(
        a,
        'https://fixture.example',
        'alice',
        team,
        roster,
      );
      final tb = saveAccountRoster(
        b,
        'https://fixture.example',
        'bob',
        team,
        roster,
      );
      server.checkMedia = (user, method) {
        if (user == 'bob') expect(b.applyingSync, isFalse);
      };
      final map = a.addMap(ta, 'Mirage');

      final tactic = a.createStrategy(map, 'Выход B', 'T');
      UtilityLibrary(a)
          .save(ta, map, 'Окно smoke', 'T', 'Сохранённая инструкция', {
            'grenade': 'smoke',
            'strategy_ids': [tactic],
            'source_url': 'https://cs2tricks.com/lineup/window',
            'screenshot_paths': [File('test/fixtures/radar.png').absolute.path],
            'author': 'Source author',
          });
      final task = a.createTask(
        ta,
        'Выучить выход',
        'Роль и тайминги',
        member:
            a.members(ta).singleWhere((m) => m['name'] == 'Player')['id']
                as String,
        strategyId: tactic,
      );
      final sa = TacticalSync(
        a,
        LocalFiles(root),
        clientFactory: (_) => SyncAccount(server, 'alice'),
      );
      final sb = TacticalSync(
        b,
        LocalFiles(root),
        clientFactory: (_) => SyncAccount(server, 'bob'),
      );
      await sa.run(ta, conflictLabel: 'Conflict');
      await sb.run(tb, conflictLabel: 'Conflict');
      expect(
        UtilityLibrary(b).list(tb).single['notes'],
        'Сохранённая инструкция',
      );
      expect(
        UtilityLibrary(b).list(tb).single['map_id'],
        b.maps(tb).single['id'],
      );
      expect(
        jsonDecode(
          UtilityLibrary(b).list(tb).single['details'] as String,
        )['strategy_ids'],
        [b.strategies(tb).single['id']],
      );
      final screenshot =
          (jsonDecode(
                        UtilityLibrary(b).list(tb).single['details'] as String,
                      )['screenshot_paths']
                      as List)
                  .single
              as String;
      expect(
        await File(screenshot).readAsBytes(),
        await File('test/fixtures/radar.png').readAsBytes(),
      );
      final received = b.tasks(tb).single;
      expect(received['title'], 'Выучить выход');
      expect(received['strategy_id'], b.strategies(tb).single['id']);
      expect(
        received['member_id'],
        b.members(tb).singleWhere((m) => m['name'] == 'bob')['id'],
      );
      server.roles['bob'] = 'player';
      await sb.run(tb, conflictLabel: 'Conflict');
      b.transitionTask(received['id'] as String, 'submitted');
      await sb.run(tb, conflictLabel: 'Conflict');
      await sa.run(ta, conflictLabel: 'Conflict');
      expect(a.tasks(ta).single['status'], 'submitted');
      a.transitionTask(task, 'approved');
      await sa.run(ta, conflictLabel: 'Conflict');
      await sb.run(tb, conflictLabel: 'Conflict');
      expect(b.tasks(tb).single['status'], 'approved');
      expect(
        server.documents.values.where((d) => d['kind'] == 'task'),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'open read-only tactic receives teammate changes without reopening',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('teamsync_live_editor_');
      final a = Store(':memory:'),
          b = Store(':memory:'),
          server = SharedFixture();
      server.roles['bob'] = 'player';
      final team = {'id': Store.uuid.v4(), 'name': 'Shared', 'role': 'owner'};
      final ta = saveAccountRoster(
            a,
            'https://fixture.example',
            'alice',
            team,
            [],
          ),
          tb = saveAccountRoster(b, 'https://fixture.example', 'bob', {
            ...team,
            'role': 'player',
          }, []);
      final map = a.addMap(ta, 'Mirage'),
          tactic = a.createStrategy(map, 'Live tactic', 'T');
      a.saveStrategy(tactic, 'first live', [], 1);
      final sa = TacticalSync(
            a,
            LocalFiles(root),
            clientFactory: (_) => SyncAccount(server, 'alice'),
          ),
          sb = TacticalSync(
            b,
            LocalFiles(root),
            clientFactory: (_) => SyncAccount(server, 'bob'),
          );
      await sa.run(ta, conflictLabel: 'Conflict copy');
      await sb.run(tb, conflictLabel: 'Conflict copy');
      final id = b.strategies(tb).single['id'] as String;
      await tester.pumpWidget(
        MaterialApp(
          theme: workspaceTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StrategyEditor(
            store: b,
            files: LocalFiles(root),
            id: id,
            onTask: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget<TextField>(find.byType(TextField))).readOnly,
        isTrue,
      );
      a.saveStrategy(
        tactic,
        'updated live',
        [],
        a.strategy(tactic)['version'] as int,
      );
      await sa.run(ta, conflictLabel: 'Conflict copy');
      await sb.run(tb, conflictLabel: 'Conflict copy');
      await tester.pumpAndSettle();
      expect(
        (tester.widget<TextField>(find.byType(TextField))).controller!.text,
        'updated live',
      );
      expect(b.editingStrategies.contains(id), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      a.close();
      b.close();
      root.deleteSync(recursive: true);
    },
  );
  for (final language in ['ru', 'en']) {
    testWidgets('shared team sync indicator fits 320px $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('teamsync_shared_ui_');
      final store = Store(':memory:');
      final server = SharedFixture();
      final team = {
        'id': Store.uuid.v4(),
        'name': 'Shared team',
        'role': 'owner',
      };
      final local = saveAccountRoster(
        store,
        'https://fixture.example',
        'alice',
        team,
        [],
      );
      store.addMap(local, 'Mirage');
      final files = LocalFiles(root),
          sync = TacticalSync(
            store,
            LocalFiles(root),
            clientFactory: (_) => SyncAccount(server, 'alice'),
          );
      await tester.pumpWidget(
        MaterialApp(
          theme: workspaceTheme(),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Workspace(
            store: store,
            files: files,
            onLocale: (_) {},
            sync: sync,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      store.close();
      root.deleteSync(recursive: true);
    });
  }
  test('two accounts share drawings, preserve conflicts and retry a durable outbox', () async {
    final root = Directory.systemTemp.createTempSync('teamsync_shared_');
    addTearDown(() => root.deleteSync(recursive: true));
    final server = SharedFixture(),
        team = {'id': Store.uuid.v4(), 'name': 'Five', 'role': 'owner'};
    var a = Store('${root.path}/a.sqlite');
    final b = Store(':memory:');
    addTearDown(b.close);
    addTearDown(() => a.close());
    final ta = saveAccountRoster(
      a,
      'https://fixture.example',
      'alice',
      team,
      [],
    );
    final tb = saveAccountRoster(b, 'https://fixture.example', 'bob', {
      ...team,
      'role': 'coach',
    }, []);
    final map = a.addMap(ta, 'Custom radar');
    a.mapImage(map, File('test/fixtures/radar.png').absolute.path);
    final tactic = a.createStrategy(map, 'A split', 'T');
    a.saveStrategy(
      tactic,
      'first',
      [
        {'type': 't', 'x': .2, 'y': .3},
      ],
      1,
      level: 'lower',
    );
    TacticalSync engine(Store s) => TacticalSync(
      s,
      LocalFiles(Directory('${root.path}/${s == a ? 'a' : 'b'}')),
      clientFactory: (_) => SyncAccount(server, s == a ? 'alice' : 'bob'),
    );
    var sa = engine(a);
    final sb = engine(b);
    await sa.run(ta, conflictLabel: 'Conflict copy');
    await sb.run(tb, conflictLabel: 'Conflict copy');
    expect(b.strategies(tb).single['notes'], 'first');
    expect(b.strategies(tb).single['level'], 'lower');
    expect(
      jsonDecode(b.strategies(tb).single['objects'] as String).single['type'],
      't',
    );
    expect(
      File(b.maps(tb).single['image_path'] as String).existsSync(),
      isTrue,
    );
    final bt = b.strategies(tb).single['id'] as String;
    b.saveStrategy(bt, 'coach change', [], b.strategy(bt)['version'] as int);
    await sb.run(tb, conflictLabel: 'Conflict copy');
    a.saveStrategy(
      tactic,
      'offline captain change',
      [],
      a.strategy(tactic)['version'] as int,
    );
    await sa.run(ta, conflictLabel: 'Conflict copy');
    await sb.run(tb, conflictLabel: 'Conflict copy');
    expect(a.strategies(ta).map((r) => r['notes']).toSet(), {
      'coach change',
      'offline captain change',
    });
    expect(b.strategies(tb).map((r) => r['notes']).toSet(), {
      'coach change',
      'offline captain change',
    });
    expect(sa.conflicts, 1);
    a.saveStrategy(
      tactic,
      'ack lost',
      [],
      a.strategy(tactic)['version'] as int,
    );
    server.loseAck = true;
    await expectLater(
      sa.run(ta, conflictLabel: 'Conflict copy'),
      throwsA(isA<SocketException>()),
    );
    final count = server.operations.length;
    a.close();
    a = Store('${root.path}/a.sqlite');
    sa = engine(a);
    await sa.run(ta, conflictLabel: 'Conflict copy');
    expect(server.operations.length, count);
    await sb.run(tb, conflictLabel: 'Conflict copy');
    expect(b.strategy(bt)['notes'], 'ack lost');
    a.editingStrategies.add(tactic);
    b.saveStrategy(
      bt,
      'fresh remote plan',
      [],
      b.strategy(bt)['version'] as int,
    );
    await sb.run(tb, conflictLabel: 'Conflict copy');
    a.saveStrategy(
      tactic,
      'local while editor open',
      [],
      a.strategy(tactic)['version'] as int,
    );
    await sa.run(ta, conflictLabel: 'Conflict copy');
    expect(a.strategy(tactic)['notes'], 'local while editor open');
    expect(sa.deferred, isTrue);
    a.editingStrategies.remove(tactic);
    await sa.run(ta, conflictLabel: 'Conflict copy');
    await sb.run(tb, conflictLabel: 'Conflict copy');
    expect(a.strategy(tactic)['notes'], 'fresh remote plan');
    expect(
      b.strategies(tb).map((r) => r['notes']),
      contains('local while editor open'),
    );
    server.roles['bob'] = 'player';
    await sb.run(tb, conflictLabel: 'Conflict copy');
    expect(
      () =>
          b.saveStrategy(bt, 'forbidden', [], b.strategy(bt)['version'] as int),
      throwsA(isA<DomainError>()),
    );
    server.roles.remove('bob');
    await expectLater(
      sb.run(tb, conflictLabel: 'Conflict copy'),
      throwsA(isA<DomainError>()),
    );
  });
}
