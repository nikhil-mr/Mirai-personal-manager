// ignore_for_file: non_const_argument_for_const_parameter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../money/data/money_database.dart';
import '../application/grocery_providers.dart';
import '../data/grocery_repository.dart';

enum StockStatus {
  wellStocked('Well stocked', Color(0xFF22C55E)),
  good('Good', Color(0xFFEAB308)),
  low('Low', Color(0xFFF97316)),
  veryLow('Very low', Color(0xFFEF4444)),
  outOfStock('Out of stock', Color(0xFFDC2626));

  const StockStatus(this.label, this.color);
  final String label;
  final Color color;
}

StockStatus calculateStockStatus(
  double currentQty,
  double targetQty, {
  double lowStockThreshold = 0,
}) {
  if (currentQty <= 0) {
    return StockStatus.outOfStock;
  }
  if (targetQty <= 0) {
    if (lowStockThreshold > 0 && currentQty <= lowStockThreshold) {
      return StockStatus.low;
    }
    return StockStatus.wellStocked;
  }
  final pct = (currentQty / targetQty) * 100;
  if (pct >= 75) return StockStatus.wellStocked;
  if (pct >= 50) return StockStatus.good;
  if (pct >= 25) return StockStatus.low;
  return StockStatus.veryLow;
}

double calculateStockPercentage(double currentQty, double targetQty) {
  if (targetQty <= 0) return currentQty > 0 ? 100.0 : 0.0;
  final pct = (currentQty / targetQty) * 100;
  return pct.clamp(0.0, 100.0);
}

String formatMilliQty(int milli, String unit) {
  final val = milli / 1000.0;
  if (val == val.roundToDouble()) {
    return '${val.toInt()} $unit';
  }
  return '${val.toStringAsFixed(1)} $unit';
}

class StockProgressBar extends StatelessWidget {
  const StockProgressBar({
    required this.currentQty,
    required this.targetQty,
    this.lowStockThreshold = 0,
    this.height = 6,
    super.key,
  });

  final double currentQty;
  final double targetQty;
  final double lowStockThreshold;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFFE0E0E0);
    final status = calculateStockStatus(
      currentQty,
      targetQty,
      lowStockThreshold: lowStockThreshold,
    );
    final pct = calculateStockPercentage(currentQty, targetQty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: trackColor),
          FractionallySizedBox(
            widthFactor: pct / 100.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: height,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData inventoryIconForCodePoint(int? codePoint) {
  const icons = <IconData>[
    Icons.shopping_bag_outlined,
    Icons.soap_outlined,
    Icons.cleaning_services_outlined,
    Icons.medication_outlined,
    Icons.edit_note_outlined,
    Icons.local_dining_outlined,
    Icons.kitchen_outlined,
    Icons.category_outlined,
    Icons.inventory_2_outlined,
    Icons.shopping_basket_outlined,
    Icons.sanitizer_outlined,
    Icons.medical_services_outlined,
    Icons.draw_outlined,
    Icons.add_circle_outline,
  ];
  return icons.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.inventory_2_outlined,
  );
}

class GroceriesScreen extends ConsumerStatefulWidget {
  const GroceriesScreen({this.quickAdd, super.key});
  final String? quickAdd;

  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  int _tabIndex = 0; // 0 = My Inventory, 1 = Shopping List
  String _searchQuery = '';
  InventoryCategory? _selectedCategory;
  String _selectedStatusFilter = 'All';
  String _selectedSortOrder = 'Name: A → Z';
  bool _quickAddHandled = false;

  @override
  void initState() {
    super.initState();
    if (widget.quickAdd == 'item') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_quickAddHandled) {
          _quickAddHandled = true;
          _showAddOrEditItemForm(context);
        }
      });
    }
  }

  @override
  void didUpdateWidget(GroceriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickAdd == 'item' && !_quickAddHandled) {
      _quickAddHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAddOrEditItemForm(context);
        }
      });
    }
  }

  final _units = const [
    'kg',
    'g',
    'L',
    'ml',
    'Piece',
    'Pack',
    'Bottle',
    'Box',
    'Packet',
    'Tube',
    'Can',
    'Dozen',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final inventoryAsync = ref.watch(homeInventoryProvider);
    final listsAsync = ref.watch(groceryListsProvider);

    return Scaffold(
      body: PageContainer(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep track of what you have at home.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Manage categories',
                  icon: const Icon(Icons.category_outlined),
                  onPressed: () => _showCategoryManagementSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search items or categories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 14),

            // Segmented Selector (My Inventory / Shopping List)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('My Inventory'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Shopping List'),
                  icon: Icon(Icons.shopping_cart_outlined),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (val) =>
                  setState(() => _tabIndex = val.first),
            ),
            const SizedBox(height: 16),

            // Main Body Content
            Expanded(
              child: _tabIndex == 0
                  ? _buildInventoryView(
                      context,
                      categoriesAsync,
                      inventoryAsync,
                      isDark,
                    )
                  : _buildShoppingListView(context, listsAsync, isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.lightText,
        onPressed: () => _showFabActionSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY VIEW (DASHBOARD & CATEGORY ITEM LIST)
  // ---------------------------------------------------------------------------
  Widget _buildInventoryView(
    BuildContext context,
    AsyncValue<List<InventoryCategory>> categoriesAsync,
    AsyncValue<List<HomeInventoryItem>> inventoryAsync,
    bool isDark,
  ) {
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load categories: $e')),
      data: (categories) => inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load inventory: $e')),
        data: (allItems) {
          // If a category is selected or searching or filtering, show Item List View
          if (_selectedCategory != null ||
              _selectedStatusFilter != 'All' ||
              _searchQuery.trim().isNotEmpty) {
            return _buildCategoryItemList(
              context,
              categories,
              allItems,
              isDark,
            );
          }

          // Otherwise show Dashboard
          return _buildDashboardView(context, categories, allItems, isDark);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN 1: DASHBOARD VIEW
  // ---------------------------------------------------------------------------
  Widget _buildDashboardView(
    BuildContext context,
    List<InventoryCategory> categories,
    List<HomeInventoryItem> allItems,
    bool isDark,
  ) {
    final totalCount = allItems.length;
    var wellStockedCount = 0;
    var lowStockCount = 0;
    var outOfStockCount = 0;

    final lowStockItems = <HomeInventoryItem>[];

    for (final item in allItems) {
      final status = calculateStockStatus(
        item.quantityMilli / 1000.0,
        item.targetQuantityMilli / 1000.0,
        lowStockThreshold: item.lowStockThresholdMilli / 1000.0,
      );
      if (status == StockStatus.wellStocked || status == StockStatus.good) {
        wellStockedCount++;
      } else if (status == StockStatus.low || status == StockStatus.veryLow) {
        lowStockCount++;
        lowStockItems.add(item);
      } else if (status == StockStatus.outOfStock) {
        outOfStockCount++;
        lowStockItems.add(item);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories Header
          SectionHeader(
            title: 'Categories',
            action: TextButton(
              onPressed: () => _showCategoryManagementSheet(context),
              child: const Text('Manage'),
            ),
          ),
          const SizedBox(height: 8),

          // Categories Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length + 1, // +1 for Add Category tile
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisExtent: 80,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, i) {
                  if (i == categories.length) {
                    // Add Category Tile
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showCategoryEditDialog(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: AppColors.brand,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add Category',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final cat = categories[i];
                  final catItemCount = allItems
                      .where(
                        (item) =>
                            item.categoryId == cat.id ||
                            item.category.toLowerCase() ==
                                cat.name.toLowerCase(),
                      )
                      .length;

                  final bg = Color(cat.colorValue);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF111111),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            inventoryIconForCodePoint(cat.iconCodePoint),
                            size: 24,
                            color: const Color(0xFF111111),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111111),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$catItemCount items',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF111111),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Stock Status Summary
          SectionHeader(title: 'Stock Summary'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSummaryChip(
                label: 'Total',
                count: totalCount,
                color: isDark ? AppColors.darkCard : Colors.white,
                textColor: isDark ? AppColors.darkText : AppColors.lightText,
                onTap: () => setState(() => _selectedStatusFilter = 'All'),
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: 'Well stocked',
                count: wellStockedCount,
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                textColor: const Color(0xFF22C55E),
                onTap: () =>
                    setState(() => _selectedStatusFilter = 'Well stocked'),
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: 'Low stock',
                count: lowStockCount,
                color: const Color(0xFFF97316).withValues(alpha: 0.2),
                textColor: const Color(0xFFF97316),
                onTap: () =>
                    setState(() => _selectedStatusFilter = 'Low stock'),
              ),
              const SizedBox(width: 8),
              _buildSummaryChip(
                label: 'Out of stock',
                count: outOfStockCount,
                color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                textColor: const Color(0xFFDC2626),
                onTap: () =>
                    setState(() => _selectedStatusFilter = 'Out of stock'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recently Low / Out of Stock
          SectionHeader(
            title: 'Recently low / out of stock',
            action: lowStockItems.isNotEmpty
                ? TextButton(
                    onPressed: () =>
                        setState(() => _selectedStatusFilter = 'Low stock'),
                    child: const Text('See all'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (lowStockItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF22C55E),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All items well stocked!',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'No low or out of stock items found.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                for (final item in lowStockItems.take(4))
                  _buildInventoryItemTile(context, item, isDark),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required int count,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: textColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN 2: CATEGORY ITEM LIST / FILTERED LIST
  // ---------------------------------------------------------------------------
  Widget _buildCategoryItemList(
    BuildContext context,
    List<InventoryCategory> categories,
    List<HomeInventoryItem> allItems,
    bool isDark,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    var filtered = allItems.where((item) {
      if (_selectedCategory != null) {
        final catMatch =
            item.categoryId == _selectedCategory!.id ||
            item.category.toLowerCase() ==
                _selectedCategory!.name.toLowerCase();
        if (!catMatch) return false;
      }

      final status = calculateStockStatus(
        item.quantityMilli / 1000.0,
        item.targetQuantityMilli / 1000.0,
        lowStockThreshold: item.lowStockThresholdMilli / 1000.0,
      );

      if (_selectedStatusFilter == 'Well stocked' &&
          status != StockStatus.wellStocked &&
          status != StockStatus.good) {
        return false;
      }
      if (_selectedStatusFilter == 'Low stock' &&
          status != StockStatus.low &&
          status != StockStatus.veryLow) {
        return false;
      }
      if (_selectedStatusFilter == 'Out of stock' &&
          status != StockStatus.outOfStock) {
        return false;
      }

      if (query.isNotEmpty) {
        final match =
            item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            item.notes.toLowerCase().contains(query);
        if (!match) return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final aCurrent = a.quantityMilli / 1000.0;
      final aTarget = a.targetQuantityMilli / 1000.0;
      final bCurrent = b.quantityMilli / 1000.0;
      final bTarget = b.targetQuantityMilli / 1000.0;

      switch (_selectedSortOrder) {
        case 'Name: A → Z':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'Name: Z → A':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'Quantity: Low → High':
          return a.quantityMilli.compareTo(b.quantityMilli);
        case 'Quantity: High → Low':
          return b.quantityMilli.compareTo(a.quantityMilli);
        case 'Stock level: Low → High':
          return calculateStockPercentage(
            aCurrent,
            aTarget,
          ).compareTo(calculateStockPercentage(bCurrent, bTarget));
        case 'Stock level: High → Low':
          return calculateStockPercentage(
            bCurrent,
            bTarget,
          ).compareTo(calculateStockPercentage(aCurrent, aTarget));
        case 'Recently added':
          return b.createdAt.compareTo(a.createdAt);
        case 'Expiry date: Earliest first':
          return (a.expiryAt ?? DateTime(9999)).compareTo(
            b.expiryAt ?? DateTime(9999),
          );
        case 'Expiry date: Latest first':
          return (b.expiryAt ?? DateTime(0)).compareTo(
            a.expiryAt ?? DateTime(0),
          );
        default:
          return a.name.compareTo(b.name);
      }
    });

    final titleText = _selectedCategory != null
        ? _selectedCategory!.name
        : (_selectedStatusFilter != 'All'
              ? '$_selectedStatusFilter Items'
              : 'Inventory Items');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Controls
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedCategory = null;
                _selectedStatusFilter = 'All';
                _searchQuery = '';
              }),
            ),
            if (_selectedCategory != null) ...[
              Icon(
                inventoryIconForCodePoint(_selectedCategory!.iconCodePoint),
                size: 22,
                color: Color(_selectedCategory!.colorValue),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filtered.length} items',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkSecondaryText
                          : AppColors.lightSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sort items',
              icon: const Icon(Icons.sort_rounded),
              onPressed: () => _showSortBottomSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in [
                'All',
                'Well stocked',
                'Low stock',
                'Out of stock',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: _selectedStatusFilter == status,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatusFilter = status);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Items List
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No items found',
                  message: 'Try adjusting your search or filters.',
                  compact: true,
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildInventoryItemTile(context, item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryItemTile(
    BuildContext context,
    HomeInventoryItem item,
    bool isDark,
  ) {
    final currentQty = item.quantityMilli / 1000.0;
    final targetQty = item.targetQuantityMilli / 1000.0;
    final lowThreshold = item.lowStockThresholdMilli / 1000.0;

    final status = calculateStockStatus(
      currentQty,
      targetQty,
      lowStockThreshold: lowThreshold,
    );
    final pct = calculateStockPercentage(currentQty, targetQty);

    final String qtyDisplay = targetQty > 0
        ? '${formatMilliQty(item.quantityMilli, item.unit)} / ${formatMilliQty(item.targetQuantityMilli, item.unit)}'
        : formatMilliQty(item.quantityMilli, item.unit);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrutalCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _showItemDetailsDialog(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    inventoryIconForCodePoint(item.iconCodePoint),
                    color: status.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category} · $qtyDisplay',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                    ),
                    if (targetQty > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (targetQty > 0) ...[
              const SizedBox(height: 8),
              StockProgressBar(
                currentQty: currentQty,
                targetQty: targetQty,
                lowStockThreshold: lowThreshold,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHOPPING LIST VIEW
  // ---------------------------------------------------------------------------
  Widget _buildShoppingListView(
    BuildContext context,
    AsyncValue<List<GroceryList>> listsAsync,
    bool isDark,
  ) {
    return listsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load shopping lists: $e')),
      data: (lists) {
        if (lists.isEmpty) {
          return EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No shopping lists yet',
            message: 'Create a list to plan your next trip.',
            action: FilledButton.icon(
              onPressed: () => _showAddListDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Shopping List'),
            ),
          );
        }

        final currentList = lists.first;
        final itemsAsync = ref.watch(groceryItemsProvider(currentList.id));

        return itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load items: $e')),
          data: (items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentList.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () =>
                          _showAddShoppingItemDialog(context, currentList.id),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(
                          icon: Icons.shopping_basket_outlined,
                          title: 'List is empty',
                          message: 'Add items you need to buy.',
                          action: FilledButton.icon(
                            onPressed: () => _showAddShoppingItemDialog(
                              context,
                              currentList.id,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                          compact: true,
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return Card(
                              child: CheckboxListTile(
                                value: item.isPurchased,
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    decoration: item.isPurchased
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  formatMilliQty(item.quantityMilli, item.unit),
                                ),
                                onChanged: (val) async {
                                  if (val != null) {
                                    await ref
                                        .read(groceryRepositoryProvider)
                                        .setPurchased(item.id, purchased: val);
                                    if (val && context.mounted) {
                                      _promptUpdateInventoryFromPurchase(
                                        context,
                                        item,
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN 3: ADD / EDIT INVENTORY ITEM FORM
  // ---------------------------------------------------------------------------
  void _showAddOrEditItemForm(
    BuildContext context, {
    HomeInventoryItem? editItem,
  }) {
    showAddOrEditItemForm(context, ref, editItem: editItem);
  }

  // ---------------------------------------------------------------------------
  // SCREEN 4: ITEM DETAILS & EDITING DIALOG
  // ---------------------------------------------------------------------------
  void _showItemDetailsDialog(BuildContext context, HomeInventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final inventory =
              ref.watch(homeInventoryProvider).asData?.value ?? [];
          final currentItem =
              inventory.where((i) => i.id == item.id).firstOrNull ?? item;

          final currentQty = currentItem.quantityMilli / 1000.0;
          final targetQty = currentItem.targetQuantityMilli / 1000.0;
          final lowThreshold = currentItem.lowStockThresholdMilli / 1000.0;

          final status = calculateStockStatus(
            currentQty,
            targetQty,
            lowStockThreshold: lowThreshold,
          );
          final pct = calculateStockPercentage(currentQty, targetQty);

          final isDiscreteUnit = [
            'Piece',
            'Pack',
            'Bottle',
            'Box',
            'Packet',
            'Tube',
            'Can',
            'Dozen',
          ].contains(currentItem.unit);

          final stepVal = isDiscreteUnit ? 1.0 : 0.5;

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    inventoryIconForCodePoint(currentItem.iconCodePoint),
                    color: status.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentItem.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currentItem.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stock Status & Bar
                  Row(
                    children: [
                      Text(
                        targetQty > 0
                            ? '${formatMilliQty(currentItem.quantityMilli, currentItem.unit)} / ${formatMilliQty(currentItem.targetQuantityMilli, currentItem.unit)}'
                            : formatMilliQty(
                                currentItem.quantityMilli,
                                currentItem.unit,
                              ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (targetQty > 0) ...[
                    const SizedBox(height: 8),
                    StockProgressBar(
                      currentQty: currentQty,
                      targetQty: targetQty,
                      lowStockThreshold: lowThreshold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pct.toStringAsFixed(0)}% remaining',
                      style: TextStyle(fontSize: 11, color: status.color),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Quantity Adjustments Control
                  const Text(
                    'Quick Adjust Quantity',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: () async {
                          final newQty = (currentQty - stepVal).clamp(
                            0.0,
                            9999.0,
                          );
                          await ref
                              .read(groceryRepositoryProvider)
                              .adjustInventoryQuantity(
                                currentItem.id,
                                (newQty * 1000).round(),
                              );
                        },
                      ),
                      const SizedBox(width: 16),
                      Text(
                        formatMilliQty(
                          currentItem.quantityMilli,
                          currentItem.unit,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final newQty = currentQty + stepVal;
                          await ref
                              .read(groceryRepositoryProvider)
                              .adjustInventoryQuantity(
                                currentItem.id,
                                (newQty * 1000).round(),
                              );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick Increment Chips
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text('-$stepVal'),
                        onPressed: () async {
                          final newQty = (currentQty - stepVal).clamp(
                            0.0,
                            9999.0,
                          );
                          await ref
                              .read(groceryRepositoryProvider)
                              .adjustInventoryQuantity(
                                currentItem.id,
                                (newQty * 1000).round(),
                              );
                        },
                      ),
                      ActionChip(
                        label: Text('+$stepVal'),
                        onPressed: () async {
                          final newQty = currentQty + stepVal;
                          await ref
                              .read(groceryRepositoryProvider)
                              .adjustInventoryQuantity(
                                currentItem.id,
                                (newQty * 1000).round(),
                              );
                        },
                      ),
                      if (!isDiscreteUnit) ...[
                        ActionChip(
                          label: const Text('+1.0'),
                          onPressed: () async {
                            final newQty = currentQty + 1.0;
                            await ref
                                .read(groceryRepositoryProvider)
                                .adjustInventoryQuantity(
                                  currentItem.id,
                                  (newQty * 1000).round(),
                                );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (currentItem.expiryAt != null) ...[
                    Text(
                      'Expiry: ${DateFormat.yMMMd().format(currentItem.expiryAt!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (currentItem.notes.isNotEmpty) ...[
                    Text(
                      'Notes: ${currentItem.notes}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 1-Tap Add to Shopping List
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(36),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Add to Shopping List'),
                    onPressed: () async {
                      final lists = await ref.read(groceryListsProvider.future);
                      if (lists.isNotEmpty) {
                        await ref
                            .read(groceryRepositoryProvider)
                            .addInventoryItemToShopping(
                              inventoryItemId: currentItem.id,
                              listId: lists.first.id,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added "${currentItem.name}" to shopping list.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete item?'),
                      content: Text(
                        'Remove "${currentItem.name}" from inventory?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(groceryRepositoryProvider)
                        .deleteInventoryItem(currentItem.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddOrEditItemForm(context, editItem: currentItem);
                },
                child: const Text('Edit'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORY MANAGEMENT SHEET & DIALOGS
  // ---------------------------------------------------------------------------
  void _showCategoryManagementSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final categories =
              ref.watch(inventoryCategoriesProvider).asData?.value ?? [];
          final items = ref.watch(homeInventoryProvider).asData?.value ?? [];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Manage Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add category',
                      onPressed: () => _showCategoryEditDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final catItems = items
                          .where(
                            (item) =>
                                item.categoryId == cat.id ||
                                item.category.toLowerCase() ==
                                    cat.name.toLowerCase(),
                          )
                          .toList();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(cat.colorValue),
                            child: Icon(
                              inventoryIconForCodePoint(cat.iconCodePoint),
                              color: const Color(0xFF111111),
                              size: 20,
                            ),
                          ),
                          title: Text(cat.name),
                          subtitle: Text('${catItems.length} items'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showCategoryEditDialog(
                                  context,
                                  category: cat,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _confirmCategoryDeletion(
                                  context,
                                  cat,
                                  catItems,
                                  categories,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCategoryEditDialog(
    BuildContext context, {
    InventoryCategory? category,
  }) {
    final nameController = TextEditingController(text: category?.name ?? '');

    final colors = [
      0xFFAEEBDD, // Light green
      0xFFFFC5D8, // Light pink
      0xFFBFE0FF, // Light blue
      0xFFE5C9FF, // Light purple
      0xFFFFD49A, // Light yellow
      0xFFFFD0AE, // Light orange
      0xFFB5E8D4, // Teal
      0xFFC9D4FF, // Soft indigo
    ];

    final icons = [
      0xe59c, // shopping_bag_outlined
      0xf017a, // soap_outlined
      0xe17d, // cleaning_services_outlined
      0xe3d9, // medication_outlined
      0xf06d8, // edit_note_outlined
      0xe25a, // local_dining_outlined
      0xe3af, // kitchen_outlined
      0xe16a, // category_outlined
    ];

    int selectedColor = category?.colorValue ?? colors.first;
    int selectedIcon = category?.iconCodePoint ?? icons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Snacks, Drinks',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Icon',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final icon in icons)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setDlgState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedIcon == icon
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedIcon == icon
                                  ? AppColors.brand
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            inventoryIconForCodePoint(icon),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Color',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in colors)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setDlgState(() => selectedColor = color),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(color),
                          child: selectedColor == color
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Color(0xFF111111),
                                )
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                await ref
                    .read(groceryRepositoryProvider)
                    .saveCategory(
                      id: category?.id,
                      name: name,
                      iconCodePoint: selectedIcon,
                      colorValue: selectedColor,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCategoryDeletion(
    BuildContext context,
    InventoryCategory category,
    List<HomeInventoryItem> catItems,
    List<InventoryCategory> allCategories,
  ) {
    if (catItems.isEmpty) {
      // Safe to delete directly
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${category.name}"?'),
          content: const Text('This category has no items assigned.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                await ref
                    .read(groceryRepositoryProvider)
                    .deleteCategory(category.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      return;
    }

    // Has items: prompt for reassignment
    final otherCategories = allCategories
        .where((c) => c.id != category.id)
        .toList();
    InventoryCategory? reassignCat = otherCategories.firstOrNull;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Delete "${category.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This category contains ${catItems.length} items. Reassign items to another category before deleting.',
              ),
              const SizedBox(height: 12),
              if (otherCategories.isNotEmpty) ...[
                DropdownButtonFormField<InventoryCategory>(
                  value: reassignCat,
                  decoration: const InputDecoration(
                    labelText: 'Reassign to Category',
                  ),
                  items: otherCategories
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (val) => setDlgState(() => reassignCat = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                await ref
                    .read(groceryRepositoryProvider)
                    .deleteCategory(
                      category.id,
                      reassignToCategoryId: reassignCat?.id,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Reassign & Delete'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SORT BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _showSortBottomSheet(BuildContext context) {
    final sortOptions = [
      'Name: A → Z',
      'Name: Z → A',
      'Quantity: Low → High',
      'Quantity: High → Low',
      'Stock level: Low → High',
      'Stock level: High → Low',
      'Recently added',
      'Expiry date: Earliest first',
      'Expiry date: Latest first',
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Sort Items By',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  for (final opt in sortOptions)
                    ListTile(
                      title: Text(opt),
                      trailing: _selectedSortOrder == opt
                          ? const Icon(Icons.check, color: AppColors.brand)
                          : null,
                      onTap: () {
                        setState(() => _selectedSortOrder = opt);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAB ACTION SHEET
  // ---------------------------------------------------------------------------
  void _showFabActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Add Inventory Item'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddOrEditItemForm(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_outlined),
              title: const Text('Add Shopping List Item'),
              onTap: () {
                Navigator.pop(ctx);
                final lists =
                    ref.read(groceryListsProvider).asData?.value ?? [];
                if (lists.isNotEmpty) {
                  _showAddShoppingItemDialog(context, lists.first.id);
                } else {
                  _showAddListDialog(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Manage Categories'),
              onTap: () {
                Navigator.pop(ctx);
                _showCategoryManagementSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHOPPING LIST HELPER DIALOGS
  // ---------------------------------------------------------------------------
  void _showAddListDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Shopping List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Weekly Groceries'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ref.read(groceryRepositoryProvider).saveList(name: name);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddShoppingItemDialog(BuildContext context, String listId) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    String unit = 'Piece';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Shopping Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => unit = v);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final qty =
                    ((double.tryParse(qtyController.text) ?? 1.0) * 1000)
                        .round();
                if (name.isNotEmpty) {
                  await ref
                      .read(groceryRepositoryProvider)
                      .saveItem(
                        listId: listId,
                        name: name,
                        quantityMilli: qty,
                        unit: unit,
                        category: 'Groceries',
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptUpdateInventoryFromPurchase(
    BuildContext context,
    GroceryItem item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Inventory?'),
        content: Text(
          'Would you like to add ${formatMilliQty(item.quantityMilli, item.unit)} of "${item.name}" to your inventory stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(groceryRepositoryProvider)
                  .receivePurchasedItem(
                    itemId: item.id,
                    location: 'Pantry',
                    addToInventory: true,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Yes, Add to Inventory'),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddOrEditItemForm(
  BuildContext context,
  WidgetRef ref, {
  HomeInventoryItem? editItem,
}) async {
  final repo = ref.read(groceryRepositoryProvider);
  repo.seedDefaultCategories();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AddItemFormSheet(editItem: editItem),
  );
}

class _AddItemFormSheet extends ConsumerStatefulWidget {
  const _AddItemFormSheet({this.editItem});
  final HomeInventoryItem? editItem;

  @override
  ConsumerState<_AddItemFormSheet> createState() => _AddItemFormSheetState();
}

class _AddItemFormSheetState extends ConsumerState<_AddItemFormSheet> {
  static const _units = [
    'kg',
    'g',
    'L',
    'ml',
    'Piece',
    'Pack',
    'Bottle',
    'Box',
    'Packet',
    'Tube',
    'Can',
    'Dozen',
    'Other',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _currentQtyController;
  late final TextEditingController _targetQtyController;
  late final TextEditingController _lowThresholdController;
  late final TextEditingController _notesController;

  String _selectedUnit = 'Piece';
  InventoryCategory? _selectedCat;
  DateTime? _selectedExpiry;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _currentQtyController = TextEditingController(
      text: item != null ? (item.quantityMilli / 1000.0).toString() : '1',
    );
    _targetQtyController = TextEditingController(
      text: item != null && item.targetQuantityMilli > 0
          ? (item.targetQuantityMilli / 1000.0).toString()
          : '',
    );
    _lowThresholdController = TextEditingController(
      text: item != null && item.lowStockThresholdMilli > 0
          ? (item.lowStockThresholdMilli / 1000.0).toString()
          : '',
    );
    _notesController = TextEditingController(text: item?.notes ?? '');

    _selectedUnit = item?.unit ?? 'Piece';
    if (!_units.contains(_selectedUnit)) _selectedUnit = 'Other';
    _selectedExpiry = item?.expiryAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentQtyController.dispose();
    _targetQtyController.dispose();
    _lowThresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(inventoryCategoriesProvider).asData?.value ?? [];

    if (_selectedCat == null && categories.isNotEmpty) {
      if (widget.editItem != null) {
        _selectedCat =
            categories
                .where((c) => c.id == widget.editItem!.categoryId)
                .firstOrNull ??
            categories
                .where(
                  (c) =>
                      c.name.toLowerCase() ==
                      widget.editItem!.category.toLowerCase(),
                )
                .firstOrNull;
      }
      _selectedCat ??= categories.firstOrNull;
    }

    final currentVal = double.tryParse(_currentQtyController.text) ?? 0.0;
    final targetVal = double.tryParse(_targetQtyController.text) ?? 0.0;
    final lowVal = double.tryParse(_lowThresholdController.text) ?? 0.0;

    final status = calculateStockStatus(
      currentVal,
      targetVal,
      lowStockThreshold: lowVal,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.editItem == null ? 'Add Inventory Item' : 'Edit Item',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Item Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g. Rice, Milk, Shampoo',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Category Dropdown
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InventoryCategory>(
                    value: _selectedCat,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      isDense: true,
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Icon(
                                  inventoryIconForCodePoint(c.iconCodePoint),
                                  size: 18,
                                  color: Color(c.colorValue),
                                ),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCat = val),
                  ),
                ),
                IconButton(
                  tooltip: 'Manage categories',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    showCategoryManagementSheet(context, ref);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Unit Dropdown
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                isDense: true,
              ),
              items: _units
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedUnit = val);
              },
            ),
            const SizedBox(height: 12),

            // Quantities (Current & Target)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentQtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Current Qty *',
                      suffixText: _selectedUnit,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetQtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Target Qty',
                      suffixText: _selectedUnit,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Low stock threshold & Expiry date
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lowThresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Low Stock Alert Qty',
                      suffixText: _selectedUnit,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedExpiry ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _selectedExpiry = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _selectedExpiry != null
                          ? DateFormat.yMd().format(_selectedExpiry!)
                          : 'Expiry Date',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Live Stock Preview Card
            BrutalCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Preview',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        targetVal > 0
                            ? '$currentVal / $targetVal $_selectedUnit'
                            : '$currentVal $_selectedUnit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (targetVal > 0) ...[
                    const SizedBox(height: 6),
                    StockProgressBar(
                      currentQty: currentVal,
                      targetQty: targetVal,
                      lowStockThreshold: lowVal,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.lightText,
                ),
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter an item name.'),
                      ),
                    );
                    return;
                  }

                  final currentMilli = (currentVal * 1000).round();
                  final targetMilli = (targetVal * 1000).round();
                  final lowMilli = (lowVal * 1000).round();

                  try {
                    await ref
                        .read(groceryRepositoryProvider)
                        .saveInventoryItem(
                          id: widget.editItem?.id,
                          item: InventoryItemInput(
                            name: name,
                            quantityMilli: currentMilli,
                            targetQuantityMilli: targetMilli,
                            lowStockThresholdMilli: lowMilli,
                            unit: _selectedUnit,
                            category: _selectedCat?.name ?? 'Other',
                            categoryId: _selectedCat?.id,
                            iconCodePoint: _selectedCat?.iconCodePoint,
                            colorValue: _selectedCat?.colorValue,
                            expiryAt: _selectedExpiry,
                            notes: _notesController.text.trim(),
                          ),
                        );
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save item: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save Item'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

void showCategoryManagementSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final categories =
            ref.watch(inventoryCategoriesProvider).asData?.value ?? [];
        final items = ref.watch(homeInventoryProvider).asData?.value ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Manage Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final catItems = items
                        .where(
                          (item) =>
                              item.categoryId == cat.id ||
                              item.category.toLowerCase() ==
                                  cat.name.toLowerCase(),
                        )
                        .toList();

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(cat.colorValue),
                          child: Icon(
                            inventoryIconForCodePoint(cat.iconCodePoint),
                            color: const Color(0xFF111111),
                            size: 20,
                          ),
                        ),
                        title: Text(cat.name),
                        subtitle: Text('${catItems.length} items'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
