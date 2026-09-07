// Widget tests for the buildings discovery + space selection flow.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/features/buildings/presentation/buildings_screen.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpBuildings(WidgetTester tester, {MockClient? mock}) async {
    final client = api.ApiClient(
      httpClient:
          mock ??
          MockClient((request) async {
            if (request.url.path.endsWith('/buildings')) {
              return http.Response(
                jsonEncode(const [
                  {
                    'id': 1,
                    'name': 'Central Library',
                    'address': '1 Main St',
                    'has_floor_plan': true,
                  },
                ]),
                200,
              );
            }
            return http.Response('{}', 200);
          }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: BuildingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the building list from the API', (tester) async {
    await pumpBuildings(tester);

    expect(find.text('Find a Place'), findsOneWidget);
    expect(find.text('Central Library'), findsOneWidget);
    expect(find.text('1 Main St'), findsOneWidget);
    expect(find.text('No places available yet'), findsNothing);
  });

  testWidgets('shows the empty state when no buildings exist', (tester) async {
    await pumpBuildings(
      tester,
      mock: MockClient(
        (request) async => http.Response(jsonEncode(const []), 200),
      ),
    );

    expect(find.text('No places available yet'), findsOneWidget);
  });

  testWidgets('shows an error state when the API is unreachable', (
    tester,
  ) async {
    await pumpBuildings(
      tester,
      mock: MockClient((request) async => http.Response('down', 503)),
    );

    expect(find.text('Could not reach the places service'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}