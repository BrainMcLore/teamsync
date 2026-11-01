import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'store.dart';

class ServerInstallJob extends ChangeNotifier {
  final Store store;
  final Directory root;
  final String? executable;
  Process? _process;
  bool running = false, cancelled = false, _disposed = false;
  String phase = 'idle', kind = '', error = '';
  double? progress, speed;
  int bytes = 0;
  ServerInstallJob(this.store, this.root, {this.executable});
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<String> install(String type, String parent) async {
    if (!Platform.isWindows ||
        running ||
        !['cs2', 'teamspeak'].contains(type)) {
      throw DomainError('jobBusy');
    }
    running = true;
    cancelled = false;
    error = '';
    kind = type;
    phase = 'starting';
    progress = null;
    bytes = 0;
    changed();
    String? installed;
    try {
      final worker = File(
        executable ??
            '${File(Platform.resolvedExecutable).parent.path}/demo-worker/teamsync-demo.exe',
      );
      if (!await worker.exists()) throw DomainError('workerMissing');
      store.setSetting('pc.installRoot', parent);
      final process = await Process.start(worker.path, [
        '--install-server',
        '--kind',
        type,
        '--destination',
        '$parent/TeamSyncServers/$type',
        '--cache',
        '${root.path}/server-downloads',
      ], runInShell: false);
      _process = process;
      if (cancelled) process.kill();
      final stderr = process.stderr.drain<void>(), done = Completer<void>();
      final subscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            try {
              final event = jsonDecode(line) as Map;
              phase = event['phase'] as String;
              progress = (event['progress'] as num?)?.toDouble();
              speed = (event['speed'] as num?)?.toDouble();
              bytes = event['bytes'] as int? ?? bytes;
              if (phase == 'error') {
                error = event['code'] as String? ?? 'server_install_failed';
              }
              if (phase == 'server_complete') {
                installed = event['path'] as String?;
              }
              changed();
            } catch (_) {}
          }, onDone: () => done.complete());
      try {
        final code = await process.exitCode.timeout(
          const Duration(hours: 4),
          onTimeout: () {
            process.kill();
            return -1;
          },
        );
        await done.future;
        await stderr;
        if (cancelled) throw DomainError('jobCancelled');
        if (code != 0 ||
            installed == null ||
            !await File(installed!).exists()) {
          throw DomainError(error.isEmpty ? 'server_install_failed' : error);
        }
        store.setSetting(type == 'cs2' ? 'pc.server' : 'pc.ts', installed!);
        store.setSetting('pc.installRoot', parent);
        phase = 'complete';
        return installed!;
      } finally {
        await subscription.cancel();
      }
    } catch (e) {
      error = e is DomainError ? e.code : 'server_install_failed';
      phase = cancelled ? 'cancelled' : 'error';
      rethrow;
    } finally {
      _process = null;
      running = false;
      changed();
    }
  }

  Future<void> cancel() async {
    cancelled = true;
    _process?.kill();
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelled = true;
    _process?.kill();
    super.dispose();
  }
}
