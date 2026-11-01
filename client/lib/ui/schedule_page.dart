import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../data/team_schedule.dart';
import '../l10n/app_localizations.dart';
import 'deadline_picker.dart';
import 'kit.dart';

String scheduleTime(BuildContext context, String value) {
  final date = DateTime.parse(value).toLocal(),
      m = MaterialLocalizations.of(context);
  return '${m.formatMediumDate(date)} · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

String eventKind(AppLocalizations l, String value) => switch (value) {
  'scrim' => l.scheduleScrim,
  'review' => l.scheduleReview,
  'bootcamp' => l.bootcamp,
  _ => l.schedulePractice,
};
String rsvpLabel(AppLocalizations l, String value) => switch (value) {
  'going' => l.rsvpGoing,
  'maybe' => l.rsvpMaybe,
  'declined' => l.rsvpDeclined,
  _ => l.rsvpUnknown,
};
String attendanceLabel(AppLocalizations l, String value) => switch (value) {
  'present' => l.attendancePresent,
  'late' => l.attendanceLate,
  'absent' => l.attendanceAbsent,
  'excused' => l.attendanceExcused,
  _ => l.attendanceUnmarked,
};
String scheduleError(AppLocalizations l, String? code) => switch (code) {
  'version_conflict' || 'operation_conflict' => l.scheduleConflict,
  'event_not_started' => l.scheduleNotStarted,
  'attendance_time_locked' => l.scheduleTimeLocked,
  'event_cancelled' => l.scheduleCancelled,
  'attendance_reason_required' => l.scheduleCorrectReason,
  'syncAccountMismatch' => l.syncAccountMismatch,
  _ => l.scheduleUnavailable,
};

class SchedulePage extends StatefulWidget {
  final Store store;
  final String team;
  final TeamSchedule? service;
  final String filter;
  const SchedulePage({
    super.key,
    required this.store,
    required this.team,
    this.service,
    this.filter = '',
  });
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with WidgetsBindingObserver {
  Timer? refreshTimer;
  bool active = true;
  void startRefresh() {
    WidgetsBinding.instance.addObserver(this);
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && active && ModalRoute.of(context)?.isCurrent == true) {
        load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active && mounted && ModalRoute.of(context)?.isCurrent == true) load();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  TeamSchedule? schedule;
  List<Map<String, dynamic>> rows = [], queue = [];
  late DateTime from, until;
  bool busy = false, offline = false;
  int? next;
  @override
  void initState() {
    super.initState();
    startRefresh();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, now.day - 7);
    until = DateTime(now.year, now.month, now.day + 61);
    if (widget.store.setting('account_team_${widget.team}') != null) {
      schedule = widget.service ?? TeamSchedule(widget.store, widget.team);
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (busy || schedule == null) return;
    setState(() => busy = true);
    try {
      await schedule!.flush();
      final page = await schedule!.list(
        from,
        until,
        offset: more ? next ?? 0 : 0,
      );
      if (!mounted) return;
      rows = {
        for (final row in [
          ...(more ? rows : <Map<String, dynamic>>[]),
          ...page.items,
        ])
          row['id']: row,
      }.values.toList();
      next = page.next;
      offline = false;
    } catch (_) {
      if (!mounted) return;
      try {
        rows = schedule!.cached().where((r) {
          final t = DateTime.parse(r['starts_at'] as String);
          return !t.isBefore(from) && t.isBefore(until);
        }).toList();
      } catch (_) {
        rows = [];
      }
      offline = true;
      next = null;
    } finally {
      if (mounted) {
        try {
          queue = schedule!.pending();
        } catch (_) {
          queue = [];
          rows = [];
        }
        setState(() => busy = false);
      }
    }
  }

  bool pending(String event) => queue.any((r) => r['event'] == event);
  Future<void> edit([Map<String, dynamic>? row]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ScheduleForm(schedule: schedule!, value: row),
    );
    if (mounted) await load();
  }

  Future<void> range() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
      initialDateRange: DateTimeRange(
        start: from,
        end: until.subtract(const Duration(days: 1)),
      ),
    );
    if (selected == null || !mounted) return;
    final end = DateTime(
      selected.end.year,
      selected.end.month,
      selected.end.day + 1,
    );
    if (end.difference(selected.start).inHours > 366 * 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).scheduleRangeLimit),
        ),
      );
      return;
    }
    setState(() {
      from = selected.start;
      until = end;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), s = schedule;
    if (s == null) return Center(child: Text(l.localNotice));
    final visible = rows
        .where(
          (r) => '${r['title']} ${r['notes']} ${r['location']}'
              .toLowerCase()
              .contains(widget.filter.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l.scheduleTitle, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text('${l.scheduleZone} (${DateTime.now().timeZoneName})'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (s.manager)
              FilledButton.icon(
                onPressed: busy ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: Text(l.scheduleNew),
              ),
            OutlinedButton.icon(
              onPressed: busy ? null : range,
              icon: const Icon(Icons.date_range),
              label: Text(
                '${MaterialLocalizations.of(context).formatCompactDate(from)} – ${MaterialLocalizations.of(context).formatCompactDate(until.subtract(const Duration(days: 1)))}',
              ),
            ),
            IconButton(
              onPressed: busy ? null : load,
              tooltip: l.discussionRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (offline) Text(l.scheduleOffline),
        for (final operation in queue)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(operation['label'] as String),
                  Text(
                    operation['error'] == null
                        ? l.schedulePending
                        : scheduleError(l, operation['error'] as String),
                  ),
                  if (operation['target'] == null) ...[
                    Text(
                      '${scheduleTime(context, (operation['body'] as Map)['starts_at'] as String)} → ${scheduleTime(context, (operation['body'] as Map)['ends_at'] as String)}',
                    ),
                    if (((operation['body'] as Map)['location'] as String? ??
                            '')
                        .isNotEmpty)
                      Text((operation['body'] as Map)['location'] as String),
                    if (((operation['body'] as Map)['notes'] as String? ?? '')
                        .isNotEmpty)
                      Text((operation['body'] as Map)['notes'] as String),
                  ] else
                    Text(
                      (operation['body'] as Map)['rsvp'] != null
                          ? '${l.scheduleReply}: ${rsvpLabel(l, (operation['body'] as Map)['rsvp'] as String)}'
                          : '${l.scheduleRecord}: ${attendanceLabel(l, (operation['body'] as Map)['attendance'] as String)}',
                    ),
                  if (((operation['body'] as Map)['reason'] as String? ?? '')
                      .isNotEmpty)
                    Text((operation['body'] as Map)['reason'] as String),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            try {
                              s.discard(
                                (operation['body'] as Map)['operation_id']
                                    as String,
                              );
                              load();
                            } catch (_) {}
                          },
                    child: Text(l.scheduleDiscard),
                  ),
                ],
              ),
            ),
          ),
        if (visible.isEmpty && !busy)
          Padding(padding: const EdgeInsets.all(24), child: Text(l.noData)),
        for (final row in visible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        row['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      StatusTag(
                        row['status'] == 'cancelled'
                            ? l.scheduleCancelled
                            : eventKind(l, row['kind'] as String),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${scheduleTime(context, row['starts_at'] as String)} → ${scheduleTime(context, row['ends_at'] as String)}',
                  ),
                  if ((row['location'] as String).isNotEmpty)
                    Text(row['location'] as String),
                  if ((row['notes'] as String).isNotEmpty)
                    Text(row['notes'] as String),
                  if ((row['reason'] as String).isNotEmpty)
                    Text(row['reason'] as String),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => ScheduleAttendance(
                                    schedule: s,
                                    event: row,
                                  ),
                                );
                                if (mounted) await load();
                              },
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(l.scheduleParticipants),
                      ),
                      if (s.manager && row['status'] != 'cancelled')
                        TextButton.icon(
                          onPressed: busy || pending(row['id'] as String)
                              ? null
                              : () => edit(row),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l.scheduleEdit),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (next != null && !busy)
          TextButton(
            onPressed: () => load(more: true),
            child: Text(l.historyMore),
          ),
      ],
    );
  }
}

class ScheduleForm extends StatefulWidget {
  final TeamSchedule schedule;
  final Map<String, dynamic>? value;
  const ScheduleForm({super.key, required this.schedule, this.value});
  @override
  State<ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<ScheduleForm> {
  final title = TextEditingController(),
      notes = TextEditingController(),
      location = TextEditingController(),
      reason = TextEditingController();
  late DateTime start, end;
  String kind = 'practice';
  bool cancelled = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    start = DateTime(now.year, now.month, now.day + 1, 18);
    end = start.add(const Duration(minutes: 90));
    final v = widget.value;
    if (v != null) {
      title.text = v['title'] as String;
      notes.text = v['notes'] as String;
      location.text = v['location'] as String;
      reason.text = v['reason'] as String;
      kind = v['kind'] as String;
      start = DateTime.parse(v['starts_at'] as String).toLocal();
      end = DateTime.parse(v['ends_at'] as String).toLocal();
      cancelled = v['status'] == 'cancelled';
    }
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    location.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final value = await pickTaskDeadline(context, first ? start : end);
    if (value != null && mounted) {
      setState(() {
        if (first) {
          start = value;
          if (!end.isAfter(start)) end = start.add(const Duration(minutes: 90));
        } else {
          end = value;
        }
      });
    }
  }

  void save() {
    final l = AppLocalizations.of(context);
    if (saving) return;
    if (title.text.trim().isEmpty ||
        !end.isAfter(start) ||
        end.difference(start).inSeconds < 60 ||
        end.difference(start).inSeconds > 7 * 86400 ||
        cancelled && reason.text.trim().isEmpty) {
      setState(() => error = l.scheduleInvalidTime);
      return;
    }
    setState(() => saving = true);
    try {
      widget.schedule.enqueue(
        widget.value?['id'] as String? ?? Store.uuid.v4(),
        {
          'expected_version': widget.value?['version'] ?? 0,
          'title': title.text.trim(),
          'notes': notes.text,
          'location': location.text,
          'kind': kind,
          'starts_at': start.toUtc().toIso8601String(),
          'ends_at': end.toUtc().toIso8601String(),
          'status': cancelled ? 'cancelled' : 'scheduled',
          'reason': cancelled ? reason.text.trim() : '',
        },
        title.text.trim(),
      );
      Navigator.pop(context);
    } catch (_) {
      setState(() {
        saving = false;
        error = l.scheduleUnavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(widget.value == null ? l.scheduleNew : l.scheduleEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('event-title'),
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.title),
              ),
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.scheduleType),
                items: [
                  for (final k in ['practice', 'scrim', 'review', 'bootcamp'])
                    DropdownMenuItem(value: k, child: Text(eventKind(l, k))),
                ],
                onChanged: saving ? null : (v) => setState(() => kind = v!),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.scheduleStart),
                subtitle: Text(
                  scheduleTime(context, start.toUtc().toIso8601String()),
                ),
                onTap: saving ? null : () => pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.scheduleEnd),
                subtitle: Text(
                  scheduleTime(context, end.toUtc().toIso8601String()),
                ),
                onTap: saving ? null : () => pick(false),
              ),
              Text(l.scheduleZone),
              TextField(
                controller: location,
                maxLength: 200,
                decoration: InputDecoration(labelText: l.scheduleLocation),
              ),
              TextField(
                controller: notes,
                maxLength: 5000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.notes),
              ),
              if (widget.value != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.scheduleCancelEvent),
                  value: cancelled,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => cancelled = v),
                ),
              if (cancelled)
                TextField(
                  controller: reason,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l.scheduleCancelReason,
                  ),
                ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('event-save'),
          onPressed: saving ? null : save,
          child: Text(l.scheduleSave),
        ),
      ],
    );
  }
}

class ScheduleAttendance extends StatefulWidget {
  final TeamSchedule schedule;
  final Map<String, dynamic> event;
  const ScheduleAttendance({
    super.key,
    required this.schedule,
    required this.event,
  });
  @override
  State<ScheduleAttendance> createState() => _ScheduleAttendanceState();
}

class _ScheduleAttendanceState extends State<ScheduleAttendance>
    with WidgetsBindingObserver {
  Timer? refreshTimer;
  bool active = true;
  void startRefresh() {
    WidgetsBinding.instance.addObserver(this);
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && active && ModalRoute.of(context)?.isCurrent == true) {
        load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active && mounted && ModalRoute.of(context)?.isCurrent == true) load();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  late Map<String, dynamic> event;
  List<Map<String, dynamic>> people = [];
  bool busy = false, offline = false;
  int? next;
  String? error;
  @override
  void initState() {
    super.initState();
    startRefresh();
    event = widget.event;
    load();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.schedule.flush();
      final page = await widget.schedule.people(
        event['id'] as String,
        offset: more ? next ?? 0 : 0,
      );
      if (!mounted) return;
      event = page.event;
      people = more ? [...people, ...page.people] : page.people;
      next = page.next;
      offline = false;
      final problem = widget.schedule
          .pending()
          .where((r) => r['event'] == event['id'] && r['error'] != null)
          .firstOrNull;
      error = problem == null
          ? null
          : scheduleError(
              AppLocalizations.of(context),
              problem['error'] as String,
            );
    } catch (_) {
      if (!mounted) return;
      try {
        people = widget.schedule.cachedPeople(event['id'] as String);
      } catch (_) {
        people = [];
      }
      offline = true;
      next = null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> answer(Map row, String choice) async {
    if (busy) return;
    try {
      widget.schedule.enqueue(
        event['id'] as String,
        {'expected_version': row['version'], 'rsvp': choice},
        '${event['title']} · ${row['name']}',
        target: row['user_id'] as String,
      );
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = AppLocalizations.of(context).scheduleUnavailable,
        );
      }
    }
  }

  Future<void> mark(Map row) async {
    if (busy) return;
    final l = AppLocalizations.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AttendanceForm(row: row, event: event),
    );
    if (result == null || !mounted) return;
    try {
      widget.schedule.enqueue(
        event['id'] as String,
        {'expected_version': row['version'], ...result},
        '${event['title']} · ${row['name']}',
        target: row['user_id'] as String,
      );
      await load();
    } catch (_) {
      if (mounted) setState(() => error = l.scheduleUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), s = widget.schedule;
    bool blocked = false;
    List<Map<String, dynamic>> queued = [];
    try {
      queued = s.pending().where((r) => r['event'] == event['id']).toList();
      blocked = queued.isNotEmpty;
    } catch (_) {
      blocked = true;
    }
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(event['title'] as String),
      content: SizedBox(
        width: 620,
        height: 460,
        child: ListView(
          children: [
            Text(
              '${scheduleTime(context, event['starts_at'] as String)} → ${scheduleTime(context, event['ends_at'] as String)}',
            ),
            if (event['status'] == 'cancelled') Text(l.scheduleCancelled),
            if (busy) const LinearProgressIndicator(),
            if (offline) Text(l.scheduleOffline),
            if (error != null) Text(error!),
            if (blocked) Text(l.schedulePending),
            for (final operation in queued)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(operation['label'] as String),
                      if (operation['target'] != null)
                        Text(
                          (operation['body'] as Map)['rsvp'] != null
                              ? '${l.scheduleReply}: ${rsvpLabel(l, (operation['body'] as Map)['rsvp'] as String)}'
                              : '${l.scheduleRecord}: ${attendanceLabel(l, (operation['body'] as Map)['attendance'] as String)}',
                        ),
                      if (((operation['body'] as Map)['reason'] as String? ??
                              '')
                          .isNotEmpty)
                        Text((operation['body'] as Map)['reason'] as String),
                      if (operation['error'] != null)
                        Text(scheduleError(l, operation['error'] as String)),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                try {
                                  s.discard(
                                    (operation['body'] as Map)['operation_id']
                                        as String,
                                  );
                                  load();
                                } catch (_) {
                                  setState(() => error = l.scheduleUnavailable);
                                }
                              },
                        child: Text(l.scheduleDiscard),
                      ),
                    ],
                  ),
                ),
              ),

            for (final row in people)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['name']}${row['active'] == true ? '' : ' · ${l.scheduleFormer}'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${l.scheduleReply}: ${rsvpLabel(l, row['rsvp'] as String)}',
                      ),
                      Text(
                        '${l.scheduleRecord}: ${attendanceLabel(l, row['attendance'] as String)}',
                      ),
                      if ((row['reason'] as String).isNotEmpty)
                        Text(row['reason'] as String),
                      if (row['recorded_by_name'] != null)
                        Text(
                          '${row['recorded_by_name']} · ${DateTime.fromMillisecondsSinceEpoch(((row['recorded_at'] as num) * 1000).round()).toLocal()}',
                        ),
                      if (row['active'] == true &&
                          event['status'] != 'cancelled')
                        Wrap(
                          spacing: 8,
                          children: [
                            if (row['user_id'] == s.binding['user'] &&
                                !s.viewer)
                              for (final k in ['going', 'maybe', 'declined'])
                                TextButton(
                                  onPressed: busy || blocked
                                      ? null
                                      : () => answer(row, k),
                                  child: Text(rsvpLabel(l, k)),
                                ),
                            if (s.manager)
                              TextButton.icon(
                                onPressed: busy || blocked
                                    ? null
                                    : () => mark(row),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: Text(l.scheduleRecord),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            if (next != null && !busy)
              TextButton(
                onPressed: () => load(more: true),
                child: Text(l.historyMore),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => ScheduleHistory(
                    schedule: s,
                    event: event['id'] as String,
                  ),
                ),
          child: Text(l.history),
        ),
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

class AttendanceForm extends StatefulWidget {
  final Map row, event;
  const AttendanceForm({super.key, required this.row, required this.event});
  @override
  State<AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<AttendanceForm> {
  final reason = TextEditingController();
  late String choice;
  bool invalid = false;
  @override
  void initState() {
    super.initState();
    choice = widget.row['attendance'] as String;
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final future = DateTime.parse(widget.event['starts_at'] as String)
        .isAfter(DateTime.now());
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(widget.row['name'] as String),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('attendance-state'),
                initialValue: choice,
                isExpanded: true,
                items: [
                  for (final status in [
                    'unmarked',
                    'present',
                    'late',
                    'absent',
                    'excused',
                  ])
                    DropdownMenuItem(
                      value: status,
                      enabled:
                          !future || ['unmarked', 'excused'].contains(status),
                      child: Text(attendanceLabel(l, status)),
                    ),
                ],
                onChanged: (value) => choice = value!,
              ),
              TextField(
                key: const ValueKey('attendance-reason'),
                controller: reason,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.scheduleReason),
              ),
              if (invalid) Text(l.scheduleCorrectReason),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const ValueKey('attendance-save'),
          onPressed: () {
            if (widget.row['attendance'] != 'unmarked' &&
                choice != widget.row['attendance'] &&
                reason.text.trim().isEmpty) {
              setState(() => invalid = true);
              return;
            }
            Navigator.pop(context, {
              'attendance': choice,
              'reason': reason.text.trim(),
            });
          },
          child: Text(l.scheduleSave),
        ),
      ],
    );
  }
}

class ScheduleHistory extends StatefulWidget {
  final TeamSchedule schedule;
  final String event;
  const ScheduleHistory({
    super.key,
    required this.schedule,
    required this.event,
  });
  @override
  State<ScheduleHistory> createState() => _ScheduleHistoryState();
}

class _ScheduleHistoryState extends State<ScheduleHistory> {
  List<Map<String, dynamic>> rows = [];
  bool busy = false, offline = false, more = false;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final page = await widget.schedule.history(widget.event, offset: offset);
      if (!mounted) return;
      rows = {
        for (final row in [...rows, ...page]) row['id']: row,
      }.values.toList();
      offset += page.length;
      more = page.length == 50;
    } catch (_) {
      if (!mounted) return;
      try {
        rows = widget.schedule.cachedHistory(widget.event);
      } catch (_) {
        rows = [];
      }
      offline = true;
      more = false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(l.history),
      content: SizedBox(
        width: 520,
        height: 400,
        child: ListView(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (offline) Text(l.scheduleOffline),
            for (final row in rows)
              ListTile(
                title: Text(
                  row['kind'] == 'event'
                      ? (row['payload'] as Map)['title'] as String
                      : row['kind'] == 'rsvp'
                      ? '${row['target_name']} · ${l.scheduleReply}: ${rsvpLabel(l, (row['payload'] as Map)['rsvp'] as String)}'
                      : row['kind'] == 'attendance'
                      ? '${row['target_name']} · ${l.scheduleRecord}: ${attendanceLabel(l, (row['payload'] as Map)['attendance'] as String)}'
                      : '${row['target_name']} · ${rsvpLabel(l, (row['payload'] as Map)['rsvp'] as String)} · ${attendanceLabel(l, (row['payload'] as Map)['attendance'] as String)}',
                ),
                subtitle: Text(
                  '${l.version(row['version'] as int)} · ${row['author_name']} · ${DateTime.fromMillisecondsSinceEpoch(((row['created'] as num) * 1000).round()).toLocal()}\n${row['kind'] == 'event' ? '${scheduleTime(context, (row['payload'] as Map)['starts_at'] as String)} → ${scheduleTime(context, (row['payload'] as Map)['ends_at'] as String)}\n${(row['payload'] as Map)['status'] == 'cancelled' ? l.scheduleCancelled : eventKind(l, (row['payload'] as Map)['kind'] as String)}\n' : ''}${row['kind'] == 'rsvp' ? '' : (row['payload'] as Map)['reason'] ?? ''}',
                ),
              ),
            if (more && !busy)
              TextButton(onPressed: load, child: Text(l.historyMore)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
