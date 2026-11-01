import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/demo_jobs.dart';
import 'package:teamsync/data/review_data.dart';
import 'package:teamsync/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final executable = File(
        '../.tools/worker-dist/teamsync-demo/teamsync-demo.exe',
      ).absolute,
      fixture = File('../.tools/demo-fixtures/test_demo.dem').absolute;
  test(
    'native companion imports a real recording once for all ten players',
    () async {
      final root = Directory.systemTemp.createTempSync('teamsync_native_job_'),
          store = Store(':memory:');
      final job = DemoJob(store, root, executable: executable.path);
      try {
        final team = store.createTeam('Native parser QA');
        store.addDemo(
          team,
          'Existing imported recording',
          fixture.path,
          fixture.lengthSync(),
        );
        final oldId = store.demos(team).single['id'];
        final ids = await job.runImport(team, fixture.path);
        expect(ids, hasLength(1));
        expect(ids.single, oldId);
        expect(store.demos(team), hasLength(1));
        final row = store.demos(team).single;
        final data = await readReview(row['analysis_path'] as String);
        expect(data['map'], 'de_mirage');
        expect(data['players'], hasLength(10));
        expect(data['rounds'], hasLength(10));
        expect((row['participants'] as String), contains('NIGHTSOUL'));
        final again = await job.runImport(team, fixture.path);
        expect(again, ids);
        expect(store.demos(team), hasLength(1));
        expect(job.running, isFalse);
      } finally {
        await job.cancel();
        store.close();
        root.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip:
        !Platform.isWindows ||
        !executable.existsSync() ||
        !fixture.existsSync(),
  );
}
