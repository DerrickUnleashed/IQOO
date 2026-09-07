import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/domain/onboarding_providers.dart';
import '../../features/onboarding/presentation/accessibility_preferences_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';

/// The application's route names, kept as constants to avoid typos.
abstract class AppRoute {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const preferences = '/onboarding/preferences';
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
