import 'package:flutter/material.dart';

import '../../domain/dashboard_calculations.dart';

class TaskProgressCard extends StatelessWidget {
  const TaskProgressCard({
    required this.progress,
    required this.onTap,
    super.key,
  });

  final TaskProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task progress',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${progress.percent}%',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: '${progress.percent} percent complete',
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              progress.total == 0
                  ? 'No tasks scheduled for today'
                  : '${progress.completed} of ${progress.total} tasks completed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 3),
            Text(
              progress.total == 0
                  ? 'Your day will take shape when your To-do list is connected.'
                  : '${progress.remaining} remaining',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
