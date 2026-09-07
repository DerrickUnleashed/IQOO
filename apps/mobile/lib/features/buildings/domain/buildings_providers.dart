// Building discovery and space selection state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../onboarding/domain/app_client_providers.dart';

/// The building currently being explored by the user.
///
/// Null until the user picks a space; drives the route planner
/// (COMMIT 18) and the space selection screen.
class BuildingSelection extends Notifier<api.BuildingOut?> {
  @override
  api.BuildingOut? build() => null;

  void select(api.BuildingOut building) => state = building;

  void clear() => state = null;
}

final buildingSelectionProvider =
    NotifierProvider<BuildingSelection, api.BuildingOut?>(
  BuildingSelection.new,
);

/// All known buildings, cached until it changes.
final buildingsProvider =
    FutureProvider.autoDispose<List<api.BuildingOut>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.listBuildings();
});

/// Profile-aware accessibility summary for a chosen building.
final buildingAccessibilityProvider = FutureProvider.autoDispose
    .family<api.BuildingAccessibilityOut, int>((ref, buildingId) async {
  final client = ref.watch(apiClientProvider);
  return client.getBuildingAccessibility(buildingId: buildingId);
});