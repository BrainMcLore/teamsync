import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'store.dart';

class DemoJob extends ChangeNotifier {
  final Store store;
  final Directory root;
  final String? executable;
  Process? _process;
  String phase = 'idle';
  String? error;
  double? progress;
  double? speed;
  int bytes = 0;
  bool cancelled = false;
  bool _active = false;
  bool get running => _active;
  DemoJob(this.store, this.root, {this.executable});
  Future<void> cancel() async {
    if (!_active) return;
    cancelled = true;
    _process?.kill();
    phase = 'cancelled';
    notifyListeners();
  }

  Future<List<String>> runImport(
    String team,
    String input, {
    String? sourcePage,
  }) async {
    if (running) throw DomainError('jobBusy');
    _active = true;
    error = null;
    cancelled = false;
    phase = 'starting';
    progress = null;
    notifyListeners();
    final folder = Directory('${root.path}/demo-jobs/${Store.uuid.v4()}');
    final worker = File(
      executable ??
          '${File(Platform.resolvedExecutable).parent.path}/demo-worker/teamsync-demo.exe',
    );
    final args = [
      '--input',
      input,
      '--output',
      folder.path,
      if (sourcePage != null && sourcePage.isNotEmpty) ...[
        '--source-page',
        sourcePage,
      ],
    ];
    Map<String, dynamic>? result;
    bool keepFolder = false;
    try {
      await folder.create(recursive: true);
      if (!Platform.isWindows) throw DomainError('desktopParserRequired');
      if (!worker.existsSync()) throw DomainError('workerMissing');
      _process = await Process.start(
        worker.path,
        args,
        runInShell: false,
        workingDirectory: worker.parent.path,
        environment: {'TEAMSYNC_LANGUAGE': store.setting('language') ?? 'ru'},
      );
      if (cancelled) _process!.kill();
      final stderr = _process!.stderr.drain<void>();
      final outputDone = Completer<void>();
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              try {
                final event = jsonDecode(line) as Map<String, dynamic>;
                phase = event['phase'] as String;
                progress = (event['progress'] as num?)?.toDouble();
                speed = (event['speed'] as num?)?.toDouble();
                bytes = (event['bytes'] as int?) ?? bytes;
                if (phase == 'complete') result = event;
                if (phase == 'error') error = event['code'] as String?;
                notifyListeners();
              } catch (_) {
                /* Ignore non-protocol library output, never display parser internals. */
              }
            },
            onDone: () {
              if (!outputDone.isCompleted) outputDone.complete();
            },
            onError: (Object e) {
              if (!outputDone.isCompleted) outputDone.complete();
            },
          );
      final exit = await _process!.exitCode.timeout(
        Duration(minutes: input.startsWith('https://') ? 30 : 8),
        onTimeout: () {
          _process?.kill();
          throw DomainError('parseTimeout');
        },
      );
      await outputDone.future;
      await stderr;
      if (cancelled) throw DomainError('jobCancelled');
      if (exit != 0 || result == null) {
        throw DomainError(error ?? 'parseFailed');
      }
      final ids = <String>[];
      var newFiles = 0;
      store.transaction(() {
        for (final raw in result!['items'] as List) {
          final item = raw as Map;
          final duplicate = store.rows(
            'SELECT id FROM demos WHERE team_id=? AND sha256=?',
            [team, item['sha256']],
          ).firstOrNull;
          if (duplicate != null) {
            ids.add(duplicate['id'] as String);
            continue;
          }
          final existing = store.rows(
            'SELECT id FROM demos WHERE team_id=? AND path=? AND analysis_path IS NULL',
            [team, input],
          ).firstOrNull;
          String id;
          if (existing != null) {
            id = existing['id'] as String;
            store.db.execute('UPDATE demos SET path=?,size=? WHERE id=?', [
              item['path'],
              item['size'],
              id,
            ]);
          } else {
            store.addDemo(
              team,
              item['name'] as String,
              item['path'] as String,
              item['size'] as int,
            );
            id =
                store.rows('SELECT id FROM demos WHERE path=?', [
                      item['path'],
                    ]).single['id']
                    as String;
          }
          store.saveAnalysis(
            id,
            item['analysis'] as String,
            item['map'] as String,
            item['sha256'] as String,
            sourcePage: sourcePage,
            match: result!['match_id'] as String?,
            participants: jsonEncode(item['participants']),
          );
          ids.add(id);
          newFiles++;
        }
      });
      keepFolder = newFiles > 0;
      phase = 'complete';
      return ids;
    } catch (e) {
      phase = 'error';
      error = e is DomainError ? e.code : 'parseFailed';
      rethrow;
    } finally {
      _process = null;
      _active = false;
      final cacheRoot = Directory('${root.path}/demo-jobs').absolute.uri
          .normalizePath();
      if (!keepFolder &&
          folder.absolute.parent.uri.normalizePath() == cacheRoot &&
          await folder.exists()) {
        await folder.delete(recursive: true);
      }
      notifyListeners();
    }
  }
}
