// Unit tests for building discovery + space selection providers.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/features/buildings/domain/buildings_providers.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

void main() {
  late MockClient mock;

  ProviderContainer makeContainer() {
    final client = api.ApiClient(httpClient: mock);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('buildingsProvider lists buildings from the API', () async {
    mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/buildings');
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'name': 'Central Library',
            'address': '1 Main St',
            'has_floor_plan': true,
          },
          {
            'id': 2,
            'name': 'Museum',
            'address': '2 Main St',
            'has_floor_plan': false,
          },
        ]),
        200,
      );
    });

    final container = makeContainer();
    final buildings = await container.read(buildingsProvider.future);

    expect(buildings, hasLength(2));
    expect(buildings.first.name, 'Central Library');
    expect(buildings.first.hasFloorPlan, isTrue);
  });

  test('buildingAccessibilityProvider resolves a summary', () async {
    mock = MockClient((request) async {
      expect(request.url.path, '/api/v1/buildings/1/accessibility');
      return http.Response(
        jsonEncode({
          'building_id': 1,
          'elevators': 3,
          'ramps': 1,
          'wheelchair_accessible_floors': [0, 1],
          'notes': ['Floor plan available'],
        }),
        200,
      );
    });

    final container = makeContainer();
    final summary = await container
        .read(buildingAccessibilityProvider(1).future);

    expect(summary.elevators, 3);
    expect(summary.wheelchairAccessibleFloors, [0, 1]);
  });

  test('BuildingSelection retains and clears a chosen building', () {
    mock = MockClient((_) async => http.Response('{}', 200));
    final container = makeContainer();

    expect(container.read(buildingSelectionProvider), isNull);

    final building = api.BuildingOut(
      id: 7,
      name: 'Station',
      address: '7 Rail Way',
      hasFloorPlan: true,
    );

    container.read(buildingSelectionProvider.notifier).select(building);
    expect(container.read(buildingSelectionProvider)?.id, 7);

    container.read(buildingSelectionProvider.notifier).clear();
    expect(container.read(buildingSelectionProvider), isNull);
  });
}