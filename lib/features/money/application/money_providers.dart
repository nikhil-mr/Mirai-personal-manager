import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/money_database.dart';
import '../data/money_repository.dart';
import '../domain/money_models.dart';

final moneyDatabaseProvider = Provider<MoneyDatabase>((ref) {
  final db = MoneyDatabase.open();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  final repository = MoneyRepository(ref.watch(moneyDatabaseProvider));
  unawaited(repository.seedDefaults());
  return repository;
});

final moneyAccountsProvider = StreamProvider<List<MoneyAccount>>(
  (ref) =>
      ref.watch(moneyRepositoryProvider).watchAccounts(includeArchived: true),
);
final moneyActiveAccountsProvider = StreamProvider<List<MoneyAccount>>(
  (ref) => ref.watch(moneyRepositoryProvider).watchAccounts(),
);
final moneyTransactionsProvider = StreamProvider<List<MoneyTransaction>>(
  (ref) => ref.watch(moneyRepositoryProvider).watchAllTransactions(),
);
final moneyExpensesCategoriesProvider = StreamProvider<List<MoneyCategory>>(
  (ref) => ref
      .watch(moneyRepositoryProvider)
      .watchCategories('expense', includeArchived: true),
);
final moneyIncomeCategoriesProvider = StreamProvider<List<MoneyCategory>>(
  (ref) => ref
      .watch(moneyRepositoryProvider)
      .watchCategories('income', includeArchived: true),
);
final moneyBalancesProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(moneyAccountsProvider);
  ref.watch(moneyTransactionsProvider);
  return ref.watch(moneyRepositoryProvider).calculateBalances();
});

final moneyPeriodProvider = StateProvider<MoneyPeriod>(
  (ref) => MoneyPeriod.day,
);
final moneyAnchorDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);
final moneyCustomRangeProvider = StateProvider<MoneyRange?>((ref) => null);
final moneySelectedAccountProvider = StateProvider<String?>((ref) => null);

final todayMoneyTotalsProvider =
    FutureProvider.family<({int expenses, int income}), DateTime>((
      ref,
      day,
    ) async {
      ref.watch(moneyTransactionsProvider);
      final start = DateTime(day.year, day.month, day.day);
      final records = await ref
          .watch(moneyRepositoryProvider)
          .transactions(
            start: start,
            end: DateTime(start.year, start.month, start.day + 1),
          );
      var expenses = 0;
      var income = 0;
      for (final record in records) {
        if (record.type == 'expense') expenses += record.amountMinor;
        if (record.type == 'income') income += record.amountMinor;
      }
      return (expenses: expenses, income: income);
    });
