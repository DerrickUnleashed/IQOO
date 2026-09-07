// Building discovery and space selection flow.
//
// Lets the user find a building, its accessibility summary, and pick a
// space (floor) before starting turn-by-turn assistance (COMMIT 18).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';
import '../domain/buildings_providers.dart';

/// Discovers buildings and opens the space selection for one of them.
class BuildingsScreen extends ConsumerWidget {
  const BuildingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final buildings = ref.watch(buildingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a Place')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: buildings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(onRetry: () {
              ref.invalidate(buildingsProvider);
            }),
            data: (items) => items.isEmpty
                ? _EmptyState(retry: () => ref.invalidate(buildingsProvider))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final building = items[index];
                      return _BuildingCard(
                        building: building,
                        scheme: scheme,
                        textTheme: textTheme,
                        onTap: () => context.push(
                          '${AppRoute.buildings}/${building.id}',
                          extra: building,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shows one building's accessibility details and lets the user select
/// a space (floor) to route from.
class BuildingDetailScreen extends ConsumerWidget {
  const BuildingDetailScreen({super.key, this.building});

  /// The building passed via the navigation extra; falls back to the
  /// current selection so deep links still resolve.
  final api.BuildingOut? building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final building =
        this.building ?? ref.watch(buildingSelectionProvider);

    final details =
        building == null ? null : ref.watch(buildingAccessibilityProvider(building.id));

    return Scaffold(
      appBar: AppBar(title: Text(building?.name ?? 'Space')),
      body: SafeArea(
        child: details == null || building == null
            ? const Center(child: CircularProgressIndicator())
            : details.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => const _ErrorState(),
                data: (summary) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Text(building.name, style: textTheme.headlineMedium),
                    if (building.address != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(building.address!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        _Stat(icon: Icons.elevator_rounded,
                            value: '${summary.elevators ?? 0}',
                            label: 'Elevators'),
                        const SizedBox(width: AppSpacing.md),
                        _Stat(icon: Icons.ramp_left_rounded,
                            value: '${summary.ramps ?? 0}',
                            label: 'Ramps'),
                        const SizedBox(width: AppSpacing.md),
                        _Stat(
                            icon: Icons.accessible_rounded,
                            value:
                                '${(summary.wheelchairAccessibleFloors ?? []).length}',
                            label: 'A11y floors'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Choose your space', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    for (final note in summary.notes ?? const <String>[])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(note)),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      onPressed: () {
                        ref.read(buildingSelectionProvider.notifier).select(building);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${building.name} selected — route to it next'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: Icons.check_rounded,
                      child: const Text('Select This Place'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.building,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final api.BuildingOut building;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${building.name}, ${building.address ?? 'no address'}',
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
              Icon(Icons.apartment_rounded, size: 32, color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(building.name, style: textTheme.titleMedium),
                    if (building.address != null)
                      Text(building.address!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.retry});

  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: AppSpacing.lg),
          Text('No places available yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: retry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: AppSpacing.lg),
          Text('Could not reach the places service',
              style: Theme.of(context).textTheme.titleMedium),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}