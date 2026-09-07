import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/domain/app_client_providers.dart';

/// Persistent flag that swaps the API transport for built-in demo data so
/// the app can be explored end-to-end without the backend running.
final demoModeProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

/// Owns the demo-mode flag. Hydrated asynchronously from local storage but
/// never overwrites a toggle that raced ahead of the read.
class DemoModeController extends Notifier<bool> {
  bool _usermodified = false;

  @override
  bool build() {
    final storage = ref.read(localStorageProvider);
    Future.microtask(() async {
      final enabled = await storage.isDemoModeEnabled();
      if (!ref.mounted || _usermodified) return;
      state = enabled;
    });
    return false;
  }

  Future<void> toggle() async {
    _usermodified = true;
    final next = !state;
    state = next;
    await ref.read(localStorageProvider).setDemoModeEnabled(next);
  }
}