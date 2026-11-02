import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

import '../data/review_index.dart';

import 'package:share_plus/share_plus.dart';

import '../data/files.dart';
import '../data/map_catalog.dart';
import '../data/review_data.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'open_demo_cs.dart';
import 'demo_tags.dart';

Future<String?> getReviewSavePath() async => (await getSaveLocation(
  suggestedName: 'TeamSync.teamsync-review',
  acceptedTypeGroups: [
    const XTypeGroup(label: 'TeamSync review', extensions: ['teamsync-review']),
  ],
))?.path;

class DemoReviewPage extends StatefulWidget {
  final Store store;
  final LocalFiles files;
  final RecordData demo;
  final Map<String, dynamic>? initialData;
  const DemoReviewPage({
    super.key,
    required this.store,
    required this.files,
    required this.demo,
    this.initialData,
  });
  @override
  State<DemoReviewPage> createState() => _DemoReviewPageState();
}

class _DemoReviewPageState extends State<DemoReviewPage>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l => AppLocalizations.of(context);
  Map<String, dynamic>? data;
  bool failed = false, playing = false, trails = false;
  int index = 0, round = 1, side = 0;
  double speed = 1;
  String level = 'default', selectedPlayer = '';
  late final Ticker ticker;
  final position = ValueNotifier<double>(0);
  double baseTick = 0;
  late ReviewIndex reviewIndex;
  MapCatalog? catalogCache;
  List<RecordData> noteCache = [];
  void refreshNotes() {
    noteCache = widget.store.annotations(widget.demo['id'] as String);
  }

  void onPlaybackFrame(Duration elapsed) {
    if (!playing || data == null) return;
    final next =
        baseTick +
        elapsed.inMicroseconds / 1000000 * (data!['tick_rate'] as num) * speed;
    final end = (frames.last['tick'] as int).toDouble();
    position.value = next.clamp(0.0, end);
    final value = floorFrameAtTick(frames, position.value);
    if (value != index || next >= end) {
      setState(() {
        index = value;
        round = (frame['round'] as int).clamp(
          1,
          (data!['rounds'] as List).length,
        );
        if (next >= end) stop();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    ticker = createTicker(onPlaybackFrame);
    refreshNotes();
    if (widget.initialData != null) {
      applyData(widget.initialData!);
    } else {
      load();
    }
  }

  void applyData(Map<String, dynamic> value) {
    data = value;
    reviewIndex = value['_index'] as ReviewIndex? ?? ReviewIndex(value);
    catalogCache = widget.files.catalog;
    final start = ((value['rounds'] as List).first as Map)['start'] as int;
    final found = (value['frames'] as List).indexWhere(
      (frame) => (frame['tick'] as int) >= start,
    );
    index = found < 0 ? 0 : found;
    position.value = (frame['tick'] as int).toDouble();
  }

  Future<void> load() async {
    try {
      final review = await readReview(widget.demo['analysis_path'] as String);
      if (mounted) setState(() => applyData(review));
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    position.dispose();
    super.dispose();
  }

  List<dynamic> get frames => data!['frames'] as List;
  Map get frame => frames[index] as Map;
  int get tick => position.value.floor();
  void stop() {
    ticker.stop();
    playing = false;
  }

  void play() {
    if (playing) {
      setState(stop);
      return;
    }
    if (index == frames.length - 1) {
      index = 0;
      position.value = (frame['tick'] as int).toDouble();
    }
    baseTick = position.value;
    setState(() => playing = true);
    ticker.start();
  }

  void step(int delta) {
    setState(() {
      stop();
      index = (index + delta).clamp(0, frames.length - 1);
      position.value = (frame['tick'] as int).toDouble();
      round = (frame['round'] as int).clamp(
        1,
        (data!['rounds'] as List).length,
      );
    });
  }

  void selectRound(int value) {
    final entry = (data!['rounds'] as List).firstWhere(
      (r) => r['number'] == value,
    ) as Map;
    setState(() {
      stop();
      round = value;
      final found = frames.indexWhere(
        (f) => (f['tick'] as int) >= (entry['start'] as int),
      );
      index = found < 0 ? 0 : found;
      position.value = (frame['tick'] as int).toDouble();
    });
  }

  String timestamp(int at) {
    final seconds = (at / (data!['tick_rate'] as num)).floor();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void seekNote(Map note) => setState(() {
    stop();
    position.value = (note['tick'] as int)
        .clamp(frames.first['tick'] as int, frames.last['tick'] as int)
        .toDouble();
    index = floorFrameAtTick(frames, position.value);
    round = (frame['round'] as int).clamp(1, (data!['rounds'] as List).length);
  });
  Future<String?> noteDialog() => showDialog<String>(
    context: context,
    builder: (context) => _ReviewNoteDialog(
      at: '${timestamp(tick)} · ${l.roundLabel} $round · ${l.tickLabel} $tick',
    ),
  );
  Future<void> annotate() async {
    setState(stop);
    final at = tick, r = round;
    final text = await noteDialog();
    if (text == null) return;
    try {
      widget.store.annotate(widget.demo['id'] as String, at, r, text);
      refreshNotes();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.error)));
      }
    }
  }

  void createTask(Map note) {
    try {
      final text = note['note'] as String;
      widget.store.createTask(
        widget.demo['team_id'] as String,
        text.length > 120 ? '${text.substring(0, 117)}…' : text,
        '${widget.demo['name']}\n${l.roundLabel} ${note['round']} / ${l.tickLabel} ${note['tick']}\n$text',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saved)));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.error)));
    }
  }

  Future<void> share() async {
    Directory? temporary;
    try {
      final target = Platform.isWindows ? await getReviewSavePath() : null;
      if (Platform.isWindows && target == null) return;
      final current = widget.store
          .demos(widget.demo['team_id'] as String)
          .firstWhere((d) => d['id'] == widget.demo['id']);
      final bytes = await exportReview(widget.store, current);
      if (Platform.isWindows) {
        await File(target!).writeAsBytes(bytes, flush: true);
      } else {
        temporary = await Directory.systemTemp.createTemp('teamsync-review-');
        final file = File('${temporary.path}/TeamSync.teamsync-review');
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            fileNameOverrides: ['TeamSync.teamsync-review'],
            sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.error)));
      }
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Widget mapView() {
    final catalog = catalogCache,
        key = data!['map'] as String,
        map = catalog?.find(key);
    if (map == null) {
      return StudioPanel(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text(l.noCalibration, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final path = catalog!.radar(map, level);
    final players = frame['players'] as List;
    final history = trails
        ? frames
              .sublist(math.max(0, index - 24), index)
              .where((f) => f['round'] == frame['round'])
              .toList()
        : <dynamic>[];
    final points = reviewIndex.active(tick);
    return StudioPanel(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, c) {
          final size = math.min(c.maxWidth, c.maxHeight);
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: ReviewPainter(
                        position: position,
                        sourceFrame: frame,
                        nextFrame: index + 1 < frames.length
                            ? frames[index + 1] as Map
                            : null,
                        tickRate: data!['tick_rate'] as num,
                        catalog: catalog,
                        keyName: key,
                        players: players,
                        history: history,
                        points: points,
                        level: level,
                        side: side,
                        selected: selectedPlayer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget controls() {
    final time = (tick / (data!['tick_rate'] as num)).floor(),
        mins = time ~/ 60,
        seconds = time % 60;
    return StudioPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Slider(
            value: index.toDouble(),
            max: (frames.length - 1).toDouble(),
            onChanged: (v) => setState(() {
              stop();
              index = v.round();
              position.value = (frame['tick'] as int).toDouble();
              round = (frame['round'] as int).clamp(
                1,
                (data!['rounds'] as List).length,
              );
            }),
          ),
          if (widget.store
              .annotations(widget.demo['id'] as String)
              .isNotEmpty) ...[
            SizedBox(
              height: 22,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final notes = widget.store.annotations(
                    widget.demo['id'] as String,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, bounds) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final note in notes)
                            Positioned(
                              left:
                                  (frameIndexAtTick(
                                        frames,
                                        note['tick'] as int,
                                      ) /
                                      (frames.length - 1).clamp(
                                        1,
                                        frames.length,
                                      )) *
                                  (bounds.maxWidth - 18).clamp(
                                    0,
                                    bounds.maxWidth,
                                  ),
                              top: 0,
                              child: Tooltip(
                                message:
                                    '${timestamp(note['tick'] as int)} · ${note['note']}',
                                child: InkWell(
                                  onTap: () => seekNote(note),
                                  child: const Icon(
                                    Icons.bookmark,
                                    size: 18,
                                    color: Studio.accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.timelineNotes,
                style: const TextStyle(fontSize: 10, color: Studio.muted),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: l.previousFrame,
                onPressed: () => step(-1),
                icon: const Icon(Icons.skip_previous_outlined),
              ),
              IconButton.filled(
                tooltip: playing ? l.pause : l.play,
                onPressed: play,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: l.nextFrame,
                onPressed: () => step(1),
                icon: const Icon(Icons.skip_next_outlined),
              ),
              Text(
                '$mins:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 13,
                ),
              ),
              Text(
                '${l.tickLabel} $tick',
                style: const TextStyle(color: Studio.muted, fontSize: 11),
              ),
              DropdownButton<double>(
                value: speed,
                items: [
                  for (final v in [.5, 1.0, 2.0, 4.0])
                    DropdownMenuItem(value: v, child: Text('$v×')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      stop();
                      speed = value;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget details() {
    final players = reviewIndex.players;
    final labels = {
      'kill': 'kill',
      'bomb_planted': l.bombPlanted,
      'bomb_defused': l.bombDefused,
      'bomb_exploded': l.bombExploded,
      'smokegrenade_detonate': l.smoke,
      'inferno_startburn': l.molotov,
      'flashbang_detonate': l.flash,
    };
    final events = reviewIndex
        .recent(tick)
        .map((e) => {...e, 'kind': labels[e['kind']] ?? e['kind']})
        .toList();
    final notes = noteCache;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.scoreboard,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: SizedBox()),
                  Text(
                    'K / D / A',
                    style: TextStyle(fontSize: 10, color: Studio.muted),
                  ),
                ],
              ),
              for (final player in players)
                InkWell(
                  onTap: () => setState(
                    () => selectedPlayer = selectedPlayer == player['steamid']
                        ? ''
                        : player['steamid'] as String,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            player['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: selectedPlayer == player['steamid']
                                  ? Studio.accent
                                  : Studio.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${player['kills']} / ${player['deaths']} / ${player['assists']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.events,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final event in events.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    event['kind'] == 'kill'
                        ? '${event['attacker_name'] ?? '—'} → ${event['user_name'] ?? '—'}\n${event['weapon'] ?? ''} · ${event['tick']}'
                        : '${event['kind']} · ${event['user_name'] ?? '—'}\n${l.tickLabel} ${event['tick']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Studio.muted,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.annotations,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: annotate,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.addAnnotation),
              ),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => seekNote(note),
                        child: Text(
                          '${timestamp(note['tick'] as int)} · ${l.roundLabel} ${note['round']} · ${l.tickLabel} ${note['tick']}',
                          style: const TextStyle(
                            color: Studio.accent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note['note'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextButton.icon(
                        onPressed: () => createTask(note),
                        icon: const Icon(Icons.assignment_outlined, size: 14),
                        label: Text(l.createTaskFromNote),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          widget.store.deleteAnnotation(
                            note['id'] as String,
                            widget.demo['id'] as String,
                          );
                          refreshNotes();
                        }),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: Text(l.deleteNote),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${data!['parser']} ${data!['parser_version']} · ${data!['sample_stride']} ticks/sample',
          style: const TextStyle(color: Studio.muted, fontSize: 10),
        ),
        const SizedBox(height: 8),
        Text(
          l.sampledPlayback,
          style: const TextStyle(
            color: Studio.muted,
            fontSize: 10,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.eventPoints,
          style: const TextStyle(
            color: Studio.muted,
            fontSize: 10,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.radarRevisionNotice,
          style: const TextStyle(
            color: Studio.muted,
            fontSize: 10,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.demo['name'] as String)),
        body: Center(
          child: failed
              ? Text(l.reviewDataInvalid)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1100,
        map = widget.files.catalog?.find(data!['map'] as String),
        multi = (map?['levels'] as List?)?.length == 2;
    final tools = Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusTag(data!['map'] as String, color: Studio.accent),
        DropdownButton<int>(
          value: round,
          items: [
            for (final entry in data!['rounds'] as List)
              DropdownMenuItem(
                value: entry['number'] as int,
                child: Text('${l.roundLabel} ${entry['number']}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) selectRound(v);
          },
        ),
        DropdownButton<int>(
          value: side,
          items: [
            DropdownMenuItem(value: 0, child: Text(l.allSides)),
            const DropdownMenuItem(value: 2, child: Text('T')),
            const DropdownMenuItem(value: 3, child: Text('CT')),
          ],
          onChanged: (v) => setState(() => side = v ?? 0),
        ),
        if (multi)
          DropdownButton<String>(
            value: level,
            items: [
              DropdownMenuItem(value: 'default', child: Text(l.upperLevel)),
              DropdownMenuItem(value: 'lower', child: Text(l.lowerLevel)),
            ],
            onChanged: (v) => setState(() => level = v ?? 'default'),
          ),
        FilterChip(
          label: Text(l.showTrails),
          selected: trails,
          onSelected: (v) => setState(() => trails = v),
        ),
      ],
    );
    final viewport = Column(
      children: [
        tools,
        const SizedBox(height: 12),
        Expanded(child: mapView()),
        const SizedBox(height: 12),
        controls(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.demo['name'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l.scouting,
            onPressed: () async {
              await editDemoTags(context, widget.store, widget.demo);
            },
            icon: const Icon(Icons.sell_outlined),
          ),
          OpenDemoCsButton(store: widget.store, demo: widget.demo),
          IconButton(
            tooltip: l.exportReview,
            onPressed: share,
            icon: const Icon(Icons.ios_share),
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
                    Expanded(child: viewport),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 300,
                      child: SingleChildScrollView(child: details()),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .86,
                      child: viewport,
                    ),
                    const SizedBox(height: 20),
                    details(),
                  ],
                ),
        ),
      ),
    );
  }
}

class ReviewPainter extends CustomPainter {
  final MapCatalog catalog;
  final String keyName, level, selected;
  final List players, history;
  final List<Map> points;
  final int side;
  final ValueListenable<double>? position;
  final Map? sourceFrame, nextFrame;
  final num tickRate;
  ReviewPainter({
    required this.catalog,
    required this.keyName,
    required this.players,
    required this.history,
    this.points = const [],
    required this.level,
    required this.side,
    required this.selected,
    this.position,
    this.sourceFrame,
    this.nextFrame,
    this.tickRate = 64,
  }) : super(repaint: position);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    Offset point(Map player) {
      final p = catalog.worldToRadar(
        keyName,
        player['x'] as num,
        player['y'] as num,
      );
      return Offset(p.dx * size.width, p.dy * size.height);
    }

    for (final event in points) {
      if (catalog.levelFor(keyName, (event['z'] as num?) ?? 0) != level) {
        continue;
      }
      final p = point(event);
      final color = event['label'] == 'S'
          ? const Color(0xffc8d4df)
          : const Color(0xffed986e);
      canvas.drawCircle(p, 8, Paint()..color = Studio.background);
      canvas.drawCircle(
        p,
        8,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final text = TextPainter(
        text: TextSpan(
          text: event['label'] as String,
          style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
    }

    final displayed = sourceFrame == null || position == null
        ? players
        : interpolatedPlayers(
            sourceFrame!,
            nextFrame,
            position!.value,
            tickRate,
          );
    for (final raw in displayed) {
      final player = raw as Map;
      if (side != 0 && player['team'] != side ||
          catalog.levelFor(keyName, (player['z'] as num?) ?? 0) != level) {
        continue;
      }
      final alive = player['alive'] != false && (player['hp'] as num) > 0,
          p = point(player),
          color = player['team'] == 2 ? Studio.t : Studio.ct;
      if (history.isNotEmpty && alive) {
        final positions = <Offset>[];
        for (final f in history) {
          final past = (f['players'] as List)
              .where((a) => a['id'] == player['id'])
              .firstOrNull;
          if (past != null &&
              catalog.levelFor(keyName, (past['z'] as num?) ?? 0) == level) {
            positions.add(point(past as Map));
          }
        }
        if (positions.isNotEmpty) {
          final path = Path()..moveTo(positions.first.dx, positions.first.dy);
          for (final v in positions.skip(1)) {
            path.lineTo(v.dx, v.dy);
          }
          path.lineTo(p.dx, p.dy);
          canvas.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: .45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
      if (!alive) {
        canvas.drawLine(
          p - const Offset(3, 3),
          p + const Offset(3, 3),
          Paint()
            ..color = color.withValues(alpha: .5)
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(
          p + const Offset(-3, 3),
          p + const Offset(3, -3),
          Paint()
            ..color = color.withValues(alpha: .5)
            ..strokeWidth = 1.5,
        );
        continue;
      }
      if (selected == player['id']) {
        canvas.drawCircle(
          p,
          12,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      final yaw = ((player['yaw'] as num?) ?? 0) * math.pi / 180;
      canvas.drawLine(
        p,
        p + Offset(math.cos(yaw) * 14, -math.sin(yaw) * 14),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.drawCircle(p, 6, Paint()..color = Studio.background);
      canvas.drawCircle(p, 4.5, Paint()..color = color);
      final hp = (player['hp'] as num).clamp(0, 100) / 100;
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 8, p.dy + 10, 16, 2),
        Paint()..color = Studio.background,
      );
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 8, p.dy + 10, 16 * hp, 2),
        Paint()..color = Studio.accent,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ReviewPainter old) => true;
}

class _ReviewNoteDialog extends StatefulWidget {
  final String at;
  const _ReviewNoteDialog({required this.at});
  @override
  State<_ReviewNoteDialog> createState() => _ReviewNoteDialogState();
}

class _ReviewNoteDialogState extends State<_ReviewNoteDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l.noteAt}\n${widget.at}'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: text,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (text.text.trim().isNotEmpty) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

int frameIndexAtTick(List<dynamic> frames, int tick) {
  var low = 0, high = frames.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if ((frames[middle]['tick'] as int) < tick) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low.clamp(0, frames.length - 1);
}
