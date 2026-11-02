import 'store.dart';

/// A snapshot of current assignments, not a historical productivity rating.
class TaskProgress {
  final Map<String, int> states = {};
  int overdue = 0;
  int get total => states.values.fold(0, (a, b) => a + b);
  int count(String state) => states[state] ?? 0;
  void add(RecordData task, DateTime now) {
    final state = task['status'] as String? ?? 'unknown';
    states[state] = count(state) + 1;
    final due = DateTime.tryParse(task['due_at'] as String? ?? '');
    // Submitted work is waiting for review, not overdue player work.
    if ((state == 'todo' || state == 'in_progress') &&
        due != null &&
        due.isBefore(now)) {
      overdue++;
    }
  }
}

class TeamProgress {
  final TaskProgress overall = TaskProgress();
  final Map<String?, TaskProgress> members = {};
  TeamProgress(Iterable<RecordData> tasks, {required DateTime now}) {
    for (final task in tasks) {
      overall.add(task, now);
      members
          .putIfAbsent(task['member_id'] as String?, TaskProgress.new)
          .add(task, now);
    }
  }
}
