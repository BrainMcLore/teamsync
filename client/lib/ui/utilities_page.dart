import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store.dart';
import '../data/utilities.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';

class UtilitiesPage extends StatefulWidget {
  final Store store;
  final String team;
  final String filter;
  final Future<void> Function(String)? onStrategy;
  const UtilitiesPage({
    super.key,
    required this.store,
    required this.team,
    this.filter = '',
    this.onStrategy,
  });
  @override
  State<UtilitiesPage> createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  UtilityLibrary get library => UtilityLibrary(widget.store);
  String query = '';
  String grenadeLabel(String type) => switch (type) {
    'smoke' => l.smoke,
    'flash' => l.flash,
    'molotov' => l.molotov,
    'he' => l.grenadeHe,
    _ => l.grenadeDecoy,
  };

  Future<void> edit([RecordData? value]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _UtilityForm(store: widget.store, team: widget.team, value: value),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> open(String source) async {
    try {
      final safe = UtilityLibrary.source(source);
      if (safe != null &&
          await launchUrl(
            Uri.parse(safe),
            mode: LaunchMode.externalApplication,
          )) {
        return;
      }
    } catch (_) {
      /* The saved instruction remains available. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.utilityUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = library
        .list(widget.team)
        .where(
          (u) => '${u['title']} ${u['map_name']} ${u['notes']}'
              .toLowerCase()
              .contains(
                (widget.filter.isEmpty ? query : widget.filter).toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l.utilityLibrary,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            if (widget.store.canEditTeam(widget.team))
              FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: Text(l.newUtility),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(l.utilitySourceHelp, style: const TextStyle(color: Studio.muted)),
        const SizedBox(height: 14),
        if (MediaQuery.sizeOf(context).width < 1000)
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.searchWorkspace,
            ),
          ),
        const SizedBox(height: 18),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(l.utilityEmpty))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final row = rows[index],
                        details =
                            jsonDecode(rows[index]['details'] as String) as Map;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                StatusTag(row['map_name'] as String),
                                StatusTag(row['side'] as String),
                                StatusTag(
                                  grenadeLabel(details['grenade'] as String),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            for (final field in [
                              (l.utilityStart, 'start'),
                              (l.utilityTarget, 'target'),
                              (l.utilityThrow, 'throw_type'),
                              (l.utilityAuthor, 'author'),
                              (l.utilityVerified, 'verified_at'),
                              (l.utilityRevision, 'map_revision'),
                            ])
                              if ((details[field.$2] as String? ?? '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${field.$1}: ${details[field.$2]}',
                                  ),
                                ),
                            for (final id
                                in details['strategy_ids'] as List? ?? [])
                              TextButton.icon(
                                onPressed: widget.onStrategy == null
                                    ? null
                                    : () => widget.onStrategy!(id as String),
                                icon: const Icon(Icons.route_outlined),
                                label: Text(
                                  widget.store.strategy(id as String)['title']
                                      as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if ((row['notes'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: SelectableText(row['notes'] as String),
                              ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (details['source_url'] != null)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        open(details['source_url'] as String),
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(l.utilityOpen),
                                  ),
                                if (widget.store.canEditTeam(widget.team))
                                  TextButton.icon(
                                    onPressed: () => edit(row),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(l.editMaterial),
                                  ),
                              ],
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
}

class _UtilityForm extends StatefulWidget {
  final Store store;
  final String team;
  final RecordData? value;
  const _UtilityForm({required this.store, required this.team, this.value});
  @override
  State<_UtilityForm> createState() => _UtilityFormState();
}

class _UtilityFormState extends State<_UtilityForm> {
  final fields = <String, TextEditingController>{};
  late String? map;
  String side = 'T', grenade = 'smoke';
  final selectedStrategies = <String>{};
  String? failure;
  @override
  void initState() {
    super.initState();
    final row = widget.value,
        details = row == null
            ? <String, dynamic>{}
            : jsonDecode(row['details'] as String) as Map;
    map =
        row?['map_id'] as String? ??
        widget.store.maps(widget.team).firstOrNull?['id'] as String?;
    side = row?['side'] as String? ?? 'T';
    grenade = details['grenade'] as String? ?? 'smoke';
    selectedStrategies.addAll(
      List<String>.from(details['strategy_ids'] as List? ?? []),
    );
    for (final key in [
      'title',
      'notes',
      'start',
      'target',
      'throw_type',
      'author',
      'source_url',
      'verified_at',
      'map_revision',
    ]) {
      fields[key] = TextEditingController(
        text:
            (key == 'title' || key == 'notes'
                    ? (row ?? <String, Object?>{})[key]
                    : details[key])
                as String? ??
            '',
      );
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        maps = widget.store.maps(widget.team);
    return AlertDialog(
      title: Text(widget.value == null ? l.newUtility : l.editUtility),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: map,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.maps),
                items: [
                  for (final m in maps)
                    DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(m['name'] as String),
                    ),
                ],
                onChanged: (v) => map = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: side,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.side),
                items: [
                  for (final s in ['T', 'CT'])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => side = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: grenade,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.utilityGrenade),
                items: [
                  for (final item in [
                    ('smoke', l.smoke),
                    ('flash', l.flash),
                    ('molotov', l.molotov),
                    ('he', l.grenadeHe),
                    ('decoy', l.grenadeDecoy),
                  ])
                    DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                ],
                onChanged: (v) => grenade = v!,
              ),
              for (final item in [
                ('title', l.title),
                ('start', l.utilityStart),
                ('target', l.utilityTarget),
                ('throw_type', l.utilityThrow),
                ('notes', l.utilityInstruction),
                ('source_url', l.utilitySource),
                ('author', l.utilityAuthor),
                ('verified_at', l.utilityVerified),
                ('map_revision', l.utilityRevision),
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: fields[item.$1],
                    minLines: item.$1 == 'notes' ? 3 : 1,
                    maxLines: item.$1 == 'notes' ? 8 : 1,
                    decoration: InputDecoration(labelText: item.$2),
                  ),
                ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l.utilityTactics),
              ),
              for (final tactic in widget.store.strategies(widget.team))
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tactic['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: selectedStrategies.contains(tactic['id']),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      selectedStrategies.add(tactic['id'] as String);
                    } else {
                      selectedStrategies.remove(tactic['id']);
                    }
                  }),
                ),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    failure!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
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
          onPressed: map == null
              ? null
              : () {
                  try {
                    UtilityLibrary(widget.store).save(
                      widget.team,
                      map!,
                      fields['title']!.text,
                      side,
                      fields['notes']!.text,
                      {
                        'grenade': grenade,
                        'strategy_ids': selectedStrategies.toList(),
                        for (final entry in fields.entries.where(
                          (e) => !['title', 'notes'].contains(e.key),
                        ))
                          entry.key: entry.value.text,
                      },
                      id: widget.value?['id'] as String?,
                    );
                    Navigator.pop(context, true);
                  } on DomainError catch (e) {
                    setState(
                      () => failure = e.code == 'invalidSource'
                          ? l.utilityInvalidSource
                          : l.invalidText,
                    );
                  }
                },
          child: Text(l.save),
        ),
      ],
    );
  }
}
