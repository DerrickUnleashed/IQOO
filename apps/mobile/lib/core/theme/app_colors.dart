import 'package:flutter/material.dart';

/// Centralized color palette for AccessCopilot.
///
/// The brand is built around a calm, accessible green that signals
/// safety and confidence, paired with warm neutral surfaces and a
/// strong, high-contrast accent for focus. Colors never carry meaning
/// alone (accessibility requirement: no color-only indicators), which
/// is handled in components via icons and labels.
class AppColors {
  AppColors._();

  // Brand greens
  static const Color primary = Color(0xFF1B5E2A);
  static const Color primaryContainer = Color(0xFFA8E0B3);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF003911);
  static const Color primaryDark = Color(0xFF43924E);

  // Neutrals
  static const Color surface = Color(0xFFFDFBF8);
  static const Color surfaceDark = Color(0xFF121417);
  static const Color surfaceContainer = Color(0xFFF3EEE9);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color outline = Color(0xFF74777F);

  // Semantic
  static const Color accessible = Color(0xFF2E7D32);
  static const Color caution = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // Focus / highlight
  static const Color focus = Color(0xFF6200EE);
  static const Color scrim = Color(0x99000000);
}
