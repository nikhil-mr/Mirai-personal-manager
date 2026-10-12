import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_container.dart';
import '../application/task_providers.dart';
import '../domain/task_logic.dart';

class TodosScreen extends ConsumerWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final categoriesAsync = ref.watch(taskCategoriesProvider);
    final allTasks = tasksAsync.asData?.value ?? const [];
    final categories = categoriesAsync.asData?.value ?? const [];
    final categoryNames = {for (final c in categories) c.id: c.name};
    final view = ref.watch(taskViewProvider);
    final filtered = filterAndSortTasks(
      tasks: allTasks,
      view: view,
      now: DateTime.now(),
      query: ref.watch(taskSearchProvider),
      categoryNames: categoryNames,
      categoryId: ref.watch(taskCategoryFilterProvider),
      priority: ref.watch(taskPriorityFilterProvider),
      sort: ref.watch(taskSortProvider),
    );
    final progress = dailyTaskProgress(allTasks, DateTime.now());
    return PageContainer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A little structure for the day ahead.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your tasks',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showTaskEditor(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add task'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.today_rounded),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Daily progress')),
                        Text('${progress.completed}/${progress.total}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progress.total == 0
                          ? 0
                          : progress.completed / progress.total,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress.total == 0
                          ? 'Add a task due today or include an undated task.'
                          : '${progress.total - progress.completed} remaining today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<TaskView>(
              initialValue: view,
              decoration: const InputDecoration(
                labelText: 'Task view',
                prefixIcon: Icon(Icons.view_agenda_outlined),
              ),
              items: const [
                DropdownMenuItem(value: TaskView.today, child: Text('Today')),
                DropdownMenuItem(
                  value: TaskView.upcoming,
                  child: Text('Upcoming'),
                ),
                DropdownMenuItem(
                  value: TaskView.allPending,
                  child: Text('All pending'),
                ),
                DropdownMenuItem(
                  value: TaskView.overdue,
                  child: Text('Overdue'),
                ),
                DropdownMenuItem(value: TaskView.done, child: Text('Done')),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(taskViewProvider.notifier).state = value;
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('task_search'),
                    decoration: InputDecoration(
                      hintText: 'Search tasks',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ref.watch(taskSearchProvider).isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  ref.read(taskSearchProvider.notifier).state =
                                      '',
                            ),
                    ),
                    onChanged: (value) =>
                        ref.read(taskSearchProvider.notifier).state = value,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Filters',
                  onPressed: () => _showFilters(context, ref, categories),
                  icon: const Icon(Icons.tune_rounded),
                ),
                PopupMenuButton<TaskSort>(
                  tooltip: 'Sort tasks',
                  initialValue: ref.watch(taskSortProvider),
                  onSelected: (v) =>
                      ref.read(taskSortProvider.notifier).state = v,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TaskSort.dueTime,
                      child: Text('Sort by due time'),
                    ),
                    PopupMenuItem(
                      value: TaskSort.priority,
                      child: Text('Sort by priority'),
                    ),
                    PopupMenuItem(
                      value: TaskSort.createdAt,
                      child: Text('Sort by recently created'),
                    ),
                  ],
                  icon: const Icon(Icons.sort_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tasksAsync.isLoading && allTasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tasksAsync.hasError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load tasks: ${tasksAsync.error}'),
                ),
              )
            else if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          view == TaskView.done
                              ? Icons.task_alt
                              : Icons.checklist_rounded,
                          size: 38,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _emptyTitle(view),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(_emptyMessage(view), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...filtered.map(
                (task) => _TaskTile(
                  task: task,
                  category: categoryNames[task.categoryId],
                  onEdit: () => showTaskEditor(context, ref, task: task),
                  onDetails: () => _showDetails(
                    context,
                    ref,
                    task,
                    categoryNames[task.categoryId],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _emptyTitle(TaskView view) => switch (view) {
  TaskView.today => 'No tasks for today',
  TaskView.upcoming => 'Nothing upcoming',
  TaskView.allPending => 'All caught up',
  TaskView.overdue => 'Nothing overdue',
  TaskView.done => 'No completed tasks yet',
};
String _emptyMessage(TaskView view) => view == TaskView.today
    ? 'Create a task due today, or add an undated task to today.'
    : 'Tasks in this view will show up here.';

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.category,
    required this.onEdit,
    required this.onDetails,
  });
  final dynamic task;
  final String? category;
  final VoidCallback onEdit;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = task.isCompleted as bool;
    final due = task.dueAt as DateTime?;
    final hasTime = task.dueHasTime as bool;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: completed,
          onChanged: (value) => ref
              .read(taskRepositoryProvider)
              .setCompleted(task.id as String, completed: value ?? false),
        ),
        title: Text(
          task.title as String,
          style: completed
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (due != null)
              Text(
                'Due ${MaterialLocalizations.of(context).formatMediumDate(due)}${hasTime ? ' · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(due))}' : ''}',
              ),
            Wrap(
              spacing: 8,
              children: [
                if (category != null) Text(category!),
                Text((task.priority as String).toUpperCase()),
                if (task.reminderEnabled as bool)
                  const Icon(Icons.notifications_active_outlined, size: 16),
              ],
            ),
          ],
        ),
        onTap: onDetails,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') onEdit();
            if (value == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete task?'),
                  content: Text('“${task.title}” will be permanently deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref
                    .read(taskRepositoryProvider)
                    .deleteTask(task.id as String);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(completed ? 'Edit' : 'Edit'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

Future<void> showTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  dynamic task,
}) async {
  final repo = ref.read(taskRepositoryProvider);
  final categories = await repo.categories();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _TaskEditor(task: task, categories: categories),
  );
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({required this.task, required this.categories});
  final dynamic task;
  final List<dynamic> categories;
  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final TextEditingController title = TextEditingController(
    text: widget.task?.title as String? ?? '',
  );
  late final TextEditingController description = TextEditingController(
    text: widget.task?.description as String? ?? '',
  );
  late DateTime? due = widget.task?.dueAt as DateTime?;
  late bool hasTime = widget.task?.dueHasTime as bool? ?? false;
  // The default screen is Today, so a new undated task should be visible
  // immediately after saving. Existing tasks retain their saved setting.
  late bool includeToday = widget.task?.includeInToday as bool? ?? true;
  late bool reminder = widget.task?.reminderEnabled as bool? ?? false;
  late DateTime? reminderAt = widget.task?.reminderAt as DateTime?;
  late String? category = widget.task?.categoryId as String?;
  late TaskPriority priority = TaskPriority.values.firstWhere(
    (p) => p.name == (widget.task?.priority as String? ?? 'medium'),
    orElse: () => TaskPriority.medium,
  );
  late String sound = widget.task?.notificationSoundId as String? ?? 'default';
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'New task' : 'Edit task'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('task_title'),
              controller: title,
              autofocus: true,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What needs to get done?',
              ),
            ),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskPriority>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final p in TaskPriority.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => priority = v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No category'),
                ),
                ...widget.categories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name as String),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickDue,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                due == null
                    ? 'Set due date'
                    : 'Due ${MaterialLocalizations.of(context).formatMediumDate(due!)}${hasTime ? ' · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(due!))}' : ''}',
              ),
            ),
            if (due != null)
              Row(
                children: [
                  TextButton(
                    onPressed: _pickTime,
                    child: Text(hasTime ? 'Change time' : 'Add time'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      due = null;
                      hasTime = false;
                    }),
                    child: const Text('Clear date'),
                  ),
                ],
              ),
            if (due == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in Today'),
                value: includeToday,
                onChanged: (v) => setState(() => includeToday = v),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder'),
              subtitle: const Text('One-time notification'),
              value: reminder,
              onChanged: (v) => setState(() {
                reminder = v;
                if (v && reminderAt == null) {
                  reminderAt =
                      due ?? DateTime.now().add(const Duration(minutes: 15));
                }
              }),
            ),
            if (reminder) ...[
              TextButton.icon(
                onPressed: _pickReminder,
                icon: const Icon(Icons.notifications_outlined),
                label: Text(
                  reminderAt == null
                      ? 'Choose reminder time'
                      : '${MaterialLocalizations.of(context).formatFullDate(reminderAt!)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reminderAt!))}',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: sound,
                decoration: const InputDecoration(
                  labelText: 'Notification sound',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'default',
                    child: Text('Default sound'),
                  ),
                  DropdownMenuItem(value: 'silent', child: Text('Silent')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => sound = v);
                },
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save task'),
      ),
    ],
  );

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: due ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(
      () => due = DateTime(
        date.year,
        date.month,
        date.day,
        hasTime ? (due?.hour ?? 9) : 0,
        hasTime ? (due?.minute ?? 0) : 0,
      ),
    );
    if (reminder && reminderAt == null) setState(() => reminderAt = due);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: due == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(due!),
    );
    if (value == null || !mounted) return;
    setState(() {
      hasTime = true;
      final d = due ?? DateTime.now();
      due = DateTime(d.year, d.month, d.day, value.hour, value.minute);
    });
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: reminderAt ?? due ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: reminderAt == null
          ? TimeOfDay.fromDateTime(
              DateTime.now().add(const Duration(minutes: 15)),
            )
          : TimeOfDay.fromDateTime(reminderAt!),
    );
    if (time != null && mounted) {
      setState(
        () => reminderAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    try {
      await ref.read(taskRepositoryProvider).saveCategory(name: name);
      final updated = await ref.read(taskRepositoryProvider).categories();
      setState(() {
        widget.categories.clear();
        widget.categories.addAll(updated);
        category = updated
            .firstWhere(
              (c) => c.name.toLowerCase() == name.trim().toLowerCase(),
            )
            .id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final result = await ref
          .read(taskRepositoryProvider)
          .saveTask(
            id: widget.task?.id as String?,
            title: title.text,
            description: description.text,
            categoryId: category,
            priority: priority,
            dueAt: due,
            dueHasTime: hasTime,
            includeInToday: includeToday,
            reminderAt: reminder ? reminderAt : null,
            reminderEnabled: reminder,
            notificationSoundId: sound,
          );
      if (!mounted) return;
      if (widget.task == null) {
        // A remembered search/filter/view can otherwise hide a newly saved
        // task and make the Add action look like it did nothing.
        ref.read(taskSearchProvider.notifier).state = '';
        ref.read(taskPriorityFilterProvider.notifier).state = null;
        ref.read(taskCategoryFilterProvider.notifier).state = null;
        final isToday = due == null
            ? includeToday
            : localDateOnly(due!) == localDateOnly(DateTime.now());
        ref.read(taskViewProvider.notifier).state = isToday
            ? TaskView.today
            : TaskView.allPending;
      }
      Navigator.pop(context);
      if (widget.task == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added to your To-do list.')),
        );
      }
      if (result.reminderMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.reminderMessage!)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

Future<void> _showFilters(
  BuildContext context,
  WidgetRef ref,
  List<dynamic> categories,
) => showModalBottomSheet<void>(
  context: context,
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter tasks', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaskPriority?>(
            initialValue: ref.read(taskPriorityFilterProvider),
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              const DropdownMenuItem<TaskPriority?>(
                value: null,
                child: Text('Any priority'),
              ),
              ...TaskPriority.values.map(
                (p) => DropdownMenuItem<TaskPriority?>(
                  value: p,
                  child: Text(p.label),
                ),
              ),
            ],
            onChanged: (v) =>
                ref.read(taskPriorityFilterProvider.notifier).state = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: ref.read(taskCategoryFilterProvider),
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Any category'),
              ),
              ...categories.map(
                (c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.name as String),
                ),
              ),
            ],
            onChanged: (v) =>
                ref.read(taskCategoryFilterProvider.notifier).state = v,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ref.read(taskPriorityFilterProvider.notifier).state = null;
                ref.read(taskCategoryFilterProvider.notifier).state = null;
                Navigator.pop(ctx);
              },
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ),
    ),
  ),
);

void _showDetails(
  BuildContext context,
  WidgetRef ref,
  dynamic task,
  String? category,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(task.title as String),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((task.description as String).isNotEmpty)
            Text(task.description as String),
          const SizedBox(height: 8),
          Text('Priority: ${(task.priority as String).toUpperCase()}'),
          if (category != null) Text('Category: $category'),
          if (task.dueAt != null)
            Text(
              'Due: ${MaterialLocalizations.of(ctx).formatFullDate(task.dueAt as DateTime)}',
            ),
          if (task.completedAt != null)
            Text(
              'Completed: ${MaterialLocalizations.of(ctx).formatFullDate(task.completedAt as DateTime)}',
            ),
        ],
      ),
    ),
    actions: [
      if (task.isCompleted as bool)
        TextButton(
          onPressed: () async {
            await ref
                .read(taskRepositoryProvider)
                .setCompleted(task.id as String, completed: false);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Restore'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(ctx);
          showTaskEditor(context, ref, task: task);
        },
        child: const Text('Edit'),
      ),
    ],
  ),
);
