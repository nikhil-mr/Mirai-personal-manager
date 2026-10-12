import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../data/task_reminder_service.dart';
import '../data/task_repository.dart';
import '../domain/task_logic.dart';

final taskReminderServiceProvider = Provider<TaskReminderService>(
  (ref) => LocalTaskReminderService(),
);
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(moneyDatabaseProvider),
    ref.watch(taskReminderServiceProvider),
  ),
);
final tasksProvider = StreamProvider<List<TaskRecord>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  unawaited(repository.reconcileReminders().catchError((_) {}));
  return repository.watchTasks();
});
final taskCategoriesProvider = StreamProvider<List<TaskCategory>>(
  (ref) => ref.watch(taskRepositoryProvider).watchCategories(),
);
final taskDetailProvider = FutureProvider.family<TaskRecord?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).task(id),
);
final taskViewProvider = StateProvider<TaskView>(
  (ref) => TaskView.allPending,
);
final taskSearchProvider = StateProvider<String>((ref) => '');
final taskPriorityFilterProvider = StateProvider<TaskPriority?>((ref) => null);
final taskCategoryFilterProvider = StateProvider<String?>((ref) => null);
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.dueTime);
