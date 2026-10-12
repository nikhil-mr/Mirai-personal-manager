enum DashboardTaskPriority { low, normal, high }

class DashboardMoneyTotals {
  const DashboardMoneyTotals({
    required this.spending,
    required this.income,
    required this.currencyCode,
  });

  final num spending;
  final num income;
  final String currencyCode;
}

/// A small presentation projection of a task from the future To-do repository.
class DashboardTask {
  const DashboardTask({
    required this.title,
    this.dueAt,
    this.scheduledFor,
    this.scheduledAt,
    this.priority = DashboardTaskPriority.normal,
    this.reminderAt,
    this.isCompleted = false,
    this.isDeleted = false,
  });

  final String title;
  final DateTime? dueAt;

  /// Calendar day assignment for scheduled tasks that may have no time.
  final DateTime? scheduledFor;

  /// Optional time of day for a scheduled task.
  final DateTime? scheduledAt;
  final DashboardTaskPriority priority;
  final DateTime? reminderAt;
  final bool isCompleted;
  final bool isDeleted;

  DateTime? get todaySortTime => dueAt ?? scheduledAt;
}

class DashboardPlace {
  const DashboardPlace({
    required this.name,
    this.id,
    this.category,
    this.plannedAt,
    this.tripName,
  });

  final String name;
  final String? id;
  final String? category;
  final DateTime? plannedAt;
  final String? tripName;
}

class DashboardGroceryItem {
  const DashboardGroceryItem({required this.name, this.quantity});

  final String name;
  final String? quantity;
}

class DashboardGrocerySummary {
  const DashboardGrocerySummary({
    required this.activeItemCount,
    required this.remainingItemCount,
    this.inventoryItemCount = 0,
    this.expiringSoonCount = 0,
    this.estimatedRemainingMinor,
    this.preview = const [],
  });

  final int activeItemCount;
  final int remainingItemCount;
  final int inventoryItemCount;
  final int expiringSoonCount;
  final int? estimatedRemainingMinor;
  final List<DashboardGroceryItem> preview;
}

class DashboardCommitment {
  const DashboardCommitment({
    required this.title,
    required this.dueAt,
    this.amount,
    this.currencyCode,
    this.status,
  });

  final String title;
  final DateTime dueAt;
  final num? amount;
  final String? currencyCode;
  final String? status;
}

/// `null` means that module is not connected; an empty list means it has no
/// matching records for the requested day.
class TodayDashboardSnapshot {
  const TodayDashboardSnapshot({
    this.money,
    this.tasks,
    this.places,
    this.groceries,
    this.commitments,
  });

  final DashboardMoneyTotals? money;
  final List<DashboardTask>? tasks;
  final List<DashboardPlace>? places;
  final DashboardGrocerySummary? groceries;
  final List<DashboardCommitment>? commitments;

  static const empty = TodayDashboardSnapshot();
}
