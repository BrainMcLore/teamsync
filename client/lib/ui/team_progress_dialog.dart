import 'package:flutter/material.dart';

import '../data/store.dart';
import '../data/team_progress.dart';
import '../l10n/app_localizations.dart';

class TeamProgressDialog extends StatelessWidget {
  final Store store;
  final String team;
  const TeamProgressDialog({
    super.key,
    required this.store,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final report = TeamProgress(store.tasks(team), now: DateTime.now());
    final roster = store.members(team);
    Widget metrics(TaskProgress p) => Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        Text('${l.progressTotal}: ${p.total}'),
        Text('${l.todo}: ${p.count('todo')}'),
        Text('${l.taskInProgress}: ${p.count('in_progress')}'),
        Text('${l.submitted}: ${p.count('submitted')}'),
        Text('${l.approved}: ${p.count('approved')}'),
        Text('${l.progressOverdue}: ${p.overdue}'),
        if (p.states.keys.any(
          (s) => !['todo', 'in_progress', 'submitted', 'approved'].contains(s),
        ))
          Text(
            '${l.progressUnknown}: ${p.states.entries.where((e) => !['todo', 'in_progress', 'submitted', 'approved'].contains(e.key)).fold<int>(0, (n, e) => n + e.value)}',
          ),
      ],
    );
    final known = roster.map((m) => m['id']).toSet();
    return AlertDialog(
      title: Text(l.teamProgress),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.progressSnapshotHelp),
              const SizedBox(height: 16),
              metrics(report.overall),
              const Divider(height: 32),
              for (final member in roster) ...[
                Text(
                  member['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                metrics(report.members[member['id']] ?? TaskProgress()),
                const Divider(height: 24),
              ],
              for (final entry in report.members.entries.where(
                (e) => !known.contains(e.key),
              )) ...[
                Text(
                  l.progressUnassigned,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                metrics(entry.value),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
