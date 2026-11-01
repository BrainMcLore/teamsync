import 'dart:io';

import 'package:flutter/material.dart';

import '../data/files.dart';
import '../data/playbook.dart';
import '../data/playbook_drafts.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';

Future<void> attachStrategyToPlaybook(
  BuildContext context,
  Store store,
  LocalFiles files,
  String strategy,
) async {
  final row = store.strategy(strategy);
  final owner =
      store.rows('SELECT team_id FROM maps WHERE id=?', [
            row['map_id'],
          ]).single['team_id']
          as String;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PlaybookEditor(
        store: store,
        files: files,
        team: owner,
        pendingStrategy: strategy,
      ),
    ),
  );
}

class PlaybookEditor extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  final String team;
  final String? pendingStrategy;
  const PlaybookEditor({
    super.key,
    required this.store,
    required this.files,
    required this.team,
    this.pendingStrategy,
  });
  @override
  State<PlaybookEditor> createState() => _PlaybookEditorState();
}

class _PlaybookEditorState extends State<PlaybookEditor> {
  AppLocalizations get l => AppLocalizations.of(context);
  late PlaybookDrafts drafts;
  late List<Map<String, dynamic>> books;
  String? selected;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    drafts = PlaybookDrafts(widget.store, widget.files.root, widget.team);
    books = drafts.load();
    selected = books.firstOrNull?['id'] as String?;
  }

  Map<String, dynamic>? get book =>
      books.where((b) => b['id'] == selected).firstOrNull;
  void persist() => drafts.save(books);
  void notice(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  Future<void> create() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _BookTitleDialog(title: l.newPlaybook),
    );
    if (title == null) return;
    final value = drafts.create(title, '${l.roundLabel} 1');
    setState(() {
      books = drafts.load();
      selected = value['id'] as String;
    });
  }

  Future<void> attach(Map page) async {
    var id = widget.pendingStrategy;
    id ??= await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.attachTactic),
        children: [
          for (final strategy in widget.store.strategies(widget.team))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, strategy['id']),
              child: Text('${strategy['map_name']} / ${strategy['title']}'),
            ),
        ],
      ),
    );
    if (id == null) return;
    setState(() => busy = true);
    try {
      persist();
      await drafts.attach(selected!, page['id'] as String, id);
      if (mounted) {
        setState(() => books = drafts.load());
        notice(l.snapshotSaved);
      }
    } catch (_) {
      if (mounted) notice(l.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    persist();
    final language = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.exportLanguage),
        children: [
          for (final pair in [('ru', 'Русский'), ('en', 'English')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, pair.$1),
              child: Text(pair.$2),
            ),
        ],
      ),
    );
    if (language == null) return;
    setState(() => busy = true);
    try {
      final labels = await AppLocalizations.delegate.load(Locale(language));
      await Playbook.saveDraftPdf(book!, labels);
    } catch (_) {
      if (mounted) notice(l.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(Map page, String key, String label, {int lines = 1}) =>
      TextFormField(
        key: ValueKey('${page['id']}:$key'),
        initialValue: page[key] as String? ?? '',
        maxLength: key == 'title' ? 120 : 10000,
        minLines: lines,
        maxLines: lines + 3,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
        onChanged: (value) {
          page[key] = value;
          persist();
        },
      );
  @override
  Widget build(BuildContext context) {
    final pages = book?['pages'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.playbooks),
        actions: [
          if (book != null)
            IconButton(
              tooltip: l.exportDocument,
              onPressed: busy ? null : export,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l.playbookHelp,
            style: const TextStyle(color: Studio.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (books.isNotEmpty)
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    isExpanded: true,
                    items: [
                      for (final b in books)
                        DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(b['title'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => selected = v),
                  ),
                ),
              FilledButton.icon(
                onPressed: busy ? null : create,
                icon: const Icon(Icons.add),
                label: Text(l.newPlaybook),
              ),
              if (book != null)
                OutlinedButton.icon(
                  onPressed: busy || pages.length >= 50
                      ? null
                      : () => setState(() {
                          pages.add(
                            PlaybookDrafts.page(
                              '${l.roundLabel} ${pages.length + 1}',
                            ),
                          );
                          persist();
                        }),
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(l.addRound),
                ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          for (var i = 0; i < pages.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.roundLabel} ${i + 1}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l.moveUp,
                          onPressed: busy || i == 0
                              ? null
                              : () => setState(() {
                                  final value = pages.removeAt(i);
                                  pages.insert(i - 1, value);
                                  persist();
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: l.moveDown,
                          onPressed: busy || i == pages.length - 1
                              ? null
                              : () => setState(() {
                                  final value = pages.removeAt(i);
                                  pages.insert(i + 1, value);
                                  persist();
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: l.removePage,
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  pages.removeAt(i);
                                  persist();
                                }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    field(pages[i] as Map, 'title', l.title),
                    field(pages[i] as Map, 'economy', l.economy),
                    field(pages[i] as Map, 'plan', l.roundPlan, lines: 3),
                    field(
                      pages[i] as Map,
                      'roles',
                      l.responsibilities,
                      lines: 3,
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => attach(pages[i] as Map),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(l.attachTactic),
                    ),
                    for (final raw in pages[i]['attachments'] as List) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${raw['title']} · ${raw['map']} / ${raw['side']} · ${l.captureVersion} ${raw['version']}',
                            ),
                          ),
                          IconButton(
                            tooltip: l.removeAttachment,
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    (pages[i]['attachments'] as List).remove(
                                      raw,
                                    );
                                    persist();
                                  }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Image.file(
                        File(raw['path'] as String),
                        height: 300,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, s) => Text(l.fileMissing),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
          if (book != null)
            FilledButton.icon(
              onPressed: busy ? null : export,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l.exportDocument),
            ),
        ],
      ),
    );
  }
}

class _BookTitleDialog extends StatefulWidget {
  final String title;
  const _BookTitleDialog({required this.title});
  @override
  State<_BookTitleDialog> createState() => _BookTitleDialogState();
}

class _BookTitleDialogState extends State<_BookTitleDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 120,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, controller.text.trim()),
          child: Text(l.create),
        ),
      ],
    );
  }
}
