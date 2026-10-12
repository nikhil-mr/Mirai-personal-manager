import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/money_providers.dart';
import '../data/money_excel_service.dart';
import '../domain/money_models.dart';

class MoneyExcelButtons extends ConsumerWidget {
  const MoneyExcelButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => _import(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import Excel'),
      ),
      OutlinedButton.icon(
        onPressed: () => _export(context, ref),
        icon: const Icon(Icons.download),
        label: const Text('Export Excel'),
      ),
    ],
  );

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final preview = MoneyExcelService().parse(bytes);
      final repository = ref.read(moneyRepositoryProvider);
      final accounts = await repository.accounts(includeArchived: true);
      final categories = await repository.categories(includeArchived: true);
      final existingTransactions = await repository.transactions();
      final accountKeys = accounts
          .map((row) => row.name.trim().toLowerCase())
          .toSet();
      final accountsByName = {
        for (final row in accounts) row.name.trim().toLowerCase(): row.id,
      };
      final categoryKeys = categories
          .map((row) => '${row.type}:${row.name.trim().toLowerCase()}')
          .toSet();
      final categoriesByName = {
        for (final row in categories)
          '${row.type}:${row.name.trim().toLowerCase()}': row.id,
      };
      final newAccounts = <String>{};
      final newCategories = <String>{};
      final reusedAccounts = <String>{};
      final reusedCategories = <String>{};
      final conflicts = <String>{};
      for (final row in preview.rows.where((row) => row.valid)) {
        final sourceMatches = accounts
            .where(
              (account) =>
                  account.name.trim().toLowerCase() ==
                  row.account.trim().toLowerCase(),
            )
            .toList();
        if (sourceMatches.length > 1 ||
            sourceMatches.any((account) => account.archivedAt != null)) {
          conflicts.add('Account: ${row.account}');
        }
        if (!accountKeys.contains(row.account.toLowerCase())) {
          newAccounts.add(row.account.trim());
        } else {
          reusedAccounts.add(row.account.trim());
        }
        if (row.destination != null &&
            !accountKeys.contains(row.destination!.toLowerCase())) {
          newAccounts.add(row.destination!.trim());
        } else if (row.destination != null) {
          reusedAccounts.add(row.destination!.trim());
        }
        if (row.destination != null) {
          final destinationMatches = accounts
              .where(
                (account) =>
                    account.name.trim().toLowerCase() ==
                    row.destination!.trim().toLowerCase(),
              )
              .toList();
          if (destinationMatches.length > 1 ||
              destinationMatches.any((account) => account.archivedAt != null)) {
            conflicts.add('Account: ${row.destination}');
          }
        }
        if (row.category != null &&
            !categoryKeys.contains(
              '${row.type!.name}:${row.category!.toLowerCase()}',
            )) {
          newCategories.add('${row.type!.name}: ${row.category!.trim()}');
        } else if (row.category != null) {
          reusedCategories.add('${row.type!.name}: ${row.category!.trim()}');
        }
        if (row.category != null) {
          final matches = categories
              .where(
                (category) =>
                    category.type == row.type!.name &&
                    category.name.trim().toLowerCase() ==
                        row.category!.trim().toLowerCase(),
              )
              .toList();
          if (matches.length > 1 ||
              matches.any((category) => category.archivedAt != null)) {
            conflicts.add('Category: ${row.category}');
          }
        }
      }
      final possibleDuplicates = <int>{};
      for (var index = 0; index < preview.rows.length; index++) {
        final row = preview.rows[index];
        if (!row.valid) continue;
        final accountId = accountsByName[row.account.trim().toLowerCase()];
        final destinationId = row.destination == null
            ? null
            : accountsByName[row.destination!.trim().toLowerCase()];
        final categoryId = row.category == null
            ? null
            : categoriesByName['${row.type!.name}:${row.category!.trim().toLowerCase()}'];
        if (existingTransactions.any(
          (existing) =>
              (existing.sourceModule == 'excel_import' &&
                  existing.sourceReferenceId == row.fingerprint) ||
              (accountId != null &&
                  existing.type == row.type!.name &&
                  existing.occurredAt.isAtSameMomentAs(row.date!) &&
                  existing.amountMinor == row.amountMinor &&
                  existing.accountId == accountId &&
                  existing.destinationAccountId == destinationId &&
                  existing.categoryId == categoryId &&
                  existing.note.trim() == row.note.trim()),
        )) {
          possibleDuplicates.add(index);
        }
      }
      var includePossibleDuplicates = false;
      var reviewedRows = List<MoneyExcelImportRow>.of(preview.rows);
      final selectedRows = <int>{
        for (var index = 0; index < reviewedRows.length; index++)
          if (reviewedRows[index].valid) index,
      };
      if (!context.mounted) return;
      final rowsToImport = await showDialog<List<MoneyExcelImportRow>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) => AlertDialog(
            title: const Text('Preview Excel import'),
            content: SizedBox(
              width: math.min(760, MediaQuery.sizeOf(context).width * 0.88),
              height: math.min(720, MediaQuery.sizeOf(context).height * 0.78),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sheets: ${preview.sheets.join(', ')}'),
                          for (final sheet in preview.detectedHeaders.keys)
                            Text(
                              '$sheet: ${preview.rowCounts[sheet]} rows; headers: ${preview.detectedHeaders[sheet]!.join(', ')}',
                            ),
                          Text(
                            'Source rows: ${reviewedRows.length}  •  Valid: ${reviewedRows.where((row) => row.valid).length}  •  Needs review: ${reviewedRows.where((row) => !row.valid).length}  •  Included: ${selectedRows.length}',
                          ),
                          Text(
                            'Possible duplicates: ${possibleDuplicates.length}',
                          ),
                          if (conflicts.isNotEmpty)
                            Text(
                              'Resolve archived or ambiguous matches in account/category management first: ${conflicts.join(', ')}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          Text(
                            'New accounts: ${newAccounts.isEmpty ? 'none' : newAccounts.join(', ')}',
                          ),
                          Text(
                            'New categories: ${newCategories.isEmpty ? 'none' : newCategories.join(', ')}',
                          ),
                          Text(
                            'Accounts reused: ${reusedAccounts.isEmpty ? 'none' : reusedAccounts.join(', ')}',
                          ),
                          Text(
                            'Categories reused: ${reusedCategories.isEmpty ? 'none' : reusedCategories.join(', ')}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: reviewedRows.length,
                      itemBuilder: (context, index) {
                        final row = reviewedRows[index];
                        final detail = row.valid
                            ? '${row.type!.name} • ${DateFormat.yMMMd().add_Hm().format(row.date!.toLocal())} • ${row.account}${row.destination == null ? '' : ' → ${row.destination}'} • ${row.category ?? 'Transfer'} • ${formatMinorUnits(row.amountMinor!)}${possibleDuplicates.contains(index) ? ' • possible duplicate' : ''}'
                            : row.issue ?? 'Row needs review.';
                        return ListTile(
                          dense: true,
                          onTap: row.valid
                              ? null
                              : () async {
                                  final corrected = await _correctRow(
                                    context,
                                    row,
                                  );
                                  if (corrected == null || !context.mounted) {
                                    return;
                                  }
                                  refresh(() {
                                    reviewedRows[index] = corrected;
                                    selectedRows.add(index);
                                    if (!accountKeys.contains(
                                      corrected.account.toLowerCase(),
                                    )) {
                                      newAccounts.add(corrected.account);
                                    }
                                    if (corrected.destination != null &&
                                        !accountKeys.contains(
                                          corrected.destination!.toLowerCase(),
                                        )) {
                                      newAccounts.add(corrected.destination!);
                                    }
                                    if (corrected.category != null &&
                                        !categoryKeys.contains(
                                          '${corrected.type!.name}:${corrected.category!.toLowerCase()}',
                                        )) {
                                      newCategories.add(
                                        '${corrected.type!.name}: ${corrected.category}',
                                      );
                                    }
                                    final accountId =
                                        accountsByName[corrected.account
                                            .toLowerCase()];
                                    final destinationId =
                                        corrected.destination == null
                                        ? null
                                        : accountsByName[corrected.destination!
                                              .toLowerCase()];
                                    final categoryId =
                                        corrected.category == null
                                        ? null
                                        : categoriesByName['${corrected.type!.name}:${corrected.category!.toLowerCase()}'];
                                    if (existingTransactions.any(
                                      (existing) =>
                                          (accountId != null &&
                                          existing.type ==
                                              corrected.type!.name &&
                                          existing.occurredAt.isAtSameMomentAs(
                                            corrected.date!,
                                          ) &&
                                          existing.amountMinor ==
                                              corrected.amountMinor &&
                                          existing.accountId == accountId &&
                                          existing.destinationAccountId ==
                                              destinationId &&
                                          existing.categoryId == categoryId &&
                                          existing.note.trim() ==
                                              corrected.note.trim()),
                                    )) {
                                      possibleDuplicates.add(index);
                                    }
                                  });
                                },
                          leading: Icon(
                            row.valid
                                ? Icons.check_circle_outline
                                : Icons.warning_amber,
                            color: row.valid
                                ? null
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            '${row.sheet} row ${row.sourceRow}: $detail',
                          ),
                          subtitle: Text(
                            row.note.isEmpty ? 'No comment' : row.note,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!row.valid)
                                IconButton(
                                  tooltip: 'Correct this row',
                                  onPressed: () async {
                                    final corrected = await _correctRow(
                                      context,
                                      row,
                                    );
                                    if (corrected != null && context.mounted) {
                                      refresh(() {
                                        reviewedRows[index] = corrected;
                                        selectedRows.add(index);
                                        if (!accountKeys.contains(
                                          corrected.account.toLowerCase(),
                                        )) {
                                          newAccounts.add(corrected.account);
                                        }
                                        if (corrected.destination != null &&
                                            !accountKeys.contains(
                                              corrected.destination!
                                                  .toLowerCase(),
                                            )) {
                                          newAccounts.add(
                                            corrected.destination!,
                                          );
                                        }
                                        if (corrected.category != null &&
                                            !categoryKeys.contains(
                                              '${corrected.type!.name}:${corrected.category!.toLowerCase()}',
                                            )) {
                                          newCategories.add(
                                            '${corrected.type!.name}: ${corrected.category}',
                                          );
                                        }
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              Checkbox(
                                value: selectedRows.contains(index),
                                onChanged: (value) async {
                                  if (value == true && !row.valid) {
                                    final corrected = await _correctRow(
                                      context,
                                      row,
                                    );
                                    if (corrected != null && context.mounted) {
                                      refresh(() {
                                        reviewedRows[index] = corrected;
                                        selectedRows.add(index);
                                      });
                                    }
                                    return;
                                  }
                                  refresh(() {
                                    if (value == true) {
                                      selectedRows.add(index);
                                    } else {
                                      selectedRows.remove(index);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includePossibleDuplicates,
                    onChanged: (value) => refresh(
                      () => includePossibleDuplicates = value ?? false,
                    ),
                    title: const Text('Import possible duplicates anyway'),
                    subtitle: const Text(
                      'Reimported Excel rows with a saved import reference are always skipped.',
                    ),
                  ),
                  const Text(
                    'New accounts use a zero opening balance. Imported history changes their calculated balances.',
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
                onPressed: selectedRows.isEmpty || conflicts.isNotEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        reviewedRows
                            .asMap()
                            .entries
                            .where(
                              (entry) =>
                                  selectedRows.contains(entry.key) &&
                                  entry.value.valid,
                            )
                            .map((entry) => entry.value)
                            .toList(),
                      ),
                child: Text('Import ${selectedRows.length} rows'),
              ),
            ],
          ),
        ),
      );
      if (rowsToImport == null || rowsToImport.isEmpty || !context.mounted) {
        return;
      }
      final importRows = rowsToImport.map((row) => row.toRecord()).toList();
      final result = await repository.importTransactions(
        importRows,
        skipPossibleDuplicates: !includePossibleDuplicates,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import complete'),
          content: Text(
            'Income: ${result.incomeImported}\nExpenses: ${result.expensesImported}\nTransfers: ${result.transfersImported}\nAccounts created: ${result.accountsCreated}\nCategories created: ${result.categoriesCreated}\nDuplicates skipped: ${result.duplicatesSkipped}\nRows requiring review or excluded: ${reviewedRows.length - rowsToImport.length}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, 'Excel import failed: $error');
    }
  }

  Future<MoneyExcelImportRow?> _correctRow(
    BuildContext context,
    MoneyExcelImportRow row,
  ) async {
    final date = TextEditingController(
      text: row.date == null
          ? ''
          : DateFormat('yyyy-MM-dd HH:mm').format(row.date!.toLocal()),
    );
    final amount = TextEditingController(
      text: row.amountMinor == null
          ? ''
          : '${row.amountMinor! ~/ 100}.${(row.amountMinor! % 100).toString().padLeft(2, '0')}',
    );
    final account = TextEditingController(text: row.account);
    final destination = TextEditingController(text: row.destination ?? '');
    final category = TextEditingController(text: row.category ?? '');
    final note = TextEditingController(text: row.note);
    var type = row.type ?? MoneyType.expense;
    var error = '';
    final corrected = await showDialog<MoneyExcelImportRow>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text('Correct ${row.sheet} row ${row.sourceRow}'),
          content: SizedBox(
            width: math.min(440, MediaQuery.sizeOf(context).width * 0.86),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.issue != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Original issue: ${row.issue}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  DropdownButtonFormField<MoneyType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: MoneyType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => refresh(() => type = value ?? type),
                  ),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Date and time',
                      hintText: 'YYYY-MM-DD HH:mm',
                    ),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount in INR',
                    ),
                  ),
                  TextField(
                    controller: account,
                    decoration: InputDecoration(
                      labelText: type == MoneyType.transfer
                          ? 'Source account'
                          : 'Account',
                    ),
                  ),
                  if (type == MoneyType.transfer)
                    TextField(
                      controller: destination,
                      decoration: const InputDecoration(
                        labelText: 'Destination account',
                      ),
                    )
                  else
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Comment'),
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedDate = MoneyExcelService.parseDateText(date.text);
                final parsedAmount = parseMinorUnits(
                  amount.text.replaceAll(',', ''),
                );
                final accountName = account.text.trim();
                final destinationName = destination.text.trim();
                final categoryName = category.text.trim();
                if (parsedDate == null ||
                    parsedAmount == null ||
                    parsedAmount <= 0 ||
                    accountName.isEmpty ||
                    accountName.length > 80 ||
                    (type == MoneyType.transfer &&
                        (destinationName.isEmpty ||
                            destinationName.length > 80 ||
                            destinationName.toLowerCase() ==
                                accountName.toLowerCase())) ||
                    (type != MoneyType.transfer &&
                        (categoryName.isEmpty || categoryName.length > 60))) {
                  refresh(
                    () => error = 'Enter a valid date, positive INR amount, account, and type-specific details.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  row.corrected(
                    correctedType: type,
                    correctedDate: parsedDate,
                    correctedAmountMinor: parsedAmount,
                    correctedAccount: accountName,
                    correctedDestination: destinationName,
                    correctedCategory: categoryName,
                    correctedNote: note.text,
                  ),
                );
              },
              child: const Text('Use corrected row'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      date,
      amount,
      account,
      destination,
      category,
      note,
    ]) {
      controller.dispose();
    }
    return corrected;
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(moneyRepositoryProvider);
      final accounts = await repository.accounts(includeArchived: true);
      final categories = await repository.categories(includeArchived: true);
      final transactions = await repository.transactions();
      if (!context.mounted) return;
      var allAccounts = true;
      final selectedAccounts = <String>{};
      DateTime? start;
      DateTime? end;
      var selectedTypes = MoneyType.values.toSet();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) => AlertDialog(
            title: const Text('Export Excel'),
            content: SizedBox(
              width: math.min(480, MediaQuery.sizeOf(context).width * 0.88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allAccounts,
                    title: const Text('All accounts'),
                    onChanged: (value) => refresh(() {
                      allAccounts = value ?? false;
                      if (allAccounts) selectedAccounts.clear();
                    }),
                  ),
                  if (!allAccounts)
                    SizedBox(
                      height: 120,
                      child: ListView(
                        children: [
                          for (final account in accounts)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selectedAccounts.contains(account.id),
                              title: Text(account.name),
                              onChanged: (value) => refresh(() {
                                if (value == true) {
                                  selectedAccounts.add(account.id);
                                } else {
                                  selectedAccounts.remove(account.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  if (!allAccounts && selectedAccounts.isEmpty)
                    const Text('Select at least one account.'),
                  Wrap(
                    children: [
                      for (final type in MoneyType.values)
                        FilterChip(
                          label: Text(
                            type.name[0].toUpperCase() + type.name.substring(1),
                          ),
                          selected: selectedTypes.contains(type),
                          onSelected: (value) => refresh(() {
                            if (value) {
                              selectedTypes.add(type);
                            } else {
                              selectedTypes.remove(type);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: dialogContext,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (range != null) {
                        refresh(() {
                          start = DateTime(
                            range.start.year,
                            range.start.month,
                            range.start.day,
                          );
                          end = DateTime(
                            range.end.year,
                            range.end.month,
                            range.end.day + 1,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      start == null
                          ? 'All dates'
                          : '${DateFormat.yMMMd().format(start!)} – ${DateFormat.yMMMd().format(end!.subtract(const Duration(days: 1)))}',
                    ),
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
                onPressed:
                    selectedTypes.isEmpty ||
                        (!allAccounts && selectedAccounts.isEmpty)
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Export'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final bytes = MoneyExcelService().export(
        accounts: accounts,
        categories: categories,
        transactions: transactions,
        start: start,
        end: end,
        accountIds: allAccounts ? null : selectedAccounts,
        types: selectedTypes,
      );
      final fileName =
          'life_partner_money_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final location = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: 'Export Money Manager workbook',
      );
      if (location != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel workbook exported.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, 'Excel export failed: $error');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
