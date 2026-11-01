import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/review_data.dart';
import 'package:teamsync/data/review_index.dart';

List<Map> originalActive(Map data, int tick) {
  final events = data['events'] as Map, result = <Map>[];
  for (final pair in [
    ('smokegrenade_detonate', 'smokegrenade_expired'),
    ('inferno_startburn', 'inferno_expire'),
  ]) {
    for (final point in events[pair.$1] as List? ?? []) {
      final ends = (events[pair.$2] as List? ?? [])
          .where(
            (e) =>
                e['entityid'] == point['entityid'] &&
                e['tick'] >= point['tick'],
          )
          .firstOrNull;
      if (point['tick'] <= tick &&
          ends != null &&
          tick < ends['tick'] &&
          point['x'] is num &&
          point['y'] is num) {
        result.add(point as Map);
      }
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'smooth motion preserves yaw wrap, death, teleports and round boundaries',
    () {
      Map player(
        double x, {
        double yaw = 350,
        int hp = 100,
        bool alive = true,
      }) => {
        'id': '1',
        'x': x,
        'y': 0.0,
        'z': 0.0,
        'team': 2,
        'hp': hp,
        'alive': alive,
        'yaw': yaw,
      };
      final a = {
        'tick': 0,
        'round': 1,
        'players': [player(0)],
      };
      final b = {
        'tick': 16,
        'round': 1,
        'players': [player(100, yaw: 10)],
      };
      final midway = interpolatedPlayers(a, b, 8, 64).single as Map;
      expect(midway['x'], 50);
      expect((midway['yaw'] as num) % 360, 0);
      expect(interpolatedPlayers(a, {...b, 'round': 2}, 8, 64).single['x'], 0);
      expect(
        interpolatedPlayers(
          a,
          {
            ...b,
            'players': [player(1000)],
          },
          8,
          64,
        ).single['x'],
        0,
      );
      expect(
        interpolatedPlayers(
          a,
          {
            ...b,
            'players': [player(100, alive: false, hp: 0)],
          },
          8,
          64,
        ).single['x'],
        0,
      );
      expect(floorFrameAtTick([a, b], 8), 0);
      expect(floorFrameAtTick([a, b], 16), 1);
    },
  );

  test('indexed events and grenades keep exact historical and reused-entity semantics', () {
    final data = <String, dynamic>{
      'players': <Map>[],
      'kills': [
        {'tick': 15},
        {'tick': 25},
      ],
      'events': {
        'smokegrenade_detonate': [
          {'tick': 10, 'entityid': 1, 'x': 1, 'y': 2},
          {'tick': 50, 'entityid': 1, 'x': 3, 'y': 4},
        ],
        'smokegrenade_expired': [
          {'tick': 30, 'entityid': 1},
          {'tick': 70, 'entityid': 1},
        ],
        'bomb_planted': [
          {'tick': 60},
        ],
      },
    };
    final index = ReviewIndex(data);
    for (var tick = 0; tick < 100; tick++) {
      expect(
        index.active(tick).map((e) => e['tick']).toList(),
        originalActive(data, tick).map((e) => e['tick']).toList(),
      );
    }
    expect(index.recent(20).first['tick'], 15);
    expect(index.recent(60).first['tick'], 60);
  });

  final source = File('../.tools/benchmark-source-04.txt');
  test('benchmark actual user review event queries without modifying the recording', () async {
    final path = source.readAsStringSync().trim();
    final watch = Stopwatch()..start();
    final data = await readReview(path);
    watch.stop();
    final index = data['_index'] as ReviewIndex,
        frames = data['frames'] as List,
        ticks = [
          for (var n = 0; n < 300; n++)
            frames[(n * (frames.length - 1) / 299).round()]['tick'] as int,
        ];
    var originalCount = 0, indexedCount = 0;
    final oldWatch = Stopwatch()..start();
    for (final tick in ticks) {
      originalCount += originalActive(data, tick).length;
    }
    oldWatch.stop();
    final indexedWatch = Stopwatch()..start();
    for (final tick in ticks) {
      indexedCount += index.active(tick).length;
      index.recent(tick);
    }
    indexedWatch.stop();
    expect(indexedCount, originalCount);
    final cached = await readReview(path);
    expect(identical(data, cached), isTrue);
    final output = {
      'review_bytes': await File(path).length(),
      'frames': frames.length,
      'rounds': (data['rounds'] as List).length,
      'load_and_index_ms': watch.elapsedMilliseconds,
      'queries': ticks.length,
      'original_active_query_us': oldWatch.elapsedMicroseconds,
      'indexed_active_and_recent_us': indexedWatch.elapsedMicroseconds,
      'original_average_us': oldWatch.elapsedMicroseconds / ticks.length,
      'indexed_average_us': indexedWatch.elapsedMicroseconds / ticks.length,
      'note': 'CPU event-query benchmark in Flutter test; not an end-to-end GPU FPS measurement.',
    };
    final report = File('../artifacts/verification/review-performance-04.json');
    await report.parent.create(recursive: true);
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(output),
    );
  }, skip: !source.existsSync());
}
