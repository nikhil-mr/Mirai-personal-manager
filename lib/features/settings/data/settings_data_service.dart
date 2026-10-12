import 'dart:convert';

import '../../money/data/money_database.dart';

/// Data export and restore for the tables currently used by Mirai.
/// Restore merges by stable primary key and runs in one SQLite transaction.
class SettingsDataService {
  SettingsDataService(this.db);

  final MoneyDatabase db;

  static const schemaVersion = 2;
  static const tableOrder = <String>[
    'money_accounts',
    'money_categories',
    'account_balance_adjustments',
    'money_transactions',
    'budget_plans',
    'budget_alert_states',
    'task_categories',
    'task_records',
    'saved_places',
    'travel_trips',
    'trip_places',
    'trip_estimates',
    'trip_expense_links',
    'grocery_lists',
    'grocery_items',
    'grocery_purchases',
    'grocery_purchase_items',
    'home_inventory_items',
  ];

  Future<String> exportJson({Map<String, Object?> settings = const {}}) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in tableOrder) {
      final rows = await db.customSelect('SELECT * FROM $table').get();
      tables[table] = rows.map((row) => row.data).toList();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'life_partner_backup',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'applicationVersion': '1.0.0+1',
      'settings': settings,
      'tables': tables,
    });
  }

  Future<int> restoreMerge(String json) async {
    final decoded = jsonDecode(json);
    final version = decoded is Map<String, dynamic>
        ? decoded['schemaVersion']
        : null;
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'life_partner_backup' ||
        version is! int ||
        version < 1 ||
        version > schemaVersion ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException(
        'Unsupported or invalid Mirai backup.',
      );
    }
    final source = decoded['tables'] as Map<String, dynamic>;
    if (source.keys.toSet().difference(tableOrder.toSet()).isNotEmpty) {
      throw const FormatException('Backup contains unknown data tables.');
    }
    final checked = <String, List<Map<String, Object?>>>{};
    for (final table in tableOrder) {
      final value = source[table];
      if (value == null) {
        checked[table] = const [];
        continue;
      }
      if (value is! List) {
        throw FormatException('Invalid rows for $table.');
      }
      final ids = <Object?>{};
      final rows = <Map<String, Object?>>[];
      for (final row in value) {
        if (row is! Map ||
            row['id'] is! String ||
            (row['id'] as String).isEmpty) {
          throw FormatException('A $table record has no valid ID.');
        }
        if (!ids.add(row['id'])) {
          throw FormatException('Duplicate ID in $table.');
        }
        rows.add(Map<String, Object?>.from(row));
      }
      checked[table] = rows;
    }

    var inserted = 0;
    await db.transaction(() async {
      for (final table in tableOrder) {
        for (final row in checked[table]!) {
          final columns = row.keys.toList();
          if (columns.isEmpty ||
              columns.any((name) => !_validIdentifier(name))) {
            throw FormatException('Invalid column in $table.');
          }
          final sql =
              'INSERT OR IGNORE INTO $table '
              '(${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})';
          await db.customStatement(
            sql,
            columns.map((key) => row[key]).toList(),
          );
          final after = await db
              .customSelect('SELECT changes() AS n')
              .getSingle();
          if ((after.data['n'] as int) == 1) inserted++;
        }
      }
    });
    return inserted;
  }

  Future<void> clearRecords() => db.transaction(() async {
    for (final table in [
      'grocery_purchase_items',
      'home_inventory_items',
      'grocery_purchases',
      'grocery_items',
      'grocery_lists',
      'trip_expense_links',
      'trip_estimates',
      'trip_places',
      'travel_trips',
      'saved_places',
      'task_records',
      'task_categories',
      'budget_alert_states',
      'budget_plans',
      'money_transactions',
      'account_balance_adjustments',
      'money_accounts',
      'money_categories',
    ]) {
      await db.customStatement('DELETE FROM $table');
    }
  });

  static bool _validIdentifier(String value) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value);
}
