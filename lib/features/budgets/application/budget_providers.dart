import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../money/application/money_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_models.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(
    ref.watch(moneyDatabaseProvider),
    ref.watch(moneyRepositoryProvider),
  ),
);
final budgetSelectedMonthProvider = StateProvider<DateTime>(
  (ref) => budgetMonth(DateTime.now()),
);
final budgetPlansProvider = StreamProvider(
  (ref) => ref
      .watch(budgetRepositoryProvider)
      .db
      .select(ref.watch(budgetRepositoryProvider).db.budgetPlans)
      .watch(),
);
final budgetMonthProvider =
    FutureProvider.family<BudgetMonthSnapshot, DateTime>((ref, month) async {
      ref.watch(moneyTransactionsProvider);
      ref.watch(moneyExpensesCategoriesProvider);
      ref.watch(budgetPlansProvider);
      final selected = ref.watch(budgetSelectedMonthProvider);
      final evaluateAlerts = budgetMonth(selected) == budgetMonth(month);
      return ref
          .watch(budgetRepositoryProvider)
          .snapshot(month, evaluateAlerts: evaluateAlerts);
    });
