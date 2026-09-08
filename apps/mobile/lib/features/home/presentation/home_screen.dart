import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';
import '../../demo/domain/demo_mode.dart';

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
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
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
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: AppColors.heroGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.accessible_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
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
                  if (ref.watch(demoModeProvider)) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _DemoChip(),
                  ],
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
                          accent: AppColors.accent,
                          onTap: () => context.push(AppRoute.assistance),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _HomeActionTile(
                          icon: Icons.map_outlined,
                          label: 'Find Accessible Route',
                          accent: AppColors.focus,
                          onTap: () => context.push(AppRoute.buildings),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _HomeActionTile(
                          icon: Icons.visibility_outlined,
                          label: 'Scan Environment',
                          accent: AppColors.accessible,
                          onTap: () => context.push(AppRoute.assistance),
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
        ],
      ),
    );
  }
}

/// Compact secondary action tile used under the primary CTA.
class _DemoChip extends StatelessWidget {
  const _DemoChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Demo mode is on',
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 16, color: scheme.onTertiaryContainer),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Demo mode',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
            border: isDark ? Border.all(color: scheme.outlineVariant) : null,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
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
