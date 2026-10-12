import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/money_models.dart';
import 'money_database.dart';

class MoneyRepository {
  MoneyRepository(this.db);
  final MoneyDatabase db;
  static const _uuid = Uuid();

  Stream<List<MoneyAccount>> watchAccounts({bool includeArchived = false}) =>
      (db.select(db.moneyAccounts)
            ..where(
              (a) => includeArchived
                  ? const Constant(true)
                  : a.archivedAt.isNull(),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Stream<List<MoneyCategory>> watchCategories(
    String type, {
    bool includeArchived = false,
  }) =>
      (db.select(db.moneyCategories)
            ..where(
              (c) =>
                  c.type.equals(type) &
                  (includeArchived
                      ? const Constant(true)
                      : c.archivedAt.isNull()),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Stream<List<MoneyTransaction>> watchTransactions({
    DateTime? start,
    DateTime? end,
    String? accountId,
    String? type,
  }) => _transactionQuery(
    start: start,
    end: end,
    accountId: accountId,
    type: type,
  ).watch();

  Selectable<MoneyTransaction> _transactionQuery({
    DateTime? start,
    DateTime? end,
    String? accountId,
    String? type,
  }) {
    final query = db.select(db.moneyTransactions);
    query.where((t) {
      Expression<bool> filter = const Constant(true);
      if (start != null) {
        filter = filter & t.occurredAt.isBiggerOrEqualValue(start);
      }
      if (end != null) filter = filter & t.occurredAt.isSmallerThanValue(end);
      if (accountId != null) {
        filter =
            filter &
            (t.accountId.equals(accountId) |
                t.destinationAccountId.equals(accountId));
      }
      if (type != null) filter = filter & t.type.equals(type);
      return filter;
    });
    query.orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query;
  }

  Future<List<MoneyAccount>> accounts({bool includeArchived = false}) =>
      (db.select(db.moneyAccounts)..where(
            (a) =>
                includeArchived ? const Constant(true) : a.archivedAt.isNull(),
          ))
          .get();

  Future<List<MoneyCategory>> categories({bool includeArchived = false}) =>
      (db.select(db.moneyCategories)..where(
            (c) =>
                includeArchived ? const Constant(true) : c.archivedAt.isNull(),
          ))
          .get();

  Future<List<MoneyTransaction>> transactions({
    DateTime? start,
    DateTime? end,
    String? accountId,
    String? type,
  }) => _transactionQuery(
    start: start,
    end: end,
    accountId: accountId,
    type: type,
  ).get();

  Stream<List<MoneyTransaction>> watchAllTransactions() => watchTransactions();

  Future<void> saveAccount({
    String? id,
    required String name,
    required AccountType type,
    required int openingBalanceMinor,
    int? icon,
    int? color,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Account name must be between 1 and 80 characters.');
    }
    final now = DateTime.now();
    if (id == null) {
      await db
          .into(db.moneyAccounts)
          .insert(
            MoneyAccountsCompanion.insert(
              id: _uuid.v4(),
              name: name.trim(),
              type: type.name,
              openingBalanceMinor: openingBalanceMinor,
              iconCodePoint: Value(icon),
              colorValue: Value(color),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (db.update(db.moneyAccounts)..where((a) => a.id.equals(id))).write(
        MoneyAccountsCompanion(
          name: Value(name.trim()),
          type: Value(type.name),
          openingBalanceMinor: Value(openingBalanceMinor),
          iconCodePoint: Value(icon),
          colorValue: Value(color),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> archiveAccount(String id, {required bool archive}) =>
      (db.update(db.moneyAccounts)..where((a) => a.id.equals(id))).write(
        MoneyAccountsCompanion(
          archivedAt: Value(archive ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Permanently removes an account and its account-specific ledger entries.
  /// Transfers involving this account are removed in full as well.
  Future<void> deleteAccount(String id) => db.transaction(() async {
    await (db.delete(db.moneyTransactions)..where(
          (t) => t.accountId.equals(id) | t.destinationAccountId.equals(id),
        ))
        .go();
    await (db.delete(
      db.accountBalanceAdjustments,
    )..where((row) => row.accountId.equals(id))).go();
    await (db.delete(db.moneyAccounts)..where((a) => a.id.equals(id))).go();
  });

  Future<void> saveCategory({
    String? id,
    required String name,
    required String type,
    required int icon,
    required int color,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw ArgumentError('Category name must be between 1 and 60 characters.');
    }
    if (id == null) {
      await db
          .into(db.moneyCategories)
          .insert(
            MoneyCategoriesCompanion.insert(
              id: _uuid.v4(),
              name: name.trim(),
              type: type,
              iconCodePoint: icon,
              colorValue: color,
            ),
          );
    } else {
      await (db.update(
        db.moneyCategories,
      )..where((c) => c.id.equals(id))).write(
        MoneyCategoriesCompanion(
          name: Value(name.trim()),
          iconCodePoint: Value(icon),
          colorValue: Value(color),
        ),
      );
    }
  }

  Future<void> archiveCategory(String id, {required bool archive}) =>
      (db.update(db.moneyCategories)..where((c) => c.id.equals(id))).write(
        MoneyCategoriesCompanion(
          archivedAt: Value(archive ? DateTime.now() : null),
        ),
      );

  Future<void> saveTransaction({
    String? id,
    required MoneyType type,
    required int amountMinor,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    required DateTime occurredAt,
    String note = '',
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (type == MoneyType.transfer &&
        (destinationAccountId == null || destinationAccountId == accountId)) {
      throw ArgumentError('Choose two different accounts.');
    }
    if (type != MoneyType.transfer && destinationAccountId != null) {
      throw ArgumentError('Only transfers can have a destination account.');
    }
    if (type != MoneyType.transfer && categoryId == null) {
      throw ArgumentError('Choose a category.');
    }
    final now = DateTime.now();
    await db.transaction(() async {
      final activeAccountIds = (await accounts()).map((a) => a.id).toSet();
      if (!activeAccountIds.contains(accountId) ||
          (destinationAccountId != null &&
              !activeAccountIds.contains(destinationAccountId))) {
        throw ArgumentError('Archived or missing accounts cannot be used.');
      }
      if (categoryId != null) {
        final category = await (db.select(
          db.moneyCategories,
        )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
        if (category == null ||
            category.archivedAt != null ||
            category.type != type.name) {
          throw ArgumentError(
            'Choose an active category of the matching type.',
          );
        }
      }
      final values = MoneyTransactionsCompanion(
        id: Value(id ?? _uuid.v4()),
        type: Value(type.name),
        amountMinor: Value(amountMinor),
        accountId: Value(accountId),
        destinationAccountId: Value(
          type == MoneyType.transfer ? destinationAccountId : null,
        ),
        categoryId: Value(type == MoneyType.transfer ? null : categoryId),
        note: Value(note.trim()),
        occurredAt: Value(occurredAt.toLocal()),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      if (id == null) {
        await db.into(db.moneyTransactions).insert(values);
      } else {
        final original = await (db.select(
          db.moneyTransactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (original == null) throw StateError('Transaction no longer exists.');
        await (db.update(db.moneyTransactions)..where((t) => t.id.equals(id)))
            .write(values.copyWith(createdAt: Value(original.createdAt)));
      }
    });
  }

  /// Commits validated Excel rows and any missing accounts/categories as one
  /// database transaction. Imported accounts start at zero; historical rows
  /// are applied through the normal ledger and do not invent opening balances.
  Future<MoneyImportResult> importTransactions(
    List<MoneyImportRecord> records, {
    bool skipPossibleDuplicates = true,
    void Function(MoneyImportProgress progress)? onProgress,
  }) async {
    final result = await db.transaction(() async {
      final accountRows = await db.select(db.moneyAccounts).get();
      final categoryRows = await db.select(db.moneyCategories).get();
      final existingTransactions = await db.select(db.moneyTransactions).get();
      final importedRefs = existingTransactions
          .where((row) => row.sourceModule == 'excel_import')
          .map((row) => row.sourceReferenceId)
          .whereType<String>()
          .toSet();
      final accountsByName = <String, MoneyAccount>{
        for (final account in accountRows)
          account.name.trim().toLowerCase(): account,
      };
      final categoriesByKey = <String, MoneyCategory>{
        for (final category in categoryRows)
          '${category.type}:${category.name.trim().toLowerCase()}': category,
      };
      var accountsCreated = 0;
      var categoriesCreated = 0;
      var duplicatesSkipped = 0;
      var incomeImported = 0;
      var expensesImported = 0;
      var transfersImported = 0;
      final now = DateTime.now();

      for (var index = 0; index < records.length; index++) {
        onProgress?.call(
          MoneyImportProgress(
            stage: MoneyImportStage.validating,
            processed: index,
            total: records.length,
          ),
        );
        final row = records[index];
        if (row.amountMinor <= 0 ||
            row.accountName.trim().isEmpty ||
            row.accountName.trim().length > 80) {
          throw ArgumentError(
            'An imported row has an invalid account name or amount.',
          );
        }
        if (row.type == MoneyType.transfer &&
            (row.destinationAccountName == null ||
                row.destinationAccountName!.trim().isEmpty ||
                row.destinationAccountName!.trim().length > 80 ||
                row.destinationAccountName!.trim().toLowerCase() ==
                    row.accountName.trim().toLowerCase())) {
          throw ArgumentError('A transfer needs two different account names.');
        }
        if (row.type != MoneyType.transfer &&
            (row.categoryName == null ||
                row.categoryName!.trim().isEmpty ||
                row.categoryName!.trim().length > 60)) {
          throw ArgumentError('An income or expense needs a category.');
        }
        final importedAccountNames = <String>{
          row.accountName.trim().toLowerCase(),
          if (row.destinationAccountName != null)
            row.destinationAccountName!.trim().toLowerCase(),
        };
        for (final name in importedAccountNames) {
          if (accountRows
                  .where((account) => account.name.trim().toLowerCase() == name)
                  .length >
              1) {
            throw StateError(
              'More than one existing account matches "$name". Resolve the account before importing.',
            );
          }
        }
        if (row.categoryName != null &&
            categoryRows
                    .where(
                      (category) =>
                          category.type == row.type.name &&
                          category.name.trim().toLowerCase() ==
                              row.categoryName!.trim().toLowerCase(),
                    )
                    .length >
                1) {
          throw StateError(
            'More than one category matches "${row.categoryName}". Resolve the category before importing.',
          );
        }
      }

      for (var index = 0; index < records.length; index++) {
        onProgress?.call(
          MoneyImportProgress(
            stage: MoneyImportStage.importing,
            processed: index,
            total: records.length,
          ),
        );
        final row = records[index];
        if (importedRefs.contains(row.fingerprint)) {
          duplicatesSkipped++;
          continue;
        }
        var account = accountsByName[row.accountName.trim().toLowerCase()];
        if (account?.archivedAt != null) {
          throw StateError('Account "${row.accountName}" is archived.');
        }
        if (account == null) {
          final id = _uuid.v4();
          account = MoneyAccount(
            id: id,
            name: row.accountName.trim(),
            type: AccountType.other.name,
            openingBalanceMinor: 0,
            iconCodePoint: null,
            colorValue: null,
            createdAt: now,
            updatedAt: now,
            archivedAt: null,
          );
          await db
              .into(db.moneyAccounts)
              .insert(
                MoneyAccountsCompanion.insert(
                  id: id,
                  name: account.name,
                  type: account.type,
                  openingBalanceMinor: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          accountsByName[account.name.toLowerCase()] = account;
          accountsCreated++;
        }

        MoneyAccount? destination;
        if (row.type == MoneyType.transfer) {
          final destinationName = row.destinationAccountName!.trim();
          destination = accountsByName[destinationName.toLowerCase()];
          if (destination?.archivedAt != null) {
            throw StateError('Account "$destinationName" is archived.');
          }
          if (destination == null) {
            final id = _uuid.v4();
            destination = MoneyAccount(
              id: id,
              name: destinationName,
              type: AccountType.other.name,
              openingBalanceMinor: 0,
              iconCodePoint: null,
              colorValue: null,
              createdAt: now,
              updatedAt: now,
              archivedAt: null,
            );
            await db
                .into(db.moneyAccounts)
                .insert(
                  MoneyAccountsCompanion.insert(
                    id: id,
                    name: destination.name,
                    type: destination.type,
                    openingBalanceMinor: 0,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
            accountsByName[destination.name.toLowerCase()] = destination;
            accountsCreated++;
          }
        }

        MoneyCategory? category;
        if (row.type != MoneyType.transfer) {
          final categoryName = row.categoryName!.trim();
          final key = '${row.type.name}:${categoryName.toLowerCase()}';
          category = categoriesByKey[key];
          if (category?.archivedAt != null) {
            throw StateError('Category "$categoryName" is archived.');
          }
          if (category == null) {
            final id = _uuid.v4();
            category = MoneyCategory(
              id: id,
              name: categoryName,
              type: row.type.name,
              iconCodePoint: _iconFor(categoryName),
              colorValue: 0xFF748078,
              isDefault: false,
              archivedAt: null,
            );
            await db
                .into(db.moneyCategories)
                .insert(
                  MoneyCategoriesCompanion.insert(
                    id: id,
                    name: categoryName,
                    type: row.type.name,
                    iconCodePoint: category.iconCodePoint,
                    colorValue: category.colorValue,
                  ),
                );
            categoriesByKey[key] = category;
            categoriesCreated++;
          }
        }

        final exactMatches = existingTransactions.where((existing) {
          return existing.type == row.type.name &&
              existing.occurredAt.isAtSameMomentAs(row.occurredAt) &&
              existing.amountMinor == row.amountMinor &&
              existing.accountId == account!.id &&
              existing.destinationAccountId == destination?.id &&
              existing.categoryId == category?.id &&
              existing.note.trim() == row.note.trim();
        });
        if (skipPossibleDuplicates && exactMatches.isNotEmpty) {
          duplicatesSkipped++;
          continue;
        }

        await db
            .into(db.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                id: _uuid.v4(),
                type: row.type.name,
                amountMinor: row.amountMinor,
                accountId: account.id,
                destinationAccountId: Value(destination?.id),
                categoryId: Value(category?.id),
                note: Value(row.note.trim()),
                occurredAt: row.occurredAt.toLocal(),
                createdAt: now,
                updatedAt: now,
                sourceModule: const Value('excel_import'),
                sourceReferenceId: Value(row.fingerprint),
              ),
            );
        importedRefs.add(row.fingerprint);
        switch (row.type) {
          case MoneyType.income:
            incomeImported++;
          case MoneyType.expense:
            expensesImported++;
          case MoneyType.transfer:
            transfersImported++;
        }
      }
      return MoneyImportResult(
        incomeImported: incomeImported,
        expensesImported: expensesImported,
        transfersImported: transfersImported,
        accountsCreated: accountsCreated,
        categoriesCreated: categoriesCreated,
        duplicatesSkipped: duplicatesSkipped,
      );
    });
    onProgress?.call(
      MoneyImportProgress(
        stage: MoneyImportStage.complete,
        processed: records.length,
        total: records.length,
      ),
    );
    return result;
  }

  Future<void> deleteTransaction(String id) =>
      (db.delete(db.moneyTransactions)..where((t) => t.id.equals(id))).go();

  /// Sets an account to the entered current balance by appending a signed
  /// adjustment. Existing income, expense, and transfer history is untouched.
  Future<int> setAccountBalance({
    required String accountId,
    required int targetBalanceMinor,
    String note = 'Manual balance adjustment',
  }) async {
    if (targetBalanceMinor < 0) {
      throw ArgumentError('Account balance cannot be negative.');
    }
    return db.transaction(() async {
      final account =
          await (db.select(db.moneyAccounts)..where(
                (row) => row.id.equals(accountId) & row.archivedAt.isNull(),
              ))
              .getSingleOrNull();
      if (account == null) {
        throw ArgumentError('Choose an active account to adjust.');
      }
      var current = account.openingBalanceMinor;
      final txns = await transactions(accountId: accountId);
      for (final transaction in txns) {
        switch (transaction.type) {
          case 'income':
            current += transaction.amountMinor;
          case 'expense':
            current -= transaction.amountMinor;
          case 'transfer':
            if (transaction.accountId == accountId) {
              current -= transaction.amountMinor;
            } else if (transaction.destinationAccountId == accountId) {
              current += transaction.amountMinor;
            }
        }
      }
      final adjustments = await (db.select(
        db.accountBalanceAdjustments,
      )..where((row) => row.accountId.equals(accountId))).get();
      current += adjustments.fold<int>(0, (sum, row) => sum + row.amountMinor);
      final difference = targetBalanceMinor - current;
      if (difference == 0) return 0;
      final now = DateTime.now();
      await db
          .into(db.accountBalanceAdjustments)
          .insert(
            AccountBalanceAdjustmentsCompanion.insert(
              id: _uuid.v4(),
              accountId: accountId,
              amountMinor: difference,
              occurredAt: now,
              note: Value(
                note.trim().isEmpty ? 'Manual balance adjustment' : note.trim(),
              ),
              createdAt: now,
            ),
          );
      await (db.update(db.moneyAccounts)
            ..where((row) => row.id.equals(accountId)))
          .write(MoneyAccountsCompanion(updatedAt: Value(now)));
      return difference;
    });
  }

  Future<Map<String, int>> calculateBalances() async {
    final accounts = await this.accounts(includeArchived: true);
    final txns = await transactions();
    final balances = {for (final a in accounts) a.id: a.openingBalanceMinor};
    for (final tx in txns) {
      switch (tx.type) {
        case 'income':
          balances[tx.accountId] =
              (balances[tx.accountId] ?? 0) + tx.amountMinor;
        case 'expense':
          balances[tx.accountId] =
              (balances[tx.accountId] ?? 0) - tx.amountMinor;
        case 'transfer':
          balances[tx.accountId] =
              (balances[tx.accountId] ?? 0) - tx.amountMinor;
          final destination = tx.destinationAccountId;
          if (destination != null) {
            balances[destination] =
                (balances[destination] ?? 0) + tx.amountMinor;
          }
      }
    }
    final adjustments = await db.select(db.accountBalanceAdjustments).get();
    for (final adjustment in adjustments) {
      balances[adjustment.accountId] =
          (balances[adjustment.accountId] ?? 0) + adjustment.amountMinor;
    }
    return balances;
  }

  Future<void> seedDefaults() async {
    const expenses = {
      'Food': 0xFFDF8C53,
      'Groceries': 0xFF4A9F8D,
      'Shopping': 0xFF7C89A8,
      'Travel': 0xFF6488B8,
      'Fuel': 0xFFB67527,
      'Bills': 0xFF8B6F9E,
      'Entertainment': 0xFFBB7187,
      'Health': 0xFF4D9B83,
      'Education': 0xFF5980A2,
      'Rent': 0xFFBC9B62,
      'Other': 0xFF748078,
    };
    const incomes = {
      'Salary': 0xFF288467,
      'Freelance': 0xFF4A9F8D,
      'Business': 0xFF6488B8,
      'Gift': 0xFFBB7187,
      'Interest': 0xFFBC9B62,
      'Refund': 0xFF7C89A8,
      'Other': 0xFF748078,
    };
    await db.transaction(() async {
      if ((await db.select(db.moneyCategories).get()).isNotEmpty) return;
      await db.batch((batch) {
        for (final (type, entries) in [
          ('expense', expenses),
          ('income', incomes),
        ]) {
          for (final entry in entries.entries) {
            batch.insert(
              db.moneyCategories,
              MoneyCategoriesCompanion.insert(
                id: _uuid.v4(),
                name: entry.key,
                type: type,
                iconCodePoint: _iconFor(entry.key),
                colorValue: entry.value,
                isDefault: const Value(true),
              ),
            );
          }
        }
      });
    });
  }

  int _iconFor(String name) => switch (name) {
    'Food' => Icons.restaurant_outlined.codePoint,
    'Groceries' => Icons.shopping_cart_outlined.codePoint,
    'Shopping' => Icons.shopping_bag_outlined.codePoint,
    'Travel' => Icons.directions_bus_outlined.codePoint,
    'Fuel' => Icons.local_gas_station_outlined.codePoint,
    'Bills' => Icons.receipt_long_outlined.codePoint,
    'Entertainment' => Icons.favorite_border.codePoint,
    'Health' => Icons.favorite_border.codePoint,
    'Education' => Icons.school_outlined.codePoint,
    'Rent' => Icons.home_outlined.codePoint,
    'Salary' => Icons.work_outline.codePoint,
    'Freelance' => Icons.payments_outlined.codePoint,
    'Business' => Icons.account_balance_outlined.codePoint,
    'Gift' => Icons.label_outline.codePoint,
    'Interest' => Icons.savings_outlined.codePoint,
    'Refund' => Icons.payments_outlined.codePoint,
    _ => Icons.label_outline.codePoint,
  };
}
