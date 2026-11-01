import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/data/account.dart';
import 'package:teamsync/data/files.dart';
import 'package:teamsync/data/store.dart';
import 'package:teamsync/data/tactical_sync.dart';

class LiveAccount extends AccountClient {
  LiveAccount(super.address);
  @override
  Future<void> loadToken() async {
    token = Platform.environment['TEAMSYNC_DIAG_TOKEN'];
  }
}

void main() {
  test(
    'actual queued tactical operation synchronizes with hosted server',
    () async {
      final store = Store(Platform.environment['TEAMSYNC_DIAG_DB']!);
      try {
        final team = store.setting('team')!;
        final sync = TacticalSync(
          store,
          LocalFiles(Directory(Platform.environment['TEAMSYNC_DIAG_ROOT']!)),
          clientFactory: LiveAccount.new,
        );
        await sync.run(team, conflictLabel: 'Conflict copy');
        final state = jsonDecode(store.setting('tactical_sync_$team')!) as Map;
        expect(state['outbox'], isEmpty);
        expect(sync.conflicts, 0);
      } finally {
        store.close();
      }
    },
    skip: !Platform.environment.containsKey('TEAMSYNC_DIAG_TOKEN'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
