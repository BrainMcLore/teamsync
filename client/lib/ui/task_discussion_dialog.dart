import 'package:flutter/material.dart';

import '../data/task_discussion.dart';
import '../l10n/app_localizations.dart';

class TaskDiscussionDialog extends StatefulWidget {
  final TaskDiscussion discussion;
  const TaskDiscussionDialog({super.key, required this.discussion});
  @override
  State<TaskDiscussionDialog> createState() => _TaskDiscussionDialogState();
}

class _TaskDiscussionDialogState extends State<TaskDiscussionDialog> {
  final text = TextEditingController();
  List<Map<String, dynamic>> rows = [], pending = [];
  bool loading = false, offline = false, failed = false;
  String? next;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      await widget.discussion.flush();
      final page = await widget.discussion.comments(before: more ? next : null);
      if (!mounted) return;
      rows = more ? [...rows, ...page.items] : page.items;
      next = page.next;
      offline = false;
    } catch (_) {
      if (!mounted) return;
      try {
        rows = widget.discussion.cached();
      } catch (_) {
        rows = [];
      }
      offline = true;
      next = null;
    } finally {
      if (mounted) {
        try {
          pending = widget.discussion.pending();
        } catch (_) {
          pending = [];
          rows = [];
        }
        setState(() => loading = false);
      }
    }
  }

  Future<void> send() async {
    try {
      widget.discussion.enqueue(text.text);
      text.clear();
      await load();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(l.taskDiscussion),
      content: SizedBox(
        width: 520,
        height: 440,
        child: ListView(
          children: [
            if (loading) const LinearProgressIndicator(),
            if (offline) Text(l.discussionOffline),
            if (failed) Text(l.discussionFailed),
            if (rows.isEmpty && pending.isEmpty && !loading) Text(l.noData),
            for (final row in pending.where(
              (r) => !rows.any((c) => c['id'] == r['id']),
            ))
              ListTile(
                title: Text(row['text'] as String),
                subtitle: Text(l.discussionPending),
              ),
            for (final row in rows)
              ListTile(
                title: SelectableText(row['text'] as String),
                subtitle: Text(
                  '${row['author_name'] ?? row['author_id']} · ${DateTime.fromMillisecondsSinceEpoch(((row['created'] as num) * 1000).round()).toLocal()}',
                ),
              ),
            if (next != null && !loading)
              TextButton(
                onPressed: () => load(more: true),
                child: Text(l.historyMore),
              ),
            if (widget.discussion.canPost) ...[
              TextField(
                controller: text,
                maxLength: 5000,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.discussionMessage),
              ),
              TextButton.icon(
                onPressed: loading ? null : send,
                icon: const Icon(Icons.send_outlined),
                label: Text(l.discussionSend),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : load,
          child: Text(l.discussionRefresh),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
