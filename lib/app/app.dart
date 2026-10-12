import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class LifePartnerApp extends ConsumerWidget {
  const LifePartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Color(ref.watch(accentColorProvider));
    final compact = ref.watch(compactLayoutProvider);
    return MaterialApp.router(
      title: 'Mirai',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: accent, compact: compact),
      darkTheme: AppTheme.dark(accent: accent, compact: compact),
      themeMode: ref.watch(themeControllerProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
