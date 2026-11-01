import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/account.dart';
import '../data/store.dart';
import '../data/utility_skills.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';

class SkillPanel extends StatelessWidget {
  final Store store;
  final String team, utility;
  const SkillPanel({
    super.key,
    required this.store,
    required this.team,
    required this.utility,
  });
  SkillStore get skills => SkillStore(store, team);
  Map get details => jsonDecode(
    store.rows('SELECT details FROM utilities WHERE id=? AND team_id=?', [
          utility,
          team,
        ]).single['details']
        as String,
  ) as Map;
  int get revision => details['training_revision'] as int? ?? 1;
  String label(AppLocalizations l, String status) => switch (status) {
    'learning' => l.skillLearning,
    'ready' => l.skillReady,
    'confirmed' => l.skillConfirmed,
    _ => l.skillNotStarted,
  };
  Stream<String> get updates => store.tacticalUpdates.where(
    (id) => id == 'skills:$team' || id == utility,
  );

  Future<String?> comment(BuildContext context, String title) async {
    final input = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) {
          final l = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(title),
            content: TextField(controller: input, maxLines: 4, maxLength: 2000),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (input.text.trim().isNotEmpty) {
                    Navigator.pop(ctx, input.text.trim());
                  }
                },
                child: Text(l.save),
              ),
            ],
          );
        },
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> choose(
    BuildContext context,
    String target,
    String status,
    int epoch,
  ) async {
    final l = AppLocalizations.of(context);
    final current = skills.row(skills.document(utility), target, epoch);
    String reason = '';
    if (target != skills.user &&
        ['ready', 'confirmed'].contains((current['remote'] as Map)['status']) &&
        status != 'confirmed') {
      final value = await comment(context, l.skillReturnReason);
      if (value == null) return;
      reason = value;
    }
    if (!context.mounted) return;
    try {
      skills.desire(utility, epoch, target, status, reason: reason);
    } on DomainError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'progress_revision_changed'
                ? l.skillMaterialChanged
                : l.readOnlyTeam,
          ),
        ),
      );
    }
  }

  Widget control(BuildContext context, String target, int epoch) {
    final l = AppLocalizations.of(context),
        row = skills.row(skills.document(utility), target, epoch),
        remote = row['remote'] as Map,
        desired = row['desired'] as Map?;
    final value = desired?['status'] as String? ?? remote['status'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: [
            for (final status in [
              'not_started',
              'learning',
              'ready',
              'confirmed',
            ])
              DropdownMenuItem(
                value: status,
                enabled:
                    status != 'confirmed' ||
                    (store.canEditTeam(team) && remote['status'] == 'ready'),
                child: Text(label(l, status), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged:
              revision != epoch ||
                  row['conflict'] == true ||
                  !skills.mayWrite(target, 'learning')
              ? null
              : (status) {
                  if (status != null) choose(context, target, status, epoch);
                },
        ),
        if (desired != null && row['archived'] != true)
          Text(
            l.skillPending,
            style: const TextStyle(color: Studio.muted, fontSize: 11),
          ),
        if (row['conflict'] == true) ...[
          Text(
            l.skillConflict,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => skills.resolve(
                  skills.document(utility),
                  target,
                  epoch,
                  keepLocal: false,
                ),
                child: Text(l.skillKeepRemote),
              ),
              if (desired != null &&
                  skills.mayWrite(target, desired['status'] as String))
                TextButton(
                  onPressed: () => skills.resolve(
                    skills.document(utility),
                    target,
                    epoch,
                    keepLocal: true,
                  ),
                  child: Text(l.skillKeepLocal),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> history(BuildContext context, String target, int epoch) async {
    final l = AppLocalizations.of(context);
    try {
      final rows = <Map<String, dynamic>>[];
      final api = AccountClient(skills.binding['server'] as String);
      await api.loadToken();
      final records =
          skills.rows
              .where(
                (r) =>
                    r['document'] == skills.document(utility) &&
                    r['user'] == target &&
                    (r['remote'] as Map)['id'] != null,
              )
              .toList()
            ..sort(
              (a, b) => (b['revision'] as int).compareTo(a['revision'] as int),
            );
      for (final record in records) {
        if (store.setting('account_signed_out') == '1' ||
            store.setting('account_identity') !=
                jsonEncode([skills.binding['server'], skills.user])) {
          throw DomainError('syncAccountMismatch');
        }
        final remote = record['remote'] as Map;
        final values =
            (await api.request(
                  'GET',
                  '/api/v1/teams/${skills.binding['team']}/utility-progress/${remote['id']}/versions',
                ))['items']
                as List;
        rows.addAll(
          values.map(
            (r) => <String, dynamic>{
              ...Map<String, dynamic>.from(r as Map),
              'revision': record['revision'],
            },
          ),
        );
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.history),
          content: SizedBox(
            width: 500,
            height: 360,
            child: rows.isEmpty
                ? Text(l.skillEmptyHistory)
                : ListView(
                    children: [
                      for (final r in rows)
                        ListTile(
                          title: Text(label(l, r['status'] as String)),
                          subtitle: Text(
                            '${l.skillRecheck} ${r['revision']} · ${r['author_name'] ?? l.skillMember}\n${r['reason'] ?? ''}',
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.syncOffline)));
      }
    }
  }

  Future<void> roster(BuildContext context) async {
    final epoch = revision,
        l = AppLocalizations.of(context),
        accounts = skills.roster;
    final members = {for (final m in store.members(team)) m['id']: m};
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.skillTeam),
        content: SizedBox(
          width: 520,
          height: 420,
          child: StreamBuilder<String>(
            stream: updates,
            builder: (context, snapshot) {
              if (revision != epoch) return Text(l.skillMaterialChanged);
              return ListView(
                children: [
                  for (final account in accounts.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            members[account.value]?['name'] as String? ??
                                l.skillMember,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          control(context, account.key, epoch),
                          TextButton(
                            onPressed: () =>
                                history(context, account.key, epoch),
                            child: Text(l.history),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<String>(
    stream: updates,
    builder: (context, snapshot) {
      final l = AppLocalizations.of(context), epoch = revision;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 28),
          Text(l.skillTitle, style: Theme.of(context).textTheme.titleMedium),
          if (epoch > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${l.skillRecheck}: ${details['review_reason'] ?? ''}',
                style: const TextStyle(color: Studio.muted),
              ),
            ),
          Text(
            l.skillSelf,
            style: const TextStyle(color: Studio.muted, fontSize: 11),
          ),
          control(context, skills.user, epoch),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => history(context, skills.user, epoch),
                icon: const Icon(Icons.history),
                label: Text(l.history),
              ),
              if (store.canEditTeam(team))
                TextButton.icon(
                  onPressed: () => roster(context),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l.skillTeam),
                ),
            ],
          ),
        ],
      );
    },
  );
}
