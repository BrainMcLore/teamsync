import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'store.dart';

class HltvClient {
  final Directory root;
  final String? executable;
  Process? _process;
  HltvClient(this.root, {this.executable});
  Directory get cache => Directory('${root.path}/hltv-cache');
  Future<Map<String, dynamic>?> cached(int offset) async {
    final file = File('${cache.path}/results-$offset.json');
    try {
      if (await file.length() > 2 * 1024 * 1024) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetch({
    int offset = 0,
    String? match,
    bool force = false,
  }) async {
    if (!Platform.isWindows) throw DomainError('desktopParserRequired');
    final file = File(
      executable ??
          '${File(Platform.resolvedExecutable).parent.path}/demo-worker/teamsync-demo.exe',
    );
    if (!await file.exists()) throw DomainError('workerMissing');
    await cache.create(recursive: true);
    final process = await Process.start(file.path, [
      '--hltv',
      '--cache',
      cache.path,
      if (match != null) ...['--match', match] else ...['--offset', '$offset'],
      if (force) '--force',
    ], runInShell: false);
    _process = process;
    final stderr = process.stderr.drain<void>();
    Map<String, dynamic>? result;
    String? error;
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.length > 2 * 1024 * 1024) return;
          try {
            final value = jsonDecode(line) as Map;
            if (value['phase'] == 'catalog_complete') {
              result = value['data'] as Map<String, dynamic>;
            }
            if (value['phase'] == 'error') error = value['code'] as String?;
          } catch (_) {}
        });
    final done = Completer<void>();
    lines.onDone(() => done.complete());
    try {
      final code = await process.exitCode.timeout(
        const Duration(minutes: 6),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await done.future;
      await stderr;
      if (code != 0 || result == null) {
        throw DomainError(error ?? 'catalog_failed');
      }
      return result!;
    } finally {
      _process = null;
      await lines.cancel();
    }
  }

  void cancel() {
    _process?.kill();
  }
}
