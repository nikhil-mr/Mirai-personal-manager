import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/todos/data/task_reminder_service.dart';
import 'package:personal_manager/features/todos/data/task_repository.dart';
import 'package:personal_manager/features/todos/domain/task_logic.dart';
import 'package:personal_manager/features/today/data/today_dashboard_repository.dart';

class _FakeReminders implements TaskReminderService {
  final scheduled = <int>[];
  final cancelled = <int>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<void> cancel(int notificationId) async =>
      cancelled.add(notificationId);
  @override
  Future<void> reconcile(List<TaskReminderEntry> tasks) async {}
  @override
  Future<ReminderResult> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    required DateTime reminderAt,
    required String soundId,
    bool requestPermission = true,
  }) async {
    scheduled.add(notificationId);
    return const ReminderResult(ReminderAvailability.scheduled);
  }
}

void main() {
  late MoneyDatabase db;
  late _FakeReminders notifications;
  late TaskRepository repository;
  setUp(() {
    db = MoneyDatabase(NativeDatabase.memory());
    notifications = _FakeReminders();
    repository = TaskRepository(db, notifications);
  });
  tearDown(() => db.close());

  test(
    'creates, edits, completes, restores and deletes task records',
    () async {
      final due = DateTime.now().add(const Duration(days: 1));
      final reminder = DateTime.now().add(const Duration(hours: 2));
      await repository.saveTask(
        title: 'Call dentist',
        dueAt: due,
        dueHasTime: true,
        reminderAt: reminder,
        reminderEnabled: true,
      );
      var task = (await repository.tasks()).single;
      expect(task.title, 'Call dentist');
      expect(notifications.scheduled, hasLength(1));
      await repository.saveTask(
        id: task.id,
        title: 'Call clinic',
        dueAt: due,
        dueHasTime: true,
        reminderAt: reminder,
        reminderEnabled: true,
      );
      task = (await repository.tasks()).single;
      expect(task.title, 'Call clinic');
      expect(task.isCompleted, isFalse);
      await repository.setCompleted(task.id, completed: true);
      task = (await repository.tasks()).single;
      expect(task.isCompleted, isTrue);
      expect(task.completedAt, isNotNull);
      expect(notifications.cancelled, contains(task.reminderNotificationId));
      await repository.setCompleted(task.id, completed: false);
      expect((await repository.tasks()).single.isCompleted, isFalse);
    expect(notifications.scheduled.length, 3);
      await repository.deleteTask(task.id);
      expect(await repository.tasks(), isEmpty);
    },
  );

  test('today integration projects task due today to dashboard', () async {
    final now = DateTime.now();
    await repository.saveTask(
      title: 'Pick up parcel',
      dueAt: now,
      dueHasTime: true,
    );
    final projection = await MoneyTodayDashboardRepository(
      MoneyRepository(db),
      taskRepository: repository,
    ).loadForDay(now);
    expect(projection.tasks!.map((t) => t.title), contains('Pick up parcel'));
  });

  test('task views identify overdue, upcoming, and completed tasks', () async {
    final now = DateTime.now();
    await repository.saveTask(
      title: 'Late',
      dueAt: now.subtract(const Duration(days: 2)),
    );
    await repository.saveTask(
      title: 'Later',
      dueAt: now.add(const Duration(days: 2)),
    );
    await repository.saveTask(
      title: 'Finish',
      dueAt: now,
      includeInToday: true,
    );
    final tasks = await repository.tasks();
    expect(
      filterAndSortTasks(
        tasks: tasks,
        view: TaskView.overdue,
        now: now,
      ).single.title,
      'Late',
    );
    expect(
      filterAndSortTasks(
        tasks: tasks,
        view: TaskView.upcoming,
        now: now,
      ).single.title,
      'Later',
    );
    final finish = tasks.singleWhere((task) => task.title == 'Finish');
    await repository.setCompleted(finish.id, completed: true);
    expect(
      filterAndSortTasks(
        tasks: await repository.tasks(),
        view: TaskView.done,
        now: now,
      ).single.title,
      'Finish',
    );
  });

  test('category names are unique without regard to case', () async {
    await repository.saveCategory(name: 'Home');
    await expectLater(
      repository.saveCategory(name: 'home'),
      throwsArgumentError,
    );
  });
}
