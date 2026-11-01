import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/editor.dart';
import 'package:teamsync/ui/account_page.dart';

void main() {
  late Store store;
  late Directory directory;
  setUp(() {
    store = Store(':memory:');
    directory = Directory.systemTemp.createTempSync('teamsync_ui_');
  });
  tearDown(() {
    store.close();
    directory.deleteSync(recursive: true);
  });
  test('RU and EN catalogs have matching keys and parameters', () {
    final ru =
        jsonDecode(File('lib/l10n/app_ru.arb').readAsStringSync()) as Map;
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    expect(ru.keys.toSet(), en.keys.toSet());
    for (final key in ru.keys.where(
      (e) => e.toString().startsWith('@') && !e.toString().startsWith('@@'),
    )) {
      expect(
        (ru[key]['placeholders'] as Map).keys.toSet(),
        (en[key]['placeholders'] as Map).keys.toSet(),
      );
    }
  });
  testWidgets('first Android screen opens account without a local team', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TeamSyncApp(store: store, files: LocalFiles(directory)),
    );
    await tester.pumpAndSettle();
    final login = find.text('Онлайн-аккаунт');
    await tester.scrollUntilVisible(
      login,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);
    expect(store.teams, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'legacy offline team is preserved but cannot open as an account',
    (tester) async {
      store.createTeam('Legacy materials');
      await tester.pumpWidget(
        TeamSyncApp(store: store, files: LocalFiles(directory)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Создать команду'), findsNothing);
      expect(find.text('Legacy materials'), findsNothing);
      expect(find.text('Онлайн-аккаунт'), findsOneWidget);
      expect(store.teams.single['name'], 'Legacy materials');
      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(store.setting('language'), 'en');
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['ru', 'en']) {
    for (final size in [
      const Size(1366, 768),
      const Size(390, 844),
      const Size(320, 640),
    ]) {
      testWidgets('all workspace pages fit $locale $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final team = store.createTeam(
          'A long team name / Длинное название команды',
        );
        store.setSetting(
          'account_team_$team',
          jsonEncode({
            'server': 'https://fixture.example',
            'team': team,
            'user': 'qa',
          }),
        );
        store.setSetting('language', locale);
        store.addMember(
          team,
          'A very long player nickname для проверки',
          'captain',
          'IGL',
        );
        final map = store.addMap(team, 'de_mirage');
        final id = store.createStrategy(
          map,
          'A long strategy title — Выход через коннектор',
          'T',
        );
        store.createTask(
          team,
          'Practice with a long task title / Подготовка выхода',
          'Hold the angle and coordinate the timing.',
          strategyId: id,
        );
        await tester.pumpWidget(
          TeamSyncApp(store: store, files: LocalFiles(directory)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width >= 900) {
          for (final label
              in locale == 'ru'
                  ? [
                      'Карты',
                      'Тактики',
                      'Тренировки',
                      'Демки',
                      'Состав',
                      'Настройки',
                      'Плейбуки / PDF',
                      'Буткемп',
                    ]
                  : [
                      'Maps',
                      'Strategies',
                      'Training',
                      'Demos',
                      'Team',
                      'Settings',
                      'Playbooks / PDF',
                      'Bootcamp',
                    ]) {
            await tester.tap(find.text(label).first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: label);
          }
        } else {
          for (final icon in [
            Icons.map_outlined,
            Icons.checklist,
            Icons.groups_outlined,
            Icons.more_horiz,
          ]) {
            await tester.tap(find.byIcon(icon).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }
  testWidgets('editor saves notes and restores history on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final team = store.createTeam('A'), map = store.addMap(team, 'Mirage');
    final id = store.createStrategy(map, 'Execute A', 'T');
    await tester.pumpWidget(
      MaterialApp(
        theme: workspaceTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StrategyEditor(
          store: store,
          files: LocalFiles(directory),
          id: id,
          onTask: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Smoke CT and stairs');
    await tester.tap(find.byTooltip('Save version'));
    await tester.pumpAndSettle();
    expect(store.strategy(id)['notes'], 'Smoke CT and stairs');
    await tester.tap(find.byTooltip('Version history'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restore as new version').last);
    await tester.pumpAndSettle();
    expect(store.strategy(id)['notes'], '');
    expect(store.strategy(id)['version'], 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online account setup fits a small phone in Russian', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: workspaceTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountPage(store: store, onLocale: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подключить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'radar preserves image aspect ratio and stores normalized coordinates',
    (tester) async {
      final objects = <Map<String, dynamic>>[];
      final file = File('test/fixtures/radar.png').absolute;
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(file.readAsBytesSync()),
      );
      final frame = await tester.runAsync(() => codec!.getNextFrame());
      PaintingBinding.instance.imageCache.putIfAbsent(
        FileImage(file),
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: frame!.image)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadarCanvas(
              path: File('test/fixtures/radar.png').absolute.path,
              objects: objects,
              tool: 'marker',
              onAdd: objects.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = find.descendant(
        of: find.byType(RadarCanvas),
        matching: find.byType(GestureDetector),
      );
      expect(gesture, findsOneWidget);
      final rect = tester.getRect(gesture);
      expect(rect.width / rect.height, closeTo(2, 0.01));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(objects, hasLength(1));
      expect(objects.single['x'], closeTo(0.5, 0.01));
      expect(objects.single['y'], closeTo(0.5, 0.01));
      expect(tester.takeException(), isNull);
      codec!.dispose();
    },
  );
}
