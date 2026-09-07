/// App-wide semantic labels for assistive technology.
///
/// Keeping these centralized ensures consistent screen-reader
/// announcements and makes the accessibility labeling easy to audit.
abstract class AppLabels {
  AppLabels._();

  static const String startAssistance = 'Start assistance';
  static const String askCopilot = 'Ask Copilot';
  static const String findAccessibleRoute = 'Find accessible route';
  static const String scanEnvironment = 'Scan environment';
  static const String holdToTalk = 'Hold to talk';
}
