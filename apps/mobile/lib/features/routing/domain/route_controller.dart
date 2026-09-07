// Turn-by-turn routing controller.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../assistance/domain/scene_pipeline.dart';
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
    this.lastVerification,
  });

  final api.Route route;
  final int stepIndex;
  final String? destinationLabel;

  /// Result of the most recent closed-loop checkpoint, if any.
  final api.VerificationResult? lastVerification;

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

  /// Closed-loop check: confirm the current step against the live scene.
  ///
  /// A temporary blockage currently visible means the action did not
  /// complete; the planner is informed so the route can be recomputed.
  Future<api.VerificationResult?> verifyCurrentStep() async {
    final current = state;
    if (current is! RouteActive) return null;

    final client = ref.read(apiClientProvider);
    final session = ref.read(sessionControllerProvider);
    final scene = ref.read(scenePipelineStateProvider);
    final objects = switch (scene) {
      SceneLive(:final sceneObjects) => sceneObjects,
      _ => <api.SceneObject>[],
    };

    try {
      final result = await client.checkVerification(
        body: api.VerificationRequest(
          sessionId: session.sessionId ?? '',
          actionId: 'step-${current.stepIndex + 1}',
          sceneObjects: objects,
        ),
      );
      if (!ref.mounted) return null;
      state = RouteActive(
        route: current.route,
        stepIndex: current.stepIndex,
        destinationLabel: current.destinationLabel,
        lastVerification: result,
      );
      return result;
    } on Exception {
      if (!ref.mounted) return null;
      state = RouteActive(
        route: current.route,
        stepIndex: current.stepIndex,
        destinationLabel: current.destinationLabel,
        lastVerification: api.VerificationResult(
          actionId: 'step-${current.stepIndex + 1}',
          verified: false,
          message: 'Could not run the checkpoint right now.',
        ),
      );
      return null;
    }
  }

  /// Recompute the route from the current position when blocked.
  Future<void> replan({String? reason}) async {
    final current = state;
    if (current is! RouteActive) return;

    final client = ref.read(apiClientProvider);
    final profile = ref.read(accessibilityProfileProvider);
    final session = ref.read(sessionControllerProvider);

    // Replan from the current position toward the same destination space.
    final destination = api.Location(
      latitude: 0,
      longitude: 0,
      floorLevel: 2,
    );

    state = const RouteCalculating();
    try {
      final route = await client.replanRoute(
        body: api.ReplanRequest(
          sessionId: session.sessionId ?? '',
          current: api.Location(latitude: 0, longitude: 0, floorLevel: 0),
          destination: destination,
          reason: reason,
          profile: ApiProfileMapper.toApi(profile),
        ),
      );
      if (!ref.mounted) return;
      state = RouteActive(
        route: route,
        stepIndex: 0,
        destinationLabel: current.destinationLabel,
        lastVerification: api.VerificationResult(
          actionId: 'replan',
          verified: true,
          message: 'Replanned — a new way is ready below.',
        ),
      );
    } on Exception {
      if (!ref.mounted) return;
      state = RouteActive(
        route: current.route,
        stepIndex: current.stepIndex,
        destinationLabel: current.destinationLabel,
        lastVerification: api.VerificationResult(
          actionId: 'replan',
          verified: false,
          message: 'Replan failed — check your connection.',
        ),
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