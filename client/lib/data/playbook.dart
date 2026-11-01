import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../ui/editor.dart' show TacticalPainter;
import 'store.dart';

class Playbook {
  static Future<Uint8List?> snapshot(RecordData strategy) async {
    Uint8List? radar;
    final path = strategy['image_path'] as String?;
    if (path != null && await File(path).exists()) {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: 1200,
      );
      final frame = await codec.getNextFrame();
      final size = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(frame.image, ui.Offset.zero, ui.Paint());
      final objects = (jsonDecode(strategy['objects'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      TacticalPainter(objects, symbolScale: 2.6).paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      radar = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      frame.image.dispose();
      codec.dispose();
    }
    return radar;
  }

  static Future<Uint8List> generateDraft(
    Map<String, dynamic> book,
    AppLocalizations l,
  ) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final doc = pw.Document(
      title: book['title'] as String,
      author: 'TeamSync',
      subject: l.localeName,
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    for (final raw in book['pages'] as List) {
      final page = raw as Map;
      final attachments = <(Map, Uint8List)>[];
      for (final item in page['attachments'] as List) {
        final file = File(item['path'] as String);
        if (!await file.exists()) throw StateError('snapshotMissing');
        attachments.add((item as Map, await file.readAsBytes()));
      }
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          maxPages: 100,
          header: (_) => pw.Text(
            'TeamSync / ${book['title']} · ${l.localeName}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (_) => [
            pw.SizedBox(height: 16),
            pw.Text(
              page['title'] as String,
              style: const pw.TextStyle(fontSize: 24),
            ),
            for (final section in [
              ('economy', l.economy),
              ('plan', l.roundPlan),
              ('roles', l.responsibilities),
            ]) ...[
              if ((page[section.$1] as String? ?? '').isNotEmpty) ...[
                pw.Header(level: 1, text: section.$2),
                ...paragraphs(page[section.$1] as String),
              ],
            ],
            for (final attachment in attachments) ...[
              pw.Header(level: 1, text: attachment.$1['title'] as String),
              pw.Text(
                '${attachment.$1['map']} / ${attachment.$1['side']} · ${l.captureVersion} ${attachment.$1['version']}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(attachment.$2),
                  height: 340,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 12),
              ...paragraphs(attachment.$1['notes'] as String? ?? ''),
            ],
          ],
        ),
      );
    }
    if ((book['pages'] as List).isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Text(book['title'] as String)));
    }
    return doc.save();
  }

  static List<pw.Widget> paragraphs(String text) {
    final result = <pw.Widget>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      var end = remaining.length.clamp(0, 700);
      if (end < remaining.length) {
        final boundary = remaining.lastIndexOf(RegExp(r'\s'), end);
        if (boundary > 0) end = boundary;
      }
      result.add(pw.Paragraph(text: remaining.substring(0, end)));
      remaining = remaining.substring(end).trimLeft();
    }
    return result;
  }

  static Future<void> saveDraftPdf(
    Map<String, dynamic> book,
    AppLocalizations l,
  ) async {
    final bytes = await generateDraft(book, l);
    if (Platform.isWindows) {
      final target = await getSaveLocation(
        suggestedName: 'TeamSync-playbook-${l.localeName}.pdf',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (target != null) {
        await File(target.path).writeAsBytes(bytes, flush: true);
      }
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TeamSync-playbook-${l.localeName}.pdf',
      );
    }
  }

  static Future<Uint8List> generate(
    Store store,
    String team,
    AppLocalizations l,
  ) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final name =
        store.teams.singleWhere((t) => t['id'] == team)['name'] as String;
    final doc = pw.Document(
      title: 'TeamSync — $name',
      author: 'TeamSync',
      subject: l.localeName,
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    final strategies = store.strategies(team);
    for (final s in strategies) {
      final radar = await snapshot(s);
      final tasks = store
          .tasks(team)
          .where((t) => t['strategy_id'] == s['id'])
          .toList();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          maxPages: 100,
          header: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TeamSync / $name',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                l.version(s['version'] as int),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 16),
            pw.Text(
              s['title'] as String,
              style: const pw.TextStyle(fontSize: 24),
            ),
            pw.SizedBox(height: 8),
            pw.Text('${s['map_name']} / ${s['side']}'),
            pw.SizedBox(height: 16),
            if (radar != null)
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(radar),
                  height: 340,
                  fit: pw.BoxFit.contain,
                ),
              )
            else
              pw.Text(l.imageRequired),
            pw.SizedBox(height: 16),
            pw.Header(level: 1, text: l.notes),
            pw.Paragraph(text: s['notes'] as String),
            if (tasks.isNotEmpty) pw.Header(level: 1, text: l.training),
            for (final task in tasks) ...[
              pw.Text(
                '${task['member_name'] ?? l.unassigned} — ${task['title']}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Paragraph(text: task['notes'] as String),
            ],
          ],
        ),
      );
    }
    if (strategies.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Text(l.emptyStrategies)));
    }
    return doc.save();
  }

  static Future<void> share(
    Store store,
    String team,
    AppLocalizations l,
  ) async {
    final bytes = await generate(store, team, l);
    if (Platform.isWindows) {
      final target = await getSaveLocation(
        suggestedName: 'TeamSync-${l.localeName}.pdf',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (target != null) {
        await File(target.path).writeAsBytes(bytes, flush: true);
      }
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TeamSync-${l.localeName}.pdf',
      );
    }
  }
}
