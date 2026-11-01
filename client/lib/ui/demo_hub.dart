import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/demo_jobs.dart';
import '../data/files.dart';
import '../data/store.dart';
import '../data/review_data.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'demo_review.dart';
import 'demo_tags.dart';
import 'hltv_catalog.dart';
import 'open_demo_cs.dart';

class DemoHub extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  final String team, query;
  final DemoJob? sharedJob;
  const DemoHub({
    super.key,
    required this.store,
    required this.files,
    required this.team,
    this.query = '',
    this.sharedJob,
  });
  @override
  State<DemoHub> createState() => _DemoHubState();
}

class _DemoHubState extends State<DemoHub> {
  AppLocalizations get l => AppLocalizations.of(context);
  late DemoJob job;
  int tab = 0;
  String teamFilter = '', positionFilter = '', tierFilter = '';
  bool busy = false;
  String? failure, lastLink;
  @override
  void initState() {
    super.initState();
    job = widget.sharedJob ?? DemoJob(widget.store, widget.files.root);
    busy = job.running;
    job.addListener(changed);
    if (busy) tab = 2;
  }

  void changed() {
    if (mounted) {
      setState(() {
        if (!job.running && busy) {
          busy = false;
          if (job.phase == 'complete' && tab == 2) tab = 0;
          if (job.error != null) failure = errorText(DomainError(job.error!));
        }
      });
    }
  }

  @override
  void dispose() {
    job.removeListener(changed);
    if (widget.sharedJob == null) job.cancel();
    super.dispose();
  }

  String phase() => switch (job.phase) {
    'downloading' => l.jobDownload,
    'source_verification' => l.sourceVerification,
    'extracting' => l.jobExtract,
    'events' => l.jobEvents,
    'positions' => l.jobPositions,
    'indexing' => l.jobIndex,
    'complete' => l.jobComplete,
    'cancelled' => l.jobCancelled,
    _ => l.jobParse,
  };
  String errorText(Object e) => switch (e is DomainError
      ? e.code
      : 'parseFailed') {
    'source_blocked' => l.sourceBlocked,
    'managed_downloader_missing' ||
    'download_runtime_missing' ||
    'download_runtime_old' => l.downloadRuntimeMissing,
    'source_verification_timeout' ||
    'native_download_interrupted' ||
    'native_download_failed' ||
    'download_runtime_failed' => l.managedDownloadFailed,
    'workerMissing' => l.parserMissing,
    'desktopParserRequired' => l.desktopParser,
    'jobCancelled' => l.jobCancelled,
    'parseTimeout' => l.parseTimeout,
    'unsafe_download_url' => l.unsafeDownload,
    'archive_limit' || 'unsafe_archive' || 'archive_corrupt' => l.unsafeArchive,
    'reviewDataInvalid' => l.reviewDataInvalid,
    _ => l.parseFailed,
  };
  Future<void> importInput(
    String input, {
    String? page,
    Map<String, dynamic>? matchInfo,
  }) async {
    setState(() {
      busy = true;
      failure = null;
      lastLink = input.startsWith('https://') ? input : null;
      tab = 2;
    });
    try {
      if (!input.startsWith('https://') &&
          (input.toLowerCase().endsWith('.json') ||
              input.toLowerCase().endsWith('.teamsync-review'))) {
        if (await File(input).length() > 100 * 1024 * 1024) {
          throw DomainError('reviewDataInvalid');
        }
        await importReview(
          widget.store,
          widget.files.root,
          widget.team,
          await File(input).readAsBytes(),
        );
      } else {
        final ids = await job.runImport(widget.team, input, sourcePage: page);
        if (matchInfo != null && ids.isNotEmpty) {
          final existing = demoTags(
            widget.store
                .demos(widget.team)
                .firstWhere((d) => d['id'] == ids.first),
          );
          widget.store.saveScouting(ids.first, {
            'teams': (matchInfo['teams'] as List? ?? []).join(', '),
            'event': matchInfo['event'] as String? ?? '',
            'tier': (matchInfo['tier'] as String? ?? '').isNotEmpty
                ? matchInfo['tier'] as String
                : existing['tier'] as String? ?? '',
            'positions': existing['positions'] as String? ?? '',
            'source': 'HLTV teams/event; coach tier/positions',
          });
        }
      }
      if (mounted) setState(() => tab = 0);
    } catch (e) {
      if (mounted) setState(() => failure = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'CS2 / TeamSync',
          extensions: ['dem', 'rar', 'zip', 'teamsync-review', 'json'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 2 * 1024 * 1024 * 1024) {
      if (mounted) setState(() => failure = l.invalidDemo);
      return;
    }
    String? page;
    if (!file.name.endsWith('.teamsync-review') &&
        !file.name.endsWith('.json')) {
      if (!mounted) return;
      page = await showDialog<String>(
        context: context,
        builder: (context) => _SourcePageDialog(name: file.name),
      );
      if (page == null) return;
    }
    await importInput(file.path, page: page);
  }

  Future<void> chooseLink() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _DemoSourceDialog(),
    );
    if (result != null) await importInput(result.$1, page: result.$2);
  }

  Future<void> open(RecordData demo) async {
    if (demo['analysis_path'] == null) {
      await importInput(
        demo['path'] as String,
        page: demo['source_page'] as String?,
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DemoReviewPage(
          store: widget.store,
          files: widget.files,
          demo: demo,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget filters() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 210,
          child: TextField(
            decoration: InputDecoration(labelText: l.filterTeam),
            onChanged: (v) => setState(() => teamFilter = v),
          ),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            decoration: InputDecoration(labelText: l.filterPosition),
            onChanged: (v) => setState(() => positionFilter = v),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: tierFilter,
            decoration: InputDecoration(labelText: l.tournamentTier),
            items: [
              DropdownMenuItem(value: '', child: Text(l.allTiers)),
              for (final v in ['1', '2', '3', '4'])
                DropdownMenuItem(value: v, child: Text('Tier $v')),
            ],
            onChanged: (v) => setState(() => tierFilter = v ?? ''),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = widget.store.demos(widget.team),
        items = all
            .where(
              (d) =>
                  matchesDemoTags(d, teamFilter, positionFilter, tierFilter) &&
                  '${d['name']} ${d['map_key']} ${d['scouting'] ?? ''} ${d['participants'] ?? ''} ${d['source_page'] ?? ''}'
                      .toLowerCase()
                      .contains(widget.query.toLowerCase()),
            )
            .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioPageTitle(
                l.demos,
                description: l.libraryDescription,
                action: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (Platform.isWindows)
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => setState(() => tab = 1),
                        icon: const Icon(
                          Icons.download_for_offline_outlined,
                          size: 16,
                        ),
                        label: Text(l.hltvInbox),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : chooseLink,
                      icon: const Icon(Icons.link, size: 16),
                      label: Text(l.importLink),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : chooseFile,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.importArchive),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in [
                      (0, l.library),
                      (1, l.catalog),
                      (2, l.downloads),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: InkWell(
                          onTap: () => setState(() => tab = entry.$1),
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 14, top: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == entry.$1
                                      ? Studio.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              entry.$2,
                              style: TextStyle(
                                color: tab == entry.$1
                                    ? Studio.text
                                    : Studio.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 20),
              if (tab == 0) filters(),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StudioPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          failure!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (lastLink != null)
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(lastLink!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(l.openSource),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverFillRemaining(
          child: switch (tab) {
            1 => HltvCatalog(
              store: widget.store,
              root: widget.files.root,
              team: widget.team,
              onDownload: (url, page, info) =>
                  importInput(url, page: page, matchInfo: info),
            ),
            2 => ListView(
              children: [
                StudioPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busy ? phase() : l.noDownloads,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (busy) ...[
                        LinearProgressIndicator(value: job.progress),
                        const SizedBox(height: 12),
                        Text(
                          job.progress == null
                              ? '…'
                              : '${(job.progress! * 100).round()}%',
                          style: const TextStyle(color: Studio.muted),
                        ),
                        if (job.speed != null)
                          Text(
                            '${(job.bytes / 1048576).toStringAsFixed(1)} MB · ${(job.speed! / 1048576).toStringAsFixed(1)} MB/s',
                            style: const TextStyle(color: Studio.muted),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: job.cancel,
                          child: Text(l.cancel),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            _ =>
              items.isEmpty
                  ? ListView(
                      children: [
                        StudioPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: 32,
                                color: Studio.accent,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                l.emptyDemos,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l.importSourceHelp,
                                style: const TextStyle(color: Studio.muted),
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: busy ? null : chooseFile,
                                icon: const Icon(Icons.add),
                                label: Text(l.importArchive),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final demo = items[index],
                            parsed = demo['analysis_path'] != null;
                        final cover = widget.files.catalog?.thumbnail(
                          demo['map_key'] as String? ?? '',
                        );
                        return StudioPanel(
                          padding: const EdgeInsets.all(14),
                          child: LayoutBuilder(
                            builder: (context, c) => Row(
                              children: [
                                if (c.maxWidth > 550) ...[
                                  SizedBox(
                                    width: 112,
                                    height: 76,
                                    child: MapCover(path: cover),
                                  ),
                                  const SizedBox(width: 20),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        demo['name'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          StatusTag(
                                            demo['map_key'] as String? ?? 'CS2',
                                            color: Studio.muted,
                                          ),
                                          StatusTag(
                                            parsed ? l.parsed : l.notAnalyzed,
                                            color: parsed
                                                ? Studio.accent
                                                : Studio.muted,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        l.fileSize(
                                          ((demo['size'] as int) / 1048576)
                                              .toStringAsFixed(1),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Studio.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: l.scouting,
                                  icon: const Icon(Icons.sell_outlined),
                                  onPressed: () async {
                                    await editDemoTags(
                                      context,
                                      widget.store,
                                      demo,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                                OpenDemoCsButton(
                                  store: widget.store,
                                  demo: demo,
                                ),
                                IconButton.filledTonal(
                                  tooltip: parsed
                                      ? l.watchReview
                                      : l.analyzeDemo,
                                  onPressed: busy ? null : () => open(demo),
                                  icon: Icon(
                                    parsed
                                        ? Icons.play_arrow_rounded
                                        : Icons.analytics_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          },
        ),
      ],
    );
  }
}

class _SourcePageDialog extends StatefulWidget {
  final String name;
  const _SourcePageDialog({required this.name});
  @override
  State<_SourcePageDialog> createState() => _SourcePageDialogState();
}

class _SourcePageDialogState extends State<_SourcePageDialog> {
  final page = TextEditingController();
  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: page,
          decoration: InputDecoration(
            labelText: l.sourcePage,
            hintText: 'https://www.hltv.org/matches/…',
          ),
          keyboardType: TextInputType.url,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, page.text.trim()),
          child: Text(l.importArchive),
        ),
      ],
    );
  }
}

class _DemoSourceDialog extends StatefulWidget {
  const _DemoSourceDialog();
  @override
  State<_DemoSourceDialog> createState() => _DemoSourceDialogState();
}

class _DemoSourceDialogState extends State<_DemoSourceDialog> {
  final file = TextEditingController(), page = TextEditingController();
  @override
  void dispose() {
    file.dispose();
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.importLink),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.importSourceHelp,
                style: const TextStyle(color: Studio.muted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: file,
                decoration: InputDecoration(labelText: l.downloadUrl),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: page,
                decoration: InputDecoration(labelText: l.sourcePage),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (file.text.trim().isNotEmpty) {
              Navigator.pop(context, (file.text.trim(), page.text.trim()));
            }
          },
          child: Text(l.importLink),
        ),
      ],
    );
  }
}
