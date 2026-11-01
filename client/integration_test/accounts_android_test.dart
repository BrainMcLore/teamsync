import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
        final sa = TacticalSync(
          a,
          LocalFiles(Directory('${sharedRoot.path}/a')),
          clientFactory: (_) => DeviceSession(owner),
        );
        final sb = TacticalSync(
          b,
          LocalFiles(Directory('${sharedRoot.path}/b')),
          clientFactory: (_) => DeviceSession(player),
        );
        await sa.run(ta, conflictLabel: 'Conflict copy');
        await sb.run(tb, conflictLabel: 'Conflict copy');
        expect(b.strategies(tb).single['notes'], 'shared first plan');
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
      } finally {
        a.close();
        b.close();
        sharedRoot.deleteSync(recursive: true);
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
}
