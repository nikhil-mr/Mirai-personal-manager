import 'dashboard_models.dart';

class TaskProgress {
  const TaskProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  int get remaining => total - completed;
  double get fraction => total == 0 ? 0 : completed / total;
  int get percent => (fraction * 100).round();
}

bool isSameLocalDay(DateTime first, DateTime second) {
  final localFirst = first.toLocal();
  final localSecond = second.toLocal();
  return localFirst.year == localSecond.year &&
      localFirst.month == localSecond.month &&
      localFirst.day == localSecond.day;
}

bool isTaskEligibleForDay(DashboardTask task, DateTime day) {
  if (task.isDeleted) return false;
  return (task.dueAt != null && isSameLocalDay(task.dueAt!, day)) ||
      (task.scheduledFor != null && isSameLocalDay(task.scheduledFor!, day)) ||
      (task.scheduledAt != null && isSameLocalDay(task.scheduledAt!, day));
}

bool _hasReminderOnDay(DashboardTask task, DateTime day) =>
    task.reminderAt != null && isSameLocalDay(task.reminderAt!, day);

TaskProgress calculateTaskProgress(
  Iterable<DashboardTask> tasks,
  DateTime day,
) {
  var total = 0;
  var completed = 0;
  for (final task in tasks) {
    if (!isTaskEligibleForDay(task, day)) continue;
    total++;
    if (task.isCompleted) completed++;
  }
  return TaskProgress(completed: completed, total: total);
}

List<DashboardTask> upcomingTasksForDay(
  Iterable<DashboardTask> tasks,
  DateTime day,
) {
  final upcoming =
      tasks
          .where(
            (task) =>
                (isTaskEligibleForDay(task, day) ||
                    _hasReminderOnDay(task, day)) &&
                !task.isCompleted,
          )
          .toList()
        ..sort((first, second) {
          final firstTime = (first.todaySortTime ?? first.reminderAt)
              ?.toLocal();
          final secondTime = (second.todaySortTime ?? second.reminderAt)
              ?.toLocal();
          if (firstTime == null) return secondTime == null ? 0 : 1;
          if (secondTime == null) return -1;
          return firstTime.compareTo(secondTime);
        });
  return upcoming;
}

List<DashboardCommitment> sortUpcomingCommitments(
  Iterable<DashboardCommitment> commitments,
) {
  final sorted = commitments.toList()
    ..sort((first, second) => first.dueAt.compareTo(second.dueAt));
  return sorted;
}
