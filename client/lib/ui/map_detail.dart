import 'dart:io';

import 'package:flutter/material.dart';

import '../data/files.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';

class MapDetailPage extends StatefulWidget {
  final RecordData map;
  final LocalFiles files;
  final ValueChanged<String> onStrategy;
  const MapDetailPage({
    super.key,
    required this.map,
    required this.files,
    required this.onStrategy,
  });
  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> {
  String level = 'default';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), catalog = widget.files.catalog;
    final map = catalog?.find(widget.map['catalog_id'] as String? ?? '');
    final levels = (map?['levels'] as List?) ?? [];
    final path = map != null
        ? catalog!.radar(map, level)
        : widget.map['image_path'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.map['name'] as String),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => widget.onStrategy(level),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.newStrategy),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  StatusTag(
                    l.readyOffline,
                    color: Studio.accent,
                    icon: Icons.offline_pin_outlined,
                  ),
                  const Spacer(),
                  if (levels.length > 1)
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'default',
                          label: Text(l.upperLevel),
                        ),
                        ButtonSegment(
                          value: 'lower',
                          label: Text(l.lowerLevel),
                        ),
                      ],
                      selected: {level},
                      onSelectionChanged: (values) =>
                          setState(() => level = values.single),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StudioPanel(
                  padding: EdgeInsets.zero,
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: Center(
                      child: path == null
                          ? const Icon(Icons.map_outlined)
                          : Image.file(File(path), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (map != null)
                Text(
                  '${map['key']} · ${catalog!.manifest['revision'].toString().substring(0, 10)} · © Valve',
                  style: const TextStyle(color: Studio.muted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
