/// A persistent, privacy-preserving app session.
///
/// The app is per-device: a stable device id is generated once and kept
/// locally, then exchanged with the backend for a session id. Both are
/// persisted so the app is usable offline and resumes a known backend
/// session when connectivity returns.
class AppSession {
  const AppSession({
    required this.deviceId,
    this.sessionId,
  });

  final String deviceId;
  final String? sessionId;

  bool get hasSession => sessionId != null && sessionId!.isNotEmpty;

  AppSession copyWith({String? deviceId, String? sessionId}) {
    return AppSession(
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'session_id': sessionId,
  };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      deviceId: (json['device_id'] as String?) ?? '',
      sessionId: json['session_id'] as String?,
    );
  }
}