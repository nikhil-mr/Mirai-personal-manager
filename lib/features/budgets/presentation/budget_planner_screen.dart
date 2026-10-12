import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../money/application/money_providers.dart';
import '../../money/domain/money_models.dart';
import '../../money/presentation/money_workflows.dart';
import '../application/budget_providers.dart';
import '../domain/budget_models.dart';

class BudgetPlannerScreen extends ConsumerWidget {
  const BudgetPlannerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetSelectedMonthProvider);
    final async = ref.watch(budgetMonthProvider(month));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Planner'),
        actions: [
          IconButton(
            tooltip: 'Choose month',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: month,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(budgetSelectedMonthProvider.notifier).state =
                    budgetMonth(picked);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, month: month),
        icon: const Icon(Icons.add),
        label: const Text('Add budget'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Budget Planner could not load: $e'),
          ),
        ),
        data: (snapshot) => _content(context, ref, snapshot),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    BudgetMonthSnapshot data,
  ) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(ref, data.month, -1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: data.month,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        ref.read(budgetSelectedMonthProvider.notifier).state =
                            budgetMonth(picked);
                      }
                    },
                    child: Text(
                      DateFormat.yMMMM().format(data.month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(ref, data.month, 1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                ),
              ],
            ),
            if (data.alerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final alert in data.alerts)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(
                      '${alert.categoryName}: ${alert.threshold}% budget threshold reached',
                    ),
                    subtitle: const Text(
                      'In-app alert. It is saved so it will not repeat on every expense.',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            _summary(context, data),
            if (data.lines.isEmpty) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.savings_outlined, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        'No budgets for ${DateFormat.yMMMM().format(data.month)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Set a monthly limit for an expense category to track spending and receive threshold alerts.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _edit(context, ref, month: data.month),
                        icon: const Icon(Icons.add),
                        label: const Text('Create budget'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 22),
              Text('Category budgets', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (wide)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final line in data.lines)
                      SizedBox(
                        width: (constraints.maxWidth - 50) / 2,
                        child: _lineCard(context, ref, line, data.month),
                      ),
                  ],
                )
              else ...[
                for (final line in data.lines)
                  _lineCard(context, ref, line, data.month),
              ],
            ],
            if (data.unbudgetedSpendMinor > 0) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Spending outside budgets'),
                  subtitle: const Text(
                    'These expenses remain included in Money Manager totals.',
                  ),
                  trailing: Text(formatMinorUnits(data.unbudgetedSpendMinor)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _comparison(context, ref, data),
            const SizedBox(height: 24),
            Text('Budget history', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var i = 1; i <= 6; i++)
              _historyRow(
                context,
                ref,
                DateTime(data.month.year, data.month.month - i),
              ),
          ],
        );
      },
    );
  }

  Widget _summary(BuildContext context, BudgetMonthSnapshot data) {
    final remaining = data.remainingMinor;
    final theme = Theme.of(context);
    final entries = <(String, int)>[
      ('Allocated', data.allocatedMinor),
      ('Budgeted expenses', data.budgetedSpendMinor),
      ('Remaining', remaining),
      ('All expenses', data.allExpenseMinor),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly overview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                for (final entry in entries)
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.$1, style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          formatMinorUnits(entry.$2),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: entry.$1 == 'Remaining' && remaining < 0
                                ? theme.colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: data.utilization.clamp(0, 1),
                    minHeight: 9,
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(data.utilization * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Utilization uses budgeted expenses and effective limits. All expenses includes unbudgeted categories.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(
    BuildContext context,
    WidgetRef ref,
    BudgetLine line,
    DateTime month,
  ) {
    final theme = Theme.of(context);
    final color = line.status == 'Exceeded' || line.status == 'Limit reached'
        ? theme.colorScheme.error
        : line.status == 'Approaching limit'
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _details(context, ref, line, month),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(line.category.colorValue)
                        .withValues(alpha: .15),
                    child: Icon(
                      moneyIconForCodePoint(line.category.iconCodePoint),
                      color: Color(line.category.colorValue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line.category.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Budget actions',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _edit(context, ref, month: month, line: line);
                      }
                      if (value == 'delete') {
                        _delete(context, ref, line);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit budget')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete budget'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Spent ${formatMinorUnits(line.spentMinor)} of ${formatMinorUnits(line.effectiveMinor)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: line.utilization.clamp(0, 1),
                      minHeight: 8,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(line.utilization * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      line.remainingMinor >= 0
                          ? '${formatMinorUnits(line.remainingMinor)} remaining'
                          : '${formatMinorUnits(line.remainingMinor.abs())} over budget',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: line.remainingMinor < 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    line.status,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ],
              ),
              if (line.carryMinor > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Base ${formatMinorUnits(line.plan.baseAmountMinor)} + carry-forward ${formatMinorUnits(line.carryMinor)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comparison(
    BuildContext context,
    WidgetRef ref,
    BudgetMonthSnapshot current,
  ) {
    final previous = ref.watch(
      budgetMonthProvider(
        DateTime(current.month.year, current.month.month - 1),
      ),
    );
    final categories = {
      for (final c
          in ref.watch(moneyExpensesCategoriesProvider).asData?.value ??
              const [])
        c.id: c.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Month-to-month comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            previous.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Comparison unavailable: $e'),
              data: (prior) {
                final comparison = compareBudgetMonths(current, prior);
                final delta = comparison.spendingChangeMinor;
                final pct = comparison.spendingChangePercent;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses: ${formatMinorUnits(comparison.currentSpendMinor)} vs ${formatMinorUnits(comparison.previousSpendMinor)} previous month',
                    ),
                    Text(
                      '${delta >= 0 ? 'Increase' : 'Decrease'} of ${formatMinorUnits(delta.abs())}${pct == null ? ' · percentage unavailable (no prior spending)' : ' · ${pct.abs().toStringAsFixed(1)}%'}',
                    ),
                    const SizedBox(height: 8),
                    for (final category in comparison.categories)
                      _categoryCompare(
                        context,
                        categories[category.categoryId] ?? 'Archived category',
                        category.currentSpentMinor,
                        category.previousSpentMinor,
                      ),
                    Text(
                      'Effective budgets: ${formatMinorUnits(comparison.currentBudgetMinor)} vs ${formatMinorUnits(comparison.previousBudgetMinor)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Budget allocation ${comparison.budgetChangeMinor >= 0 ? 'increased' : 'decreased'} by ${formatMinorUnits(comparison.budgetChangeMinor.abs())} · utilization ${(comparison.currentUtilization * 100).round()}% vs ${(comparison.previousUtilization * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCompare(
    BuildContext context,
    String name,
    int now,
    int previous,
  ) {
    final delta = now - previous;
    final maxAmount = (now > previous ? now : previous).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              Text(
                '${delta >= 0 ? '↑' : '↓'} ${formatMinorUnits(delta.abs())}',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: maxAmount == 0 ? 0 : previous / maxAmount,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMinorUnits(previous),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: LinearProgressIndicator(
                  value: maxAmount == 0 ? 0 : now / maxAmount,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMinorUnits(now),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, WidgetRef ref, DateTime month) {
    final result = ref.watch(budgetMonthProvider(month));
    return result.when(
      loading: () => const ListTile(title: LinearProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
      data: (s) {
        if (s.lines.isEmpty && s.allExpenseMinor == 0) {
          return const SizedBox.shrink();
        }
        return ListTile(
          onTap: () =>
              ref.read(budgetSelectedMonthProvider.notifier).state = month,
          leading: const Icon(Icons.history),
          title: Text(DateFormat.yMMMM().format(month)),
          subtitle: Text(
            '${s.lines.length} budgets · ${(s.utilization * 100).round()}% utilized',
          ),
          trailing: Text(formatMinorUnits(s.allExpenseMinor)),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required DateTime month,
    BudgetLine? line,
  }) async {
    final categories = await ref.read(moneyRepositoryProvider).categories();
    final expenseCategories = categories
        .where((c) => c.type == 'expense' && c.archivedAt == null)
        .toList();
    if (!context.mounted) return;
    if (expenseCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an expense category in Money Manager first.'),
        ),
      );
      return;
    }
    final amount = TextEditingController(
      text: line == null
          ? ''
          : (line.plan.baseAmountMinor / 100).toStringAsFixed(2),
    );
    var categoryId = line?.category.id ?? expenseCategories.first.id;
    var rollover = line?.plan.rolloverEnabled ?? false;
    var alert80 = line?.plan.alert80Enabled ?? true;
    var alert100 = line?.plan.alert100Enabled ?? true;
    String? error;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(line == null ? 'Add monthly budget' : 'Edit budget'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Expense category',
                    ),
                    items: [
                      for (final c in expenseCategories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) =>
                        setState(() => categoryId = v ?? categoryId),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly limit',
                      prefixText: '₹ ',
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Carry unused amount forward'),
                    value: rollover,
                    onChanged: (v) => setState(() => rollover = v),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alert at 80%'),
                    value: alert80,
                    onChanged: (v) => setState(() => alert80 = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alert at 100%'),
                    value: alert100,
                    onChanged: (v) => setState(() => alert100 = v ?? false),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final parsed = parseMinorUnits(amount.text);
                      if (parsed == null || parsed <= 0) {
                        setState(
                          () => error = 'Enter an amount greater than zero with up to two decimals.',
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await ref
                            .read(budgetRepositoryProvider)
                            .save(
                              id: line?.plan.id,
                              categoryId: categoryId,
                              baseAmountMinor: parsed,
                              month: month,
                              rolloverEnabled: rollover,
                              alert80Enabled: alert80,
                              alert100Enabled: alert100,
                            );
                        ref.invalidate(budgetMonthProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setState(() {
                          error = e.toString().replaceFirst(
                            'Invalid argument(s): ',
                            '',
                          );
                          saving = false;
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BudgetLine line,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'Delete the ${line.category.name} budget? Its expense transactions will stay in Money Manager.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(budgetRepositoryProvider).delete(line.plan.id);
      ref.invalidate(budgetMonthProvider);
    }
  }

  Future<void> _details(
    BuildContext context,
    WidgetRef ref,
    BudgetLine line,
    DateTime month,
  ) async {
    final txs = await ref
        .read(moneyRepositoryProvider)
        .transactions(
          start: DateTime(month.year, month.month),
          end: DateTime(month.year, month.month + 1),
          type: 'expense',
        );
    final matching = txs
        .where((tx) => tx.categoryId == line.category.id)
        .toList();
    final historyTransactions = await ref
        .read(moneyRepositoryProvider)
        .transactions(
          start: DateTime(month.year, month.month - 5),
          end: DateTime(month.year, month.month + 1),
          type: 'expense',
        );
    final history = <DateTime, int>{};
    for (final tx in historyTransactions.where(
      (tx) => tx.categoryId == line.category.id,
    )) {
      final key = DateTime(tx.occurredAt.year, tx.occurredAt.month);
      history.update(
        key,
        (value) => value + tx.amountMinor,
        ifAbsent: () => tx.amountMinor,
      );
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(line.category.name),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  _edit(context, ref, month: month, line: line);
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit budget',
              ),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  _delete(context, ref, line);
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete budget',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Base budget ${formatMinorUnits(line.plan.baseAmountMinor)}',
                      ),
                      Text(
                        'Carry-forward ${formatMinorUnits(line.carryMinor)}',
                      ),
                      Text(
                        'Effective budget ${formatMinorUnits(line.effectiveMinor)}',
                      ),
                      Text('Spent ${formatMinorUnits(line.spentMinor)}'),
                      Text(
                        line.remainingMinor >= 0
                            ? 'Remaining ${formatMinorUnits(line.remainingMinor)}'
                            : 'Exceeded by ${formatMinorUnits(line.remainingMinor.abs())}',
                      ),
                      Text(
                        'Utilization ${(line.utilization * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transactions · ${DateFormat.yMMMM().format(month)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Monthly spending history',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var offset = 5; offset >= 0; offset--)
                ListTile(
                  dense: true,
                  title: Text(
                    DateFormat.yMMMM().format(
                      DateTime(month.year, month.month - offset),
                    ),
                  ),
                  trailing: Text(
                    formatMinorUnits(
                      history[DateTime(month.year, month.month - offset)] ?? 0,
                    ),
                  ),
                ),
              const Divider(),
              if (matching.isEmpty)
                const ListTile(
                  title: Text('No expenses for this category this month.'),
                ),
              for (final tx in matching)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(tx.note.isEmpty ? line.category.name : tx.note),
                  subtitle: Text(
                    DateFormat.yMMMd().format(tx.occurredAt.toLocal()),
                  ),
                  trailing: Text(formatMinorUnits(tx.amountMinor)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TransactionDetailScreen(transactionId: tx.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _shift(WidgetRef ref, DateTime month, int delta) =>
      ref.read(budgetSelectedMonthProvider.notifier).state = DateTime(
        month.year,
        month.month + delta,
      );
}
