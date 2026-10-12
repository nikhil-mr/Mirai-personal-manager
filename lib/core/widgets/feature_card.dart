import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.tint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(height: 17),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Row(
              children: [
                Text(
                  'Explore',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
