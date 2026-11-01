import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/main.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/map_catalog.dart';
import 'package:teamsync/data/review_data.dart';
import 'package:teamsync/ui/editor.dart';
import 'package:teamsync/ui/demo_review.dart';
import 'package:teamsync/l10n/app_localizations.dart';

Future<void> cacheImage(String path) async {
  final file = File(path),
      codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  PaintingBinding.instance.imageCache.putIfAbsent(
    FileImage(file),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: frame.image)),
    ),
  );
  codec.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(configFile.readAsStringSync()) as Map;
    final flutter = (config['packages'] as List).firstWhere(
      (p) => p['name'] == 'flutter',
    ) as Map;
    final sdk = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final icon = File(
      '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icon.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icon.readAsBytesSync())));
      await loader.load();
    }
    PaintingBinding.instance.imageCache.maximumSizeBytes = 300 * 1024 * 1024;
  });
  testWidgets('capture native studio maps, editor and mobile task layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('teamsync_studio_'),
        store = Store(':memory:');
    addTearDown(() {
      store.close();
      root.deleteSync(recursive: true);
    });
    final catalog = await tester.runAsync(() => MapCatalog.install(root));
    await tester.runAsync(() async {
      for (final map in catalog!.maps) {
        for (final level in map['levels'] as List) {
          await cacheImage(catalog.path(level['asset'] as String));
        }
        await cacheImage(catalog.thumbnail(map['key'] as String)!);
      }
    });
    final team = store.createTeam('TEAMSYNC / QA');
    store.setSetting(
      'account_team_$team',
      jsonEncode({
        'server': 'https://fixture.example',
        'team': team,
        'user': 'qa',
      }),
    );
    catalog!.ensureTeam(store, team);
    final member = store.addMember(team, 'QA captain', 'captain', 'IGL');
    final mirage = store
        .maps(team)
        .singleWhere((m) => m['catalog_id'] == 'de_mirage');
    final id = store.createStrategy(
      mirage['id'] as String,
      'Контроль мида → сплит A',
      'T',
    );
    store.saveStrategy(
      id,
      'Дымы: окно и коннектор.\nEntry выходит после флешки. Support удерживает short.',
      [
        {'type': 'smoke', 'x': .48, 'y': .46},
        {'type': 't', 'x': .63, 'y': .64},
        {'type': 't', 'x': .69, 'y': .62},
        {'type': 'ct', 'x': .43, 'y': .43},
        {'type': 'arrow', 'x': .63, 'y': .64, 'x2': .52, 'y2': .53},
      ],
      1,
    );
    store.createTask(
      team,
      'Отработать синхронный выход через коннектор',
      'Проверить тайминг дыма и флешки перед командной тренировкой.',
      member: member,
      strategyId: id,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('native-shot'),
        child: TeamSyncApp(store: store, files: LocalFiles(root)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Карты').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('native-shot')),
      matchesGoldenFile('../../artifacts/verification/studio-maps-08.png'),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('native-shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: workspaceTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StrategyEditor(
            store: store,
            files: LocalFiles(root),
            id: id,
            onTask: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('native-shot')),
      matchesGoldenFile('../../artifacts/verification/studio-editor-08.png'),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('native-shot'),
        child: TeamSyncApp(store: store, files: LocalFiles(root)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.checklist).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('native-shot')),
      matchesGoldenFile('../../artifacts/verification/studio-mobile-08.png'),
    );
  });
  final fixture = Directory('../.tools/demo-fixtures/parsed');
  testWidgets('real recorded positions render in native review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('teamsync_review_'),
        store = Store(':memory:');
    addTearDown(() {
      store.close();
      root.deleteSync(recursive: true);
    });
    final catalog = await tester.runAsync(() => MapCatalog.install(root));
    await tester.runAsync(
      () => cacheImage(catalog!.radar(catalog.find('de_mirage')!)),
    );
    final team = store.createTeam('QA');
    final file = fixture.listSync().whereType<File>().firstWhere(
      (f) => f.path.endsWith('.json'),
    );
    store.addDemo(team, 'Real CS2 parser fixture', file.path, 60601900);
    final demo = store.demos(team).single;
    store.saveAnalysis(
      demo['id'] as String,
      file.absolute.path,
      'de_mirage',
      'fixture',
    );
    store.annotate(demo['id'] as String, 18000, 2, 'Проверить тайминг размена');
    store.annotate(demo['id'] as String, 27000, 4, 'Позиция опорника');
    final review = await tester.runAsync(() => readReview(file.absolute.path));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('native-shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: workspaceTheme(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DemoReviewPage(
            store: store,
            files: LocalFiles(root),
            demo: store.demos(team).single,
            initialData: review,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('native-shot')),
      matchesGoldenFile('../../artifacts/verification/studio-review-08.png'),
    );
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    ReviewPainter currentPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ReviewPainter>()
        .single;
    final delegate = currentPainter(), at = currentPainter().position!.value;
    await tester.pump(const Duration(milliseconds: 16));
    expect(currentPainter().position!.value, greaterThan(at));
    expect(currentPainter().position!.value, lessThan(at + 16));
    expect(
      identical(delegate, currentPainter()),
      isTrue,
      reason: 'one display frame should repaint players without rebuilding UI',
    );
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    final pausedAt = currentPainter().position!.value;
    await tester.pump(const Duration(milliseconds: 250));
    expect(currentPainter().position!.value, pausedAt);
    for (final size in [const Size(390, 844), const Size(320, 640)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await expectLater(
          find.byKey(const Key('native-shot')),
          matchesGoldenFile(
            '../../artifacts/verification/studio-review-mobile-08.png',
          ),
        );
      }
    }
  }, skip: !fixture.existsSync());
}
