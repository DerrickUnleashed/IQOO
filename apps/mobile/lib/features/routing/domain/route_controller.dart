// Turn-by-turn routing controller.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../onboarding/domain/api_profile_mapper.dart';
import '../../onboarding/domain/app_client_providers.dart';
import '../../onboarding/domain/onboarding_providers.dart';
import '../../onboarding/domain/session_controller.dart';

/// The active navigation state of the routing flow.
sealed class RoutingState {
  const RoutingState();
}

/// No route in progress yet.
class RouteIdle extends RoutingState {
  const RouteIdle({this.lastMessage});
  final String? lastMessage;
}

/// Waiting for the planner to respond.
class RouteCalculating extends RoutingState {
  const RouteCalculating();
}

/// A route is loaded; [stepIndex] points at the current instruction.
class RouteActive extends RoutingState {
  const RouteActive({
    required this.route,
    required this.stepIndex,
    this.destinationLabel,
  });

  final api.Route route;
  final int stepIndex;
  final String? destinationLabel;

  int get totalSteps => route.steps?.length ?? 0;

  api.RouteStep? get currentStep =>
      (stepIndex >= 0 && stepIndex < totalSteps)
          ? route.steps![stepIndex]
          : null;
}

/// The planner could not produce a route.
class RouteFailed extends RoutingState {
  const RouteFailed({required this.reason});
  final String reason;
}

/// Drives the turn-by-turn flow: calculate, then step forward/back.
final routeControllerProvider = NotifierProvider<RouteController, RoutingState>(
  RouteController.new,
);

class RouteController extends Notifier<RoutingState> {
  @override
  RoutingState build() => const RouteIdle();

  Future<void> startRoute({
    required api.Location origin,
    required api.Location destination,
    String? destinationLabel,
  }) async {
    final client = ref.read(apiClientProvider);
    final profile = ref.read(accessibilityProfileProvider);
    final session = ref.read(sessionControllerProvider);

    state = const RouteCalculating();
    try {
      final route = await client.calculateRoute(
        body: api.RouteRequest(
          sessionId: session.sessionId,
          origin: origin,
          destination: destination,
          profile: ApiProfileMapper.toApi(profile),
        ),
      );
      if (!ref.mounted) return;
      state = RouteActive(route: route, stepIndex: 0, destinationLabel: destinationLabel);
    } on Exception {
      if (!ref.mounted) return;
      state = const RouteFailed(
        reason: 'I could not plan that route right now. Check your connection and try again.',
      );
    }
  }

  void nextStep() {
    final current = state;
    if (current is RouteActive && current.stepIndex < current.totalSteps - 1) {
      state = RouteActive(
        route: current.route,
        stepIndex: current.stepIndex + 1,
        destinationLabel: current.destinationLabel,
      );
    }
  }

  void previousStep() {
    final current = state;
    if (current is RouteActive && current.stepIndex > 0) {
      state = RouteActive(
        route: current.route,
        stepIndex: current.stepIndex - 1,
        destinationLabel: current.destinationLabel,
      );
    }
  }

  void reset() => state = const RouteIdle();
}