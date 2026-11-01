import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/download_inbox.dart';
import 'package:teamsync/data/map_catalog.dart';
import 'package:teamsync/data/offline_package.dart';
import 'package:teamsync/data/pc_services.dart';
import 'package:teamsync/data/playbook.dart';
import 'package:teamsync/data/playbook_drafts.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/l10n/app_localizations.dart';
import 'package:teamsync/ui/demo_review.dart';
import 'package:teamsync/ui/demo_tags.dart';
import 'package:teamsync/ui/lan_match_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Store store;
  setUp(() {
    root = Directory.systemTemp.createTempSync('teamsync_03_');
    store = Store(':memory:');
  });
  tearDown(() {
    store.close();
    root.deleteSync(recursive: true);
  });

  test('T and CT remain distinct in history and offline package', () async {
    final team = store.createTeam('Sides'), map = store.addMap(team, 'Cache');
    final strategy = store.createStrategy(map, 'Split', 'T');
    store.saveStrategy(strategy, 'Both sides', [
      {'type': 't', 'x': .2, 'y': .3},
      {'type': 'ct', 'x': .7, 'y': .6},
    ], 1);
    final clone = await OfflinePackage.restore(
      store,
      root,
      OfflinePackage.export(store, team, 'ru'),
    );
    final objects =
        jsonDecode(store.strategies(clone).single['objects'] as String) as List;
    expect(objects.map((o) => o['type']), ['t', 'ct']);
    store.restoreVersion(strategy, 2);
    expect(
      jsonDecode(store.strategy(strategy)['objects'] as String),
      hasLength(2),
    );
  });

  test('notes are persisted at ticks and seek to a bounded sampled frame', () {
    final team = store.createTeam('Notes');
    store.addDemo(team, 'Match', 'sample.dem', 20);
    final demo = store.demos(team).single['id'] as String;
    store.annotate(demo, 39, 2, 'Trade timing');
    final frames = [
      {'tick': 0},
      {'tick': 16},
      {'tick': 32},
      {'tick': 48},
    ];
    expect(frameIndexAtTick(frames, 39), 3);
    expect(frameIndexAtTick(frames, -1), 0);
    expect(frameIndexAtTick(frames, 999), 3);
    expect(store.annotations(demo).single['tick'], 39);
    store.deleteAnnotation(
      store.annotations(demo).single['id'] as String,
      'other-demo',
    );
    expect(store.annotations(demo), hasLength(1));
    store.deleteAnnotation(
      store.annotations(demo).single['id'] as String,
      demo,
    );
    expect(store.annotations(demo), isEmpty);
  });

  test('scouting filters require actual coach labels, with AND semantics', () {
    final team = store.createTeam('Filter');
    store.addDemo(team, 'Match', 'x.dem', 20);
    final id = store.demos(team).single['id'] as String;
    expect(matchesDemoTags(store.demos(team).single, 'Navi', '', ''), isFalse);
    store.saveScouting(id, {
      'teams': 'NAVI, Vitality',
      'tier': '1',
      'positions': 'Player — CT — A anchor',
      'source': 'coach',
    });
    final demo = store.demos(team).single;
    expect(matchesDemoTags(demo, 'navi', 'anchor', '1'), isTrue);
    expect(matchesDemoTags(demo, 'navi', 'AWP', '1'), isFalse);
    expect(matchesDemoTags(demo, '', '', '2'), isFalse);
  });

  test('download inbox ignores old and partial files and waits for stable new archive', () async {
    await File('${root.path}/old.rar').writeAsBytes(List.filled(32, 1));
    final inbox = await DownloadInbox.open(root), now = DateTime(2026, 10, 29);
    final fresh = File('${root.path}/new.rar');
    await fresh.writeAsBytes(List.filled(40, 1));
    final partial = File('${fresh.path}.crdownload');
    await partial.writeAsString('incomplete');
    expect(await inbox.next(now: now), isNull);
    await partial.delete();
    expect(await inbox.next(now: now), isNull);
    await fresh.writeAsBytes(List.filled(50, 1));
    expect(await inbox.next(now: now.add(const Duration(seconds: 12))), isNull);
    expect(await inbox.next(now: now.add(const Duration(seconds: 20))), isNull);
    expect(
      (await inbox.next(now: now.add(const Duration(seconds: 23))))?.uri,
      fresh.uri,
    );
    expect(await inbox.next(now: now.add(const Duration(seconds: 40))), isNull);
    expect(await File('${root.path}/old.rar').exists(), isTrue);
  });

  test('CS launch copies a DEM to a safe name, reuses it and never accepts command injection', () async {
    final game = Directory('${root.path}/host with spaces/game'),
        bin = Directory('${root.path}/host with spaces/game/bin/win64');
    await bin.create(recursive: true);
    await Directory('${game.path}/csgo').create();
    final exe = File('${bin.path}/cs2.exe');
    await exe.writeAsString('not executed');
    final steam = File('${root.path}/steam.exe');
    await steam.writeAsString('not executed');
    final demo = File('${root.path}/bad;quit.dem');
    await demo.writeAsBytes([
      ...ascii.encode('PBDEMS2'),
      0,
      ...List.filled(30, 1),
    ]);
    final pc = PcInstallation(steam.path, exe.path);
    final plan = await PcDemoLauncher.prepare(
          store,
          demo.path,
          installation: pc,
        ),
        again = await PcDemoLauncher.prepare(
          store,
          demo.path,
          installation: pc,
        );
    expect(plan.copiedPath, again.copiedPath);
    expect(plan.arguments.take(3), ['-applaunch', '730', '+playdemo']);
    expect(
      plan.arguments.last,
      matches(r'^replays/teamsync_[0-9a-f]{64}\.dem$'),
    );
    expect(await File(plan.copiedPath).readAsBytes(), await demo.readAsBytes());
    await demo.writeAsString('corrupt data that must be rejected');
    await expectLater(
      PcDemoLauncher.prepare(store, demo.path, installation: pc),
      throwsA(isA<DomainError>()),
    );
  });

  test(
    'LAN command profiles reject injection and isolate practice settings',
    () {
      final practice = LanHost.csArguments('de_cache', 'practice', 27015),
          pug = LanHost.csArguments('de_mirage', 'scrim', 27015);
      expect(practice, contains('+sv_infinite_ammo'));
      expect(pug, isNot(contains('+sv_infinite_ammo')));
      expect(
        pug,
        containsAll([
          '-dedicated',
          '-insecure',
          '+sv_lan',
          '1',
          '+sv_cheats',
          '0',
        ]),
      );
      expect(
        () => LanHost.csArguments('de_mirage;quit', 'scrim', 27015),
        throwsA(isA<DomainError>()),
      );
      expect(
        () => LanHost.csArguments('de_mirage', 'scrim', -1),
        throwsA(isA<DomainError>()),
      );
      expect(
        parseMatchRoster('76561198000000001 Entry\n76561198000000002 IGL'),
        hasLength(2),
      );
      expect(
        () => parseMatchRoster('76561198000000001 A\n76561198000000001 B'),
        throwsA(isA<DomainError>()),
      );
    },
  );

  test('RCON authenticates and handles fragmented TCP response before reporting a command', () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    String? received;
    listener.listen((socket) {
      var buffer = <int>[], auth = false;
      socket.listen((chunk) {
        buffer.addAll(chunk);
        if (buffer.length < 14) return;
        final text = utf8.decode(buffer.sublist(12, buffer.length - 2));
        buffer.clear();
        if (!auth) {
          expect(text, 'test-secret');
          auth = true;
          socket.add(SourceRcon.packet(1, 2, ''));
        } else {
          received = text;
          final reply = SourceRcon.packet(2, 0, 'MatchZy 0.9.2 loaded');
          socket.add(reply.sublist(0, 3));
          socket.add(reply.sublist(3));
        }
      });
    });
    try {
      expect(
        await SourceRcon.execute(
          listener.port,
          'test-secret',
          'css_plugins list',
        ),
        'MatchZy 0.9.2 loaded',
      );
      expect(received, 'css_plugins list');
    } finally {
      await listener.close();
    }
  });

  test(
    'round PDF holds immutable real map snapshots with T/CT in both languages',
    () async {
      final loader = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await loader.load();
      final catalog = await MapCatalog.install(root),
          team = store.createTeam('PDF QA');
      catalog.ensureTeam(store, team);
      final cache = store
          .maps(team)
          .singleWhere((m) => m['catalog_id'] == 'de_cache');
      final id = store.createStrategy(
        cache['id'] as String,
        'Cache — выход A',
        'T',
      );
      store.saveStrategy(
        id,
        'Два игрока выходят синхронно. Защитник держит позицию.',
        [
          {'type': 't', 'x': .4, 'y': .4},
          {'type': 'ct', 'x': .6, 'y': .5},
        ],
        1,
      );
      final drafts = PlaybookDrafts(store, root, team),
          book = drafts.create('Плейбук / LAN', 'Раунд 1 — выход A');
      await drafts.attach(
        book['id'] as String,
        book['pages'][0]['id'] as String,
        id,
      );
      final attached = drafts.load().single, page = attached['pages'][0] as Map;
      page['economy'] = 'Полный закуп / full buy';
      page['plan'] = 'Дым на CT. Выход по флешке.\n' * 25;
      page['roles'] = 'T1 — entry. T2 — trade. CT1 — противник на пленте.';
      final picture = File(page['attachments'][0]['path'] as String),
          before = sha256.convert(
            await File(page['attachments'][0]['path'] as String).readAsBytes(),
          );
      store.saveStrategy(id, 'Changed later', [], 2);
      expect(page['attachments'][0]['version'], 2);
      expect(sha256.convert(await picture.readAsBytes()), before);
      for (final language in ['ru', 'en']) {
        final labels = await AppLocalizations.delegate.load(Locale(language)),
            pdf = await Playbook.generateDraft(attached, labels);
        expect(ascii.decode(pdf.take(4).toList()), '%PDF');
        await File('../artifacts/verification/round-playbook-03-$language.pdf')
            .writeAsBytes(pdf);
      }
      expect(
        drafts.load().single['pages'][0]['attachments'][0]['notes'],
        contains('синхронно'),
      );
    },
  );
}
