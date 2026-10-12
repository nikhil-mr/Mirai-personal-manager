import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_controller.dart';

enum DashboardSection {
  money,
  taskProgress,
  upcomingTasks,
  places,
  groceries,
  commitments,
}

class DashboardVisibility {
  DashboardVisibility(Map<DashboardSection, bool> values)
    : _values = Map.unmodifiable(values);

  final Map<DashboardSection, bool> _values;

  bool isVisible(DashboardSection section) => _values[section] ?? true;

  DashboardVisibility withSection(DashboardSection section, bool visible) =>
      DashboardVisibility({..._values, section: visible});

  static DashboardVisibility defaults() => DashboardVisibility({
    for (final section in DashboardSection.values) section: true,
  });
}

const _visibilityPreferenceKey = 'dashboard_hidden_sections';

final dashboardVisibilityProvider =
    NotifierProvider<DashboardVisibilityController, DashboardVisibility>(
      DashboardVisibilityController.new,
    );

class DashboardVisibilityController extends Notifier<DashboardVisibility> {
  @override
  DashboardVisibility build() {
    final hidden =
        ref
            .read(sharedPreferencesProvider)
            .getStringList(_visibilityPreferenceKey)
            ?.toSet() ??
        {};
    return DashboardVisibility({
      for (final section in DashboardSection.values)
        section: !hidden.contains(section.name),
    });
  }

  void setVisible(DashboardSection section, bool visible) {
    state = state.withSection(section, visible);
    final hidden = DashboardSection.values
        .where((candidate) => !state.isVisible(candidate))
        .map((candidate) => candidate.name)
        .toList();
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setStringList(_visibilityPreferenceKey, hidden),
    );
  }

  void restoreDefaults() {
    state = DashboardVisibility.defaults();
    unawaited(
      ref.read(sharedPreferencesProvider).remove(_visibilityPreferenceKey),
    );
  }
}
