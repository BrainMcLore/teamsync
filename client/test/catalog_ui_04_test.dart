import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/hltv_client.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/ui/hltv_catalog.dart';

class FixtureCatalog extends HltvClient {
  FixtureCatalog(super.root);
  Map<String, dynamic> get page => {
    'items': [
      {
        'id': '123',
        'url': 'https://www.hltv.org/matches/123/a-vs-b',
        'teams': ['Team A', 'Team B'],
        'event': 'Tournament',
        'format': 'bo3',
        'score': '2 - 1',
        'stars': 2,
        'date': '2026-10-29T10:00:00Z',
      },
    ],
    'offset': 0,
    'fetched_at': '2026-10-29T11:00:00Z',
  };
  @override
  Future<Map<String, dynamic>?> cached(int offset) async => page;
  @override
  Future<Map<String, dynamic>> fetch({
    int offset = 0,
    String? match,
    bool force = false,
  }) async => match == null
      ? page
      : {
          'teams': ['Team A', 'Team B'],
          'event': 'Tournament',
          'maps': ['Cache', 'Mirage'],
          'players': ['Entry', 'Anchor'],
          'demo_urls': ['https://www.hltv.org/download/demo/42'],
        };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['ru', 'en']) {
    for (final size in [const Size(320, 640), const Size(1366, 768)]) {
      testWidgets(
        'HLTV catalog renders, tags event tier and passes genuine URL to download $locale $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = Store(':memory:'),
              root = Directory.systemTemp.createTempSync(
                'teamsync_catalog_ui_',
              ),
              team = store.createTeam('QA');
          addTearDown(() {
            store.close();
            root.deleteSync(recursive: true);
          });
          String? downloaded;
          await tester.pumpWidget(
            MaterialApp(
              theme: workspaceTheme(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: HltvCatalog(
                  store: store,
                  root: root,
                  team: team,
                  client: FixtureCatalog(root),
                  onDownload: (url, page, info) async {
                    downloaded = url;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final button = find.widgetWithText(
            FilledButton,
            locale == 'ru' ? 'Скачать и разобрать' : 'Download and analyze',
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(downloaded, 'https://www.hltv.org/download/demo/42');
          expect(find.textContaining('Cache / Mirage'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
