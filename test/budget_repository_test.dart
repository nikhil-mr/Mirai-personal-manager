import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_manager/features/budgets/application/budget_providers.dart';
import 'package:personal_manager/features/budgets/data/budget_repository.dart';
import 'package:personal_manager/features/money/application/money_providers.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';
import 'package:personal_manager/features/budgets/domain/budget_models.dart';

void main() {
  late MoneyDatabase db;
  late MoneyRepository money;
  late BudgetRepository budgets;
  late String account;
  late String destination;
  late String food;
  late String salary;

  setUp(() async {
    db = MoneyDatabase(NativeDatabase.memory());
    money = MoneyRepository(db);
    budgets = BudgetRepository(db, money);
    await money.seedDefaults();
    await money.saveAccount(
      name: 'Checking',
      type: AccountType.bank,
      openingBalanceMinor: 100000,
    );
    await money.saveAccount(
      name: 'Cash',
      type: AccountType.cash,
      openingBalanceMinor: 0,
    );
    final accounts = await money.accounts();
    account = accounts.first.id;
    destination = accounts.last.id;
    final categories = await money.categories();
    food = categories.singleWhere((c) => c.name == 'Food').id;
    salary = categories.singleWhere((c) => c.name == 'Salary').id;
  });
  tearDown(() => db.close());

  test(
    'month snapshot counts only real expenses in local calendar month',
    () async {
      await budgets.save(
        categoryId: food,
        baseAmountMinor: 10000,
        month: DateTime(2026, 2, 18),
        rolloverEnabled: false,
        alert80Enabled: true,
        alert100Enabled: true,
      );
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 8000,
        accountId: account,
        categoryId: food,
        occurredAt: DateTime(2026, 2, 28, 23, 59),
      );
      await money.saveTransaction(
        type: MoneyType.income,
        amountMinor: 50000,
        accountId: account,
        categoryId: salary,
        occurredAt: DateTime(2026, 2, 10),
      );
      await money.saveTransaction(
        type: MoneyType.transfer,
        amountMinor: 1000,
        accountId: account,
        destinationAccountId: destination,
        occurredAt: DateTime(2026, 2, 11),
      );
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 500,
        accountId: account,
        categoryId: food,
        occurredAt: DateTime(2026, 3, 1),
      );
      final snapshot = await budgets.snapshot(DateTime(2026, 2, 1));
      expect(snapshot.lines.single.spentMinor, 8000);
      expect(snapshot.lines.single.remainingMinor, 2000);
      expect(snapshot.lines.single.utilization, .8);
      expect(snapshot.allExpenseMinor, 8000);
      expect(snapshot.alerts.map((a) => a.threshold), [80]);
    },
  );

  test('duplicate and invalid budgets are rejected; edit and delete preserve ledger', () async {
    await expectLater(
      budgets.save(
        categoryId: food,
        baseAmountMinor: 0,
        month: DateTime(2026, 1),
        rolloverEnabled: false,
        alert80Enabled: true,
        alert100Enabled: true,
      ),
      throwsArgumentError,
    );
    await budgets.save(
      categoryId: food,
      baseAmountMinor: 12000,
      month: DateTime(2026, 1),
      rolloverEnabled: false,
      alert80Enabled: true,
      alert100Enabled: true,
    );
    await expectLater(
      budgets.save(
        categoryId: food,
        baseAmountMinor: 13000,
        month: DateTime(2026, 1, 20),
        rolloverEnabled: false,
        alert80Enabled: true,
        alert100Enabled: true,
      ),
      throwsArgumentError,
    );
    await money.saveTransaction(
      type: MoneyType.expense,
      amountMinor: 900,
      accountId: account,
      categoryId: food,
      occurredAt: DateTime(2026, 1, 4),
    );
    final tx = (await money.transactions()).single;
    final plan = (await budgets.plans()).single;
    await budgets.save(
      id: plan.id,
      categoryId: food,
      baseAmountMinor: 15000,
      month: DateTime(2026, 1),
      rolloverEnabled: false,
      alert80Enabled: true,
      alert100Enabled: true,
    );
    expect(
      (await budgets.snapshot(DateTime(2026, 1)))
          .lines
          .single
          .plan
          .baseAmountMinor,
      15000,
    );
    await budgets.delete(plan.id);
    expect(await money.transactions(), [tx]);
  });

  test('threshold alerts persist once and can retrigger after spending falls below', () async {
    await budgets.save(
      categoryId: food,
      baseAmountMinor: 5000,
      month: DateTime(2026, 5),
      rolloverEnabled: false,
      alert80Enabled: true,
      alert100Enabled: true,
    );
    await money.saveTransaction(
      type: MoneyType.expense,
      amountMinor: 4000,
      accountId: account,
      categoryId: food,
      occurredAt: DateTime(2026, 5, 1),
    );
    expect(
      (await budgets.snapshot(DateTime(2026, 5))).alerts
          .map((a) => a.threshold),
      [80],
    );
    expect((await budgets.snapshot(DateTime(2026, 5))).alerts, isEmpty);
    await money.saveTransaction(
      type: MoneyType.expense,
      amountMinor: 1000,
      accountId: account,
      categoryId: food,
      occurredAt: DateTime(2026, 5, 2),
    );
    expect(
      (await budgets.snapshot(DateTime(2026, 5))).alerts
          .map((a) => a.threshold),
      [100],
    );
    await money.saveTransaction(
      type: MoneyType.expense,
      amountMinor: 100,
      accountId: account,
      categoryId: food,
      occurredAt: DateTime(2026, 5, 3),
    );
    final exceeded = await budgets.snapshot(DateTime(2026, 5));
    expect(exceeded.lines.single.status, 'Exceeded');
    expect(exceeded.lines.single.remainingMinor, -100);
    final txs = await money.transactions(type: 'expense');
    final originalLarge = txs.singleWhere((tx) => tx.amountMinor == 4000);
    await money.saveTransaction(
      id: originalLarge.id,
      type: MoneyType.expense,
      amountMinor: 2500,
      accountId: account,
      categoryId: food,
      occurredAt: originalLarge.occurredAt,
    );
    expect((await budgets.snapshot(DateTime(2026, 5))).alerts, isEmpty);
    final edited = await money.transactions(type: 'expense');
    final previousLarge = edited.singleWhere((tx) => tx.amountMinor == 2500);
    await money.saveTransaction(
      id: previousLarge.id,
      type: MoneyType.expense,
      amountMinor: 3100,
      accountId: account,
      categoryId: food,
      occurredAt: previousLarge.occurredAt,
    );
    expect(
      (await budgets.snapshot(DateTime(2026, 5))).alerts
          .map((a) => a.threshold),
      [80],
    );
  });

  test(
    'positive rollover is transparent and negative deficit is not carried',
    () async {
      await budgets.save(
        categoryId: food,
        baseAmountMinor: 4000,
        month: DateTime(2026, 6),
        rolloverEnabled: true,
        alert80Enabled: false,
        alert100Enabled: false,
      );
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 3500,
        accountId: account,
        categoryId: food,
        occurredAt: DateTime(2026, 6, 18),
      );
      await budgets.save(
        categoryId: food,
        baseAmountMinor: 4000,
        month: DateTime(2026, 7),
        rolloverEnabled: false,
        alert80Enabled: false,
        alert100Enabled: false,
      );
      var july = await budgets.snapshot(DateTime(2026, 7));
      expect(july.lines.single.carryMinor, 500);
      expect(july.lines.single.effectiveMinor, 4500);
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 5000,
        accountId: account,
        categoryId: food,
        occurredAt: DateTime(2026, 7, 20),
      );
      await budgets.save(
        categoryId: food,
        baseAmountMinor: 4000,
        month: DateTime(2026, 8),
        rolloverEnabled: false,
        alert80Enabled: false,
        alert100Enabled: false,
      );
      final august = await budgets.snapshot(DateTime(2026, 8));
      expect(august.lines.single.carryMinor, 0);
      expect(august.lines.single.effectiveMinor, 4000);
    },
  );

  test(
    'monthly comparison reports category changes and zero baseline safely',
    () async {
      final groceries = (await money.categories())
          .singleWhere((category) => category.name == 'Groceries')
          .id;
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 1000,
        accountId: account,
        categoryId: food,
        occurredAt: DateTime(2026, 3, 2),
      );
      await money.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 2000,
        accountId: account,
        categoryId: groceries,
        occurredAt: DateTime(2026, 3, 3),
      );
      final march = await budgets.snapshot(DateTime(2026, 3));
      final february = await budgets.snapshot(DateTime(2026, 2));
      final comparison = compareBudgetMonths(march, february);
      expect(comparison.spendingChangeMinor, 3000);
      expect(comparison.spendingChangePercent, isNull);
      expect(comparison.categories, hasLength(2));
      expect(comparison.categories.first.categoryId, groceries);
    },
  );

  test('schema version 1 migrates without changing ledger rows', () async {
    final directory = await Directory.systemTemp.createTemp('budget_migration');
    final path = p.join(directory.path, 'money.sqlite');
    try {
      var fileDb = MoneyDatabase(NativeDatabase(File(path)));
      final fileMoney = MoneyRepository(fileDb);
      await fileMoney.seedDefaults();
      await fileMoney.saveAccount(
        name: 'Kept account',
        type: AccountType.bank,
        openingBalanceMinor: 12345,
      );
      final fileAccount = (await fileMoney.accounts()).single.id;
      final fileFood = (await fileMoney.categories())
          .singleWhere((category) => category.name == 'Food')
          .id;
      await fileMoney.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 900,
        accountId: fileAccount,
        categoryId: fileFood,
        occurredAt: DateTime(2026, 4, 3),
      );
      await fileDb.customStatement('DROP TABLE budget_alert_states');
      await fileDb.customStatement('DROP TABLE budget_plans');
      await fileDb.customStatement('PRAGMA user_version = 1');
      await fileDb.close();

      fileDb = MoneyDatabase(NativeDatabase(File(path)));
      final migratedMoney = MoneyRepository(fileDb);
      final migratedBudgets = BudgetRepository(fileDb, migratedMoney);
      expect(
        (await migratedMoney.accounts()).single.openingBalanceMinor,
        12345,
      );
      expect((await migratedMoney.transactions()).single.amountMinor, 900);
      expect(await migratedBudgets.plans(), isEmpty);
      await migratedBudgets.save(
        categoryId: fileFood,
        baseAmountMinor: 3000,
        month: DateTime(2026, 4),
        rolloverEnabled: false,
        alert80Enabled: true,
        alert100Enabled: true,
      );
      expect((await migratedBudgets.plans()).single.baseAmountMinor, 3000);
      await fileDb.close();
    } finally {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Windows may release SQLite handles at test process exit.
      }
    }
  });

  test(
    'Riverpod budget snapshot provider loads from the shared ledger',
    () async {
      final container = ProviderContainer(
        overrides: [moneyDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final snapshot = await container
          .read(budgetMonthProvider(DateTime(2026, 10)).future)
          .timeout(const Duration(seconds: 5));
      expect(snapshot.month, DateTime(2026, 10));
      expect(snapshot.lines, isEmpty);
    },
  );
}
