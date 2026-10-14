import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/today/application/dashboard_providers.dart';
import '../theme/app_colors.dart';
import 'app_routes.dart';
import 'quick_add_sheet.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _Destination(
      label: 'Money',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    _Destination(
      label: 'To-do',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
    ),
    _Destination(
      label: 'Places',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    _Destination(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      void onDestinationSelected(int index) {
        if (index == 0) ref.invalidate(todayDashboardSnapshotProvider);
        navigationShell.goBranch(index);
      }

      const double navBarHeight = 68.0;
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

      final page = Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              titleSpacing: wide ? 28 : 20,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/jpg(9)',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.spa_rounded,
                            size: 19,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Mirai'),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) => context.push(value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: AppRoutes.explore,
                        child: Text('More features'),
                      ),
                      PopupMenuItem(
                        value: AppRoutes.settings,
                        child: Text('Settings'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
            body: navigationShell,
            bottomNavigationBar: wide
                ? null
                : _MiraiBottomNavigationBar(
                    height: navBarHeight,
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: onDestinationSelected,
                  ),
          ),
          if (!wide)
            Positioned(
              right: 20,
              bottom: navBarHeight + bottomInset + 14,
              child: _SquareQuickAddButton(
                onPressed: () => showQuickAddSheet(context, ref),
              ),
            ),
        ],
      );

      if (!wide) return page;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 8, 14),
                child: NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/jpg(9)',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.spa_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(child: page),
          ],
        ),
      );
    },
  );
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _MiraiBottomNavigationBar extends StatelessWidget {
  const _MiraiBottomNavigationBar({
    required this.height,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final double height;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: const Border(
          top: BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (
                var index = 0;
                index < MainShell._destinations.length;
                index++
              )
                Expanded(
                  child: _NavigationItem(
                    destination: MainShell._destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.onPrimary
        : AppColors.darkSecondaryText;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: double.infinity,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brand.withValues(alpha: .72)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareQuickAddButton extends StatefulWidget {
  const _SquareQuickAddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_SquareQuickAddButton> createState() => _SquareQuickAddButtonState();
}

class _SquareQuickAddButtonState extends State<_SquareQuickAddButton> {
  static const _size = 72.0;
  static const _shadowOffset = 4.0;

  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final currentOffset = _isPressed ? 1.0 : _shadowOffset;
    final translation = _shadowOffset - currentOffset;

    return Semantics(
      button: true,
      label: 'Quick Add',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          width: _size,
          height: _size,
          transform: Matrix4.translationValues(translation, translation, 0),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lightText, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.lightText,
                offset: Offset(currentOffset, currentOffset),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: AppColors.lightText,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}
