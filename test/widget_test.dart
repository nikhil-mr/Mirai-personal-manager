import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:personal_manager/app/app.dart';
import 'package:personal_manager/app/router/app_router.dart';
import 'package:personal_manager/app/theme/theme_controller.dart';
import 'package:personal_manager/features/today/application/dashboard_providers.dart';
import 'package:personal_manager/features/today/data/today_dashboard_repository.dart';
import 'package:personal_manager/features/today/domain/dashboard_models.dart';
import 'package:personal_manager/features/money/application/money_providers.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/budgets/application/budget_providers.dart';
import 'package:personal_manager/features/budgets/domain/budget_models.dart';
import 'package:personal_manager/features/todos/application/task_providers.dart';
import 'package:personal_manager/features/todos/data/task_reminder_service.dart';
import 'package:personal_manager/features/places/application/places_providers.dart';

class _NoopTaskReminders implements TaskReminderService {
  @override
  Future<void> initialize() async {}
  @override
  Future<ReminderResult> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    required DateTime reminderAt,
    required String soundId,
    bool requestPermission = true,
  }) async => const ReminderResult(ReminderAvailability.scheduled);
  @override
  Future<void> cancel(int notificationId) async {}
  @override
  Future<void> reconcile(List<TaskReminderEntry> tasks) async {}
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({
    'life_partner_setup_complete_v1': true,
  });
  return SharedPreferences.getInstance();
}

List<dynamic> _moneyOverrides(MoneyDatabase database) => [
  moneyDatabaseProvider.overrideWithValue(database),
  moneyAccountsProvider.overrideWith(
    (ref) => Stream.value(const <MoneyAccount>[]),
  ),
  moneyActiveAccountsProvider.overrideWith(
    (ref) => Stream.value(const <MoneyAccount>[]),
  ),
  moneyTransactionsProvider.overrideWith(
    (ref) => Stream.value(const <MoneyTransaction>[]),
  ),
  moneyExpensesCategoriesProvider.overrideWith(
    (ref) => Stream.value(const <MoneyCategory>[]),
  ),
  moneyIncomeCategoriesProvider.overrideWith(
    (ref) => Stream.value(const <MoneyCategory>[]),
  ),
  moneyBalancesProvider.overrideWith((ref) async => <String, int>{}),
];

List<dynamic> _taskTestOverrides() => [
  taskReminderServiceProvider.overrideWithValue(_NoopTaskReminders()),
  tasksProvider.overrideWith((ref) => Stream.value(const <TaskRecord>[])),
  taskCategoriesProvider.overrideWith(
    (ref) => Stream.value(const <TaskCategory>[]),
  ),
];

final _fixedNow = DateTime(2026, 6, 15, 9);

Future<void> _pumpApp(
  WidgetTester tester, {
  DateTime? now,
  TodayDashboardRepository? repository,
}) async {
  final preferences = await _preferences();
  final database = MoneyDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        dashboardClockProvider.overrideWithValue(() => now ?? _fixedNow),
        ..._moneyOverrides(database),
        taskReminderServiceProvider.overrideWithValue(_NoopTaskReminders()),
        tasksProvider.overrideWith((ref) => Stream.value(const <TaskRecord>[])),
        savedPlacesProvider.overrideWith(
          (ref) => Stream.value(const <SavedPlace>[]),
        ),
        tripsProvider.overrideWith((ref) => Stream.value(const <TravelTrip>[])),
        taskCategoriesProvider.overrideWith(
          (ref) => Stream.value(const <TaskCategory>[]),
        ),
        if (repository != null)
          todayDashboardRepositoryProvider.overrideWithValue(repository),
      ],
      child: const LifePartnerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('launches on Today without invented activity', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Mirai'), findsOneWidget);
    expect(find.text('Good morning,'), findsOneWidget);
    expect(
      find.text(DateFormat('EEEE, MMMM d').format(_fixedNow)),
      findsOneWidget,
    );
    expect(find.text("Today's spending"), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('No places planned'), findsOneWidget);
    expect(
      find.text('Basket details will appear when Grocery Basket is connected.'),
      findsOneWidget,
    );
    expect(find.text('Bills & deadlines'), findsOneWidget);
  });

  testWidgets('creates a task from the To-do screen', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('To-do'));
    await tester.pumpAndSettle();
    expect(find.text('Your tasks'), findsOneWidget);
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task_title')),
      'Pay the utility bill',
    );
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsNothing);
    expect(find.text('Your tasks'), findsOneWidget);
  });

  testWidgets('uses the current local time for greeting and date', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 15, 18, 5);
    await _pumpApp(tester, now: now);

    expect(find.text('Good evening,'), findsOneWidget);
    expect(find.text(DateFormat('EEEE, MMMM d').format(now)), findsOneWidget);
  });

  testWidgets('renders supplied dashboard projections without fake records', (
    tester,
  ) async {
    final snapshot = TodayDashboardSnapshot(
      money: const DashboardMoneyTotals(
        spending: 42.5,
        income: 1250,
        currencyCode: 'USD',
      ),
      tasks: [
        DashboardTask(
          title: 'Send the proposal',
          dueAt: DateTime(2026, 6, 15, 10),
          priority: DashboardTaskPriority.high,
          reminderAt: DateTime(2026, 6, 15, 9, 45),
        ),
        DashboardTask(
          title: 'Review notes',
          dueAt: DateTime(2026, 6, 15, 8),
          isCompleted: true,
        ),
        DashboardTask(title: 'Future item', dueAt: DateTime(2026, 6, 16, 11)),
      ],
      places: [
        DashboardPlace(
          name: 'City Library',
          category: 'Work',
          plannedAt: DateTime(2026, 6, 15, 14),
        ),
      ],
      groceries: const DashboardGrocerySummary(
        activeItemCount: 4,
        remainingItemCount: 3,
        preview: [
          DashboardGroceryItem(name: 'Oats'),
          DashboardGroceryItem(name: 'Apples'),
        ],
      ),
      commitments: [
        DashboardCommitment(
          title: 'Rent',
          dueAt: DateTime(2026, 6, 20, 9),
          amount: 800,
          currencyCode: 'USD',
        ),
      ],
    );
    await _pumpApp(tester, repository: _DashboardRepository(snapshot));

    expect(find.textContaining('42.50'), findsOneWidget);
    expect(find.textContaining('1,250.00'), findsOneWidget);
    expect(find.text('1 of 2 tasks completed'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Send the proposal'), findsOneWidget);
    expect(find.text('Future item'), findsNothing);
    expect(find.text('City Library'), findsOneWidget);
    expect(find.text('4 active · 3 to purchase'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('dashboard cards open their related modules', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text("Today's spending"));
    await tester.pumpAndSettle();
    expect(find.text('Add your first account'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Task progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task progress'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(0);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View basket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View basket'));
    await tester.pumpAndSettle();
    expect(find.text('Your basket is empty'), findsOneWidget);
  });

  testWidgets('dashboard error state offers a retry', (tester) async {
    await _pumpApp(tester, repository: const _FailingDashboardRepository());

    expect(find.text('Your dashboard could not load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('places section opens Places & Trips', (tester) async {
    await _pumpApp(tester);
    await tester.ensureVisible(find.text('Places planned for today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all').first);
    await tester.pumpAndSettle();

    expect(find.text('No saved places yet'), findsOneWidget);
  });

  testWidgets('main navigation switches between all destinations', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Add your first account'), findsOneWidget);

    await tester.tap(find.text('To-do').last);
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);

    await tester.tap(find.text('Places').last);
    await tester.pumpAndSettle();
    expect(find.text('Saved places'), findsOneWidget);

    await tester.tap(find.text('Grocery').last);
    await tester.pumpAndSettle();
    expect(find.text('Shopping list'), findsOneWidget);
  });

  testWidgets('Money Manager opens transaction and account workflows', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Money Manager'), findsOneWidget);
    expect(find.text('Add your first account'), findsOneWidget);

    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Add transaction'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Money Manager opens the Budget Planner', (tester) async {
    final preferences = await _preferences();
    final database = MoneyDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ..._moneyOverrides(database),
        taskReminderServiceProvider.overrideWithValue(_NoopTaskReminders()),
        tasksProvider.overrideWith((ref) => Stream.value(const <TaskRecord>[])),
        taskCategoriesProvider.overrideWith(
          (ref) => Stream.value(const <TaskCategory>[]),
        ),
        budgetMonthProvider.overrideWith(
          (ref, month) async => BudgetMonthSnapshot(
            month: month,
            lines: const [],
            unbudgetedSpendMinor: 0,
            allExpenseMinor: 0,
            transactions: const [],
            alerts: const [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LifePartnerApp(),
      ),
    );
    router.go('/budgets');
    await tester.pumpAndSettle();
    expect(find.text('Budget Planner'), findsOneWidget);
    expect(find.textContaining('No budgets for'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Places and Grocery tabs open their real screens', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Places').last);
    await tester.pumpAndSettle();
    expect(find.text('No saved places yet'), findsOneWidget);
    await tester.tap(find.text('Grocery').last);
    await tester.pumpAndSettle();
    expect(find.text('Your basket is empty'), findsOneWidget);
  });

  testWidgets('appearance selection updates immediately and persists', (
    tester,
  ) async {
    final preferences = await _preferences();
    final database = MoneyDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ..._moneyOverrides(database),
          ..._taskTestOverrides(),
        ],
        child: const LifePartnerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(preferences.getString('appearance_mode'), 'dark');
  });

  testWidgets('dashboard renders with the saved dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({'appearance_mode': 'dark'});
    final preferences = await SharedPreferences.getInstance();
    final database = MoneyDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dashboardClockProvider.overrideWithValue(() => _fixedNow),
          ..._moneyOverrides(database),
          ..._taskTestOverrides(),
        ],
        child: const LifePartnerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Good morning,'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown paths show a recovery action', (tester) async {
    final preferences = await _preferences();
    final database = MoneyDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ..._moneyOverrides(database),
        ..._taskTestOverrides(),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LifePartnerApp(),
      ),
    );
    router.go('/unknown-page');
    await tester.pumpAndSettle();

    expect(find.text("We couldn't find that page"), findsOneWidget);
    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Good '), findsOneWidget);
  });

  testWidgets('adapts navigation for narrow and wide windows', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await _pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

class _DashboardRepository implements TodayDashboardRepository {
  const _DashboardRepository(this.snapshot);

  final TodayDashboardSnapshot snapshot;

  @override
  Future<TodayDashboardSnapshot> loadForDay(DateTime localDay) async =>
      snapshot;
}

class _FailingDashboardRepository implements TodayDashboardRepository {
  const _FailingDashboardRepository();

  @override
  Future<TodayDashboardSnapshot> loadForDay(DateTime localDay) =>
      Future.error(StateError('Dashboard source unavailable'));
}
