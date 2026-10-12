import '../domain/dashboard_models.dart';
import '../../money/data/money_repository.dart';
import '../../todos/data/task_repository.dart';
import '../../places/data/places_repository.dart';
import '../../groceries/data/grocery_repository.dart';

abstract interface class TodayDashboardRepository {
  /// Loads dashboard projections for a local calendar day.
  ///
  /// Implementations should aggregate only external income and expenses,
  /// excluding transfers between a user's own accounts, and return tasks,
  /// places and commitments already scoped to [localDay].
  Future<TodayDashboardSnapshot> loadForDay(DateTime localDay);
}

/// Empty source for consumers that have not connected module repositories.
/// It intentionally returns no sample records.
class EmptyTodayDashboardRepository implements TodayDashboardRepository {
  const EmptyTodayDashboardRepository();

  @override
  Future<TodayDashboardSnapshot> loadForDay(DateTime localDay) async =>
      TodayDashboardSnapshot.empty;
}

class MoneyTodayDashboardRepository implements TodayDashboardRepository {
  const MoneyTodayDashboardRepository(
    this.moneyRepository, {
    this.taskRepository,
    this.placesRepository,
    this.groceryRepository,
  });
  final MoneyRepository moneyRepository;
  final TaskRepository? taskRepository;
  final PlacesRepository? placesRepository;
  final GroceryRepository? groceryRepository;

  @override
  Future<TodayDashboardSnapshot> loadForDay(DateTime localDay) async {
    final start = DateTime(localDay.year, localDay.month, localDay.day);
    final records = await moneyRepository.transactions(
      start: start,
      end: DateTime(start.year, start.month, start.day + 1),
    );
    var spending = 0;
    var income = 0;
    for (final record in records) {
      if (record.type == 'expense') spending += record.amountMinor;
      if (record.type == 'income') income += record.amountMinor;
    }
    final taskRows = taskRepository == null
        ? null
        : await taskRepository!.forDashboard(localDay);
    final placeRows = placesRepository == null
        ? null
        : await placesRepository!.placesPlannedFor(localDay);
    final groceries = await groceryRepository?.dashboardSummary();
    return TodayDashboardSnapshot(
      money: DashboardMoneyTotals(
        spending: spending / 100,
        income: income / 100,
        currencyCode: 'INR',
      ),
      tasks: taskRows?.map((task) {
        final due = task.dueAt?.toLocal();
        final timedDue = task.dueHasTime ? due : null;
        final assignedDay = due != null && !task.dueHasTime
            ? DateTime(due.year, due.month, due.day)
            : task.includeInToday && due == null
            ? DateTime(localDay.year, localDay.month, localDay.day)
            : null;
        return DashboardTask(
          title: task.title,
          dueAt: timedDue,
          scheduledFor: assignedDay,
          scheduledAt: timedDue,
          priority: switch (task.priority) {
            'low' => DashboardTaskPriority.low,
            'high' || 'urgent' => DashboardTaskPriority.high,
            _ => DashboardTaskPriority.normal,
          },
          reminderAt: task.reminderEnabled ? task.reminderAt : null,
          isCompleted: task.isCompleted,
        );
      }).toList(),
      places: placeRows
          ?.map(
            (place) => DashboardPlace(
              id: place.id,
              name: place.name,
              category: place.category,
              plannedAt: place.plannedAt,
            ),
          )
          .toList(),
      groceries: groceries == null
          ? null
          : DashboardGrocerySummary(
              activeItemCount: groceries.remaining + groceries.purchased,
              remainingItemCount: groceries.remaining,
              inventoryItemCount: groceries.inventoryCount,
              expiringSoonCount: groceries.expiringSoon,
              estimatedRemainingMinor: groceries.estimatedRemaining,
              preview: groceries.preview
                  .map(
                    (item) => DashboardGroceryItem(
                      name: item.name,
                      quantity: '${item.quantityMilli / 1000} ${item.unit}',
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
