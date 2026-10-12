import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Outlined card with the crisp, offset shadow used throughout Mirai.
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: dark ? AppColors.darkBorder : AppColors.lightText,
        width: 2,
      ),
    );
    final content = Material(
      color: color ?? Theme.of(context).cardColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow && !dark
            ? const [
                BoxShadow(color: AppColors.lightText, offset: Offset(4, 4)),
              ]
            : null,
      ),
      child: content,
    );
  }
}
