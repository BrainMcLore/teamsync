import 'package:flutter/material.dart';

Future<DateTime?> pickTaskDeadline(
  BuildContext context,
  DateTime? current,
) async {
  final now = DateTime.now(),
      first = DateTime(2000),
      last = DateTime(DateTime.now().year + 20, 12, 31);
  final preferred = current?.toLocal() ?? now;
  final initial = preferred.isBefore(first)
      ? first
      : preferred.isAfter(last)
      ? last
      : preferred;
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: current == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(current.toLocal()),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
