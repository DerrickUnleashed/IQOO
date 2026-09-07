import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../demo/domain/demo_http_client.dart';
import '../../demo/domain/demo_mode.dart';
import '../data/local_storage.dart';

/// Provider for the generated typed API client.
///
/// Injectable so tests can override the transport (MockClient) while
/// keeping the rest of the app's providers aware of the same instance.
/// When demo mode is enabled the app talks to the built-in demo server
/// instead of the live backend.
final apiClientProvider = Provider<api.ApiClient>((ref) {
  final demo = ref.watch(demoModeProvider);
  if (!demo) return api.ApiClient();
  return api.ApiClient(httpClient: DemoHttpClient());
});

/// Provides local persistence (shared across onboarding, profile and
/// session state so they operate on the same storage instance).
final localStorageProvider = Provider<LocalStorage>((ref) {
  return const LocalStorage();
});