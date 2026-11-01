import 'package:flutter/material.dart';

import '../data/account_roster.dart';
import '../data/preparation_plan.dart';
import '../data/store.dart';
import '../l10n/app_localizations.dart';
import 'deadline_picker.dart';
import 'task_form.dart';

String preparationCriteria(AppLocalizations l, String type) => switch (type) {
  'dry_run' => l.prepCriteriaDryRun,
  'execute' => l.prepCriteriaExecute,
  'retake' => l.prepCriteriaRetake,
  _ => l.prepCriteriaRole,
};

class PreparationWizard extends StatefulWidget {
  final Store store;
  final String team, map;
  const PreparationWizard({
    super.key,
    required this.store,
    required this.team,
    required this.map,
  });
  @override
  State<PreparationWizard> createState() => _PreparationWizardState();
}

class _PreparationWizardState extends State<PreparationWizard> {
  late final PreparationPlan plan;
  late final List<RecordData> strategies, members;
  final selectedStrategies = <String>{}, selectedMembers = <String>{};
  final criteria = TextEditingController();
  final assignments = <String, Set<String>>{};
  final previousMembers = <String>{};
  void prepareDistribution() {
    assignments.removeWhere((id, _) => !selectedStrategies.contains(id));
    final added = selectedMembers.difference(previousMembers);
    for (final id in selectedStrategies) {
      final ids = assignments.putIfAbsent(id, () => selectedMembers.toSet());
      ids.removeWhere((member) => !selectedMembers.contains(member));
      ids.addAll(added);
    }
    previousMembers
      ..clear()
      ..addAll(selectedMembers);
  }

  int get count => assignments.values.fold(0, (sum, ids) => sum + ids.length);
  int step = 0;
  String type = 'tactic';
  String? error;
  DateTime? due;
  bool creating = false, initialized = false;
  @override
  void initState() {
    super.initState();
    plan = PreparationPlan(widget.store, widget.team, widget.map);
    strategies = widget.store
        .strategies(widget.team)
        .where((s) => s['map_id'] == widget.map)
        .toList();
    members = accountAssignableMembers(widget.store, widget.team);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      criteria.text = preparationCriteria(AppLocalizations.of(context), type);
      initialized = true;
    }
  }

  @override
  void dispose() {
    criteria.dispose();
    super.dispose();
  }

  Future<void> deadline() async {
    final value = await pickTaskDeadline(context, due);
    if (value != null && mounted) setState(() => due = value);
  }

  void proceed() {
    final l = AppLocalizations.of(context);
    if (selectedStrategies.isEmpty) {
      setState(() {
        step = 0;
        error = l.prepChooseStrategies;
      });
      return;
    }
    if (step >= 1 && selectedMembers.isEmpty) {
      setState(() {
        step = 1;
        error = l.prepChooseMembers;
      });
      return;
    }
    if (step < 2) {
      setState(() {
        if (step == 1) prepareDistribution();
        step++;
        error = null;
      });
      return;
    }
    if (assignments.values.any((ids) => ids.isEmpty)) {
      setState(() => error = l.prepChooseAssignments);
      return;
    }
    if (due == null) {
      setState(() => error = l.prepDeadlineRequired);
      return;
    }
    if (criteria.text.trim().isEmpty) {
      setState(() => error = l.invalidText);
      return;
    }
    if (creating) return;
    setState(() => creating = true);
    try {
      final ids = plan.create(
        strategies: selectedStrategies,
        members: selectedMembers,
        type: type,
        dueAt: due!,
        criteria: criteria.text,
        assignments: assignments,
      );
      Navigator.pop(context, ids.length);
    } on DomainError catch (e) {
      setState(() {
        creating = false;
        error = switch (e.code) {
          'limit' => l.prepBatchLimit,
          'crossTeam' => l.prepRosterChanged,
          'invalidPlan' => l.prepChooseAssignments,
          'readOnlyTeam' || 'syncAccountMismatch' => l.readOnlyTeam,
          _ => l.invalidText,
        };
      });
    } catch (_) {
      setState(() {
        creating = false;
        error = l.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        m = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l.prepareMap),
      content: SizedBox(
        width: 640,
        height: 500,
        child: Stepper(
          currentStep: step,
          onStepTapped: creating
              ? null
              : (value) => setState(() {
                  if (value == 2) prepareDistribution();
                  step = value;
                  error = null;
                }),
          controlsBuilder: (context, details) => !details.isActive
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            key: const ValueKey('prep-next'),
                            onPressed: creating ? null : proceed,
                            child: Text(step == 2 ? l.prepCreate : l.prepNext),
                          ),
                          if (step > 0)
                            TextButton(
                              onPressed: creating
                                  ? null
                                  : () => setState(() {
                                      step--;
                                      error = null;
                                    }),
                              child: Text(l.back),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          steps: [
            Step(
              title: Text(l.prepStrategies),
              isActive: step >= 0,
              content: Column(
                children: [
                  if (strategies.isEmpty) Text(l.prepNoStrategies),
                  for (final row in strategies)
                    CheckboxListTile(
                      key: ValueKey('prep-strategy-${row['id']}'),
                      contentPadding: EdgeInsets.zero,
                      value: selectedStrategies.contains(row['id']),
                      title: Text(row['title'] as String),
                      subtitle: Text(row['side'] as String),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selectedStrategies.add(row['id'] as String);
                        } else {
                          selectedStrategies.remove(row['id']);
                        }
                        error = null;
                      }),
                    ),
                ],
              ),
            ),
            Step(
              title: Text(l.prepMembers),
              isActive: step >= 1,
              content: Column(
                children: [
                  if (members.isEmpty) Text(l.prepNoMembers),
                  for (final row in members)
                    CheckboxListTile(
                      key: ValueKey('prep-member-${row['id']}'),
                      contentPadding: EdgeInsets.zero,
                      value: selectedMembers.contains(row['id']),
                      title: Text(row['name'] as String),
                      subtitle: Text(row['game_role'] as String),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selectedMembers.add(row['id'] as String);
                        } else {
                          selectedMembers.remove(row['id']);
                        }
                        error = null;
                      }),
                    ),
                ],
              ),
            ),
            Step(
              title: Text(l.prepPlan),
              isActive: step >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.prepTemplate),
                    items: [
                      for (final value in PreparationPlan.types)
                        DropdownMenuItem(
                          value: value,
                          child: Text(taskTypeLabel(l, value)),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      final old = preparationCriteria(l, type);
                      type = value!;
                      if (criteria.text == old) {
                        criteria.text = preparationCriteria(l, type);
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('prep-criteria'),
                    controller: criteria,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 5000,
                    decoration: InputDecoration(labelText: l.taskCriteria),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('prep-deadline'),
                        onPressed: deadline,
                        icon: const Icon(Icons.event),
                        label: Text(
                          due == null
                              ? l.taskNoDeadline
                              : '${m.formatMediumDate(due!)} · ${m.formatTimeOfDay(TimeOfDay.fromDateTime(due!))}',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l.taskDeadlineHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.prepAssignTactics,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final row in strategies.where(
                    (r) => selectedStrategies.contains(r['id']),
                  ))
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(row['title'] as String),
                      subtitle: Text(
                        l.prepAssigneeCount(
                          assignments[row['id']]?.length ?? 0,
                        ),
                      ),
                      children: [
                        for (final member in members.where(
                          (m) => selectedMembers.contains(m['id']),
                        ))
                          CheckboxListTile(
                            key: ValueKey(
                              'prep-assignee-${row['id']}-${member['id']}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: Text(member['name'] as String),
                            value:
                                assignments[row['id']]?.contains(
                                  member['id'],
                                ) ??
                                false,
                            onChanged: (value) => setState(() {
                              final ids = assignments[row['id']]!;
                              if (value == true) {
                                ids.add(member['id'] as String);
                              } else {
                                ids.remove(member['id']);
                              }
                            }),
                          ),
                      ],
                    ),
                  Text(l.prepCount(count)),
                  if (count > 500) Text(l.prepBatchLimit),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: creating ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
