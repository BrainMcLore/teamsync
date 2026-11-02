import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/review_data.dart';
import 'package:teamsync/data/store.dart';

Map<String, dynamic> analysis() => {
  'schema': 1,
  'parser': 'demoparser2',
  'map': 'de_mirage',
  'name': 'Match',
  'tick_rate': 64,
  'sample_stride': 8,
  'players': [],
  'kills': [],
  'rounds': [
    {'number': 1, 'start': 0, 'end': 128},
  ],
  'frames': [
    {'tick': 0, 'round': 1, 'players': []},
    {'tick': 128, 'round': 1, 'players': []},
  ],
};
Uint8List encoded(Map<String, dynamic> data) =>
    Uint8List.fromList(utf8.encode(jsonEncode(data)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Store store;
  late Directory root;
  late String team;
  setUp(() async {
    store = Store(':memory:');
    root = await Directory.systemTemp.createTemp('teamsync-review-test');
    team = store.createTeam('Team');
  });
  tearDown(() async {
    store.close();
    await root.delete(recursive: true);
  });

  test('legacy analysis and notebook export preserve tick notes without source paths or IDs', () async {
    final id = await importReview(store, root, team, encoded(analysis()));
    store.annotate(id, 64, 1, 'Контроль коннектора / hold connector');
    store.saveScouting(id, {
      'teams': 'A vs B',
      'tier': '1',
      'positions': 'AWP',
    });
    final row = store.demos(team).single;
    final note = store.annotations(id).single;
    final bytes = await exportReview(store, row);
    final payload = jsonDecode(utf8.decode(bytes)) as Map;
    final notebook = payload['notebook'] as Map;
    expect((notebook['annotations'] as List).single['tick'], 64);
    expect(utf8.decode(bytes), isNot(contains(root.path)));
    expect(utf8.decode(bytes), isNot(contains(id)));
    final copyTeam = store.createTeam('Other team');
    final copy = await importReview(store, root, copyTeam, bytes);
    final restored = store.annotations(copy).single;
    for (final key in ['tick', 'round', 'note', 'created_at']) {
      expect(restored[key], note[key]);
    }
    expect(restored['id'], isNot(note['id']));
    expect(store.demos(copyTeam).single['scouting'], row['scouting']);
    expect(
      decodeReview(
        await File(store.demos(copyTeam).single['analysis_path'] as String)
            .readAsString(),
      )['frames'],
      analysis()['frames'],
    );
  });

  test('invalid notebook rejects before persistence and forged paths are never extracted', () async {
    for (final note in [
      {
        'tick': 999,
        'round': 1,
        'note': 'bad',
        'created_at': '2026-11-02T12:00:00Z',
      },
      {
        'tick': 64,
        'round': 9,
        'note': 'bad',
        'created_at': '2026-11-02T12:00:00Z',
      },
      {
        'tick': 64,
        'round': 1,
        'note': '',
        'created_at': '2026-11-02T12:00:00Z',
      },
      {'tick': 64, 'round': 1, 'note': 'bad', 'created_at': 'invalid'},
    ]) {
      final data = analysis()
        ..['notebook'] = {
          'schema': 1,
          'annotations': [note],
          'scouting': {},
        };
      await expectLater(
        importReview(store, root, team, encoded(data)),
        throwsA(isA<DomainError>()),
      );
    }
    final data = analysis()
      ..['notebook'] = {
        'schema': 1,
        'annotations': [],
        'scouting': {'video_path': '/tmp/forged'},
      };
    await expectLater(
      importReview(store, root, team, encoded(data)),
      throwsA(isA<DomainError>()),
    );
    expect(store.demos(team), isEmpty);
    expect(
      await root.list(recursive: true).where((e) => e is File).toList(),
      isEmpty,
    );
  });

  test(
    'database failure rolls back imported analysis and removes created file',
    () async {
      store.db.execute(
        "CREATE TRIGGER fail_review BEFORE UPDATE OF analysis_path ON demos BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        importReview(store, root, team, encoded(analysis())),
        throwsA(isA<DomainError>()),
      );
      expect(store.demos(team), isEmpty);
      expect(
        await root.list(recursive: true).where((e) => e is File).toList(),
        isEmpty,
      );
    },
  );
}
