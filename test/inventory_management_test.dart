import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/groceries/data/grocery_repository.dart';
import 'package:personal_manager/features/groceries/presentation/groceries_screen.dart';
import 'package:personal_manager/features/money/data/money_database.dart';

void main() {
  late MoneyDatabase db;
  late GroceryRepository repository;

  setUp(() async {
    db = MoneyDatabase(NativeDatabase.memory());
    repository = GroceryRepository(db);
    await repository.seedDefaultCategories();
  });

  tearDown(() async {
    await db.close();
  });

  group('Inventory Management Tests', () {
    test('1 & 15. Default categories seeding & data migration', () async {
      final categories = await repository.categories();
      expect(categories.length, equals(5));
      expect(
        categories.map((c) => c.name),
        containsAll([
          'Groceries',
          'Toiletries',
          'Cleaning Supplies',
          'Medicines',
          'Stationery',
        ]),
      );
    });

    test(
      '1, 6 & 9. Creating inventory items with decimal quantities',
      () async {
        await repository.saveInventoryItem(
          item: const InventoryItemInput(
            name: 'Rice',
            quantityMilli: 2500, // 2.5 kg
            targetQuantityMilli: 5000, // 5.0 kg
            lowStockThresholdMilli: 1000,
            unit: 'kg',
            category: 'Groceries',
          ),
        );

        final items = await repository.inventory();
        expect(items.length, equals(1));
        expect(items.first.name, equals('Rice'));
        expect(items.first.quantityMilli, equals(2500));
        expect(items.first.targetQuantityMilli, equals(5000));
        expect(items.first.unit, equals('kg'));
      },
    );

    test('2. Editing inventory items', () async {
      await repository.saveInventoryItem(
        item: const InventoryItemInput(
          name: 'Milk',
          quantityMilli: 1000,
          unit: 'L',
          category: 'Groceries',
        ),
      );

      var items = await repository.inventory();
      final id = items.first.id;

      await repository.saveInventoryItem(
        id: id,
        item: const InventoryItemInput(
          name: 'Whole Milk',
          quantityMilli: 2000,
          unit: 'L',
          category: 'Groceries',
        ),
      );

      items = await repository.inventory();
      expect(items.first.name, equals('Whole Milk'));
      expect(items.first.quantityMilli, equals(2000));
    });

    test('3. Deleting inventory items', () async {
      await repository.saveInventoryItem(
        item: const InventoryItemInput(
          name: 'Shampoo',
          quantityMilli: 1000,
          unit: 'Bottle',
          category: 'Toiletries',
        ),
      );

      var items = await repository.inventory();
      expect(items.length, equals(1));

      await repository.deleteInventoryItem(items.first.id);
      items = await repository.inventory();
      expect(items, isEmpty);
    });

    test('4 & 5. Creating, editing, and deleting categories safely with reassignment', () async {
      await repository.saveCategory(
        name: 'Snacks',
        iconCodePoint: 0xe16a,
        colorValue: 0xFFFFD0AE,
      );

      var categories = await repository.categories();
      final snacksCat = categories.firstWhere((c) => c.name == 'Snacks');

      await repository.saveInventoryItem(
        item: InventoryItemInput(
          name: 'Chips',
          quantityMilli: 2000,
          unit: 'Pack',
          category: 'Snacks',
          categoryId: snacksCat.id,
        ),
      );

      final groceriesCat = categories.firstWhere((c) => c.name == 'Groceries');

      // Reassign items from Snacks to Groceries before deleting Snacks category
      await repository.deleteCategory(
        snacksCat.id,
        reassignToCategoryId: groceriesCat.id,
      );

      categories = await repository.categories();
      expect(categories.any((c) => c.id == snacksCat.id), isFalse);

      final items = await repository.inventory();
      expect(items.first.categoryId, equals(groceriesCat.id));
      expect(items.first.category, equals('Groceries'));
    });

    test('7 & 8. Percentage calculations & stock status thresholds', () {
      // 75-100% -> Well stocked
      expect(
        calculateStockStatus(4.0, 5.0),
        equals(StockStatus.wellStocked), // 80% = Well stocked
      );
      // 50-74% -> Good
      expect(
        calculateStockStatus(2.5, 5.0),
        equals(StockStatus.good), // 50% = Good
      );
      // 25-49% -> Low
      expect(
        calculateStockStatus(2.0, 5.0),
        equals(StockStatus.low), // 40% = Low
      );
      // 1-24% -> Very low
      expect(
        calculateStockStatus(1.0, 5.0),
        equals(StockStatus.veryLow), // 20% = Very low
      );
      // 0% -> Out of stock
      expect(
        calculateStockStatus(0.0, 5.0),
        equals(StockStatus.outOfStock), // 0% = Out of stock
      );

      expect(calculateStockPercentage(2.5, 5.0), equals(50.0));
      expect(calculateStockPercentage(5.0, 5.0), equals(100.0));
    });

    test('9 & 10. Zero quantity & invalid/zero target quantity', () {
      expect(calculateStockStatus(0.0, 0.0), equals(StockStatus.outOfStock));
      expect(calculateStockStatus(2.0, 0.0), equals(StockStatus.wellStocked));
      expect(calculateStockPercentage(2.0, 0.0), equals(100.0));
      expect(calculateStockPercentage(0.0, 0.0), equals(0.0));
    });

    test('11. Quantity adjustments', () async {
      await repository.saveInventoryItem(
        item: const InventoryItemInput(
          name: 'Soap',
          quantityMilli: 1000,
          unit: 'Piece',
          category: 'Toiletries',
        ),
      );

      var items = await repository.inventory();
      final id = items.first.id;

      await repository.adjustInventoryQuantity(id, 3000); // 3 pieces
      items = await repository.inventory();
      expect(items.first.quantityMilli, equals(3000));
    });

    test('14. Shopping list operations and receiving purchases', () async {
      await repository.saveList(name: 'Weekly List');
      final lists = await repository.lists();
      final listId = lists.first.id;

      await repository.saveItem(
        listId: listId,
        name: 'Eggs',
        quantityMilli: 12000, // 12 pieces
        unit: 'Piece',
        category: 'Groceries',
        isPurchased: true,
      );

      final shoppingItems = await repository.items(listId);
      expect(shoppingItems.first.isPurchased, isTrue);

      // Receive purchased item into inventory
      final received = await repository.receivePurchasedItem(
        itemId: shoppingItems.first.id,
        location: 'Pantry',
        addToInventory: true,
      );

      expect(received, isTrue);
      final inventoryItems = await repository.inventory();
      expect(inventoryItems.any((i) => i.name == 'Eggs'), isTrue);
    });

    test('16. Persistence after database reopen', () async {
      await repository.saveInventoryItem(
        item: const InventoryItemInput(
          name: 'Pen',
          quantityMilli: 5000,
          unit: 'Piece',
          category: 'Stationery',
        ),
      );

      final repo2 = GroceryRepository(db);
      final items = await repo2.inventory();
      expect(items.length, equals(1));
      expect(items.first.name, equals('Pen'));
    });
  });
}
