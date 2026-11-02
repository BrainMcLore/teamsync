import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/demo_jobs.dart';
import 'package:teamsync/data/review_data.dart';
import 'package:teamsync/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'frozen managed HLTV download reaches native library',
    () async {
      final root = Directory('../.tools/live-frozen-05').absolute;
      await root.create(recursive: true);
      final store = Store(':memory:');
      final job = DemoJob(
        store,
        root,
        executable: File(
          '../.tools/worker-dist/teamsync-demo/teamsync-demo.exe',
        ).absolute.path,
      );
      try {
        final team = store.createTeam('Managed download QA');
        final ids = await job.runImport(
          team,
          'https://www.hltv.org/download/demo/113273',
          sourcePage: 'https://www.hltv.org/matches/2399753/vitality-vs-natus-vincere-pgl-masters-bucharest-2026',
        );
        expect(ids, hasLength(3));
        final maps = <String>[];
        for (final row in store.demos(team)) {
          final data = await readReview(row['analysis_path'] as String);
          expect(data['players'], hasLength(10));
          maps.add(data['map'] as String);
        }
        expect(maps, unorderedEquals(['de_cache', 'de_mirage', 'de_dust2']));
        expect(job.bytes, 617663073);
      } on DomainError catch (error) {
        fail(
          'HLTV native import failed: code=${error.code}, phase=${job.phase}, bytes=${job.bytes}',
        );
      } finally {
        await job.cancel();
        store.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
    skip: Platform.environment['TEAMSYNC_LIVE_HLTV'] != '1',
  );
}
