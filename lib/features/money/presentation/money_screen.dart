// Persisted icon code points are selected at runtime, so these IconData values
// cannot be compile-time constants.
// ignore_for_file: non_const_argument_for_const_parameter

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../application/money_providers.dart';
import '../data/money_database.dart';
import '../domain/money_models.dart';
import 'money_workflows.dart';

class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(moneyActiveAccountsProvider);
    final transactions = ref.watch(moneyTransactionsProvider);
    final balances = ref.watch(moneyBalancesProvider);
    final range =
        ref.watch(moneyCustomRangeProvider) ??
        MoneyRange.forPeriod(
          ref.watch(moneyPeriodProvider),
          ref.watch(moneyAnchorDateProvider),
        );
    return PageContainer(
      child: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorState(message: 'Accounts could not be loaded: $e'),
        data: (accountRows) => transactions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _ErrorState(message: 'Transactions could not be loaded: $e'),
          data: (allTransactions) => balances.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                _ErrorState(message: 'Balances could not be calculated: $e'),
            data: (balanceMap) => _MoneyDashboard(
              accounts: accountRows,
              transactions: allTransactions,
              balances: balanceMap,
              range: range,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyDashboard extends ConsumerWidget {
  const _MoneyDashboard({
    required this.accounts,
    required this.transactions,
    required this.balances,
    required this.range,
  });
  final List<MoneyAccount> accounts;
  final List<MoneyTransaction> transactions;
  final Map<String, int> balances;
  final MoneyRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(moneyPeriodProvider);
    final selectedDate = ref.watch(moneyAnchorDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    const allAccountsKey = '__all_accounts__';
    final primaryAccount = accounts
        .where((a) => a.isPrimary && a.archivedAt == null)
        .firstOrNull;

    final rawSelectedAccount = ref.watch(moneySelectedAccountProvider);
    final effectiveAccountId =
        rawSelectedAccount ?? (primaryAccount?.id ?? allAccountsKey);

    final isAllAccountsSelected =
        effectiveAccountId == allAccountsKey ||
        !accounts.any((a) => a.id == effectiveAccountId);

    final MoneyAccount? activeSelectedAccount = isAllAccountsSelected
        ? null
        : accounts.firstWhere((a) => a.id == effectiveAccountId);

    final scopedTransactions = isAllAccountsSelected
        ? transactions
        : transactions
              .where(
                (t) =>
                    t.accountId == effectiveAccountId ||
                    t.destinationAccountId == effectiveAccountId,
              )
              .toList();

    final inPeriod = scopedTransactions
        .where(
          (t) =>
              !t.occurredAt.isBefore(range.start) &&
              t.occurredAt.isBefore(range.end),
        )
        .toList();

    final expenses = inPeriod
        .where((t) => t.type == 'expense')
        .fold<int>(0, (sum, t) => sum + t.amountMinor);

    final income = inPeriod
        .where((t) => t.type == 'income')
        .fold<int>(0, (sum, t) => sum + t.amountMinor);

    final totalBalance = accounts.fold<int>(
      0,
      (sum, a) => sum + (balances[a.id] ?? a.openingBalanceMinor),
    );

    final selectedBalance = isAllAccountsSelected
        ? totalBalance
        : (balances[activeSelectedAccount!.id] ??
              activeSelectedAccount.openingBalanceMinor);

    final expenseCategories =
        ref.watch(moneyExpensesCategoriesProvider).value ??
        const <MoneyCategory>[];
    final incomeCategories =
        ref.watch(moneyIncomeCategoriesProvider).value ??
        const <MoneyCategory>[];
    final categoryMap = {
      for (final c in [...expenseCategories, ...incomeCategories]) c.id: c,
    };
    final accountMap = {for (final a in accounts) a.id: a};

    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Money Manager',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Your finances, in one place.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkSecondaryText
                : AppColors.lightSecondaryText,
          ),
        ),
      ],
    );

    final headerActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Manage accounts',
          onPressed: () => _open(context, const AccountManagementScreen()),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Transaction history',
          onPressed: () => _open(context, const TransactionHistoryScreen()),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerTitle),
              const SizedBox(width: 8),
              headerActions,
            ],
          ),
          const SizedBox(height: 16),
          _buildTotalBalanceCard(
            context: context,
            ref: ref,
            accounts: accounts,
            balances: balances,
            effectiveAccountId: effectiveAccountId,
            selectedAccount: activeSelectedAccount,
            isAllSelected: isAllAccountsSelected,
            selectedBalance: selectedBalance,
            isDark: isDark,
            borderColor: borderColor,
          ),
          const SizedBox(height: 16),
          _buildPeriodNavigationRow(
            context: context,
            ref: ref,
            period: period,
            selectedDate: selectedDate,
            range: range,
            isDark: isDark,
            borderColor: borderColor,
          ),
          const SizedBox(height: 12),
          _buildSummaryCardsRow(
            context: context,
            income: income,
            expenses: expenses,
            rangeLabel: _rangeLabel(range),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Spending analytics',
            subtitle: 'Expenses only. Transfers are excluded.',
          ),
          const SizedBox(height: 8),
          SpendingCharts(
            transactions: inPeriod,
            categories: categoryMap,
            period: period,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Recent transactions',
            subtitle: 'Latest activity across your accounts.',
            action: TextButton(
              onPressed: () => _open(context, const TransactionHistoryScreen()),
              child: const Text('View all'),
            ),
          ),
          if (inPeriod.isEmpty)
            const Card(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                message: 'Your recorded income, expenses, and transfers will appear here.',
                compact: true,
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final tx in inPeriod.take(6))
                    MoneyTransactionTile(
                      transaction: tx,
                      account: accountMap[tx.accountId],
                      destination: tx.destinationAccountId == null
                          ? null
                          : accountMap[tx.destinationAccountId],
                      category: categoryMap[tx.categoryId],
                      onTap: () => _open(
                        context,
                        TransactionDetailScreen(transactionId: tx.id),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard({
    required BuildContext context,
    required WidgetRef ref,
    required List<MoneyAccount> accounts,
    required Map<String, int> balances,
    required String effectiveAccountId,
    required MoneyAccount? selectedAccount,
    required bool isAllSelected,
    required int selectedBalance,
    required bool isDark,
    required Color borderColor,
  }) {
    const allAccountsKey = '__all_accounts__';

    final titleText = isAllSelected
        ? 'Total balance'
        : '${selectedAccount!.name} balance';

    final subtitleText = isAllSelected
        ? '${accounts.length} active account${accounts.length == 1 ? '' : 's'}'
        : _accountTypeName(selectedAccount!.type);

    final isPrimary = selectedAccount?.isPrimary ?? false;

    return BrutalCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 380;

          final balanceInfo = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.brand.withValues(alpha: 0.2)
                      : AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightText,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  selectedAccount != null
                      ? moneyIconForCodePoint(selectedAccount.iconCodePoint)
                      : Icons.account_balance_wallet_outlined,
                  color: isDark ? AppColors.brand : AppColors.lightText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMinorUnits(selectedBalance),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final selectorWidget = Column(
            crossAxisAlignment: isNarrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveAccountId,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: [
                      const DropdownMenuItem<String>(
                        value: allAccountsKey,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'All accounts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final account in accounts)
                        DropdownMenuItem<String>(
                          value: account.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                moneyIconForCodePoint(account.iconCodePoint),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                account.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(moneySelectedAccountProvider.notifier).state =
                            val == allAccountsKey ? null : val;
                      }
                    },
                  ),
                ),
              ),
              if (isPrimary) ...[
                const SizedBox(height: 6),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: AppColors.brand),
                    SizedBox(width: 3),
                    Text(
                      'Primary account',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                balanceInfo,
                const SizedBox(height: 12),
                selectorWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: balanceInfo),
              const SizedBox(width: 12),
              selectorWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodNavigationRow({
    required BuildContext context,
    required WidgetRef ref,
    required MoneyPeriod period,
    required DateTime selectedDate,
    required MoneyRange range,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<MoneyPeriod>(
              value: period,
              isDense: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              items: MoneyPeriod.values
                  .map(
                    (p) =>
                        DropdownMenuItem(value: p, child: Text(_periodName(p))),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                ref.read(moneyPeriodProvider.notifier).state = value;
                if (value == MoneyPeriod.custom && context.mounted) {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    ref
                        .read(moneyCustomRangeProvider.notifier)
                        .state = MoneyRange(
                      picked.start,
                      DateTime(
                        picked.end.year,
                        picked.end.month,
                        picked.end.day + 1,
                      ),
                    );
                  }
                } else {
                  ref.read(moneyCustomRangeProvider.notifier).state = null;
                }
              },
            ),
          ),
          const Spacer(),
          if (period != MoneyPeriod.custom) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 20,
              tooltip: 'Previous ${_periodName(period).toLowerCase()}',
              onPressed: () =>
                  ref.read(moneyAnchorDateProvider.notifier).state = _shift(
                    selectedDate,
                    period,
                    -1,
                  ),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 20,
              tooltip: 'Next ${_periodName(period).toLowerCase()}',
              onPressed: () =>
                  ref.read(moneyAnchorDateProvider.notifier).state = _shift(
                    selectedDate,
                    period,
                    1,
                  ),
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _rangeLabel(range),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsRow({
    required BuildContext context,
    required int income,
    required int expenses,
    required String rangeLabel,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: BrutalCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.south_west_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Income',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatMinorUnits(income),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rangeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BrutalCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        color: AppColors.pink,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  formatMinorUnits(expenses),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rangeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.lightSecondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SpendingCharts extends StatefulWidget {
  const SpendingCharts({
    required this.transactions,
    required this.categories,
    required this.period,
    super.key,
  });
  final List<MoneyTransaction> transactions;
  final Map<String, MoneyCategory> categories;
  final MoneyPeriod period;

  @override
  State<SpendingCharts> createState() => _SpendingChartsState();
}

class _SpendingChartsState extends State<SpendingCharts> {
  bool _lineChart = false;
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.transactions;
    final categories = widget.categories;
    final byCategory = <String, int>{};
    final byDay = <DateTime, int>{};
    final chartType = _income ? 'income' : 'expense';
    for (final tx in transactions.where((t) => t.type == chartType)) {
      final categoryId = tx.categoryId ?? '__uncategorized__';
      if (categoryId.isNotEmpty) {
        byCategory.update(
          categoryId,
          (n) => n + tx.amountMinor,
          ifAbsent: () => tx.amountMinor,
        );
      }
      final date = widget.period == MoneyPeriod.year
          ? DateTime(tx.occurredAt.year, tx.occurredAt.month)
          : DateTime(
              tx.occurredAt.year,
              tx.occurredAt.month,
              tx.occurredAt.day,
            );
      byDay.update(
        date,
        (n) => n + tx.amountMinor,
        ifAbsent: () => tx.amountMinor,
      );
    }
    final total = byCategory.values.fold<int>(0, (sum, n) => sum + n);
    final chartTitle = _income ? 'Income by category' : 'Expenses by category';
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 740;
        final width = wide
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        final pie = PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (var i = 0; i < entries.length; i++)
              PieChartSectionData(
                value: entries[i].value.toDouble(),
                title: '',
                radius: 44,
                color: categories[entries[i].key] == null
                    ? AppColors.chart[i % AppColors.chart.length]
                    : Color(categories[entries[i].key]!.colorValue),
              ),
          ],
        );
        final bars = BarChartData(
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].value / 100,
                    color: AppColors.brand,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: days.length > 8 ? 3 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  return index >= 0 && index < days.length
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.period == MoneyPeriod.year
                                ? DateFormat.MMM().format(days[index].key)
                                : DateFormat.Md().format(days[index].key),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: _rupeeAxis,
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        );
        final line = LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < days.length; i++)
                  FlSpot(i.toDouble(), days[i].value / 100),
              ],
              isCurved: true,
              color: AppColors.brand,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
        );
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chartTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Expenses'),
                              ),
                              ButtonSegment(value: true, label: Text('Income')),
                            ],
                            selected: {_income},
                            onSelectionChanged: (selection) =>
                                setState(() => _income = selection.first),
                            showSelectedIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: total == 0
                            ? const Center(
                                child: SingleChildScrollView(
                                  physics: NeverScrollableScrollPhysics(),
                                  child: EmptyState(
                                    icon: Icons.pie_chart_outline,
                                    title: 'No data for this period',
                                    message: 'This chart will appear after you record activity.',
                                    compact: true,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(child: PieChart(pie)),
                                  Expanded(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final entry in entries.take(5))
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              '${entry.key == '__uncategorized__' ? 'Uncategorized' : categories[entry.key]?.name ?? 'Archived category'} · ${(entry.value * 100 / total).toStringAsFixed(0)}%  ${formatMinorUnits(entry.value)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                              maxLines: 2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Spending trend',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.bar_chart),
                                tooltip: 'Bar chart',
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.show_chart),
                                tooltip: 'Line chart',
                              ),
                            ],
                            selected: {_lineChart},
                            onSelectionChanged: (selection) =>
                                setState(() => _lineChart = selection.first),
                            showSelectedIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: days.isEmpty
                            ? const Center(
                                child: SingleChildScrollView(
                                  physics: NeverScrollableScrollPhysics(),
                                  child: EmptyState(
                                    icon: Icons.show_chart,
                                    title: 'No trend data',
                                    message: 'This chart will appear after you record activity.',
                                    compact: true,
                                  ),
                                ),
                              )
                            : (_lineChart ? LineChart(line) : BarChart(bars)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _rupeeAxis(double value, TitleMeta meta) => SideTitleWidget(
  meta: meta,
  child: Text(
    value == 0 ? '0' : '₹${value.toInt()}',
    style: const TextStyle(fontSize: 9),
  ),
);

class MoneyTransactionTile extends StatelessWidget {
  const MoneyTransactionTile({
    required this.transaction,
    required this.account,
    required this.destination,
    required this.category,
    required this.onTap,
    super.key,
  });
  final MoneyTransaction transaction;
  final MoneyAccount? account;
  final MoneyAccount? destination;
  final MoneyCategory? category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = transaction.type == 'income'
        ? AppColors.success
        : transaction.type == 'expense'
        ? AppColors.warning
        : Theme.of(context).colorScheme.primary;
    final amountPrefix = transaction.type == 'income'
        ? '+'
        : transaction.type == 'expense'
        ? '−'
        : '↔ ';
    final title = transaction.type == 'transfer'
        ? '${account?.name ?? 'Account'} → ${destination?.name ?? 'Account'}'
        : category?.name ?? 'Archived category';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(
          moneyIconForCodePoint(
            category?.iconCodePoint ??
                (transaction.type == 'transfer'
                    ? Icons.swap_horiz.codePoint
                    : Icons.receipt_long.codePoint),
          ),
          color: color,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        '${transaction.type[0].toUpperCase()}${transaction.type.substring(1)} · ${DateFormat.yMMMd().add_jm().format(transaction.occurredAt.toLocal())} · ${account?.name ?? 'Archived account'}',
      ),
      trailing: Text(
        '$amountPrefix${formatMinorUnits(transaction.amountMinor)}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: EmptyState(
      icon: Icons.error_outline,
      title: 'Money Manager could not load',
      message: message,
    ),
  );
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
String _periodName(MoneyPeriod period) => switch (period) {
  MoneyPeriod.day => 'Day',
  MoneyPeriod.week => 'Week',
  MoneyPeriod.month => 'Month',
  MoneyPeriod.year => 'Year',
  MoneyPeriod.custom => 'Custom range',
};
String _accountTypeName(String type) => switch (type) {
  'bank' => 'Bank account',
  'cash' => 'Cash wallet',
  _ => 'Other account',
};
String _rangeLabel(MoneyRange range) =>
    '${DateFormat.yMMMd().format(range.start)}${range.end.difference(range.start).inDays > 1 ? ' – ${DateFormat.yMMMd().format(range.end.subtract(const Duration(days: 1)))}' : ''}';
DateTime _shift(DateTime date, MoneyPeriod period, int direction) =>
    switch (period) {
      MoneyPeriod.day => date.add(Duration(days: direction)),
      MoneyPeriod.week => date.add(Duration(days: 7 * direction)),
      MoneyPeriod.month => DateTime(date.year, date.month + direction, 1),
      MoneyPeriod.year => DateTime(date.year + direction, date.month, 1),
      MoneyPeriod.custom => date,
    };
