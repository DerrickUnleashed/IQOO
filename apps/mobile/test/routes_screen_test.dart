// Widget tests for the turn-by-turn routing screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/features/buildings/domain/buildings_providers.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';
import 'package:accesscopilot/features/routing/presentation/routes_screen.dart';

final _building = api.BuildingOut(
  id: 1,
  name: 'Central Library',
  address: '1 Main St',
  hasFloorPlan: true,
);

final _accessibilityJson = {
  'building_id': 1,
  'elevators': 2,
  'ramps': 1,
  'wheelchair_accessible_floors': [0, 1],
  'notes': ['Floor plan available'],
};

final _routeJson = {
  'route_id': 'r-1',
  'distance_m': 42.0,
  'duration_estimate_s': 120,
  'accessibility_score': 0.9,
  'steps': [
    {'instruction': 'Exit the lobby', 'action_type': 'walk', 'distance_m': 12},
    {
      'instruction': 'Take the elevator to floor 2',
      'action_type': 'elevator',
      'required_accessibility': 'elevator',
    },
  ],
};

MockClient _mock() => MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/buildings/1/accessibility')) {
        return http.Response(jsonEncode(_accessibilityJson), 200);
      }
      if (path.endsWith('/auth/session')) {
        return http.Response(jsonEncode({'session_id': 's-1'}), 200);
      }
      if (path.endsWith('/routes/calculate')) {
        return http.Response(jsonEncode(_routeJson), 200);
      }
      return http.Response('{}', 200);
    });

(ProviderContainer, MockClient) _start() {
  final mock = _mock();
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api.ApiClient(httpClient: mock))],
  );
  return (container, mock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the space prompt when nothing is selected', (tester) async {
    final (container, _) = _start();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a place first.'), findsOneWidget);
  });

  testWidgets('offers accessible-floor destinations for a selected building',
      (tester) async {
    final (container, _) = _start();
    addTearDown(container.dispose);
    container.read(buildingSelectionProvider.notifier).select(_building);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Floor 1'), findsOneWidget);
    expect(find.text('Floor 2'), findsOneWidget);
    expect(find.text('Street level'), findsOneWidget);
  });

  testWidgets('starting a route shows the first step navigator', (tester) async {
    final (container, _) = _start();
    addTearDown(container.dispose);
    container.read(buildingSelectionProvider.notifier).select(_building);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Floor 2'));
    await tester.pumpAndSettle();

    expect(find.text('Exit the lobby'), findsWidgets);
    expect(find.textContaining('Step 1 of 2'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);

    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 2 of 2'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });
}