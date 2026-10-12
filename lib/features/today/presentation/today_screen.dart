import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_card.dart';
import '../application/dashboard_providers.dart';
import '../application/dashboard_visibility.dart';
import '../domain/dashboard_calculations.dart';
import '../domain/dashboard_models.dart';
import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../../money/domain/money_models.dart';
import '../../todos/application/task_providers.dart';
import 'widgets/dashboard_task_tile.dart';
import 'widgets/task_progress_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _clockTimer;
  MoneyPeriod _period = MoneyPeriod.day;
  late DateTime _anchor;

  DateTime get _localDay => DateTime(_now.year, _now.month, _now.day);

  @override
  void initState() {
    super.initState();
    _now = ref.read(dashboardClockProvider)().toLocal();
    _anchor = DateTime(_now.year, _now.month, _now.day);
    WidgetsBinding.instance.addObserver(this);
    _scheduleClockRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(taskRepositoryProvider).reconcileReminders();
      _refreshClock(refreshData: true);
    }
  }

  void _refreshClock({required bool refreshData}) {
    if (!mounted) return;
    final updated = ref.read(dashboardClockProvider)().toLocal();
    final dayChanged = !isSameLocalDay(_now, updated);
    setState(() => _now = updated);
    if (refreshData || dayChanged) {
      ref.invalidate(todayDashboardSnapshotProvider);
    }
    _scheduleClockRefresh();
  }

  void _scheduleClockRefresh() {
    _clockTimer?.cancel();
    final now = _now;
    final boundary = now.hour < 12
        ? DateTime(now.year, now.month, now.day, 12)
        : now.hour < 17
        ? DateTime(now.year, now.month, now.day, 17)
        : DateTime(now.year, now.month, now.day + 1);
    _clockTimer = Timer(
      boundary.difference(now) + const Duration(milliseconds: 100),
      () {
        _refreshClock(refreshData: false);
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = _localDay;
    final snapshot = ref.watch(todayDashboardSnapshotProvider(day));
    final transactions = ref.watch(moneyTransactionsProvider).asData?.value;
    final categories = ref.watch(moneyExpensesCategoriesProvider).asData?.value;
    final visibility = ref.watch(dashboardVisibilityProvider);
    return PageContainer(
      child: snapshot.when(
        loading: () => const _DashboardLoading(),
        error: (error, stackTrace) => _DashboardError(
          onRetry: () => ref.invalidate(todayDashboardSnapshotProvider(day)),
        ),
        data: (data) => _DashboardContent(
          now: _now,
          day: day,
          data: data,
          visibility: visibility,
          period: _period,
          anchor: _anchor,
          transactions: transactions ?? const [],
          categories: categories ?? const [],
          onPeriodChanged: (period) => setState(() => _period = period),
          onAnchorChanged: (anchor) => setState(() => _anchor = anchor),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.now,
    required this.day,
    required this.data,
    required this.visibility,
    required this.period,
    required this.anchor,
    required this.transactions,
    required this.categories,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  final DateTime now;
  final DateTime day;
  final TodayDashboardSnapshot data;
  final DashboardVisibility visibility;
  final MoneyPeriod period;
  final DateTime anchor;
  final List<MoneyTransaction> transactions;
  final List<MoneyCategory> categories;
  final ValueChanged<MoneyPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final progress = calculateTaskProgress(data.tasks ?? const [], day);
      final upcomingTasks = upcomingTasksForDay(data.tasks ?? const [], day);
      final range = MoneyRange.forPeriod(period, anchor);
      final periodTransactions = transactions.where((transaction) {
        final occurred = transaction.occurredAt.toLocal();
        return !occurred.isBefore(range.start) && occurred.isBefore(range.end);
      }).toList();
      final spending = periodTransactions
          .where((transaction) => transaction.type == 'expense')
          .fold<int>(
            0,
            (total, transaction) => total + transaction.amountMinor,
          );
      final income = periodTransactions
          .where((transaction) => transaction.type == 'income')
          .fold<int>(
            0,
            (total, transaction) => total + transaction.amountMinor,
          );
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              _greetingFor(now),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM d').format(anchor),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _PeriodCard(
              period: period,
              anchor: anchor,
              onPeriodChanged: onPeriodChanged,
              onAnchorChanged: onAnchorChanged,
            ),
            const SizedBox(height: 24),
            if (visibility.isVisible(DashboardSection.money)) ...[
              SectionHeader(
                title: 'Your money today',
                subtitle: 'A quick look at what is coming in and going out.',
                action: TextButton(
                  onPressed: () => context.go(AppRoutes.money),
                  child: const Text('Money'),
                ),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: wide ? 1.8 : 0.8,
                children: [
                  SummaryCard(
                    label: "Today's spending",
                    icon: Icons.north_east_rounded,
                    tint: AppColors.warning,
                    value: _formatMinorMoney(context, spending),
                    supportingText: _periodLabel(period),
                    onTap: () => context.go(AppRoutes.money),
                  ),
                  SummaryCard(
                    label: "Today's income",
                    icon: Icons.south_west_rounded,
                    tint: AppColors.success,
                    value: _formatMinorMoney(context, income),
                    supportingText: _periodLabel(period),
                    onTap: () => context.go(AppRoutes.money),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (visibility.isVisible(DashboardSection.money)) ...[
              _SpendingBreakdown(
                transactions: periodTransactions,
                categories: categories,
                onViewAll: () => context.go(AppRoutes.money),
              ),
              const SizedBox(height: 24),
            ],
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (visibility.isVisible(DashboardSection.taskProgress))
                    Expanded(
                      child: TaskProgressCard(
                        progress: progress,
                        onTap: () => context.go(AppRoutes.todos),
                      ),
                    ),
                  if (visibility.isVisible(DashboardSection.taskProgress) &&
                      visibility.isVisible(DashboardSection.places))
                    const SizedBox(width: 16),
                  if (visibility.isVisible(DashboardSection.places))
                    Expanded(
                      child: _PlacesCard(
                        places: data.places,
                        onViewAll: () => context.go(AppRoutes.places),
                      ),
                    ),
                ],
              )
            else ...[
              if (visibility.isVisible(DashboardSection.taskProgress)) ...[
                TaskProgressCard(
                  progress: progress,
                  onTap: () => context.go(AppRoutes.todos),
                ),
                const SizedBox(height: 18),
              ],
              if (visibility.isVisible(DashboardSection.places)) ...[
                _PlacesCard(
                  places: data.places,
                  onViewAll: () => context.go(AppRoutes.places),
                ),
                const SizedBox(height: 18),
              ],
            ],
            if (visibility.isVisible(DashboardSection.upcomingTasks)) ...[
              const SizedBox(height: 24),
              _UpcomingTasksCard(
                tasks: data.tasks,
                upcoming: upcomingTasks,
                onViewAll: () => context.go(AppRoutes.todos),
              ),
            ],
            if (visibility.isVisible(DashboardSection.groceries)) ...[
              const SizedBox(height: 18),
              _GroceryCard(
                summary: data.groceries,
                onViewBasket: () => context.go(AppRoutes.groceries),
              ),
            ],
            if (visibility.isVisible(DashboardSection.commitments)) ...[
              const SizedBox(height: 24),
              _CommitmentsCard(
                commitments: data.commitments,
                onViewAll: () => context.go(AppRoutes.money),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning,';
  if (now.hour < 17) return 'Good afternoon,';
  return 'Good evening,';
}

String _formatMoney(BuildContext context, num amount, String currencyCode) =>
    NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      name: currencyCode,
    ).format(amount);

String _formatMinorMoney(BuildContext context, int amountMinor) =>
    formatMinorUnits(amountMinor);

String _periodLabel(MoneyPeriod period) => switch (period) {
  MoneyPeriod.day => 'Recorded today',
  MoneyPeriod.week => 'Recorded this week',
  MoneyPeriod.month => 'Recorded this month',
  MoneyPeriod.year => 'Recorded this year',
  MoneyPeriod.custom => 'Recorded in period',
};

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onAnchorChanged,
  });

  final MoneyPeriod period;
  final DateTime anchor;
  final ValueChanged<MoneyPeriod> onPeriodChanged;
  final ValueChanged<DateTime> onAnchorChanged;

  @override
  Widget build(BuildContext context) {
    final range = MoneyRange.forPeriod(period, anchor);
    final label = switch (period) {
      MoneyPeriod.day => DateFormat('EEE, MMM d').format(anchor),
      MoneyPeriod.week =>
        '${DateFormat('MMM d').format(range.start)} - '
            '${DateFormat('MMM d').format(range.end.subtract(const Duration(days: 1)))}',
      MoneyPeriod.month => DateFormat('MMMM yyyy').format(anchor),
      MoneyPeriod.year => DateFormat('yyyy').format(anchor),
      MoneyPeriod.custom => DateFormat('MMM d, yyyy').format(anchor),
    };
    return BrutalCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in const [
                  MoneyPeriod.day,
                  MoneyPeriod.week,
                  MoneyPeriod.month,
                  MoneyPeriod.year,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_periodName(option)),
                      selected: period == option,
                      onSelected: (_) => onPeriodChanged(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous ${_periodName(period).toLowerCase()}',
                onPressed: () =>
                    onAnchorChanged(_shiftAnchor(anchor, period, -1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next ${_periodName(period).toLowerCase()}',
                onPressed: () =>
                    onAnchorChanged(_shiftAnchor(anchor, period, 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (period == MoneyPeriod.day) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 9,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = anchor.add(Duration(days: index - 4));
                  final selected = isSameLocalDay(date, anchor);
                  return InkWell(
                    onTap: () => onAnchorChanged(date),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.brand
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE').format(date),
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${date.day}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _periodName(MoneyPeriod period) => switch (period) {
  MoneyPeriod.day => 'Day',
  MoneyPeriod.week => 'Week',
  MoneyPeriod.month => 'Month',
  MoneyPeriod.year => 'Year',
  MoneyPeriod.custom => 'Custom',
};

DateTime _shiftAnchor(DateTime anchor, MoneyPeriod period, int amount) {
  switch (period) {
    case MoneyPeriod.day:
      return anchor.add(Duration(days: amount));
    case MoneyPeriod.week:
      return anchor.add(Duration(days: amount * 7));
    case MoneyPeriod.month:
      final target = DateTime(anchor.year, anchor.month + amount, 1);
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      return DateTime(target.year, target.month, anchor.day.clamp(1, lastDay));
    case MoneyPeriod.year:
      final target = DateTime(anchor.year + amount, anchor.month, 1);
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      return DateTime(target.year, target.month, anchor.day.clamp(1, lastDay));
    case MoneyPeriod.custom:
      return anchor.add(Duration(days: amount));
  }
}

class _SpendingBreakdown extends StatelessWidget {
  const _SpendingBreakdown({
    required this.transactions,
    required this.categories,
    required this.onViewAll,
  });

  final List<MoneyTransaction> transactions;
  final List<MoneyCategory> categories;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final expenses = transactions.where((item) => item.type == 'expense');
    final totals = <String, int>{};
    for (final transaction in expenses) {
      final key = transaction.categoryId ?? 'uncategorized';
      totals[key] = (totals[key] ?? 0) + transaction.amountMinor;
    }
    final total = totals.values.fold<int>(0, (sum, value) => sum + value);
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Spending breakdown',
            action: TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No expenses recorded for this period.'),
            )
          else ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  for (final entry in totals.entries)
                    Expanded(
                      flex: entry.value,
                      child: Container(
                        height: 14,
                        color: _categoryColor(entry.key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in totals.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _categoryColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(categoryNames[entry.key] ?? 'Uncategorized'),
                    ),
                    Text('${(entry.value * 100 / total).round()}%'),
                    const SizedBox(width: 12),
                    Text(formatMinorUnits(entry.value)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Color _categoryColor(String key) {
  final index = key.hashCode.abs() % AppColors.chart.length;
  return AppColors.chart[index];
}

class _PlacesCard extends StatelessWidget {
  const _PlacesCard({required this.places, required this.onViewAll});

  final List<DashboardPlace>? places;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: SectionHeader(
            title: 'Places planned for today',
            action: TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ),
        ),
        if (places == null)
          const EmptyState(
            icon: Icons.place_outlined,
            title: 'Places are not connected yet',
            message: 'Today’s destinations will appear when Places & Trips is available.',
            compact: true,
          )
        else if (places!.isEmpty)
          EmptyState(
            icon: Icons.place_outlined,
            title: 'No places planned',
            message: 'Save a destination or plan a trip to see it here.',
            action: OutlinedButton(
              onPressed: onViewAll,
              child: const Text('Explore places'),
            ),
            compact: true,
          )
        else
          for (final place in places!.take(2)) _PlaceTile(place: place),
      ],
    ),
  );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place});
  final DashboardPlace place;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (place.category != null) place.category!,
      if (place.plannedAt != null)
        DateFormat.jm().format(place.plannedAt!.toLocal()),
      if (place.tripName != null) place.tripName!,
    ];
    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      onTap: place.id == null
          ? () => context.go(AppRoutes.places)
          : () => context.go(
              '${AppRoutes.places}/${Uri.encodeComponent(place.id!)}',
            ),
    );
  }
}

class _UpcomingTasksCard extends StatelessWidget {
  const _UpcomingTasksCard({
    required this.tasks,
    required this.upcoming,
    required this.onViewAll,
  });

  final List<DashboardTask>? tasks;
  final List<DashboardTask> upcoming;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: SectionHeader(
            title: 'Up next',
            subtitle: 'Tasks and reminders for today.',
            action: TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ),
        ),
        if (tasks == null)
          const EmptyState(
            icon: Icons.checklist_outlined,
            title: 'To-do is not connected yet',
            message: 'Your pending tasks and reminders will appear here when the To-do list is available.',
            compact: true,
          )
        else if (upcoming.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nothing else planned today',
            message: 'Tasks scheduled for today will appear here.',
            compact: true,
          )
        else ...[
          for (final task in upcoming.take(3)) ...[
            DashboardTaskTile(task: task),
            if (task != upcoming.take(3).last)
              const Divider(height: 1, indent: 48, endIndent: 16),
          ],
        ],
      ],
    ),
  );
}

class _GroceryCard extends StatelessWidget {
  const _GroceryCard({required this.summary, required this.onViewBasket});

  final DashboardGrocerySummary? summary;
  final VoidCallback onViewBasket;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onViewBasket,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grocery Basket',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (summary == null)
                    Text(
                      'Basket details will appear when Grocery Basket is connected.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (summary!.activeItemCount == 0 &&
                      summary!.inventoryItemCount == 0)
                    Text(
                      'Your basket is empty. Add shopping items in Grocery Basket.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    Text(
                      '${summary!.remainingItemCount} to buy · ${summary!.activeItemCount - summary!.remainingItemCount} purchased',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (summary!.inventoryItemCount > 0)
                      Text(
                        '${summary!.inventoryItemCount} items currently at home',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (summary!.expiringSoonCount > 0)
                      Text(
                        '${summary!.expiringSoonCount} expiring within 7 days',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (summary!.estimatedRemainingMinor != null)
                      Text(
                        'Estimated remaining ${_formatMoney(context, summary!.estimatedRemainingMinor! / 100, 'INR')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (summary!.preview.isNotEmpty)
                      Text(
                        summary!.preview
                            .take(2)
                            .map(
                              (item) => item.quantity == null
                                  ? item.name
                                  : '${item.name} (${item.quantity})',
                            )
                            .join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewBasket,
              child: const Text('View basket'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.commitments, required this.onViewAll});

  final List<DashboardCommitment>? commitments;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final sorted = commitments == null
        ? const <DashboardCommitment>[]
        : sortUpcomingCommitments(commitments!);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: SectionHeader(
              title: 'Bills & deadlines',
              subtitle: 'Upcoming financial commitments and dates.',
              action: TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ),
          ),
          if (commitments == null)
            const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Nothing due yet',
              message: 'Bills and deadlines will appear here when those features are available.',
              compact: true,
            )
          else if (sorted.isEmpty)
            const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming bills or deadlines',
              message:
                  'You’ll see upcoming commitments here when you add them.',
              compact: true,
            )
          else
            for (final item in sorted.take(3))
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(item.title),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(item.dueAt.toLocal()),
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.amount != null && item.currencyCode != null)
                      Text(
                        _formatMoney(context, item.amount!, item.currencyCode!),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (item.status != null)
                      Text(
                        item.status!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your day…'),
        ],
      ),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Your dashboard could not load',
        message: 'Check again to refresh today’s overview.',
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    ),
  );
}
