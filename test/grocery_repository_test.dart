import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/groceries/data/grocery_repository.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';

void main() {
  late MoneyDatabase database;
  late GroceryRepository groceries;
  late MoneyRepository money;
  Directory? temporaryDirectory;

  setUp(() async {
    database = MoneyDatabase(NativeDatabase.memory());
    groceries = GroceryRepository(database);
    money = MoneyRepository(database);
    await money.seedDefaults();
  });

  tearDown(() async {
    await database.close();
    final directory = temporaryDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    temporaryDirectory = null;
  });

  test(
    'shopping lists and items persist, edit, archive, restore and delete',
    () async {
      await groceries.saveList(
        name: 'Weekly groceries',
        description: 'Market run',
      );
      var list = (await groceries.lists()).single;
      await groceries.saveItem(
        listId: list.id,
        name: 'Apples',
        quantityMilli: 1500,
        unit: 'Kilogram',
        category: 'Fruits',
        estimatedUnitPriceMinor: 25000,
      );
      var item = (await groceries.items(list.id)).single;
      expect(item.quantityMilli, 1500);
      expect(item.estimatedUnitPriceMinor, 25000);

      await groceries.saveList(id: list.id, name: 'Monthly groceries');
      await groceries.saveItem(
        id: item.id,
        listId: list.id,
        name: 'Green apples',
        quantityMilli: 1000,
        unit: 'Piece',
        category: 'Fruits',
        estimatedUnitPriceMinor: 1200,
      );
      expect((await groceries.items(list.id)).single.name, 'Green apples');
      await groceries.setArchived(list.id, archived: true);
      expect((await groceries.lists()).isEmpty, isTrue);
      expect(
        (await groceries.lists(archived: true)).single.name,
        'Monthly groceries',
      );
      await groceries.setArchived(list.id, archived: false);
      expect((await groceries.items(list.id)).single.id, item.id);
      await groceries.deleteList(list.id);
      expect(await groceries.lists(), isEmpty);
    },
  );

  test('validates item names, quantity and non-negative price', () async {
    await groceries.saveList(name: 'Errands');
    final list = (await groceries.lists()).single;
    Future<void> save({
      String name = 'Milk',
      int quantity = 1000,
      int? price,
    }) => groceries.saveItem(
      listId: list.id,
      name: name,
      quantityMilli: quantity,
      unit: 'Litre',
      category: 'Dairy',
      estimatedUnitPriceMinor: price,
    );
    await expectLater(save(name: ' '), throwsArgumentError);
    await expectLater(save(quantity: 0), throwsArgumentError);
    await expectLater(save(price: -1), throwsArgumentError);
    await save(price: null);
    expect(
      (await groceries.items(list.id)).single.estimatedUnitPriceMinor,
      isNull,
    );
  });

  test(
    'saved lists and items survive closing and reopening the database',
    () async {
      final directory = temporaryDirectory = await Directory.systemTemp
          .createTemp('grocery_db_');
      final file = File(
        '${directory.path}${Platform.pathSeparator}basket.sqlite',
      );
      await database.close();
      database = MoneyDatabase(NativeDatabase(file));
      groceries = GroceryRepository(database);
      await groceries.saveList(name: 'Persistent list');
      final list = (await groceries.lists()).single;
      await groceries.saveItem(
        listId: list.id,
        name: 'Tea',
        quantityMilli: 500,
        unit: 'Pack',
        category: 'Beverages',
      );
      await database.close();
      database = MoneyDatabase(NativeDatabase(file));
      groceries = GroceryRepository(database);
      expect((await groceries.lists()).single.name, 'Persistent list');
      expect((await groceries.items(list.id)).single.name, 'Tea');
    },
  );

  test(
    'clearing purchased items removes them but keeps the shopping list',
    () async {
      await groceries.saveList(name: 'Clear after shopping');
      final list = (await groceries.lists()).single;
      await groceries.saveItem(
        listId: list.id,
        name: 'Soap',
        quantityMilli: 1000,
        unit: 'Piece',
        category: 'Household essentials',
      );
      final item = (await groceries.items(list.id)).single;
      await groceries.setPurchased(item.id, purchased: true);
      await groceries.clearPurchased(list.id);
      expect(await groceries.items(list.id), isEmpty);
      expect((await groceries.lists()).single.id, list.id);
    },
  );

  test(
    'marks items without a financial entry and records a combined bill once',
    () async {
      await groceries.saveList(name: 'Market');
      final list = (await groceries.lists()).single;
      for (final entry in [('Rice', 10000), ('Milk', 6000)]) {
        await groceries.saveItem(
          listId: list.id,
          name: entry.$1,
          quantityMilli: 1000,
          unit: 'Pack',
          category: 'Pantry',
          estimatedUnitPriceMinor: entry.$2,
        );
      }
      final items = await groceries.items(list.id);
      for (final item in items) {
        await groceries.setPurchased(
          item.id,
          purchased: true,
          actualUnitPriceMinor: item.estimatedUnitPriceMinor,
        );
      }
      expect(await database.select(database.moneyTransactions).get(), isEmpty);

      await money.saveAccount(
        name: 'Cash',
        type: AccountType.cash,
        openingBalanceMinor: 0,
      );
      final account = (await money.accounts()).single;
      final category = (await money.categories()).firstWhere(
        (row) => row.name == 'Groceries',
      );
      final ids = items.map((item) => item.id).toList();
      await groceries.recordPurchase(
        listId: list.id,
        itemIds: ids,
        amountMinor: 16800,
        accountId: account.id,
        categoryId: category.id,
        occurredAt: DateTime(2026, 10, 11),
        note: 'Market bill',
      );
      await groceries.recordPurchase(
        listId: list.id,
        itemIds: ids,
        amountMinor: 17000,
        accountId: account.id,
        categoryId: category.id,
        occurredAt: DateTime(2026, 10, 11),
        note: 'Corrected bill total',
      );
      final transactions = await database
          .select(database.moneyTransactions)
          .get();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'expense');
      expect(transactions.single.amountMinor, 17000);
      expect(transactions.single.sourceModule, 'grocery');
      expect(
        await groceries.dashboardSummary().then((summary) => summary.purchased),
        2,
      );
    },
  );

  test(
    'removing grocery records preserves the linked money transaction',
    () async {
      await groceries.saveList(name: 'Quick shop');
      final list = (await groceries.lists()).single;
      await groceries.saveItem(
        listId: list.id,
        name: 'Bread',
        quantityMilli: 1000,
        unit: 'Piece',
        category: 'Bakery',
      );
      final item = (await groceries.items(list.id)).single;
      await groceries.setPurchased(item.id, purchased: true);
      await money.saveAccount(
        name: 'Bank',
        type: AccountType.bank,
        openingBalanceMinor: 0,
      );
      final account = (await money.accounts()).single;
      final category = (await money.categories()).firstWhere(
        (row) => row.type == 'expense',
      );
      await groceries.recordPurchase(
        listId: list.id,
        itemIds: [item.id],
        amountMinor: 500,
        accountId: account.id,
        categoryId: category.id,
        occurredAt: DateTime.now(),
      );
      await groceries.deleteList(list.id);
      final transactions = await database
          .select(database.moneyTransactions)
          .get();
      expect(transactions, hasLength(1));
      expect(transactions.single.amountMinor, 500);
    },
  );
}
