import 'dart:io';
import 'dart:convert';

import '../data/server_install_job.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/pc_services.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'lan_match_setup.dart';

class BootcampPage extends StatefulWidget {
  final Store store;
  final LanHost host;
  final ServerInstallJob? installer;
  const BootcampPage({
    super.key,
    required this.store,
    required this.host,
    this.installer,
  });
  @override
  State<BootcampPage> createState() => _BootcampPageState();
}

class _BootcampPageState extends State<BootcampPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  Store get store => widget.store;
  LanHost get host => widget.host;
  PcInstallation? pc;
  List<String> addresses = [];
  bool working = false;
  late ServerInstallJob installer;
  @override
  void initState() {
    super.initState();
    host.addListener(refresh);
    installer =
        widget.installer ??
        ServerInstallJob(
          store,
          Directory('${Directory.systemTemp.path}/TeamSync-server-setup'),
        );
    installer.addListener(refresh);
    if (Platform.isWindows) load();
  }

  Future<void> load() async {
    final found = await PcInstallation.discover(store);
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    if (mounted) {
      setState(() {
        pc = found;
        addresses = [
          for (final i in interfaces)
            for (final a in i.addresses) '${i.name}: ${a.address}',
        ];
      });
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    host.removeListener(refresh);
    installer.removeListener(refresh);
    if (widget.installer == null) installer.dispose();
    super.dispose();
  }

  void notice(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  Future<void> downloadServer(String kind) async {
    final parent =
        store.setting('pc.installRoot') ??
        await getDirectoryPath(confirmButtonText: l.serverFolder);
    if (parent == null || !mounted) return;
    try {
      final path = await installer.install(kind, parent);
      await load();
      if (!mounted) return;
      notice(l.serverFilesReady);
      if (kind == 'teamspeak') await license(path);
    } catch (e) {
      if (mounted) {
        notice(
          e is DomainError && e.code == 'server_disk_space'
              ? l.serverDiskSpace
              : e is DomainError && e.code == 'jobCancelled'
              ? l.jobCancelled
              : l.serverSetupError,
        );
      }
    }
  }

  Future<void> license(String path) async {
    final file = File('${File(path).parent.path}/license.txt');
    if (!await file.exists() || await file.length() > 250000 || !mounted) {
      return;
    }
    final text = await file.readAsString(
      encoding: const Utf8Codec(allowMalformed: true),
    );
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _TsLicenseDialog(text: text),
    );
    if (accepted == true) {
      await File('${File(path).parent.path}/.ts3server_license_accepted')
          .writeAsString('', flush: true);
    }
  }

  String setupPhase() => switch (installer.phase) {
    'server_download' => l.jobDownload,
    'server_extract' => l.jobExtract,
    'server_installing' => l.serverContentDownload,
    'steamcmd' => l.steamcmdPreparing,
    'complete' => l.serverFilesReady,
    'cancelled' => l.jobCancelled,
    'error' => l.serverSetupError,
    _ => l.serverContentDownload,
  };
  Widget setupPanel() => StudioPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.downloadServerFiles,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Text(
          l.serverDownloadHelp,
          style: const TextStyle(color: Studio.muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: host.running || host.busy || installer.running
                  ? null
                  : () => downloadServer('cs2'),
              icon: const Icon(Icons.download_outlined),
              label: Text(l.downloadCsServer),
            ),
            FilledButton.tonalIcon(
              onPressed: host.running || host.busy || installer.running
                  ? null
                  : () => downloadServer('teamspeak'),
              icon: const Icon(Icons.download_outlined),
              label: Text(l.downloadTsServer),
            ),
            if (store.setting('pc.ts') != null)
              OutlinedButton(
                onPressed: installer.running || host.running
                    ? null
                    : () => license(store.setting('pc.ts')!),
                child: Text(l.tsLicense),
              ),
            OutlinedButton.icon(
              onPressed: installer.running || host.running
                  ? null
                  : () async {
                      final value = await getDirectoryPath(
                        confirmButtonText: l.serverFolder,
                      );
                      if (value != null && mounted) {
                        setState(
                          () => store.setSetting('pc.installRoot', value),
                        );
                      }
                    },
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l.serverFolder),
            ),
          ],
        ),
        if (store.setting('pc.installRoot') != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(
              '${store.setting('pc.installRoot')}/TeamSyncServers',
              style: const TextStyle(fontSize: 11, color: Studio.muted),
            ),
          ),
        if (installer.phase != 'idle') ...[
          const SizedBox(height: 16),
          Text('${installer.kind.toUpperCase()} · ${setupPhase()}'),
          const SizedBox(height: 10),
          if (installer.running)
            LinearProgressIndicator(value: installer.progress?.clamp(0.0, 1.0)),
          if (installer.progress != null)
            Text('${(installer.progress! * 100).toStringAsFixed(1)}%'),
          if (installer.running)
            TextButton.icon(
              onPressed: installer.cancel,
              icon: const Icon(Icons.close),
              label: Text(l.cancel),
            ),
          if (installer.error.isNotEmpty && !installer.running)
            Text(
              installer.error == 'server_disk_space'
                  ? l.serverDiskSpace
                  : l.serverSetupError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ],
    ),
  );
  Future<void> pick(String key, String expected) async {
    final value = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Windows', extensions: ['exe']),
      ],
    );
    if (value == null) return;
    try {
      if (value.name.toLowerCase() != expected) {
        throw DomainError('invalidExecutable');
      }
      if (expected == 'cs2.exe') PcInstallation.gameDirectory(value.path);
      if (key == 'pc.server' &&
          pc?.cs2 != null &&
          File(value.path).resolveSymbolicLinksSync().toLowerCase() ==
              File(pc!.cs2!).resolveSymbolicLinksSync().toLowerCase()) {
        throw DomainError('clientIsNotServer');
      }
      store.setSetting(key, value.path);
      await load();
    } catch (_) {
      if (mounted) notice(l.chooseExecutables);
    }
  }

  Future<void> start(bool game, bool voice) async {
    setState(() => working = true);
    try {
      await host.start(game: game, voice: voice);
    } catch (e) {
      if (mounted) {
        notice(
          e is DomainError && e.code == 'serverIncomplete'
              ? l.serverSetupError
              : e is DomainError && e.code == 'pluginMissing'
              ? l.installPlugin
              : e is DomainError && e.code == 'tsLicense'
              ? l.tsLicenseHelp
              : l.chooseExecutables,
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> stop(bool game, {bool restart = false}) async {
    setState(() => working = true);
    try {
      await host.stop(game);
      if (restart) await host.start(game: game, voice: !game);
    } catch (_) {
      if (mounted) notice(l.error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> command(String action) async {
    setState(() => working = true);
    try {
      final output = await host.command(action);
      host.log(output);
      if (mounted) notice(output.trim().isEmpty ? l.commandSent : output);
    } catch (_) {
      if (mounted) notice(l.pluginCommandFailed);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> setupMatch() async {
    try {
      await configureLanMatch(context, store, host);
    } catch (_) {
      if (mounted) notice(l.pluginCommandFailed);
    }
  }

  Future<void> installPlugin() async {
    final server = store.setting('pc.server');
    if (server == null) {
      notice(l.chooseServerInstallation);
      return;
    }
    setState(() => working = true);
    try {
      await host.installPlugin(server);
      if (mounted) notice(l.pluginInstalled);
    } catch (_) {
      if (mounted) notice(l.pluginInstallFailed);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget path(String key, String label, String exe, String? value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      value ?? '—',
      style: const TextStyle(fontSize: 11),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: IconButton(
      tooltip: label,
      onPressed: host.running || working || installer.running
          ? null
          : () => pick(key, exe),
      icon: const Icon(Icons.folder_open_outlined),
    ),
  );
  Widget server(bool game) {
    final process = game ? host.cs : host.ts,
        ready = game ? host.csReady : host.tsReady,
        exit = game ? host.csExit : host.tsExit;
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                game
                    ? Icons.sports_esports_outlined
                    : Icons.headset_mic_outlined,
                color: Studio.accent,
              ),
              const SizedBox(width: 12),
              Text(
                game ? 'CS2 · LAN' : 'TeamSpeak 3 · LAN',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            process != null
                ? (ready ? l.serverReady : l.serverStarting)
                : exit == null
                ? l.serverStopped
                : '${l.serverFailed} ($exit)',
            style: TextStyle(color: ready ? Studio.accent : Studio.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: working || installer.running
                    ? null
                    : process == null
                    ? () => start(game, !game)
                    : () => stop(game),
                icon: Icon(process == null ? Icons.play_arrow : Icons.stop),
                label: Text(process == null ? l.startServer : l.stopServer),
              ),
              OutlinedButton.icon(
                onPressed: working || process == null
                    ? null
                    : () => stop(game, restart: true),
                icon: const Icon(Icons.restart_alt),
                label: Text(l.restartServer),
              ),
              TextButton.icon(
                onPressed: process == null
                    ? null
                    : () => launchUrl(
                        Uri.parse(
                          game
                              ? 'steam://connect/127.0.0.1:${store.setting('pc.port') ?? '27015'}'
                              : 'ts3server://127.0.0.1?port=9987',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                icon: const Icon(Icons.open_in_new),
                label: Text(l.connectServer),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return Center(child: Text(l.localHostOnly));
    final enabled =
        !working && !host.running && !host.busy && !installer.running;
    final profile = store.setting('pc.profile') ?? 'scrim';
    return ListView(
      children: [
        StudioPageTitle(
          l.bootcamp,
          description: l.bootcampHelp,
          action: FilledButton.icon(
            onPressed: working || host.busy || installer.running
                ? null
                : () => start(true, true),
            icon: const Icon(Icons.play_arrow),
            label: Text(l.startBoth),
          ),
        ),
        setupPanel(),
        const SizedBox(height: 20),
        if (working)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              path('pc.cs2', l.csExecutable, 'cs2.exe', pc?.cs2),
              path('pc.steam', l.steamExecutable, 'steam.exe', pc?.steam),
              const Divider(),
              Text(
                l.chooseServerInstallation,
                style: const TextStyle(color: Studio.muted, height: 1.6),
              ),
              path(
                'pc.server',
                l.serverExecutable,
                'cs2.exe',
                store.setting('pc.server'),
              ),
              path(
                'pc.ts',
                l.tsExecutable,
                'ts3server.exe',
                store.setting('pc.ts'),
              ),
              Text(
                l.tsLicenseHelp,
                style: const TextStyle(fontSize: 12, color: Studio.muted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: profile,
                decoration: InputDecoration(labelText: l.serverProfile),
                items: [
                  DropdownMenuItem(value: 'scrim', child: Text(l.scrimProfile)),
                  DropdownMenuItem(
                    value: 'practice',
                    child: Text(l.practiceProfile),
                  ),
                ],
                onChanged: enabled
                    ? (v) {
                        if (v != null) {
                          setState(() => store.setSetting('pc.profile', v));
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: store.setting('pc.map') ?? 'de_mirage',
                decoration: InputDecoration(labelText: l.maps),
                items: [
                  for (final key in [
                    'de_mirage',
                    'de_dust2',
                    'de_inferno',
                    'de_nuke',
                    'de_ancient',
                    'de_anubis',
                    'de_train',
                    'de_overpass',
                    'de_vertigo',
                    'de_cache',
                  ])
                    DropdownMenuItem(value: key, child: Text(key)),
                ],
                onChanged: enabled
                    ? (v) {
                        if (v != null) store.setSetting('pc.map', v);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: store.setting('pc.port') ?? '27015',
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(labelText: l.serverPort),
                validator: (v) {
                  final port = int.tryParse(v ?? '');
                  return port == null || port < 1024 || port > 65535
                      ? l.invalidServerPort
                      : null;
                },
                onChanged: (v) {
                  final port = int.tryParse(v);
                  if (port != null && port >= 1024 && port <= 65535) {
                    store.setSetting('pc.port', '$port');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MatchZy 0.9.2 + CounterStrikeSharp + Metamod',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                l.pluginHelp,
                style: const TextStyle(color: Studio.muted, height: 1.6),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: enabled ? installPlugin : null,
                icon: const Icon(Icons.extension_outlined),
                label: Text(l.installPlugin),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Text(
                host.pluginLoaded ? l.pluginLoaded : l.pluginNotVerified,
                style: TextStyle(
                  color: host.pluginLoaded ? Studio.accent : Studio.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: host.cs == null || working ? null : setupMatch,
                    child: Text(l.matchSetup),
                  ),
                  OutlinedButton(
                    onPressed: host.cs == null || working
                        ? null
                        : () => command('practice'),
                    child: Text(l.applyPractice),
                  ),
                  OutlinedButton(
                    onPressed: host.cs == null || working
                        ? null
                        : () => command('scrim'),
                    child: Text(l.applyScrim),
                  ),
                  OutlinedButton(
                    onPressed: host.cs == null || working
                        ? null
                        : () => command('status'),
                    child: const Text('css_plugins list'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.pluginCommands,
                style: const TextStyle(fontSize: 12, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        server(true),
        const SizedBox(height: 20),
        server(false),
        const SizedBox(height: 20),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.lanAddress,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SelectableText(addresses.join('\n')),
              const SizedBox(height: 20),
              Text(
                l.bootcampLimits,
                style: const TextStyle(color: Studio.muted, height: 1.6),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.teamspeak.com/en/downloads?product=server',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.download),
                label: Text(l.getTeamspeak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.serverLog,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SelectableText(
                host.logs.isEmpty
                    ? l.noServerLogs
                    : host.logs.reversed.take(35).join('\n'),
                style: const TextStyle(fontSize: 11, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TsLicenseDialog extends StatefulWidget {
  final String text;
  const _TsLicenseDialog({required this.text});
  @override
  State<_TsLicenseDialog> createState() => _TsLicenseDialogState();
}

class _TsLicenseDialogState extends State<_TsLicenseDialog> {
  bool accepted = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.tsLicense),
      content: SizedBox(
        width: 700,
        height: 450,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.text,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ),
            CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: Text(l.acceptTsLicense),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: accepted ? () => Navigator.pop(context, true) : null,
          child: Text(l.continueLabel),
        ),
      ],
    );
  }
}
