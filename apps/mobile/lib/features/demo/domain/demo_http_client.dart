import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// In-memory transport that stands in for the ACCESSCOPILOT backend.
///
/// Serves realistic canned JSON for every endpoint the mobile app calls, so
/// the whole experience (buildings, routing, verification, the copilot) can
/// be explored end-to-end without a server. Responses are weighted to feel
/// like a live system rather than a static fixture.
class DemoHttpClient extends http.BaseClient {
  DemoHttpClient();

  int _routeCounter = 0;

  final _buildings = [
    {
      'id': 1,
      'name': 'Main Library',
      'address': '1 Campus Drive',
      'has_floor_plan': true,
    },
    {
      'id': 2,
      'name': 'Student Union',
      'address': '240 Student Lane',
      'has_floor_plan': true,
    },
    {
      'id': 3,
      'name': 'Science Centre',
      'address': '88 Research Way',
      'has_floor_plan': true,
    },
  ];

  final _accessibility = {
    1: {
      'building_id': 1,
      'accessible_entrances': [
        {'latitude': 51.055, 'longitude': -114.064, 'accuracy_m': 6, 'floor_level': 0},
      ],
      'elevators': 3,
      'ramps': 2,
      'wheelchair_accessible_floors': [0, 1, 2, 3],
      'notes': ['Step-free access at the north entrance.', 'Elevator B near the atrium.'],
    },
    2: {
      'building_id': 2,
      'accessible_entrances': [
        {'latitude': 51.056, 'longitude': -114.062, 'accuracy_m': 5, 'floor_level': 0},
      ],
      'elevators': 1,
      'ramps': 1,
      'wheelchair_accessible_floors': [0, 1],
      'notes': ['Main doors are automatic.'],
    },
    3: {
      'building_id': 3,
      'accessible_entrances': [
        {'latitude': 51.057, 'longitude': -114.070, 'accuracy_m': 6, 'floor_level': 0},
      ],
      'elevators': 4,
      'ramps': 3,
      'wheelchair_accessible_floors': [0, 1, 2, 3, 4],
      'notes': ['Lift lobby on the west side.'],
    },
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final path = uri.path.replaceFirst(RegExp(r'^/api/v1'), '');
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final method = request.method;

    Map<String, dynamic> body = const {};
    if (request is http.Request && request.body.isNotEmpty) {
      body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    }

    final now = DateTime.now().toUtc().toIso8601String();
    Object? payload;

    if (path == '/health') {
      payload = {'status': 'ok', 'version': 'demo'};
    } else if (path == '/readiness') {
      payload = {'ready': true, 'components': {'database': 'mock'}};
    } else if (path == '/auth/session' && method == 'POST') {
      payload = {
        'session_id': 'demo-session-1',
        'user_id': 1,
        'started_at': now,
        'status': 'active',
      };
    } else if (path == '/users/me' && method == 'GET') {
      payload = {
        'id': 1,
        'device_id': uri.queryParameters['device_id'] ?? 'demo-device',
        'created_at': now,
      };
    } else if (path == '/users/me/profile' && method == 'GET') {
      payload = {
        if (body.containsKey('mobility')) 'mobility': body['mobility'],
      };
    } else if (path == '/users/me/profile' && method == 'PUT') {
      payload = ProfileFixture.mergeDefaults(body);
    } else if (path == '/buildings' && method == 'GET') {
      payload = _buildings;
    } else if (seg.length == 2 && seg.first == 'buildings' && method == 'GET') {
      final id = int.tryParse(seg.last);
      payload = _buildings.firstWhere(
        (b) => b['id'] == id,
        orElse: () => _buildings.first,
      );
    } else if (seg.length == 3 &&
        seg.first == 'buildings' &&
        seg.last == 'accessibility' &&
        method == 'GET') {
      final id = int.tryParse(seg[1]) ?? 1;
      payload = _accessibility[id] ?? _accessibility[1];
    } else if (path == '/perception/analyze' && method == 'POST') {
      payload = {
        'frame_id': body['frame_id'] ?? 'demo-frame',
        'detections': <Object>[],
        'scene_summary': <String, dynamic>{},
        'processing_ms': 14,
      };
    } else if (path == '/scene/update' && method == 'POST') {
      payload = {
        'session_id': body['session_id'] ?? 'demo-session-1',
        'scene_objects': const [
          {
            'id': 'demo-ramp',
            'type': 'ramp',
            'distance_m': 4.0,
            'direction': 'front',
            'accessible': true,
            'confidence': 0.93,
            'currently_visible': true,
          },
          {
            'id': 'demo-elevator',
            'type': 'elevator',
            'distance_m': 12.0,
            'direction': 'left',
            'accessible': true,
            'confidence': 0.88,
          },
        ],
        'updated_at': now,
      };
    } else if ((path == '/routes/calculate' || path == '/routes/replan') &&
        method == 'POST') {
      _routeCounter++;
      final stepCount = 3;
      payload = {
        'route_id':
            path == '/routes/replan'
                ? 'demo-route-replan-${_routeCounter++}'
                : 'demo-route-${_routeCounter++}',
        'distance_m': 180.0,
        'duration_estimate_s': 210,
        'accessibility_score': 0.92,
        'cost_breakdown': {
          'steps': _stepsPayload(stepCount),
        },
        'steps': _stepsPayload(stepCount),
      };
    } else if (path == '/verification/check' && method == 'POST') {
      payload = {
        'action_id': body['action_id'] ?? 'demo-action',
        'verified': true,
        'confidence': 0.9,
        'message': 'You are on the right path.',
        'replan_required': false,
      };
    } else if (path == '/assistant/query' && method == 'POST') {
      payload = {
        'reply':
            'Take the accessible route ahead for about 20 metres, keeping the '
            'railing on your left.',
        'action': {
          'title': 'Follow the railing',
          'detail': '20 metres, straight ahead',
          'kind': 'navigate',
          'confidence': 0.91,
          'haptics': 'light',
        },
        'detections': const [
          {
            'id': 'demo-railing',
            'type': 'railing',
            'distance_m': 2.0,
            'direction': 'front',
            'confidence': 0.9,
          },
        ],
        'route_change': false,
      };
    } else if (path == '/ping') {
      payload = {'pong': now};
    } else {
      return http.StreamedResponse(
        Stream.fromIterable(
          [utf8.encode(jsonEncode({'detail': 'Unknown demo endpoint: $path'}))],
        ),
        404,
        headers: const {'content-type': 'application/json'},
      );
    }

    payload ??= <String, dynamic>{};

    return http.StreamedResponse(
      Stream.fromIterable([utf8.encode(jsonEncode(payload))]),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  List<Map<String, dynamic>> _stepsPayload(int count) {
    final steps = <Map<String, dynamic>>[
      {
        'instruction': 'Exit the entrance hall and turn right.',
        'distance_m': 25,
        'action_type': 'proceed',
        'required_accessibility': 'step_free',
        'node_id': 1,
      },
      {
        'instruction': 'Take the elevator to the third floor.',
        'distance_m': 60,
        'action_type': 'elevator',
        'required_accessibility': 'wheelchair',
        'node_id': 2,
      },
      {
        'instruction': 'Exit the elevator and walk straight to the meeting room.',
        'distance_m': 95,
        'action_type': 'proceed',
        'required_accessibility': 'step_free',
        'node_id': 3,
      },
    ];
    return steps.sublist(0, count < steps.length ? count : steps.length);
  }
}

/// Shared fixtures for profile payloads.
abstract final class ProfileFixture {
  static Map<String, dynamic> mergeDefaults(Map<String, dynamic> body) => {
    'mobility': body['mobility'],
    'vision': body['vision'],
    'hearing': body['hearing'],
    'guidance_style': body['guidance_style'],
    'walking_speed_mps': body['walking_speed_mps'] ?? 1.2,
    'max_comfortable_distance_m': body['max_comfortable_distance_m'] ?? 800,
    'cognitive_load_preference': body['cognitive_load_preference'] ?? 1,
  };
}