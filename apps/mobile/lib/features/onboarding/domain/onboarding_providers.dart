import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/accessibility_profile.dart';
import '../data/local_storage.dart';

/// Provides local persistence.
final localStorageProvider = Provider<LocalStorage>((ref) {
  return const LocalStorage();
});

/// The user's current accessibility profile.
///
/// This is the single source of truth for personalization. It starts as
/// a default profile and is hydrated from local storage on first use.
class ProfileNotifier extends Notifier<AccessibilityProfile> {
  @override
  AccessibilityProfile build() {
    final storage = ref.read(localStorageProvider);
    // Hydrate asynchronously so first build is never blocking.
    Future.microtask(() async {
      final saved = await storage.loadProfile();
      if (saved != null) {
        state = saved;
      }
    });
    return const AccessibilityProfile();
  }

  Future<void> update(AccessibilityProfile profile) async {
    state = profile;
    await ref.read(localStorageProvider).saveProfile(profile);
  }
}

final accessibilityProfileProvider =
    NotifierProvider<ProfileNotifier, AccessibilityProfile>(
      ProfileNotifier.new,
    );

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
