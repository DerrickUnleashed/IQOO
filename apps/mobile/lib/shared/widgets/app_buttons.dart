import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Primary call-to-action button. High contrast, generous target size.
///
/// Renders as a brand-gradient pill with a soft matching shadow — the
/// tap target is a real [FilledButton] filling the gradient surface, so
/// sizing, semantics and hit-testing all behave exactly as a stock
/// FilledButton would.
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
    final enabled = onPressed != null;

    final label = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: enabled
            ? const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: enabled ? null : Theme.of(context).disabledColor.withValues(alpha: 0.12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        ),
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
///
/// Glows with a cyan/indigo accent to read as "an AI is present here",
/// not just a static mic icon. It breathes with a continuous pulse only
/// while [listening] is true — that is the one state where perpetual
/// motion is actually meaningful ("I'm actively hearing you"). At rest
/// it stays visually calm rather than animating forever, which keeps
/// the button from being a distraction and lets it settle for tests.
class VoiceButton extends StatefulWidget {
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
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  bool get _shouldAnimate =>
      widget.listening &&
      !WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (_shouldAnimate) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_shouldAnimate && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.listening
          ? 'Listening, release when finished'
          : 'Hold to talk',
      child: GestureDetector(
        onTap: widget.onPressed,
        onLongPressStart: widget.onLongPress == null
            ? null
            : (_) => widget.onLongPress?.call(),
        onLongPressEnd: widget.isHolding ? (_) {} : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final glowStrength = widget.listening ? 0.55 : 0.22;
            final glowBlur = widget.listening ? 28.0 : 18.0;
            final scale = 1.0 + (t * (widget.listening ? 0.05 : 0.0));

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.listening
                      ? const LinearGradient(
                          colors: AppColors.glowGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.listening ? null : colorScheme.surface,
                  border: widget.listening
                      ? null
                      : Border.all(color: AppColors.accent, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(
                        alpha: glowStrength * (0.75 + t * 0.5),
                      ),
                      blurRadius: glowBlur,
                      spreadRadius: widget.listening ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.listening ? Icons.graphic_eq : Icons.mic_rounded,
                  size: 36,
                  color: widget.listening ? Colors.white : AppColors.accent,
                ),
              ),
            );
          },
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
        border: Border.all(color: color.withValues(alpha: 0.28)),
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
                  gradient: const LinearGradient(colors: AppColors.glowGradient),
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
