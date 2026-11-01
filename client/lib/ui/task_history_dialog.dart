import 'package:flutter/material.dart';

import '../data/task_history.dart';
import '../l10n/app_localizations.dart';

class TaskHistoryDialog extends StatefulWidget {
  final TaskHistory history;
  const TaskHistoryDialog({super.key, required this.history});
  @override
  State<TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<TaskHistoryDialog> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true, offline = false, more = false;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final result = await widget.history.page(offset);
      if (!mounted) return;
      setState(() {
        rows = offset == 0 ? result : [...rows, ...result];
        offset += result.length;
        more = result.length == 50;
        offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      try {
        rows = widget.history.cached();
      } catch (_) {
        rows = [];
      }
      setState(() {
        offline = true;
        more = false;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String status(String value) => switch (value) {
      'todo' => l.todo,
      'in_progress' => l.taskInProgress,
      'submitted' => l.submitted,
      _ => l.approved,
    };
    return AlertDialog(
      title: Text(l.history),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          children: [
            if (offline) Text(l.syncOffline),
            if (loading) const LinearProgressIndicator(),
            Expanded(
              child: rows.isEmpty && !loading
                  ? Center(child: Text(l.noData))
                  : ListView(
                      children: [
                        for (final row in rows)
                          ListTile(
                            title: Text(
                              '${l.version(row['version'] as int)} · ${status((row['payload'] as Map)['status'] as String? ?? 'todo')}',
                            ),
                            subtitle: Text(
                              '${row['author_name'] ?? row['author_id']} · ${DateTime.fromMillisecondsSinceEpoch(((row['created'] as num) * 1000).round()).toLocal()}\n${(row['payload'] as Map)['task_review_reason'] ?? ''}',
                            ),
                          ),
                        if (more && !loading)
                          TextButton(
                            onPressed: load,
                            child: Text(l.historyMore),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
