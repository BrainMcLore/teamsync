import 'package:flutter/material.dart';

import '../data/account_roster.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'deadline_picker.dart';

const taskTypes = [
  'general',
  'utility',
  'tactic',
  'dry_run',
  'execute',
  'retake',
  'demo',
  'round_review',
  'fix',
  'quiz',
];
String taskTypeLabel(AppLocalizations l, String type) => switch (type) {
  'utility' => l.taskTypeUtility,
  'dry_run' => l.taskTypeDryRun,
  'execute' => l.taskTypeExecute,
  'retake' => l.taskTypeRetake,
  'demo' => l.taskTypeDemo,
  'round_review' => l.taskTypeRound,
  'fix' => l.taskTypeFix,
  'quiz' => l.taskTypeQuiz,
  'tactic' => l.taskTypeTactic,
  _ => l.taskTypeGeneral,
};

class TaskForm extends StatefulWidget {
  final Store store;
  final String team;
  final String? strategy;
  final RecordData? value;
  const TaskForm({
    super.key,
    required this.store,
    required this.team,
    this.strategy,
    this.value,
  });
  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final key = GlobalKey<FormState>();
  final title = TextEditingController(),
      notes = TextEditingController(),
      criteria = TextEditingController();
  String type = 'tactic';
  String? member, strategy;
  DateTime? due;
  bool saving = false;
  late final List<RecordData> members, strategies;
  String? accountBinding, accountIdentity;
  @override
  void initState() {
    super.initState();
    strategy = widget.strategy;
    members = accountAssignableMembers(widget.store, widget.team);
    strategies = widget.store.strategies(widget.team);
    accountBinding = widget.store.setting('account_team_${widget.team}');
    accountIdentity = widget.store.setting('account_identity');
    final value = widget.value;
    if (value != null) {
      title.text = value['title'] as String;
      type = value['task_type'] as String? ?? 'general';
      due = DateTime.tryParse(value['due_at'] as String? ?? '')?.toLocal();
      criteria.text = value['criteria'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    criteria.dispose();
    super.dispose();
  }

  Future<void> deadline() async {
    final value = await pickTaskDeadline(context, due);
    if (value != null && mounted) setState(() => due = value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        m = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.value == null ? l.newTask : l.editTaskPlan),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.value != null) Text(title.text),
                if (widget.value == null)
                  TextFormField(
                    key: const ValueKey('task-title'),
                    controller: title,
                    autofocus: true,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: l.title),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.invalidText : null,
                  ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('task-type'),
                  initialValue: type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.taskType),
                  items: [
                    for (final item in taskTypes)
                      DropdownMenuItem(
                        value: item,
                        child: Text(taskTypeLabel(l, item)),
                      ),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 12),
                if (widget.value == null)
                  DropdownButtonFormField<String>(
                    key: const ValueKey('task-member'),
                    initialValue: member ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.assignee),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.unassigned)),
                      for (final item in members)
                        DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(
                            item['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => member = v == '' ? null : v,
                  ),
                if (widget.value == null && widget.strategy == null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: strategy ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.strategyLink),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l.noLink)),
                      for (final item in strategies)
                        DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text(
                            item['title'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => strategy = v == '' ? null : v,
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.taskDeadline),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('task-deadline'),
                      onPressed: deadline,
                      icon: const Icon(Icons.event),
                      label: Text(
                        due == null
                            ? l.taskNoDeadline
                            : '${m.formatMediumDate(due!)} · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(due!))}',
                      ),
                    ),
                    if (due != null)
                      IconButton(
                        tooltip: l.taskClearDeadline,
                        onPressed: () => setState(() => due = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                Text(
                  l.taskDeadlineHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('task-criteria'),
                  controller: criteria,
                  maxLength: 5000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: l.taskCriteria),
                ),
                if (widget.value == null)
                  TextFormField(
                    key: const ValueKey('task-notes'),
                    controller: notes,
                    maxLength: 20000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: l.taskDetails),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('task-save'),
          onPressed: saving
              ? null
              : () {
                  if (saving || !key.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    if (accountBinding != null &&
                        (accountIdentity == null ||
                            accountBinding !=
                                widget.store.setting(
                                  'account_team_${widget.team}',
                                ) ||
                            accountIdentity !=
                                widget.store.setting('account_identity') ||
                            widget.store.setting('account_signed_out') ==
                                '1')) {
                      throw DomainError('readOnlyTeam');
                    }
                    if (widget.value == null &&
                        member != null &&
                        !accountAssignableMembers(
                          widget.store,
                          widget.team,
                        ).any((m) => m['id'] == member)) {
                      throw DomainError('crossTeam');
                    }
                    if (widget.value != null) {
                      widget.store.updateTaskPlan(
                        widget.value!['id'] as String,
                        taskType: type,
                        dueAt: due,
                        criteria: criteria.text,
                      );
                      Navigator.pop(context, widget.value!['id']);
                      return;
                    }
                    final id = widget.store.createTask(
                      widget.team,
                      title.text,
                      notes.text,
                      member: member,
                      strategyId: strategy,
                      taskType: type,
                      dueAt: due,
                      criteria: criteria.text,
                    );
                    Navigator.pop(context, id);
                  } on DomainError catch (e) {
                    setState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.code == 'readOnlyTeam'
                              ? l.readOnlyTeam
                              : l.invalidText,
                        ),
                      ),
                    );
                  } catch (_) {
                    setState(() => saving = false);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l.error)));
                  }
                },
          child: Text(widget.value == null ? l.taskCreate : l.taskSavePlan),
        ),
      ],
    );
  }
}
