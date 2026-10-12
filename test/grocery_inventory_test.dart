import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/groceries/data/grocery_repository.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';

void main() {
  late MoneyDatabase db;
  late GroceryRepository repository;
  late String listId;

  setUp(() async {
    db = MoneyDatabase(NativeDatabase.memory());
    repository = GroceryRepository(db);
    await repository.saveList(id: 'weekly-list', name: 'Weekly shop');
    listId = 'weekly-list';
  });

  tearDown(() => db.close());

  test(
    'inventory item can be edited, moved and marked used without expense',
    () async {
      await repository.saveInventoryItem(
        id: 'milk-fridge',
        item: const InventoryItemInput(
          name: 'Milk',
          quantityMilli: 2000,
          unit: 'Litre',
          category: 'Dairy',
          location: 'Fridge',
        ),
      );
      await repository.adjustInventoryQuantity('milk-fridge', 1500);
      await repository.moveInventoryItem('milk-fridge', 'Freezer');
      final updated = (await repository.inventory()).single;
      expect(updated.quantityMilli, 1500);
      expect(updated.location, 'Freezer');

      await repository.adjustInventoryQuantity('milk-fridge', 0);
      expect(await repository.inventory(), isEmpty);
      expect(
        (await repository.inventory(includeUsedUp: true)).single.quantityMilli,
        0,
      );
      expect(await db.select(db.moneyTransactions).get(), isEmpty);
    },
  );

  test('bulk inventory validates all rows and saves together', () async {
    await repository.addInventoryItems(const [
      InventoryItemInput(
        name: 'Apples',
        quantityMilli: 4,
        unit: 'Piece',
        category: 'Fruits',
        location: 'Pantry',
      ),
      InventoryItemInput(
        name: 'Yogurt',
        quantityMilli: 500,
        unit: 'Gram',
        category: 'Dairy',
        location: 'Fridge',
      ),
    ]);
    expect((await repository.inventory()).length, 2);
    await expectLater(
      repository.addInventoryItems(const [
        InventoryItemInput(
          name: 'Bread',
          quantityMilli: 1,
          unit: 'Loaf',
          category: 'Bakery',
          location: 'Pantry',
        ),
        InventoryItemInput(
          name: '',
          quantityMilli: 1,
          unit: 'Piece',
          category: 'Other',
          location: 'Pantry',
        ),
      ]),
      throwsArgumentError,
    );
    expect((await repository.inventory()).length, 2);
  });

  test(
    'purchased shopping quantity merges once at the chosen location',
    () async {
      await repository.saveInventoryItem(
        id: 'milk-fridge',
        item: const InventoryItemInput(
          name: 'Milk',
          quantityMilli: 1000,
          unit: 'Litre',
          category: 'Dairy',
          location: 'Fridge',
        ),
      );
      await repository.saveInventoryItem(
        id: 'milk-pantry',
        item: const InventoryItemInput(
          name: 'Milk',
          quantityMilli: 4000,
          unit: 'Litre',
          category: 'Dairy',
          location: 'Pantry',
        ),
      );
      await repository.saveItem(
        listId: listId,
        name: 'Milk',
        quantityMilli: 2000,
        unit: 'Litre',
        category: 'Dairy',
      );
      final shoppingItem = (await repository.items(listId)).single;
      await repository.setPurchased(shoppingItem.id, purchased: true);

      expect(
        await repository.receivePurchasedItem(
          itemId: shoppingItem.id,
          location: 'Fridge',
          addToInventory: true,
        ),
        isTrue,
      );
      expect(
        await repository.receivePurchasedItem(
          itemId: shoppingItem.id,
          location: 'Fridge',
          addToInventory: true,
        ),
        isFalse,
      );
      final inventory = await repository.inventory();
      expect(
        inventory.singleWhere((row) => row.id == 'milk-fridge').quantityMilli,
        3000,
      );
      expect(
        inventory.singleWhere((row) => row.id == 'milk-pantry').quantityMilli,
        4000,
      );
      expect(await db.select(db.moneyTransactions).get(), isEmpty);
    },
  );

  test('recorded grocery bill and inventory receipt are idempotent', () async {
    final money = MoneyRepository(db);
    await money.seedDefaults();
    await money.saveAccount(
      id: 'cash-account',
      name: 'Cash',
      type: AccountType.cash,
      openingBalanceMinor: 0,
    );
    final groceries = (await money.categories()).singleWhere(
      (row) => row.name == 'Groceries',
    );
    await repository.saveInventoryItem(
      id: 'milk-fridge',
      item: const InventoryItemInput(
        name: 'Milk',
        quantityMilli: 1000,
        unit: 'Litre',
        category: 'Dairy',
        location: 'Fridge',
      ),
    );
    await repository.saveItem(
      listId: listId,
      name: 'Milk',
      quantityMilli: 2000,
      unit: 'Litre',
      category: 'Dairy',
    );
    final item = (await repository.items(listId)).single;
    await repository.setPurchased(item.id, purchased: true);

    Future<void> record(int amount) => repository.recordPurchase(
      listId: listId,
      itemIds: [item.id],
      amountMinor: amount,
      accountId: 'cash-account',
      categoryId: groceries.id,
      occurredAt: DateTime(2026, 10, 11),
      addPurchasedToInventory: true,
      inventoryLocation: 'Fridge',
    );

    await record(500);
    await record(700);
    final transactions = await db.select(db.moneyTransactions).get();
    expect(transactions.length, 1);
    expect(transactions.single.amountMinor, 700);
    expect((await repository.inventory()).single.quantityMilli, 3000);
  });

  test(
    'bulk shopping items persist and inventory expiry is summarized',
    () async {
      final soon = DateTime.now().add(const Duration(days: 3));
      await repository.addShoppingItemsBulk(listId, const [
        ShoppingItemInput(name: 'Coffee', quantityMilli: 1, unit: 'Pack'),
        ShoppingItemInput(
          name: 'Bananas',
          quantityMilli: 6,
          unit: 'Piece',
          category: 'Fruits',
        ),
      ]);
      await repository.addInventoryItems([
        InventoryItemInput(
          name: 'Yogurt',
          quantityMilli: 500,
          unit: 'Gram',
          category: 'Dairy',
          location: 'Fridge',
          expiryAt: soon,
        ),
      ]);
      final summary = await repository.dashboardSummary();
      expect(summary.remaining, 2);
      expect(summary.inventoryCount, 1);
      expect(summary.expiringSoon, 1);
    },
  );
}
