import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';
import 'package:personal_manager/features/money/presentation/money_screen.dart';

void main() {
  group('Money Charts Widget & Selector Tests', () {
    final now = DateTime(2026, 10, 12);

    final expenseOnlyTxns = [
      MoneyTransaction(
        id: '1',
        accountId: 'acc1',
        type: 'expense',
        amountMinor: 5000,
        categoryId: 'cat_food',
        note: '',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        sourceModule: 'manual',
      ),
    ];

    final incomeOnlyTxns = [
      MoneyTransaction(
        id: '2',
        accountId: 'acc1',
        type: 'income',
        amountMinor: 100000,
        categoryId: 'cat_salary',
        note: '',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        sourceModule: 'manual',
      ),
    ];

    final categories = <String, MoneyCategory>{
      'cat_food': MoneyCategory(
        id: 'cat_food',
        name: 'Food',
        type: 'expense',
        iconCodePoint: 0,
        colorValue: 0xFF123456,
        isDefault: true,
      ),
      'cat_salary': MoneyCategory(
        id: 'cat_salary',
        name: 'Salary',
        type: 'income',
        iconCodePoint: 0,
        colorValue: 0xFF654321,
        isDefault: true,
      ),
    };

    testWidgets('Expense data exists -> Expense chart renders with selector', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpendingCharts(
                transactions: expenseOnlyTxns,
                categories: categories,
                period: MoneyPeriod.month,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expenses by category'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('No data for this period'), findsNothing);
    });

    testWidgets('Income data exists -> Income chart renders when toggled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpendingCharts(
                transactions: incomeOnlyTxns,
                categories: categories,
                period: MoneyPeriod.month,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Income' segment
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Income by category'), findsOneWidget);
      expect(find.text('No data for this period'), findsNothing);
    });

    testWidgets(
      'Income data is empty -> empty state appears while selector stays visible & usable',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingCharts(
                  transactions: expenseOnlyTxns,
                  categories: categories,
                  period: MoneyPeriod.month,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 'Income' segment (no income transactions exist)
        await tester.tap(find.text('Income'));
        await tester.pumpAndSettle();

        expect(find.text('Income by category'), findsOneWidget);
        expect(find.text('No data for this period'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);

        // Tap 'Expenses' segment -> switches back immediately!
        await tester.tap(find.text('Expenses'));
        await tester.pumpAndSettle();

        expect(find.text('Expenses by category'), findsOneWidget);
        expect(find.text('No data for this period'), findsNothing);
      },
    );

    testWidgets('Both datasets empty -> selector remains visible and usable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpendingCharts(
                transactions: const [],
                categories: categories,
                period: MoneyPeriod.month,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No data for this period'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Income by category'), findsOneWidget);
      expect(find.text('No data for this period'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets(
      'Changing selected period updates chart without hiding selector',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingCharts(
                  transactions: expenseOnlyTxns,
                  categories: categories,
                  period: MoneyPeriod.year,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Expenses by category'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
      },
    );
  });
}
