import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hltv_client.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'demo_tags.dart';
import 'kit.dart';

class HltvCatalog extends StatefulWidget {
  final Store store;
  final Directory root;
  final String team;
  final HltvClient? client;
  final Future<void> Function(
    String url,
    String page,
    Map<String, dynamic> info,
  )
  onDownload;
  const HltvCatalog({
    super.key,
    required this.store,
    required this.root,
    required this.team,
    required this.onDownload,
    this.client,
  });
  @override
  State<HltvCatalog> createState() => _HltvCatalogState();
}

class _HltvCatalogState extends State<HltvCatalog> {
  AppLocalizations get l => AppLocalizations.of(context);
  late HltvClient client;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> details = {};
  Map<String, dynamic> tiers = {};
  int offset = 0, minimumStars = 0;
  String query = '', event = '', tier = '', position = '';
  String? failure, selected, fetched;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    client = widget.client ?? HltvClient(widget.root);
    try {
      tiers = jsonDecode(
        widget.store.setting('hltv.eventTiers') ?? '{}',
      ) as Map<String, dynamic>;
    } catch (_) {}
    load();
  }

  @override
  void dispose() {
    client.cancel();
    super.dispose();
  }

  void apply(Map<String, dynamic> data) {
    items = (data['items'] as List).cast<Map<String, dynamic>>();
    fetched = data['fetched_at'] as String?;
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      loading = true;
      failure = null;
    });
    final cached = await client.cached(offset);
    if (cached != null && mounted) setState(() => apply(cached));
    try {
      final data = await client.fetch(offset: offset, force: force);
      if (mounted) setState(() => apply(data));
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is DomainError && e.code == 'hltv_rate_limited'
              ? l.hltvRateLimit
              : l.hltvUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choose(Map<String, dynamic> match, bool download) async {
    setState(() {
      selected = match['id'] as String;
      loading = true;
      failure = null;
    });
    try {
      final value = await client.fetch(match: match['url'] as String);
      if (!mounted) return;
      setState(() => details[match['id'] as String] = value);
      if (download) {
        final demos = (value['demo_urls'] as List).cast<String>();
        if (demos.isEmpty) {
          setState(() => failure = l.hltvNoDemo);
          return;
        }
        await widget.onDownload(demos.first, match['url'] as String, {
          ...match,
          ...value,
          'tier': tiers[match['event']] ?? '',
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is DomainError && e.code == 'hltv_rate_limited'
              ? l.hltvRateLimit
              : l.hltvUnavailable,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          selected = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.store.demos(widget.team);
    final visible = items
        .where(
          (m) =>
              (m['teams'] as List)
                  .join(' ')
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (m['event'] as String).toLowerCase().contains(
                event.toLowerCase(),
              ) &&
              (m['stars'] as int) >= minimumStars &&
              (tier.isEmpty || tiers[m['event']] == tier) &&
              (position.isEmpty ||
                  local.any(
                    (d) =>
                        d['source_page'] == m['url'] &&
                        '${demoTags(d)['positions'] ?? ''}'
                            .toLowerCase()
                            .contains(position.toLowerCase()),
                  )),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: loading ? null : () => load(force: true),
                    icon: const Icon(Icons.refresh),
                    label: Text(l.refreshCatalog),
                  ),
                  OutlinedButton(
                    onPressed: loading || offset == 0
                        ? null
                        : () {
                            offset -= 100;
                            items = [];
                            fetched = null;
                            load();
                          },
                    child: Text(l.catalogPrevious),
                  ),
                  OutlinedButton(
                    onPressed: loading || offset >= 10000
                        ? null
                        : () {
                            offset += 100;
                            items = [];
                            fetched = null;
                            load();
                          },
                    child: Text(l.catalogNext),
                  ),
                  Text(
                    '${offset + 1}–${offset + 100}',
                    style: const TextStyle(color: Studio.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 210,
                    child: TextField(
                      decoration: InputDecoration(labelText: l.filterTeam),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: InputDecoration(labelText: l.tournament),
                      onChanged: (v) => setState(() => event = v),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: minimumStars,
                      decoration: const InputDecoration(labelText: 'HLTV ★'),
                      items: [
                        for (var n = 0; n <= 5; n++)
                          DropdownMenuItem(
                            value: n,
                            child: Text(n == 0 ? l.anyStars : '$n+ ★'),
                          ),
                      ],
                      onChanged: (v) => setState(() => minimumStars = v ?? 0),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: tier,
                      decoration: InputDecoration(labelText: l.tournamentTier),
                      items: [
                        DropdownMenuItem(value: '', child: Text(l.allTiers)),
                        for (final n in ['1', '2', '3', '4'])
                          DropdownMenuItem(value: n, child: Text('Tier $n')),
                      ],
                      onChanged: (v) => setState(() => tier = v ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: InputDecoration(labelText: l.catalogPosition),
                      onChanged: (v) => setState(() => position = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.catalogFilterHelp,
                style: const TextStyle(
                  color: Studio.muted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
              if (fetched != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${l.catalogUpdated} ${DateTime.tryParse(fetched!)?.toLocal().toString().split('.').first ?? fetched}',
                    style: const TextStyle(color: Studio.muted, fontSize: 10),
                  ),
                ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final match = visible[i], info = details[match['id']] as Map?;
            final matchEvent = match['event'] as String;
            final playedAt = DateTime.tryParse(match['date'] as String? ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (match['teams'] as List).join('  vs  '),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          match['score'] as String,
                          style: const TextStyle(
                            color: Studio.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$matchEvent · ${match['format']} · ${match['stars']} ★${playedAt == null ? '' : ' · ${DateFormat.yMMMd(l.localeName).add_Hm().format(playedAt.toLocal())}'}',
                      style: const TextStyle(color: Studio.muted, fontSize: 12),
                    ),
                    if (info != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${(info['maps'] as List).join(' / ')}\n${(info['players'] as List).join(', ')}',
                          style: const TextStyle(fontSize: 11, height: 1.6),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: loading ? null : () => choose(match, true),
                          icon: const Icon(Icons.download_outlined),
                          label: Text(l.downloadAndAnalyze),
                        ),
                        OutlinedButton(
                          onPressed: loading
                              ? null
                              : () => choose(match, false),
                          child: Text(l.matchDetails),
                        ),
                        IconButton(
                          tooltip: l.openSource,
                          onPressed: () => launchUrl(
                            Uri.parse(match['url'] as String),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              '${match['id']}:${tiers[matchEvent]}',
                            ),
                            isExpanded: true,
                            initialValue: tiers[matchEvent] as String? ?? '',
                            decoration: InputDecoration(labelText: l.coachTier),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(l.untagged),
                              ),
                              for (final n in ['1', '2', '3', '4'])
                                DropdownMenuItem(
                                  value: n,
                                  child: Text('Tier $n'),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              tiers[matchEvent] = v ?? '';
                              widget.store.setSetting(
                                'hltv.eventTiers',
                                jsonEncode(tiers),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
