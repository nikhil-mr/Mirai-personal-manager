import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';
import 'package:personal_manager/features/today/data/today_dashboard_repository.dart';

void main() {
  late MoneyDatabase database;
  late MoneyRepository repository;
  late String accountA;
  late String accountB;
  late String foodCategory;
  late String salaryCategory;

  setUp(() async {
    database = MoneyDatabase(NativeDatabase.memory());
    repository = MoneyRepository(database);
    await repository.seedDefaults();
    await repository.saveAccount(
      name: 'Everyday',
      type: AccountType.bank,
      openingBalanceMinor: 100000,
    );
    await repository.saveAccount(
      name: 'Cash',
      type: AccountType.cash,
      openingBalanceMinor: 5000,
    );
    final accounts = await repository.accounts();
    accountA = accounts.singleWhere((a) => a.name == 'Everyday').id;
    accountB = accounts.singleWhere((a) => a.name == 'Cash').id;
    final categories = await repository.categories();
    foodCategory = categories.singleWhere((c) => c.name == 'Food').id;
    salaryCategory = categories.singleWhere((c) => c.name == 'Salary').id;
  });

  tearDown(() async => database.close());

  test('paise parser preserves decimal precision', () {
    expect(parseMinorUnits('0.10')! + parseMinorUnits('0.20')!, 30);
    expect(parseMinorUnits('1,234.56'), 123456);
    expect(parseMinorUnits('1.234'), isNull);
    expect(formatMinorUnits(123456), '₹1,234.56');
    expect(formatMinorUnits(123456789), '₹12,34,567.89');
  });

  test('period ranges use local calendar boundaries', () {
    final day = MoneyRange.forPeriod(
      MoneyPeriod.day,
      DateTime(2026, 10, 10, 23),
    );
    expect(day.start, DateTime(2026, 10, 10));
    expect(day.end, DateTime(2026, 10, 11));
    final month = MoneyRange.forPeriod(
      MoneyPeriod.month,
      DateTime(2026, 10, 20),
    );
    expect(month.start, DateTime(2026, 10));
    expect(month.end, DateTime(2026, 11));
    final year = MoneyRange.forPeriod(MoneyPeriod.year, DateTime(2026, 10, 20));
    expect(year.end, DateTime(2027));
  });

  test(
    'accounts calculate opening balance, income, expense and edit effects',
    () async {
      final date = DateTime(2026, 10, 10, 10);
      await repository.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 1250,
        accountId: accountA,
        categoryId: foodCategory,
        occurredAt: date,
      );
      await repository.saveTransaction(
        type: MoneyType.income,
        amountMinor: 50000,
        accountId: accountA,
        categoryId: salaryCategory,
        occurredAt: date,
      );
      final expense = (await repository.transactions()).firstWhere(
        (t) => t.type == 'expense',
      );
      expect((await repository.calculateBalances())[accountA], 148750);
      await repository.saveTransaction(
        id: expense.id,
        type: MoneyType.expense,
        amountMinor: 2000,
        accountId: accountB,
        categoryId: foodCategory,
        occurredAt: date.add(const Duration(days: 1)),
      );
      final balances = await repository.calculateBalances();
      expect(balances[accountA], 150000);
      expect(balances[accountB], 3000);
      expect(
        (await repository.transactions(
          start: date,
          end: date.add(const Duration(days: 1)),
        )).where((t) => t.type == 'income').length,
        1,
      );
    },
  );

  test('transfer is one record, keeps combined balance and is excluded from totals', () async {
    final before = (await repository.calculateBalances()).values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    await repository.saveTransaction(
      type: MoneyType.transfer,
      amountMinor: 2500,
      accountId: accountA,
      destinationAccountId: accountB,
      occurredAt: DateTime(2026, 10, 10),
    );
    var entries = await repository.transactions();
    expect(entries, hasLength(1));
    expect(entries.single.type, 'transfer');
    var balances = await repository.calculateBalances();
    expect(balances[accountA], 97500);
    expect(balances[accountB], 7500);
    expect(balances.values.fold<int>(0, (sum, value) => sum + value), before);
    await repository.saveTransaction(
      id: entries.single.id,
      type: MoneyType.transfer,
      amountMinor: 1000,
      accountId: accountB,
      destinationAccountId: accountA,
      occurredAt: DateTime(2026, 10, 11),
    );
    entries = await repository.transactions();
    expect(entries, hasLength(1));
    balances = await repository.calculateBalances();
    expect(balances[accountA], 101000);
    expect(balances[accountB], 4000);
    await repository.deleteTransaction(entries.single.id);
    expect((await repository.calculateBalances())[accountA], 100000);
  });

  test(
    'Today dashboard reads the same daily ledger and excludes transfers',
    () async {
      final today = DateTime.now();
      await repository.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 1234,
        accountId: accountA,
        categoryId: foodCategory,
        occurredAt: today,
      );
      await repository.saveTransaction(
        type: MoneyType.income,
        amountMinor: 5000,
        accountId: accountA,
        categoryId: salaryCategory,
        occurredAt: today,
      );
      await repository.saveTransaction(
        type: MoneyType.transfer,
        amountMinor: 1000,
        accountId: accountA,
        destinationAccountId: accountB,
        occurredAt: today,
      );
      final snapshot = await MoneyTodayDashboardRepository(repository)
          .loadForDay(today);
      expect(snapshot.money?.spending, 12.34);
      expect(snapshot.money?.income, 50);
      expect(snapshot.money?.currencyCode, 'INR');
    },
  );

  test('same-account transfer and zero amounts are rejected', () async {
    await expectLater(
      repository.saveTransaction(
        type: MoneyType.transfer,
        amountMinor: 100,
        accountId: accountA,
        destinationAccountId: accountA,
        occurredAt: DateTime.now(),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.saveTransaction(
        type: MoneyType.expense,
        amountMinor: 0,
        accountId: accountA,
        categoryId: foodCategory,
        occurredAt: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });

  test('archived accounts remain in history and balance but cannot receive new entries', () async {
    await repository.archiveAccount(accountA, archive: true);
    expect(
      (await repository.accounts()).map((a) => a.id),
      isNot(contains(accountA)),
    );
    expect((await repository.calculateBalances())[accountA], 100000);
    await expectLater(
      repository.saveTransaction(
        type: MoneyType.income,
        amountMinor: 10,
        accountId: accountA,
        categoryId: salaryCategory,
        occurredAt: DateTime.now(),
      ),
      throwsArgumentError,
    );
    await repository.archiveAccount(accountA, archive: false);
    expect((await repository.accounts()).map((a) => a.id), contains(accountA));
  });

  test('database retains ledger rows when reopened', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life_partner_money_test',
    );
    final path = p.join(directory.path, 'money.sqlite');
    try {
      var fileDb = MoneyDatabase(NativeDatabase(File(path)));
      var fileRepository = MoneyRepository(fileDb);
      await fileRepository.seedDefaults();
      await fileRepository.saveAccount(
        name: 'Persistent',
        type: AccountType.bank,
        openingBalanceMinor: 12345,
      );
      await fileDb.close();
      fileDb = MoneyDatabase(NativeDatabase(File(path)));
      fileRepository = MoneyRepository(fileDb);
      expect(
        (await fileRepository.accounts()).single.openingBalanceMinor,
        12345,
      );
      await fileDb.close();
    } finally {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Windows can release SQLite's file handle when the test process exits.
      }
    }
  });
}
