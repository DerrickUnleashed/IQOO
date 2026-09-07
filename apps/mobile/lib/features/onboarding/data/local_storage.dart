import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/models/accessibility_profile.dart';
import '../../../core/domain/models/app_session.dart';

/// Persistence keys used for local storage.
abstract class StorageKeys {
  StorageKeys._();

  static const onboardingCompleted = 'onboarding_completed';
  static const accessibilityProfile = 'accessibility_profile';
  static const appSession = 'app_session';
  static const eventQueue = 'event_queue';
  static const demoMode = 'demo_mode';
}

/// Local persistence layer for the user profile and onboarding state.
class LocalStorage {
  const LocalStorage();

  /// Returns whether the user has completed onboarding.
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.onboardingCompleted, completed);
  }

  Future<void> saveProfile(AccessibilityProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.accessibilityProfile,
      jsonEncode(profile.toJson()),
    );
  }

  Future<AccessibilityProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.accessibilityProfile);
    if (raw == null) return null;
    try {
      return AccessibilityProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AppSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.appSession,
      jsonEncode(session.toJson()),
    );
  }

  Future<AppSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.appSession);
    if (raw == null) return null;
    try {
      return AppSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Persists the pending offline event queue (JSON lines).
  Future<void> saveEventQueue(List<String> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(StorageKeys.eventQueue, events);
  }

  Future<List<String>> loadEventQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(StorageKeys.eventQueue) ?? const [];
    return List<String>.from(raw);
  }

  /// Whether built-in demo data is used instead of the live backend.
  Future<bool> isDemoModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.demoMode) ?? false;
  }

  Future<void> setDemoModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.demoMode, enabled);
  }
}
