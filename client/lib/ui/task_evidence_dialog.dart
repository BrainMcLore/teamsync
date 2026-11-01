import 'package:flutter/material.dart';

import '../data/task_evidence.dart';
import '../data/store.dart';
import '../data/own_video.dart';
import '../l10n/app_localizations.dart';

class TaskEvidenceDialog extends StatefulWidget {
  final TaskEvidence evidence;
  const TaskEvidenceDialog({super.key, required this.evidence});
  @override
  State<TaskEvidenceDialog> createState() => _TaskEvidenceDialogState();
}

class _TaskEvidenceDialogState extends State<TaskEvidenceDialog> {
  List<Map<String, dynamic>> rows = [], pending = [];
  bool busy = false, offline = false, failed = false;
  String? next, failureCode;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false, bool keepFailure = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      if (!keepFailure) {
        failed = false;
        failureCode = null;
      }
    });
    try {
      await widget.evidence.flush();
      final page = await widget.evidence.comments(before: more ? next : null);
      if (!mounted) return;
      rows = more ? [...rows, ...page.items] : page.items;
      next = page.next;
      offline = false;
    } catch (error) {
      failureCode = error is DomainError ? error.code : null;
      failed = [
        'media_quota',
        'fileMissing',
        'invalid_media',
        'invalid_transition',
        'forbidden',
        'limit',
      ].contains(failureCode);
      if (!mounted) return;
      try {
        rows = widget.evidence.cached();
      } catch (_) {
        rows = [];
      }
      offline = true;
      next = null;
    } finally {
      if (mounted) {
        try {
          pending = widget.evidence.pending();
        } catch (_) {
          pending = [];
          rows = [];
        }
        setState(() => busy = false);
      }
    }
  }

  Future<void> attach(bool video) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      failureCode = null;
    });
    try {
      final path = video
          ? await OwnVideo.pick(widget.evidence.files)
          : await widget.evidence.files.importRadar();
      if (path != null) await widget.evidence.enqueueFile(path);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => busy = false);
    await load(keepFailure: failed);
  }

  Future<void> open(Map row) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      failureCode = null;
    });
    try {
      final file = await widget.evidence.openFile(row);
      widget.evidence.assertActive();
      if (row['mime'] == 'video/mp4') {
        await OwnVideo.open(file.path);
      } else if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            content: SizedBox(
              width: 520,
              height: 400,
              child: InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(l.taskEvidence),
      content: SizedBox(
        width: 520,
        height: 440,
        child: ListView(
          children: [
            ExpansionTile(
              title: Text(l.evidenceLimits),
              children: [Text(l.evidenceHelp)],
            ),
            if (busy) const LinearProgressIndicator(),
            if (offline) Text(l.discussionOffline),
            if (failed)
              Text(
                failureCode == 'media_quota'
                    ? l.syncMediaQuota
                    : failureCode == 'fileMissing'
                    ? l.fileMissing
                    : l.evidenceFailed,
              ),
            for (final row in pending.where(
              (r) => !rows.any((e) => e['id'] == r['id']),
            ))
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  row['mime'] == 'video/mp4'
                      ? l.evidenceVideoType
                      : l.evidenceImageType,
                ),
                subtitle: Text(l.discussionPending),
                trailing: IconButton(
                  tooltip: l.evidenceRemovePending,
                  onPressed: busy
                      ? null
                      : () {
                          try {
                            widget.evidence.discardPending(row['id'] as String);
                            setState(() => pending = widget.evidence.pending());
                          } catch (_) {
                            setState(() => failed = true);
                          }
                        },
                  icon: const Icon(Icons.close),
                ),
              ),
            for (final row in rows)
              ListTile(
                leading: Icon(
                  row['mime'] == 'video/mp4'
                      ? Icons.movie_outlined
                      : Icons.image_outlined,
                ),
                title: Text(
                  '${row['mime'] == 'video/mp4' ? l.evidenceVideoType : l.evidenceImageType} · ${((row['size'] as num) / 1024).ceil()} KB',
                ),
                subtitle: Text(
                  '${l.version(row['task_version'] as int)} · ${row['author_name'] ?? row['author_id']} · ${DateTime.fromMillisecondsSinceEpoch(((row['created'] as num) * 1000).round()).toLocal()}',
                ),
                onTap: busy ? null : () => open(row),
              ),
            if (next != null && !busy)
              TextButton(
                onPressed: () => load(more: true),
                child: Text(l.historyMore),
              ),
            if (widget.evidence.canPost)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => attach(false),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l.evidenceImage),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => attach(true),
                    icon: const Icon(Icons.video_call_outlined),
                    label: Text(l.evidenceVideo),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : load,
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
