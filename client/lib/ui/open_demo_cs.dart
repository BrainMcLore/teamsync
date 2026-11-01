import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/pc_services.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';

class OpenDemoCsButton extends StatefulWidget {
  final Store store;
  final RecordData demo;
  const OpenDemoCsButton({super.key, required this.store, required this.demo});
  @override
  State<OpenDemoCsButton> createState() => _OpenDemoCsButtonState();
}

class _OpenDemoCsButtonState extends State<OpenDemoCsButton> {
  bool busy = false;
  Future<void> open() async {
    final l = AppLocalizations.of(context);
    setState(() => busy = true);
    try {
      final plan = await PcDemoLauncher.prepare(
        widget.store,
        widget.demo['path'] as String,
      );
      await Clipboard.setData(ClipboardData(text: plan.command));
      await PcDemoLauncher.launch(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.csLaunchHelp),
            duration: const Duration(seconds: 12),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.csLaunchError),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppLocalizations.of(context).openInCS,
      onPressed:
          busy ||
              !(widget.demo['path'] as String).toLowerCase().endsWith('.dem')
          ? null
          : open,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sports_esports_outlined),
    );
  }
}
