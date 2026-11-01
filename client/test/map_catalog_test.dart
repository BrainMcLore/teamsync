import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:teamsync/data/map_catalog.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/offline_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('upgrade the shipped v0.1 database without losing user materials', () {
    final root = Directory.systemTemp.createTempSync('teamsync_migration_');
    final path = '${root.path}/old.sqlite';
    final old = sqlite3.open(path);
    old.execute(File('test/fixtures/schema_v1.sql').readAsStringSync());
    old.execute(
      "INSERT INTO teams VALUES('team','Existing team','','2026-10-28')",
    );
    old.execute(
      "INSERT INTO members VALUES('member','team','Captain','captain','IGL')",
    );
    old.execute(
      "INSERT INTO maps VALUES('map','team','Mirage','custom-radar.png')",
    );
    old.execute(
      "INSERT INTO strategies VALUES('strategy','map','Existing tactic','T','Keep my notes','[]',1,'2026-10-28')",
    );
    old.close();
    final store = Store(path);
    try {
      expect(store.teams.single['name'], 'Existing team');
      expect(store.strategy('strategy')['notes'], 'Keep my notes');
      expect(store.strategy('strategy')['level'], 'default');
      expect(store.maps('team').single['image_path'], 'custom-radar.png');
      store.createTask(
        'team',
        'Review old tactic',
        '',
        member: 'member',
        strategyId: 'strategy',
      );
      expect(store.tasks('team').single['strategy_title'], 'Existing tactic');
    } finally {
      store.close();
      root.deleteSync(recursive: true);
    }
  });
  test('ten ready maps install offline, seed idempotently and calibrate both Nuke levels', () async {
    final root = Directory.systemTemp.createTempSync('teamsync_catalog_'),
        store = Store(':memory:');
    try {
      final catalog = await MapCatalog.install(root),
          team = store.createTeam('Maps QA');
      catalog.ensureTeam(store, team);
      catalog.ensureTeam(store, team);
      expect(store.maps(team), hasLength(10));
      for (final map in store.maps(team)) {
        expect(File(map['image_path'] as String).existsSync(), isTrue);
      }
      final nuke = store
          .maps(team)
          .singleWhere((m) => m['catalog_id'] == 'de_nuke');
      expect(File(nuke['lower_image_path'] as String).existsSync(), isTrue);
      expect(catalog.levelFor('de_nuke', -600), 'lower');
      expect(catalog.levelFor('de_nuke', 0), 'default');
      final corner = catalog.worldToRadar('de_mirage', -3230, 1713);
      expect(corner.dx, 0);
      expect(corner.dy, 0);
      final point = catalog.worldToRadar('de_mirage', -670, -847);
      expect(point.dx, closeTo(.5, .0001));
      expect(point.dy, closeTo(.5, .0001));
      final strategy = store.createStrategy(
        nuke['id'] as String,
        'Lower site',
        'T',
      );
      store.saveStrategy(strategy, 'B site', [], 1, level: 'lower');
      expect(store.strategy(strategy)['image_path'], contains('_lower_'));
      final activeTask = store.createTask(
        team,
        'Active practice',
        '',
        strategyId: strategy,
      );
      store.transitionTask(activeTask, 'in_progress');
      final returnedTask = store.createTask(team, 'Needs review', '');
      store.transitionTask(returnedTask, 'submitted');
      store.transitionTask(
        returnedTask,
        'todo',
        reason: 'Repeat the smoke timing',
      );
      final imported = await OfflinePackage.restore(
        store,
        root,
        OfflinePackage.export(store, team, 'ru'),
      );
      expect(
        store
            .tasks(imported)
            .singleWhere((t) => t['title'] == 'Active practice')['status'],
        'in_progress',
      );
      expect(
        store
            .tasks(imported)
            .singleWhere((t) => t['title'] == 'Needs review')['review_reason'],
        'Repeat the smoke timing',
      );
      final copy = store.strategies(imported).single;
      expect(copy['level'], 'lower');
      expect(File(copy['image_path'] as String).existsSync(), isTrue);
      expect(
        File(copy['image_path'] as String).readAsBytesSync(),
        File(nuke['lower_image_path'] as String).readAsBytesSync(),
      );
      store.restoreVersion(strategy, 1);
      expect(store.strategy(strategy)['level'], 'default');
    } finally {
      store.close();
      root.deleteSync(recursive: true);
    }
  });
}
