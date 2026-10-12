import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../money/data/money_database.dart';
import '../domain/task_logic.dart';
import 'task_reminder_service.dart';

class TaskSaveResult {
  const TaskSaveResult({this.reminderMessage});
  final String? reminderMessage;
}

class TaskRepository {
  TaskRepository(this.db, this.reminders);
  final MoneyDatabase db;
  final TaskReminderService reminders;
  static const _uuid = Uuid();

  Stream<List<TaskRecord>> watchTasks() => (db.select(
    db.taskRecords,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Stream<List<TaskCategory>> watchCategories() =>
      (db.select(db.taskCategories)
            ..where((c) => c.archivedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<List<TaskRecord>> tasks() => (db.select(
    db.taskRecords,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<TaskRecord?> task(String id) => (db.select(
    db.taskRecords,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TaskCategory>> categories() =>
      (db.select(db.taskCategories)
            ..where((c) => c.archivedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .get();

  Future<void> saveCategory({
    String? id,
    required String name,
    int colorValue = 0xFF087F72,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 60) {
      throw ArgumentError('Category name must be between 1 and 60 characters.');
    }
    final matches = await categories();
    if (matches.any(
      (category) =>
          category.name.toLowerCase() == clean.toLowerCase() &&
          category.id != id,
    )) {
      throw ArgumentError('A category with this name already exists.');
    }
    final now = DateTime.now();
    if (id == null) {
      await db
          .into(db.taskCategories)
          .insert(
            TaskCategoriesCompanion.insert(
              id: _uuid.v4(),
              name: clean,
              colorValue: Value(colorValue),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (db.update(db.taskCategories)..where((c) => c.id.equals(id))).write(
        TaskCategoriesCompanion(
          name: Value(clean),
          colorValue: Value(colorValue),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> archiveCategory(String id) =>
      (db.update(db.taskCategories)..where((c) => c.id.equals(id))).write(
        TaskCategoriesCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<TaskSaveResult> saveTask({
    String? id,
    required String title,
    String description = '',
    String? categoryId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
    bool dueHasTime = false,
    bool includeInToday = false,
    DateTime? reminderAt,
    bool reminderEnabled = false,
    String notificationSoundId = 'default',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 160) {
      throw ArgumentError('Enter a task title (up to 160 characters).');
    }
    if (categoryId != null) {
      final category =
          await (db.select(db.taskCategories)
                ..where((c) => c.id.equals(categoryId) & c.archivedAt.isNull()))
              .getSingleOrNull();
      if (category == null) {
        throw ArgumentError('Choose an active task category.');
      }
    }
    if (reminderEnabled && reminderAt == null) {
      throw ArgumentError('Choose a reminder date and time.');
    }
    if (reminderEnabled && !reminderAt!.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a reminder time in the future.');
    }
    final existing = id == null ? null : await task(id);
    if (id != null && existing == null) {
      throw StateError('Task no longer exists.');
    }
    final taskId = id ?? _uuid.v4();
    final notificationId = reminderEnabled
        ? (existing?.reminderNotificationId ?? await _notificationIdFor(taskId))
        : existing?.reminderNotificationId;
    final now = DateTime.now();
    final normalizedDue = dueAt == null
        ? null
        : dueHasTime
        ? dueAt.toLocal()
        : DateTime(
            dueAt.toLocal().year,
            dueAt.toLocal().month,
            dueAt.toLocal().day,
          );
    final values = TaskRecordsCompanion(
      id: Value(taskId),
      title: Value(cleanTitle),
      description: Value(description.trim()),
      categoryId: Value(categoryId),
      priority: Value(priority.name),
      dueAt: Value(normalizedDue),
      dueHasTime: Value(dueHasTime && normalizedDue != null),
      includeInToday: Value(includeInToday),
      reminderAt: Value(reminderEnabled ? reminderAt!.toLocal() : null),
      reminderEnabled: Value(reminderEnabled),
      notificationSoundId: Value(notificationSoundId),
      reminderNotificationId: Value(notificationId),
      isCompleted: Value(existing?.isCompleted ?? false),
      completedAt: Value(existing?.completedAt),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (existing == null) {
      await db.into(db.taskRecords).insert(values);
    } else {
      await (db.update(
        db.taskRecords,
      )..where((t) => t.id.equals(taskId))).write(values);
    }

    final reminderChanged =
        existing?.reminderNotificationId != null &&
        (reminderEnabled == false ||
            existing?.reminderAt != reminderAt ||
            existing?.notificationSoundId != notificationSoundId);
    if (reminderChanged && existing?.reminderNotificationId != null) {
      await reminders.cancel(existing!.reminderNotificationId!);
    }
    if (!reminderEnabled) {
      return const TaskSaveResult();
    }
    if (existing?.isCompleted == true) {
      return const TaskSaveResult();
    }
    final outcome = await reminders
        .schedule(
          notificationId: notificationId!,
          taskId: taskId,
          title: cleanTitle,
          reminderAt: reminderAt!,
          soundId: notificationSoundId,
        )
        .catchError(
          (Object error) => ReminderResult(
            ReminderAvailability.unsupported,
            message: 'Reminder could not be scheduled: $error',
          ),
        );
    if (!outcome.scheduled) {
      await reminders.cancel(notificationId);
      await (db.update(
        db.taskRecords,
      )..where((t) => t.id.equals(taskId))).write(
        const TaskRecordsCompanion(
          reminderEnabled: Value(false),
          reminderAt: Value(null),
        ),
      );
    }
    return TaskSaveResult(reminderMessage: outcome.message);
  }

  Future<int> _notificationIdFor(String taskId) async {
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    hash = max(1, hash);
    final collision = await (db.select(
      db.taskRecords,
    )..where((t) => t.reminderNotificationId.equals(hash))).getSingleOrNull();
    if (collision == null || collision.id == taskId) return hash;
    return (hash + Random.secure().nextInt(1000000) + 1) & 0x7fffffff;
  }

  Future<void> setCompleted(String id, {required bool completed}) async {
    final record = await task(id);
    if (record == null) return;
    final completedAt = completed ? DateTime.now() : null;
    await (db.update(db.taskRecords)..where((t) => t.id.equals(id))).write(
      TaskRecordsCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completedAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final notificationId = record.reminderNotificationId;
    if (notificationId != null) {
      if (completed) {
        await reminders.cancel(notificationId);
      } else if (record.reminderEnabled &&
          record.reminderAt != null &&
          record.reminderAt!.isAfter(DateTime.now())) {
        final result = await reminders
            .schedule(
              notificationId: notificationId,
              taskId: record.id,
              title: record.title,
              reminderAt: record.reminderAt!,
              soundId: record.notificationSoundId,
            )
            .catchError(
              (Object error) => ReminderResult(
                ReminderAvailability.unsupported,
                message: 'Reminder could not be restored: $error',
              ),
            );
        if (!result.scheduled) {
          await reminders.cancel(notificationId);
          await (db.update(
            db.taskRecords,
          )..where((t) => t.id.equals(id))).write(
            const TaskRecordsCompanion(
              reminderEnabled: Value(false),
              reminderAt: Value(null),
            ),
          );
        }
      } else if (record.reminderEnabled) {
        await (db.update(db.taskRecords)..where((t) => t.id.equals(id))).write(
          const TaskRecordsCompanion(
            reminderEnabled: Value(false),
            reminderAt: Value(null),
          ),
        );
      }
    }
  }

  Future<void> deleteTask(String id) async {
    final record = await task(id);
    if (record?.reminderNotificationId != null) {
      await reminders.cancel(record!.reminderNotificationId!);
    }
    await (db.delete(db.taskRecords)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reconcileReminders() async {
    final records = await tasks();
    await reminders.reconcile(
      records
          .map(
            (record) => TaskReminderEntry(
              id: record.id,
              notificationId: record.reminderNotificationId,
              title: record.title,
              reminderAt: record.reminderAt,
              reminderEnabled: record.reminderEnabled,
              isCompleted: record.isCompleted,
              soundId: record.notificationSoundId,
            ),
          )
          .toList(),
    );
    for (final record in records) {
      if (record.reminderEnabled &&
          record.reminderAt != null &&
          !record.reminderAt!.isAfter(DateTime.now())) {
        await (db.update(
          db.taskRecords,
        )..where((t) => t.id.equals(record.id))).write(
          const TaskRecordsCompanion(
            reminderEnabled: Value(false),
            reminderAt: Value(null),
          ),
        );
      }
    }
  }

  Future<List<TaskRecord>> forDashboard(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(start.year, start.month, start.day + 1);
    return (db.select(db.taskRecords)
          ..where(
            (t) =>
                (t.dueAt.isBiggerOrEqualValue(start) &
                    t.dueAt.isSmallerThanValue(end)) |
                (t.includeInToday.equals(true) & t.dueAt.isNull()) |
                (t.reminderEnabled.equals(true) &
                    t.reminderAt.isBiggerOrEqualValue(start) &
                    t.reminderAt.isSmallerThanValue(end)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .get();
  }
}
