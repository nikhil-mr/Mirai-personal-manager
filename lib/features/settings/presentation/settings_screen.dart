import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../money/application/money_providers.dart';
import '../../groceries/application/grocery_providers.dart';
import '../../places/application/places_providers.dart';
import '../../today/application/dashboard_visibility.dart';
import '../../today/application/dashboard_providers.dart';
import '../../todos/application/task_providers.dart';
import '../application/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMode = ref.watch(themeControllerProvider);
    final visibility = ref.watch(dashboardVisibilityProvider);
    final accent = ref.watch(accentColorProvider);
    final compact = ref.watch(compactLayoutProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Settings & Privacy'),
      ),
      body: PageContainer(
        child: ListView(
          children: [
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Choose how Mirai looks on this device.',
            ),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: selectedMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeControllerProvider.notifier).setMode(value);
                  }
                },
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        value: mode,
                        title: Text(switch (mode) {
                          ThemeMode.system => 'System default',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Accent color'),
                      subtitle: const Text('Applied throughout the app.'),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          for (final value in accentColorOptions)
                            Semantics(
                              button: true,
                              label: 'Choose accent color',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => ref
                                    .read(accentColorProvider.notifier)
                                    .setColor(value),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(value),
                                  child: accent == value
                                      ? const Icon(Icons.check, size: 16)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Compact spacing'),
                      subtitle: const Text('Fit more content on screen.'),
                      value: compact,
                      onChanged: ref
                          .read(compactLayoutProvider.notifier)
                          .setCompact,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Dashboard customization',
              subtitle: 'Hide sections without deleting their records.',
            ),
            Card(
              child: Column(
                children: [
                  for (final section in DashboardSection.values)
                    SwitchListTile(
                      secondary: Icon(_sectionIcon(section)),
                      title: Text(_sectionLabel(section)),
                      value: visibility.isVisible(section),
                      onChanged: (value) => ref
                          .read(dashboardVisibilityProvider.notifier)
                          .setVisible(section, value),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Restore default layout'),
                    subtitle: const Text('Show all dashboard sections.'),
                    onTap: () => ref
                        .read(dashboardVisibilityProvider.notifier)
                        .restoreDefaults(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Security & app lock',
              subtitle: 'Protection available on this installation.',
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('App lock is not available'),
                subtitle: Text(
                  'This build has no secure credential storage or biometric plugin. A browser or local PIN would not protect data from someone with access to the device profile.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Data & backup',
              subtitle: 'Export a backup, or merge one into this device.',
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.ios_share_outlined),
                    title: const Text('Export data (JSON)'),
                    subtitle: const Text(
                      'Copy a complete backup to the clipboard, then save it as a .json file.',
                    ),
                    onTap: () => _export(context, ref),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Restore from JSON'),
                    subtitle: const Text(
                      'Merge records by ID. Existing records with matching IDs are kept.',
                    ),
                    onTap: () => _restore(context, ref),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Clear local data'),
                    subtitle: const Text(
                      'Permanently remove records stored on this device.',
                    ),
                    onTap: () => _clearData(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Privacy',
              subtitle: 'Where your information lives and how to manage it.',
            ),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrivacyLine(
                      title: 'Storage',
                      body: 'Your records are stored in a local database on this device/browser profile.',
                    ),
                    _PrivacyLine(
                      title: 'Cloud sync',
                      body: 'Cloud synchronization is not available.',
                    ),
                    _PrivacyLine(
                      title: 'Encryption',
                      body: 'This app does not currently provide verified database encryption at rest.',
                    ),
                    _PrivacyLine(
                      title: 'Backups and deletion',
                      body: 'Use Export and Restore above to manage backups. Clear Local Data removes local Mirai records only.',
                    ),
                    _PrivacyLine(
                      title: 'Browser storage',
                      body: 'Browser data can be cleared by browser settings. A browser PIN cannot protect data from someone who can inspect the browser profile.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Notifications & reminders',
              subtitle:
                  'Task reminders use the existing local notification service.',
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Task reminders'),
                subtitle: Text(
                  'Reminder permissions are requested when scheduling a task. Scheduled background reminders are unavailable in web browsers and Linux in this build.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'About Mirai'),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.favorite_outline),
                    title: Text('Mirai'),
                    subtitle: Text(
                      'Personal management for everyday life · Version 1.0.0+1',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy information'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Mirai',
                      applicationVersion: '1.0.0+1',
                      applicationLegalese: 'Personal management for everyday life. Data is stored locally; cloud sync is not available.',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Open-source licenses'),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Mirai',
                      applicationVersion: '1.0.0+1',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 3),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

String _sectionLabel(DashboardSection section) => switch (section) {
  DashboardSection.money => 'Money overview',
  DashboardSection.taskProgress => 'Task progress',
  DashboardSection.upcomingTasks => 'Upcoming tasks',
  DashboardSection.places => 'Places planned today',
  DashboardSection.groceries => 'Grocery basket',
  DashboardSection.commitments => 'Bills & deadlines',
};

IconData _sectionIcon(DashboardSection section) => switch (section) {
  DashboardSection.money => Icons.wallet_outlined,
  DashboardSection.taskProgress => Icons.donut_small_outlined,
  DashboardSection.upcomingTasks => Icons.checklist_outlined,
  DashboardSection.places => Icons.place_outlined,
  DashboardSection.groceries => Icons.shopping_basket_outlined,
  DashboardSection.commitments => Icons.event_note_outlined,
};

Future<void> _export(BuildContext context, WidgetRef ref) async {
  try {
    final preferences = ref.read(sharedPreferencesProvider);
    final mode = ref.read(themeControllerProvider);
    final json = await ref
        .read(settingsDataServiceProvider)
        .exportJson(
          settings: {
            'themeMode': switch (mode) {
              ThemeMode.system => 'system',
              ThemeMode.light => 'light',
              ThemeMode.dark => 'dark',
            },
            'accentColor': preferences.getInt('appearance_accent_color'),
            'compactLayout': preferences.getBool('layout_compact') ?? false,
            'hiddenDashboardSections':
                preferences.getStringList('dashboard_hidden_sections') ??
                const [],
          },
        );
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup copied'),
          content: const Text(
            'The JSON backup is on your clipboard. Paste it into a text editor and save it as a .json file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Could not export data: $error');
  }
}

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final json = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Restore Mirai backup'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the contents of a Mirai JSON backup. Records are merged by ID; matching IDs already on this device are left unchanged. Export a backup of current data first.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'Backup JSON'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Validate and merge'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (json == null || !context.mounted) return;
  try {
    final count = await ref
        .read(settingsDataServiceProvider)
        .restoreMerge(json);
    if (!context.mounted) return;
    _invalidateData(ref);
    if (context.mounted) {
      _showMessage(context, 'Backup merged. $count new records restored.');
    }
  } catch (error) {
    if (context.mounted) {
      _showMessage(
        context,
        'Restore failed; existing data was left unchanged. $error',
      );
    }
  }
}

Future<void> _clearData(BuildContext context, WidgetRef ref) async {
  var resetSettings = false;
  final firstConfirmation = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Clear local data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your local accounts, transactions, budgets, tasks, places, trips, and grocery records. Export a backup first. It does not delete remote data.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: resetSettings,
              title: const Text('Also reset appearance and dashboard settings'),
              onChanged: (value) =>
                  setDialogState(() => resetSettings = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  if (firstConfirmation != true || !context.mounted) return;
  final finalConfirmation = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm permanent deletion'),
      content: const Text('There is no undo for clearing these local records.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Go back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Clear local data'),
        ),
      ],
    ),
  );
  if (finalConfirmation != true || !context.mounted) return;
  try {
    await ref.read(settingsDataServiceProvider).clearRecords();
    await ref.read(moneyRepositoryProvider).seedDefaults();
    if (resetSettings) {
      await ref.read(sharedPreferencesProvider).clear();
      ref.invalidate(themeControllerProvider);
      ref.invalidate(accentColorProvider);
      ref.invalidate(compactLayoutProvider);
      ref.invalidate(dashboardVisibilityProvider);
    }
    if (!context.mounted) return;
    _invalidateData(ref);
    if (context.mounted) {
      _showMessage(context, 'Local Mirai records cleared.');
    }
  } catch (error) {
    if (context.mounted) {
      _showMessage(context, 'Could not clear local data: $error');
    }
  }
}

void _invalidateData(WidgetRef ref) {
  ref.invalidate(moneyAccountsProvider);
  ref.invalidate(moneyActiveAccountsProvider);
  ref.invalidate(moneyTransactionsProvider);
  ref.invalidate(moneyExpensesCategoriesProvider);
  ref.invalidate(moneyIncomeCategoriesProvider);
  ref.invalidate(moneyBalancesProvider);
  ref.invalidate(tasksProvider);
  ref.invalidate(taskCategoriesProvider);
  ref.invalidate(savedPlacesProvider);
  ref.invalidate(groceryListsProvider);
  ref.invalidate(todayDashboardSnapshotProvider);
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
