import 'package:flutter/material.dart';

import 'brutal_card.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.label,
    required this.icon,
    required this.tint,
    this.value = '-',
    this.supportingText = 'No data yet',
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final String value;
  final String supportingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => BrutalCard(
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          supportingText,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
