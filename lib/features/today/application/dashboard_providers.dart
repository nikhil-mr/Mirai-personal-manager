import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/today_dashboard_repository.dart';
import '../domain/dashboard_models.dart';
import '../../money/application/money_providers.dart';
import '../../todos/application/task_providers.dart';
import '../../places/application/places_providers.dart';
import '../../groceries/application/grocery_providers.dart';

final todayDashboardRepositoryProvider = Provider<TodayDashboardRepository>(
  (ref) => MoneyTodayDashboardRepository(
    ref.watch(moneyRepositoryProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    placesRepository: ref.watch(placesRepositoryProvider),
    groceryRepository: ref.watch(groceryRepositoryProvider),
  ),
);

/// Module write actions should invalidate this provider after changing their
/// records. Navigation back to Today and app resume also invalidate it.
final todayDashboardSnapshotProvider =
    FutureProvider.family<TodayDashboardSnapshot, DateTime>((
      ref,
      localDay,
    ) async {
      ref.watch(tasksProvider);
      ref.watch(savedPlacesProvider);
      ref.watch(groceryListsProvider);
      ref.watch(homeInventoryProvider);
      return ref.watch(todayDashboardRepositoryProvider).loadForDay(localDay);
    });

final dashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
