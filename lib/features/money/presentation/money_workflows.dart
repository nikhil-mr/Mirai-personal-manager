// Persisted icon code points are selected at runtime, so these IconData values
// cannot be compile-time constants.
// ignore_for_file: non_const_argument_for_const_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/money_providers.dart';
import '../data/money_database.dart';
import '../domain/money_models.dart';
import 'money_excel_workflows.dart';
import '../../today/application/dashboard_providers.dart';
import 'money_screen.dart' show MoneyTransactionTile;

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    this.initialType = MoneyType.expense,
    this.transactionId,
    super.key,
  });
  final MoneyType initialType;
  final String? transactionId;
  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  MoneyType _type = MoneyType.expense;
  String? _accountId, _destinationId, _categoryId;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;
  bool _loadedExisting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(moneyActiveAccountsProvider).value ?? const <MoneyAccount>[];
    if (widget.transactionId != null && !_loadedExisting) {
      final existing = ref
          .watch(moneyTransactionsProvider)
          .value
          ?.where((t) => t.id == widget.transactionId)
          .firstOrNull;
      if (existing != null) {
        _loadedExisting = true;
        _type = MoneyType.values.firstWhere((t) => t.name == existing.type);
        _amount.text = _amountText(existing.amountMinor);
        _note.text = existing.note;
        _accountId = existing.accountId;
        _destinationId = existing.destinationAccountId;
        _categoryId = existing.categoryId;
        _occurredAt = existing.occurredAt;
      }
    }
    final categories =
        (_type == MoneyType.income
                ? ref.watch(moneyIncomeCategoriesProvider).value ??
                      const <MoneyCategory>[]
                : ref.watch(moneyExpensesCategoriesProvider).value ??
                      const <MoneyCategory>[])
            .where((category) => category.archivedAt == null)
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionId == null ? 'Add transaction' : 'Edit transaction',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<MoneyType>(
                segments: const [
                  ButtonSegment(
                    value: MoneyType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: MoneyType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: MoneyType.transfer,
                    label: Text('Transfer'),
                    icon: Icon(Icons.swap_horiz),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _type = selection.first;
                        _categoryId = null;
                      }),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  hintText: '0.00',
                ),
                validator: (value) {
                  final amount = parseMinorUnits(value ?? '');
                  return amount == null || amount <= 0
                      ? 'Enter an amount greater than zero (up to 2 decimal places).'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    accounts.any((account) => account.id == _accountId)
                    ? _accountId
                    : null,
                decoration: InputDecoration(
                  labelText: _type == MoneyType.transfer
                      ? 'From account'
                      : 'Account',
                ),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Choose an account.' : null,
              ),
              if (_type == MoneyType.transfer) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue:
                      accounts.any((account) => account.id == _destinationId)
                      ? _destinationId
                      : null,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: accounts
                      .where((a) => a.id != _accountId)
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _destinationId = v),
                  validator: (v) => v == null || v == _accountId
                      ? 'Choose a different destination account.'
                      : null,
                ),
              ] else ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Choose a category.' : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CategoryManagementScreen(
                            type: _type == MoneyType.income
                                ? 'income'
                                : 'expense',
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Manage categories'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date and time'),
                subtitle: Text(
                  DateFormat.yMMMMd().add_jm().format(_occurredAt),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _note,
                maxLength: 240,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'What was this for?',
                ),
              ),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Create an account before adding transactions.'),
                ),
              FilledButton.icon(
                onPressed: _saving || accounts.isEmpty ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time != null && mounted) {
      setState(
        () => _occurredAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .saveTransaction(
            id: widget.transactionId,
            type: _type,
            amountMinor: parseMinorUnits(_amount.text)!,
            accountId: _accountId!,
            destinationAccountId: _type == MoneyType.transfer
                ? _destinationId
                : null,
            categoryId: _type == MoneyType.transfer ? null : _categoryId,
            occurredAt: _occurredAt,
            note: _note.text,
          );
      ref.invalidate(moneyBalancesProvider);
      ref.invalidate(todayDashboardSnapshotProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save transaction: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<void> showAccountBalanceEditor(
  BuildContext context,
  WidgetRef ref,
  MoneyAccount account,
  int currentBalanceMinor,
) async {
  final balance = TextEditingController(text: _amountText(currentBalanceMinor));
  final note = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Adjust ${account.name} balance'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current balance: ${formatMinorUnits(currentBalanceMinor)}'),
            const SizedBox(height: 12),
            TextField(
              controller: balance,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'New account balance',
                prefixText: '₹ ',
              ),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'For example, balance reconciliation',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This records a balance adjustment. Existing income, expenses, and transfers stay unchanged.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Save balance'),
        ),
      ],
    ),
  );
  if (!context.mounted) {
    balance.dispose();
    note.dispose();
    return;
  }
  if (saved == true) {
    final target = parseMinorUnits(balance.text);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative balance.')),
      );
    } else {
      try {
        final difference = await ref
            .read(moneyRepositoryProvider)
            .setAccountBalance(
              accountId: account.id,
              targetBalanceMinor: target,
              note: note.text,
            );
        ref.invalidate(moneyBalancesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                difference == 0
                    ? 'Account balance is already up to date.'
                    : 'Account balance updated to ${formatMinorUnits(target)}.',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update account balance: $error')),
          );
        }
      }
    }
  }
  balance.dispose();
  note.dispose();
}

class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(moneyAccountsProvider);
    final balances =
        ref.watch(moneyBalancesProvider).value ?? const <String, int>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            onPressed: () => _push(context, const AccountFormScreen()),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load accounts: $e')),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No accounts yet',
                message: 'Add a bank account, cash wallet, or other account.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final account in rows)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            moneyIconForCodePoint(account.iconCodePoint),
                          ),
                        ),
                        title: Text(account.name),
                        subtitle: Text(
                          '${_accountTypeName(account.type)}${account.archivedAt == null ? '' : ' · Archived'}',
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              formatMinorUnits(
                                balances[account.id] ??
                                    account.openingBalanceMinor,
                              ),
                            ),
                            if (account.archivedAt == null)
                              IconButton(
                                tooltip: 'Edit account balance',
                                onPressed: () => showAccountBalanceEditor(
                                  context,
                                  ref,
                                  account,
                                  balances[account.id] ??
                                      account.openingBalanceMinor,
                                ),
                                icon: const Icon(Icons.edit_note),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _push(
                                    context,
                                    AccountFormScreen(account: account),
                                  );
                                } else if (action == 'delete') {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete account?'),
                                      content: Text(
                                        'Delete "${account.name}" and its transactions and balance adjustments? Transfers involving this account will also be deleted.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          child: const Text('Delete account'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      await ref
                                          .read(moneyRepositoryProvider)
                                          .deleteAccount(account.id);
                                      ref.invalidate(moneyBalancesProvider);
                                      ref.invalidate(moneyTransactionsProvider);
                                      ref.invalidate(
                                        todayDashboardSnapshotProvider,
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not delete account: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } else {
                                  await ref
                                      .read(moneyRepositoryProvider)
                                      .archiveAccount(
                                        account.id,
                                        archive: account.archivedAt == null,
                                      );
                                  ref.invalidate(moneyBalancesProvider);
                                }
                              },
                              itemBuilder: (_) => [
                                if (account.archivedAt == null)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit details'),
                                  ),
                                PopupMenuItem(
                                  value: account.archivedAt == null
                                      ? 'archive'
                                      : 'restore',
                                  child: Text(
                                    account.archivedAt == null
                                        ? 'Archive'
                                        : 'Restore',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete account'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({this.account, super.key});
  final MoneyAccount? account;
  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name, _balance;
  bool _balanceChanged = false;
  AccountType _type = AccountType.bank;
  static const _colors = [
    AppColors.brand,
    Color(0xFF6488B8),
    Color(0xFFB67527),
    Color(0xFF8B6F9E),
    Color(0xFF288467),
  ];
  static const _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_outlined,
    Icons.wallet_outlined,
    Icons.savings_outlined,
    Icons.credit_card_outlined,
    Icons.payments_outlined,
  ];
  int _color = AppColors.brand.toARGB32();
  int _icon = 0xe8d1;
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
      text: a == null ? '' : _amountText(a.openingBalanceMinor),
    );
    _type = AccountType.values.firstWhere(
      (x) => x.name == a?.type,
      orElse: () => AccountType.bank,
    );
    _color = a?.colorValue ?? _color;
    _icon = a?.iconCodePoint ?? _icon;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final currentBalance = account == null
        ? null
        : ref.watch(moneyBalancesProvider).asData?.value[account.id] ??
              account.openingBalanceMinor;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'New account' : 'Edit account'),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter an account name.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Account type'),
              items: AccountType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(switch (t) {
                        AccountType.bank => 'Bank account',
                        AccountType.cash => 'Cash wallet',
                        AccountType.other => 'Other',
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            if (widget.account == null) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Opening balance',
                  prefixText: '₹ ',
                ),
                validator: (v) => parseMinorUnits(v ?? '') == null
                    ? 'Enter a valid amount.'
                    : null,
              ),
            ] else ...[
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey('account-balance-${currentBalance ?? 0}'),
                initialValue: _balanceChanged
                    ? _balance.text
                    : _amountText(currentBalance ?? 0),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Current balance',
                  prefixText: 'â‚¹ ',
                  helperText: 'Changing this records a balance adjustment; transaction history stays unchanged.',
                ),
                validator: (value) => parseMinorUnits(value ?? '') == null
                    ? 'Enter a valid non-negative balance.'
                    : null,
                onChanged: (value) => setState(() {
                  _balanceChanged = true;
                  _balance.text = value;
                }),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Account icon'),
            Wrap(
              spacing: 8,
              children: [
                for (final icon in _icons)
                  IconButton.filledTonal(
                    tooltip: 'Choose account icon',
                    onPressed: () => setState(() => _icon = icon.codePoint),
                    icon: Icon(icon),
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == icon.codePoint
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Account color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color.toARGB32()),
                    child: CircleAvatar(
                      backgroundColor: color,
                      child: _color == color.toARGB32()
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                if (!_key.currentState!.validate()) return;
                try {
                  await ref
                      .read(moneyRepositoryProvider)
                      .saveAccount(
                        id: widget.account?.id,
                        name: _name.text,
                        type: _type,
                        openingBalanceMinor:
                            widget.account?.openingBalanceMinor ??
                            parseMinorUnits(_balance.text)!,
                        icon: _icon,
                        color: _color,
                      );
                  if (widget.account != null && _balanceChanged) {
                    await ref
                        .read(moneyRepositoryProvider)
                        .setAccountBalance(
                          accountId: widget.account!.id,
                          targetBalanceMinor: parseMinorUnits(_balance.text)!,
                        );
                  }
                  ref.invalidate(moneyBalancesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save account: $e')),
                    );
                  }
                }
              },
              child: const Text('Save account'),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({required this.type, super.key});
  final String type;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'income'
        ? moneyIncomeCategoriesProvider
        : moneyExpensesCategoriesProvider;
    final rows = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${type == 'income' ? 'Income' : 'Expense'} categories'),
        actions: [
          IconButton(
            onPressed: () => _editCategory(context, ref, type),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load categories: $e')),
        data: (categories) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final category in categories)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(category.colorValue),
                    child: Icon(moneyIconForCodePoint(category.iconCodePoint)),
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    category.archivedAt != null
                        ? 'Archived'
                        : category.isDefault
                        ? 'Default'
                        : 'Custom',
                  ),
                  trailing: Wrap(
                    children: [
                      if (category.archivedAt == null)
                        IconButton(
                          tooltip: 'Rename',
                          onPressed: () =>
                              _editCategory(context, ref, type, category),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      TextButton(
                        onPressed: () => ref
                            .read(moneyRepositoryProvider)
                            .archiveCategory(
                              category.id,
                              archive: category.archivedAt == null,
                            ),
                        child: Text(
                          category.archivedAt == null ? 'Archive' : 'Restore',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editCategory(
  BuildContext context,
  WidgetRef ref,
  String type, [
  MoneyCategory? category,
]) async {
  final name = TextEditingController(text: category?.name ?? '');
  final formKey = GlobalKey<FormState>();
  const colors = [
    AppColors.brand,
    Color(0xFF6488B8),
    Color(0xFFB67527),
    Color(0xFF8B6F9E),
  ];
  const icons = [
    Icons.label_outline,
    Icons.restaurant_outlined,
    Icons.shopping_bag_outlined,
    Icons.directions_bus_outlined,
    Icons.local_gas_station_outlined,
    Icons.receipt_long_outlined,
    Icons.favorite_border,
    Icons.school_outlined,
    Icons.home_outlined,
    Icons.work_outline,
  ];
  var color = category?.colorValue ?? colors.first.toARGB32();
  var iconCode = category?.iconCodePoint ?? icons.first.codePoint;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        return AlertDialog(
          title: Text(category == null ? 'New category' : 'Rename category'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name.' : null,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in colors)
                      InkWell(
                        onTap: () => setState(() => color = c.toARGB32()),
                        child: CircleAvatar(
                          backgroundColor: c,
                          child: color == c.toARGB32()
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final icon in icons)
                      IconButton.filledTonal(
                        tooltip: 'Choose category icon',
                        onPressed: () =>
                            setState(() => iconCode = icon.codePoint),
                        icon: Icon(icon),
                        style: IconButton.styleFrom(
                          backgroundColor: iconCode == icon.codePoint
                              ? Theme.of(dialogContext)
                                    .colorScheme
                                    .primaryContainer
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  if (saved == true) {
    await ref
        .read(moneyRepositoryProvider)
        .saveCategory(
          id: category?.id,
          name: name.text,
          type: type,
          icon: iconCode,
          color: color,
        );
  }
  name.dispose();
}

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _search = TextEditingController();
  String _type = 'all';
  DateTimeRange? _range;
  MoneyPeriod _period = MoneyPeriod.day;
  DateTime _anchorDate = DateTime.now();
  String? _categoryFilter;
  bool _allDates = true;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txns =
        ref.watch(moneyTransactionsProvider).value ??
        const <MoneyTransaction>[];
    final accounts =
        ref.watch(moneyAccountsProvider).value ?? const <MoneyAccount>[];
    final categories = [
      ...(ref.watch(moneyExpensesCategoriesProvider).value ??
          const <MoneyCategory>[]),
      ...(ref.watch(moneyIncomeCategoriesProvider).value ??
          const <MoneyCategory>[]),
    ];
    final accountMap = {for (final a in accounts) a.id: a};
    final categoryMap = {for (final c in categories) c.id: c};
    final accountFilter = ref.watch(moneySelectedAccountProvider);
    final dateRange = _range == null
        ? MoneyRange.forPeriod(_period, _anchorDate)
        : MoneyRange(
            _range!.start,
            DateTime(_range!.end.year, _range!.end.month, _range!.end.day + 1),
          );
    final filtered = txns.where((t) {
      if (_type != 'all' && t.type != _type) return false;
      if (accountFilter != null &&
          t.accountId != accountFilter &&
          t.destinationAccountId != accountFilter) {
        return false;
      }
      if (!_allDates &&
          (t.occurredAt.isBefore(dateRange.start) ||
              !t.occurredAt.isBefore(dateRange.end))) {
        return false;
      }
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      final query = _search.text.trim().toLowerCase();
      if (query.isNotEmpty &&
          !('${t.note} ${categoryMap[t.categoryId]?.name ?? ''} ${accountMap[t.accountId]?.name ?? ''} ${accountMap[t.destinationAccountId]?.name ?? ''}')
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction history'),
        actions: [
          if (accountFilter != null)
            TextButton(
              onPressed: () =>
                  ref.read(moneySelectedAccountProvider.notifier).state = null,
              child: const Text('Clear account'),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MoneyExcelButtons(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search note, category, or account',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          ).then(
                            (r) => setState(() {
                              _range = r;
                              _period = MoneyPeriod.custom;
                              _allDates = false;
                            }),
                          ),
                      icon: const Icon(Icons.date_range),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final type in [
                        'all',
                        'expense',
                        'income',
                        'transfer',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              type == 'all'
                                  ? 'All types'
                                  : '${type[0].toUpperCase()}${type.substring(1)}',
                            ),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                        ),
                      DropdownButton<String?>(
                        value: accountFilter,
                        hint: const Text('All accounts'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All accounts'),
                          ),
                          ...accounts.map(
                            (a) => DropdownMenuItem<String?>(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () =>
                              ref
                                      .read(
                                        moneySelectedAccountProvider.notifier,
                                      )
                                      .state =
                                  v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String?>(
                        value: _categoryFilter,
                        hint: const Text('All categories'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ...categories
                              .where((c) => c.archivedAt == null)
                              .map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryFilter = value),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _allDates ? 'all' : _period.name,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All dates'),
                          ),
                          for (final period in MoneyPeriod.values)
                            DropdownMenuItem(
                              value: period.name,
                              child: Text(_historyPeriodName(period)),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == 'all') {
                            setState(() {
                              _allDates = true;
                              _range = null;
                            });
                          } else if (value == MoneyPeriod.custom.name) {
                            await _pickHistoryRange();
                          } else {
                            setState(() {
                              _period = MoneyPeriod.values.firstWhere(
                                (period) => period.name == value,
                              );
                              _range = null;
                              _allDates = false;
                            });
                          }
                        },
                      ),
                      if (!_allDates && _period != MoneyPeriod.custom) ...[
                        IconButton(
                          tooltip: 'Previous period',
                          onPressed: () => setState(
                            () => _anchorDate = _shiftHistoryDate(
                              _anchorDate,
                              _period,
                              -1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next period',
                          onPressed: () => setState(
                            () => _anchorDate = _shiftHistoryDate(
                              _anchorDate,
                              _period,
                              1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching transactions',
                    message: 'Try another search or date filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final tx = filtered[i];
                      return Card(
                        child: MoneyTransactionTile(
                          transaction: tx,
                          account: accountMap[tx.accountId],
                          destination: accountMap[tx.destinationAccountId],
                          category: categoryMap[tx.categoryId],
                          onTap: () => _push(
                            context,
                            TransactionDetailScreen(transactionId: tx.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickHistoryRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (range != null && mounted) {
      setState(() {
        _range = range;
        _period = MoneyPeriod.custom;
        _allDates = false;
      });
    }
  }
}

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});
  final String transactionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref
        .watch(moneyTransactionsProvider)
        .value
        ?.where((t) => t.id == transactionId)
        .firstOrNull;
    final accounts =
        ref.watch(moneyAccountsProvider).value ?? const <MoneyAccount>[];
    final categories = [
      ...(ref.watch(moneyExpensesCategoriesProvider).value ??
          const <MoneyCategory>[]),
      ...(ref.watch(moneyIncomeCategoriesProvider).value ??
          const <MoneyCategory>[]),
    ];
    if (tx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const EmptyState(
          icon: Icons.receipt_long,
          title: 'Transaction unavailable',
          message: 'It may have been deleted.',
        ),
      );
    }
    final account = accounts.where((a) => a.id == tx.accountId).firstOrNull;
    final destination = accounts
        .where((a) => a.id == tx.destinationAccountId)
        .firstOrNull;
    final category = categories.where((c) => c.id == tx.categoryId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _push(
              context,
              TransactionFormScreen(
                initialType: MoneyType.values.firstWhere(
                  (t) => t.name == tx.type,
                ),
                transactionId: tx.id,
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, tx.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    tx.type == 'income'
                        ? Icons.south_west
                        : tx.type == 'expense'
                        ? Icons.north_east
                        : Icons.swap_horiz,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatMinorUnits(tx.amountMinor),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    tx.type.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _detailRow(
            context,
            'Category',
            category?.name ??
                (tx.type == 'transfer' ? 'Transfer' : 'Archived category'),
          ),
          _detailRow(
            context,
            'Account',
            tx.type == 'transfer'
                ? '${account?.name ?? 'Archived'} → ${destination?.name ?? 'Archived'}'
                : account?.name ?? 'Archived account',
          ),
          _detailRow(
            context,
            'Date and time',
            DateFormat.yMMMMd().add_jm().format(tx.occurredAt.toLocal()),
          ),
          _detailRow(context, 'Note', tx.note.isEmpty ? 'No note' : tx.note),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete transaction?'),
      content: const Text(
        'This removes the ledger entry and recalculates account balances and summaries.',
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
  if (yes == true) {
    await ref.read(moneyRepositoryProvider).deleteTransaction(id);
    ref.invalidate(moneyBalancesProvider);
    ref.invalidate(todayDashboardSnapshotProvider);
    if (context.mounted) Navigator.pop(context);
  }
}

Widget _detailRow(BuildContext context, String label, String value) => ListTile(
  title: Text(label, style: Theme.of(context).textTheme.labelMedium),
  subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
);
Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
String _accountTypeName(String type) => switch (type) {
  'bank' => 'Bank account',
  'cash' => 'Cash wallet',
  _ => 'Other account',
};
String _amountText(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

String _historyPeriodName(MoneyPeriod period) => switch (period) {
  MoneyPeriod.day => 'Day',
  MoneyPeriod.week => 'Week',
  MoneyPeriod.month => 'Month',
  MoneyPeriod.year => 'Year',
  MoneyPeriod.custom => 'Custom range',
};

DateTime _shiftHistoryDate(DateTime date, MoneyPeriod period, int direction) =>
    switch (period) {
      MoneyPeriod.day => date.add(Duration(days: direction)),
      MoneyPeriod.week => date.add(Duration(days: 7 * direction)),
      MoneyPeriod.month => DateTime(date.year, date.month + direction, 1),
      MoneyPeriod.year => DateTime(date.year + direction, date.month, 1),
      MoneyPeriod.custom => date,
    };
