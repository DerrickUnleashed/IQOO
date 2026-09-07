import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;

void main() {
  group('strict DTO parsing', () {
    test('never crashes on unknown or missing fields', () {
      final detection = api.Detection.fromJson(const {
        'object_type': 'door',
        'confidence': 'not-a-number', // hostile value
        'mystery_field': [1, 2, 3], // unknown key
        'extra': null,
      });
      expect(detection.objectType, 'door');
      expect(detection.confidence, 0); // coerced, not thrown
      expect(detection.estimatedDistanceM, isNull);
    });

    test('parses nested objects and direction enum', () {
      final scene = api.AssistantResponse.fromJson(const {
        'reply': 'Approaching the door',
        'action': {
          'title': 'Open the door',
          'confidence': 0.82,
          'haptics': 'double',
        },
        'route_change': true,
      });
      expect(scene.reply, 'Approaching the door');
      expect(scene.action!.title, 'Open the door');
      expect(scene.action!.haptics, 'double');
      expect(scene.routeChange, isTrue);
    });

    test('direction enum defaults to unknown for bad values', () {
      final wrong = api.SceneObject.fromJson(const {'id': 'x', 'type': 'door', 'direction': 'sideways'});
      expect(wrong.direction, api.Direction.unknown);
      final ok = api.SceneObject.fromJson(const {'id': 'x', 'type': 'door', 'direction': 'left'});
      expect(ok.direction, api.Direction.left);
    });

    test('toJson round-trips the wire shape', () {
      final route = api.Route(
        routeId: 'r1',
        distanceM: 12.5,
        accessibilityScore: 0.9,
        steps: [
          api.RouteStep(
            instruction: 'turn left',
            distanceM: 3,
            actionType: 'walk',
          ),
        ],
      );
      final decoded = jsonDecode(jsonEncode(route.toJson())) as Map<String, dynamic>;
      expect(decoded['route_id'], 'r1');
      expect(decoded['distance_m'], 12.5);
      final step = decoded['steps'] as List;
      expect((step.first as Map)['instruction'], 'turn left');
    });
  });

  group('request lifecycle', () {
    test('stamps X-Request-Id and Authorization on every call', () async {
      late http.Request captured;
      final client = api.ApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'session_id': 's1',
              'user_id': 7,
              'started_at': '2026-01-01T00:00:00Z',
              'status': 'active',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        apiToken: 'tok-123',
      );

      await client.authSession(body: api.SessionCreate(deviceId: 'device-a'));

      expect(captured.headers['X-Request-Id'], isNotEmpty);
      expect(captured.headers['Authorization'], 'Bearer tok-123');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/v1/auth/session');
    });

    test('retries 5xx with exponential backoff before succeeding', () async {
      var calls = 0;
      final client = api.ApiClient(
        httpClient: MockClient((request) async {
          calls += 1;
          if (calls < 3) {
            return http.Response('boom', 503);
          }
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'accesscopilot'}),
            200,
          );
        }),
      );

      final sw = Stopwatch()..start();
      final result = await client.health();
      sw.stop();

      expect(calls, 3);
      expect(result['status'], 'ok');
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(200 + 400));
    });

    test('times out instead of hanging', () async {
      final client = api.ApiClient(
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.send(
          api.Req<String>(
            method: 'GET',
            path: '/slow',
            timeout: const Duration(milliseconds: 50),
            maxRetries: 0,
            parse: (j) => 'x',
          ),
        ),
        throwsA(isA<api.ApiException>()),
      );
    });

    test('rejects 4xx without retry', () async {
      var calls = 0;
      final client = api.ApiClient(
        httpClient: MockClient((request) async {
          calls += 1;
          return http.Response('{"detail":"nope"}', 422);
        }),
      );

      await expectLater(
        client.checkVerification(
          body: api.VerificationRequest(
            sessionId: 's1',
            actionId: 'a1',
            sceneObjects: [],
          ),
        ),
        throwsA(
          isA<api.ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
      expect(calls, 1); // no retry on 4xx
    });
  });

  group('apiToken evidence', () {
    test('session token enables auth header injection', () {
      final client = api.ApiClient();
      expect(client.apiToken, isNull);
      client.apiToken = 'abc';
      expect(client.apiToken, 'abc');
    });
  });
}