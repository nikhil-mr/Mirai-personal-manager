import '../../money/data/money_database.dart';

enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
    TaskPriority.urgent => 'Urgent',
  };
  int get weight => index;
}

enum TaskView { today, upcoming, allPending, overdue, done }

enum TaskSort { dueTime, priority, createdAt }

DateTime localDateOnly(DateTime date) =>
    DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day);

bool isTaskDueToday(TaskRecord task, DateTime now) {
  if (task.dueAt != null && localDateOnly(task.dueAt!) == localDateOnly(now)) {
    return true;
  }
  return task.dueAt == null && task.includeInToday;
}

bool isTaskOverdue(TaskRecord task, DateTime now) {
  if (task.isCompleted || task.dueAt == null) return false;
  final due = task.dueAt!.toLocal();
  if (task.dueHasTime) return due.isBefore(now.toLocal());
  return localDateOnly(due).isBefore(localDateOnly(now));
}

bool _matchesView(TaskRecord task, TaskView view, DateTime now) =>
    switch (view) {
      TaskView.today => isTaskDueToday(task, now),
      TaskView.upcoming =>
        !task.isCompleted &&
            task.dueAt != null &&
            localDateOnly(task.dueAt!).isAfter(localDateOnly(now)),
      TaskView.allPending => !task.isCompleted,
      TaskView.overdue => isTaskOverdue(task, now),
      TaskView.done => task.isCompleted,
    };

List<TaskRecord> filterAndSortTasks({
  required Iterable<TaskRecord> tasks,
  required TaskView view,
  required DateTime now,
  String query = '',
  Map<String, String> categoryNames = const {},
  String? categoryId,
  TaskPriority? priority,
  TaskSort sort = TaskSort.dueTime,
}) {
  final normalized = query.trim().toLowerCase();
  final result = tasks.where((task) {
    if (!_matchesView(task, view, now)) return false;
    if (categoryId != null && task.categoryId != categoryId) return false;
    if (priority != null && task.priority != priority.name) return false;
    if (normalized.isEmpty) return true;
    return task.title.toLowerCase().contains(normalized) ||
        task.description.toLowerCase().contains(normalized) ||
        categoryNames[task.categoryId]?.toLowerCase().contains(normalized) ==
            true;
  }).toList();
  result.sort((a, b) {
    if (view == TaskView.done) {
      return (b.completedAt ?? b.updatedAt).compareTo(
        a.completedAt ?? a.updatedAt,
      );
    }
    switch (sort) {
      case TaskSort.dueTime:
        final aDue = a.dueAt;
        final bDue = b.dueAt;
        if (aDue == null) return bDue == null ? 0 : 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      case TaskSort.priority:
        final byPriority = _priorityWeight(b.priority)
            .compareTo(_priorityWeight(a.priority));
        if (byPriority != 0) return byPriority;
        return _dueCompare(a, b);
      case TaskSort.createdAt:
        return b.createdAt.compareTo(a.createdAt);
    }
  });
  return result;
}

int _priorityWeight(String value) => switch (value) {
  'urgent' => 3,
  'high' => 2,
  'medium' => 1,
  _ => 0,
};

int _dueCompare(TaskRecord a, TaskRecord b) {
  if (a.dueAt == null) return b.dueAt == null ? 0 : 1;
  if (b.dueAt == null) return -1;
  return a.dueAt!.compareTo(b.dueAt!);
}

({int completed, int total}) dailyTaskProgress(
  Iterable<TaskRecord> tasks,
  DateTime day,
) {
  final eligible = tasks.where((task) => isTaskDueToday(task, day)).toList();
  return (
    completed: eligible.where((task) => task.isCompleted).length,
    total: eligible.length,
  );
}
