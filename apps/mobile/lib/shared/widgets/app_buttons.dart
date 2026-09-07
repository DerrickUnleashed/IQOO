import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Primary call-to-action button. High contrast, generous target size.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final label = FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: label) : label;
  }
}

/// Secondary action button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Large circular button used for voice interaction.
class VoiceButton extends StatelessWidget {
  const VoiceButton({
    super.key,
    required this.onPressed,
    this.listening = false,
    this.onLongPress,
    this.isHolding = false,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool listening;
  final bool isHolding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: listening ? 'Listening, release when finished' : 'Hold to talk',
      child: GestureDetector(
        onTap: onPressed,
        onLongPressStart: onLongPress == null
            ? null
            : (_) => onLongPress?.call(),
        onLongPressEnd: isHolding ? (_) {} : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? colorScheme.primary : Colors.white,
            border: Border.all(color: colorScheme.primary, width: 3),
            boxShadow: listening
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            listening ? Icons.graphic_eq : Icons.mic,
            size: 36,
            color: listening ? colorScheme.onPrimary : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Badge indicating accessibility status of a detected object or route.
///
/// Uses icon + label + color (never color alone) so that the meaning
/// survives grayscale and screen readers.
class AccessibilityBadge extends StatelessWidget {
  const AccessibilityBadge({
    super.key,
    required this.label,
    this.status = AccessibilityStatus.neutral,
  });

  final String label;
  final AccessibilityStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      AccessibilityStatus.accessible => (
        Icons.check_circle,
        AppColors.accessible,
      ),
      AccessibilityStatus.inaccessible => (Icons.cancel, AppColors.danger),
      AccessibilityStatus.warning => (
        Icons.warning_amber_rounded,
        AppColors.caution,
      ),
      AccessibilityStatus.neutral => (Icons.help_outline, AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

enum AccessibilityStatus { accessible, inaccessible, warning, neutral }

/// Confidence indicator that conveys confidence without relying on
/// color alone. Shows a percentage and a proportional bar.
class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.compact = false,
  });

  final double confidence; // 0..1

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence.clamp(0.0, 1.0) * 100).round();
    final level = switch (pct) {
      >= 80 => 'High',
      >= 50 => 'Medium',
      _ => 'Low',
    };

    return Semantics(
      label: 'Confidence $level, $pct percent',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(level, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: AppSpacing.xs),
                Text('$pct%', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          Container(
            width: compact ? 40 : 80,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: confidence.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status pill for live session state (Listening, Connected, etc.).
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.label,
    this.active = false,
    this.icon,
  });

  final String label;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.accessible
        : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
