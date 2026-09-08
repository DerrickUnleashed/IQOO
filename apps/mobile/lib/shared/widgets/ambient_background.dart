import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft brand-colored glow used behind hero content (home, onboarding).
/// Purely decorative — never carries information, so it is safe to
/// ignore for screen readers.
///
/// Eases in once on mount rather than pulsing forever: continuous motion
/// behind body copy reads as distracting rather than premium, and a
/// perpetual animation would never let a widget test's `pumpAndSettle`
/// complete. Deliberately does not touch text contrast: the glow sits
/// behind content at low opacity, never behind or through text itself.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            children: [
              _Blob(
                diameter: 260 + (t * 60),
                alignment: const Alignment(1.3, -1.1),
                colors: AppColors.heroGradient,
                opacity: (isDark ? 0.30 : 0.16) * t,
              ),
              _Blob(
                diameter: 280 + (t * 80),
                alignment: const Alignment(-1.3, 1.15),
                colors: AppColors.glowGradient,
                opacity: (isDark ? 0.24 : 0.12) * t,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.diameter,
    required this.alignment,
    required this.colors,
    required this.opacity,
  });

  final double diameter;
  final Alignment alignment;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colors.first.withValues(alpha: opacity),
              colors.last.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
