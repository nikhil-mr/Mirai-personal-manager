import 'dart:convert';

import 'package:excel/excel.dart';

import '../domain/money_models.dart';
import 'money_database.dart';

class MoneyExcelImportRow {
  MoneyExcelImportRow({
    required this.sheet,
    required this.sourceRow,
    required this.type,
    required this.date,
    required this.amountMinor,
    required this.account,
    required this.destination,
    required this.category,
    required this.note,
    required this.fingerprint,
    required this.issue,
  });

  final String sheet;
  final int sourceRow;
  final MoneyType? type;
  final DateTime? date;
  final int? amountMinor;
  final String account;
  final String? destination;
  final String? category;
  final String note;
  final String fingerprint;
  final String? issue;

  bool get valid =>
      issue == null &&
      type != null &&
      date != null &&
      amountMinor != null &&
      account.isNotEmpty &&
      (type == MoneyType.transfer
          ? destination != null && destination!.isNotEmpty
          : category != null && category!.isNotEmpty);

  MoneyExcelImportRow corrected({
    required MoneyType correctedType,
    required DateTime correctedDate,
    required int correctedAmountMinor,
    required String correctedAccount,
    required String? correctedDestination,
    required String? correctedCategory,
    required String correctedNote,
  }) {
    final fingerprintText = [
      correctedType.name,
      correctedDate.toIso8601String(),
      correctedAmountMinor.toString(),
      correctedAccount.trim().toLowerCase(),
      correctedDestination?.trim().toLowerCase() ?? '',
      correctedCategory?.trim().toLowerCase() ?? '',
      correctedNote.trim(),
    ].join('\u001f');
    return MoneyExcelImportRow(
      sheet: sheet,
      sourceRow: sourceRow,
      type: correctedType,
      date: correctedDate,
      amountMinor: correctedAmountMinor,
      account: correctedAccount.trim(),
      destination: correctedType == MoneyType.transfer
          ? correctedDestination?.trim()
          : null,
      category: correctedType == MoneyType.transfer
          ? null
          : correctedCategory?.trim(),
      note: correctedNote.trim(),
      fingerprint: base64Url.encode(
        utf8.encode('manual:$sheet:$sourceRow:$fingerprintText'),
      ),
      issue: null,
    );
  }

  MoneyImportRecord toRecord() => MoneyImportRecord(
    type: type!,
    occurredAt: date!,
    amountMinor: amountMinor!,
    accountName: account,
    destinationAccountName: destination,
    categoryName: category,
    note: note,
    fingerprint: fingerprint,
  );
}

class MoneyExcelPreview {
  const MoneyExcelPreview(
    this.rows,
    this.sheets, {
    this.detectedHeaders = const {},
    this.rowCounts = const {},
  });
  final List<MoneyExcelImportRow> rows;
  final List<String> sheets;
  final Map<String, List<String>> detectedHeaders;
  final Map<String, int> rowCounts;

  int get validCount => rows.where((row) => row.valid).length;
  int get invalidCount => rows.length - validCount;
}

/// Reads the user's three-sheet report format and recognizable mixed sheets.
/// The Money model stores one currency per amount; non-INR and foreign exchange
/// rows are explicitly marked for review instead of being converted silently.
class MoneyExcelService {
  static DateTime? parseDateText(String value) => _date(TextCellValue(value));

  MoneyExcelPreview parse(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final rows = <MoneyExcelImportRow>[];
    final fingerprintOccurrences = <String, int>{};
    final unsupportedDataSheets = <String>[];
    final detectedHeaders = <String, List<String>>{};
    final rowCounts = <String, int>{};
    final sheets = workbook.tables.keys.toList(growable: false);
    for (final sheetName in sheets) {
      final sheet = workbook.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;
      final normalizedSheet = sheetName.trim().toLowerCase();
      final fixedType = switch (normalizedSheet) {
        'expenses' => MoneyType.expense,
        'income' => MoneyType.income,
        'transfers' => MoneyType.transfer,
        _ => null,
      };
      final headerIndex = _findHeader(sheet.rows, fixedType);
      if (headerIndex == null) {
        if (sheet.rows
            .skip(1)
            .any(
              (row) => row.any((cell) => _cellText(cell?.value).isNotEmpty),
            )) {
          unsupportedDataSheets.add(sheetName);
        }
        continue;
      }
      final headers = <String, List<int>>{};
      detectedHeaders[sheetName] = sheet.rows[headerIndex]
          .map((cell) => _cellText(cell?.value).trim())
          .where((value) => value.isNotEmpty)
          .toList();
      rowCounts[sheetName] = 0;
      for (var i = 0; i < sheet.rows[headerIndex].length; i++) {
        final value = _cellText(sheet.rows[headerIndex][i]?.value);
        if (value.isNotEmpty) {
          headers.putIfAbsent(_normalize(value), () => []).add(i);
        }
      }
      for (
        var rowIndex = headerIndex + 1;
        rowIndex < sheet.rows.length;
        rowIndex++
      ) {
        final cells = sheet.rows[rowIndex];
        if (cells.every((cell) => _cellText(cell?.value).isEmpty)) continue;
        rowCounts[sheetName] = rowCounts[sheetName]! + 1;
        final type =
            fixedType ??
            _mixedType(
              _cellText(
                _value(cells, _index(headers, ['type', 'transaction type'])),
              ),
            );
        final issue = <String>[];
        if (type == null) issue.add('Transaction type is missing or unclear.');
        final dateValue = _value(
          cells,
          _index(headers, const ['date and time', 'date', 'transaction date']),
        );
        final date = _date(dateValue);
        if (date == null) issue.add('Date is missing, invalid, or ambiguous.');

        final accountColumn = type == MoneyType.transfer
            ? _index(headers, const [
                'outgoing',
                'source account',
                'from account',
              ])
            : _index(headers, const [
                'account',
                'source account',
                'destination account',
              ]);
        final account = _cellText(_value(cells, accountColumn)).trim();
        if (account.isEmpty) issue.add('Account is missing.');

        String? destination;
        if (type == MoneyType.transfer) {
          destination = _cellText(
            _value(
              cells,
              _index(headers, const [
                'incoming',
                'destination account',
                'to account',
              ]),
            ),
          ).trim();
          if (destination.isEmpty) issue.add('Destination account is missing.');
          if (destination.toLowerCase() == account.toLowerCase()) {
            issue.add('A transfer needs two different accounts.');
          }
        }

        String? category;
        if (type != null && type != MoneyType.transfer) {
          category = _cellText(
            _value(cells, _index(headers, const ['category'])),
          ).trim();
          if (category.isEmpty) issue.add('Category is missing.');
        }

        final amountAndIssue = type == MoneyType.transfer
            ? _transferAmount(cells, headers)
            : _transactionAmount(cells, headers);
        if (amountAndIssue.$2 != null) issue.add(amountAndIssue.$2!);

        final comment = _cellText(
          _value(
            cells,
            _index(headers, const ['comment', 'description', 'notes']),
          ),
        ).trim();
        final tags = _cellText(_value(cells, _index(headers, const ['tags'])))
            .trim();
        final note = tags.isEmpty
            ? comment
            : comment.isEmpty
            ? 'Tags: $tags'
            : '$comment\nTags: $tags';
        final fingerprintBase = [
          type?.name ?? '',
          date?.toIso8601String() ?? '',
          amountAndIssue.$1?.toString() ?? '',
          account.toLowerCase(),
          destination?.toLowerCase() ?? '',
          category?.toLowerCase() ?? '',
          note,
        ].join('\u001f');
        final ordinal = fingerprintOccurrences.update(
          fingerprintBase,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        final fingerprint = base64Url.encode(
          utf8.encode('$fingerprintBase\u001f$ordinal'),
        );
        rows.add(
          MoneyExcelImportRow(
            sheet: sheetName,
            sourceRow: rowIndex + 1,
            type: type,
            date: date,
            amountMinor: amountAndIssue.$1,
            account: account,
            destination: destination,
            category: category,
            note: note,
            fingerprint: fingerprint,
            issue: issue.isEmpty ? null : issue.join(' '),
          ),
        );
      }
    }
    if (unsupportedDataSheets.isNotEmpty) {
      throw FormatException(
        'These non-empty worksheets could not be mapped safely: ${unsupportedDataSheets.join(', ')}. No rows were imported.',
      );
    }
    if (rows.isEmpty) {
      throw const FormatException(
        'No supported transaction sheets or recognizable column headers were found.',
      );
    }
    return MoneyExcelPreview(
      rows,
      sheets,
      detectedHeaders: detectedHeaders,
      rowCounts: rowCounts,
    );
  }

  int? _findHeader(List<List<Data?>> rows, MoneyType? type) {
    for (var row = 0; row < rows.length && row < 8; row++) {
      final headers = rows[row]
          .map((cell) => _normalize(_cellText(cell?.value)))
          .toSet();
      final isTransfer = type == MoneyType.transfer;
      if (headers.contains('date and time') &&
          (isTransfer
              ? headers.contains('outgoing') && headers.contains('incoming')
              : headers.contains('category') && headers.contains('account'))) {
        return row;
      }
      if (type == null &&
          (headers.contains('type') || headers.contains('transaction type')) &&
          (headers.contains('date') ||
              headers.contains('date and time') ||
              headers.contains('transaction date') ||
              headers.contains('occurred at'))) {
        return row;
      }
    }
    return null;
  }

  (int?, String?) _transactionAmount(
    List<Data?> row,
    Map<String, List<int>> headers,
  ) {
    final candidates = <({String amount, String currency})>[
      (amount: 'amount in default currency', currency: 'default currency'),
      (amount: 'amount in account currency', currency: 'account currency'),
      (
        amount: 'transaction amount in transaction currency',
        currency: 'transaction currency',
      ),
    ];
    final supported = <int>[];
    var hasAmount = false;
    var invalidInrAmount = false;
    var hasForeignCurrencyAmount = false;
    for (final candidate in candidates) {
      final amountIndex = _index(headers, [candidate.amount]);
      if (amountIndex == null) continue;
      final rawAmount = _value(row, amountIndex);
      final parsed = _minor(rawAmount);
      if (rawAmount != null && _cellText(rawAmount).trim().isNotEmpty) {
        hasAmount = true;
      }
      final currencyIndex = _index(headers, [candidate.currency]);
      final currency = _cellText(_value(row, currencyIndex))
          .trim()
          .toUpperCase();
      final inrCurrency =
          currency.isEmpty || currency == 'INR' || currency == '₹';
      if (!inrCurrency &&
          rawAmount != null &&
          _cellText(rawAmount).trim().isNotEmpty) {
        hasForeignCurrencyAmount = true;
      }
      if (rawAmount != null &&
          _cellText(rawAmount).trim().isNotEmpty &&
          parsed == null &&
          inrCurrency) {
        invalidInrAmount = true;
      }
      if (parsed != null && inrCurrency) {
        supported.add(parsed.abs());
      }
    }
    if (invalidInrAmount) {
      return (
        null,
        'An INR amount has an invalid value or more than two decimal places.',
      );
    }
    if (hasForeignCurrencyAmount) {
      return (
        null,
        'Foreign-currency values cannot be preserved by the current INR-only Money model; row needs review.',
      );
    }
    if (supported.isEmpty) {
      final simpleAmountColumn = _index(headers, const [
        'amount',
        'transaction amount',
      ]);
      if (simpleAmountColumn != null) {
        final rawAmount = _value(row, simpleAmountColumn);
        final amount = _minor(rawAmount);
        final currency = _cellText(
          _value(row, _index(headers, const ['currency'])),
        ).trim().toUpperCase();
        final supportedCurrency =
            currency.isEmpty || currency == 'INR' || currency == '₹';
        if (rawAmount != null && _cellText(rawAmount).trim().isNotEmpty) {
          if (amount == null && supportedCurrency) {
            return (
              null,
              'Amount is invalid or has more than two decimal places.',
            );
          }
          if (!supportedCurrency) {
            return (
              null,
              'Foreign-currency amount needs review because this Money model stores INR only.',
            );
          }
        }
        if (amount != null && supportedCurrency) {
          return amount.abs() <= 0
              ? (null, 'Amount must be greater than zero.')
              : (amount.abs(), null);
        }
      }
      return (
        null,
        hasAmount
            ? 'Currency is not supported by the current INR-only Money model; row needs review.'
            : 'No valid monetary amount was found.',
      );
    }
    if (supported.any((amount) => amount != supported.first)) {
      return (null, 'INR amount columns disagree; row needs review.');
    }
    if (supported.first <= 0) {
      return (null, 'Amount must be greater than zero.');
    }
    return (supported.first, null);
  }

  (int?, String?) _transferAmount(
    List<Data?> row,
    Map<String, List<int>> headers,
  ) {
    final sourceCurrency = _cellText(
      _value(row, _index(headers, const ['outgoing currency', 'currency'])),
    ).trim().toUpperCase();
    final destinationCurrency = _cellText(
      _value(
        row,
        _index(headers, const ['incoming currency', 'destination currency']),
      ),
    ).trim().toUpperCase();
    if ((sourceCurrency.isNotEmpty &&
            sourceCurrency != 'INR' &&
            sourceCurrency != '₹') ||
        (destinationCurrency.isNotEmpty &&
            destinationCurrency != 'INR' &&
            destinationCurrency != '₹')) {
      return (
        null,
        'Foreign-currency transfers need review because account currencies and exchange rates are not represented.',
      );
    }
    final source = _minor(
      _value(
        row,
        _index(headers, const [
          'amount in outgoing currency',
          'source amount',
          'amount',
          'transaction amount',
        ]),
      ),
    );
    final incomingIndex = _index(headers, const [
      'amount in incoming currency',
      'destination amount',
    ]);
    final incoming = incomingIndex == null
        ? source
        : _minor(_value(row, incomingIndex));
    if (source == null || incoming == null || source <= 0 || incoming <= 0) {
      return (null, 'Transfer has a missing or invalid amount.');
    }
    if (sourceCurrency == destinationCurrency && source != incoming) {
      return (null, 'Transfer amounts differ despite matching currencies.');
    }
    if (source != incoming) {
      return (
        null,
        'Different source and destination amounts require an exchange rate the Money model cannot store.',
      );
    }
    return (source, null);
  }

  static int? _index(Map<String, List<int>> headers, List<String> names) {
    for (final name in names) {
      final matches = headers[_normalize(name)];
      if (matches?.length == 1) return matches!.single;
      if (matches != null && matches.length > 1) return null;
    }
    return null;
  }

  static Object? _value(List<Data?> row, int? index) =>
      index == null || index >= row.length ? null : row[index]?.value;

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _cellText(Object? value) => switch (value) {
    null => '',
    TextCellValue(:final value) => _textSpan(value),
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => value.toString(),
    BoolCellValue(:final value) => value.toString(),
    DateTimeCellValue(
      :final year,
      :final month,
      :final day,
      :final hour,
      :final minute,
      :final second,
    ) =>
      DateTime(year, month, day, hour, minute, second).toIso8601String(),
    DateCellValue(:final year, :final month, :final day) => DateTime(
      year,
      month,
      day,
    ).toIso8601String(),
    TimeCellValue(:final hour, :final minute, :final second) =>
      '$hour:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}',
    FormulaCellValue(:final formula) => formula,
    _ => value.toString(),
  };

  static String _textSpan(TextSpan value) =>
      '${value.text ?? ''}${value.children?.map(_textSpan).join() ?? ''}';

  static DateTime? _date(Object? value) {
    if (value is DateTimeCellValue) return value.asDateTimeLocal();
    if (value is DateCellValue) return value.asDateTimeLocal();
    if (value is IntCellValue || value is DoubleCellValue) {
      final serial = double.tryParse(_cellText(value));
      if (serial == null || serial < 1 || serial > 2958465) return null;
      final wholeDays = serial.floor();
      final milliseconds = ((serial - wholeDays) * Duration.millisecondsPerDay)
          .round();
      return DateTime(
        1899,
        12,
        30,
      ).add(Duration(days: wholeDays, milliseconds: milliseconds));
    }
    final text = _cellText(value).trim();
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    final match = RegExp(
      r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(text);
    if (match == null) return null;
    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    if (first <= 12 && second <= 12) return null;
    final day = first > 12 ? first : second;
    final month = first > 12 ? second : first;
    final result = DateTime(
      int.parse(match.group(3)!),
      month,
      day,
      int.tryParse(match.group(4) ?? '') ?? 0,
      int.tryParse(match.group(5) ?? '') ?? 0,
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
    if (result.year != int.parse(match.group(3)!) ||
        result.month != month ||
        result.day != day) {
      return null;
    }
    return result;
  }

  static int? _minor(Object? value) {
    if (value is IntCellValue) return value.value * 100;
    if (value is DoubleCellValue) {
      final scaled = value.value * 100;
      final rounded = scaled.round();
      if ((scaled - rounded).abs() > 0.000001) return null;
      return rounded;
    }
    return _decimalMinor(
      _cellText(value).trim().replaceAll(',', '').replaceAll('₹', '').trim(),
    );
  }

  static int? _decimalMinor(String text) {
    final match = RegExp(r'^([+-]?\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) return null;
    final whole = int.tryParse(match.group(1)!);
    if (whole == null) return null;
    final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
    return (whole < 0 ? whole * 100 - fraction : whole * 100 + fraction);
  }

  static MoneyType? _mixedType(String value) =>
      switch (value.trim().toLowerCase()) {
        'expense' || 'expenses' => MoneyType.expense,
        'income' || 'earnings' => MoneyType.income,
        'transfer' || 'transfers' => MoneyType.transfer,
        _ => null,
      };

  List<int> export({
    required List<MoneyAccount> accounts,
    required List<MoneyCategory> categories,
    required List<MoneyTransaction> transactions,
    DateTime? start,
    DateTime? end,
    Set<String>? accountIds,
    Set<MoneyType>? types,
  }) {
    final accountNames = {for (final row in accounts) row.id: row.name};
    final categoryNames = {for (final row in categories) row.id: row.name};
    final selected = transactions.where((row) {
      final type = MoneyType.values
          .where((value) => value.name == row.type)
          .firstOrNull;
      if (type == null || (types != null && !types.contains(type))) {
        return false;
      }
      if (start != null && row.occurredAt.isBefore(start)) return false;
      if (end != null && !row.occurredAt.isBefore(end)) return false;
      if (accountIds != null &&
          !accountIds.contains(row.accountId) &&
          !accountIds.contains(row.destinationAccountId)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Expenses');
    final expenseSheet = excel['Expenses'];
    final incomeSheet = excel['Income'];
    final transferSheet = excel['Transfers'];
    final transactionHeaders = [
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
    ];
    final transferHeaders = [
      'Date and time',
      'Outgoing',
      'Incoming',
      'Amount in outgoing currency',
      'Outgoing currency',
      'Amount in incoming currency',
      'Incoming currency',
      'Comment',
    ];
    void initialize(Sheet sheet, String title, List<String> headers) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        TextCellValue(title),
      );
      for (var col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FFE082'),
        );
        sheet.setColumnWidth(col, col == 0 ? 22 : 24);
      }
      sheet.setColumnWidth(headers.length - 1, 34);
    }

    initialize(expenseSheet, 'Mirai - Expenses', transactionHeaders);
    initialize(incomeSheet, 'Mirai - Income', transactionHeaders);
    initialize(transferSheet, 'Mirai - Transfers', transferHeaders);
    var expenseRow = 2;
    var incomeRow = 2;
    var transferRow = 2;
    void setCell(Sheet sheet, int col, int row, CellValue value) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
              .value =
          value;
    }

    void setDate(Sheet sheet, int row, DateTime value) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      cell.value = DateTimeCellValue.fromDateTime(value);
      cell.cellStyle = CellStyle(numberFormat: NumFormat.defaultDateTime);
    }

    void setAmount(Sheet sheet, int col, int row, int minor) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = DoubleCellValue(minor / 100);
      cell.cellStyle = CellStyle(numberFormat: NumFormat.standard_4);
    }

    for (final tx in selected) {
      switch (tx.type) {
        case 'expense':
        case 'income':
          final sheet = tx.type == 'expense' ? expenseSheet : incomeSheet;
          final row = tx.type == 'expense' ? expenseRow++ : incomeRow++;
          setDate(sheet, row, tx.occurredAt);
          setCell(
            sheet,
            1,
            row,
            TextCellValue(categoryNames[tx.categoryId] ?? ''),
          );
          setCell(
            sheet,
            2,
            row,
            TextCellValue(accountNames[tx.accountId] ?? ''),
          );
          setAmount(sheet, 3, row, tx.amountMinor);
          setCell(sheet, 4, row, TextCellValue('INR'));
          setAmount(sheet, 5, row, tx.amountMinor);
          setCell(sheet, 6, row, TextCellValue('INR'));
          setAmount(sheet, 7, row, tx.amountMinor);
          setCell(sheet, 8, row, TextCellValue('INR'));
          setCell(sheet, 9, row, TextCellValue(''));
          setCell(sheet, 10, row, TextCellValue(tx.note));
        case 'transfer':
          final row = transferRow++;
          setDate(transferSheet, row, tx.occurredAt);
          setCell(
            transferSheet,
            1,
            row,
            TextCellValue(accountNames[tx.accountId] ?? ''),
          );
          setCell(
            transferSheet,
            2,
            row,
            TextCellValue(accountNames[tx.destinationAccountId] ?? ''),
          );
          setAmount(transferSheet, 3, row, tx.amountMinor);
          setCell(transferSheet, 4, row, TextCellValue('INR'));
          setAmount(transferSheet, 5, row, tx.amountMinor);
          setCell(transferSheet, 6, row, TextCellValue('INR'));
          setCell(transferSheet, 7, row, TextCellValue(tx.note));
      }
    }
    return excel.encode() ??
        (throw StateError('Excel workbook generation failed.'));
  }
}
