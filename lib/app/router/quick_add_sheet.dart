import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/money/presentation/money_workflows.dart';
import '../../features/todos/presentation/todos_screen.dart';
import 'app_routes.dart';

Future<void> showQuickAddSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _QuickAddSheet(
      onAction: (action) async {
        Navigator.of(sheetContext).pop();
        await action(context, ref);
      },
    ),
  );
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.onAction});
  final Future<void> Function(Future<void> Function(BuildContext, WidgetRef))
  onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _QuickAddColors(theme.brightness);
    final actions = [
      _QuickAddAction(
        'Transaction',
        'Expense, income, or transfer',
        Icons.receipt_long_rounded,
        const Color(0xFFFFD928),
        const Color(0xFFFF7900),
        (context, ref) => _openTransaction(context),
      ),
      _QuickAddAction(
        'Task',
        'Keep your day organized',
        Icons.checklist_rounded,
        const Color(0xFFFF2D91),
        const Color(0xFFD90065),
        (context, ref) => showTaskEditor(context, ref),
      ),
      _QuickAddAction(
        'Place',
        'Save somewhere to go',
        Icons.place_rounded,
        const Color(0xFF843CFF),
        const Color(0xFF350078),
        (context, ref) => _go(context, '${AppRoutes.places}?quickAdd=place'),
      ),
      _QuickAddAction(
        'Item',
        'Add to inventory or shopping list',
        Icons.inventory_2_rounded,
        const Color(0xFF00BFF3),
        const Color(0xFF0057B8),
        (context, ref) => _go(context, AppRoutes.groceries),
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colors.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF111111), width: 2),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.dragHandle,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'What would you like to add?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quickly add to keep your day organized.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: width,
                          child: _ActionCard(
                            action: action,
                            textColor: colors.cardText,
                            onTap: () => onAction(action.callback),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.sheetBackground,
                    foregroundColor: colors.primaryText,
                    side: const BorderSide(color: Color(0xFF111111), width: 2),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.textColor,
    required this.onTap,
  });
  final _QuickAddAction action;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 148,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: action.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF111111), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF111111),
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const Spacer(),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ).copyWith(color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddColors {
  const _QuickAddColors(this.brightness);

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;
  Color get sheetBackground =>
      isDark ? AppColors.darkSurface : AppColors.lightBackground;
  Color get primaryText => isDark ? Colors.white : const Color(0xFF111111);
  Color get secondaryText =>
      isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333);
  Color get cardText => primaryText;
  Color get dragHandle =>
      isDark ? const Color(0xFFBDBDBD) : const Color(0xFF777777);
}

class _QuickAddAction {
  const _QuickAddAction(
    this.label,
    this.description,
    this.icon,
    this.color,
    this.badgeColor,
    this.callback,
  );
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Color badgeColor;
  final Future<void> Function(BuildContext, WidgetRef) callback;
}

Future<void> _openTransaction(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const TransactionFormScreen()));
}

Future<void> _go(BuildContext context, String route) async {
  if (context.mounted) context.go(route);
}
