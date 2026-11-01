import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/utilities.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/ui/utilities_page.dart';

void main() {
  test('utility source links keep timestamps and reject credentials or foreign maps', () {
    final store = Store(':memory:');
    addTearDown(store.close);
    final team = store.createTeam('Five'), other = store.createTeam('Other');
    final map = store.addMap(team, 'Mirage'),
        foreign = store.addMap(other, 'Other');
    final library = UtilityLibrary(store);
    final id = library.save(team, map, 'Окно', 'T', 'Прицелиться\nБросок', {
      'grenade': 'smoke',
      'source_url': 'https://youtu.be/abc123?t=42',
      'start': '  T spawn  ',
    });
    final row = library.list(team).single;
    expect(row['id'], id);
    expect(jsonDecode(row['details'] as String)['start'], 'T spawn');
    expect(
      jsonDecode(row['details'] as String)['source_url'],
      endsWith('?t=42'),
    );
    expect(
      () => library.save(team, foreign, 'Bad', 'T', '', {'grenade': 'smoke'}),
      throwsA(isA<DomainError>()),
    );
    for (final url in [
      'file:///tmp/a',
      'https://youtube.com@evil.example/a',
      'https://evil.example/watch',
      'http://youtu.be/a',
    ]) {
      expect(() => UtilityLibrary.source(url), throwsA(isA<DomainError>()));
    }
    store.setSetting('shared_role_$team', 'player');
    expect(
      () => library.save(team, map, 'Rewrite', 'T', '', {
        'grenade': 'smoke',
      }, id: id),
      throwsA(isA<DomainError>()),
    );
  });

  for (final locale in ['ru', 'en']) {
    testWidgets(
      'utility form and saved instructions fit a narrow phone $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = Directory.systemTemp.createTempSync(
          'teamsync_utility_ui_',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final store = Store(':memory:');
        addTearDown(store.close);
        final team = store.createTeam('Five');
        store.addMap(team, 'Mirage');
        await tester.pumpWidget(
          MaterialApp(
            theme: workspaceTheme(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: UtilitiesPage(
                  store: store,
                  files: LocalFiles(root),
                  team: team,
                ),
              ),
            ),
          ),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(UtilitiesPage)),
        );
        await tester.tap(find.text(l.newUtility));
        await tester.pumpAndSettle();
        final title = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == l.title,
        );
        await tester.ensureVisible(title);
        await tester.enterText(title, 'Окно / Window');
        final notes = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == l.utilityInstruction,
        );
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Jumpthrow from T spawn');
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
        expect(
          UtilityLibrary(store).list(team).single['notes'],
          'Jumpthrow from T spawn',
        );
        expect(find.text('Окно / Window'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
