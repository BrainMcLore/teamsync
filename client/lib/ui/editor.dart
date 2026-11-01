import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/store.dart';
import '../data/files.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'playbook_editor.dart';

class StrategyEditor extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  final String id;
  final Future<void> Function() onTask;
  const StrategyEditor({
    super.key,
    required this.store,
    required this.files,
    required this.id,
    required this.onTask,
  });
  @override
  State<StrategyEditor> createState() => _StrategyEditorState();
}

class _StrategyEditorState extends State<StrategyEditor> {
  AppLocalizations get l => AppLocalizations.of(context);
  late RecordData row;
  late TextEditingController notes;
  List<Map<String, dynamic>> objects = [];
  final List<String> undoStack = [], redoStack = [];
  String tool = 't';
  String level = 'default';
  bool dirty = false, busy = false;
  late bool readOnly;
  StreamSubscription<String>? remoteUpdates;
  Offset? start, end;
  @override
  void initState() {
    super.initState();
    row = widget.store.strategy(widget.id);
    readOnly = !widget.store.canEditTeam(
      widget.store.rows('SELECT team_id FROM maps WHERE id=?', [
            row['map_id'],
          ]).single['team_id']
          as String,
    );
    level = row['level'] as String? ?? 'default';
    notes = TextEditingController(text: row['notes'] as String);
    loadObjects();
    notes.addListener(changedNotes);
    remoteUpdates = widget.store.tacticalUpdates.listen((id) {
      if (id != widget.id || !mounted || dirty) return;
      notes.removeListener(changedNotes);
      setState(() {
        row = widget.store.strategy(widget.id);
        notes.text = row['notes'] as String;
        level = row['level'] as String;
        loadObjects();
      });
      notes.addListener(changedNotes);
    });
  }

  void changedNotes() {
    if (!readOnly) widget.store.editingStrategies.add(widget.id);
    if (!dirty) setState(() => dirty = true);
  }

  void loadObjects() {
    objects = (jsonDecode(row['objects'] as String) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  void dispose() {
    remoteUpdates?.cancel();
    widget.store.editingStrategies.remove(widget.id);
    notes.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void mutate(VoidCallback action) {
    if (readOnly) return;
    widget.store.editingStrategies.add(widget.id);
    undoStack.add(jsonEncode(objects));
    redoStack.clear();
    setState(() {
      action();
      dirty = true;
    });
  }

  void undo() {
    if (undoStack.isEmpty) return;
    widget.store.editingStrategies.add(widget.id);
    redoStack.add(jsonEncode(objects));
    setState(() {
      objects = decodeObjects(undoStack.removeLast());
      dirty = true;
    });
  }

  void redo() {
    if (redoStack.isEmpty) return;
    widget.store.editingStrategies.add(widget.id);
    undoStack.add(jsonEncode(objects));
    setState(() {
      objects = decodeObjects(redoStack.removeLast());
      dirty = true;
    });
  }

  List<Map<String, dynamic>> decodeObjects(String value) =>
      (jsonDecode(value) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<bool> save() async {
    if (readOnly) {
      message(l.readOnlyTeam);
      return false;
    }
    if (!dirty) return true;
    try {
      widget.store.saveStrategy(
        widget.id,
        notes.text,
        objects,
        row['version'] as int,
        level: level,
      );
      setState(() {
        row = widget.store.strategy(widget.id);
        dirty = false;
      });
      widget.store.editingStrategies.remove(widget.id);
      message(l.saved);
      return true;
    } catch (e) {
      message(e is DomainError && e.code == 'conflict' ? l.conflict : l.error);
      return false;
    }
  }

  Future<void> back() async {
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: Text(l.stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(l.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (choice == 'discard' || choice == 'save' && await save()) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> radar() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final path = await widget.files.importRadar();
      if (path != null) {
        widget.store.mapImage(row['map_id'] as String, path);
        if (mounted) setState(() => row = widget.store.strategy(widget.id));
      }
    } catch (e) {
      if (mounted) {
        message(
          e is DomainError && e.code == 'invalidImage'
              ? l.invalidImage
              : l.error,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> history() async {
    // Preserve unsaved work before restoring a historical version.
    if (dirty && !await save()) return;
    if (!mounted) return;
    final versions = widget.store.versions(widget.id);
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.history),
        content: SizedBox(
          width: 500,
          height: 350,
          child: ListView.separated(
            itemCount: versions.length,
            separatorBuilder: (_, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final v = versions[i];
              return ListTile(
                title: Text(l.version(v['version'] as int)),
                subtitle: Text(
                  DateFormat.yMMMd(l.localeName).add_Hm().format(
                    DateTime.parse(v['created_at'] as String).toLocal(),
                  ),
                ),
                trailing: IconButton(
                  tooltip: l.restore,
                  icon: const Icon(Icons.restore),
                  onPressed: readOnly
                      ? null
                      : () => Navigator.pop(ctx, v['version'] as int),
                ),
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
    if (selected == null) return;
    try {
      widget.store.restoreVersion(widget.id, selected);
      if (mounted) {
        setState(() {
          row = widget.store.strategy(widget.id);
          level = row['level'] as String? ?? 'default';
          loadObjects();
          notes.removeListener(changedNotes);
          notes.text = row['notes'] as String;
          notes.addListener(changedNotes);
          undoStack.clear();
          redoStack.clear();
          dirty = false;
        });
      }
    } catch (_) {
      if (mounted) message(l.error);
    }
  }

  List<(String, String, IconData)> get tools => [
    ('t', l.playerT, Icons.circle_outlined),
    ('ct', l.playerCT, Icons.shield_outlined),
    ('smoke', l.smoke, Icons.cloud_outlined),
    ('flash', l.flash, Icons.flash_on_outlined),
    ('molotov', l.molotov, Icons.local_fire_department_outlined),
    ('arrow', l.arrow, Icons.trending_flat),
  ];
  Widget toolbar() => Wrap(
    spacing: 4,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final t in tools)
        Tooltip(
          message: t.$2,
          child: IconButton(
            isSelected: tool == t.$1,
            onPressed: () => setState(() => tool = t.$1),
            icon: Icon(t.$3),
          ),
        ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: l.undo,
        onPressed: undoStack.isEmpty ? null : undo,
        icon: const Icon(Icons.undo),
      ),
      IconButton(
        tooltip: l.redo,
        onPressed: redoStack.isEmpty ? null : redo,
        icon: const Icon(Icons.redo),
      ),
      IconButton(
        tooltip: l.clear,
        onPressed: objects.isEmpty ? null : () => mutate(() => objects.clear()),
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ],
  );
  Widget canvas() {
    final map = widget.files.catalog?.find(row['map_key'] as String? ?? '');
    final path = level == 'lower'
        ? (row['lower_image_path'] as String? ??
              (map != null
                  ? widget.files.catalog!.radar(map, level)
                  : row['image_path'] as String?))
        : (row['primary_image_path'] as String? ??
              row['image_path'] as String?);
    final available = path != null && File(path).existsSync();
    if (!available) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 48),
              const SizedBox(height: 16),
              Text(l.radarHelp, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : radar,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(l.importRadar),
              ),
            ],
          ),
        ),
      );
    }
    return RadarCanvas(
      path: path,
      objects: objects,
      tool: tool,
      onAdd: (object) => mutate(() => objects.add(object)),
    );
  }

  Widget notesPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l.version(row['version'] as int),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text('${row['map_name']} · ${row['side']}'),
      if ((widget.files.catalog?.find(
                    row['map_key'] as String? ?? '',
                  )?['levels']
                  as List?)
              ?.length ==
          2) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: level,
          decoration: InputDecoration(labelText: l.chooseLevel),
          items: [
            DropdownMenuItem(value: 'default', child: Text(l.upperLevel)),
            DropdownMenuItem(value: 'lower', child: Text(l.lowerLevel)),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                level = v;
                if (!readOnly) {
                  dirty = true;
                  widget.store.editingStrategies.add(widget.id);
                }
              });
            }
          },
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: notes,
        readOnly: readOnly,
        maxLength: 20000,
        minLines: 5,
        maxLines: 10,
        decoration: InputDecoration(
          labelText: l.notes,
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      Text(l.objectCount(objects.length)),
      const SizedBox(height: 8),
      Text(l.playerLegend, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: () async {
          if (!await save() || !mounted) return;
          await attachStrategyToPlaybook(
            context,
            widget.store,
            widget.files,
            widget.id,
          );
        },
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l.attachToPlaybook),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          if (await save()) {
            try {
              await widget.onTask();
            } catch (_) {
              if (mounted) message(l.error);
            }
          }
        },
        icon: const Icon(Icons.assignment_outlined),
        label: Text(l.newTask),
      ),
      const SizedBox(height: 12),
      Text(l.tipArrow, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
          SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true): SaveIntent(),
        },
        child: Actions(
          actions: {
            UndoIntent: CallbackAction<UndoIntent>(
              onInvoke: (_) {
                undo();
                return null;
              },
            ),
            RedoIntent: CallbackAction<RedoIntent>(
              onInvoke: (_) {
                redo();
                return null;
              },
            ),
            SaveIntent: CallbackAction<SaveIntent>(
              onInvoke: (_) {
                save();
                return null;
              },
            ),
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: l.back,
                onPressed: back,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['title'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dirty ? l.unsaved : l.saved,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l.attachToPlaybook,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () async {
                    if (!await save()) return;
                    if (!context.mounted) return;
                    await attachStrategyToPlaybook(
                      context,
                      widget.store,
                      widget.files,
                      widget.id,
                    );
                  },
                ),
                IconButton(
                  tooltip: l.history,
                  onPressed: history,
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  tooltip: l.importRadar,
                  onPressed: busy ? null : radar,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton.filled(
                    tooltip: l.save,
                    onPressed: dirty ? save : null,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                toolbar(),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ColoredBox(
                                      color: Studio.surface,
                                      child: canvas(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 300,
                            child: SingleChildScrollView(
                              child: StudioPanel(child: notesPanel()),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          toolbar(),
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * .52,
                            child: canvas(),
                          ),
                          const SizedBox(height: 24),
                          notesPanel(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class RadarCanvas extends StatefulWidget {
  final String path, tool;
  final List<Map<String, dynamic>> objects;
  final ValueChanged<Map<String, dynamic>> onAdd;
  const RadarCanvas({
    super.key,
    required this.path,
    required this.objects,
    required this.tool,
    required this.onAdd,
  });
  @override
  State<RadarCanvas> createState() => _RadarCanvasState();
}

class _RadarCanvasState extends State<RadarCanvas> {
  Size? imageSize;
  ImageStream? stream;
  ImageStreamListener? listener;
  Offset? start, end;
  bool failed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    resolve();
  }

  @override
  void didUpdateWidget(RadarCanvas old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) resolve();
  }

  void resolve() {
    if (stream != null && listener != null) stream!.removeListener(listener!);
    imageSize = null;
    failed = false;
    stream = FileImage(File(widget.path))
        .resolve(createLocalImageConfiguration(context));
    listener = ImageStreamListener(
      (image, synchronous) {
        if (mounted) {
          setState(
            () => imageSize = Size(
              image.image.width.toDouble(),
              image.image.height.toDouble(),
            ),
          );
        }
      },
      onError: (error, stack) {
        if (mounted) setState(() => failed = true);
      },
    );
    stream!.addListener(listener!);
  }

  @override
  void dispose() {
    if (stream != null && listener != null) stream!.removeListener(listener!);
    super.dispose();
  }

  Offset normalize(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
  void add(Offset p, Size size) {
    final n = normalize(p, size);
    widget.onAdd({'type': widget.tool, 'x': n.dx, 'y': n.dy});
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(child: Text(AppLocalizations.of(context).invalidImage));
    }
    if (imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, c) {
        final fitted = applyBoxFit(
          BoxFit.contain,
          imageSize!,
          Size(c.maxWidth, c.maxHeight),
        ).destination;
        return Center(
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: GestureDetector(
              onTapUp: widget.tool == 'arrow'
                  ? null
                  : (d) => add(d.localPosition, fitted),
              onPanStart: widget.tool != 'arrow'
                  ? null
                  : (d) => setState(() {
                      start = normalize(d.localPosition, fitted);
                      end = start;
                    }),
              onPanUpdate: widget.tool != 'arrow'
                  ? null
                  : (d) => setState(
                      () => end = normalize(d.localPosition, fitted),
                    ),
              onPanCancel: () => setState(() {
                start = null;
                end = null;
              }),
              onPanEnd: widget.tool != 'arrow'
                  ? null
                  : (d) {
                      if (start != null &&
                          end != null &&
                          (end! - start!).distance > 0.01) {
                        widget.onAdd({
                          'type': 'arrow',
                          'x': start!.dx,
                          'y': start!.dy,
                          'x2': end!.dx,
                          'y2': end!.dy,
                        });
                      }
                      setState(() {
                        start = null;
                        end = null;
                      });
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(widget.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) => const SizedBox.shrink(),
                  ),
                  CustomPaint(
                    painter: TacticalPainter([
                      ...widget.objects,
                      if (start != null && end != null)
                        {
                          'type': 'arrow',
                          'x': start!.dx,
                          'y': start!.dy,
                          'x2': end!.dx,
                          'y2': end!.dy,
                        },
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TacticalPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final double symbolScale;
  TacticalPainter(this.objects, {this.symbolScale = 1});
  @override
  void paint(Canvas canvas, Size size) {
    var marker = 0, ct = 0, t = 0;
    for (final o in objects) {
      final p = Offset(
        (o['x'] as num).toDouble() * size.width,
        (o['y'] as num).toDouble() * size.height,
      );
      final color = switch (o['type']) {
        'marker' || 't' => const Color(0xfff2bc60),
        'ct' => const Color(0xff75bdff),
        'smoke' => const Color(0xffb4c5d4),
        'flash' => const Color(0xffffeab1),
        'molotov' => const Color(0xffed986e),
        _ => const Color(0xff81c8b2),
      };
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3;
      if (o['type'] == 'arrow') {
        final end = Offset(
          (o['x2'] as num).toDouble() * size.width,
          (o['y2'] as num).toDouble() * size.height,
        );
        canvas.drawLine(p, end, paint);
        final angle = math.atan2(end.dy - p.dy, end.dx - p.dx);
        for (final delta in [-0.5, 0.5]) {
          canvas.drawLine(
            end,
            end -
                Offset(
                  math.cos(angle + delta) * 13,
                  math.sin(angle + delta) * 13,
                ),
            paint,
          );
        }
      } else {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.scale(symbolScale);
        const q = Offset.zero;
        if (o['type'] == 'ct') {
          final shield = Path()
            ..moveTo(q.dx - 18, q.dy - 16)
            ..lineTo(q.dx + 18, q.dy - 16)
            ..lineTo(q.dx + 16, q.dy + 8)
            ..lineTo(q.dx, q.dy + 20)
            ..lineTo(q.dx - 16, q.dy + 8)
            ..close();
          canvas.drawPath(shield, Paint()..color = const Color(0xff101b2b));
          canvas.drawPath(shield, paint..style = PaintingStyle.stroke);
        } else {
          final radius = o['type'] == 't' ? 19.0 : 15.0;
          canvas.drawCircle(
            q,
            radius,
            Paint()..color = const Color(0xff101417),
          );
          canvas.drawCircle(q, radius - 2, paint..style = PaintingStyle.stroke);
        }
        final label = switch (o['type']) {
          'marker' => '${++marker}',
          't' => 'T${++t}',
          'ct' => 'CT${++ct}',
          'smoke' => 'S',
          'flash' => 'F',
          _ => 'M',
        };
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, q - Offset(text.width / 2, text.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant TacticalPainter oldDelegate) => true;
}
