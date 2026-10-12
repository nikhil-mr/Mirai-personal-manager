import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/dashboard_models.dart';

class DashboardTaskTile extends StatelessWidget {
  const DashboardTaskTile({required this.task, super.key});

  final DashboardTask task;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = task.dueAt ?? task.scheduledAt;
    final priority = switch (task.priority) {
      DashboardTaskPriority.low => 'Low priority',
      DashboardTaskPriority.normal => 'Normal priority',
      DashboardTaskPriority.high => 'High priority',
    };
    final priorityColor = task.priority == DashboardTaskPriority.high
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: [
        task.title,
        if (time != null) DateFormat.jm().format(time.toLocal()),
        priority,
        if (task.reminderAt != null) 'Reminder set',
      ].join(', '),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time == null
                        ? 'No time set'
                        : DateFormat.jm().format(time.toLocal()),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (task.reminderAt != null) ...[
              Tooltip(
                message: 'Reminder set',
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              priority,
              style: textTheme.bodySmall?.copyWith(color: priorityColor),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
