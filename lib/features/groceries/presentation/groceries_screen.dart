import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../../money/domain/money_models.dart';
import '../application/grocery_providers.dart';
import '../data/grocery_repository.dart';

class GroceriesScreen extends ConsumerStatefulWidget {
  const GroceriesScreen({super.key});
  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  String? _selectedListId;
  String _query = '';
  String _status = 'All';
  String _category = 'All';
  String _sort = 'Recently added';
  bool _showInventory = true;
  String _inventoryLocation = 'All locations';
  String _expiryFilter = 'All expiry dates';
  bool _showArchived = false;
  final Set<String> _purchaseSelection = {};

  Widget _inventoryBody(List<GroceryList> lists) {
    final inventoryAsync = ref.watch(homeInventoryProvider);
    return inventoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Could not load home inventory: $error'),
      data: (allItems) {
        final locations = allItems.map((item) => item.location).toSet().toList()
          ..sort();
        final now = DateUtils.dateOnly(DateTime.now());
        final soon = now.add(const Duration(days: 7));
        final query = _query.trim().toLowerCase();
        final items =
            allItems.where((item) {
              final locationMatch =
                  _inventoryLocation == 'All locations' ||
                  item.location == _inventoryLocation;
              final expiry = item.expiryAt == null
                  ? null
                  : DateUtils.dateOnly(item.expiryAt!.toLocal());
              final expiryMatch = switch (_expiryFilter) {
                'Expiring soon' =>
                  expiry != null &&
                      !expiry.isBefore(now) &&
                      !expiry.isAfter(soon),
                'Expired' => expiry != null && expiry.isBefore(now),
                'No expiry date' => expiry == null,
                _ => true,
              };
              final textMatch =
                  query.isEmpty ||
                  '${item.name} ${item.notes}'.toLowerCase().contains(query);
              final categoryMatch =
                  _category == 'All' || item.category == _category;
              return locationMatch && expiryMatch && textMatch && categoryMatch;
            }).toList()..sort((a, b) {
              if (_sort == 'Name') {
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              }
              if (_sort == 'Recently added') {
                return b.createdAt.compareTo(a.createdAt);
              }
              return (a.expiryAt ?? DateTime(9999)).compareTo(
                b.expiryAt ?? DateTime(9999),
              );
            });
        final categories =
            allItems.map((item) => item.category).toSet().toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${allItems.length} items at home',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${allItems.where((item) => item.expiryAt != null && DateUtils.dateOnly(item.expiryAt!.toLocal()).isBefore(now)).length} expired',
                    ),
                    Text(
                      '${allItems.where((item) {
                        final d = item.expiryAt == null ? null : DateUtils.dateOnly(item.expiryAt!.toLocal());
                        return d != null && !d.isBefore(now) && !d.isAfter(soon);
                      }).length} expiring within 7 days',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search inventory name or notes',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                DropdownButton<String>(
                  value:
                      _inventoryLocation == 'All locations' ||
                          locations.contains(_inventoryLocation)
                      ? _inventoryLocation
                      : 'All locations',
                  items: ['All locations', ...locations]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _inventoryLocation = value ?? 'All locations',
                  ),
                ),
                DropdownButton<String>(
                  value: _expiryFilter,
                  items:
                      const [
                            'All expiry dates',
                            'Expiring soon',
                            'Expired',
                            'No expiry date',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(
                    () => _expiryFilter = value ?? 'All expiry dates',
                  ),
                ),
                DropdownButton<String>(
                  value: categories.contains(_category) || _category == 'All'
                      ? _category
                      : 'All',
                  items: ['All', ...categories]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 'All' ? 'All categories' : value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'All'),
                ),
                DropdownButton<String>(
                  value: _sort,
                  items: const ['Recently added', 'Name', 'Expiry date']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('Sort: $value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sort = value ?? _sort),
                ),
              ],
            ),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.kitchen_outlined,
                title: 'No inventory items found',
                message: 'Add what you currently have at home, or adjust the filters.',
              )
            else
              for (final item in items) _inventoryCard(item, lists),
          ],
        );
      },
    );
  }

  Widget _inventoryCard(HomeInventoryItem item, List<GroceryList> lists) {
    final expiryDate = item.expiryAt?.toLocal();
    final expired =
        expiryDate != null &&
        DateUtils.dateOnly(expiryDate)
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    final expiring =
        expiryDate != null &&
        !expired &&
        !DateUtils.dateOnly(expiryDate).isAfter(
          DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7)),
        );
    final details = <String>[
      '${_quantityText(item.quantityMilli)} ${item.unit}',
      item.category,
      item.location,
    ];
    if (expiryDate != null) {
      details.add(
        '${expired
            ? 'Expired'
            : expiring
            ? 'Expires soon'
            : 'Best before'} ${DateFormat.yMMMd().format(expiryDate)}',
      );
    }
    if (item.unitCostMinor != null) {
      details.add('Unit cost ${formatMinorUnits(item.unitCostMinor!)}');
    }
    if (item.notes.isNotEmpty) {
      details.add(item.notes);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_categoryIcon(item.category))),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(details.join(' · ')),
        trailing: PopupMenuButton<String>(
          tooltip: 'Inventory item actions',
          onSelected: (action) async {
            switch (action) {
              case 'edit':
                await _editInventoryItem(item: item);
                break;
              case 'quantity':
                await _adjustInventory(item);
                break;
              case 'move':
                await _moveInventory(item);
                break;
              case 'shopping':
                await _addInventoryToShopping(item, lists);
                break;
              case 'used':
                await ref
                    .read(groceryRepositoryProvider)
                    .adjustInventoryQuantity(item.id, 0);
                break;
              case 'delete':
                if (await _confirm(
                      'Delete ${item.name}?',
                      'Remove this inventory record?',
                    ) ==
                    true) {
                  await ref
                      .read(groceryRepositoryProvider)
                      .deleteInventoryItem(item.id);
                }
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit item')),
            PopupMenuItem(value: 'quantity', child: Text('Change quantity')),
            PopupMenuItem(value: 'move', child: Text('Move storage location')),
            PopupMenuItem(value: 'shopping', child: Text('Add to Basket')),
            PopupMenuItem(value: 'used', child: Text('Mark as used up')),
            PopupMenuItem(value: 'delete', child: Text('Delete item')),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
    'fruits' => Icons.apple_outlined,
    'vegetables' => Icons.eco_outlined,
    'dairy' => Icons.egg_outlined,
    'meat and seafood' => Icons.set_meal_outlined,
    'beverages' => Icons.local_drink_outlined,
    'snacks' => Icons.cookie_outlined,
    'household essentials' => Icons.cleaning_services_outlined,
    _ => Icons.inventory_2_outlined,
  };

  Future<void> _editInventoryItem({HomeInventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final quantity = TextEditingController(
      text: _quantityText(item?.quantityMilli ?? 1000),
    );
    final unit = TextEditingController(text: item?.unit ?? 'Piece');
    final category = TextEditingController(text: item?.category ?? 'Other');
    final location = TextEditingController(text: item?.location ?? 'Pantry');
    final cost = TextEditingController(
      text: item?.unitCostMinor == null ? '' : _minorText(item!.unitCostMinor!),
    );
    final notes = TextEditingController(text: item?.notes ?? '');
    DateTime? expiry = item?.expiryAt;
    DateTime? purchased = item?.purchasedAt;
    var error = '';
    final input = await showDialog<InventoryItemInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(
            item == null ? 'Add inventory item' : 'Edit inventory item',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Item name *'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            hintText: 'Piece, kg, litre, pack...',
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'Fruits, dairy, household...',
                    ),
                  ),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Storage location *',
                      hintText: 'Fridge, freezer, pantry...',
                    ),
                  ),
                  TextField(
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Unit cost (optional)',
                      prefixText: '₹',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2200),
                              initialDate: expiry ?? DateTime.now(),
                            );
                            if (date != null) refresh(() => expiry = date);
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            expiry == null
                                ? 'Expiry date'
                                : 'Expires ${DateFormat.yMMMd().format(expiry!.toLocal())}',
                          ),
                        ),
                        if (expiry != null)
                          IconButton(
                            tooltip: 'Remove expiry date',
                            onPressed: () => refresh(() => expiry = null),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2200),
                              initialDate: purchased ?? DateTime.now(),
                            );
                            if (date != null) refresh(() => purchased = date);
                          },
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            purchased == null
                                ? 'Purchase date (optional)'
                                : 'Bought ${DateFormat.yMMMd().format(purchased!.toLocal())}',
                          ),
                        ),
                        if (purchased != null)
                          IconButton(
                            tooltip: 'Remove purchase date',
                            onPressed: () => refresh(() => purchased = null),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
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
                final parsedQuantity = _parseMilli(quantity.text);
                final parsedCost = cost.text.trim().isEmpty
                    ? null
                    : parseMinorUnits(cost.text);
                if (name.text.trim().isEmpty ||
                    parsedQuantity == null ||
                    parsedQuantity < (item == null ? 1 : 0) ||
                    unit.text.trim().isEmpty ||
                    location.text.trim().isEmpty ||
                    (cost.text.trim().isNotEmpty &&
                        (parsedCost == null || parsedCost < 0))) {
                  refresh(
                    () => error = 'Enter a name, valid quantity, unit and location. Unit cost must be a valid non-negative amount.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  InventoryItemInput(
                    name: name.text,
                    quantityMilli: parsedQuantity,
                    unit: unit.text,
                    category: category.text,
                    location: location.text,
                    expiryAt: expiry,
                    purchasedAt: purchased,
                    unitCostMinor: parsedCost,
                    notes: notes.text,
                  ),
                );
              },
              child: const Text('Save item'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      name,
      quantity,
      unit,
      category,
      location,
      cost,
      notes,
    ]) {
      controller.dispose();
    }
    if (input == null || !mounted) return;
    try {
      if (item == null) {
        final duplicates = await ref
            .read(groceryRepositoryProvider)
            .findInventoryDuplicates(input.name, input.location);
        if (duplicates.isNotEmpty && mounted) {
          final compatible = duplicates
              .where(
                (row) =>
                    row.unit.toLowerCase() == input.unit.trim().toLowerCase(),
              )
              .toList();
          final decision = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('This item is already in this location'),
              content: Text(
                'There ${duplicates.length == 1 ? 'is' : 'are'} ${duplicates.length} matching inventory entr${duplicates.length == 1 ? 'y' : 'ies'} for ${input.name} in ${input.location}. Choose how to save it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'separate'),
                  child: const Text('Keep separate'),
                ),
                if (compatible.length == 1)
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'merge'),
                    child: const Text('Increase quantity'),
                  ),
              ],
            ),
          );
          if (decision == 'cancel' || decision == null) return;
          if (decision == 'merge') {
            final old = compatible.single;
            await ref
                .read(groceryRepositoryProvider)
                .saveInventoryItem(
                  id: old.id,
                  item: InventoryItemInput(
                    name: old.name,
                    quantityMilli: old.quantityMilli + input.quantityMilli,
                    unit: old.unit,
                    category: input.category,
                    location: old.location,
                    expiryAt: input.expiryAt ?? old.expiryAt,
                    purchasedAt: input.purchasedAt ?? old.purchasedAt,
                    unitCostMinor: input.unitCostMinor ?? old.unitCostMinor,
                    notes: input.notes.isEmpty ? old.notes : input.notes,
                  ),
                );
            return;
          }
        }
      }
      await ref
          .read(groceryRepositoryProvider)
          .saveInventoryItem(id: item?.id, item: input);
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _addMultipleInventoryItems() async {
    final rows = <_BulkInventoryRow>[_BulkInventoryRow()];
    String error = '';
    final result = await showDialog<List<InventoryItemInput>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Add multiple inventory items'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: rows[i].name,
                            decoration: InputDecoration(
                              labelText: 'Item ${i + 1} *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: rows[i].quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Qty *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: rows[i].unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove row',
                          onPressed: rows.length == 1
                              ? null
                              : () => refresh(() => rows.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rows[i].location,
                            decoration: const InputDecoration(
                              labelText: 'Storage location',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2200),
                              initialDate: rows[i].expiryAt ?? DateTime.now(),
                            );
                            if (date != null) {
                              refresh(() => rows[i].expiryAt = date);
                            }
                          },
                          child: Text(
                            rows[i].expiryAt == null
                                ? 'Expiry (optional)'
                                : DateFormat.yMMMd().format(
                                    rows[i].expiryAt!.toLocal(),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          refresh(() => rows.add(_BulkInventoryRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add another row'),
                    ),
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
                final parsed = rows
                    .map((row) => _parseMilli(row.quantity.text))
                    .toList();
                if (rows.any(
                      (row) =>
                          row.name.text.trim().isEmpty ||
                          row.unit.text.trim().isEmpty ||
                          row.location.text.trim().isEmpty,
                    ) ||
                    parsed.any((q) => q == null || q <= 0)) {
                  refresh(
                    () => error = 'Fix every row: enter an item name, non-negative quantity, unit and location.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, [
                  for (var i = 0; i < rows.length; i++)
                    InventoryItemInput(
                      name: rows[i].name.text,
                      quantityMilli: parsed[i]!,
                      unit: rows[i].unit.text,
                      category: 'Other',
                      location: rows[i].location.text,
                      expiryAt: rows[i].expiryAt,
                    ),
                ]);
              },
              child: const Text('Save all'),
            ),
          ],
        ),
      ),
    );
    for (final row in rows) {
      row.dispose();
    }
    if (result == null || !mounted) return;
    try {
      await ref.read(groceryRepositoryProvider).addInventoryItems(result);
    } catch (error) {
      _message('Nothing was saved. $error');
    }
  }

  Future<void> _addMultipleShoppingItems(String listId) async {
    final rows = <_BulkShoppingRow>[_BulkShoppingRow()];
    String error = '';
    final result = await showDialog<List<ShoppingItemInput>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Add multiple shopping items'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: rows[i].name,
                            decoration: InputDecoration(
                              labelText: 'Item ${i + 1} *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: rows[i].quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Qty *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: rows[i].unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove row',
                          onPressed: rows.length == 1
                              ? null
                              : () => refresh(() => rows.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          refresh(() => rows.add(_BulkShoppingRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add another row'),
                    ),
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
                final parsed = rows
                    .map((row) => _parseMilli(row.quantity.text))
                    .toList();
                if (rows.any(
                      (row) =>
                          row.name.text.trim().isEmpty ||
                          row.unit.text.trim().isEmpty,
                    ) ||
                    parsed.any((q) => q == null || q <= 0)) {
                  refresh(
                    () => error = 'Fix every row: enter a name, positive quantity and unit.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, [
                  for (var i = 0; i < rows.length; i++)
                    ShoppingItemInput(
                      name: rows[i].name.text,
                      quantityMilli: parsed[i]!,
                      unit: rows[i].unit.text,
                    ),
                ]);
              },
              child: const Text('Save all'),
            ),
          ],
        ),
      ),
    );
    for (final row in rows) {
      row.dispose();
    }
    if (result == null || !mounted) return;
    try {
      await ref
          .read(groceryRepositoryProvider)
          .addShoppingItemsBulk(listId, result);
    } catch (error) {
      _message('Nothing was saved. $error');
    }
  }

  Future<void> _adjustInventory(HomeInventoryItem item) async {
    final quantity = TextEditingController(
      text: _quantityText(item.quantityMilli),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change ${item.name} quantity'),
        content: TextField(
          controller: quantity,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Remaining ${item.unit}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save quantity'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      final value = _parseMilli(quantity.text);
      if (value == null || value < 0) {
        _message('Enter a non-negative quantity.');
      } else {
        await ref
            .read(groceryRepositoryProvider)
            .adjustInventoryQuantity(item.id, value);
      }
    }
    quantity.dispose();
  }

  Future<void> _moveInventory(HomeInventoryItem item) async {
    final location = TextEditingController(text: item.location);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move ${item.name}'),
        content: TextField(
          controller: location,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Storage location',
            hintText: 'Fridge, freezer, pantry...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move item'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await ref
          .read(groceryRepositoryProvider)
          .moveInventoryItem(item.id, location.text);
    }
    location.dispose();
  }

  Future<void> _addInventoryToShopping(
    HomeInventoryItem item,
    List<GroceryList> lists,
  ) async {
    if (lists.isEmpty) {
      _message('Create a basket first.');
      return;
    }
    var selectedListId = lists.first.id;
    final listId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${item.name} to Basket'),
        content: StatefulBuilder(
          builder: (ctx, refresh) => DropdownButtonFormField<String>(
            initialValue: selectedListId,
            decoration: const InputDecoration(labelText: 'Choose list'),
            items: lists
                .map(
                  (list) =>
                      DropdownMenuItem(value: list.id, child: Text(list.name)),
                )
                .toList(),
            onChanged: (value) =>
                refresh(() => selectedListId = value ?? selectedListId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selectedListId),
            child: const Text('Add item'),
          ),
        ],
      ),
    );
    if (listId != null) {
      await ref
          .read(groceryRepositoryProvider)
          .addInventoryItemToShopping(inventoryItemId: item.id, listId: listId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(
      _showArchived ? groceryArchivedListsProvider : groceryListsProvider,
    );
    return PageContainer(
      child: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load baskets: $error')),
        data: (lists) {
          final current =
              lists.where((list) => list.id == _selectedListId).firstOrNull ??
              (lists.isEmpty ? null : lists.first);
          if (current != null && current.id != _selectedListId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedListId = current.id);
            });
          }
          return ListView(
            children: [
              _sectionSelector(),
              if (_showInventory) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'My Inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    OutlinedButton.icon(
                      onPressed: _addMultipleInventoryItems,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add multiple'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _editInventoryItem(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Track the food and essentials you currently have at home.',
                ),
                const SizedBox(height: 16),
                _inventoryBody(lists),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Baskets',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    FilledButton.icon(
                      onPressed: _showArchived
                          ? null
                          : current == null
                          ? () => _editList()
                          : () => _editItem(current.id),
                      icon: Icon(
                        current == null ? Icons.playlist_add : Icons.add,
                      ),
                      label: Text(
                        current == null ? 'Create a list' : 'Add item',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: current == null || _showArchived
                          ? null
                          : () => _addMultipleShoppingItems(current.id),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add multiple'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Plan your shop, track what you bought, and record the bill when you are ready.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _listControls(lists, current),
                if (current == null) ...[
                  const SizedBox(height: 32),
                  EmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: _showArchived
                        ? 'No archived lists'
                        : 'No baskets yet',
                    message: _showArchived
                        ? 'Archived lists will appear here.'
                        : 'Create a basket to start adding items.',
                    action: !_showArchived
                        ? FilledButton.icon(
                            onPressed: _editList,
                            icon: const Icon(Icons.add),
                            label: const Text('Create a list'),
                          )
                        : null,
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  _listBody(current),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionSelector() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          icon: Icon(Icons.kitchen_outlined),
          label: Text('My Inventory'),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.shopping_cart_outlined),
          label: Text('Baskets'),
        ),
      ],
      selected: {_showInventory},
      onSelectionChanged: (value) => setState(() {
        _showInventory = value.single;
        _query = '';
      }),
    ),
  );

  Widget _listControls(List<GroceryList> lists, GroceryList? current) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String>(
              initialValue: current?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Basket',
                border: OutlineInputBorder(),
              ),
              items: lists
                  .map(
                    (list) => DropdownMenuItem(
                      value: list.id,
                      child: Text(list.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() {
                _selectedListId = id;
                _query = '';
                _category = 'All';
                _purchaseSelection.clear();
              }),
            ),
          ),
          Wrap(
            spacing: 4,
            children: [
              if (!_showArchived)
                IconButton(
                  tooltip: 'New list',
                  onPressed: _editList,
                  icon: const Icon(Icons.playlist_add),
                ),
              if (current != null)
                PopupMenuButton<String>(
                  tooltip: 'List options',
                  onSelected: (action) => _listAction(action, current),
                  itemBuilder: (_) => _showArchived
                      ? const [
                          PopupMenuItem(
                            value: 'restore',
                            child: Text('Restore list'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete permanently'),
                          ),
                        ]
                      : const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Edit list'),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive list'),
                          ),
                          PopupMenuItem(
                            value: 'clear',
                            child: Text('Clear purchased items'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete permanently'),
                          ),
                        ],
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _showArchived = !_showArchived;
                  _selectedListId = null;
                }),
                icon: Icon(
                  _showArchived ? Icons.list_alt : Icons.archive_outlined,
                ),
                label: Text(_showArchived ? 'Active lists' : 'Archived'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _listBody(GroceryList list) {
    final itemsAsync = ref.watch(groceryItemsProvider(list.id));
    return itemsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load items: $error'),
        ),
      ),
      data: (items) {
        final purchased = items.where((item) => item.isPurchased).toList();
        final remaining = items.where((item) => !item.isPurchased).toList();
        final estimated = _total(items, (item) => item.estimatedUnitPriceMinor);
        final actual = _total(purchased, (item) => item.actualUnitPriceMinor);
        final estimateLeft = _total(
          remaining,
          (item) => item.estimatedUnitPriceMinor,
        );
        final categories = items.map((item) => item.category).toSet().toList()
          ..sort();
        final q = _query.trim().toLowerCase();
        // Keep search, status, and category filters composable.
        final filtered =
            items.where((item) {
              final statusMatch =
                  _status == 'All' ||
                  (_status == 'Purchased') == item.isPurchased;
              final categoryMatch =
                  _category == 'All' || item.category == _category;
              final textMatch =
                  q.isEmpty ||
                  '${item.name} ${item.notes}'.toLowerCase().contains(q);
              return statusMatch && categoryMatch && textMatch;
            }).toList()..sort(
              (a, b) => switch (_sort) {
                'Name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                'Category' => a.category.toLowerCase().compareTo(
                  b.category.toLowerCase(),
                ),
                'Purchase status' => a.isPurchased.toString().compareTo(
                  b.isPurchased.toString(),
                ),
                _ => b.createdAt.compareTo(a.createdAt),
              },
            );
        final progress = items.isEmpty ? 0.0 : purchased.length / items.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (list.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(list.description),
              ),
            if (list.targetAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Target date: ${DateFormat.yMMMd().format(list.targetAt!.toLocal())}',
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${purchased.length} of ${items.length} purchased',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text('${(progress * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _totalText('Estimated list', estimated),
                        _totalText('Purchased actual', actual),
                        _totalText('Estimated remaining', estimateLeft),
                      ],
                    ),
                    if (items.any(
                      (item) =>
                          item.isPurchased && item.actualUnitPriceMinor == null,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Some purchased items do not have an actual price yet.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (purchased.isNotEmpty) ...[
              Text(
                'Choose the purchased items on this bill:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in purchased)
                    FilterChip(
                      label: Text(item.name),
                      selected: _purchaseSelection.contains(item.id),
                      onSelected: _showArchived
                          ? null
                          : (selected) => setState(() {
                              selected
                                  ? _purchaseSelection.add(item.id)
                                  : _purchaseSelection.remove(item.id);
                            }),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _showArchived
                      ? null
                      : () => _recordPurchase(
                          list,
                          _purchaseSelection.isEmpty
                              ? purchased
                              : purchased
                                    .where(
                                      (item) =>
                                          _purchaseSelection.contains(item.id),
                                    )
                                    .toList(),
                        ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(
                    'Record ${_purchaseSelection.isEmpty ? 'all purchased items' : 'selected items'} in Money Manager',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search item names and notes',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final value in const ['All', 'Remaining', 'Purchased'])
                  ChoiceChip(
                    label: Text(value),
                    selected: _status == value,
                    onSelected: (_) => setState(() => _status = value),
                  ),
                DropdownButton<String>(
                  value: categories.contains(_category) || _category == 'All'
                      ? _category
                      : 'All',
                  underline: const SizedBox.shrink(),
                  items: ['All', ...categories]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 'All' ? 'All categories' : value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'All'),
                ),
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  items:
                      const [
                            'Recently added',
                            'Name',
                            'Category',
                            'Purchase status',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('Sort: $value'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _sort = value ?? _sort),
                ),
                if (_query.isNotEmpty || _status != 'All' || _category != 'All')
                  TextButton(
                    onPressed: () => setState(() {
                      _query = '';
                      _status = 'All';
                      _category = 'All';
                    }),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'This list is empty',
                message: 'Add grocery items to plan your shop.',
                action: !_showArchived
                    ? FilledButton.icon(
                        onPressed: () => _editItem(list.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      )
                    : null,
              )
            else if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: 'No matching items',
                message: 'Try another search or clear the filters.',
                compact: true,
              )
            else ...[
              if (remaining.any(filtered.contains))
                _sectionLabel(
                  'To buy',
                  remaining.where(filtered.contains).length,
                ),
              for (final item in filtered.where((item) => !item.isPurchased))
                _itemCard(list, item),
              if (purchased.any(filtered.contains))
                _sectionLabel(
                  'Purchased',
                  purchased.where(filtered.contains).length,
                ),
              for (final item in filtered.where((item) => item.isPurchased))
                _itemCard(list, item),
            ],
          ],
        );
      },
    );
  }

  int? _total(List<GroceryItem> items, int? Function(GroceryItem) price) {
    if (items.any((item) => price(item) == null)) return null;
    return items.fold<int>(
      0,
      (sum, item) => sum + (price(item)! * item.quantityMilli ~/ 1000),
    );
  }

  Widget _totalText(String label, int? amount) => SizedBox(
    width: 175,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          amount == null ? 'Price unknown' : formatMinorUnits(amount),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );

  Widget _sectionLabel(String title, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
    child: Text(
      '$title ($count)',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  Widget _itemCard(GroceryList list, GroceryItem item) {
    final estimatedLine = item.estimatedUnitPriceMinor == null
        ? null
        : formatMinorUnits(
            item.estimatedUnitPriceMinor! * item.quantityMilli ~/ 1000,
          );
    final actualLine = item.actualUnitPriceMinor == null
        ? 'Actual total unknown'
        : 'Actual ${formatMinorUnits(item.actualUnitPriceMinor! * item.quantityMilli ~/ 1000)}';
    final purchasedDate = item.purchasedAt == null
        ? ''
        : ' · ${DateFormat.yMMMd().format(item.purchasedAt!.toLocal())}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: item.isPurchased,
          onChanged: _showArchived
              ? null
              : (value) => _togglePurchased(item, value ?? false),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_quantityText(item.quantityMilli)} ${item.unit} · ${item.category}',
            ),
            Text(
              estimatedLine == null
                  ? 'Estimated total: unknown'
                  : 'Estimated $estimatedLine',
            ),
            if (item.isPurchased) Text('$actualLine$purchasedDate'),
            if (item.notes.isNotEmpty) Text(item.notes),
            FutureBuilder<bool>(
              future: ref
                  .read(groceryRepositoryProvider)
                  .hasRecordedPurchase(item.id),
              builder: (context, snapshot) => snapshot.data == true
                  ? Text(
                      'Linked Money Manager transaction saved',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        isThreeLine: item.notes.isNotEmpty,
        trailing: PopupMenuButton<String>(
          tooltip: 'Item actions',
          onSelected: (action) async {
            if (action == 'edit') await _editItem(list.id, item: item);
            if (action == 'delete') await _deleteItem(item);
            if (action == 'inventory') await _receivePurchasedItem(item);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (item.isPurchased && item.inventoryAppliedAt == null)
              const PopupMenuItem(
                value: 'inventory',
                child: Text('Add purchased quantity to My Inventory'),
              ),
            const PopupMenuItem(value: 'delete', child: Text('Remove item')),
          ],
        ),
      ),
    );
  }

  Future<void> _receivePurchasedItem(GroceryItem item) async {
    final locations = _storageLocations();
    var location = locations.contains('Pantry') ? 'Pantry' : locations.first;
    var mergeExisting = true;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text('Add ${item.name} to My Inventory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(
                  labelText: 'Storage location',
                ),
                items: locations
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    refresh(() => location = value ?? location),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: mergeExisting,
                title: const Text('Increase a matching item in this location'),
                onChanged: (value) =>
                    refresh(() => mergeExisting = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, location),
              child: const Text('Add to inventory'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final added = await ref
          .read(groceryRepositoryProvider)
          .receivePurchasedItem(
            itemId: item.id,
            location: selected,
            addToInventory: true,
            mergeExisting: mergeExisting,
          );
      _message(
        added
            ? 'Inventory updated.'
            : 'This purchase was already added to inventory.',
      );
    } catch (error) {
      _message(error.toString());
    }
  }

  String _quantityText(int milli) => (milli / 1000).toStringAsFixed(
    milli % 1000 == 0
        ? 0
        : milli % 100 == 0
        ? 1
        : milli % 10 == 0
        ? 2
        : 3,
  );

  Future<void> _togglePurchased(GroceryItem item, bool purchased) async {
    int? actual;
    var addToInventory = false;
    var storageLocation = 'Pantry';
    var mergeInventory = true;
    if (purchased) {
      final price = TextEditingController(
        text: item.actualUnitPriceMinor == null
            ? ''
            : _minorText(item.actualUnitPriceMinor!),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: Text('Mark ${item.name} purchased?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: price,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Actual unit price (optional)',
                    prefixText: '₹',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: addToInventory,
                  title: const Text('Add purchased quantity to My Inventory'),
                  onChanged: (value) =>
                      refresh(() => addToInventory = value ?? false),
                ),
                if (addToInventory)
                  DropdownButtonFormField<String>(
                    initialValue: storageLocation,
                    decoration: const InputDecoration(
                      labelText: 'Storage location',
                    ),
                    items: _storageLocations()
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => refresh(
                      () => storageLocation = value ?? storageLocation,
                    ),
                  ),
                if (addToInventory)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: mergeInventory,
                    title: const Text(
                      'Increase a matching item in this location',
                    ),
                    onChanged: (value) =>
                        refresh(() => mergeInventory = value ?? false),
                  ),
                const Text(
                  'Inventory updates do not create a Money Manager expense.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Purchased'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) {
        price.dispose();
        return;
      }
      final input = price.text.trim();
      if (input.isNotEmpty) {
        actual = parseMinorUnits(input);
        if (actual == null) {
          price.dispose();
          _message('Enter a non-negative price with up to two decimal places.');
          return;
        }
      }
      price.dispose();
    } else if (await ref
            .read(groceryRepositoryProvider)
            .hasRecordedPurchase(item.id) &&
        mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unmark purchased item?'),
          content: const Text(
            'The linked Money Manager expense will remain recorded. You can manage that transaction in Money Manager.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unmark'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    _purchaseSelection.remove(item.id);
    await ref
        .read(groceryRepositoryProvider)
        .setPurchased(
          item.id,
          purchased: purchased,
          actualUnitPriceMinor: actual,
        );
    if (purchased && addToInventory && mounted) {
      try {
        final applied = await ref
            .read(groceryRepositoryProvider)
            .receivePurchasedItem(
              itemId: item.id,
              location: storageLocation,
              addToInventory: true,
              mergeExisting: mergeInventory,
            );
        if (!applied) _message('This purchase was already added to inventory.');
      } catch (error) {
        _message('Purchase saved, but inventory was not updated: $error');
      }
    }
  }

  Future<void> _editItem(String listId, {GroceryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final quantity = TextEditingController(
      text: _quantityText(item?.quantityMilli ?? 1000),
    );
    final estimate = TextEditingController(
      text: item?.estimatedUnitPriceMinor == null
          ? ''
          : _minorText(item!.estimatedUnitPriceMinor!),
    );
    final actual = TextEditingController(
      text: item?.actualUnitPriceMinor == null
          ? ''
          : _minorText(item!.actualUnitPriceMinor!),
    );
    final notes = TextEditingController(text: item?.notes ?? '');
    const standardUnits = [
      'Piece',
      'Kilogram',
      'Gram',
      'Litre',
      'Millilitre',
      'Pack',
      'Bottle',
      'Dozen',
      'Other',
    ];
    const standardCategories = [
      'Fruits',
      'Vegetables',
      'Dairy',
      'Bakery',
      'Meat and seafood',
      'Snacks',
      'Beverages',
      'Household essentials',
      'Personal care',
      'Other',
    ];
    String unit = standardUnits.contains(item?.unit)
        ? item?.unit ?? 'Piece'
        : 'Other';
    String category = standardCategories.contains(item?.category)
        ? item?.category ?? 'Other'
        : 'Other';
    final customUnit = TextEditingController(
      text: unit == 'Other' && item?.unit != 'Other' ? item?.unit ?? '' : '',
    );
    final customCategory = TextEditingController(
      text: category == 'Other' && item?.category != 'Other'
          ? item?.category ?? ''
          : '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(item == null ? 'Add grocery item' : 'Edit grocery item'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Item name *'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              const [
                                'Piece',
                                'Kilogram',
                                'Gram',
                                'Litre',
                                'Millilitre',
                                'Pack',
                                'Bottle',
                                'Dozen',
                                'Other',
                              ].contains(unit)
                              ? unit
                              : 'Other',
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items:
                              const [
                                    'Piece',
                                    'Kilogram',
                                    'Gram',
                                    'Litre',
                                    'Millilitre',
                                    'Pack',
                                    'Bottle',
                                    'Dozen',
                                    'Other',
                                  ]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => refresh(() => unit = v ?? unit),
                        ),
                      ),
                    ],
                  ),
                  if (unit == 'Other')
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Custom unit',
                        hintText: item?.unit,
                      ),
                      controller: customUnit,
                    ),
                  TextField(
                    controller: estimate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Estimated unit price (optional)',
                      prefixText: '₹',
                    ),
                  ),
                  if (item?.isPurchased == true)
                    TextField(
                      controller: actual,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Actual unit price (optional)',
                        prefixText: '₹',
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue:
                        const [
                          'Fruits',
                          'Vegetables',
                          'Dairy',
                          'Bakery',
                          'Meat and seafood',
                          'Snacks',
                          'Beverages',
                          'Household essentials',
                          'Personal care',
                          'Other',
                        ].contains(category)
                        ? category
                        : 'Other',
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        const [
                              'Fruits',
                              'Vegetables',
                              'Dairy',
                              'Bakery',
                              'Meat and seafood',
                              'Snacks',
                              'Beverages',
                              'Household essentials',
                              'Personal care',
                              'Other',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => refresh(() => category = v ?? category),
                  ),
                  if (category == 'Other')
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Custom category',
                        hintText: item?.category == 'Other'
                            ? null
                            : item?.category,
                      ),
                      controller: customCategory,
                    ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save item'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      final q = _parseMilli(quantity.text);
      final estimateMinor = estimate.text.trim().isEmpty
          ? null
          : parseMinorUnits(estimate.text);
      final actualMinor = actual.text.trim().isEmpty
          ? null
          : parseMinorUnits(actual.text);
      if (name.text.trim().isEmpty ||
          q == null ||
          q <= 0 ||
          (estimate.text.trim().isNotEmpty && estimateMinor == null) ||
          (actual.text.trim().isNotEmpty && actualMinor == null)) {
        _message(
          'Check the item name, positive quantity, and prices. Prices allow up to two decimals.',
        );
      } else {
        try {
          await ref
              .read(groceryRepositoryProvider)
              .saveItem(
                id: item?.id,
                listId: listId,
                name: name.text,
                quantityMilli: q,
                unit: unit == 'Other' && customUnit.text.trim().isNotEmpty
                    ? customUnit.text.trim()
                    : unit,
                category:
                    category == 'Other' && customCategory.text.trim().isNotEmpty
                    ? customCategory.text.trim()
                    : category,
                estimatedUnitPriceMinor: estimateMinor,
                actualUnitPriceMinor: actualMinor,
                notes: notes.text,
              );
        } catch (error) {
          _message(error.toString());
        }
      }
    }
    for (final controller in [name, quantity, estimate, actual, notes]) {
      controller.dispose();
    }
    customUnit.dispose();
    customCategory.dispose();
  }

  Future<void> _editList({GroceryList? list}) async {
    final name = TextEditingController(text: list?.name ?? '');
    final description = TextEditingController(text: list?.description ?? '');
    DateTime? target = list?.targetAt;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(list == null ? 'New basket' : 'Edit basket'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'List name *'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final value = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: target ?? DateTime.now(),
                      );
                      if (value != null) refresh(() => target = value);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      target == null
                          ? 'Set target shopping date'
                          : DateFormat.yMMMd().format(target!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save list'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      try {
        await ref
            .read(groceryRepositoryProvider)
            .saveList(
              id: list?.id,
              name: name.text,
              description: description.text,
              targetAt: target,
            );
        if (list == null) ref.invalidate(groceryListsProvider);
      } catch (error) {
        _message(error.toString());
      }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _listAction(String action, GroceryList list) async {
    final repository = ref.read(groceryRepositoryProvider);
    switch (action) {
      case 'rename':
        await _editList(list: list);
        break;
      case 'archive':
        await repository.setArchived(list.id, archived: true);
        setState(() => _selectedListId = null);
        break;
      case 'restore':
        await repository.setArchived(list.id, archived: false);
        setState(() => _selectedListId = null);
        break;
      case 'clear':
        if (await _confirm(
              'Clear purchased items?',
              'Purchased items will be removed from this list. Money Manager transactions and recorded purchase history will remain.',
            ) ==
            true) {
          await repository.clearPurchased(list.id);
        }
        break;
      case 'delete':
        if (await _confirm(
              'Delete ${list.name}?',
              'This permanently deletes the list and its items. Existing Money Manager transactions remain in your financial history.',
            ) ==
            true) {
          await repository.deleteList(list.id);
          setState(() => _selectedListId = null);
        }
    }
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  Future<void> _deleteItem(GroceryItem item) async {
    if (await _confirm(
          'Remove ${item.name}?',
          'The grocery item and its list link will be removed. Any Money Manager transaction already recorded will remain.',
        ) ==
        true) {
      await ref.read(groceryRepositoryProvider).deleteItem(item.id);
    }
  }

  Future<void> _recordPurchase(
    GroceryList list,
    List<GroceryItem> items,
  ) async {
    final cleanup = <TextEditingController>[];
    var addPurchasedToInventory = false;
    var inventoryLocation = 'Pantry';
    var mergePurchasedWithExisting = true;
    try {
      final mode = await ref
          .read(groceryRepositoryProvider)
          .purchaseModeForItems(items.map((item) => item.id).toList());
      if (mode == 'mixed') {
        _message(
          'Select all items from one recorded bill, or choose only unrecorded items.',
        );
        return;
      }
      final accounts = await ref.read(moneyActiveAccountsProvider.future);
      final categories = (await ref.read(
        moneyExpensesCategoriesProvider.future,
      )).where((category) => category.archivedAt == null).toList();
      if (!mounted) return;
      if (accounts.isEmpty || categories.isEmpty) {
        _message(
          'Add an active Money Manager account and expense category first.',
        );
        return;
      }
      final defaultTotal = _total(items, (item) => item.actualUnitPriceMinor);
      final amount = TextEditingController(
        text: defaultTotal == null ? '' : _minorText(defaultTotal),
      );
      cleanup.add(amount);
      final note = TextEditingController(text: 'Groceries - ${list.name}');
      cleanup.add(note);
      final actualPriceControllers = <String, TextEditingController>{
        for (final item in items)
          item.id: TextEditingController(
            text: item.actualUnitPriceMinor == null
                ? ''
                : _minorText(item.actualUnitPriceMinor!),
          ),
      };
      cleanup.addAll(actualPriceControllers.values);
      String accountId = accounts.first.id;
      String categoryId =
          categories
              .where((c) => c.name.toLowerCase() == 'groceries')
              .firstOrNull
              ?.id ??
          categories.first.id;
      DateTime occurredAt = DateTime.now();
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: const Text('Record grocery purchase'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This bill covers ${items.length} purchased ${items.length == 1 ? 'item' : 'items'}.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimated selected total: ${_total(items, (item) => item.estimatedUnitPriceMinor) == null ? 'unknown' : formatMinorUnits(_total(items, (item) => item.estimatedUnitPriceMinor)!)}',
                    ),
                    for (final item in items) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${item.name} · ${_quantityText(item.quantityMilli)} ${item.unit}',
                        ),
                      ),
                      TextField(
                        controller: actualPriceControllers[item.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              'Actual unit price for ${item.name} (optional)',
                          prefixText: '₹',
                        ),
                        onChanged: (_) => refresh(() {}),
                      ),
                    ],
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Actual bill total *',
                        prefixText: '₹',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'Payment account',
                      ),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          refresh(() => accountId = value ?? accountId),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Expense category',
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          refresh(() => categoryId = value ?? categoryId),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: occurredAt,
                          );
                          if (value != null) refresh(() => occurredAt = value);
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(DateFormat.yMMMd().format(occurredAt)),
                      ),
                    ),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: addPurchasedToInventory,
                      title: const Text('Add purchased items to My Inventory'),
                      onChanged: (value) => refresh(
                        () => addPurchasedToInventory = value ?? false,
                      ),
                    ),
                    if (addPurchasedToInventory)
                      DropdownButtonFormField<String>(
                        initialValue: inventoryLocation,
                        decoration: const InputDecoration(
                          labelText: 'Storage location for these items',
                        ),
                        items: _storageLocations()
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => refresh(
                          () => inventoryLocation = value ?? inventoryLocation,
                        ),
                      ),
                    if (addPurchasedToInventory)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: mergePurchasedWithExisting,
                        title: const Text(
                          'Increase matching items in this location',
                        ),
                        onChanged: (value) => refresh(
                          () => mergePurchasedWithExisting = value ?? false,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      mode == 'update'
                          ? 'This will update the existing linked Money Manager expense.'
                          : 'This will create one new Money Manager expense for these items.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save expense'),
              ),
            ],
          ),
        ),
      );
      if (result == true && mounted) {
        final amountMinor = parseMinorUnits(amount.text);
        if (amountMinor == null || amountMinor <= 0) {
          _message('Enter a bill total greater than zero.');
        } else {
          final unitPrices = <String, int?>{};
          var invalidPrice = false;
          for (final entry in actualPriceControllers.entries) {
            final input = entry.value.text.trim();
            final parsed = input.isEmpty ? null : parseMinorUnits(input);
            if (input.isNotEmpty && parsed == null) invalidPrice = true;
            unitPrices[entry.key] = parsed;
          }
          if (invalidPrice) {
            _message(
              'Item prices must be non-negative with up to two decimal places.',
            );
            return;
          }
          await ref
              .read(groceryRepositoryProvider)
              .recordPurchase(
                listId: list.id,
                itemIds: items.map((item) => item.id).toList(),
                amountMinor: amountMinor,
                accountId: accountId,
                categoryId: categoryId,
                occurredAt: occurredAt,
                note: note.text,
                actualUnitPricesMinor: unitPrices,
                addPurchasedToInventory: addPurchasedToInventory,
                inventoryLocation: inventoryLocation,
                mergePurchasedWithExisting: mergePurchasedWithExisting,
              );
          _message('Grocery expense saved in Money Manager.');
        }
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      for (final controller in cleanup) {
        controller.dispose();
      }
    }
  }

  int? _parseMilli(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(value.trim());
    if (match == null) return null;
    final whole = int.tryParse(match.group(1)!);
    return whole == null
        ? null
        : whole * 1000 + int.parse((match.group(2) ?? '').padRight(3, '0'));
  }

  String _minorText(int value) =>
      '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';

  List<String> _storageLocations() => {
    'Fridge',
    'Freezer',
    'Pantry',
    'Other',
    ...(ref.read(homeInventoryProvider).value ?? const <HomeInventoryItem>[])
        .map((item) => item.location),
  }.toList()..sort();

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _BulkInventoryRow {
  _BulkInventoryRow()
    : name = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'Piece'),
      location = TextEditingController(text: 'Pantry');

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController location;
  DateTime? expiryAt;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    location.dispose();
  }
}

class _BulkShoppingRow {
  _BulkShoppingRow()
    : name = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'Piece');

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }
}
