import 'dart:io';
import 'dart:async';

import 'kit.dart';
import 'studio_shell.dart';
import 'map_detail.dart';
import 'demo_hub.dart';
import 'bootcamp.dart';
import 'playbook_editor.dart';
import '../data/pc_services.dart';
import '../data/server_install_job.dart';
import '../data/demo_jobs.dart';
import '../data/tactical_sync.dart';
import '../data/account_roster.dart';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../data/files.dart';
import '../data/playbook.dart';
import '../data/offline_package.dart';
import '../l10n/app_localizations.dart';
import 'editor.dart';
import 'account_page.dart';
import 'utilities_page.dart';
import 'task_history_dialog.dart';
import 'task_form.dart';
import 'preparation_wizard.dart';
import '../data/task_history.dart';

class Workspace extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  final ValueChanged<String> onLocale;
  final TacticalSync? sync;
  const Workspace({
    super.key,
    required this.store,
    required this.files,
    required this.onLocale,
    this.sync,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  Store get db => widget.store;
  AppLocalizations get l => AppLocalizations.of(context);
  String? teamId;
  int page = 0;
  String query = "";
  bool busy = false;
  late DemoJob demoJob;
  late LanHost lanHost;
  late ServerInstallJob serverInstaller;
  late TacticalSync tacticalSync;
  Timer? syncTimer, syncDebounce;
  bool syncing = false, syncAgain = false;
  String? syncError;
  List<RecordData> get onlineTeams => visibleAccountTeams(db);
  bool get shared =>
      teamId != null && onlineTeams.any((t) => t['id'] == teamId);
  String get syncLabel => syncing
      ? l.syncWorking
      : syncError == 'conflicts'
      ? l.syncConflict
      : syncError == 'readOnlyPending'
      ? l.syncReadOnlyPending
      : syncError == 'media_quota'
      ? l.syncMediaQuota
      : syncError == 'fileMissing'
      ? l.fileMissing
      : syncError == 'pending'
      ? l.syncWorking
      : syncError == 'syncAccountMismatch'
      ? l.syncAccountMismatch
      : syncError == 'unauthorized'
      ? l.sessionExpired
      : ['forbidden', 'not_found'].contains(syncError)
      ? l.syncAccessLost
      : syncError != null
      ? l.syncOffline
      : l.syncReady;
  Future<void> syncNow() async {
    if (!shared || !mounted) return;
    if (syncing || tacticalSync.running) {
      syncAgain = true;
      return;
    }
    syncAgain = false;
    final selected = teamId!;
    syncTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        syncNow();
      }
    });
    setState(() {
      syncing = true;
      syncError = null;
    });
    try {
      await tacticalSync.run(selected, conflictLabel: l.syncConflictCopy);
      if (mounted && teamId == selected) {
        syncError = tacticalSync.conflicts > 0
            ? 'conflicts'
            : tacticalSync.blockedByRole
            ? 'readOnlyPending'
            : tacticalSync.deferred
            ? 'pending'
            : null;
      }
    } catch (e) {
      if (mounted && teamId == selected) {
        syncError = e is DomainError ? e.code : 'offline';
      }
    } finally {
      if (mounted) {
        setState(() => syncing = false);
        if ((teamId != selected || syncAgain) && shared) {
          scheduleMicrotask(syncNow);
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tacticalSync = widget.sync ?? TacticalSync(db, widget.files);
    db.onTeamChange = () {
      if (!mounted) return;
      final selected = db.setting('team');
      if (selected == null || !onlineTeams.any((t) => t['id'] == selected)) {
        return;
      }
      widget.files.catalog?.ensureTeam(db, selected);
      setState(() => teamId = selected);
      syncNow();
    };
    db.onTacticalChange = () {
      if (!shared) return;
      syncDebounce?.cancel();
      syncDebounce = Timer(const Duration(milliseconds: 800), syncNow);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncNow();
    });
    demoJob = DemoJob(db, widget.files.root);
    lanHost = LanHost(db);
    serverInstaller = ServerInstallJob(db, widget.files.root);
    final teams = onlineTeams;
    for (final team in teams) {
      widget.files.catalog?.ensureTeam(db, team["id"] as String);
    }
    final saved = db.setting('team');
    teamId = teams.any((e) => e['id'] == saved)
        ? saved
        : teams.firstOrNull?['id'] as String?;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncTimer?.cancel();
    syncDebounce?.cancel();
    db.onTacticalChange = null;
    db.onTeamChange = null;
    demoJob.cancel();
    lanHost.dispose();
    serverInstaller.dispose();
    super.dispose();
  }

  void refresh() => setState(() {});
  Future<void> openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AccountPage(store: db, onLocale: widget.onLocale),
      ),
    );
    if (!mounted) return;
    for (final team in db.teams) {
      widget.files.catalog?.ensureTeam(db, team['id'] as String);
    }
    setState(() {
      final selected = db.setting('team');
      teamId = onlineTeams.any((t) => t['id'] == selected)
          ? selected
          : onlineTeams.firstOrNull?['id'] as String?;
    });
    await syncNow();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  String errorText(Object error) =>
      switch (error is DomainError ? error.code : 'error') {
        'invalidText' => l.invalidText,
        'conflict' => l.conflict,
        'invalidImage' => l.invalidImage,
        'invalidDemo' => l.invalidDemo,
        'fileMissing' => l.fileMissing,
        'packageError' => l.packageError,
        'readOnlyTeam' => l.readOnlyTeam,
        _ => l.error,
      };
  Future<void> act(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
      if (mounted) refresh();
    } catch (e) {
      if (mounted) message(errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, String>?> form(
    String title,
    Map<String, String> fields, {
    Map<String, List<(String, String)>> choices = const {},
  }) async {
    final controllers = {
      for (final key in fields.keys) key: TextEditingController(),
    };
    final values = {for (final e in choices.entries) e.key: e.value.first.$1};
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: controllers[e.key],
                          autofocus: e.key == fields.keys.first,
                          maxLength: e.key == 'notes'
                              ? 20000
                              : e.key == 'reason'
                              ? 2000
                              : 120,
                          minLines: ['notes', 'reason'].contains(e.key) ? 3 : 1,
                          maxLines: ['notes', 'reason'].contains(e.key) ? 5 : 1,
                          decoration: InputDecoration(labelText: e.value),
                          validator: (v) =>
                              e.key != 'notes' &&
                                  (v == null || v.trim().isEmpty)
                              ? l.invalidText
                              : null,
                        ),
                      ),
                    for (final e in choices.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: values[e.key],
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: switch (e.key) {
                              'map' => l.selectMap,
                              'side' => l.side,
                              'role' => l.role,
                              'member' => l.assignee,
                              'strategy' => l.strategyLink,
                              _ => e.key,
                            },
                          ),
                          items: e.value
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.$1,
                                  child: Text(
                                    v.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => update(() => values[e.key] = v!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    for (final e in controllers.entries)
                      e.key: e.value.text.trim(),
                    ...values,
                  });
                }
              },
              child: Text(l.create),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), () {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
    return result;
  }

  Future<void> createTeam() async {
    await openAccount();
  }

  Future<void> addMap() async {
    final v = await form(l.addMap, {'name': l.name});
    if (v != null) db.addMap(teamId!, v['name']!);
  }

  Future<void> addMember() async {
    final v = await form(
      l.addMember,
      {'name': l.name, 'gameRole': l.gameRole},
      choices: {
        'role': [
          ('player', l.player),
          ('captain', l.captain),
          ('coach', l.coach),
          ('owner', l.owner),
          ('viewer', l.viewer),
        ],
      },
    );
    if (v != null) {
      db.addMember(teamId!, v['name']!, v['role']!, v['gameRole']!);
    }
  }

  Future<void> createStrategy([
    String? selectedMap,
    String level = 'default',
  ]) async {
    final maps = db.maps(teamId!);
    if (selectedMap != null) {
      maps.sort(
        (a, b) => a["id"] == selectedMap
            ? -1
            : b["id"] == selectedMap
            ? 1
            : 0,
      );
    }
    if (maps.isEmpty) {
      message(l.emptyMaps);
      return;
    }
    final v = await form(
      l.newStrategy,
      {'title': l.title},
      choices: {
        'map': maps
            .map((e) => (e['id'] as String, e['name'] as String))
            .toList(),
        'side': [('T', 'T'), ('CT', 'CT')],
      },
    );
    if (v == null) return;
    final id = db.createStrategy(
      v['map']!,
      v['title']!,
      v['side']!,
      level: level,
    );
    if (mounted) await openStrategy(id);
  }

  Future<void> createTask({String? strategy}) async {
    await showDialog<String>(
      context: context,
      builder: (_) => TaskForm(store: db, team: teamId!, strategy: strategy),
    );
  }

  Future<void> openStrategy(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrategyEditor(
          store: db,
          files: widget.files,
          id: id,
          onTask: () => createTask(strategy: id),
        ),
      ),
    );
    if (mounted) {
      refresh();
      syncNow();
    }
  }

  Widget language() => DropdownButton<String>(
    value: Localizations.localeOf(context).languageCode,
    underline: const SizedBox.shrink(),
    items: const [
      DropdownMenuItem(value: 'ru', child: Text('Русский')),
      DropdownMenuItem(value: 'en', child: Text('English')),
    ],
    onChanged: (value) {
      if (value != null) widget.onLocale(value);
    },
  );
  List<(String, IconData)> get destinations => [
    (l.overview, Icons.space_dashboard_outlined),
    (l.maps, Icons.map_outlined),
    (l.strategies, Icons.route_outlined),
    (l.training, Icons.checklist_outlined),
    (l.demos, Icons.movie_outlined),
    (l.team, Icons.groups_outlined),
    (l.settings, Icons.settings_outlined),
    (l.playbooks, Icons.picture_as_pdf_outlined),
    (l.bootcamp, Icons.dns_outlined),
    (l.utilityLibrary, Icons.sports_baseball_outlined),
  ];
  Widget empty(String text, IconData icon) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    ),
  );
  Widget info(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
  Widget heading(String title, {String? action, VoidCallback? onAction}) =>
      StudioPageTitle(
        title,
        action: action == null
            ? null
            : FilledButton.icon(
                onPressed: busy ? null : onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(action),
              ),
      );
  bool matches(String text) => text.toLowerCase().contains(query.toLowerCase());
  String? cover(RecordData map) =>
      widget.files.catalog?.thumbnail(map['catalog_id'] as String? ?? '');
  Future<void> openMap(RecordData map) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MapDetailPage(
          map: map,
          files: widget.files,
          onPrepare: db.canEditTeam(map['team_id'] as String)
              ? () async {
                  final count = await showDialog<int>(
                    context: context,
                    builder: (_) => PreparationWizard(
                      store: db,
                      team: map['team_id'] as String,
                      map: map['id'] as String,
                    ),
                  );
                  if (count != null && mounted) {
                    refresh();
                    message(l.prepCreated(count));
                  }
                }
              : null,
          onStrategy: (level) {
            Navigator.pop(context);
            act(() => createStrategy(map['id'] as String, level));
          },
        ),
      ),
    );
    if (mounted) refresh();
  }

  Widget overview() {
    final tasks = db.tasks(teamId!),
        maps = db.maps(teamId!),
        strategies = db.strategies(teamId!);
    final approved = tasks.where((t) => t['status'] == 'approved').length;
    return ListView(
      children: [
        StudioPageTitle(l.overview, description: l.workspaceSubtitle),
        LayoutBuilder(
          builder: (context, c) {
            final readiness = StudioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.readiness,
                    style: const TextStyle(color: Studio.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tasks.isEmpty ? l.noData : '$approved / ${tasks.length}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (tasks.isNotEmpty)
                    LinearProgressIndicator(
                      value: approved / tasks.length,
                      minHeight: 4,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l.readinessDetail,
                    style: const TextStyle(
                      color: Studio.muted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            );
            final focus = StudioPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusTag(
                    l.preparation,
                    color: Studio.accent,
                    icon: Icons.route_outlined,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l.nextSteps,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.nextStepsBody,
                    style: const TextStyle(
                      color: Studio.muted,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => act(createStrategy),
                        icon: const Icon(Icons.add, size: 17),
                        label: Text(l.newStrategy),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => page = 3),
                        icon: const Icon(Icons.checklist, size: 17),
                        label: Text(l.taskCount(tasks.length)),
                      ),
                    ],
                  ),
                ],
              ),
            );
            return c.maxWidth > 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: focus),
                      const SizedBox(width: 20),
                      Expanded(child: readiness),
                    ],
                  )
                : Column(
                    children: [focus, const SizedBox(height: 16), readiness],
                  );
          },
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Text(
                l.yourMapPool,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => page = 1),
              child: Text(l.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: maps.length,
            separatorBuilder: (_, i) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final m = maps[i];
              return SizedBox(
                width: 225,
                child: InkWell(
                  onTap: () => openMap(m),
                  child: MapCover(
                    path: cover(m),
                    overlay: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            m['name'] as String,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            m['catalog_id'] as String? ?? l.customMap,
                            style: const TextStyle(
                              color: Studio.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Text(
                l.recentStrategies,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => page = 2),
              child: Text(l.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (strategies.isEmpty)
          StudioPanel(
            child: Text(
              l.emptyStrategies,
              style: const TextStyle(color: Studio.muted),
            ),
          )
        else
          for (final strategy in strategies.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StudioPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: StatusTag(
                    strategy['side'] as String,
                    color: strategy['side'] == 'T' ? Studio.t : Studio.ct,
                  ),
                  title: Text(
                    strategy['title'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    strategy['map_name'] as String,
                    style: const TextStyle(fontSize: 11, color: Studio.muted),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Studio.muted,
                  ),
                  onTap: () => openStrategy(strategy['id'] as String),
                ),
              ),
            ),
      ],
    );
  }

  Widget mapsPage() {
    final maps = db
        .maps(teamId!)
        .where((m) => matches('${m['name']} ${m['catalog_id']}'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioPageTitle(
          l.maps,
          description: l.mapsReadyBody,
          action: OutlinedButton.icon(
            onPressed: () => act(addMap),
            icon: const Icon(Icons.add, size: 17),
            label: Text(l.customMap),
          ),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 240,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: maps.length,
            itemBuilder: (context, i) {
              final map = maps[i];
              return InkWell(
                onTap: () => openMap(map),
                borderRadius: BorderRadius.circular(14),
                child: StudioPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 164,
                        child: MapCover(
                          path: cover(map) ?? map['image_path'] as String?,
                          overlay: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  map['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.7,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  map['catalog_id'] as String? ?? l.customMap,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Studio.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  map['image_path'] == null
                                      ? l.imageRequired
                                      : l.readyOffline,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Studio.muted,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l.importRadar,
                                onPressed: busy
                                    ? null
                                    : () => act(() async {
                                        final path = await widget.files
                                            .importRadar();
                                        if (path != null) {
                                          db.mapImage(
                                            map['id'] as String,
                                            path,
                                          );
                                        }
                                      }),
                                icon: const Icon(Icons.tune_rounded, size: 17),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: Studio.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget strategiesPage() {
    final items = db
        .strategies(teamId!)
        .where((s) => matches('${s['title']} ${s['map_name']} ${s['notes']}'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          l.strategies,
          action: l.newStrategy,
          onAction: () => act(createStrategy),
        ),
        Expanded(
          child: items.isEmpty
              ? empty(l.emptyStrategies, Icons.route_outlined)
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 276,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return InkWell(
                      onTap: () => openStrategy(item['id'] as String),
                      borderRadius: BorderRadius.circular(14),
                      child: StudioPanel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 154,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: item['image_path'] != null
                                          ? Image.file(
                                              File(
                                                item['image_path'] as String,
                                              ),
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, e, s) =>
                                                  const Icon(
                                                    Icons.map_outlined,
                                                    color: Studio.muted,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.map_outlined,
                                              color: Studio.muted,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: StatusTag(
                                      item['side'] as String,
                                      color: item['side'] == 'T'
                                          ? Studio.t
                                          : Studio.ct,
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: StatusTag(
                                      l.version(item['version'] as int),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.layers_outlined,
                                        size: 13,
                                        color: Studio.muted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item['map_name'] as String,
                                          style: const TextStyle(
                                            color: Studio.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: Studio.accent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String status(String value) => switch (value) {
    'todo' => l.todo,
    'in_progress' => l.taskInProgress,
    'submitted' => l.submitted,
    _ => l.approved,
  };
  Widget taskCard(RecordData task) {
    final state = task['status'] as String;
    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusTag(
            status(state),
            color: state == 'approved'
                ? Studio.accent
                : state == 'submitted'
                ? Studio.ct
                : Studio.t,
          ),
          const SizedBox(height: 8),
          Text(
            taskTypeLabel(l, task['task_type'] as String? ?? 'general'),
            style: const TextStyle(color: Studio.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            task['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            task['member_name'] as String? ?? l.unassigned,
            style: const TextStyle(color: Studio.muted, fontSize: 11),
          ),
          if (task['due_at'] != null) ...[
            const SizedBox(height: 12),
            Text(
              '${state != 'approved' && DateTime.parse(task['due_at'] as String).isBefore(DateTime.now()) ? '${l.taskOverdue} · ' : ''}${l.taskDeadline}: ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(task['due_at'] as String).toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.parse(task['due_at'] as String).toLocal()))}',
              style: TextStyle(
                fontSize: 12,
                color:
                    state != 'approved' &&
                        DateTime.parse(task['due_at'] as String)
                            .isBefore(DateTime.now())
                    ? Colors.orange
                    : Studio.muted,
              ),
            ),
          ],
          if ((task['criteria'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${l.taskCriteria}: ${task['criteria']}'),
          ],
          if ((task['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              task['notes'] as String,
              style: const TextStyle(fontSize: 12, color: Studio.muted),
            ),
          ],
          if ((task['review_reason'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${l.taskReturnReason}: ${task['review_reason']}'),
            ),
          if (task['strategy_id'] != null)
            TextButton.icon(
              onPressed: () => openStrategy(task['strategy_id'] as String),
              icon: const Icon(Icons.route, size: 14),
              label: Text(
                task['strategy_title'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (['todo', 'in_progress'].contains(state) &&
                  (db.canEditTeam(teamId!) ||
                      (db.setting('shared_role_$teamId') == 'player' &&
                          task['member_id'] ==
                              db.setting('shared_user_member_$teamId'))))
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          db.transitionTask(
                            task['id'] as String,
                            state == 'todo' ? 'in_progress' : 'submitted',
                          );
                        }),
                  child: Text(state == 'todo' ? l.taskStart : l.submit),
                ),
              if (state == 'submitted' && db.canEditTeam(teamId!))
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          db.transitionTask(task['id'] as String, 'approved');
                        }),
                  child: Text(l.approve),
                ),
              if (db.canEditTeam(teamId!) &&
                  ['todo', 'in_progress'].contains(state))
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await showDialog<String>(
                            context: context,
                            builder: (_) =>
                                TaskForm(store: db, team: teamId!, value: task),
                          );
                        }),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.editTaskPlan),
                ),
              if (db.setting('account_team_$teamId') != null)
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TaskHistoryDialog(
                      history: TaskHistory(db, teamId!, task['id'] as String),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: Text(l.history),
                ),
              if (state != 'todo' && db.canEditTeam(teamId!))
                TextButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          final v = await form(l.returnTask, {
                            'reason': l.taskReturnReason,
                          });
                          if (v == null || (v['reason'] ?? '').trim().isEmpty) {
                            return;
                          }
                          db.transitionTask(
                            task['id'] as String,
                            'todo',
                            reason: v['reason']!,
                          );
                        }),
                  child: Text(l.returnTask),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget tasksPage() {
    final items = db
        .tasks(teamId!)
        .where(
          (t) => matches('${t['title']} ${t['member_name']} ${t['notes']}'),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          l.training,
          action: db.canEditTeam(teamId!) ? l.newTask : null,
          onAction: db.canEditTeam(teamId!)
              ? () => act(() => createTask())
              : null,
        ),
        Expanded(
          child: items.isEmpty
              ? empty(l.emptyTasks, Icons.checklist)
              : LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth < 1200) {
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 14),
                        itemBuilder: (context, i) => taskCard(items[i]),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final state in [
                          'todo',
                          'in_progress',
                          'submitted',
                          'approved',
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        status(state),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusTag(
                                        '${items.where((e) => e['status'] == state).length}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ListView(
                                      children: [
                                        for (final task in items.where(
                                          (e) => e['status'] == state,
                                        ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 14,
                                            ),
                                            child: taskCard(task),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget teamPage() {
    final members = db
        .members(teamId!)
        .where((m) => matches('${m['name']} ${m['game_role']}'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(l.team, action: l.accountRosterManaged, onAction: openAccount),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: openAccount,
                icon: const Icon(Icons.person_add_outlined),
                label: Text(l.accountInvite),
              ),
              if (db.setting('account_team_$teamId') == null)
                TextButton(
                  onPressed: () => act(addMember),
                  child: Text(l.addMember),
                ),
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? empty(l.emptyMembers, Icons.groups_outlined)
              : ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final role = switch (m['role']) {
                      'owner' => l.owner,
                      'captain' => l.captain,
                      'coach' => l.coach,
                      'viewer' => l.viewer,
                      _ => l.player,
                    };
                    return StudioPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Studio.elevated,
                          child: Text(
                            (m['name'] as String).characters.first
                                .toUpperCase(),
                            style: const TextStyle(color: Studio.accent),
                          ),
                        ),
                        title: Text(
                          m['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          role,
                          style: const TextStyle(
                            color: Studio.muted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: StatusTag(
                            m['game_role'] as String,
                            color: Studio.ct,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),
        Text(
          l.localRoles,
          style: const TextStyle(color: Studio.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget demosPage() => DemoHub(
    key: ValueKey(teamId),
    store: db,
    files: widget.files,
    team: teamId!,
    query: query,
    sharedJob: demoJob,
  );

  Future<void> exportPdf() async {
    final language = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.exportLanguage),
        children: [
          for (final entry in [('ru', 'Русский'), ('en', 'English')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, entry.$1),
              child: Text(entry.$2),
            ),
        ],
      ),
    );
    if (language == null) return;
    final labels = await AppLocalizations.delegate.load(Locale(language));
    await Playbook.share(db, teamId!, labels);
  }

  Future<void> exportPackage() async {
    final bytes = OfflinePackage.export(db, teamId!, l.localeName);
    if (Platform.isWindows) {
      final target = await getSaveLocation(
        suggestedName: 'TeamSync.teamsync',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'TeamSync', extensions: ['teamsync']),
        ],
      );
      if (target == null) return;
      await File(target.path).writeAsBytes(bytes, flush: true);
      message(l.exported);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/octet-stream',
              name: 'TeamSync.teamsync',
            ),
          ],
          fileNameOverrides: ['TeamSync.teamsync'],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
    }
  }

  Future<void> importPackage() async {
    final source = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'TeamSync',
          extensions: ['teamsync'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    if (source == null) return;
    if (await source.length() > OfflinePackage.limit) {
      throw DomainError('packageError');
    }
    await OfflinePackage.restore(
      db,
      widget.files.root,
      await source.readAsBytes(),
    );
    message(l.packageImported);
    await openAccount();
  }

  Widget settingsPage() => ListView(
    children: [
      heading(l.settings),
      if (shared)
        ListTile(
          title: Text(l.syncTactics),
          subtitle: Text('${l.syncTeamHelp}\n$syncLabel'),
          trailing: IconButton(
            tooltip: l.syncNow,
            onPressed: syncing ? null : syncNow,
            icon: const Icon(Icons.sync),
          ),
        ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.onlineAccount),
        leading: const Icon(Icons.account_circle_outlined),
        trailing: const Icon(Icons.chevron_right),
        onTap: openAccount,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.language),
        trailing: language(),
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.exportPdf),
        subtitle: Text(l.pdfHelp),
        leading: const Icon(Icons.picture_as_pdf_outlined),
        onTap: busy ? null : () => act(exportPdf),
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.backup),
        subtitle: Text(l.backupHelp),
        leading: const Icon(Icons.inventory_2_outlined),
        onTap: busy ? null : () => act(exportPackage),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.restorePackage),
        leading: const Icon(Icons.file_open_outlined),
        onTap: busy ? null : () => act(importPackage),
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.storage),
        subtitle: SelectableText(widget.files.root.path),
      ),
      const SizedBox(height: 24),
      info(l.stageNotice),
    ],
  );
  Future<void> mobileMore() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in [2, 9, 4, 7, 8, 6])
              ListTile(
                leading: Icon(destinations[i].$2),
                title: Text(destinations[i].$1),
                onTap: () {
                  setState(() => page = i);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = onlineTeams,
        selected = teams.where((e) => e['id'] == teamId).firstOrNull;
    if (selected == null) {
      final catalog = widget.files.catalog;
      final covers =
          catalog?.maps
              .take(3)
              .map((m) => catalog.thumbnail(m['key'] as String))
              .toList() ??
          [];
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Studio.accent, size: 24),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'TeamSync',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
              ),
            ],
          ),
          actions: [language(), const SizedBox(width: 24)],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: EdgeInsets.all(c.maxWidth > 800 ? 64 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusTag(l.gameLibrary, color: Studio.accent),
                        const SizedBox(height: 28),
                        Text(
                          l.noTeams,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Text(
                            l.noTeamsBody,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Studio.muted,
                              height: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: openAccount,
                              icon: const Icon(
                                Icons.account_circle_outlined,
                                size: 18,
                              ),
                              label: Text(l.onlineAccount),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          l.mapsReady,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (covers.isNotEmpty)
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: covers.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, i) => SizedBox(
                                width: 250,
                                child: MapCover(path: covers[i]),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          l.localNotice,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Studio.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final content = switch (page) {
      0 => overview(),
      1 => mapsPage(),
      2 => strategiesPage(),
      3 => tasksPage(),
      4 => demosPage(),
      5 => teamPage(),
      7 => PlaybookEditor(
        key: ValueKey('playbook:$teamId'),
        store: db,
        files: widget.files,
        team: teamId!,
      ),
      8 => BootcampPage(store: db, host: lanHost, installer: serverInstaller),
      9 => UtilitiesPage(
        key: ValueKey('utilities:$teamId'),
        store: db,
        files: widget.files,
        team: teamId!,
        filter: query,
        onStrategy: openStrategy,
      ),
      _ => settingsPage(),
    };
    return StudioShell(
      content: content,
      destinations: destinations,
      selected: page,
      onSelect: (value) => setState(() => page = value),
      onSearch: (value) => setState(() => query = value),
      busy: busy,
      more: mobileMore,
      language: language(),
      teamSelector: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: teamId,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Studio.muted,
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Studio.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                items: teams
                    .map(
                      (e) => DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(
                          e['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) {
                          act(() async {
                            db.setSetting('team', value);
                            setState(() => teamId = value);
                            syncNow();
                          });
                        }
                      },
              ),
            ),
          ),
          IconButton(
            tooltip: l.createTeam,
            onPressed: busy ? null : () => act(createTeam),
            icon: const Icon(Icons.add_rounded, size: 17, color: Studio.muted),
          ),
          if (shared)
            IconButton(
              tooltip: syncLabel,
              onPressed: syncing ? null : syncNow,
              icon: Icon(
                syncing
                    ? Icons.sync
                    : syncError != null
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                size: 18,
                color: syncError != null ? Colors.orange : Studio.accent,
              ),
            ),
        ],
      ),
    );
  }
}
