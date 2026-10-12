import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'appearance_mode';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences must be initialized in main.'),
);

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

const accentColorOptions = <int>[
  0xFFFFDF24,
  0xFF6750A4,
  0xFF0B806F,
  0xFF1769AA,
  0xFFB3261E,
  0xFF9A4D00,
  0xFF9C3E75,
];

final accentColorProvider = NotifierProvider<AccentColorController, int>(
  AccentColorController.new,
);

class AccentColorController extends Notifier<int> {
  static const _key = 'appearance_accent_color';

  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_key) ?? accentColorOptions[0];

  void setColor(int value) {
    if (!accentColorOptions.contains(value)) return;
    state = value;
    unawaited(ref.read(sharedPreferencesProvider).setInt(_key, value));
  }
}

final compactLayoutProvider = NotifierProvider<CompactLayoutController, bool>(
  CompactLayoutController.new,
);

class CompactLayoutController extends Notifier<bool> {
  static const _key = 'layout_compact';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  void setCompact(bool value) {
    state = value;
    unawaited(ref.read(sharedPreferencesProvider).setBool(_key, value));
  }
}

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final value = ref
        .read(sharedPreferencesProvider)
        .getString(_themePreferenceKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setMode(ThemeMode mode) {
    state = mode;
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    unawaited(
      ref.read(sharedPreferencesProvider).setString(_themePreferenceKey, name),
    );
  }
}
