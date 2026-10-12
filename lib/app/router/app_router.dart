import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/groceries/presentation/groceries_screen.dart';
import '../../features/money/presentation/money_screen.dart';
import '../../features/budgets/presentation/budget_planner_screen.dart';
import '../../features/places/presentation/places_screen.dart';
import '../../features/places/presentation/place_details_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/todos/presentation/todos_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow.dart';
import '../../features/money/domain/money_models.dart';
import '../../app/theme/theme_controller.dart';
import 'app_routes.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.launch,
    redirect: (context, state) {
      final complete =
          ref
              .read(sharedPreferencesProvider)
              .getBool('life_partner_setup_complete_v1') ??
          false;
      final location = state.uri.path;
      final setupRoute =
          location == AppRoutes.welcome ||
          location == AppRoutes.onboarding ||
          location == AppRoutes.excelImport ||
          location == AppRoutes.importPreview ||
          location == AppRoutes.importProgress;
      if (!complete && !setupRoute && location != AppRoutes.launch) {
        return AppRoutes.welcome;
      }
      if (complete && (setupRoute || location == AppRoutes.launch)) {
        return AppRoutes.startup;
      }
      return null;
    },
    errorBuilder: (context, state) =>
        UnknownRouteScreen(location: state.uri.toString()),
    routes: [
      GoRoute(
        path: AppRoutes.launch,
        builder: (context, state) => const LaunchScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const FeatureOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.excelImport,
        builder: (context, state) => const ExcelImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.importPreview,
        builder: (context, state) => state.extra is ImportPreviewData
            ? ImportPreviewScreen(data: state.extra! as ImportPreviewData)
            : const ExcelImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.importProgress,
        builder: (context, state) =>
            state.extra is List<MoneyImportRecord> &&
                (state.extra as List<MoneyImportRecord>).isNotEmpty
            ? ImportProgressScreen(
                records: state.extra! as List<MoneyImportRecord>,
              )
            : const ExcelImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                name: 'today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.money,
                name: 'money',
                builder: (context, state) => const MoneyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.todos,
                name: 'todos',
                builder: (context, state) => const TodosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.places,
                name: 'places',
                builder: (context, state) => PlacesScreen(
                  quickAdd: state.uri.queryParameters['quickAdd'],
                ),
                routes: [
                  GoRoute(
                    path: ':placeId',
                    name: 'placeDetails',
                    builder: (context, state) => PlaceDetailsScreen(
                      placeId: state.pathParameters['placeId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.groceries,
                name: 'groceries',
                builder: (context, state) => const GroceriesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.budgets,
        name: 'budgets',
        builder: (context, state) => const BudgetPlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({required this.location, super.key});
  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "We couldn't find that page",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '"$location" is not a Mirai destination.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.today),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Go to Today'),
            ),
          ],
        ),
      ),
    ),
  );
}
