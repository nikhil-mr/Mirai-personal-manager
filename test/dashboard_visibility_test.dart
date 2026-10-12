import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal_manager/app/theme/theme_controller.dart';
import 'package:personal_manager/features/today/application/dashboard_visibility.dart';

void main() {
  test('section visibility is configurable and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(dashboardVisibilityProvider)
          .isVisible(DashboardSection.places),
      isTrue,
    );
    container
        .read(dashboardVisibilityProvider.notifier)
        .setVisible(DashboardSection.places, false);

    expect(
      container
          .read(dashboardVisibilityProvider)
          .isVisible(DashboardSection.places),
      isFalse,
    );
    expect(preferences.getStringList('dashboard_hidden_sections'), ['places']);
  });

  test('accent color persists and dashboard visibility resets', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    container
        .read(accentColorProvider.notifier)
        .setColor(accentColorOptions[2]);
    expect(
      preferences.getInt('appearance_accent_color'),
      accentColorOptions[2],
    );
    container
        .read(dashboardVisibilityProvider.notifier)
        .setVisible(DashboardSection.money, false);
    container.read(dashboardVisibilityProvider.notifier).restoreDefaults();
    expect(
      container
          .read(dashboardVisibilityProvider)
          .isVisible(DashboardSection.money),
      isTrue,
    );
    expect(preferences.getStringList('dashboard_hidden_sections'), isNull);
  });
}
