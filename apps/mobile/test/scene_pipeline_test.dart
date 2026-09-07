// Tests for the live scene perception pipeline and profile-aware overlay.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/services/profile_guidance.dart';
import 'package:accesscopilot/features/assistance/domain/scene_overlay.dart';
import 'package:accesscopilot/features/assistance/domain/scene_pipeline.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

/// A camera-free scene-pipeline harness with a scripted HTTP backend.
ProviderContainer _harness({
  required Future<http.Response> Function(http.Request) handler,
}) {
  final client = api.ApiClient(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/auth/session')) {
        return http.Response(
          jsonEncode({
            'session_id': 'sess-1',
            'user_id': 1,
            'started_at': '2026-01-01T00:00:00Z',
            'status': 'active',
          }),
          200,
        );
      }
      return handler(request);
    }),
  );
  return ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
}

api.SceneUpdateResponse _sceneResponse() => api.SceneUpdateResponse(
  sessionId: 'sess-1',
  sceneObjects: [
    api.SceneObject(
      id: 'obj-1',
      type: 'staircase',
      distanceM: 2.5,
      direction: api.Direction.front,
      accessible: false,
      confidence: 0.9,
      currentlyVisible: true,
    ),
    api.SceneObject(
      id: 'obj-2',
      type: 'door',
      state: 'closed',
      accessible: null,
      confidence: 0.7,
      currentlyVisible: true,
    ),
  ],
  updatedAt: '2026-01-01T00:00:00Z',
  observationId: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ScenePipelineController', () {
    test('starts idle and survives frame ingest before attach', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(scenePipelineStateProvider),
        isA<SceneIdle>(),
      );
      final accepted = container
          .read(scenePipelineStateProvider.notifier)
          .ingestFrame('aGVsbG8=');
      expect(accepted, isTrue);
    });

    test('ingest is throttled while a request is in flight', () async {
      final container = _harness(
        handler: (request) async {
          if (request.url.path.endsWith('/perception/analyze')) {
            return http.Response(
              jsonEncode({
                'frame_id': 'f1',
                'detections': [
                  {
                    'object_type': 'person',
                    'confidence': 0.8,
                    'source': 'test',
                  },
                ],
                'processing_ms': 5,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/scene/update')) {
            return http.Response(jsonEncode(_sceneResponse().toJson()), 200);
          }
          return http.Response('{}', 200);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(scenePipelineStateProvider.notifier);

      // Wait for the session handshake so sessionId is populated.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.ingestFrame('Zmlyc3Q='), isTrue);
      // The second matches the in-flight window (throttled).
      expect(notifier.ingestFrame('c2Vjb25k'), isFalse);
    });

    test('processes a frame into a live scene', () async {
      final container = _harness(
        handler: (request) async {
          if (request.url.path.endsWith('/perception/analyze')) {
            return http.Response(
              jsonEncode({
                'frame_id': 'f1',
                'detections': [
                  {
                    'object_type': 'staircase',
                    'confidence': 0.9,
                  },
                ],
                'processing_ms': 5,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/scene/update')) {
            return http.Response(jsonEncode(_sceneResponse().toJson()), 200);
          }
          return http.Response('{}', 200);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(scenePipelineStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      notifier.ingestFrame('aGVsbG8=');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(scenePipelineStateProvider);
      expect(state, isA<SceneLive>());
      final live = state as SceneLive;
      expect(live.sceneObjects, hasLength(2));
      expect(live.sceneObjects.first.type, 'staircase');
    });

    test('degrades to SceneDegraded when the backend errors', () async {
      final container = _harness(
        handler: (request) async {
          if (request.url.path.endsWith('/perception/analyze')) {
            return http.Response('boom', 503);
          }
          return http.Response('{}', 200);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(scenePipelineStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      notifier.ingestFrame('aGVsbG8=');
      // Wait through the client's 5xx backoff retries (~200ms + 400ms)
      // before the ApiException surfaces as SceneDegraded.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final state = container.read(scenePipelineStateProvider);
      expect(state, isA<SceneDegraded>());
      expect((state as SceneDegraded).message, isNotEmpty);
    });

    test('detach stops streaming and clears the scene', () async {
      final container = _harness(
        handler: (request) async {
          if (request.url.path.endsWith('/perception/analyze')) {
            return http.Response(
              jsonEncode({'frame_id': 'f1', 'detections': [], 'processing_ms': 5}),
              200,
            );
          }
          if (request.url.path.endsWith('/scene/update')) {
            return http.Response(jsonEncode(_sceneResponse().toJson()), 200);
          }
          return http.Response('{}', 200);
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(scenePipelineStateProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      notifier.ingestFrame('aGVsbG8=');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await notifier.detach();
      expect(container.read(scenePipelineStateProvider), isA<SceneIdle>());
    });
  });

  group('presentScene (profile-aware overlay)', () {
    test('hides objects that are not currently visible', () {
      final obj = api.SceneObject(
        id: 'e1',
        type: 'staircase',
        accessible: false,
        currentlyVisible: false,
        confidence: 0.9,
      );
      final annotations = presentScene(
        objects: [obj],
        guidance: ProfileGuidance(
          profile: const AccessibilityProfile(),
        ),
      );
      expect(annotations, isEmpty);
    });

    test('marks blockages and inaccessible objects as urgent', () {
      final obj = api.SceneObject(
        id: 'e1',
        type: 'ramp',
        temporaryBlockage: true,
        currentlyVisible: true,
        confidence: 0.9,
      );
      final annotations = presentScene(
        objects: [obj],
        guidance: ProfileGuidance(profile: const AccessibilityProfile()),
      );
      expect(annotations.single.urgent, isTrue);
      expect(annotations.single.color, const Color(0xFFD32F2F));
    });
  });
}