import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistance/presentation/assistance_screen.dart';
import '../../features/buildings/presentation/buildings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/domain/onboarding_providers.dart';
import '../../features/onboarding/presentation/accessibility_preferences_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/routing/presentation/routes_screen.dart';

/// The application's route names, kept as constants to avoid typos.
abstract class AppRoute {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const preferences = '/onboarding/preferences';
  static const assistance = '/assistance';
  static const profile = '/profile';
  static const buildings = '/buildings';
  static const routes = '/routes';
}

/// Provides the [GoRouter] instance for the application.
///
/// The router redirects to onboarding until the user has completed it,
/// keeping the decision in one place.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home,
    redirect: (context, state) {
      final onboardingComplete = ref.read(onboardingCompletedProvider);
      final onOnboarding = state.matchedLocation.startsWith(
        AppRoute.onboarding,
      );

      if (!onboardingComplete && !onOnboarding) {
        return AppRoute.onboarding;
      }
      if (onboardingComplete && onOnboarding) {
        // Entered the onboarding flow again (e.g. from settings reset) —
        // allow it only for the preferences step, otherwise go home.
        if (state.matchedLocation == AppRoute.onboarding) {
          return AppRoute.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.home,
        name: AppRoute.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.assistance,
        name: AppRoute.assistance,
        builder: (context, state) => const AssistanceScreen(),
      ),
      GoRoute(
        path: AppRoute.profile,
        name: AppRoute.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.buildings,
        name: AppRoute.buildings,
        builder: (context, state) => const BuildingsScreen(),
        routes: [
          GoRoute(
            path: ':buildingId',
            name: '${AppRoute.buildings}/:buildingId',
            builder: (context, state) => BuildingDetailScreen(
              building: state.extra as dynamic,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.routes,
        name: AppRoute.routes,
        builder: (context, state) => const RoutesScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding,
        name: AppRoute.onboarding,
        builder: (context, state) => const OnboardingFlowScreen(),
        routes: [
          GoRoute(
            path: 'preferences',
            name: AppRoute.preferences,
            builder: (context, state) => const AccessibilityPreferencesScreen(),
          ),
        ],
      ),
    ],
  );
});
