import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';

/// The application's route names, kept as constants to avoid typos.
abstract class AppRoute {
  static const home = '/';
}

/// Provides the [GoRouter] instance for the application.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home,
    routes: [
      GoRoute(
        path: AppRoute.home,
        name: AppRoute.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
