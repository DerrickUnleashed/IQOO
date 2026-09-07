import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';

/// The assistant home screen.
///
/// Immediately communicates the product purpose with a time-aware
/// greeting and a single dominant action ("Start assistance"), plus
/// three secondary actions and a persistent voice entry point.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.accessible_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.go(AppRoute.profile),
                    tooltip: 'Profile',
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text(_greeting(), style: textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'How can I help you navigate?',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Primary call to action.
              PrimaryButton(
                onPressed: () => context.push(AppRoute.assistance),
                icon: Icons.play_arrow_rounded,
                child: const Text('Start Assistance'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Secondary actions.
              Row(
                children: [
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Ask Copilot',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.map_outlined,
                      label: 'Find Accessible Route',
                      onTap: () => context.push(AppRoute.buildings),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _HomeActionTile(
                      icon: Icons.visibility_outlined,
                      label: 'Scan Environment',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Persistent voice entry.
              Center(
                child: Semantics(
                  label: 'Hold to talk to your accessibility copilot',
                  child: VoiceButton(
                    onPressed: () => context.push(AppRoute.assistance),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  'Hold to talk',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact secondary action tile used under the primary CTA.
class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
