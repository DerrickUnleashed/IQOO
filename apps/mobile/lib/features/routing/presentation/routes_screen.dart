// Turn-by-turn routing UI with profile-aware cues.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';
import '../../buildings/domain/buildings_providers.dart';
import '../../guidance/domain/guidance_engine.dart';
import '../../onboarding/domain/onboarding_providers.dart';
import '../domain/route_controller.dart';
import '../domain/route_cues.dart';

/// Anyone can route once a building is selected; the screen resolves the
/// current space while the planner runs in the background.
class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeControllerProvider);
    final selection = ref.watch(buildingSelectionProvider);

    // Announce new instructions as the user advances the route.
    ref.listen(routeControllerProvider, (previous, next) {
      final guidance = ref.read(guidanceEngineProvider);
      final profile = ref.read(accessibilityProfileProvider);
      if (next is RouteActive && next.currentStep != null) {
        final changedStep = previous is! RouteActive ||
            previous.stepIndex != next.stepIndex ||
            previous.route.routeId != next.route.routeId;
        if (changedStep) {
          guidance.cueStep(next.currentStep!, profile);
        }
      }
    });

    if (selection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route')),
        body: const Center(child: Text('Select a place first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Route')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (state) {
            RouteIdle() => _DestinationPicker(building: selection),
            RouteCalculating() => const Center(
                child: CircularProgressIndicator(),
              ),
            RouteActive(:final route, :final stepIndex, :final destinationLabel, :final lastVerification) =>
              _StepNavigator(
                route: route,
                stepIndex: stepIndex,
                destination: destinationLabel ?? selection.name,
                lastVerification: lastVerification,
                onPrevious: () =>
                    ref.read(routeControllerProvider.notifier).previousStep(),
                onNext: () =>
                    ref.read(routeControllerProvider.notifier).nextStep(),
                onVerify: () =>
                    ref.read(routeControllerProvider.notifier).verifyCurrentStep(),
                onReplan: () =>
                    ref.read(routeControllerProvider.notifier).replan(
                      reason: lastVerification?.message,
                    ),
                onDone: () {
                  ref.read(routeControllerProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You have arrived.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            RouteFailed(:final reason) => _PlannerError(
                reason: reason,
                onRetry: () => ref.read(routeControllerProvider.notifier).reset(),
              ),
          },
        ),
      ),
    );
  }
}

/// Selects a destination space and starts the planner.
class _DestinationPicker extends ConsumerWidget {
  const _DestinationPicker({required this.building});

  final api.BuildingOut building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accessibility = ref.watch(buildingAccessibilityProvider(building.id));
    final summary = accessibility.value;

    final floors = summary?.wheelchairAccessibleFloors ?? const <int>[];

    return ListView(
      children: [
        Text('Routing from', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          building.name,
          style: textTheme.headlineSmall,
        ),
        if (building.address != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            building.address!,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Where to?', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (summary == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          for (final level in floors)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DestinationTile(
                icon: Icons.looks_one_rounded,
                label: 'Floor ${level + 1}',
                detail: level == 0
                    ? 'Street level'
                    : 'Wheelchair accessible',
                onTap: () => _start(ref, context, level),
              ),
            ),
          if (floors.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DestinationTile(
                icon: Icons.storefront_rounded,
                label: 'The lobby',
                detail: 'Accessible entrance',
                onTap: () => _start(ref, context, null),
              ),
            ),
        ],
      ],
    );
  }

  void _start(WidgetRef ref, BuildContext context, int? floor) {
    final controller = ref.read(routeControllerProvider.notifier);
    final destination = api.Location(
      latitude: 0,
      longitude: 0,
      floorLevel: floor,
    );
    final origin = api.Location(latitude: 0, longitude: 0, floorLevel: 0);
    controller.startRoute(
      origin: origin,
      destination: destination,
      destinationLabel: floor == null ? building.name : 'Floor ${floor + 1}',
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label, $detail',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large current instruction with a cue and step-by-step navigation.
class _StepNavigator extends ConsumerWidget {
  const _StepNavigator({
    required this.route,
    required this.stepIndex,
    required this.destination,
    required this.lastVerification,
    required this.onPrevious,
    required this.onNext,
    required this.onVerify,
    required this.onReplan,
    required this.onDone,
  });

  final api.Route route;
  final int stepIndex;
  final String destination;
  final api.VerificationResult? lastVerification;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onVerify;
  final VoidCallback onReplan;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(accessibilityProfileProvider);
    final steps = route.steps ?? const <api.RouteStep>[];
    final step = (stepIndex >= 0 && stepIndex < steps.length)
        ? steps[stepIndex]
        : null;

    if (step == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 64, color: scheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Arrived at $destination', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              onPressed: onDone,
              icon: Icons.check_rounded,
              child: const Text('Finish'),
            ),
          ],
        ),
      );
    }

    final cue = cueForStep(step, profile);
    final progress = (stepIndex + 1) / (steps.isEmpty ? 1 : steps.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Step ${stepIndex + 1} of ${steps.length} · ${formatDuration(route.durationEstimateS)}',
          style: textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('To $destination', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(cue.title, style: textTheme.headlineMedium),
        if (cue.detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            cue.detail,
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (step.distanceM != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            formatDistance(step.distanceM),
            style: textTheme.displaySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        if (lastVerification != null)
          _CheckpointBanner(
            result: lastVerification!,
            onReplan: onReplan,
          ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onVerify,
            icon: const Icon(Icons.radar_rounded),
            label: const Text('Checkpoint — am I here?'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: stepIndex == 0 ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                onPressed: onNext,
                icon: stepIndex == steps.length - 1
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
                child: Text(
                  stepIndex == steps.length - 1 ? 'Finish' : 'Next step',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < steps.length; i++)
                _StepListTile(
                  index: i,
                  step: steps[i],
                  cue: cueForStep(steps[i], profile),
                  isCurrent: i == stepIndex,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepListTile extends StatelessWidget {
  const _StepListTile({
    required this.index,
    required this.step,
    required this.cue,
    required this.isCurrent,
  });

  final int index;
  final api.RouteStep step;
  final RouteCue cue;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final iconColor = isCurrent ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                isCurrent ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            child: Text(
              '${index + 1}',
              style: textTheme.labelMedium?.copyWith(color: iconColor),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cue.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: scheme.onSurface,
                  ),
                ),
                if (cue.detail.isNotEmpty)
                  Text(
                    cue.detail,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerError extends StatelessWidget {
  const _PlannerError({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 64, color: scheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(reason,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(onPressed: onRetry, child: const Text('Back')),
        ],
      ),
    );
  }
}
/// Result banner for the closed-loop checkpoint, with a replan action
/// when the current path is blocked.
class _CheckpointBanner extends StatelessWidget {
  const _CheckpointBanner({required this.result, required this.onReplan});

  final api.VerificationResult result;
  final VoidCallback onReplan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verified = result.verified == true;
    final color = verified ? scheme.primary : scheme.errorContainer;
    final onColor = verified ? scheme.onPrimary : scheme.onErrorContainer;

    return Semantics(
      liveRegion: true,
      label: result.message ?? (verified ? 'Step verified' : 'Step blocked'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              verified ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: onColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                result.message ??
                    (verified ? 'Step verified.' : 'Step could not be verified.'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onColor,
                    ),
              ),
            ),
            if (!verified)
              TextButton(
                onPressed: onReplan,
                style: TextButton.styleFrom(foregroundColor: onColor),
                child: const Text('Replan'),
              ),
          ],
        ),
      ),
    );
  }
}
