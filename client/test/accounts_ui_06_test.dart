import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/ui/account_page.dart';
import 'package:teamsync/ui/online_team_page.dart';

class FixtureAccount extends AccountClient {
  bool joined = false;
  FixtureAccount() : super('https://fixture.example');
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
    if (path.endsWith('/health')) {
      return {
        'providers': {'steam': true, 'discord': true},
      };
    }
    if (path == '/api/v1/me') {
      return {
        'id': 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
        'name': 'Test Player',
        'identities': [
          {'provider': 'steam'},
        ],
        'session_id': 'device',
      };
    }
    if (path == '/api/v1/teams') {
      return {
        'items': joined
            ? [
                {'id': 'team', 'name': 'Team Five', 'role': 'player'},
              ]
            : [],
      };
    }
    if (path.endsWith('/sessions')) return {'items': []};
    if (path.endsWith('/accept')) {
      joined = true;
      return {'team_id': 'team'};
    }
    if (path.endsWith('/invitations')) {
      return {
        'items': joined
            ? []
            : [
                {'id': 'invitation', 'name': 'Team Five', 'role': 'player'},
              ],
      };
    }
    if (path.contains('/members?')) {
      return {
        'items': [
          {'id': 'me', 'name': 'Owner', 'role': 'owner'},
          {
            'id': 'player',
            'name': 'AWPer',
            'role': 'player',
            'squad': 'reserve',
            'game_role': 'AWPer',
          },
        ],
      };
    }
    if (path.endsWith('/account-invites')) return {'items': []};
    throw StateError('$method $path');
  }
}

void main() {
  for (final lang in ['ru', 'en']) {
    testWidgets('account inbox accepts invitation at 320px $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = Store(':memory:');
      addTearDown(store.close);
      store.setSetting('api_url', 'https://fixture.example');
      final api = FixtureAccount();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          theme: workspaceTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountPage(
            store: store,
            onLocale: (_) {},
            clientFactory: (_) => api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Player'), findsOneWidget);
      final accept = find.text(lang == 'ru' ? 'Принять' : 'Accept');
      await tester.scrollUntilVisible(
        accept,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(accept);
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(api.joined, isTrue);
      expect(find.text(lang == 'ru' ? 'Принять' : 'Accept'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('online roster and actions fit small screen $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = Store(':memory:');
      addTearDown(store.close);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          theme: workspaceTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnlineTeamPage(
            api: FixtureAccount(),
            store: store,
            team: const {'id': 'team', 'name': 'Five', 'role': 'owner'},
            user: 'me',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
