/// Centralized spacing scale for AccessCopilot.
///
/// Uses a 4pt base unit for consistent rhythm across the app.
/// All components should reference this scale rather than hardcoding
/// pixel values, ensuring a coherent, calm layout.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Standard horizontal screen padding.
  static const double screenPadding = xl;

  /// Minimum touch target size (accessibility requirement).
  static const double minTouchTarget = 48;
}
