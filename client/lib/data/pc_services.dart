import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import 'store.dart';

class PcInstallation {
  final String? steam, cs2;
  const PcInstallation(this.steam, this.cs2);
  static Future<PcInstallation> discover(Store store) async {
    if (!Platform.isWindows) return const PcInstallation(null, null);
    final roots = <String>{
      if (Platform.environment['ProgramFiles(x86)'] != null)
        '${Platform.environment['ProgramFiles(x86)']}\\Steam',
      if (Platform.environment['ProgramFiles'] != null)
        '${Platform.environment['ProgramFiles']}\\Steam',
    };
    // Steam supports a custom install location; query its per-user key read-only.
    try {
      final result = await Process.run('reg.exe', [
        'query',
        r'HKCU\Software\Valve\Steam',
        '/v',
        'SteamPath',
      ]);
      final match = RegExp(r'SteamPath\s+REG_SZ\s+(.+)')
          .firstMatch(result.stdout as String);
      if (match != null) roots.add(match.group(1)!.trim());
    } catch (_) {
      /* Native picker remains available. */
    }
    final steamOverride = store.setting('pc.steam');
    final csOverride = store.setting('pc.cs2');
    String? steam = steamOverride != null && File(steamOverride).existsSync()
        ? steamOverride
        : null;
    String? cs = csOverride != null && File(csOverride).existsSync()
        ? csOverride
        : null;
    final libraries = <String>{...roots};
    for (final root in roots) {
      if (steam == null && File('$root/steam.exe').existsSync()) {
        steam = '$root/steam.exe';
      }
      final vdf = File('$root/steamapps/libraryfolders.vdf');
      if (await vdf.exists()) {
        final text = await vdf.readAsString();
        for (final match in RegExp(r'"path"\s+"([^"]+)"').allMatches(text)) {
          libraries.add(match.group(1)!.replaceAll(r'\\', r'\'));
        }
      }
    }
    for (final root in libraries) {
      final path =
          '$root/steamapps/common/Counter-Strike Global Offensive/game/bin/win64/cs2.exe';
      if (cs == null && await File(path).exists()) cs = path;
    }
    return PcInstallation(steam, cs);
  }

  static Directory gameDirectory(String cs2) {
    final bin = File(cs2).absolute.parent.parent;
    final game = bin.parent;
    if (bin.uri.pathSegments.where((s) => s.isNotEmpty).last.toLowerCase() !=
            'bin' ||
        !Directory('${game.path}/csgo').existsSync()) {
      throw DomainError('invalidCsPath');
    }
    return game;
  }
}

class DemoLaunchPlan {
  final String steam, command, copiedPath;
  final List<String> arguments;
  DemoLaunchPlan(this.steam, this.command, this.copiedPath)
    : arguments = [
        '-applaunch',
        '730',
        '+playdemo',
        command.substring('playdemo '.length),
      ];
}

class PcDemoLauncher {
  static Future<DemoLaunchPlan> prepare(
    Store store,
    String source, {
    PcInstallation? installation,
  }) async {
    final pc = installation ?? await PcInstallation.discover(store);
    if (pc.cs2 == null || pc.steam == null) throw DomainError('gameMissing');
    final original = File(source);
    if (!source.toLowerCase().endsWith('.dem') || !await original.exists()) {
      throw DomainError('fileMissing');
    }
    final size = await original.length();
    if (size < 16 || size > 2 * 1024 * 1024 * 1024) {
      throw DomainError('invalidDemo');
    }
    final handle = await original.open();
    try {
      final header = await handle.read(8);
      if (header.length != 8 ||
          header[7] != 0 ||
          ascii.decode(header.take(7).toList(), allowInvalid: true) !=
              'PBDEMS2') {
        throw DomainError('invalidDemo');
      }
    } finally {
      await handle.close();
    }
    final folder = Directory(
      '${PcInstallation.gameDirectory(pc.cs2!).path}/csgo/replays',
    );
    await folder.create(recursive: true);
    // Only our safe generated filename enters a CS console command, never a user path.
    final hash = await sha256.bind(original.openRead()).first;
    final name = 'teamsync_$hash.dem';
    var destination = File('${folder.path}/$name');
    if (!await destination.exists() ||
        (await sha256.bind(destination.openRead()).first) != hash) {
      destination = await original.copy(destination.path);
    }
    return DemoLaunchPlan(
      pc.steam!,
      'playdemo replays/$name',
      destination.path,
    );
  }

  static Future<void> launch(DemoLaunchPlan plan) async {
    await Process.start(
      plan.steam,
      plan.arguments,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }
}

/// Owns only processes started by this application. No taskkill, shell, remote
/// commands, firewall edits or automatic licence acceptance.
class LanHost extends ChangeNotifier {
  final Store store;
  Process? cs, ts;
  bool csReady = false, tsReady = false, busy = false;
  int? csExit, tsExit;
  String? _rcon;
  bool pluginLoaded = false, _activating = false;
  String pluginProgress = '';
  Future<void> installPlugin(String server) async {
    if (running || busy) throw DomainError('serverBusy');
    busy = true;
    changed();
    try {
      final executable = File(
        '${File(Platform.resolvedExecutable).parent.path}/demo-worker/teamsync-demo.exe',
      );
      if (!await executable.exists()) throw DomainError('workerMissing');
      final cache = Directory(
        '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}/TeamSync/plugin-cache',
      );
      final process = await Process.start(executable.path, [
        '--install-plugin',
        '--server',
        server,
        '--cache',
        cache.path,
      ], runInShell: false);
      final errors = process.stderr.drain<void>();
      final output = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            try {
              final event = jsonDecode(line) as Map;
              pluginProgress = '${event['phase']} ${event['package'] ?? ''}';
              log('$pluginProgress ${event['code'] ?? ''}');
            } catch (_) {}
          });
      final code = await process.exitCode.timeout(
        const Duration(minutes: 8),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await errors;
      await output.cancel();
      if (code != 0) throw DomainError('pluginInstallFailed');
    } finally {
      busy = false;
      changed();
    }
  }

  final List<String> logs = [];
  Timer? _probe;
  bool _disposed = false;
  LanHost(this.store);
  bool get running => cs != null || ts != null;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void log(String message) {
    logs.add('${DateTime.now().toIso8601String().substring(11, 19)} $message');
    if (logs.length > 180) logs.removeRange(0, logs.length - 180);
    changed();
  }

  static List<String> csArguments(String map, String profile, int port) {
    if (!RegExp(r'^(de|cs)_[a-z0-9_]+$').hasMatch(map) ||
        !['practice', 'scrim'].contains(profile) ||
        port < 1024 ||
        port > 65535) {
      throw DomainError('invalidHostSettings');
    }
    return [
      '-dedicated',
      '-insecure',
      '-console',
      '-usercon',
      '-ip',
      '0.0.0.0',
      '-port',
      '$port',
      '+sv_lan',
      '1',
      '+game_type',
      '0',
      '+game_mode',
      '1',
      '+map',
      map,
      if (profile == 'practice') ...[
        '+sv_cheats',
        '1',
        '+bot_kick',
        '+mp_warmup_end',
        '+mp_roundtime_defuse',
        '60',
        '+mp_freezetime',
        '0',
        '+sv_infinite_ammo',
        '1',
        '+mp_buy_anywhere',
        '1',
        '+mp_buytime',
        '9999',
      ],
      if (profile == 'scrim') ...[
        '+sv_cheats',
        '0',
        '+mp_maxrounds',
        '24',
        '+mp_freezetime',
        '15',
      ],
    ];
  }

  Future<void> start({required bool game, required bool voice}) async {
    if (!Platform.isWindows || busy) return;
    busy = true;
    changed();
    try {
      // Validate both before launching either one.
      final pc = PcInstallation(null, store.setting('pc.server'));
      final tsPath = store.setting('pc.ts');
      if (game &&
          cs == null &&
          (pc.cs2 == null || !File(pc.cs2!).existsSync())) {
        throw DomainError('serverMissing');
      }
      if (voice &&
          ts == null &&
          (tsPath == null || !File(tsPath).existsSync())) {
        throw DomainError('serverMissing');
      }
      for (final entry in [
        if (game && pc.cs2 != null)
          File(
            '${PcInstallation.gameDirectory(pc.cs2!).parent.path}/.teamsync-install.json',
          ),
        if (voice && tsPath != null)
          File('${File(tsPath).parent.path}/.teamsync-install.json'),
      ]) {
        if (entry.existsSync() &&
            (jsonDecode(entry.readAsStringSync()) as Map)['state'] !=
                'installed') {
          throw DomainError('serverIncomplete');
        }
      }
      if (voice &&
          ts == null &&
          !File('${File(tsPath!).parent.path}/.ts3server_license_accepted')
              .existsSync()) {
        throw DomainError('tsLicense');
      }
      if (game && cs == null) {
        final port = int.tryParse(store.setting('pc.port') ?? '') ?? 27015;
        final arguments = csArguments(
          store.setting('pc.map') ?? 'de_mirage',
          store.setting('pc.profile') ?? 'scrim',
          port,
        );
        _rcon = Store.uuid.v4().replaceAll('-', '');
        pluginLoaded = false;
        await configureMatchZy(pc.cs2!, store.setting('pc.profile') ?? 'scrim');
        final process = await Process.start(
          pc.cs2!,
          [...arguments, '+rcon_password', _rcon!],
          workingDirectory: PcInstallation.gameDirectory(pc.cs2!).path,
          runInShell: false,
        );
        cs = process;
        csExit = null;
        csReady = false;
        watch(process, true);
        log('CS2 PID ${process.pid}');
      }
      if (voice && ts == null) {
        final process = await Process.start(
          tsPath!,
          [
            'query_ip=127.0.0.1',
            'query_ssh_ip=127.0.0.1',
            'query_http_ip=127.0.0.1',
            'query_protocols=raw',
          ],
          workingDirectory: File(tsPath).parent.path,
          runInShell: false,
        );
        ts = process;
        tsExit = null;
        tsReady = false;
        watch(process, false);
        log('TS3 PID ${process.pid}');
      }
      _probe ??= Timer.periodic(const Duration(seconds: 3), (_) => probe());
    } finally {
      busy = false;
      changed();
    }
  }

  void watch(Process process, bool game) {
    // TS first-run admin privilege keys may appear in its output. Keep TS output
    // in its own server logs, not in app logs or exported diagnostics.
    for (final stream in [process.stdout, process.stderr]) {
      stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
            if (game && line.isNotEmpty) {
              final clean = _rcon == null
                  ? line
                  : line.replaceAll(_rcon!, '[private]');
              log(
                'CS2 ${clean.length > 400 ? clean.substring(0, 400) : clean}',
              );
              if (RegExp(
                r'(loaded plugin.*MatchZy|MatchZy.*loaded|MatchZy.*initialized)',
                caseSensitive: false,
              ).hasMatch(line)) {
                pluginLoaded = true;
                if (store.setting('pc.profile') == 'practice' && !_activating) {
                  _activating = true;
                  Future<void>.delayed(const Duration(seconds: 3), () async {
                    try {
                      if (cs != null) await command('practice');
                    } catch (_) {
                      log('Practice: use .prac in game');
                    }
                    _activating = false;
                  });
                }
              }
            }
          }, onError: (_) {});
    }
    process.exitCode.then((code) {
      if (game && identical(cs, process)) {
        cs = null;
        csReady = false;
        csExit = code;
        _rcon = null;
        pluginLoaded = false;
      }
      if (!game && identical(ts, process)) {
        ts = null;
        tsReady = false;
        tsExit = code;
      }
      log('${game ? 'CS2' : 'TS3'} exit $code');
      if (!running) {
        _probe?.cancel();
        _probe = null;
      }
    });
  }

  Future<void> probe() async {
    if (cs != null) {
      csReady = await a2sReady(
        int.tryParse(store.setting('pc.port') ?? '') ?? 27015,
      );
    }
    if (ts != null) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          10011,
          timeout: const Duration(milliseconds: 600),
        );
        tsReady = true;
        socket.destroy();
      } catch (_) {
        tsReady = false;
      }
    }
    changed();
  }

  static Future<bool> a2sReady(int port) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    final result = Completer<bool>();
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final query = [
        255,
        255,
        255,
        255,
        0x54,
        ...ascii.encode('Source Engine Query'),
        0,
      ];
      final target = socket;
      sub = target.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = target.receive();
        if (datagram == null ||
            datagram.port != port ||
            datagram.data.length < 5) {
          return;
        }
        final bytes = datagram.data;
        if (!bytes.take(4).every((b) => b == 255)) return;
        if (bytes[4] == 0x41 && bytes.length >= 9) {
          target.send(
            [...query, ...bytes.sublist(5, 9)],
            InternetAddress.loopbackIPv4,
            port,
          );
        } else if (bytes[4] == 0x49 && !result.isCompleted) {
          result.complete(true);
        }
      });
      target.send(query, InternetAddress.loopbackIPv4, port);
      return await result.future.timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }

  static Future<void> configureMatchZy(String server, String profile) async {
    final root = Directory('${PcInstallation.gameDirectory(server).path}/csgo');
    if (!File(
      '${root.path}/addons/counterstrikesharp/plugins/MatchZy/MatchZy.dll',
    ).existsSync()) {
      throw DomainError('pluginMissing');
    }
    final file = File('${root.path}/cfg/MatchZy/config_override.cfg');
    final original = await file.exists() ? await file.readAsString() : '';
    if (original.isNotEmpty &&
        !File('${file.path}.teamsync-before').existsSync()) {
      await File('${file.path}.teamsync-before')
          .writeAsString(original, flush: true);
    }
    final cleaned = original.replaceAll(
      RegExp(
        r'// TeamSync begin[\s\S]*?// TeamSync end\r?\n?',
        multiLine: true,
      ),
      '',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '$cleaned\n// TeamSync begin\nmatchzy_autostart_mode ${profile == 'practice' ? 2 : 1}\nmatchzy_minimum_ready_required 10\nmatchzy_knife_enabled_default true\n// TeamSync end\n',
      flush: true,
    );
  }

  static const commands = <String, String>{
    'practice': 'css_prac',
    'scrim': 'css_exitprac',
    'pause': 'css_forcepause',
    'unpause': 'css_forceunpause',
    'knife': 'css_roundknife',
    'start': 'css_start',
    'status': 'css_plugins list',
    'veto': 'matchzy_loadmatch cfg/teamsync_match.json',
    'stop': 'quit',
  };
  Future<String> command(String action) async {
    if (cs == null || _rcon == null || !commands.containsKey(action)) {
      throw DomainError('serverNotRunning');
    }
    return SourceRcon.execute(
      int.tryParse(store.setting('pc.port') ?? '') ?? 27015,
      _rcon!,
      commands[action]!,
    );
  }

  Future<void> stop(bool game) async {
    final process = game ? cs : ts;
    if (process == null) return;
    // CS2 supports console quit. TS3 Windows has no stdin shutdown; terminate
    // only our process. Existing third-party servers are never stopped.
    if (game) {
      try {
        await command('stop');
      } catch (_) {}
      try {
        process.stdin.writeln('quit');
        await process.stdin.flush();
      } catch (_) {}
      try {
        await process.exitCode.timeout(const Duration(seconds: 4));
        return;
      } catch (_) {}
    }
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 4),
      onTimeout: () => -1,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _probe?.cancel();
    cs?.kill();
    ts?.kill();
    super.dispose();
  }
}

class SourceRcon {
  static Uint8List packet(int id, int type, String value) {
    final body = utf8.encode(value), bytes = Uint8List(body.length + 14);
    final data = ByteData.sublistView(bytes);
    data.setInt32(0, body.length + 10, Endian.little);
    data.setInt32(4, id, Endian.little);
    data.setInt32(8, type, Endian.little);
    bytes.setRange(12, 12 + body.length, body);
    return bytes;
  }

  static Future<String> execute(
    int port,
    String password,
    String command,
  ) async {
    final socket = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: const Duration(seconds: 2),
    );
    final done = Completer<String>();
    var buffer = <int>[], authenticated = false;
    final sub = socket.listen(
      (chunk) {
        buffer.addAll(chunk);
        while (buffer.length >= 4) {
          final size = ByteData.sublistView(
            Uint8List.fromList(buffer.sublist(0, 4)),
          ).getInt32(0, Endian.little);
          if (size < 10 || size > 1024 * 1024) {
            if (!done.isCompleted) {
              done.completeError(DomainError('rconProtocol'));
            }
            return;
          }
          if (buffer.length < size + 4) break;
          final frame = Uint8List.fromList(buffer.sublist(0, size + 4));
          buffer = buffer.sublist(size + 4);
          final header = ByteData.sublistView(frame),
              id = header.getInt32(4, Endian.little),
              type = header.getInt32(8, Endian.little);
          if (id == -1) {
            if (!done.isCompleted) done.completeError(DomainError('rconAuth'));
          } else if (!authenticated && id == 1 && type == 2) {
            authenticated = true;
            socket.add(packet(2, 2, command));
          } else if (authenticated && id == 2 && !done.isCompleted) {
            done.complete(
              utf8.decode(
                frame.sublist(12, frame.length - 2),
                allowMalformed: true,
              ),
            );
          }
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.completeError(DomainError('rconClosed'));
      },
    );
    try {
      socket.add(packet(1, 3, password));
      return await done.future.timeout(const Duration(seconds: 4));
    } finally {
      await sub.cancel();
      socket.destroy();
    }
  }
}
