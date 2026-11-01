import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/task_evidence.dart';
import 'package:teamsync/ui/task_evidence_dialog.dart';
import 'package:teamsync/l10n/app_localizations.dart';

class EvidenceApi extends AccountClient {
  EvidenceApi() : super('https://fixture.example');
  final receipts = <String, Map<String, dynamic>>{};
  final blobs = <String, Uint8List>{};
  bool offline = false, loseAck = false;
  int uploads = 0;
  Completer<Uint8List>? held;
  final started = Completer<void>();
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
    return {'items': receipts.values.toList(), 'next': null};
  }

  @override
  Future<Uint8List> media(
    String method,
    String path, {
    Uint8List? bytes,
  }) async {
    if (offline) throw DomainError('offline');
    if (held != null) {
      if (!started.isCompleted) started.complete();
      return held!.future;
    }
    final id = path.split('/').last;
    if (method == 'GET') return blobs[id]!;
    uploads++;
    blobs.putIfAbsent(id, () => bytes!);
    final result = receipts.putIfAbsent(
      id,
      () => {
        'id': id,
        'media_id': sha256.convert(bytes!).toString(),
        'author_id': 'alice',
        'author_name': 'Alice',
        'mime': 'image/png',
        'size': bytes.length,
        'created': 123,
        'task_version': 1,
      },
    );
    if (loseAck) {
      loseAck = false;
      throw DomainError('offline');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }
}

class OfflineEvidence extends TaskEvidence {
  OfflineEvidence(
    super.store,
    super.team,
    super.task,
    super.files, {
    super.clientFactory,
  });
  @override
  Future<void> flush() async {
    throw DomainError('offline');
  }
}

(Store, String, String) fixture() {
  final s = Store(':memory:');
  final team = s.createTeam('Evidence');
  final task = s.createTask(team, 'Practice', '');
  s.setSetting(
    'account_team_$team',
    jsonEncode({
      'server': 'https://fixture.example',
      'team': 'remote-team',
      'user': 'alice',
    }),
  );
  s.setSetting(
    'account_identity',
    jsonEncode(['https://fixture.example', 'alice']),
  );
  s.setSetting('shared_role_$team', 'owner');
  s.setSetting(
    'tactical_sync_$team',
    jsonEncode({
      'entries': {
        'task:$task': {'remote': 'remote-task', 'version': 1},
      },
    }),
  );
  return (s, team, task);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'proof retry survives reopening, verifies hashes and opens offline',
    () async {
      final (s, team, task) = fixture();
      addTearDown(s.close);
      final root = Directory.systemTemp.createTempSync('proof_');
      addTearDown(() => root.deleteSync(recursive: true));
      final api = EvidenceApi()..loseAck = true;
      var evidence = TaskEvidence(
        s,
        team,
        task,
        LocalFiles(root),
        clientFactory: (_) => api,
      );
      await evidence.enqueueFile('test/fixtures/radar.png');
      final id = evidence.pending().single['id'];
      await expectLater(evidence.flush(), throwsA(isA<DomainError>()));
      evidence = TaskEvidence(
        s,
        team,
        task,
        LocalFiles(root),
        clientFactory: (_) => api,
      );
      expect(evidence.pending().single['id'], id);
      await evidence.flush();
      expect(api.receipts, hasLength(1));
      expect(evidence.pending(), isEmpty);
      final row = evidence.cached().single;
      final local = await evidence.openFile(row);
      api.offline = true;
      expect((await evidence.openFile(row)).path, local.path);
      await local.writeAsBytes([0, 1, 2]);
      await expectLater(evidence.openFile(row), throwsA(isA<DomainError>()));
      api.offline = false;
      expect(
        await (await evidence.openFile(row)).readAsBytes(),
        File('test/fixtures/radar.png').readAsBytesSync(),
      );
      s.setSetting('shared_role_$team', 'player');
      await expectLater(
        evidence.enqueueFile('test/fixtures/radar.png'),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'changed queued bytes cannot upload, and local retry can be removed',
    () async {
      final (s, team, task) = fixture();
      addTearDown(s.close);
      final root = Directory.systemTemp.createTempSync('proof_');
      addTearDown(() => root.deleteSync(recursive: true));
      final api = EvidenceApi();
      final evidence = TaskEvidence(
        s,
        team,
        task,
        LocalFiles(root),
        clientFactory: (_) => api,
      );
      await evidence.enqueueFile('test/fixtures/own_clip.mp4');
      final row = evidence.pending().single;
      await File(row['path'] as String).writeAsBytes([1, 2]);
      await expectLater(evidence.flush(), throwsA(isA<DomainError>()));
      expect(api.uploads, 0);
      expect(evidence.pending(), hasLength(1));
      evidence.discardPending(row['id'] as String);
      expect(evidence.pending(), isEmpty);
      await expectLater(
        evidence.enqueueFile('pubspec.yaml'),
        throwsA(isA<DomainError>()),
      );
    },
  );
  test(
    'account changes cannot acknowledge a delayed upload or expose its cache',
    () async {
      final (s, team, task) = fixture();
      addTearDown(s.close);
      final root = Directory.systemTemp.createTempSync('proof_');
      addTearDown(() => root.deleteSync(recursive: true));
      final api = EvidenceApi()..held = Completer<Uint8List>();
      final evidence = TaskEvidence(
        s,
        team,
        task,
        LocalFiles(root),
        clientFactory: (_) => api,
      );
      await evidence.enqueueFile('test/fixtures/radar.png');
      final key = evidence.queueKey;
      final upload = evidence.flush();
      await api.started.future;
      s.setSetting(
        'account_identity',
        jsonEncode(['https://fixture.example', 'bob']),
      );
      api.held!.complete(Uint8List.fromList(utf8.encode('{}')));
      await expectLater(upload, throwsA(isA<DomainError>()));
      expect(jsonDecode(s.setting(key)!) as List, hasLength(1));
      expect(s.setting(evidence.cacheKey), isNull);
      expect(() => evidence.pending(), throwsA(isA<DomainError>()));
    },
  );
  for (final lang in ['ru', 'en']) {
    testWidgets('evidence fits 320px offline and viewers cannot attach $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (s, team, task) = fixture();
      addTearDown(s.close);
      final root = Directory.systemTemp.createTempSync('proof_');
      addTearDown(() => root.deleteSync(recursive: true));
      final api = EvidenceApi()..offline = true;
      final evidence = OfflineEvidence(
        s,
        team,
        task,
        LocalFiles(root),
        clientFactory: (_) => api,
      );
      await tester.runAsync(
        () => evidence.enqueueFile('test/fixtures/radar.png'),
      );
      s.setSetting('shared_role_$team', 'viewer');
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TaskEvidenceDialog(evidence: evidence)),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(TaskEvidenceDialog)),
      );
      await tester.scrollUntilVisible(
        find.text(l.evidenceImageType),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l.evidenceImageType), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
