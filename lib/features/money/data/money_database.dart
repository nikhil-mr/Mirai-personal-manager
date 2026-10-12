import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'money_database.g.dart';

class MoneyAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()();
  IntColumn get openingBalanceMinor => integer()();
  IntColumn get iconCodePoint => integer().nullable()();
  IntColumn get colorValue => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text()();
  IntColumn get iconCodePoint => integer()();
  IntColumn get colorValue => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Auditable manual corrections to an account's running balance. These are
/// excluded from income and expense reports.
class AccountBalanceAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(MoneyAccounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A transfer is one row: accountId is its source, destinationAccountId its
/// destination. It never enters income/expense aggregates.
class MoneyTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  @ReferenceName('sourceTransactions')
  TextColumn get accountId => text().references(MoneyAccounts, #id)();
  @ReferenceName('destinationTransactions')
  TextColumn get destinationAccountId =>
      text().nullable().references(MoneyAccounts, #id)();
  TextColumn get categoryId =>
      text().nullable().references(MoneyCategories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get sourceModule => text().withDefault(const Constant('manual'))();
  TextColumn get sourceReferenceId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BudgetPlans extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(MoneyCategories, #id)();
  IntColumn get baseAmountMinor => integer()();
  DateTimeColumn get periodStart => dateTime()();
  BoolColumn get rolloverEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get alert80Enabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get alert100Enabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {categoryId, periodStart},
  ];
}

class BudgetAlertStates extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId => text().references(BudgetPlans, #id)();
  DateTimeColumn get periodStart => dateTime()();
  IntColumn get threshold => integer()();
  BoolColumn get isAbove => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastTriggeredAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {budgetId, periodStart, threshold},
  ];
}

class TaskCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF087F72))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskRecords extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get categoryId =>
      text().nullable().references(TaskCategories, #id)();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueHasTime => boolean().withDefault(const Constant(false))();
  BoolColumn get includeInToday =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notificationSoundId =>
      text().withDefault(const Constant('default'))();
  IntColumn get reminderNotificationId => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SavedPlaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get mapUrl => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get plannedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  IntColumn get rating => integer().nullable()();
  TextColumn get review => text().withDefault(const Constant(''))();
  DateTimeColumn get visitedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TravelTrips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get destination => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  IntColumn get budgetMinor => integer().nullable()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TripPlaces extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(TravelTrips, #id, onDelete: KeyAction.cascade)();
  TextColumn get placeId =>
      text().references(SavedPlaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get itineraryOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get plannedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {tripId, placeId},
  ];
}

class TripEstimates extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(TravelTrips, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text().withLength(min: 1, max: 160)();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  DateTimeColumn get occurredAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Associates a trip with an existing Money Manager expense transaction.
/// Removing this row never deletes the transaction itself.
class TripExpenseLinks extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(TravelTrips, #id, onDelete: KeyAction.cascade)();
  TextColumn get transactionId =>
      text().references(MoneyTransactions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {transactionId},
  ];
}

class GroceryLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get targetAt => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class GroceryItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(GroceryLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  IntColumn get quantityMilli => integer()();
  TextColumn get unit => text().withDefault(const Constant('Piece'))();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  IntColumn get estimatedUnitPriceMinor => integer().nullable()();
  IntColumn get actualUnitPriceMinor => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
  DateTimeColumn get purchasedAt => dateTime().nullable()();
  DateTimeColumn get inventoryAppliedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class GroceryPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(GroceryLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get transactionId => text().nullable().unique().references(
    MoneyTransactions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class GroceryPurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId =>
      text().references(GroceryPurchases, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId =>
      text().references(GroceryItems, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {itemId},
  ];
}

/// Supplies currently on hand, distinct from GroceryItems planned for shopping.
class HomeInventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  IntColumn get quantityMilli => integer()();
  TextColumn get unit => text().withDefault(const Constant('Piece'))();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get location => text().withDefault(const Constant('Pantry'))();
  DateTimeColumn get expiryAt => dateTime().nullable()();
  DateTimeColumn get purchasedAt => dateTime().nullable()();
  IntColumn get unitCostMinor => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    MoneyAccounts,
    MoneyCategories,
    AccountBalanceAdjustments,
    MoneyTransactions,
    BudgetPlans,
    BudgetAlertStates,
    TaskCategories,
    TaskRecords,
    SavedPlaces,
    TravelTrips,
    TripPlaces,
    TripEstimates,
    TripExpenseLinks,
    GroceryLists,
    GroceryItems,
    GroceryPurchases,
    GroceryPurchaseItems,
    HomeInventoryItems,
  ],
)
class MoneyDatabase extends _$MoneyDatabase {
  MoneyDatabase(super.executor);

  factory MoneyDatabase.open() => MoneyDatabase(
    driftDatabase(
      name: 'life_partner_money',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgetPlans);
        await m.createTable(budgetAlertStates);
      }
      if (from < 3) {
        await m.createTable(taskCategories);
        await m.createTable(taskRecords);
      }
      if (from < 4) {
        await m.createTable(savedPlaces);
        await m.createTable(travelTrips);
        await m.createTable(tripPlaces);
        await m.createTable(tripEstimates);
        await m.createTable(tripExpenseLinks);
      }
      if (from >= 4 && from < 5) {
        await m.addColumn(savedPlaces, savedPlaces.mapUrl);
      }
      if (from < 6) {
        await m.createTable(groceryLists);
        await m.createTable(groceryItems);
        await m.createTable(groceryPurchases);
        await m.createTable(groceryPurchaseItems);
      }
      if (from < 7) {
        await m.createTable(accountBalanceAdjustments);
      }
      if (from < 8) {
        await m.createTable(homeInventoryItems);
        try {
          await m.addColumn(groceryItems, groceryItems.inventoryAppliedAt);
        } catch (_) {}
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS money_transactions_date ON money_transactions (occurred_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS money_transactions_account ON money_transactions (account_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS money_transactions_category ON money_transactions (category_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS account_balance_adjustments_account ON account_balance_adjustments (account_id, occurred_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS task_records_due_at ON task_records (due_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS task_records_completed ON task_records (is_completed)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS task_records_reminder ON task_records (reminder_enabled, reminder_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS saved_places_planned ON saved_places (status, planned_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS trip_places_trip_order ON trip_places (trip_id, itinerary_order)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS trip_expense_links_trip ON trip_expense_links (trip_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS grocery_items_list_purchased ON grocery_items (list_id, is_purchased)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS grocery_purchases_list ON grocery_purchases (list_id)',
      );
    },
  );
}
