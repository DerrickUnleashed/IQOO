import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/accessibility_profile.dart';
import '../../../core/domain/services/profile_guidance.dart';
import 'api_profile_mapper.dart';
import 'app_client_providers.dart';
export 'app_client_providers.dart' show localStorageProvider;
import 'session_controller.dart';

/// The user's current accessibility profile.
///
/// This is the single source of truth for personalization. It is
/// hydrated from local storage on first use, then synced to the backend
/// when a session is available.
class ProfileNotifier extends Notifier<AccessibilityProfile> {
  @override
  AccessibilityProfile build() {
    final storage = ref.read(localStorageProvider);
    // Hydrate asynchronously so first build is never blocking.
    Future.microtask(() async {
      if (!ref.mounted) return;
      final saved = await storage.loadProfile();
      if (!ref.mounted) return;
      if (saved != null) {
        state = saved;
        await _syncToBackend(saved);
      }
    });
    return const AccessibilityProfile();
  }

  Future<void> update(AccessibilityProfile profile) async {
    state = profile;
    await ref.read(localStorageProvider).saveProfile(profile);
    await _syncToBackend(profile);
  }

  Future<void> _syncToBackend(AccessibilityProfile profile) async {
    if (!ref.mounted) return;
    final session = ref.read(sessionControllerProvider);
    final deviceId = session.deviceId;
    if (deviceId.isEmpty) return;

    final client = ref.read(apiClientProvider);
    try {
      await client.updateMyProfile(
        deviceId: deviceId,
        body: ApiProfileMapper.toApiUpdate(profile),
      );
    } on Exception {
      // Offline: the local profile remains authoritative; the backend will
      // be reconciled on the next successful update.
    }
  }
}

final accessibilityProfileProvider =
    NotifierProvider<ProfileNotifier, AccessibilityProfile>(
      ProfileNotifier.new,
    );

/// Derives how guidance should be delivered for the current profile.
///
/// Consumers watch this rather than the raw profile so personalization
/// logic stays in one place (avoids scattered switches across UI).
final profileGuidanceProvider = Provider<ProfileGuidance>((ref) {
  final profile = ref.watch(accessibilityProfileProvider);
  return ProfileGuidance(profile: profile);
});

/// Whether onboarding has been completed.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final storage = ref.read(localStorageProvider);
    Future.microtask(() async {
      final completed = await storage.isOnboardingCompleted();
      if (completed && !state) {
        state = completed;
      }
    });
    return false;
  }

  Future<void> complete() async {
    state = true;
    await ref.read(localStorageProvider).setOnboardingCompleted(true);
  }

  Future<void> skip() => complete();
}

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);