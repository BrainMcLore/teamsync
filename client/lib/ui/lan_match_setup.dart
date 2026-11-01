import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/pc_services.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';

Map<String, String> parseMatchRoster(String value) {
  final players = <String, String>{};
  for (final line in value.split('\n').where((v) => v.trim().isNotEmpty)) {
    final match = RegExp(r'^\s*(7656119\d{10})\s*(.*)$').firstMatch(line);
    if (match == null || players.containsKey(match.group(1))) {
      throw DomainError('invalidRoster');
    }
    players[match.group(1)!] = match.group(2)!.trim().isEmpty
        ? match.group(1)!
        : match
              .group(2)!
              .trim()
              .substring(0, match.group(2)!.trim().length.clamp(0, 80));
  }
  if (players.isEmpty || players.length > 5) throw DomainError('invalidRoster');
  return players;
}

Future<void> configureLanMatch(
  BuildContext context,
  Store store,
  LanHost host,
) async {
  final config = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _MatchDialog(),
  );
  if (config == null) return;
  final server = store.setting('pc.server');
  if (server == null) throw DomainError('serverMissing');
  final file = File(
    '${PcInstallation.gameDirectory(server).path}/csgo/cfg/teamsync_match.json',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(config), flush: true);
  await host.command('veto');
}

class _MatchDialog extends StatefulWidget {
  const _MatchDialog();
  @override
  State<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends State<_MatchDialog> {
  final form = GlobalKey<FormState>();
  final names = [TextEditingController(), TextEditingController()];
  final players = [TextEditingController(), TextEditingController()];
  final maps = <String>{
    'de_mirage',
    'de_inferno',
    'de_nuke',
    'de_ancient',
    'de_anubis',
    'de_dust2',
    'de_overpass',
  };
  int bestOf = 1;
  @override
  void dispose() {
    for (final c in [...names, ...players]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final a = parseMatchRoster(players[0].text),
        b = parseMatchRoster(players[1].text);
    final l = AppLocalizations.of(context);
    if (a.keys.any(b.containsKey) || maps.length < bestOf) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.invalidMatchRoster)));
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'matchid': Store.uuid.v4(),
      'team1': {'name': names[0].text.trim(), 'players': a},
      'team2': {'name': names[1].text.trim(), 'players': b},
      'num_maps': bestOf,
      'maplist': maps.toList(),
      'skip_veto': false,
      'side_type': 'always_knife',
      'players_per_team': 5,
      'min_players_to_ready': a.length < b.length ? a.length : b.length,
      'cvars': {
        'sv_lan': '1',
        'sv_cheats': '0',
        'mp_maxrounds': '24',
        'tv_enable': '1',
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.matchSetup),
      content: SizedBox(
        width: 600,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.matchSetupHelp),
                const SizedBox(height: 16),
                for (var i = 0; i < 2; i++) ...[
                  TextFormField(
                    controller: names[i],
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: '${l.team} ${i + 1}',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? l.invalidText : null,
                  ),
                  TextFormField(
                    controller: players[i],
                    maxLength: 700,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: '${l.steamRoster} ${i + 1}',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      try {
                        parseMatchRoster(v ?? '');
                        return null;
                      } catch (_) {
                        return l.invalidMatchRoster;
                      }
                    },
                  ),
                ],
                DropdownButtonFormField<int>(
                  initialValue: bestOf,
                  isExpanded: true,
                  items: [
                    for (final n in [1, 3, 5])
                      DropdownMenuItem(value: n, child: Text('BO$n')),
                  ],
                  onChanged: (v) => bestOf = v ?? 1,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final map in [
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
                      FilterChip(
                        label: Text(map),
                        selected: maps.contains(map),
                        onSelected: (v) => setState(() {
                          if (v) {
                            maps.add(map);
                          } else {
                            maps.remove(map);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: submit, child: Text(l.loadMatch)),
      ],
    );
  }
}
