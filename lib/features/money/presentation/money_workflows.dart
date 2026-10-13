// Persisted icon code points are selected at runtime, so these IconData values
// cannot be compile-time constants.
// ignore_for_file: non_const_argument_for_const_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/brutal_card.dart';
import '../application/money_providers.dart';
import '../data/money_database.dart';
import '../domain/money_models.dart';
import 'money_excel_workflows.dart';
import 'calculator_screen.dart';
import '../../today/application/dashboard_providers.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final accounts =
        ref.watch(moneyActiveAccountsProvider).value ?? const <MoneyAccount>[];
    final balances =
        ref.watch(moneyBalancesProvider).value ?? const <String, int>{};

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

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
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
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.transactionId == null ? 'Add transaction' : 'Edit transaction',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTypeSelector(isDark, borderColor),
              const SizedBox(height: 20),
              _buildAmountAndCalculator(isDark, borderColor),
              const SizedBox(height: 20),
              _buildAccountSelectors(accounts, balances, isDark, borderColor),
              const SizedBox(height: 20),
              if (_type != MoneyType.transfer) ...[
                _buildCategoryGrid(categories, isDark, borderColor),
                const SizedBox(height: 20),
              ],
              _buildDateTimePicker(isDark, borderColor),
              const SizedBox(height: 20),
              _buildNotesAndSaveButton(
                isDark,
                borderColor,
                accounts.isNotEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: !isDark
            ? const [
                BoxShadow(color: AppColors.lightText, offset: Offset(3, 3)),
              ]
            : null,
      ),
      child: Row(
        children: [
          for (final type in [
            MoneyType.expense,
            MoneyType.income,
            MoneyType.transfer,
          ])
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _saving
                    ? null
                    : () => setState(() {
                        _type = type;
                        _categoryId = null;
                      }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _type == type ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: _type == type
                        ? Border.all(color: AppColors.lightText, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_type == type) ...[
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.lightText,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        type.name[0].toUpperCase() + type.name.substring(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _type == type
                              ? AppColors.lightText
                              : (isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountAndCalculator(bool isDark, Color borderColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              hintText: '0.00',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              final amount = parseMinorUnits(value ?? '');
              return amount == null || amount <= 0
                  ? 'Enter an amount greater than zero.'
                  : null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: !isDark
                ? const [
                    BoxShadow(color: AppColors.lightText, offset: Offset(3, 3)),
                  ]
                : null,
          ),
          child: Material(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CalculatorScreen(initialValue: _amount.text),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _amount.text = result;
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightText, width: 2),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: AppColors.lightText,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelectors(
    List<MoneyAccount> accounts,
    Map<String, int> balances,
    bool isDark,
    Color borderColor,
  ) {
    if (_type == MoneyType.transfer) {
      final outgoingBalance = _accountId != null ? balances[_accountId] : null;
      final incomingBalance = _destinationId != null
          ? balances[_destinationId]
          : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _accountId)
                ? _accountId
                : null,
            decoration: InputDecoration(
              labelText: 'From account',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  width: 2,
                ),
              ),
            ),
            items: accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v),
            validator: (v) => v == null ? 'Choose outgoing account.' : null,
          ),
          if (outgoingBalance != null) ...[
            const SizedBox(height: 4),
            Text(
              'Available balance: ${formatMinorUnits(outgoingBalance)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _destinationId)
                ? _destinationId
                : null,
            decoration: InputDecoration(
              labelText: 'To account',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  width: 2,
                ),
              ),
            ),
            items: accounts
                .where((a) => a.id != _accountId)
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _destinationId = v),
            validator: (v) => v == null || v == _accountId
                ? 'Choose a different destination account.'
                : null,
          ),
          if (incomingBalance != null) ...[
            const SizedBox(height: 4),
            Text(
              'Current balance: ${formatMinorUnits(incomingBalance)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    } else {
      final accountBalance = _accountId != null ? balances[_accountId] : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _accountId)
                ? _accountId
                : null,
            decoration: InputDecoration(
              labelText: 'Account',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  width: 2,
                ),
              ),
            ),
            items: accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v),
            validator: (v) => v == null ? 'Choose an account.' : null,
          ),
          if (accountBalance != null) ...[
            const SizedBox(height: 4),
            Text(
              'Available balance: ${formatMinorUnits(accountBalance)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildCategoryGrid(
    List<MoneyCategory> categories,
    bool isDark,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryManagementScreen(
                      type: _type == MoneyType.income ? 'income' : 'expense',
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Manage categories'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'No categories available. Add one using Manage Categories.',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.lightSecondaryText,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _categoryId == cat.id;

              final (tileColor, iconColor) = _categoryStyle(cat, isDark);
              final circleColor = isDark
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFFFFFFF);
              final labelColor = isDark
                  ? AppColors.darkText
                  : const Color(0xFF111111);

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected && !isDark
                      ? const [
                          BoxShadow(
                            color: AppColors.lightText,
                            offset: Offset(3, 3),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: tileColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? (isDark ? AppColors.brand : AppColors.lightText)
                          : borderColor,
                      width: isSelected ? 3 : 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _categoryId = cat.id),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            moneyIconForCodePoint(cat.iconCodePoint),
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: labelColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  (Color tileColor, Color iconColor) _categoryStyle(
    MoneyCategory cat,
    bool isDark,
  ) {
    final name = cat.name.trim().toLowerCase();

    Color? bg;
    Color? icon;

    switch (name) {
      case 'bills':
        bg = const Color(0xFFE5C9FF);
        icon = const Color(0xFF8E44AD);
      case 'education':
        bg = const Color(0xFFBFE0FF);
        icon = const Color(0xFF2476C5);
      case 'entertainment':
        bg = const Color(0xFFFFC5D8);
        icon = const Color(0xFFD93670);
      case 'food':
      case 'cafe':
        bg = const Color(0xFFFFD0AE);
        icon = const Color(0xFFE8752D);
      case 'fuel':
        bg = const Color(0xFFFFD49A);
        icon = const Color(0xFFBD7417);
      case 'groceries':
        bg = const Color(0xFFAEEBDD);
        icon = const Color(0xFF168F78);
      case 'health':
      case 'hygiene':
      case 'self':
        bg = const Color(0xFFB5E8D4);
        icon = const Color(0xFF188D69);
      case 'other':
        bg = const Color(0xFFD7DEDE);
        icon = const Color(0xFF596B68);
      case 'rent':
      case 'home':
        bg = const Color(0xFFFFE1A3);
        icon = const Color(0xFFB88927);
      case 'shopping':
      case 'gifts':
        bg = const Color(0xFFC9D4FF);
        icon = const Color(0xFF5269C7);
      case 'travel':
      case 'transportation':
        bg = const Color(0xFFB8D9FF);
        icon = const Color(0xFF347BC1);
    }

    final baseAccent = icon ?? Color(cat.colorValue);

    if (isDark) {
      final darkTile = Color.lerp(AppColors.darkCard, baseAccent, 0.35)!;
      return (darkTile, baseAccent);
    } else {
      final lightTile =
          bg ?? Color.lerp(const Color(0xFFFFFFFF), baseAccent, 0.35)!;
      return (lightTile, baseAccent);
    }
  }

  Widget _buildDateTimePicker(bool isDark, Color borderColor) {
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: _pickDateTime,
        child: Row(
          children: [
            const Icon(Icons.event, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date & Time',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.yMMMMd().add_jm().format(_occurredAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesAndSaveButton(
    bool isDark,
    Color borderColor,
    bool hasAccounts,
  ) {
    return Column(
      children: [
        TextFormField(
          controller: _note,
          maxLength: 240,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'What was this for?',
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasAccounts)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Create an account before adding transactions.',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: !isDark
                  ? const [
                      BoxShadow(
                        color: AppColors.lightText,
                        offset: Offset(4, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.lightText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor, width: 2),
                ),
              ),
              onPressed: _saving || !hasAccounts ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lightText,
                      ),
                    )
                  : const Icon(
                      Icons.check,
                      color: AppColors.lightText,
                      size: 24,
                    ),
              label: Text(
                _saving ? 'Saving…' : 'Save transaction',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                ),
              ),
            ),
          ),
        ),
      ],
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
    if (_type != MoneyType.transfer && _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }
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
      ref.invalidate(moneyTransactionsProvider);
      ref.invalidate(todayDashboardSnapshotProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully!')),
        );
        Navigator.of(context).pop();
      }
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

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({required this.type, super.key});
  final String type;

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  late String _activeType;

  @override
  void initState() {
    super.initState();
    _activeType = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final provider = _activeType == 'income'
        ? moneyIncomeCategoriesProvider
        : moneyExpensesCategoriesProvider;
    final rows = ref.watch(provider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Category',
            onPressed: () => _editCategory(context, ref, _activeType),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    for (final t in ['expense', 'income'])
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _activeType = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeType == t
                                  ? AppColors.brand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t == 'expense' ? 'Expense' : 'Income',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeType == t
                                    ? AppColors.lightText
                                    : (isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: rows.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load categories: $e')),
                data: (categories) => categories.isEmpty
                    ? const EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No categories',
                        message: 'Tap + to add a category.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: BrutalCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Color(category.colorValue),
                                    child: Icon(
                                      moneyIconForCodePoint(
                                        category.iconCodePoint,
                                      ),
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          category.archivedAt != null
                                              ? 'Archived'
                                              : category.isDefault
                                              ? 'Default'
                                              : 'Custom',
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
                                  if (category.archivedAt == null)
                                    IconButton(
                                      tooltip: 'Edit',
                                      onPressed: () => _editCategory(
                                        context,
                                        ref,
                                        _activeType,
                                        category,
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                  IconButton(
                                    tooltip: category.archivedAt == null
                                        ? 'Delete'
                                        : 'Restore',
                                    onPressed: () => _deleteOrArchiveCategory(
                                      context,
                                      ref,
                                      category,
                                    ),
                                    icon: Icon(
                                      category.archivedAt == null
                                          ? Icons.delete_outline
                                          : Icons.restore,
                                      color: category.archivedAt == null
                                          ? AppColors.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _deleteOrArchiveCategory(
  BuildContext context,
  WidgetRef ref,
  MoneyCategory category,
) async {
  final repository = ref.read(moneyRepositoryProvider);
  final isUsed = await repository.isCategoryUsed(category.id);

  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete "${category.name}"?'),
      content: Text(
        isUsed
            ? 'This category is used in existing transactions. It will be archived so historical records remain intact.'
            : 'Are you sure you want to permanently delete this category?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isUsed ? AppColors.warning : AppColors.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(isUsed ? 'Archive' : 'Delete permanently'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    if (isUsed || category.archivedAt != null) {
      await repository.archiveCategory(
        category.id,
        archive: category.archivedAt == null,
      );
    } else {
      await repository.deleteCategory(category.id);
    }
    ref.invalidate(moneyExpensesCategoriesProvider);
    ref.invalidate(moneyIncomeCategoriesProvider);
  }
}

Future<void> _editCategory(
  BuildContext context,
  WidgetRef ref,
  String type, [
  MoneyCategory? category,
]) async {
  final nameController = TextEditingController(text: category?.name ?? '');
  final formKey = GlobalKey<FormState>();

  const colors = [
    AppColors.brand,
    AppColors.orange,
    AppColors.success,
    AppColors.blue,
    AppColors.accent,
    AppColors.pink,
    Color(0xFF6488B8),
    Color(0xFFB67527),
    Color(0xFF8B6F9E),
    Color(0xFF4D9B83),
  ];

  const icons = [
    Icons.restaurant_outlined,
    Icons.shopping_cart_outlined,
    Icons.shopping_bag_outlined,
    Icons.directions_bus_outlined,
    Icons.local_gas_station_outlined,
    Icons.receipt_long_outlined,
    Icons.favorite_border,
    Icons.school_outlined,
    Icons.home_outlined,
    Icons.work_outline,
    Icons.payments_outlined,
    Icons.account_balance_outlined,
    Icons.label_outline,
  ];

  var selectedColor = category?.colorValue ?? colors.first.toARGB32();
  var selectedIconCode = category?.iconCodePoint ?? icons.first.codePoint;
  String? duplicateError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        return AlertDialog(
          title: Text(
            category == null ? 'New Category' : 'Edit Category',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      errorText: duplicateError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (duplicateError != null) {
                        setState(() => duplicateError = null);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter a category name.';
                      if (v.trim().length > 60)
                        return 'Name must be under 60 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in colors)
                        InkWell(
                          onTap: () =>
                              setState(() => selectedColor = c.toARGB32()),
                          child: CircleAvatar(
                            backgroundColor: c,
                            radius: 18,
                            child: selectedColor == c.toARGB32()
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Icon',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final icon in icons)
                        InkWell(
                          onTap: () =>
                              setState(() => selectedIconCode = icon.codePoint),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selectedIconCode == icon.codePoint
                                  ? AppColors.brand
                                  : Theme.of(dialogContext).cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedIconCode == icon.codePoint
                                    ? AppColors.lightText
                                    : Colors.grey,
                                width: selectedIconCode == icon.codePoint
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: AppColors.lightText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.lightText,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final repository = ref.read(moneyRepositoryProvider);
                final exists = await repository.categoryNameExists(
                  nameController.text,
                  type,
                  excludeId: category?.id,
                );

                if (exists) {
                  setState(
                    () => duplicateError =
                        'A category with this name already exists.',
                  );
                  return;
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
          name: nameController.text,
          type: type,
          icon: selectedIconCode,
          color: selectedColor,
        );
    ref.invalidate(moneyExpensesCategoriesProvider);
    ref.invalidate(moneyIncomeCategoriesProvider);
  }
}

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _HistoryTransactionTile extends StatelessWidget {
  const _HistoryTransactionTile({
    required this.transaction,
    required this.account,
    required this.destination,
    required this.category,
    required this.onTap,
  });
  final MoneyTransaction transaction;
  final MoneyAccount? account;
  final MoneyAccount? destination;
  final MoneyCategory? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        : category?.name ?? 'Uncategorized';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: .5),
                  width: 1,
                ),
              ),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.type[0].toUpperCase()}${transaction.type.substring(1)} • ${DateFormat.jm().format(transaction.occurredAt.toLocal())} • ${transaction.type == 'transfer' ? 'Transfer' : account?.name ?? 'Account'}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                      fontSize: 13,
                    ),
                  ),
                  if (transaction.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.note.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$amountPrefix${formatMinorUnits(transaction.amountMinor)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _search = TextEditingController();

  String _type = 'all'; // all, expense, income, transfer
  String? _categoryFilter;

  bool _allDates = false;
  MoneyPeriod _period = MoneyPeriod.month;
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _customRange;

  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _type = 'all';
      _categoryFilter = null;
      ref.read(moneySelectedAccountProvider.notifier).state = null;
      _customRange = null;
      _period = MoneyPeriod.month;
      _anchorDate = DateTime.now();
      _allDates = false;
      _sortBy = 'date';
      _sortAscending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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

    final dateRange = _customRange != null
        ? MoneyRange(
            _customRange!.start,
            DateTime(
              _customRange!.end.year,
              _customRange!.end.month,
              _customRange!.end.day + 1,
            ),
          )
        : (_allDates
              ? MoneyRange(DateTime(2000), DateTime(2100))
              : MoneyRange.forPeriod(_period, _anchorDate));

    final filtered = txns.where((t) {
      if (_type != 'all' && t.type != _type) return false;
      if (accountFilter != null &&
          t.accountId != accountFilter &&
          t.destinationAccountId != accountFilter)
        return false;
      if (!_allDates &&
          (t.occurredAt.isBefore(dateRange.start) ||
              !t.occurredAt.isBefore(dateRange.end)))
        return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter)
        return false;

      final query = _search.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final searchString =
            '${t.note} ${categoryMap[t.categoryId]?.name ?? ''} ${accountMap[t.accountId]?.name ?? ''}\n${accountMap[t.destinationAccountId]?.name ?? ''}'
                .toLowerCase();
        if (!searchString.contains(query)) return false;
      }
      return true;
    }).toList();

    // Summary calculation
    int totalExpense = 0;
    int totalIncome = 0;
    for (final t in filtered) {
      if (t.type == 'expense') totalExpense += t.amountMinor;
      if (t.type == 'income') totalIncome += t.amountMinor;
    }

    // Sort
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'amount':
          cmp = a.amountMinor.compareTo(b.amountMinor);
          break;
        case 'category':
          final catA = (categoryMap[a.categoryId]?.name ?? 'Z').toLowerCase();
          final catB = (categoryMap[b.categoryId]?.name ?? 'Z').toLowerCase();
          cmp = catA.compareTo(catB);
          break;
        case 'account':
          final accA = (accountMap[a.accountId]?.name ?? 'Z').toLowerCase();
          final accB = (accountMap[b.accountId]?.name ?? 'Z').toLowerCase();
          cmp = accA.compareTo(accB);
          break;
        case 'date':
        default:
          cmp = a.occurredAt.compareTo(b.occurredAt);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    // Grouping by Date
    final groups = <DateTime, List<MoneyTransaction>>{};
    for (final t in filtered) {
      final date = DateTime(
        t.occurredAt.year,
        t.occurredAt.month,
        t.occurredAt.day,
      );
      groups.putIfAbsent(date, () => []).add(t);
    }
    final sortedGroupKeys = groups.keys.toList()
      ..sort(
        (a, b) => _sortBy == 'date' && _sortAscending
            ? a.compareTo(b)
            : b.compareTo(a),
      );

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Transaction history'),
        actions: [
          if (accountFilter != null ||
              _categoryFilter != null ||
              _type != 'all' ||
              _search.text.isNotEmpty ||
              _customRange != null)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset filters'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    hintText: 'Search note, category, or account',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        width: 2,
                      ),
                    ),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
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
                              style: TextStyle(
                                fontWeight: _type == type
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            selected: _type == type,
                            selectedColor: AppColors.brand,
                            backgroundColor: Theme.of(context).cardColor,
                            onSelected: (_) => setState(() => _type = type),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _type == type
                                    ? AppColors.lightBorder
                                    : borderColor,
                                width: 2,
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BrutalCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(
                        'Filter & Sort',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      leading: const Icon(Icons.filter_list),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                width: 2,
                              ),
                            ),
                          ),
                          value: _categoryFilter,
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
                          onChanged: (v) => setState(() => _categoryFilter = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            labelText: 'Account',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                width: 2,
                              ),
                            ),
                          ),
                          value: accountFilter,
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
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Period',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkSecondaryText
                                  : AppColors.lightSecondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in [
                                MoneyPeriod.day,
                                MoneyPeriod.week,
                                MoneyPeriod.month,
                                MoneyPeriod.year,
                              ])
                                ChoiceChip(
                                  label: Text(
                                    p.name[0].toUpperCase() +
                                        p.name.substring(1),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                    ),
                                  ),
                                  selected:
                                      _customRange == null && _period == p,
                                  selectedColor: AppColors.brand,
                                  backgroundColor: Theme.of(context).cardColor,
                                  onSelected: (_) => setState(() {
                                    _period = p;
                                    _customRange = null;
                                    _allDates = false;
                                  }),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color:
                                          (_customRange == null && _period == p)
                                          ? AppColors.lightBorder
                                          : borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  showCheckmark: false,
                                ),
                              ActionChip(
                                label: Text(
                                  _customRange == null
                                      ? 'Custom...'
                                      : 'Custom: ${DateFormat.yMd().format(_customRange!.start)} – ${DateFormat.yMd().format(_customRange!.end)}',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                  ),
                                ),
                                onPressed: () async {
                                  final range = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (range != null && mounted) {
                                    setState(() {
                                      _customRange = range;
                                      _allDates = false;
                                    });
                                  }
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: _customRange != null
                                        ? AppColors.lightBorder
                                        : borderColor,
                                    width: 2,
                                  ),
                                ),
                                backgroundColor: _customRange != null
                                    ? AppColors.brand
                                    : Theme.of(context).cardColor,
                              ),
                              if (_customRange != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () =>
                                      setState(() => _customRange = null),
                                  tooltip: 'Clear custom range',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Sort by',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                value: _sortBy,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'date',
                                    child: Text('Date'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'amount',
                                    child: Text('Amount'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'category',
                                    child: Text('Category'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'account',
                                    child: Text('Account'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _sortBy = v ?? 'date'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<bool>(
                                decoration: InputDecoration(
                                  labelText: 'Order',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                value: _sortAscending,
                                items: [
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text(
                                      _sortBy == 'date'
                                          ? 'Newest first'
                                          : _sortBy == 'amount'
                                          ? 'Highest first'
                                          : 'Z–A',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text(
                                      _sortBy == 'date'
                                          ? 'Oldest first'
                                          : _sortBy == 'amount'
                                          ? 'Lowest first'
                                          : 'A–Z',
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _sortAscending = v ?? false),
                              ),
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
          if (_customRange == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(
                      () => _anchorDate = _shiftHistoryDate(
                        _anchorDate,
                        _period,
                        -1,
                      ),
                    ),
                  ),
                  Text(
                    _formatRange(dateRange),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(
                      () => _anchorDate = _shiftHistoryDate(
                        _anchorDate,
                        _period,
                        1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_customRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Custom Range: ${_formatRange(dateRange)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BrutalCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_type == 'all' || _type == 'expense')
                    Column(
                      children: [
                        Text(
                          'Expenses',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMinorUnits(totalExpense),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  if (_type == 'all' || _type == 'income')
                    Column(
                      children: [
                        Text(
                          'Income',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMinorUnits(totalIncome),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching transactions',
                    message: 'Try another search or date filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: sortedGroupKeys.length,
                    itemBuilder: (context, i) {
                      final date = sortedGroupKeys[i];
                      final txnsInGroup = groups[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('d MMMM y (E)').format(date),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          BrutalCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (
                                  int j = 0;
                                  j < txnsInGroup.length;
                                  j++
                                ) ...[
                                  if (j > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: borderColor,
                                    ),
                                  _HistoryTransactionTile(
                                    transaction: txnsInGroup[j],
                                    account:
                                        accountMap[txnsInGroup[j].accountId],
                                    destination:
                                        accountMap[txnsInGroup[j]
                                            .destinationAccountId],
                                    category:
                                        categoryMap[txnsInGroup[j].categoryId],
                                    onTap: () => _push(
                                      context,
                                      TransactionDetailScreen(
                                        transactionId: txnsInGroup[j].id,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatRange(MoneyRange range) {
    if (_period == MoneyPeriod.day)
      return DateFormat.yMMMd().format(range.start);
    if (_period == MoneyPeriod.month)
      return DateFormat.yMMM().format(range.start);
    if (_period == MoneyPeriod.year) return DateFormat.y().format(range.start);
    return '${DateFormat.MMMd().format(range.start)} - ${DateFormat.yMMMd().format(range.end.subtract(const Duration(days: 1)))}';
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

DateTime _shiftHistoryDate(DateTime date, MoneyPeriod period, int direction) =>
    switch (period) {
      MoneyPeriod.day => date.add(Duration(days: direction)),
      MoneyPeriod.week => date.add(Duration(days: 7 * direction)),
      MoneyPeriod.month => DateTime(date.year, date.month + direction, 1),
      MoneyPeriod.year => DateTime(date.year + direction, date.month, 1),
      MoneyPeriod.custom => date,
    };
