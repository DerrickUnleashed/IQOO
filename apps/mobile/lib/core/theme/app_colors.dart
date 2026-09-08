import 'package:flutter/material.dart';

/// Centralized color palette for AccessCopilot.
///
/// The brand reads as a confident, modern AI copilot — a deep indigo/
/// violet identity with an electric cyan accent used for "live AI"
/// moments (listening, active reasoning). Functional accessibility
/// signals (accessible / caution / danger / info) stay in their own
/// distinct, unambiguous hues so they are never confused with brand
/// decoration. Colors never carry meaning alone (accessibility
/// requirement: no color-only indicators) — that's handled via icons
/// and labels in components.
class AppColors {
  AppColors._();

  // Brand — indigo/violet.
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryContainer = Color(0xFFE0E1FF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1E1B4B);
  static const Color primaryDark = Color(0xFF818CF8);

  // Accent — electric cyan, reserved for "live AI" moments (voice
  // listening, active reasoning glow, focus).
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentDark = Color(0xFF22D3EE);

  // Neutrals — cool, near-black/near-white rather than warm cream, for
  // a cleaner, more premium surface.
  static const Color surface = Color(0xFFFAFAFC);
  static const Color surfaceDark = Color(0xFF0B0B12);
  static const Color surfaceContainer = Color(0xFFF1F1F8);
  static const Color surfaceContainerDark = Color(0xFF16161F);
  static const Color onSurface = Color(0xFF16161D);
  static const Color onSurfaceDark = Color(0xFFE5E5F0);
  static const Color outline = Color(0xFF8A8A9A);

  // Semantic — deliberately distinct from the brand hue so accessibility
  // status is never mistaken for a decorative choice.
  static const Color accessible = Color(0xFF16A34A);
  static const Color caution = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // Focus / highlight
  static const Color focus = Color(0xFF7C3AED);
  static const Color scrim = Color(0x99000000);

  /// The primary call-to-action / hero gradient.
  static const List<Color> heroGradient = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
  ];

  /// The "live AI" gradient used for the voice button glow and active
  /// reasoning states.
  static const List<Color> glowGradient = [
    Color(0xFF22D3EE),
    Color(0xFF4F46E5),
  ];
}
