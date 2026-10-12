import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/today/domain/dashboard_calculations.dart';
import 'package:personal_manager/features/today/domain/dashboard_models.dart';

void main() {
  final today = DateTime(2026, 6, 15, 9);

  group('dashboard task calculations', () {
    test(
      'counts only due or scheduled tasks for today and excludes deleted',
      () {
        final tasks = [
          DashboardTask(
            title: 'Completed today',
            isCompleted: true,
            dueAt: DateTime(2026, 6, 15, 8),
          ),
          DashboardTask(
            title: 'Pending today',
            dueAt: DateTime(2026, 6, 15, 11),
          ),
          DashboardTask(
            title: 'Future',
            scheduledAt: DateTime(2026, 6, 16, 10),
          ),
          DashboardTask(
            title: 'Deleted today',
            dueAt: DateTime(2026, 6, 15),
            isDeleted: true,
          ),
        ];

        final progress = calculateTaskProgress(tasks, today);

        expect(progress.completed, 1);
        expect(progress.total, 2);
        expect(progress.remaining, 1);
        expect(progress.percent, 50);
      },
    );

    test('returns zero progress when there are no eligible tasks', () {
      final progress = calculateTaskProgress([
        DashboardTask(title: 'Tomorrow', dueAt: DateTime(2026, 6, 16)),
      ], today);

      expect(progress.completed, 0);
      expect(progress.total, 0);
      expect(progress.remaining, 0);
      expect(progress.fraction, 0);
      expect(progress.percent, 0);
    });

    test('sorts pending tasks by today time and leaves untimed tasks last', () {
      final tasks = [
        DashboardTask(title: 'No time', scheduledFor: DateTime(2026, 6, 15)),
        DashboardTask(title: 'Later', scheduledAt: DateTime(2026, 6, 15, 14)),
        DashboardTask(title: 'Soon', dueAt: DateTime(2026, 6, 15, 10)),
        DashboardTask(
          title: 'Done',
          dueAt: DateTime(2026, 6, 15, 8),
          isCompleted: true,
        ),
      ];

      expect(upcomingTasksForDay(tasks, today).map((task) => task.title), [
        'Soon',
        'Later',
        'No time',
      ]);
    });

    test('compares date boundaries using local calendar dates', () {
      expect(
        isSameLocalDay(DateTime(2026, 6, 15, 0), DateTime(2026, 6, 15, 23, 59)),
        isTrue,
      );
      expect(isSameLocalDay(today, DateTime(2026, 6, 16)), isFalse);
    });
  });

  test('sorts upcoming commitments by nearest due date', () {
    final commitments = [
      DashboardCommitment(title: 'Later', dueAt: DateTime(2026, 7, 1)),
      DashboardCommitment(title: 'Sooner', dueAt: DateTime(2026, 6, 20)),
    ];

    expect(sortUpcomingCommitments(commitments).map((item) => item.title), [
      'Sooner',
      'Later',
    ]);
  });
}
