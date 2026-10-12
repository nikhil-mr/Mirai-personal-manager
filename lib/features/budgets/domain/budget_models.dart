import '../../money/data/money_database.dart';

DateTime budgetMonth(DateTime date) => DateTime(date.year, date.month);

class BudgetLine {
  const BudgetLine({
    required this.plan,
    required this.category,
    required this.spentMinor,
    required this.carryMinor,
    required this.effectiveMinor,
  });
  final BudgetPlan plan;
  final MoneyCategory category;
  final int spentMinor;
  final int carryMinor;
  final int effectiveMinor;
  int get remainingMinor => effectiveMinor - spentMinor;
  double get utilization =>
      effectiveMinor <= 0 ? 0 : spentMinor / effectiveMinor;
  String get status => spentMinor > effectiveMinor
      ? 'Exceeded'
      : spentMinor == effectiveMinor
      ? 'Limit reached'
      : utilization >= .8
      ? 'Approaching limit'
      : 'On track';
}

class BudgetMonthSnapshot {
  const BudgetMonthSnapshot({
    required this.month,
    required this.lines,
    required this.unbudgetedSpendMinor,
    required this.allExpenseMinor,
    required this.transactions,
    required this.alerts,
  });
  final DateTime month;
  final List<BudgetLine> lines;
  final int unbudgetedSpendMinor;
  final int allExpenseMinor;
  final List<MoneyTransaction> transactions;
  final List<BudgetAlert> alerts;
  int get allocatedMinor =>
      lines.fold(0, (sum, line) => sum + line.effectiveMinor);
  int get budgetedSpendMinor =>
      lines.fold(0, (sum, line) => sum + line.spentMinor);
  int get remainingMinor => allocatedMinor - budgetedSpendMinor;
  double get utilization =>
      allocatedMinor == 0 ? 0 : budgetedSpendMinor / allocatedMinor;
}

class BudgetAlert {
  const BudgetAlert(this.categoryName, this.threshold);
  final String categoryName;
  final int threshold;
}

class BudgetCategoryComparison {
  const BudgetCategoryComparison({
    required this.categoryId,
    required this.currentSpentMinor,
    required this.previousSpentMinor,
  });
  final String categoryId;
  final int currentSpentMinor;
  final int previousSpentMinor;
  int get changeMinor => currentSpentMinor - previousSpentMinor;
}

class BudgetMonthComparison {
  const BudgetMonthComparison({
    required this.currentSpendMinor,
    required this.previousSpendMinor,
    required this.currentBudgetMinor,
    required this.previousBudgetMinor,
    required this.categories,
  });
  final int currentSpendMinor;
  final int previousSpendMinor;
  final int currentBudgetMinor;
  final int previousBudgetMinor;
  final List<BudgetCategoryComparison> categories;
  int get spendingChangeMinor => currentSpendMinor - previousSpendMinor;
  double? get spendingChangePercent => previousSpendMinor == 0
      ? null
      : spendingChangeMinor * 100 / previousSpendMinor;
  int get budgetChangeMinor => currentBudgetMinor - previousBudgetMinor;
  double get currentUtilization =>
      currentBudgetMinor == 0 ? 0 : currentSpendMinor / currentBudgetMinor;
  double get previousUtilization =>
      previousBudgetMinor == 0 ? 0 : previousSpendMinor / previousBudgetMinor;
}

BudgetMonthComparison compareBudgetMonths(
  BudgetMonthSnapshot current,
  BudgetMonthSnapshot previous,
) {
  final currentByCategory = <String, int>{};
  final previousByCategory = <String, int>{};
  for (final transaction in current.transactions) {
    final categoryId = transaction.categoryId;
    if (transaction.type == 'expense' && categoryId != null) {
      currentByCategory.update(
        categoryId,
        (amount) => amount + transaction.amountMinor,
        ifAbsent: () => transaction.amountMinor,
      );
    }
  }
  for (final transaction in previous.transactions) {
    final categoryId = transaction.categoryId;
    if (transaction.type == 'expense' && categoryId != null) {
      previousByCategory.update(
        categoryId,
        (amount) => amount + transaction.amountMinor,
        ifAbsent: () => transaction.amountMinor,
      );
    }
  }
  final ids = {...currentByCategory.keys, ...previousByCategory.keys};
  final categories =
      [
        for (final id in ids)
          BudgetCategoryComparison(
            categoryId: id,
            currentSpentMinor: currentByCategory[id] ?? 0,
            previousSpentMinor: previousByCategory[id] ?? 0,
          ),
      ]..sort(
        (a, b) => (b.currentSpentMinor + b.previousSpentMinor).compareTo(
          a.currentSpentMinor + a.previousSpentMinor,
        ),
      );
  return BudgetMonthComparison(
    currentSpendMinor: current.allExpenseMinor,
    previousSpendMinor: previous.allExpenseMinor,
    currentBudgetMinor: current.allocatedMinor,
    previousBudgetMinor: previous.allocatedMinor,
    categories: categories,
  );
}
