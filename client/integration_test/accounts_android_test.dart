import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:teamsync/data/review_data.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/tactical_sync.dart';
import 'package:teamsync/data/account_roster.dart';
import 'package:teamsync/data/own_video.dart';
import 'package:teamsync/data/utilities.dart';
import 'package:teamsync/data/utility_skills.dart';
import 'package:teamsync/data/task_history.dart';
import 'package:teamsync/data/preparation_plan.dart';
import 'package:path_provider/path_provider.dart';

import '../test/fixtures/own_clip_data.dart';

import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/ui/account_page.dart';

class DeviceSession extends AccountClient {
  DeviceSession(AccountClient source) : super(source.base.toString()) {
    token = source.token;
  }
  @override
  Future<void> loadToken() async {}
}

Future<AccountClient> fixtureLogin(String subject) async {
  final api = AccountClient('http://127.0.0.1:8766');
  final verifier = base64UrlEncode(
    List.generate(48, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');
  final start = await api.request(
    'POST',
    '/api/v1/auth/steam/start',
    body: {'redirect': 'teamsync://auth/callback', 'challenge': challenge},
    authorize: false,
  );
  final url = Uri.parse(start['url'] as String);
  final callback = Uri.parse(url.queryParameters['openid.return_to']!);
  final http = HttpClient();
  late Uri redirect;
  try {
    final request = await http.getUrl(
      callback.replace(
        queryParameters: {
          ...callback.queryParameters,
          'fixture_subject': subject,
        },
      ),
    );
    request.followRedirects = false;
    final response = await request.close();
    expect(response.statusCode, 303);
    redirect = Uri.parse(response.headers.value('location')!);
    await response.drain<void>();
  } finally {
    http.close(force: true);
  }
  await api.storage.write(
    key: api.pendingKey,
    value: jsonEncode({
      'verifier': verifier,
      'expires': DateTime.now()
          .add(const Duration(minutes: 3))
          .millisecondsSinceEpoch,
    }),
  );
  // Same path used when Android restores the app from an OAuth deep link.
  await api.completeLogin(redirect);
  expect(await api.storage.read(key: api.pendingKey), isNull);
  return api;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android secure login, account invitations and roster access end to end',
    (tester) async {
      final owner = await fixtureLogin('76561198000000001');
      final ownerProfile = await owner.request('GET', '/api/v1/me');
      final player = await fixtureLogin('76561198000000002');
      final playerProfile = await player.request('GET', '/api/v1/me');
      expect(playerProfile['id'], isNot(ownerProfile['id']));
      final restored = AccountClient(player.base.toString());
      await restored.loadToken();
      expect(
        (await restored.request('GET', '/api/v1/me'))['id'],
        playerProfile['id'],
      );
      final team = await owner.request(
        'POST',
        '/api/v1/teams',
        body: {'name': 'Android QA ${DateTime.now().millisecondsSinceEpoch}'},
      );
      final path = '/api/v1/teams/${team['id']}';
      final invitation = await owner.request(
        'POST',
        '$path/account-invites',
        body: {'user_id': playerProfile['id']},
      );
      expect(
        (await player.request('GET', '/api/v1/me/invitations'))['items'],
        isNotEmpty,
      );
      await player.request(
        'POST',
        '/api/v1/me/invitations/${invitation['id']}/accept',
      );
      await owner.request(
        'PATCH',
        '$path/members/${playerProfile['id']}',
        body: {'role': 'player', 'game_role': 'AWPer', 'squad': 'reserve'},
      );
      final roster =
          (await player.request('GET', '$path/members'))['items'] as List;
      expect(
        roster.singleWhere((r) => r['id'] == playerProfile['id'])['game_role'],
        'AWPer',
      );
      final sharedRoot = Directory.systemTemp.createTempSync(
        'teamsync_shared_device_',
      );
      final a = Store(':memory:'), b = Store(':memory:');
      Directory? nativeCache;
      String? nativeClip;
      try {
        final ta = saveAccountRoster(
          a,
          owner.base.toString(),
          ownerProfile['id'] as String,
          team,
          roster,
        );
        final tb = saveAccountRoster(
          b,
          player.base.toString(),
          playerProfile['id'] as String,
          {...team, 'role': 'player'},
          roster,
        );
        final radar = File('${sharedRoot.path}/radar.png');
        await radar.writeAsBytes(
          (await rootBundle.load('assets/maps/de_mirage_1_png.png')).buffer
              .asUint8List(),
        );
        final map = a.addMap(ta, 'Shared custom map');
        a.mapImage(map, radar.path);
        final tactic = a.createStrategy(map, 'Team split', 'T');
        a.saveStrategy(tactic, 'shared first plan', [
          {'type': 't', 'x': .2, 'y': .3},
          {'type': 'ct', 'x': .7, 'y': .6},
        ], 1);
        final nativeRoot = await getApplicationSupportDirectory();
        final cache = Directory(
          '${nativeRoot.path}/media/qa-team-${team['id']}',
        );
        nativeCache = cache;
        final clip = await OwnVideo.importBytes(
          LocalFiles(nativeRoot),
          base64Decode(ownClipBase64),
        );
        nativeClip = clip;
        final outside = File(
          '${nativeRoot.path}/qa-outside-${Store.uuid.v4()}.mp4',
        );
        await outside.writeAsBytes(base64Decode(ownClipBase64));
        try {
          expect(await OwnVideo.canOpenOnAndroid(clip), isA<bool>());
          await expectLater(
            OwnVideo.channel.invokeMethod<bool>('canOpenVideo', {
              'path': outside.path,
            }),
            throwsA(
              isA<PlatformException>().having(
                (e) => e.code,
                'code',
                'invalidMedia',
              ),
            ),
          );
        } finally {
          await outside.delete();
        }
        UtilityLibrary(a).save(
          ta,
          map,
          'Own clip and aiming point',
          'T',
          'Offline instruction',
          {
            'grenade': 'smoke',
            'strategy_ids': [tactic],
            'video_path': clip,
            'screenshot_paths': [radar.path],
          },
        );
        final sa = TacticalSync(
          a,
          LocalFiles(Directory('${sharedRoot.path}/a')),
          clientFactory: (_) => DeviceSession(owner),
        );
        final sb = TacticalSync(
          b,
          LocalFiles(cache),
          clientFactory: (_) => DeviceSession(player),
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(b.strategies(tb).single['notes'], 'shared first plan');
        final bclip =
            jsonDecode(
                  UtilityLibrary(b).list(tb).single['details'] as String,
                )['video_path']
                as String;
        expect(await File(bclip).readAsBytes(), base64Decode(ownClipBase64));
        expect(await OwnVideo.canOpenOnAndroid(bclip), isA<bool>());
        final utilityA = UtilityLibrary(a).list(ta).single['id'] as String;
        final utilityB = UtilityLibrary(b).list(tb).single['id'] as String;
        final skillsA = SkillStore(a, ta), skillsB = SkillStore(b, tb);
        final playerId = playerProfile['id'] as String;
        expect(skillsB.mayWrite(playerId, 'confirmed'), isFalse);
        skillsB.desire(utilityB, 1, playerId, 'ready');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        await sa.run(ta, conflictLabel: 'Conflict copy');
        skillsA.desire(utilityA, 1, playerId, 'confirmed');
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(
          (skillsB.row(skillsB.document(utilityB), playerId, 1)['remote']
              as Map)['status'],
          'confirmed',
        );

        expect(
          File(b.maps(tb).single['image_path'] as String).lengthSync(),
          radar.lengthSync(),
        );
        a.saveStrategy(
          tactic,
          'shared revised plan',
          [],
          a.strategy(tactic)['version'] as int,
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(b.strategies(tb).single['notes'], 'shared revised plan');
        final playerMember =
            a.members(ta).singleWhere((m) => m['name'] == 'QA Player')['id']
                as String;
        final assignment = a.createTask(
          ta,
          'Отработать выход',
          'Тайминг первой флешки',
          taskType: 'execute',
          dueAt: DateTime.parse('2026-11-02T18:30:00+02:00'),
          criteria: 'Three coordinated runs',
          member: playerMember,
          strategyId: tactic,
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        final receivedTask = b.tasks(tb).single;
        expect(receivedTask['task_type'], 'execute');
        expect(
          DateTime.parse(receivedTask['due_at'] as String),
          DateTime.utc(2026, 11, 2, 16, 30),
        );
        expect(receivedTask['criteria'], 'Three coordinated runs');
        expect(receivedTask['strategy_id'], b.strategies(tb).single['id']);
        b.transitionTask(receivedTask['id'] as String, 'in_progress');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        await sa.run(ta, conflictLabel: 'Conflict copy');
        expect(a.tasks(ta).single['status'], 'in_progress');
        b.transitionTask(receivedTask['id'] as String, 'submitted');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        await sa.run(ta, conflictLabel: 'Conflict copy');
        expect(a.tasks(ta).single['status'], 'submitted');
        expect(
          () => b.transitionTask(receivedTask['id'] as String, 'approved'),
          throwsA(
            isA<DomainError>().having((e) => e.code, 'code', 'readOnlyTeam'),
          ),
        );
        a.transitionTask(assignment, 'approved');
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(b.tasks(tb).single['status'], 'approved');
        a.transitionTask(
          assignment,
          'todo',
          reason: 'Repeat the first flash timing',
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(
          b.tasks(tb).single['review_reason'],
          'Repeat the first flash timing',
        );
        final history = TaskHistory(
          b,
          tb,
          receivedTask['id'] as String,
          clientFactory: (_) => DeviceSession(player),
        );
        final versions = await history.page(0);
        expect(versions.first['payload']['status'], 'todo');
        expect(
          versions.first['payload']['task_review_reason'],
          'Repeat the first flash timing',
        );
        expect(versions.first['author_name'], isNotEmpty);
        expect(history.cached().first['version'], versions.first['version']);
        PreparationPlan(a, ta, map).create(
          strategies: {tactic},
          members: {playerMember},
          type: 'dry_run',
          dueAt: DateTime.utc(2026, 11, 3, 18),
          criteria: 'Walk the route together',
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        final prepared = b
            .tasks(tb)
            .singleWhere((t) => t['task_type'] == 'dry_run');
        expect(prepared['criteria'], 'Walk the route together');
        expect(prepared['strategy_id'], b.strategies(tb).single['id']);
        expect(prepared['member_id'], b.setting('shared_user_member_$tb'));
      } finally {
        a.close();
        b.close();
        sharedRoot.deleteSync(recursive: true);
        if (nativeClip != null && File(nativeClip).existsSync()) {
          File(nativeClip).deleteSync();
        }
        if (nativeCache != null && nativeCache.existsSync()) {
          nativeCache.deleteSync(recursive: true);
        }
      }
      final store = Store(':memory:');
      store.setSetting('api_url', player.base.toString());
      await tester.pumpWidget(
        MaterialApp(
          theme: workspaceTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountPage(store: store, onLocale: (_) {}),
        ),
      );
      // Network and Android keystore are real, so give them time outside fake frames.
      for (
        var i = 0;
        i < 30 && find.text('QA Player').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('QA Player'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await owner.request('DELETE', '$path/members/${playerProfile['id']}');
      await expectLater(
        player.request('GET', '$path/members'),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 'not_found')),
      );
      await player.logout();
      final loggedOut = AccountClient(player.base.toString());
      await loggedOut.loadToken();
      expect(loggedOut.token, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.close();
    },
  );
  testWidgets('native reminders replace schedules and clear on logout', (
    tester,
  ) async {
    const channel = MethodChannel('app.teamsync/reminders');
    await tester.runAsync(() async {
      final status = await channel.invokeMapMethod<String, dynamic>('status');
      expect(status?['supported'], isTrue);
      final now = DateTime.now().millisecondsSinceEpoch;
      final item = {
        'id': '0123456789abcdef',
        'at': now + 600000,
        'start': now + 1200000,
        'title': 'TeamSync',
        'body':
            'Practice reminder. Open TeamSync to check your current schedule.',
      };
      await channel.invokeMethod<int>('replace', {
        'items': [item],
      });
      expect(
        (await channel.invokeMapMethod<String, dynamic>('status'))?['count'],
        1,
      );
      await channel.invokeMethod<int>('replace', {
        'items': [item],
      });
      expect(
        (await channel.invokeMapMethod<String, dynamic>('status'))?['count'],
        1,
      );
      await channel.invokeMethod<int>('replace', {'items': []});
      expect(
        (await channel.invokeMapMethod<String, dynamic>('status'))?['count'],
        0,
      );
      await channel.invokeMethod<int>('replace', {
        'items': [item],
      });
      await channel.invokeMethod<void>('clear');
      expect(
        (await channel.invokeMapMethod<String, dynamic>('status'))?['count'],
        0,
      );
    });
  });
  testWidgets('offline review notebook survives Android export and import', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('teamsync-notebook-');
      final store = Store(':memory:');
      try {
        final team = store.createTeam('Notebook');
        final source = {
          'schema': 1,
          'parser': 'demoparser2',
          'map': 'de_mirage',
          'name': 'Offline',
          'tick_rate': 64,
          'sample_stride': 8,
          'players': [],
          'kills': [],
          'rounds': [
            {'number': 1, 'start': 0, 'end': 128},
          ],
          'frames': [
            {'tick': 0, 'round': 1, 'players': []},
            {'tick': 128, 'round': 1, 'players': []},
          ],
        };
        final id = await importReview(
          store,
          root,
          team,
          Uint8List.fromList(utf8.encode(jsonEncode(source))),
        );
        store.annotate(id, 64, 1, 'Контроль / hold');
        store.saveScouting(id, {'teams': 'A vs B', 'tier': '1'});
        final bytes = await exportReview(store, store.demos(team).single);
        final copyTeam = store.createTeam('Imported');
        final copy = await importReview(store, root, copyTeam, bytes);
        expect(store.annotations(copy).single['tick'], 64);
        expect(store.annotations(copy).single['note'], 'Контроль / hold');
        expect(
          jsonDecode(
            store.demos(copyTeam).single['scouting'] as String,
          )['tier'],
          '1',
        );
        expect(
          (await readReview(
            store.demos(copyTeam).single['analysis_path'] as String,
          ))['map'],
          'de_mirage',
        );
      } finally {
        store.close();
        await root.delete(recursive: true);
      }
    });
  });
}
