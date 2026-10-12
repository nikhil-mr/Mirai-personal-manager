// Persisted icon code points are selected at runtime, so these IconData values
// cannot be compile-time constants.
// ignore_for_file: non_const_argument_for_const_parameter

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_card.dart';
import '../application/money_providers.dart';
import '../data/money_database.dart';
import '../domain/money_models.dart';
import 'money_workflows.dart';
import 'money_excel_workflows.dart';

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
    final selectedAccount = ref.watch(moneySelectedAccountProvider);
    const allAccountsKey = '__all_accounts__';
    const bothAccountsKey = '__both_accounts__';
    final scopedTransactions =
        selectedAccount == null ||
            selectedAccount == allAccountsKey ||
            selectedAccount == bothAccountsKey
        ? transactions
        : transactions
              .where(
                (t) =>
                    t.accountId == selectedAccount ||
                    t.destinationAccountId == selectedAccount,
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
      (sum, a) =>
          selectedAccount != null &&
              selectedAccount != allAccountsKey &&
              selectedAccount != bothAccountsKey &&
              a.id != selectedAccount
          ? sum
          : sum + (balances[a.id] ?? a.openingBalanceMinor),
    );
    final selectedBalance =
        selectedAccount != null &&
            selectedAccount != allAccountsKey &&
            selectedAccount != bothAccountsKey
        ? (balances[selectedAccount] ??
              accounts
                  .where((a) => a.id == selectedAccount)
                  .fold<int>(0, (sum, a) => sum + a.openingBalanceMinor))
        : totalBalance;
    final expenseCategories =
        ref.watch(moneyExpensesCategoriesProvider).value ??
        const <MoneyCategory>[];
    final incomeCategories =
        ref.watch(moneyIncomeCategoriesProvider).value ??
        const <MoneyCategory>[];
    final categoryMap = {
      for (final c in [...expenseCategories, ...incomeCategories]) c.id: c,
    };
    final byCategory = <String, int>{};
    for (final tx in inPeriod.where((t) => t.type == 'expense')) {
      if (tx.categoryId != null) {
        byCategory.update(
          tx.categoryId!,
          (value) => value + tx.amountMinor,
          ifAbsent: () => tx.amountMinor,
        );
      }
    }
    final accountMap = {for (final a in accounts) a.id: a};
    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Money Manager',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Your finances, in one place.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    final headerActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IconButton.filledTonal(
          tooltip: 'Accounts',
          onPressed: () => _open(context, const AccountManagementScreen()),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        IconButton.filledTonal(
          tooltip: 'Transaction history',
          onPressed: () => _open(context, const TransactionHistoryScreen()),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        FilledButton.icon(
          onPressed: () => _open(context, const TransactionFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Add transaction'),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 620
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerTitle,
                      const SizedBox(height: 12),
                      headerActions,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: headerTitle),
                      headerActions,
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          DropdownButtonFormField<String>(
            initialValue: selectedAccount ?? allAccountsKey,
            decoration: const InputDecoration(
              labelText: 'Account',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: allAccountsKey,
                child: Text('Total (All accounts)'),
              ),
              if (accounts.length == 2)
                const DropdownMenuItem(
                  value: bothAccountsKey,
                  child: Text('Both Accounts'),
                ),
              for (final account in accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) =>
                ref
                    .read(moneySelectedAccountProvider.notifier)
                    .state = value == allAccountsKey || value == bothAccountsKey
                ? null
                : value,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              DropdownButton<MoneyPeriod>(
                value: period,
                items: MoneyPeriod.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(_periodName(p)),
                      ),
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
              if (period != MoneyPeriod.custom)
                IconButton(
                  tooltip: 'Previous ${_periodName(period).toLowerCase()}',
                  onPressed: () =>
                      ref.read(moneyAnchorDateProvider.notifier).state = _shift(
                        selectedDate,
                        period,
                        -1,
                      ),
                  icon: const Icon(Icons.chevron_left),
                ),
              if (period != MoneyPeriod.custom)
                IconButton(
                  tooltip: 'Next ${_periodName(period).toLowerCase()}',
                  onPressed: () =>
                      ref.read(moneyAnchorDateProvider.notifier).state = _shift(
                        selectedDate,
                        period,
                        1,
                      ),
                  icon: const Icon(Icons.chevron_right),
                ),
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  period == MoneyPeriod.custom
                      ? _rangeLabel(range)
                      : _rangeLabel(range),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 740 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: columns == 3 ? 2.5 : 1.65,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  SummaryCard(
                    label: 'Total balance',
                    value: formatMinorUnits(selectedBalance),
                    icon: Icons.account_balance_wallet_outlined,
                    tint: AppColors.purple,
                    supportingText: selectedAccount == null
                        ? 'Across active accounts'
                        : 'Selected account',
                  ),
                  SummaryCard(
                    label: 'Income',
                    value: formatMinorUnits(income),
                    icon: Icons.south_west_rounded,
                    tint: AppColors.success,
                    supportingText: _rangeLabel(range),
                  ),
                  SummaryCard(
                    label: 'Expenses',
                    value: formatMinorUnits(expenses),
                    icon: Icons.north_east_rounded,
                    tint: AppColors.pink,
                    supportingText: _rangeLabel(range),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Quick actions',
            subtitle: 'Record money or manage your accounts.',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _QuickAction(
                label: 'Add expense',
                icon: Icons.north_east_rounded,
                onTap: () => _open(
                  context,
                  const TransactionFormScreen(initialType: MoneyType.expense),
                ),
              ),
              _QuickAction(
                label: 'Add income',
                icon: Icons.south_west_rounded,
                onTap: () => _open(
                  context,
                  const TransactionFormScreen(initialType: MoneyType.income),
                ),
              ),
              _QuickAction(
                label: 'Transfer',
                icon: Icons.swap_horiz_rounded,
                onTap: () => _open(
                  context,
                  const TransactionFormScreen(initialType: MoneyType.transfer),
                ),
              ),
              _QuickAction(
                label: 'Manage accounts',
                icon: Icons.account_balance_outlined,
                onTap: () => _open(context, const AccountManagementScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Your accounts',
            subtitle: 'Archived account balances are excluded from this total.',
            action: TextButton(
              onPressed: () => _open(context, const AccountManagementScreen()),
              child: const Text('Manage'),
            ),
          ),
          if (accounts.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Add your first account',
                message: 'Create a bank account, cash wallet, or another account to start tracking your money.',
                action: FilledButton.icon(
                  onPressed: () => _open(context, const AccountFormScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add account'),
                ),
                compact: true,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 740;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 3 : 1,
                    mainAxisExtent: 92,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, i) {
                    final account = accounts[i];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          ref
                                  .read(moneySelectedAccountProvider.notifier)
                                  .state =
                              account.id;
                          _open(context, const TransactionHistoryScreen());
                        },
                        leading: CircleAvatar(
                          backgroundColor: account.colorValue == null
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Color(account.colorValue!),
                          child: Icon(
                            moneyIconForCodePoint(account.iconCodePoint),
                          ),
                        ),
                        title: Text(account.name),
                        subtitle: Text(_accountTypeName(account.type)),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              formatMinorUnits(
                                balances[account.id] ??
                                    account.openingBalanceMinor,
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            IconButton(
                              tooltip: 'Adjust account balance',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showAccountBalanceEditor(
                                context,
                                ref,
                                account,
                                balances[account.id] ??
                                    account.openingBalanceMinor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Spending analytics',
            subtitle: 'Expenses only. Transfers are excluded.',
          ),
          _SpendingCharts(
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
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Money tools',
            subtitle: 'Manage budgets and move data in or out.',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/budgets'),
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Budgets'),
              ),
              const MoneyExcelButtons(),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SpendingCharts extends StatefulWidget {
  const _SpendingCharts({
    required this.transactions,
    required this.categories,
    required this.period,
  });
  final List<MoneyTransaction> transactions;
  final Map<String, MoneyCategory> categories;
  final MoneyPeriod period;

  @override
  State<_SpendingCharts> createState() => _SpendingChartsState();
}

class _SpendingChartsState extends State<_SpendingCharts> {
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
    if (total == 0) {
      return const Card(
        child: EmptyState(
          icon: Icons.pie_chart_outline,
          title: 'No data for this period',
          message: 'This chart will appear after you record activity.',
          compact: true,
        ),
      );
    }
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
                        child: Row(
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
                        child: _lineChart ? LineChart(line) : BarChart(bars),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
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
