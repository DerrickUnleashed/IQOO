import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/domain/models/app_session.dart';
import 'app_client_providers.dart';

/// Holds the persistent app session (device id + backend session id).
///
/// On startup it hydrates from local storage, generating and persisting
/// a stable device id on first use. If a backend is reachable it then
/// exchanges the device id for a session id and stores it. Backend
/// session creation is best-effort: failures (offline / degraded) keep
/// the local session so the app still works and retries next time.
class SessionController extends Notifier<AppSession> {
  @override
  AppSession build() {
    Future.microtask(_hydrate);
    return const AppSession(deviceId: '');
  }

  Future<void> _hydrate() async {
    if (!ref.mounted) return;
    final storage = ref.read(localStorageProvider);
    var session = await storage.loadSession();
    if (!ref.mounted) return;
    if (session == null) {
      session = AppSession(deviceId: _newDeviceId());
      await storage.saveSession(session);
      if (!ref.mounted) return;
      state = session;
    } else {
      state = session;
    }
    await _ensureBackendSession();
  }

  /// Exchanges the device id for a backend session id (best-effort).
  Future<void> _ensureBackendSession() async {
    final current = state;
    if (current.deviceId.isEmpty) return;

    final client = ref.read(apiClientProvider);
    try {
      final out = await client.authSession(
        body: api.SessionCreate(deviceId: current.deviceId),
      );
      if (!ref.mounted) return;
      if (out.sessionId != current.sessionId) {
        final updated = AppSession(
          deviceId: current.deviceId,
          sessionId: out.sessionId,
        );
        state = updated;
        await ref.read(localStorageProvider).saveSession(updated);
      }
    } on Exception {
      // Offline or degraded backend: retain the local session and retry
      // on the next hydrate (app relaunch / refresh) rather than surface
      // an error the user can't act on.
    }
  }

  /// Forces a fresh backend session handshake (e.g. after login/capture).
  Future<void> refreshSession() => _ensureBackendSession();

  static String _newDeviceId() {
    final random = Random();
    final hex = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return 'dev-$hex';
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, AppSession>(SessionController.new);