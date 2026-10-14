import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../money/data/money_database.dart';

class InventoryItemInput {
  const InventoryItemInput({
    required this.name,
    required this.quantityMilli,
    required this.unit,
    required this.category,
    this.location = 'Pantry',
    this.targetQuantityMilli = 0,
    this.lowStockThresholdMilli = 0,
    this.iconCodePoint,
    this.colorValue,
    this.categoryId,
    this.expiryAt,
    this.purchasedAt,
    this.unitCostMinor,
    this.notes = '',
  });

  final String name;
  final int quantityMilli;
  final String unit;
  final String category;
  final String location;
  final int targetQuantityMilli;
  final int lowStockThresholdMilli;
  final int? iconCodePoint;
  final int? colorValue;
  final String? categoryId;
  final DateTime? expiryAt;
  final DateTime? purchasedAt;
  final int? unitCostMinor;
  final String notes;
}

class ShoppingItemInput {
  const ShoppingItemInput({
    required this.name,
    required this.quantityMilli,
    required this.unit,
    this.category = 'Other',
  });

  final String name;
  final int quantityMilli;
  final String unit;
  final String category;
}

class GroceryRepository {
  GroceryRepository(this.db);
  final MoneyDatabase db;
  static const _uuid = Uuid();

  Future<void> seedDefaultCategories() async {
    final existing = await db.select(db.inventoryCategories).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = [
      InventoryCategoriesCompanion.insert(
        id: 'cat_groceries',
        name: 'Groceries',
        iconCodePoint: 0xe59c, // Icons.shopping_bag_outlined
        colorValue: 0xFFAEEBDD,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      InventoryCategoriesCompanion.insert(
        id: 'cat_toiletries',
        name: 'Toiletries',
        iconCodePoint: 0xf017a, // Icons.soap_outlined
        colorValue: 0xFFFFC5D8,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      InventoryCategoriesCompanion.insert(
        id: 'cat_cleaning',
        name: 'Cleaning Supplies',
        iconCodePoint: 0xe17d, // Icons.cleaning_services_outlined
        colorValue: 0xFFBFE0FF,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      InventoryCategoriesCompanion.insert(
        id: 'cat_medicines',
        name: 'Medicines',
        iconCodePoint: 0xe3d9, // Icons.medication_outlined
        colorValue: 0xFFE5C9FF,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      InventoryCategoriesCompanion.insert(
        id: 'cat_stationery',
        name: 'Stationery',
        iconCodePoint: 0xf06d8, // Icons.edit_note_outlined
        colorValue: 0xFFFFD49A,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await db.batch((batch) {
      batch.insertAll(db.inventoryCategories, defaults);
    });
  }

  Stream<List<InventoryCategory>> watchCategories() {
    return (db.select(
      db.inventoryCategories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  }

  Future<List<InventoryCategory>> categories() {
    return (db.select(
      db.inventoryCategories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Enter a category name between 1 and 80 characters.');
    }
    final now = DateTime.now();
    final categoryId = id ?? _uuid.v4();
    await db
        .into(db.inventoryCategories)
        .insertOnConflictUpdate(
          InventoryCategoriesCompanion(
            id: Value(categoryId),
            name: Value(name.trim()),
            iconCodePoint: Value(iconCodePoint),
            colorValue: Value(colorValue),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> deleteCategory(String id, {String? reassignToCategoryId}) async {
    await db.transaction(() async {
      if (reassignToCategoryId != null) {
        final newCategory = await (db.select(
          db.inventoryCategories,
        )..where((c) => c.id.equals(reassignToCategoryId))).getSingleOrNull();
        await (db.update(
          db.homeInventoryItems,
        )..where((item) => item.categoryId.equals(id))).write(
          HomeInventoryItemsCompanion(
            categoryId: Value(reassignToCategoryId),
            category: Value(newCategory?.name ?? 'Other'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await (db.update(
          db.homeInventoryItems,
        )..where((item) => item.categoryId.equals(id))).write(
          HomeInventoryItemsCompanion(
            categoryId: const Value(null),
            category: const Value('Other'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await (db.delete(
        db.inventoryCategories,
      )..where((c) => c.id.equals(id))).go();
    });
  }

  Stream<List<HomeInventoryItem>> watchInventory({bool includeUsedUp = true}) {
    final query = db.select(db.homeInventoryItems);
    if (!includeUsedUp) {
      query.where((item) => item.quantityMilli.isBiggerThanValue(0));
    }
    query.orderBy([(item) => OrderingTerm.asc(item.name)]);
    return query.watch();
  }

  Future<List<HomeInventoryItem>> inventory({bool includeUsedUp = true}) {
    final query = db.select(db.homeInventoryItems);
    if (!includeUsedUp) {
      query.where((item) => item.quantityMilli.isBiggerThanValue(0));
    }
    query.orderBy([(item) => OrderingTerm.asc(item.name)]);
    return query.get();
  }

  Future<void> saveInventoryItem({
    String? id,
    required InventoryItemInput item,
  }) async {
    _validateInventoryInput(item);
    final old = id == null ? null : await _inventoryItem(id);
    if (id != null && old == null) {
      throw StateError('Inventory item not found.');
    }
    final now = DateTime.now();
    await db
        .into(db.homeInventoryItems)
        .insertOnConflictUpdate(
          HomeInventoryItemsCompanion(
            id: Value(id ?? _uuid.v4()),
            name: Value(item.name.trim()),
            quantityMilli: Value(item.quantityMilli),
            unit: Value(item.unit.trim()),
            category: Value(
              item.category.trim().isEmpty ? 'Other' : item.category.trim(),
            ),
            location: Value(item.location.trim()),
            targetQuantityMilli: Value(item.targetQuantityMilli),
            lowStockThresholdMilli: Value(item.lowStockThresholdMilli),
            iconCodePoint: Value(item.iconCodePoint),
            colorValue: Value(item.colorValue),
            categoryId: Value(item.categoryId),
            expiryAt: Value(item.expiryAt),
            purchasedAt: Value(item.purchasedAt),
            unitCostMinor: Value(item.unitCostMinor),
            notes: Value(item.notes.trim()),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<List<HomeInventoryItem>> findInventoryDuplicates(
    String name,
    String location,
  ) async {
    final normalizedName = name.trim().toLowerCase();
    return (await inventory())
        .where(
          (item) =>
              item.location.toLowerCase() == location.trim().toLowerCase() &&
              item.name.trim().toLowerCase() == normalizedName,
        )
        .toList();
  }

  Future<void> addInventoryItems(List<InventoryItemInput> items) async {
    if (items.isEmpty) throw ArgumentError('Add at least one valid item.');
    for (final item in items) {
      _validateInventoryInput(item);
      if (item.quantityMilli == 0) {
        throw ArgumentError(
          'New inventory items need a quantity greater than zero.',
        );
      }
    }
    await db.transaction(() async {
      final now = DateTime.now();
      for (final item in items) {
        await db
            .into(db.homeInventoryItems)
            .insert(
              HomeInventoryItemsCompanion.insert(
                id: _uuid.v4(),
                name: item.name.trim(),
                quantityMilli: item.quantityMilli,
                unit: Value(item.unit.trim()),
                category: Value(
                  item.category.trim().isEmpty ? 'Other' : item.category.trim(),
                ),
                location: Value(item.location.trim()),
                targetQuantityMilli: Value(item.targetQuantityMilli),
                lowStockThresholdMilli: Value(item.lowStockThresholdMilli),
                iconCodePoint: Value(item.iconCodePoint),
                colorValue: Value(item.colorValue),
                categoryId: Value(item.categoryId),
                expiryAt: Value(item.expiryAt),
                purchasedAt: Value(item.purchasedAt),
                unitCostMinor: Value(item.unitCostMinor),
                notes: Value(item.notes.trim()),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<void> adjustInventoryQuantity(String id, int quantityMilli) async {
    if (quantityMilli < 0) throw ArgumentError('Quantity cannot be negative.');
    final changed =
        await (db.update(
          db.homeInventoryItems,
        )..where((item) => item.id.equals(id))).write(
          HomeInventoryItemsCompanion(
            quantityMilli: Value(quantityMilli),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw StateError('Inventory item not found.');
  }

  Future<void> moveInventoryItem(String id, String location) async {
    if (location.trim().isEmpty) {
      throw ArgumentError('Enter a storage location.');
    }
    final changed =
        await (db.update(
          db.homeInventoryItems,
        )..where((item) => item.id.equals(id))).write(
          HomeInventoryItemsCompanion(
            location: Value(location.trim()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw StateError('Inventory item not found.');
  }

  Future<void> deleteInventoryItem(String id) => (db.delete(
    db.homeInventoryItems,
  )..where((item) => item.id.equals(id))).go();

  Future<void> addInventoryItemToShopping({
    required String inventoryItemId,
    required String listId,
    int? quantityMilli,
  }) async {
    final source = await _inventoryItem(inventoryItemId);
    if (source == null) throw StateError('Inventory item no longer exists.');
    await saveItem(
      listId: listId,
      name: source.name,
      quantityMilli: quantityMilli ?? source.quantityMilli,
      unit: source.unit,
      category: source.category,
      estimatedUnitPriceMinor: source.unitCostMinor,
      notes: source.notes,
    );
  }

  /// Records receipt of one purchased shopping entry. Its applied timestamp is
  /// stored on that entry, so reopening the flow cannot add its quantity twice.
  Future<bool> receivePurchasedItem({
    required String itemId,
    required String location,
    required bool addToInventory,
    bool mergeExisting = true,
  }) async => db.transaction(
    () => _receivePurchasedItem(
      itemId: itemId,
      location: location,
      addToInventory: addToInventory,
      mergeExisting: mergeExisting,
    ),
  );

  Future<bool> _receivePurchasedItem({
    required String itemId,
    required String location,
    required bool addToInventory,
    required bool mergeExisting,
  }) async {
    final shoppingItem = await _item(itemId);
    if (shoppingItem == null || !shoppingItem.isPurchased) {
      throw StateError('Mark the shopping item purchased first.');
    }
    if (location.trim().isEmpty) {
      throw ArgumentError('Choose a storage location.');
    }
    if (!addToInventory || shoppingItem.inventoryAppliedAt != null) {
      return false;
    }

    final allInventory = await inventory();
    final candidates = allInventory
        .where(
          (row) =>
              row.name.trim().toLowerCase() ==
                  shoppingItem.name.trim().toLowerCase() &&
              row.location.trim().toLowerCase() ==
                  location.trim().toLowerCase() &&
              row.unit.trim().toLowerCase() ==
                  shoppingItem.unit.trim().toLowerCase(),
        )
        .toList();
    if (mergeExisting && candidates.length > 1) {
      throw StateError(
        'More than one matching item exists in that location. Edit inventory and keep one item per name and unit to merge automatically.',
      );
    }
    final now = DateTime.now();
    if (mergeExisting && candidates.length == 1) {
      final current = candidates.single;
      await (db.update(
        db.homeInventoryItems,
      )..where((row) => row.id.equals(current.id))).write(
        HomeInventoryItemsCompanion(
          quantityMilli: Value(
            current.quantityMilli + shoppingItem.quantityMilli,
          ),
          unitCostMinor: Value(
            shoppingItem.actualUnitPriceMinor ??
                shoppingItem.estimatedUnitPriceMinor ??
                current.unitCostMinor,
          ),
          purchasedAt: Value(shoppingItem.purchasedAt ?? now),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.homeInventoryItems)
          .insert(
            HomeInventoryItemsCompanion.insert(
              id: _uuid.v4(),
              name: shoppingItem.name,
              quantityMilli: shoppingItem.quantityMilli,
              unit: Value(shoppingItem.unit),
              category: Value(shoppingItem.category),
              location: Value(location.trim()),
              purchasedAt: Value(shoppingItem.purchasedAt ?? now),
              unitCostMinor: Value(
                shoppingItem.actualUnitPriceMinor ??
                    shoppingItem.estimatedUnitPriceMinor,
              ),
              notes: Value(shoppingItem.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await (db.update(db.groceryItems)..where((row) => row.id.equals(itemId)))
        .write(GroceryItemsCompanion(inventoryAppliedAt: Value(now)));
    return true;
  }

  Future<HomeInventoryItem?> _inventoryItem(String id) => (db.select(
    db.homeInventoryItems,
  )..where((item) => item.id.equals(id))).getSingleOrNull();

  void _validateInventoryInput(InventoryItemInput item) {
    if (item.name.trim().isEmpty || item.name.trim().length > 160) {
      throw ArgumentError('Enter an item name (up to 160 characters).');
    }
    if (item.quantityMilli < 0) {
      throw ArgumentError('Quantity cannot be negative.');
    }
    if (item.unit.trim().isEmpty || item.location.trim().isEmpty) {
      throw ArgumentError('Choose a unit and storage location.');
    }
    if ((item.unitCostMinor ?? 0) < 0) {
      throw ArgumentError('Unit cost cannot be negative.');
    }
  }

  Stream<List<GroceryList>> watchLists({bool archived = false}) =>
      (db.select(db.groceryLists)
            ..where((list) => list.isArchived.equals(archived))
            ..orderBy([(list) => OrderingTerm.desc(list.updatedAt)]))
          .watch();

  Future<List<GroceryList>> lists({bool archived = false}) =>
      (db.select(db.groceryLists)
            ..where((list) => list.isArchived.equals(archived))
            ..orderBy([(list) => OrderingTerm.desc(list.updatedAt)]))
          .get();

  Stream<List<GroceryItem>> watchItems(String listId) => (db.select(
    db.groceryItems,
  )..where((item) => item.listId.equals(listId))).watch();

  Future<List<GroceryItem>> items(String listId) => (db.select(
    db.groceryItems,
  )..where((item) => item.listId.equals(listId))).get();

  Future<void> saveList({
    String? id,
    required String name,
    String description = '',
    DateTime? targetAt,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 100) {
      throw ArgumentError('Enter a list name (up to 100 characters).');
    }
    final old = id == null ? null : await _list(id);
    if (id != null && old == null) throw StateError('List no longer exists.');
    final now = DateTime.now();
    await db
        .into(db.groceryLists)
        .insertOnConflictUpdate(
          GroceryListsCompanion(
            id: Value(id ?? _uuid.v4()),
            name: Value(clean),
            description: Value(description.trim()),
            targetAt: Value(targetAt),
            isArchived: Value(old?.isArchived ?? false),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<GroceryList?> _list(String id) => (db.select(
    db.groceryLists,
  )..where((list) => list.id.equals(id))).getSingleOrNull();

  Future<void> setArchived(String id, {required bool archived}) async {
    await (db.update(
      db.groceryLists,
    )..where((list) => list.id.equals(id))).write(
      GroceryListsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteList(String id) =>
      (db.delete(db.groceryLists)..where((list) => list.id.equals(id))).go();

  Future<void> saveItem({
    String? id,
    required String listId,
    required String name,
    required int quantityMilli,
    required String unit,
    required String category,
    int? estimatedUnitPriceMinor,
    int? actualUnitPriceMinor,
    String notes = '',
    bool? isPurchased,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 160) {
      throw ArgumentError('Enter an item name (up to 160 characters).');
    }
    if (quantityMilli <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }
    if ((estimatedUnitPriceMinor ?? 0) < 0 || (actualUnitPriceMinor ?? 0) < 0) {
      throw ArgumentError('Prices cannot be negative.');
    }
    final old = id == null ? null : await _item(id);
    if (id != null && old == null) throw StateError('Item no longer exists.');
    if (old != null && old.listId != listId) {
      throw ArgumentError(
        'An item cannot be moved to a different list while editing.',
      );
    }
    final purchased = isPurchased ?? old?.isPurchased ?? false;
    final now = DateTime.now();
    await db
        .into(db.groceryItems)
        .insertOnConflictUpdate(
          GroceryItemsCompanion(
            id: Value(id ?? _uuid.v4()),
            listId: Value(listId),
            name: Value(name.trim()),
            quantityMilli: Value(quantityMilli),
            unit: Value(unit.trim().isEmpty ? 'Other' : unit.trim()),
            category: Value(
              category.trim().isEmpty ? 'Other' : category.trim(),
            ),
            estimatedUnitPriceMinor: Value(estimatedUnitPriceMinor),
            actualUnitPriceMinor: Value(actualUnitPriceMinor),
            notes: Value(notes.trim()),
            isPurchased: Value(purchased),
            inventoryAppliedAt: Value(old?.inventoryAppliedAt),
            purchasedAt: Value(
              purchased ? (old?.purchasedAt ?? now) : old?.purchasedAt,
            ),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    await _touchList(listId);
  }

  Future<void> addShoppingItemsBulk(
    String listId,
    List<ShoppingItemInput> inputs,
  ) async {
    if (inputs.isEmpty) throw ArgumentError('Add at least one item.');
    final list = await _list(listId);
    if (list == null || list.isArchived) {
      throw StateError('Choose an active basket.');
    }
    for (final input in inputs) {
      if (input.name.trim().isEmpty || input.name.trim().length > 160) {
        throw ArgumentError('Every item needs a name (up to 160 characters).');
      }
      if (input.quantityMilli <= 0 || input.unit.trim().isEmpty) {
        throw ArgumentError('Every item needs a positive quantity and unit.');
      }
    }
    await db.transaction(() async {
      final now = DateTime.now();
      for (final input in inputs) {
        await db
            .into(db.groceryItems)
            .insert(
              GroceryItemsCompanion.insert(
                id: _uuid.v4(),
                listId: listId,
                name: input.name.trim(),
                quantityMilli: input.quantityMilli,
                unit: Value(input.unit.trim()),
                category: Value(
                  input.category.trim().isEmpty
                      ? 'Other'
                      : input.category.trim(),
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      await _touchList(listId);
    });
  }

  Future<GroceryItem?> _item(String id) => (db.select(
    db.groceryItems,
  )..where((item) => item.id.equals(id))).getSingleOrNull();

  Future<void> setPurchased(
    String id, {
    required bool purchased,
    int? actualUnitPriceMinor,
  }) async {
    if ((actualUnitPriceMinor ?? 0) < 0) {
      throw ArgumentError('Actual price cannot be negative.');
    }
    final item = await _item(id);
    if (item == null) throw StateError('Item no longer exists.');
    await (db.update(db.groceryItems)..where((row) => row.id.equals(id))).write(
      GroceryItemsCompanion(
        isPurchased: Value(purchased),
        actualUnitPriceMinor: Value(
          purchased
              ? actualUnitPriceMinor ?? item.actualUnitPriceMinor
              : item.actualUnitPriceMinor,
        ),
        purchasedAt: Value(
          purchased ? item.purchasedAt ?? DateTime.now() : null,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _touchList(item.listId);
  }

  Future<void> deleteItem(String id) async {
    final item = await _item(id);
    if (item == null) return;
    await (db.delete(db.groceryItems)..where((row) => row.id.equals(id))).go();
    await _touchList(item.listId);
  }

  Future<void> clearPurchased(String listId) async {
    await (db.delete(
      db.groceryItems,
    )..where((item) => item.listId.equals(listId) & item.isPurchased)).go();
    await _touchList(listId);
  }

  Future<void> _touchList(String id) =>
      (db.update(db.groceryLists)..where((list) => list.id.equals(id))).write(
        GroceryListsCompanion(updatedAt: Value(DateTime.now())),
      );

  Future<bool> hasRecordedPurchase(String itemId) async {
    final query = db.select(db.groceryPurchases).join([
      innerJoin(
        db.groceryPurchaseItems,
        db.groceryPurchaseItems.purchaseId.equalsExp(db.groceryPurchases.id),
      ),
    ])..where(db.groceryPurchaseItems.itemId.equals(itemId));
    final row = await query.getSingleOrNull();
    return row?.readTable(db.groceryPurchases).transactionId != null;
  }

  Future<String> purchaseModeForItems(List<String> itemIds) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return 'invalid';
    final links = await (db.select(
      db.groceryPurchaseItems,
    )..where((link) => link.itemId.isIn(ids))).get();
    if (links.isEmpty) return 'create';
    final purchaseIds = links.map((link) => link.purchaseId).toSet();
    if (purchaseIds.length != 1 || links.length != ids.length) return 'mixed';
    final purchase = await (db.select(
      db.groceryPurchases,
    )..where((row) => row.id.equals(purchaseIds.single))).getSingleOrNull();
    if (purchase == null) return 'mixed';
    final allLinks = await (db.select(
      db.groceryPurchaseItems,
    )..where((link) => link.purchaseId.equals(purchase.id))).get();
    if (allLinks.length != ids.length ||
        !allLinks.every((link) => ids.contains(link.itemId))) {
      return 'mixed';
    }
    if (purchase.transactionId == null) return 'create';
    final transaction =
        await (db.select(db.moneyTransactions)
              ..where((row) => row.id.equals(purchase.transactionId!)))
            .getSingleOrNull();
    return transaction == null ? 'create' : 'update';
  }

  Future<void> recordPurchase({
    required String listId,
    required List<String> itemIds,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    String note = '',
    Map<String, int?> actualUnitPricesMinor = const {},
    bool addPurchasedToInventory = false,
    String inventoryLocation = 'Pantry',
    bool mergePurchasedWithExisting = true,
  }) async {
    if (itemIds.isEmpty) throw ArgumentError('Select purchased items first.');
    if (amountMinor <= 0) {
      throw ArgumentError('Purchase amount must be greater than zero.');
    }
    await db.transaction(() async {
      final selected =
          await (db.select(db.groceryItems)..where(
                (item) => item.id.isIn(itemIds) & item.listId.equals(listId),
              ))
              .get();
      if (selected.length != itemIds.toSet().length ||
          selected.any((i) => !i.isPurchased)) {
        throw StateError('Select existing purchased items from this list.');
      }
      if (actualUnitPricesMinor.values.any((price) => (price ?? 0) < 0) ||
          actualUnitPricesMinor.keys.any((id) => !itemIds.contains(id))) {
        throw ArgumentError(
          'Enter valid actual prices for the selected items.',
        );
      }
      final account =
          await (db.select(db.moneyAccounts)..where(
                (row) => row.id.equals(accountId) & row.archivedAt.isNull(),
              ))
              .getSingleOrNull();
      if (account == null) {
        throw ArgumentError('Choose an active payment account.');
      }
      final category =
          await (db.select(db.moneyCategories)..where(
                (row) =>
                    row.id.equals(categoryId) &
                    row.type.equals('expense') &
                    row.archivedAt.isNull(),
              ))
              .getSingleOrNull();
      if (category == null) {
        throw ArgumentError('Choose an active expense category.');
      }

      final existingLinks = await (db.select(
        db.groceryPurchaseItems,
      )..where((link) => link.itemId.isIn(itemIds))).get();
      final purchaseIds = existingLinks.map((link) => link.purchaseId).toSet();
      if (purchaseIds.length > 1 ||
          (purchaseIds.isNotEmpty &&
              existingLinks.length != itemIds.toSet().length)) {
        throw StateError(
          'These items belong to different recorded bills. Select items from one bill at a time.',
        );
      }
      GroceryPurchase? purchase;
      if (purchaseIds.isNotEmpty) {
        purchase = await (db.select(
          db.groceryPurchases,
        )..where((row) => row.id.equals(purchaseIds.single))).getSingleOrNull();
        final allLinks = await (db.select(
          db.groceryPurchaseItems,
        )..where((link) => link.purchaseId.equals(purchase!.id))).get();
        if (purchase == null ||
            allLinks.map((link) => link.itemId).toSet().length !=
                itemIds.toSet().length) {
          throw StateError(
            'This is a combined bill. Select all of its items to edit the Money Manager expense.',
          );
        }
      }

      final now = DateTime.now();
      final purchaseId = purchase?.id ?? _uuid.v4();
      final transactionId = purchase?.transactionId ?? _uuid.v4();
      final oldTransaction = await (db.select(
        db.moneyTransactions,
      )..where((row) => row.id.equals(transactionId))).getSingleOrNull();
      final txn = MoneyTransactionsCompanion(
        id: Value(transactionId),
        type: const Value('expense'),
        amountMinor: Value(amountMinor),
        accountId: Value(accountId),
        destinationAccountId: const Value(null),
        categoryId: Value(categoryId),
        note: Value(note.trim()),
        occurredAt: Value(occurredAt.toLocal()),
        createdAt: Value(oldTransaction?.createdAt ?? now),
        updatedAt: Value(now),
        sourceModule: const Value('grocery'),
        sourceReferenceId: Value(purchaseId),
      );
      if (oldTransaction == null) {
        await db.into(db.moneyTransactions).insert(txn);
      } else {
        if (oldTransaction.type != 'expense' ||
            oldTransaction.sourceModule != 'grocery' ||
            oldTransaction.sourceReferenceId != purchaseId) {
          throw StateError(
            'The linked Money Manager record is no longer available to update.',
          );
        }
        await (db.update(
          db.moneyTransactions,
        )..where((row) => row.id.equals(transactionId))).write(txn);
      }
      await db
          .into(db.groceryPurchases)
          .insertOnConflictUpdate(
            GroceryPurchasesCompanion(
              id: Value(purchaseId),
              listId: Value(listId),
              transactionId: Value(transactionId),
              occurredAt: Value(occurredAt.toLocal()),
              note: Value(note.trim()),
              createdAt: Value(purchase?.createdAt ?? now),
            ),
          );
      if (purchase == null) {
        for (final itemId in itemIds.toSet()) {
          await db
              .into(db.groceryPurchaseItems)
              .insert(
                GroceryPurchaseItemsCompanion.insert(
                  id: _uuid.v4(),
                  purchaseId: purchaseId,
                  itemId: itemId,
                ),
              );
        }
      }
      for (final item in selected) {
        if (actualUnitPricesMinor.containsKey(item.id)) {
          await (db.update(
            db.groceryItems,
          )..where((row) => row.id.equals(item.id))).write(
            GroceryItemsCompanion(
              actualUnitPriceMinor: Value(actualUnitPricesMinor[item.id]),
              updatedAt: Value(now),
            ),
          );
        }
      }
      if (addPurchasedToInventory) {
        for (final item in selected) {
          await _receivePurchasedItem(
            itemId: item.id,
            location: inventoryLocation,
            addToInventory: true,
            mergeExisting: mergePurchasedWithExisting,
          );
        }
      }
      await _touchList(listId);
    });
  }

  Future<
    ({
      int remaining,
      int purchased,
      int? estimatedRemaining,
      List<GroceryItem> preview,
      int inventoryCount,
      int expiringSoon,
    })
  >
  dashboardSummary() async {
    final activeLists = await lists();
    final rows = <GroceryItem>[];
    for (final list in activeLists) {
      rows.addAll(await items(list.id));
    }
    final remainingRows = rows.where((item) => !item.isPurchased).toList();
    final purchased = rows.where((item) => item.isPurchased).length;
    final hasUnknown = remainingRows.any(
      (item) => item.estimatedUnitPriceMinor == null,
    );
    final estimate = remainingRows.fold<int>(
      0,
      (sum, item) =>
          sum +
          ((item.estimatedUnitPriceMinor ?? 0) * item.quantityMilli ~/ 1000),
    );
    final inventoryRows = await inventory();
    final currentTime = DateTime.now();
    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final expiryLimit = today.add(const Duration(days: 7));
    final expiringSoon = inventoryRows.where((item) {
      final expiry = item.expiryAt?.toLocal();
      if (expiry == null) return false;
      final day = DateTime(expiry.year, expiry.month, expiry.day);
      return !day.isBefore(today) && !day.isAfter(expiryLimit);
    }).length;
    return (
      remaining: remainingRows.length,
      purchased: purchased,
      estimatedRemaining: hasUnknown ? null : estimate,
      preview: remainingRows.take(3).toList(),
      inventoryCount: inventoryRows.length,
      expiringSoon: expiringSoon,
    );
  }
}
