import 'package:flutter/material.dart';

import '../data/reminders.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';

class ReminderSettings extends StatefulWidget {
  final ReminderCoordinator controller;
  const ReminderSettings({super.key, required this.controller});
  @override
  State<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends State<ReminderSettings> {
  bool saving = false;
  String? error;
  Future<void> change(bool enabled, int minutes) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.controller.configure(enabled, minutes);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is DomainError ? e.code : 'unavailable');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => AlertDialog(
        insetPadding: const EdgeInsets.all(12),
        title: Text(l.remindersTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.remindersHelp),
                const SizedBox(height: 12),
                if (c.busy || saving) const LinearProgressIndicator(),
                if (!c.available) Text(l.remindersUnavailable),
                if (error != null)
                  Text(
                    error == 'notificationPermission'
                        ? l.remindersPermission
                        : l.scheduleUnavailable,
                  ),
                if (c.error != null)
                  Text(
                    c.error == 'auth'
                        ? l.sessionExpired
                        : l.remindersUnavailable,
                  ),
                if (c.partial) Text(l.remindersPartial),
                if (c.identity == null)
                  Text(l.localNotice)
                else ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.remindersEnable),
                    value: c.enabled,
                    onChanged: saving || !c.available
                        ? null
                        : (v) => change(v, c.minutes),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey(c.minutes),
                    initialValue: c.minutes,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.remindersLead),
                    items: [
                      for (final value in [0, 5, 10, 15, 30, 60, 120])
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 0
                                ? l.remindersAtStart
                                : l.remindersMinutes(value),
                          ),
                        ),
                    ],
                    onChanged: saving || !c.available
                        ? null
                        : (v) => change(c.enabled, v!),
                  ),
                  const SizedBox(height: 12),
                  Text(l.remindersCount(c.count)),
                  if (c.enabled && !c.allowed) Text(l.remindersPermission),
                  if (c.lastSync != null)
                    Text(
                      '${l.refresh}: ${DateTime.parse(c.lastSync!).toLocal()}',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: saving || !c.available
                            ? null
                            : () async {
                                try {
                                  await c.native.settings();
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => error = 'unavailable');
                                  }
                                }
                              },
                        child: Text(l.remindersSystemSettings),
                      ),
                      TextButton(
                        onPressed: saving || !c.available || !c.allowed
                            ? null
                            : () async {
                                try {
                                  if (!await c.native.test(l.remindersTestBody)) {
                                    throw DomainError('notificationPermission');
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => error = 'unavailable');
                                  }
                                }
                              },
                        child: Text(l.remindersTest),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: c.busy ? null : c.refresh,
            child: Text(l.refresh),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }
}

Future<void> openReminderSettings(BuildContext context, Store store) async {
  final existing = ReminderCoordinator.of(store),
      controller = ReminderCoordinator.of(store) ?? ReminderCoordinator(store);
  if (existing == null) controller.start();
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => ReminderSettings(controller: controller),
    );
  } finally {
    if (existing == null) controller.dispose();
  }
}
