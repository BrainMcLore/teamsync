import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/app_localizations.dart';

Map<String, dynamic> demoTags(RecordData demo) {
  try {
    return jsonDecode(demo['scouting'] as String? ?? '{}')
        as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

bool matchesDemoTags(
  RecordData demo,
  String team,
  String position,
  String tier,
) {
  final tags = demoTags(demo);
  return '${tags['teams'] ?? ''}'.toLowerCase().contains(
        team.trim().toLowerCase(),
      ) &&
      '${tags['positions'] ?? ''}'.toLowerCase().contains(
        position.trim().toLowerCase(),
      ) &&
      (tier.isEmpty || tags['tier'] == tier);
}

Future<void> editDemoTags(
  BuildContext context,
  Store store,
  RecordData demo,
) async {
  final value = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _TagDialog(initial: demoTags(demo)),
  );
  if (value != null) store.saveScouting(demo['id'] as String, value);
}

class _TagDialog extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _TagDialog({required this.initial});
  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late TextEditingController teams, event, positions;
  late String tier;
  @override
  void initState() {
    super.initState();
    teams = TextEditingController(
      text: widget.initial['teams'] as String? ?? '',
    );
    event = TextEditingController(
      text: widget.initial['event'] as String? ?? '',
    );
    positions = TextEditingController(
      text: widget.initial['positions'] as String? ?? '',
    );
    tier = widget.initial['tier'] as String? ?? '';
  }

  @override
  void dispose() {
    teams.dispose();
    event.dispose();
    positions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.scouting),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.scoutingHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: teams,
                maxLength: 500,
                decoration: InputDecoration(labelText: l.matchTeams),
              ),
              TextField(
                controller: event,
                maxLength: 250,
                decoration: InputDecoration(labelText: l.tournament),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: tier,
                decoration: InputDecoration(labelText: l.tournamentTier),
                items: [
                  DropdownMenuItem(value: '', child: Text(l.untagged)),
                  for (final v in ['1', '2', '3', '4'])
                    DropdownMenuItem(value: v, child: Text('Tier $v')),
                ],
                onChanged: (v) => tier = v ?? '',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: positions,
                maxLength: 10000,
                minLines: 4,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l.playerPositions,
                  alignLabelWithHint: true,
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
          onPressed: () => Navigator.pop(context, <String, dynamic>{
            'teams': teams.text.trim(),
            'event': event.text.trim(),
            'positions': positions.text.trim(),
            'tier': tier,
            'source': 'coach',
          }),
          child: Text(l.save),
        ),
      ],
    );
  }
}
