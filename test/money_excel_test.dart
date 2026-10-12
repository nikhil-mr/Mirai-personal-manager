import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_excel_service.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';

void main() {
  late MoneyDatabase db;
  late MoneyRepository repository;

  setUp(() {
    db = MoneyDatabase(NativeDatabase.memory());
    repository = MoneyRepository(db);
  });
  tearDown(() => db.close());

  test('detects headers on row two and skips the report title', () async {
    final preview = MoneyExcelService().parse(_sampleWorkbook());
    expect(preview.rows, hasLength(1));
    expect(preview.rows.single.valid, isTrue);
    expect(preview.rows.single.sourceRow, 3);
    expect(preview.rows.single.type, MoneyType.expense);
    expect(preview.rows.single.account, 'HDFC BANK');
    expect(preview.rows.single.category, 'Groceries');
    expect(preview.rows.single.date, DateTime(2024, 1, 16, 18, 45));
    expect(preview.rows.single.amountMinor, 12345);
    final result = await repository.importTransactions(
      preview.rows.map((row) => row.toRecord()).toList(),
    );
    expect(result.expensesImported, 1);
    expect(result.accountsCreated, 1);
    expect(result.categoriesCreated, 1);
    final account = (await repository.accounts()).single;
    final category = (await repository.categories()).single;
    final transaction = (await repository.transactions()).single;
    expect(account.openingBalanceMinor, 0);
    expect(category.name, 'Groceries');
    expect(category.type, 'expense');
    expect(transaction.accountId, account.id);
    expect(transaction.categoryId, category.id);
    expect(transaction.occurredAt, DateTime(2024, 1, 16, 18, 45));
  });

  test('imports income as income even when source amount is negative', () {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Income');
    final sheet = workbook['Income'];
    _write(sheet, 0, 0, TextCellValue('Monthly report'));
    _writeRow(sheet, 1, [
      'Date and time',
      'Category',
      'Account',
      'Amount in default currency',
      'Default currency',
      'Amount in account currency',
      'Account currency',
      'Transaction amount in transaction currency',
      'Transaction currency',
      'Tags',
      'Comment',
    ]);
    _writeRow(sheet, 2, [
      DateTimeCellValue.fromDateTime(DateTime(2023, 7, 5, 9, 15)),
      TextCellValue('Paycheck'),
      TextCellValue('Salary account'),
      DoubleCellValue(-2500),
      TextCellValue('INR'),
      DoubleCellValue(-2500),
      TextCellValue('INR'),
      DoubleCellValue(-2500),
      TextCellValue('INR'),
      TextCellValue(''),
      TextCellValue('July salary'),
    ]);
    final row = MoneyExcelService().parse(workbook.encode()!).rows.single;
    expect(row.type, MoneyType.income);
    expect(row.amountMinor, 250000);
    expect(row.valid, isTrue);
  });

  test('reads Excel serial dates with fractional time', () {
    final row = MoneyExcelService()
        .parse(_sampleWorkbook(date: DoubleCellValue(45292.25)))
        .rows
        .single;
    expect(row.date, DateTime(2024, 1, 1, 6));
  });

  test('recognizes mixed transaction types on one worksheet', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];
    _writeRow(sheet, 0, [
      'Transaction Type',
      'Date',
      'Source Account',
      'Destination Account',
      'Category',
      'Amount',
      'Currency',
      'Comment',
    ]);
    _writeRow(sheet, 1, [
      TextCellValue('Expense'),
      DateTimeCellValue.fromDateTime(DateTime(2025, 1, 2)),
      TextCellValue('Cash'),
      TextCellValue(''),
      TextCellValue('Cafe'),
      DoubleCellValue(10.5),
      TextCellValue('INR'),
      TextCellValue('Coffee'),
    ]);
    _writeRow(sheet, 2, [
      TextCellValue('Income'),
      DateTimeCellValue.fromDateTime(DateTime(2025, 1, 3)),
      TextCellValue('Bank'),
      TextCellValue(''),
      TextCellValue('Gift'),
      DoubleCellValue(-25),
      TextCellValue('INR'),
      TextCellValue('Gift'),
    ]);
    _writeRow(sheet, 3, [
      TextCellValue('Transfer'),
      DateTimeCellValue.fromDateTime(DateTime(2025, 1, 4)),
      TextCellValue('Cash'),
      TextCellValue('Bank'),
      TextCellValue(''),
      DoubleCellValue(20),
      TextCellValue('INR'),
      TextCellValue('Move'),
    ]);
    final preview = MoneyExcelService().parse(workbook.encode()!);
    expect(preview.rows, hasLength(3));
    expect(preview.rows.map((row) => row.type), [
      MoneyType.expense,
      MoneyType.income,
      MoneyType.transfer,
    ]);
    expect(preview.rows.every((row) => row.valid), isTrue);
  });

  test('flags inconsistent INR amount columns for review', () {
    final row = MoneyExcelService()
        .parse(_sampleWorkbook(accountAmount: 130))
        .rows
        .single;
    expect(row.valid, isFalse);
    expect(row.issue, contains('INR amount columns disagree'));
  });

  test('flags monetary precision beyond paise', () {
    final row = MoneyExcelService()
        .parse(_sampleWorkbook(defaultAmount: DoubleCellValue(123.456)))
        .rows
        .single;
    expect(row.valid, isFalse);
    expect(row.issue, contains('more than two decimal places'));
  });

  test('a reviewed correction repairs an invalid source row', () {
    final invalid = MoneyExcelService()
        .parse(_sampleWorkbook(date: TextCellValue('02/03/2024')))
        .rows
        .single;
    final corrected = invalid.corrected(
      correctedType: MoneyType.expense,
      correctedDate: DateTime(2024, 3, 2, 14, 30),
      correctedAmountMinor: 999,
      correctedAccount: 'Cash',
      correctedDestination: null,
      correctedCategory: 'Cafe',
      correctedNote: 'Reviewed row',
    );
    expect(corrected.valid, isTrue);
    expect(corrected.toRecord().occurredAt, DateTime(2024, 3, 2, 14, 30));
    expect(corrected.toRecord().amountMinor, 999);
    expect(corrected.toRecord().accountName, 'Cash');
  });

  test('imports a transfer as one record and creates both accounts', () async {
    final preview = MoneyExcelService().parse(_transferWorkbook());
    expect(preview.rows, hasLength(1));
    expect(preview.rows.single.type, MoneyType.transfer);
    expect(preview.rows.single.valid, isTrue);
    final result = await repository.importTransactions(
      preview.rows.map((row) => row.toRecord()).toList(),
    );
    expect(result.transfersImported, 1);
    expect(result.expensesImported, 0);
    expect(result.incomeImported, 0);
    expect(result.accountsCreated, 2);
    expect(await db.select(db.moneyTransactions).get(), hasLength(1));
    final balances = await repository.calculateBalances();
    expect(balances.values.fold<int>(0, (sum, amount) => sum + amount), 0);
  });

  test('does not import ambiguous text dates or non-INR rows', () {
    final preview = MoneyExcelService().parse(
      _sampleWorkbook(
        date: TextCellValue('02/03/2024'),
        defaultCurrency: TextCellValue('USD'),
        accountCurrency: TextCellValue('USD'),
        transactionCurrency: TextCellValue('USD'),
      ),
    );
    expect(preview.invalidCount, 1);
    expect(preview.rows.single.valid, isFalse);
    expect(preview.rows.single.issue, contains('Date'));
  });

  test(
    'flags unsupported original currencies even when default amount is INR',
    () {
      final row = MoneyExcelService()
          .parse(_sampleWorkbook(transactionCurrency: TextCellValue('USD')))
          .rows
          .single;
      expect(row.valid, isFalse);
      expect(row.issue, contains('Foreign-currency values'));
    },
  );

  test(
    'reuses names case-insensitively and skips workbook reimports',
    () async {
      await repository.saveAccount(
        name: 'hdfc bank',
        type: AccountType.bank,
        openingBalanceMinor: 0,
      );
      await repository.saveCategory(
        name: 'groceries',
        type: 'expense',
        icon: 1,
        color: 2,
      );
      final record = MoneyExcelService()
          .parse(_sampleWorkbook())
          .rows
          .single
          .toRecord();
      final first = await repository.importTransactions([record]);
      final second = await repository.importTransactions([record]);
      expect(first.accountsCreated, 0);
      expect(first.categoriesCreated, 0);
      expect(second.expensesImported, 0);
      expect(second.duplicatesSkipped, 1);
      expect(await db.select(db.moneyTransactions).get(), hasLength(1));
      expect(
        (await repository.accounts()).where(
          (row) => row.name.toLowerCase() == 'hdfc bank',
        ),
        hasLength(1),
      );
    },
  );

  test('skips an exact match already entered manually', () async {
    await repository.saveAccount(
      name: 'HDFC BANK',
      type: AccountType.bank,
      openingBalanceMinor: 0,
    );
    await repository.saveCategory(
      name: 'Groceries',
      type: 'expense',
      icon: 1,
      color: 2,
    );
    final account = (await repository.accounts()).single;
    final category = (await repository.categories()).single;
    final source = MoneyExcelService().parse(_sampleWorkbook()).rows.single;
    await repository.saveTransaction(
      type: MoneyType.expense,
      amountMinor: source.amountMinor!,
      accountId: account.id,
      categoryId: category.id,
      occurredAt: source.date!,
      note: source.note,
    );
    final result = await repository.importTransactions([source.toRecord()]);
    expect(result.duplicatesSkipped, 1);
    expect(result.expensesImported, 0);
    expect(await db.select(db.moneyTransactions).get(), hasLength(1));
  });

  test(
    'rolls back new entities if any row cannot be safely committed',
    () async {
      await repository.saveAccount(
        name: 'Archived',
        type: AccountType.bank,
        openingBalanceMinor: 0,
      );
      final archived = (await repository.accounts()).single;
      await repository.archiveAccount(archived.id, archive: true);
      final good = MoneyExcelService()
          .parse(_sampleWorkbook())
          .rows
          .single
          .toRecord();
      final bad = MoneyImportRecord(
        type: MoneyType.expense,
        occurredAt: good.occurredAt,
        amountMinor: 500,
        accountName: 'Archived',
        categoryName: 'Food',
        note: '',
        fingerprint: 'blocked',
      );
      await expectLater(
        repository.importTransactions([good, bad]),
        throwsStateError,
      );
      expect(
        (await repository.accounts()).any((row) => row.name == 'HDFC BANK'),
        isFalse,
      );
      expect(await db.select(db.moneyTransactions).get(), isEmpty);
    },
  );

  test('exported three-sheet workbook can be parsed back', () async {
    final preview = MoneyExcelService().parse(_sampleWorkbook());
    await repository.importTransactions([
      ...preview.rows.map((row) => row.toRecord()),
      ...MoneyExcelService()
          .parse(_transferWorkbook())
          .rows
          .map((row) => row.toRecord()),
    ]);
    final bytes = MoneyExcelService().export(
      accounts: await repository.accounts(includeArchived: true),
      categories: await repository.categories(includeArchived: true),
      transactions: await repository.transactions(),
    );
    final roundTrip = MoneyExcelService().parse(bytes);
    expect(roundTrip.rows, hasLength(2));
    expect(
      roundTrip.rows.where((row) => row.type == MoneyType.expense),
      hasLength(1),
    );
    expect(
      roundTrip.rows.where((row) => row.type == MoneyType.transfer),
      hasLength(1),
    );
    expect(roundTrip.rows.every((row) => row.valid), isTrue);
    expect(
      roundTrip.rows.map((row) => row.amountMinor),
      containsAll([12345, 8000]),
    );
  });
}

List<int> _sampleWorkbook({
  CellValue? date,
  CellValue? defaultAmount,
  double accountAmount = 123.45,
  CellValue? defaultCurrency,
  CellValue? accountCurrency,
  CellValue? transactionCurrency,
}) {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Expenses');
  final sheet = workbook['Expenses'];
  _write(sheet, 0, 0, TextCellValue('Expense report'));
  _writeRow(sheet, 1, [
    'Date and time',
    'Category',
    'Account',
    'Amount in default currency',
    'Default currency',
    'Amount in account currency',
    'Account currency',
    'Transaction amount in transaction currency',
    'Transaction currency',
    'Tags',
    'Comment',
  ]);
  _writeRow(sheet, 2, [
    date ?? DateTimeCellValue.fromDateTime(DateTime(2024, 1, 16, 18, 45)),
    TextCellValue('Groceries'),
    TextCellValue('HDFC BANK'),
    defaultAmount ?? DoubleCellValue(123.45),
    defaultCurrency ?? TextCellValue('INR'),
    DoubleCellValue(accountAmount),
    accountCurrency ?? TextCellValue('INR'),
    DoubleCellValue(123.45),
    transactionCurrency ?? TextCellValue('INR'),
    TextCellValue('home'),
    TextCellValue('Weekly supplies'),
  ]);
  return workbook.encode()!;
}

List<int> _transferWorkbook() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Transfers');
  final sheet = workbook['Transfers'];
  _write(sheet, 0, 0, TextCellValue('Transfer report'));
  _writeRow(sheet, 1, [
    'Date and time',
    'Outgoing',
    'Incoming',
    'Amount in outgoing currency',
    'Outgoing currency',
    'Amount in incoming currency',
    'Incoming currency',
    'Comment',
  ]);
  _writeRow(sheet, 2, [
    DateTimeCellValue.fromDateTime(DateTime(2022, 12, 1, 13, 20)),
    TextCellValue('Cash'),
    TextCellValue('Bank'),
    DoubleCellValue(80),
    TextCellValue('INR'),
    DoubleCellValue(80),
    TextCellValue('INR'),
    TextCellValue('Move savings'),
  ]);
  return workbook.encode()!;
}

void _writeRow(Sheet sheet, int row, List<Object> values) {
  for (var col = 0; col < values.length; col++) {
    _write(
      sheet,
      col,
      row,
      values[col] is CellValue
          ? values[col] as CellValue
          : TextCellValue(values[col].toString()),
    );
  }
}

void _write(Sheet sheet, int col, int row, CellValue value) {
  sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value =
      value;
}
