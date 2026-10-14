import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_manager/app/router/app_routes.dart';
import 'package:personal_manager/app/router/quick_add_sheet.dart';
import 'package:personal_manager/features/groceries/presentation/groceries_screen.dart';
import 'package:personal_manager/features/money/application/money_providers.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:drift/native.dart';

void main() {
  late MoneyDatabase db;

  setUp(() {
    db = MoneyDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Quick Add Sheet & Item Navigation Tests', () {
    testWidgets(
      'Quick Add displays four options in correct order: Transaction, Task, Place, Item',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => Consumer(
                    builder: (context, ref, _) => ElevatedButton(
                      onPressed: () => showQuickAddSheet(context, ref),
                      child: const Text('Open Quick Add'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Quick Add'));
        await tester.pumpAndSettle();

        expect(find.text('What would you like to add?'), findsOneWidget);
        expect(find.text('Transaction'), findsOneWidget);
        expect(find.text('Task'), findsOneWidget);
        expect(find.text('Place'), findsOneWidget);
        expect(find.text('Item'), findsOneWidget);
      },
    );

    testWidgets('Tapping Cancel closes Quick Add sheet normally', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showQuickAddSheet(context, ref),
                    child: const Text('Open Quick Add'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Quick Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to add?'), findsNothing);
    });

    testWidgets('Tapping Item opens Add Item form in Inventory module', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showQuickAddSheet(context, ref),
                  child: const Text('Open Quick Add'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.groceries,
            builder: (context, state) => GroceriesScreen(
              quickAdd: state.uri.queryParameters['quickAdd'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [moneyDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.text('Open Quick Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Item'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Inventory Item'), findsOneWidget);
      expect(find.text('Item Name *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Unit *'), findsOneWidget);
      expect(find.text('Current Qty *'), findsOneWidget);
      expect(find.text('Target Qty'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
