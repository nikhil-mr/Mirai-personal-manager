import 'package:flutter/material.dart';

enum MoneyType { expense, income, transfer }

enum AccountType { bank, cash, other }

enum MoneyPeriod { day, week, month, year, custom }

/// One fully validated row prepared by the Excel import preview.
class MoneyImportRecord {
  const MoneyImportRecord({
    required this.type,
    required this.occurredAt,
    required this.amountMinor,
    required this.accountName,
    required this.categoryName,
    required this.note,
    this.destinationAccountName,
    required this.fingerprint,
  });

  final MoneyType type;
  final DateTime occurredAt;
  final int amountMinor;
  final String accountName;
  final String? destinationAccountName;
  final String? categoryName;
  final String note;
  final String fingerprint;
}

class MoneyImportResult {
  const MoneyImportResult({
    required this.incomeImported,
    required this.expensesImported,
    required this.transfersImported,
    required this.accountsCreated,
    required this.categoriesCreated,
    required this.duplicatesSkipped,
  });

  final int incomeImported;
  final int expensesImported;
  final int transfersImported;
  final int accountsCreated;
  final int categoriesCreated;
  final int duplicatesSkipped;
}

enum MoneyImportStage { validating, importing, complete }

class MoneyImportProgress {
  const MoneyImportProgress({
    required this.stage,
    required this.processed,
    required this.total,
  });

  final MoneyImportStage stage;
  final int processed;
  final int total;
}

class MoneyRange {
  const MoneyRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  factory MoneyRange.forPeriod(
    MoneyPeriod period,
    DateTime anchor, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    switch (period) {
      case MoneyPeriod.day:
        return MoneyRange(day, DateTime(day.year, day.month, day.day + 1));
      case MoneyPeriod.week:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return MoneyRange(
          start,
          DateTime(start.year, start.month, start.day + 7),
        );
      case MoneyPeriod.month:
        return MoneyRange(
          DateTime(day.year, day.month),
          DateTime(day.year, day.month + 1),
        );
      case MoneyPeriod.year:
        return MoneyRange(DateTime(day.year), DateTime(day.year + 1));
      case MoneyPeriod.custom:
        final start = customStart ?? day;
        return MoneyRange(
          DateTime(start.year, start.month, start.day),
          DateTime(
            (customEnd ?? start).year,
            (customEnd ?? start).month,
            (customEnd ?? start).day + 1,
          ),
        );
    }
  }
}

/// Parses decimal rupees into paise without binary floating point.
int? parseMinorUnits(String input) {
  final value = input.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
}

String formatMinorUnits(int amountMinor, {String symbol = '₹'}) {
  final negative = amountMinor < 0;
  final absolute = amountMinor.abs();
  final rupees = absolute ~/ 100;
  final paise = (absolute % 100).toString().padLeft(2, '0');
  final digits = rupees.toString();
  final grouped = digits.length <= 3
      ? digits
      : '${digits.substring(0, digits.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',')},${digits.substring(digits.length - 3)}';
  return '${negative ? '-' : ''}$symbol$grouped.$paise';
}

/// Converts a persisted icon code point through a constant icon set so Flutter
/// can tree shake the Material icon font for release builds.
IconData moneyIconForCodePoint(int? codePoint) {
  const icons = <IconData>[
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_outlined,
    Icons.wallet_outlined,
    Icons.savings_outlined,
    Icons.credit_card_outlined,
    Icons.payments_outlined,
    Icons.label_outline,
    Icons.restaurant_outlined,
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.directions_bus_outlined,
    Icons.local_gas_station_outlined,
    Icons.receipt_long_outlined,
    Icons.favorite_border,
    Icons.school_outlined,
    Icons.home_outlined,
    Icons.work_outline,
    Icons.swap_horiz,
    Icons.north_east,
    Icons.south_west,
  ];
  return icons.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.label_outline,
  );
}
