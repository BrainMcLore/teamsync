import 'dart:io';

import 'package:flutter/material.dart';

abstract final class Studio {
  static const background = Color(0xff090e15);
  static const surface = Color(0xff111a26);
  static const elevated = Color(0xff192536);
  static const border = Color(0xff233247);
  static const muted = Color(0xff8e9fb5);
  static const accent = Color(0xff93e6ca);
  static const text = Color(0xffedf3fa);
  static const t = Color(0xffedba70);
  static const ct = Color(0xff81b9f9);
}

class StatusTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const StatusTag(this.text, {super.key, this.color = Studio.muted, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class StudioPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Studio.surface,
      border: Border.all(color: Studio.border.withValues(alpha: .65)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class MapCover extends StatelessWidget {
  final String? path;
  final Widget? overlay;
  final double? height;
  const MapCover({super.key, this.path, this.overlay, this.height});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Studio.elevated,
            child: path != null
                ? Image.file(
                    File(path!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const Icon(
                      Icons.map_outlined,
                      color: Studio.muted,
                      size: 42,
                    ),
                  )
                : const Icon(Icons.map_outlined, color: Studio.muted, size: 42),
          ),
          if (overlay != null) ...[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xee080d14)],
                ),
              ),
            ),
            overlay!,
          ],
        ],
      ),
    ),
  );
}

class StudioPageTitle extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? action;
  const StudioPageTitle(this.title, {super.key, this.description, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (action != null && c.maxWidth > 600) ...[
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Align(alignment: Alignment.topRight, child: action!),
                ),
              ],
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: const TextStyle(color: Studio.muted, height: 1.6),
            ),
          ],
          if (action != null && c.maxWidth <= 600) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    ),
  );
}
