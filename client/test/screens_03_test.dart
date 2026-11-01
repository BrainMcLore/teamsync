import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/pc_services.dart';
import 'package:teamsync/data/playbook_drafts.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/ui/bootcamp.dart';
import 'package:teamsync/ui/demo_hub.dart';
import 'package:teamsync/ui/playbook_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['ru', 'en']) {
    for (final size in [const Size(320, 640), const Size(1366, 768)]) {
      testWidgets(
        'new demo filters, round editor and LAN settings fit $locale $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final root = Directory.systemTemp.createTempSync(
                'teamsync_screens03_',
              ),
              store = Store(':memory:');
          final host = LanHost(store);
          addTearDown(() {
            host.dispose();
            store.close();
            root.deleteSync(recursive: true);
          });
          final team = store.createTeam('Screen QA');
          store.addDemo(
            team,
            'A very long real imported demo title',
            'source.dem',
            500,
          );
          final drafts = PlaybookDrafts(store, root, team);
          drafts.create('LAN — раунды / rounds', 'Раунд / round 1');
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: workspaceTheme(),
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: SafeArea(child: child)),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          await mount(
            DemoHub(store: store, files: LocalFiles(root), team: team),
          );
          await mount(
            PlaybookEditor(store: store, files: LocalFiles(root), team: team),
          );
          final title = locale == 'ru' ? 'План раунда' : 'Round plan';
          await tester.enterText(
            find.widgetWithText(TextFormField, title),
            'Saved plan for this round',
          );
          expect(
            drafts.load().single['pages'][0]['plan'],
            'Saved plan for this round',
          );
          await mount(BootcampPage(store: store, host: host));
          // Allow native read-only installation discovery to finish before disposing.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
