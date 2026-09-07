// GENERATED CODE - DO NOT EDIT MANUALLY.
// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps
//
// This file is produced by scripts/generate_api_client.py (api-steward)
// from backend/openapi.json. It is a typed, single-file client with a
// Req wrapper covering request lifecycle (request-id, retries with
// exponential backoff, timeouts, credentials) and strict-but-safe DTO
// parsing that never crashes on unknown or missing fields.
//
// Source contract version: 0.1.0

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Thrown for HTTP-level failures (4xx/5xx) and transport errors.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.payload});

  final int? statusCode;
  final String message;
  final Map<String, dynamic>? payload;

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Generates a short unique request id per call.
String _uid() =>
    (DateTime.now().millisecondsSinceEpoch.toRadixString(16) +
        Random().nextInt(1 << 32).toRadixString(16));

// --- lenient readers --------------------------------------------------
// Every DTO below reads through these helpers: a mismatched or missing
// field yields null (or the provided fallback) instead of crashing, and
// unknown fields are always ignored.

String? optStr(dynamic v) => v is String ? v : null;
String reqStr(dynamic v, [String fallback = '']) => v is String ? v : fallback;
double? optDouble(dynamic v) => v is num ? v.toDouble() : null;
double reqDouble(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
int? optInt(dynamic v) => v is num ? v.toInt() : null;
int reqInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
bool? optBool(dynamic v) => v is bool ? v : null;
bool reqBool(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;
Map<String, dynamic> optMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
List<T>? optList<T>(dynamic v, T Function(dynamic) f) =>
    v is List ? v.map((e) => f(e)).toList() : null;
T? optParse<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    v is Map ? f(Map<String, dynamic>.from(v)) : null;
T parse<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    f(optMap(v));
T identity<T>(T v) => v;

/// Direction — generated enum.
enum Direction {
  front,
  left,
  right,
  behind,
  unknown,
}

Direction _readDirection(dynamic v) {
  for (final e in Direction.values) {
    if (e.name == v) return e;
  }
  return Direction.unknown;
}

/// AccessibilityProfile — generated DTO (strict-but-safe parse).
class AccessibilityProfile {
  AccessibilityProfile({ this.mobility, this.vision, this.hearing, this.guidanceStyle, this.walkingSpeedMps, this.maxComfortableDistanceM, this.cognitiveLoadPreference });

  final String? mobility;
  final String? vision;
  final String? hearing;
  final String? guidanceStyle;
  final double? walkingSpeedMps;
  final int? maxComfortableDistanceM;
  final int? cognitiveLoadPreference;

  factory AccessibilityProfile.fromJson(Map<String, dynamic> json) => AccessibilityProfile(
    mobility: optStr(json['mobility']),
    vision: optStr(json['vision']),
    hearing: optStr(json['hearing']),
    guidanceStyle: optStr(json['guidance_style']),
    walkingSpeedMps: optDouble(json['walking_speed_mps']),
    maxComfortableDistanceM: optInt(json['max_comfortable_distance_m']),
    cognitiveLoadPreference: optInt(json['cognitive_load_preference']),
  );

  Map<String, dynamic> toJson() => {
    'mobility': mobility,
    'vision': vision,
    'hearing': hearing,
    'guidance_style': guidanceStyle,
    'walking_speed_mps': walkingSpeedMps,
    'max_comfortable_distance_m': maxComfortableDistanceM,
    'cognitive_load_preference': cognitiveLoadPreference,
  };
}

/// Action — generated DTO (strict-but-safe parse).
class Action {
  Action({ required this.title, this.detail, this.kind, this.confidence, this.haptics });

  final String title;
  final String? detail;
  final String? kind;
  final double? confidence;
  final String? haptics;

  factory Action.fromJson(Map<String, dynamic> json) => Action(
    title: reqStr(json['title']),
    detail: optStr(json['detail']),
    kind: optStr(json['kind']),
    confidence: optDouble(json['confidence']),
    haptics: optStr(json['haptics']),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    'kind': kind,
    'confidence': confidence,
    'haptics': haptics,
  };
}

/// AnalyzeFrameRequest — generated DTO (strict-but-safe parse).
class AnalyzeFrameRequest {
  AnalyzeFrameRequest({ required this.frameId, required this.sessionId, this.encodedFrame, this.source });

  final String frameId;
  final String sessionId;
  final String? encodedFrame;
  final String? source;

  factory AnalyzeFrameRequest.fromJson(Map<String, dynamic> json) => AnalyzeFrameRequest(
    frameId: reqStr(json['frame_id']),
    sessionId: reqStr(json['session_id']),
    encodedFrame: optStr(json['encoded_frame']),
    source: optStr(json['source']),
  );

  Map<String, dynamic> toJson() => {
    'frame_id': frameId,
    'session_id': sessionId,
    'encoded_frame': encodedFrame,
    'source': source,
  };
}

/// AnalyzeFrameResponse — generated DTO (strict-but-safe parse).
class AnalyzeFrameResponse {
  AnalyzeFrameResponse({ required this.frameId, required this.detections, this.sceneSummary, this.processingMs });

  final String frameId;
  final List<Detection> detections;
  final Map<String, dynamic>? sceneSummary;
  final int? processingMs;

  factory AnalyzeFrameResponse.fromJson(Map<String, dynamic> json) => AnalyzeFrameResponse(
    frameId: reqStr(json['frame_id']),
    detections: optList(json['detections'], (e) => Detection.fromJson(optMap(e))) ?? const [],
    sceneSummary: optMap(json['scene_summary']),
    processingMs: optInt(json['processing_ms']),
  );

  Map<String, dynamic> toJson() => {
    'frame_id': frameId,
    'detections': detections.map((e) => e.toJson()).toList(),
    'scene_summary': sceneSummary,
    'processing_ms': processingMs,
  };
}

/// AssistantQuery — generated DTO (strict-but-safe parse).
class AssistantQuery {
  AssistantQuery({ this.sessionId, required this.text, this.intent });

  final String? sessionId;
  final String text;
  final String? intent;

  factory AssistantQuery.fromJson(Map<String, dynamic> json) => AssistantQuery(
    sessionId: optStr(json['session_id']),
    text: reqStr(json['text']),
    intent: optStr(json['intent']),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'text': text,
    'intent': intent,
  };
}

/// AssistantResponse — generated DTO (strict-but-safe parse).
class AssistantResponse {
  AssistantResponse({ required this.reply, this.action, this.detections, this.routeChange, this.debug });

  final String reply;
  final Action? action;
  final List<SceneObject>? detections;
  final bool? routeChange;
  final Map<String, dynamic>? debug;

  factory AssistantResponse.fromJson(Map<String, dynamic> json) => AssistantResponse(
    reply: reqStr(json['reply']),
    action: optParse(json['action'], Action.fromJson),
    detections: optList(json['detections'], (e) => SceneObject.fromJson(optMap(e))),
    routeChange: optBool(json['route_change']),
    debug: optMap(json['debug']),
  );

  Map<String, dynamic> toJson() => {
    'reply': reply,
    'action': action?.toJson(),
    'detections': detections?.map((e) => e.toJson()).toList(),
    'route_change': routeChange,
    'debug': debug,
  };
}

/// BuildingAccessibilityOut — generated DTO (strict-but-safe parse).
class BuildingAccessibilityOut {
  BuildingAccessibilityOut({ required this.buildingId, this.accessibleEntrances, this.elevators, this.ramps, this.wheelchairAccessibleFloors, this.notes });

  final int buildingId;
  final List<Location>? accessibleEntrances;
  final int? elevators;
  final int? ramps;
  final List<int>? wheelchairAccessibleFloors;
  final List<String>? notes;

  factory BuildingAccessibilityOut.fromJson(Map<String, dynamic> json) => BuildingAccessibilityOut(
    buildingId: reqInt(json['building_id']),
    accessibleEntrances: optList(json['accessible_entrances'], (e) => Location.fromJson(optMap(e))),
    elevators: optInt(json['elevators']),
    ramps: optInt(json['ramps']),
    wheelchairAccessibleFloors: optList(json['wheelchair_accessible_floors'], (e) => reqInt(e)),
    notes: optList(json['notes'], (e) => reqStr(e)),
  );

  Map<String, dynamic> toJson() => {
    'building_id': buildingId,
    'accessible_entrances': accessibleEntrances?.map((e) => e.toJson()).toList(),
    'elevators': elevators,
    'ramps': ramps,
    'wheelchair_accessible_floors': wheelchairAccessibleFloors?.map(identity).toList(),
    'notes': notes?.map(identity).toList(),
  };
}

/// BuildingOut — generated DTO (strict-but-safe parse).
class BuildingOut {
  BuildingOut({ required this.id, required this.name, this.address, this.hasFloorPlan });

  final int id;
  final String name;
  final String? address;
  final bool? hasFloorPlan;

  factory BuildingOut.fromJson(Map<String, dynamic> json) => BuildingOut(
    id: reqInt(json['id']),
    name: reqStr(json['name']),
    address: optStr(json['address']),
    hasFloorPlan: optBool(json['has_floor_plan']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'has_floor_plan': hasFloorPlan,
  };
}

/// Detection — generated DTO (strict-but-safe parse).
class Detection {
  Detection({ required this.objectType, required this.confidence, this.estimatedDistanceM, this.distanceConfidence, this.direction, this.bbox, this.text, this.source, this.attributes });

  final String objectType;
  final double confidence;
  final double? estimatedDistanceM;
  final double? distanceConfidence;
  final Direction? direction;
  final List<double>? bbox;
  final String? text;
  final String? source;
  final Map<String, dynamic>? attributes;

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    objectType: reqStr(json['object_type']),
    confidence: reqDouble(json['confidence']),
    estimatedDistanceM: optDouble(json['estimated_distance_m']),
    distanceConfidence: optDouble(json['distance_confidence']),
    direction: json['direction'] is String ? _readDirection(json['direction']) : null,
    bbox: optList(json['bbox'], (e) => reqDouble(e)),
    text: optStr(json['text']),
    source: optStr(json['source']),
    attributes: optMap(json['attributes']),
  );

  Map<String, dynamic> toJson() => {
    'object_type': objectType,
    'confidence': confidence,
    'estimated_distance_m': estimatedDistanceM,
    'distance_confidence': distanceConfidence,
    'direction': direction?.name,
    'bbox': bbox?.map(identity).toList(),
    'text': text,
    'source': source,
    'attributes': attributes,
  };
}

/// Location — generated DTO (strict-but-safe parse).
class Location {
  Location({ required this.latitude, required this.longitude, this.accuracyM, this.floorLevel });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final int? floorLevel;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    latitude: reqDouble(json['latitude']),
    longitude: reqDouble(json['longitude']),
    accuracyM: optDouble(json['accuracy_m']),
    floorLevel: optInt(json['floor_level']),
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy_m': accuracyM,
    'floor_level': floorLevel,
  };
}

/// ProfileUpdate — generated DTO (strict-but-safe parse).
class ProfileUpdate {
  ProfileUpdate({ this.mobility, this.vision, this.hearing, this.guidanceStyle, this.walkingSpeedMps, this.maxComfortableDistanceM, this.cognitiveLoadPreference });

  final String? mobility;
  final String? vision;
  final String? hearing;
  final String? guidanceStyle;
  final double? walkingSpeedMps;
  final int? maxComfortableDistanceM;
  final int? cognitiveLoadPreference;

  factory ProfileUpdate.fromJson(Map<String, dynamic> json) => ProfileUpdate(
    mobility: optStr(json['mobility']),
    vision: optStr(json['vision']),
    hearing: optStr(json['hearing']),
    guidanceStyle: optStr(json['guidance_style']),
    walkingSpeedMps: optDouble(json['walking_speed_mps']),
    maxComfortableDistanceM: optInt(json['max_comfortable_distance_m']),
    cognitiveLoadPreference: optInt(json['cognitive_load_preference']),
  );

  Map<String, dynamic> toJson() => {
    'mobility': mobility,
    'vision': vision,
    'hearing': hearing,
    'guidance_style': guidanceStyle,
    'walking_speed_mps': walkingSpeedMps,
    'max_comfortable_distance_m': maxComfortableDistanceM,
    'cognitive_load_preference': cognitiveLoadPreference,
  };
}

/// ReplanRequest — generated DTO (strict-but-safe parse).
class ReplanRequest {
  ReplanRequest({ required this.sessionId, required this.current, required this.destination, this.reason, this.profile });

  final String sessionId;
  final Location current;
  final Location destination;
  final String? reason;
  final AccessibilityProfile? profile;

  factory ReplanRequest.fromJson(Map<String, dynamic> json) => ReplanRequest(
    sessionId: reqStr(json['session_id']),
    current: parse(json['current'], Location.fromJson),
    destination: parse(json['destination'], Location.fromJson),
    reason: optStr(json['reason']),
    profile: optParse(json['profile'], AccessibilityProfile.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'current': current.toJson(),
    'destination': destination.toJson(),
    'reason': reason,
    'profile': profile?.toJson(),
  };
}

/// Route — generated DTO (strict-but-safe parse).
class Route {
  Route({ required this.routeId, required this.distanceM, this.durationEstimateS, this.accessibilityScore, this.steps, this.costBreakdown });

  final String routeId;
  final double distanceM;
  final int? durationEstimateS;
  final double? accessibilityScore;
  final List<RouteStep>? steps;
  final Map<String, dynamic>? costBreakdown;

  factory Route.fromJson(Map<String, dynamic> json) => Route(
    routeId: reqStr(json['route_id']),
    distanceM: reqDouble(json['distance_m']),
    durationEstimateS: optInt(json['duration_estimate_s']),
    accessibilityScore: optDouble(json['accessibility_score']),
    steps: optList(json['steps'], (e) => RouteStep.fromJson(optMap(e))),
    costBreakdown: optMap(json['cost_breakdown']),
  );

  Map<String, dynamic> toJson() => {
    'route_id': routeId,
    'distance_m': distanceM,
    'duration_estimate_s': durationEstimateS,
    'accessibility_score': accessibilityScore,
    'steps': steps?.map((e) => e.toJson()).toList(),
    'cost_breakdown': costBreakdown,
  };
}

/// RouteRequest — generated DTO (strict-but-safe parse).
class RouteRequest {
  RouteRequest({ this.sessionId, required this.origin, required this.destination, this.profile });

  final String? sessionId;
  final Location origin;
  final Location destination;
  final AccessibilityProfile? profile;

  factory RouteRequest.fromJson(Map<String, dynamic> json) => RouteRequest(
    sessionId: optStr(json['session_id']),
    origin: parse(json['origin'], Location.fromJson),
    destination: parse(json['destination'], Location.fromJson),
    profile: optParse(json['profile'], AccessibilityProfile.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'profile': profile?.toJson(),
  };
}

/// RouteStep — generated DTO (strict-but-safe parse).
class RouteStep {
  RouteStep({ required this.instruction, this.distanceM, this.actionType, this.requiredAccessibility, this.nodeId, this.attributes });

  final String instruction;
  final double? distanceM;
  final String? actionType;
  final String? requiredAccessibility;
  final int? nodeId;
  final Map<String, dynamic>? attributes;

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
    instruction: reqStr(json['instruction']),
    distanceM: optDouble(json['distance_m']),
    actionType: optStr(json['action_type']),
    requiredAccessibility: optStr(json['required_accessibility']),
    nodeId: optInt(json['node_id']),
    attributes: optMap(json['attributes']),
  );

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distance_m': distanceM,
    'action_type': actionType,
    'required_accessibility': requiredAccessibility,
    'node_id': nodeId,
    'attributes': attributes,
  };
}

/// SceneObject — generated DTO (strict-but-safe parse).
class SceneObject {
  SceneObject({ required this.id, required this.type, this.distanceM, this.direction, this.accessible, this.temporaryBlockage, this.confidence, this.currentlyVisible, this.state, this.attributes });

  final String id;
  final String type;
  final double? distanceM;
  final Direction? direction;
  final bool? accessible;
  final bool? temporaryBlockage;
  final double? confidence;
  final bool? currentlyVisible;
  final String? state;
  final Map<String, dynamic>? attributes;

  factory SceneObject.fromJson(Map<String, dynamic> json) => SceneObject(
    id: reqStr(json['id']),
    type: reqStr(json['type']),
    distanceM: optDouble(json['distance_m']),
    direction: json['direction'] is String ? _readDirection(json['direction']) : null,
    accessible: optBool(json['accessible']),
    temporaryBlockage: optBool(json['temporary_blockage']),
    confidence: optDouble(json['confidence']),
    currentlyVisible: optBool(json['currently_visible']),
    state: optStr(json['state']),
    attributes: optMap(json['attributes']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'distance_m': distanceM,
    'direction': direction?.name,
    'accessible': accessible,
    'temporary_blockage': temporaryBlockage,
    'confidence': confidence,
    'currently_visible': currentlyVisible,
    'state': state,
    'attributes': attributes,
  };
}

/// SceneUpdate — generated DTO (strict-but-safe parse).
class SceneUpdate {
  SceneUpdate({ required this.sessionId, this.detections, this.location });

  final String sessionId;
  final List<Detection>? detections;
  final Map<String, dynamic>? location;

  factory SceneUpdate.fromJson(Map<String, dynamic> json) => SceneUpdate(
    sessionId: reqStr(json['session_id']),
    detections: optList(json['detections'], (e) => Detection.fromJson(optMap(e))),
    location: optMap(json['location']),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'detections': detections?.map((e) => e.toJson()).toList(),
    'location': location,
  };
}

/// SceneUpdateResponse — generated DTO (strict-but-safe parse).
class SceneUpdateResponse {
  SceneUpdateResponse({ required this.sessionId, required this.sceneObjects, required this.updatedAt, this.observationId });

  final String sessionId;
  final List<SceneObject> sceneObjects;
  final String updatedAt;
  final int? observationId;

  factory SceneUpdateResponse.fromJson(Map<String, dynamic> json) => SceneUpdateResponse(
    sessionId: reqStr(json['session_id']),
    sceneObjects: optList(json['scene_objects'], (e) => SceneObject.fromJson(optMap(e))) ?? const [],
    updatedAt: reqStr(json['updated_at']),
    observationId: optInt(json['observation_id']),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'scene_objects': sceneObjects.map((e) => e.toJson()).toList(),
    'updated_at': updatedAt,
    'observation_id': observationId,
  };
}

/// SessionCreate — generated DTO (strict-but-safe parse).
class SessionCreate {
  SessionCreate({ required this.deviceId, this.mode });

  final String deviceId;
  final String? mode;

  factory SessionCreate.fromJson(Map<String, dynamic> json) => SessionCreate(
    deviceId: reqStr(json['device_id']),
    mode: optStr(json['mode']),
  );

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'mode': mode,
  };
}

/// SessionOut — generated DTO (strict-but-safe parse).
class SessionOut {
  SessionOut({ required this.sessionId, required this.userId, required this.startedAt, this.status });

  final String sessionId;
  final int userId;
  final String startedAt;
  final String? status;

  factory SessionOut.fromJson(Map<String, dynamic> json) => SessionOut(
    sessionId: reqStr(json['session_id']),
    userId: reqInt(json['user_id']),
    startedAt: reqStr(json['started_at']),
    status: optStr(json['status']),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'user_id': userId,
    'started_at': startedAt,
    'status': status,
  };
}

/// UserOut — generated DTO (strict-but-safe parse).
class UserOut {
  UserOut({ required this.id, required this.deviceId, required this.createdAt });

  final int id;
  final String deviceId;
  final String createdAt;

  factory UserOut.fromJson(Map<String, dynamic> json) => UserOut(
    id: reqInt(json['id']),
    deviceId: reqStr(json['device_id']),
    createdAt: reqStr(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    'created_at': createdAt,
  };
}

/// VerificationRequest — generated DTO (strict-but-safe parse).
class VerificationRequest {
  VerificationRequest({ required this.sessionId, required this.actionId, this.sceneObjects });

  final String sessionId;
  final String actionId;
  final List<SceneObject>? sceneObjects;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) => VerificationRequest(
    sessionId: reqStr(json['session_id']),
    actionId: reqStr(json['action_id']),
    sceneObjects: optList(json['scene_objects'], (e) => SceneObject.fromJson(optMap(e))),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'action_id': actionId,
    'scene_objects': sceneObjects?.map((e) => e.toJson()).toList(),
  };
}

/// VerificationResult — generated DTO (strict-but-safe parse).
class VerificationResult {
  VerificationResult({ required this.actionId, required this.verified, this.confidence, this.message, this.replanRequired });

  final String actionId;
  final bool verified;
  final double? confidence;
  final String? message;
  final bool? replanRequired;

  factory VerificationResult.fromJson(Map<String, dynamic> json) => VerificationResult(
    actionId: reqStr(json['action_id']),
    verified: reqBool(json['verified']),
    confidence: optDouble(json['confidence']),
    message: optStr(json['message']),
    replanRequired: optBool(json['replan_required']),
  );

  Map<String, dynamic> toJson() => {
    'action_id': actionId,
    'verified': verified,
    'confidence': confidence,
    'message': message,
    'replan_required': replanRequired,
  };
}

// ---------------------------------------------------------------------------
// Request lifecycle wrapper.
//
// A Req fully describes one API call. ApiClient.send executes that Req
// with the full lifecycle: request-id stamping, credential injection,
// per-request timeout, and bounded retries with exponential backoff.
// ---------------------------------------------------------------------------

/// One described request; created by the generated endpoint methods below.
class Req<R> {
  const Req({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    required this.parse,
  });

  final String method;
  final String path;
  final Map<String, String>? query;
  final Object? body;
  final Duration timeout;
  final int maxRetries;

  /// Strict-but-safe parse of the JSON response body.
  final R Function(dynamic json) parse;
}

/// Typed API client: credentials, retries with backoff, timeouts and
/// request-id correlation bundled into a single request lifecycle.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.apiToken,
  })  : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'ACCESSCOPILOT_API_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  final http.Client _http;
  final String baseUrl;

  /// Bearer credential; injected on every request when set.
  String? apiToken;

  Future<R> send<R>(Req<R> req) async {
    final requestId = _uid();
    late http.Response response;
    var lastError = '';

    for (var attempt = 0; attempt <= req.maxRetries; attempt++) {
      var uri = Uri.parse('$baseUrl${req.path}');
      final query = req.query;
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }
      final request = http.Request(req.method, uri);
      request.headers['X-Request-Id'] = requestId;
      request.headers['Accept'] = 'application/json';
      if (apiToken != null && apiToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $apiToken';
      }
      if (req.body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(req.body);
      }

      try {
        final streamed = await _http.send(request).timeout(req.timeout);
        response = await http.Response.fromStream(streamed);
      } on TimeoutException {
        lastError = 'request timed out after ${req.timeout.inMilliseconds}ms';
        if (attempt < req.maxRetries) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        throw ApiException(null, lastError);
      } catch (e) {
        lastError = 'network error: $e';
        if (attempt < req.maxRetries) {
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        throw ApiException(null, lastError);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = _decodeBody(response.body);
        return req.parse(decoded);
      }

      final isRetryable = response.statusCode >= 500;
      if (isRetryable && attempt < req.maxRetries) {
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }
      final payload = _decodeBody(response.body);
      throw ApiException(
        response.statusCode,
        'request failed: ${response.statusCode} ${response.reasonPhrase}',
        payload: payload is Map<String, dynamic> ? payload : null,
      );
    }
    throw ApiException(null, lastError);
  }

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 200 * pow(2, attempt).toInt());

  static dynamic _decodeBody(String body) {
    if (body.isEmpty) return const {};
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  // ---------------------------------------------------------------
  // Endpoints (generated from the OpenAPI operations).
  // ---------------------------------------------------------------


  /// GET /api/v1/health
  Future<Map<String, dynamic>> health() => send(Req<Map<String, dynamic>>(
    method: 'GET',
    path: '/health',
    
    
    parse: (j) => j,
  ));



  /// GET /api/v1/readiness
  Future<Map<String, dynamic>> readiness() => send(Req<Map<String, dynamic>>(
    method: 'GET',
    path: '/readiness',
    
    
    parse: (j) => j,
  ));



  /// POST /api/v1/auth/session
  Future<SessionOut> authSession({ required SessionCreate body }) => send(Req<SessionOut>(
    method: 'POST',
    path: '/auth/session',
    body: body.toJson(),
    
    parse: (j) => SessionOut.fromJson(j as Map<String, dynamic>),
  ));



  /// GET /api/v1/users/me
  Future<UserOut> getMe({ required String deviceId }) => send(Req<UserOut>(
    method: 'GET',
    path: '/users/me',
    
    query: {'device_id': deviceId},
    parse: (j) => UserOut.fromJson(j as Map<String, dynamic>),
  ));



  /// GET /api/v1/users/me/profile
  Future<AccessibilityProfile> getMyProfile({ required String deviceId }) => send(Req<AccessibilityProfile>(
    method: 'GET',
    path: '/users/me/profile',
    
    query: {'device_id': deviceId},
    parse: (j) => AccessibilityProfile.fromJson(j as Map<String, dynamic>),
  ));



  /// PUT /api/v1/users/me/profile
  Future<AccessibilityProfile> updateMyProfile({ required String deviceId, required ProfileUpdate body }) => send(Req<AccessibilityProfile>(
    method: 'PUT',
    path: '/users/me/profile',
    body: body.toJson(),
    query: {'device_id': deviceId},
    parse: (j) => AccessibilityProfile.fromJson(j as Map<String, dynamic>),
  ));



  /// GET /api/v1/buildings
  Future<List<BuildingOut>> listBuildings() => send(Req<List<BuildingOut>>(
    method: 'GET',
    path: '/buildings',
    
    
    parse: (j) => (j as List).map((e) => BuildingOut.fromJson(e as Map<String, dynamic>)).toList(),
  ));



  /// GET /api/v1/buildings/{building_id}
  Future<BuildingOut> getBuilding({ required int buildingId }) => send(Req<BuildingOut>(
    method: 'GET',
    path: '/buildings/${buildingId}',
    
    
    parse: (j) => BuildingOut.fromJson(j as Map<String, dynamic>),
  ));



  /// GET /api/v1/buildings/{building_id}/accessibility
  Future<BuildingAccessibilityOut> getBuildingAccessibility({ required int buildingId }) => send(Req<BuildingAccessibilityOut>(
    method: 'GET',
    path: '/buildings/${buildingId}/accessibility',
    
    
    parse: (j) => BuildingAccessibilityOut.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/perception/analyze
  Future<AnalyzeFrameResponse> analyzeFrame({ required AnalyzeFrameRequest body }) => send(Req<AnalyzeFrameResponse>(
    method: 'POST',
    path: '/perception/analyze',
    body: body.toJson(),
    
    parse: (j) => AnalyzeFrameResponse.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/scene/update
  Future<SceneUpdateResponse> updateScene({ required SceneUpdate body }) => send(Req<SceneUpdateResponse>(
    method: 'POST',
    path: '/scene/update',
    body: body.toJson(),
    
    parse: (j) => SceneUpdateResponse.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/routes/calculate
  Future<Route> calculateRoute({ required RouteRequest body }) => send(Req<Route>(
    method: 'POST',
    path: '/routes/calculate',
    body: body.toJson(),
    
    parse: (j) => Route.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/routes/replan
  Future<Route> replanRoute({ required ReplanRequest body }) => send(Req<Route>(
    method: 'POST',
    path: '/routes/replan',
    body: body.toJson(),
    
    parse: (j) => Route.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/verification/check
  Future<VerificationResult> checkVerification({ required VerificationRequest body }) => send(Req<VerificationResult>(
    method: 'POST',
    path: '/verification/check',
    body: body.toJson(),
    
    parse: (j) => VerificationResult.fromJson(j as Map<String, dynamic>),
  ));



  /// POST /api/v1/assistant/query
  Future<AssistantResponse> assistantQuery({ required AssistantQuery body }) => send(Req<AssistantResponse>(
    method: 'POST',
    path: '/assistant/query',
    body: body.toJson(),
    
    parse: (j) => AssistantResponse.fromJson(j as Map<String, dynamic>),
  ));



  /// GET /api/v1/ping
  Future<Map<String, dynamic>> ping() => send(Req<Map<String, dynamic>>(
    method: 'GET',
    path: '/ping',
    
    
    parse: (j) => j,
  ));


}
