import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../data/local_storage.dart';

/// Provider for the generated typed API client.
///
/// Injectable so tests can override the transport (MockClient) while
/// keeping the rest of the app's providers aware of the same instance.
final apiClientProvider = Provider<api.ApiClient>((ref) {
  return api.ApiClient();
});

/// Provides local persistence (shared across onboarding, profile and
/// session state so they operate on the same storage instance).
final localStorageProvider = Provider<LocalStorage>((ref) {
  return const LocalStorage();
});