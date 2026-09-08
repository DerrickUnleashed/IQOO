import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The most important element in the app: tells the user what to do next.
///
/// Always answers the question "What do I do now?" with a single,
/// prioritized action. Uses a leading icon, a bold action phrase, and
/// a supporting detail line.
class InstructionCard extends StatelessWidget {
  const InstructionCard({
    super.key,
    required this.action,
    this.actionIcon,
    this.detail,
    this.tone = InstructionTone.info,
  });

  final String action;
  final IconData? actionIcon;
  final String? detail;
  final InstructionTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      InstructionTone.info => const Color(0xFF0EA5E9),
      InstructionTone.success => const Color(0xFF16A34A),
      InstructionTone.warning => const Color(0xFFDC2626),
      InstructionTone.neutral => Theme.of(context).colorScheme.onSurface,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.18)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              actionIcon ?? Icons.navigation_outlined,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT ACTION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  action,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (detail != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(detail!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum InstructionTone { info, success, warning, neutral }

/// Displays the current navigation destination and progress.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    this.distanceMeters,
    this.onTap,
  });

  final String destination;
  final int? distanceMeters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 32),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESTINATION',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      destination,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (distanceMeters != null)
                Text(
                  '$distanceMeters m',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
