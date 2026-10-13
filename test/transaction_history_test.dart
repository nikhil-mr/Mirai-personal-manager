import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';

void main() {
  group('Transaction History Logic Tests', () {
    final now = DateTime(2026, 10, 12, 14, 30);
    const accountA = 'acc_1';
    const accountB = 'acc_2';

    final txns = [
      MoneyTransaction(
        id: '1',
        accountId: accountA,
        destinationAccountId: null,
        categoryId: 'cat_food',
        type: 'expense',
        amountMinor: 5000,
        note: 'Grocery shopping',
        sourceModule: 'manual',
        occurredAt: now.subtract(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      ),
      MoneyTransaction(
        id: '2',
        accountId: accountA,
        destinationAccountId: null,
        categoryId: 'cat_salary',
        type: 'income',
        amountMinor: 200000,
        note: 'October Salary',
        sourceModule: 'manual',
        occurredAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ),
      MoneyTransaction(
        id: '3',
        accountId: accountA,
        destinationAccountId: accountB,
        categoryId: null,
        type: 'transfer',
        amountMinor: 10000,
        note: 'Savings transfer',
        sourceModule: 'manual',
        occurredAt: now.subtract(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('Filter by transaction type correctly isolates expenses', () {
      final expenses = txns.where((t) => t.type == 'expense').toList();
      expect(expenses.length, 1);
      expect(expenses.first.id, '1');
    });

    test('Filter by search query matches note and ignores case', () {
      const query = 'grocery';
      final results = txns.where((t) => t.note.toLowerCase().contains(query)).toList();
      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('Totals calculate expenses and income without transfers inflating them', () {
      int totalExpense = 0;
      int totalIncome = 0;
      for (final t in txns) {
        if (t.type == 'expense') totalExpense += t.amountMinor;
        if (t.type == 'income') totalIncome += t.amountMinor;
      }
      expect(totalExpense, 5000);
      expect(totalIncome, 200000);
    });

    test('Transfers match when filtering by source or destination account', () {
      final matchingAccB = txns.where((t) => t.accountId == accountB || t.destinationAccountId == accountB).toList();
      expect(matchingAccB.length, 1);
      expect(matchingAccB.first.type, 'transfer');
    });

    test('Sorting by amount descending places largest amount first', () {
      final sorted = List<MoneyTransaction>.from(txns)
        ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
      expect(sorted.first.id, '2');
      expect(sorted.last.id, '1');
    });
  });
}
