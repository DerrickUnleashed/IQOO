// Tests for demo mode: the built-in transport and provider wiring.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/features/demo/domain/demo_http_client.dart';
import 'package:accesscopilot/features/demo/domain/demo_mode.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';
import 'package:accesscopilot/features/onboarding/data/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('demo transport serves buildings, details and accessibility', () async {
    final client = http.Client();
    final transport = DemoHttpClient();

    final buildings =
        await api.ApiClient(httpClient: transport).listBuildings();
    expect(buildings, hasLength(3));
    expect(buildings.first.name, isNotEmpty);

    final pickedId = buildings.first.id;
    final detail = await api.ApiClient(httpClient: transport)
        .getBuilding(buildingId: pickedId);
    expect(detail.id, pickedId);

    final accessibility = await api.ApiClient(httpClient: transport)
        .getBuildingAccessibility(buildingId: pickedId);
    expect(accessibility.wheelchairAccessibleFloors, isNotEmpty);
    expect(accessibility.elevators, greaterThan(0));

    client.close();
  });

  test('demo transport supports routing and verification', () async {
    final apiClient = api.ApiClient(httpClient: DemoHttpClient());

    final route = await apiClient.calculateRoute(
      body: api.RouteRequest(
        sessionId: 'demo-session-1',
        origin: api.Location(latitude: 51.055, longitude: -114.064),
        destination: api.Location(latitude: 51.057, longitude: -114.070),
      ),
    );
    expect(route.routeId, startsWith('demo-route-'));
    expect(route.steps, isNotNull);
    expect(route.steps, isNotEmpty);

    final verification = await apiClient.checkVerification(
      body: api.VerificationRequest(
        sessionId: 'demo-session-1',
        actionId: route.steps!.first.actionType ?? 'proceed',
        sceneObjects: route.steps!.map(_sceneOf).toList(),
      ),
    );
    expect(verification.verified, isTrue);
    expect(verification.replanRequired, isFalse);
  });

  test('demo transport answers the copilot', () async {
    final apiClient = api.ApiClient(httpClient: DemoHttpClient());

    final response = await apiClient.assistantQuery(
      body: api.AssistantQuery(sessionId: 'demo-session-1', text: 'next step'),
    );
    expect(response.reply, contains('railing'));
    expect(response.action, isNotNull);
  });

  test('demo mode persists its flag and rebuilds the api client', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(demoModeProvider), isFalse);

    await container.read(demoModeProvider.notifier).toggle();
    expect(container.read(demoModeProvider), isTrue);

    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool(StorageKeys.demoMode), isTrue);

    await container.read(demoModeProvider.notifier).toggle();
    expect(container.read(demoModeProvider), isFalse);
  });

  test('api client uses the demo transport while demo mode is on', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final real = container.read(apiClientProvider);
    expect(real.baseUrl, isNotNull);

    await container.read(demoModeProvider.notifier).toggle();
    final demo = container.read(apiClientProvider);
    expect(demo, isA<api.ApiClient>());

    final buildings = await demo.listBuildings();
    expect(buildings, isNotEmpty);
    expect(buildings.first.name, 'Main Library');
  });
}

api.SceneObject _sceneOf(api.RouteStep step) => api.SceneObject(
      id: 'obj-${step.nodeId}',
      type: step.requiredAccessibility ?? 'landmark',
      distanceM: step.distanceM,
    );