#!/usr/bin/env python3
"""api-steward: generate the typed single-file Dart API client.

Reads the backend OpenAPI contract (``backend/openapi.json``, committed
as the system-of-record) and emits one self-contained Dart library:

    apps/mobile/lib/core/api/api_client.g.dart

The generated client contains:
  * strict-but-safe DTO classes that never crash on unknown fields
  * the ``Req`` wrapper (method, path, query, body, timeouts, retries,
    request-id) and a client lifecycle handling credentials, retries
    with exponential backoff, timeouts and structured errors

Regenerate after schema changes:

    python3 scripts/generate_api_client.py
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_SCHEMAS = {"HTTPValidationError", "ValidationError"}

_DART_SCALARS = {
    "string": "String",
    "number": "double",
    "integer": "int",
    "boolean": "bool",
}

_OPT_READERS = {"String": "optStr", "double": "optDouble", "int": "optInt", "bool": "optBool"}
_REQ_READERS = {"String": "reqStr", "double": "reqDouble", "int": "reqInt", "bool": "reqBool"}

_HEADER_DOC = """// GENERATED CODE - DO NOT EDIT MANUALLY.
// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps
//
// This file is produced by scripts/generate_api_client.py (api-steward)
// from backend/openapi.json. It is a typed, single-file client with a
// Req wrapper covering request lifecycle (request-id, retries with
// exponential backoff, timeouts, credentials) and strict-but-safe DTO
// parsing that never crashes on unknown or missing fields.
//
// Source contract version: {version}
"""

_IMPORTS = """import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
"""

_HELPERS = """/// Thrown for HTTP-level failures (4xx/5xx) and transport errors.
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
"""

_MANUAL_FOOTER = """// ---------------------------------------------------------------------------
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
  final R Function(Map<String, dynamic> json) parse;
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
        if (decoded is Map<String, dynamic>) {
          return req.parse(decoded);
        }
        return req.parse(const {});
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
"""

# Clean endpoint method names, keyed by (method, path). Regenerate this
# table when new endpoints are added.
_ENDPOINT_NAMES = {
    ("get", "/api/v1/health"): "health",
    ("get", "/api/v1/readiness"): "readiness",
    ("get", "/api/v1/ping"): "ping",
    ("post", "/api/v1/auth/session"): "authSession",
    ("get", "/api/v1/users/me"): "getMe",
    ("get", "/api/v1/users/me/profile"): "getMyProfile",
    ("put", "/api/v1/users/me/profile"): "updateMyProfile",
    ("get", "/api/v1/buildings/{building_id}"): "getBuilding",
    ("get", "/api/v1/buildings/{building_id}/accessibility"): "getBuildingAccessibility",
    ("post", "/api/v1/perception/analyze"): "analyzeFrame",
    ("post", "/api/v1/scene/update"): "updateScene",
    ("post", "/api/v1/routes/calculate"): "calculateRoute",
    ("post", "/api/v1/routes/replan"): "replanRoute",
    ("post", "/api/v1/verification/check"): "checkVerification",
    ("post", "/api/v1/assistant/query"): "assistantQuery",
}


def _endpoint_name(method: str, path: str) -> str:
    name = _ENDPOINT_NAMES.get((method, path))
    if name:
        return name
    # Fallback: derive from the last path segment + method.
    seg = path.rstrip("/").split("/")[-1]
    seg = re.sub(r"[{}]", "", seg)
    return f"{method}{seg.title().replace('_', '')}"


@dataclass
class FieldInfo:
    """Everything needed to render a DTO field."""

    json_key: str
    name: str  # dart field name (camelCase)
    dart_type: str  # final type used on the field
    reader: str  # expression using json['json_key'], already substituted
    to_json: str  # expression using the field reference


def _resolve(prop: dict) -> dict:
    """Resolve $ref/anyOf to a concrete OpenAPI property description."""
    if "$ref" in prop:
        ref = prop["$ref"].rsplit("/", 1)[-1]
        return {"$ref": ref}
    any_of = prop.get("anyOf")
    if any_of:
        non_null = [p for p in any_of if p.get("type") != "null"]
        if non_null:
            chosen = non_null[0]
            if "$ref" in chosen:
                return {"$ref": chosen["$ref"].rsplit("/", 1)[-1]}
            return chosen
    return prop


def _field(name: str, prop: dict, schemas: dict, required: bool) -> FieldInfo:
    dart_name = _camel(name)
    j = f"json[{name!r}]"
    prop = _resolve(prop)
    if "$ref" in prop:
        class_name = prop["$ref"]
        is_enum = schemas.get(class_name, {}).get("type") == "string"
        if is_enum:
            return FieldInfo(
                json_key=name,
                name=dart_name,
                dart_type=f"{class_name}?",
                reader=f"json[{name!r}] is String ? _read{class_name}({j}) : null",
                to_json=f"{dart_name}?.name",
            )
        if required:
            return FieldInfo(
                json_key=name,
                name=dart_name,
                dart_type=class_name,
                reader=f"parse({j}, {class_name}.fromJson)",
                to_json=f"{dart_name}.toJson()",
            )
        return FieldInfo(
            json_key=name,
            name=dart_name,
            dart_type=f"{class_name}?",
            reader=f"optParse({j}, {class_name}.fromJson)",
            to_json=f"{dart_name}?.toJson()",
        )
    if not isinstance(prop, dict):
        return FieldInfo(name, dart_name, "dynamic", j, dart_name)

    ptype = prop.get("type")
    if ptype == "array":
        item = _resolve(prop.get("items", {}))
        if "$ref" in item:
            ic = item["$ref"]
            is_enum_item = schemas.get(ic, {}).get("type") == "string"
            is_object_item = schemas.get(ic, {}).get("type") == "object"
            elem_type = ic
            if is_enum_item:
                elem_read = f"_read{ic}(e)"
                elem_write = "(e) => e.name"
            elif is_object_item:
                elem_read = f"{ic}.fromJson(optMap(e))"
                elem_write = "(e) => e.toJson()"
            else:
                elem_read = f"{ic}.parseFrom(e)"  # unresolved plain type
                elem_write = "identity"
        else:
            itype = item.get("type", "dynamic")
            elem_type = _DART_SCALARS.get(itype, "dynamic")
            if itype in _DART_SCALARS:
                # Elements inside a present list are never null; optList
                # already handles the absent-list case.
                elem_read = f"{_REQ_READERS[elem_type]}(e)"
            else:
                elem_read = "e"
            elem_write = "identity"
        base = f"List<{elem_type}>"
        empty_default = " ?? const []" if required else ""
        return FieldInfo(
            json_key=name,
            name=dart_name,
            dart_type=f"{base}?" if not required else base,
            reader=f"optList({j}, (e) => {elem_read}){empty_default}",
            to_json=(
                f"{dart_name}?.map({elem_write}).toList()"
                if not required
                else f"{dart_name}.map({elem_write}).toList()"
            ),
        )
    if ptype == "object":
        return FieldInfo(
            json_key=name,
            name=dart_name,
            dart_type="Map<String, dynamic>?",
            reader=f"optMap({j})",
            to_json=f"{dart_name}",
        )
    if ptype in _DART_SCALARS:
        base = _DART_SCALARS[ptype]
        if required:
            return FieldInfo(
                json_key=name,
                name=dart_name,
                dart_type=base,
                reader=f"{_REQ_READERS[base]}({j})",
                to_json=f"{dart_name}",
            )
        return FieldInfo(
            json_key=name,
            name=dart_name,
            dart_type=f"{base}?",
            reader=f"{_OPT_READERS[base]}({j})",
            to_json=f"{dart_name}",
        )
    return FieldInfo(name, _camel(name), "dynamic", f"json[{name!r}]", _camel(name))


def _gen_enum(values: list[str], name: str) -> str:
    lines = [f"/// {name} — generated enum.", f"enum {name} {{"]
    for v in values:
        lines.append(f"  {_safe_ident(v)},")
    lines.append("  unknown,")
    lines.append("}")
    lines.append("")
    lines.append(f"{name} _read{name}(dynamic v) {{")
    lines.append(f"  for (final e in {name}.values) {{")
    lines.append("    if (e.name == v) return e;")
    lines.append("  }")
    lines.append(f"  return {name}.unknown;")
    lines.append("}")
    return "\n".join(lines) + "\n"


def _safe_ident(v: str) -> str:
    ident = re.sub(r"[^A-Za-z0-9]", "_", v)
    if not ident or ident[0].isdigit():
        ident = f"v_{ident}"
    return ident


def _camel(name: str) -> str:
    parts = name.split("_")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def _gen_dto(name: str, sch: dict, schemas: dict) -> str:
    props = sch.get("properties", {})
    required = set(sch.get("required", []))
    fields = [
        _field(pname, prop, schemas, pname in required)
        for pname, prop in props.items()
    ]

    lines = [f"/// {name} — generated DTO (strict-but-safe parse).", f"class {name} {{"]
    params = ", ".join(
        (f"required this.{f.name}" if not f.dart_type.endswith("?") else f"this.{f.name}")
        for f in fields
    )
    lines.append(f"  {name}({{ {params} }});")
    lines.append("")
    for f in fields:
        lines.append(f"  final {f.dart_type} {f.name};")
    lines.append("")
    lines.append(f"  factory {name}.fromJson(Map<String, dynamic> json) => {name}(")
    for f in fields:
        lines.append(f"    {f.name}: {f.reader},")
    lines.append("  );")
    lines.append("")
    lines.append(f"  Map<String, dynamic> toJson() => {{")
    for f in fields:
        lines.append(f"    '{f.json_key}': {f.to_json},")
    lines.append("  };")
    lines.append("}")
    return "\n".join(lines)


def _gen_endpoint(method: str, path: str, op: dict, schemas: dict) -> str:
    path_params = re.findall(r"\{([^}]+)\}", path)
    query_params = [p for p in op.get("parameters", []) if p.get("in") == "query"]
    required_params = {
        p["name"]
        for p in op.get("parameters", [])
        if p.get("in") == "query" and p.get("required")
    }

    named_params: list[str] = []
    for pp in path_params:
        named_params.append(f"required {_query_type_name(pp)} {_camel(pp)}")
    for q in query_params:
        dart_name_q = _camel(q["name"])
        qtype = _query_type(q.get("schema", {}))
        if q["name"] in required_params:
            named_params.append(f"required {qtype} {dart_name_q}")
        else:
            named_params.append(f"{qtype}? {dart_name_q}")

    # request body
    body_type: str | None = None
    body_expr = ""
    rb = op.get("requestBody")
    if rb:
        schema = next(iter(rb.get("content", {}).values()), {}).get("schema", {})
        if schema.get("$ref"):
            body_type = schema["$ref"].rsplit("/", 1)[-1]
            named_params.append(f"required {body_type} body")
            body_expr = "body: body.toJson(),"
        else:
            named_params.append("required Map<String, dynamic> body")
            body_expr = "body: body,"

    # response type
    resp_type = "Map<String, dynamic>"
    parse = "(j) => j"
    for resp in op.get("responses", {}).values():
        schema = resp.get("content", {}).get("application/json", {}).get("schema")
        if schema and schema.get("$ref"):
            resp_type = schema["$ref"].rsplit("/", 1)[-1]
            parse = f"{resp_type}.fromJson"
            break

    # path rendering
    path_expr = path
    if path_expr.startswith("/api/v1"):
        path_expr = path_expr[len("/api/v1"):]
    for pp in path_params:
        path_expr = path_expr.replace(f"{{{pp}}}", f"${{{_camel(pp)}}}")

    # query rendering (values are strings; interpolate non-strings)
    query_expr = ""
    if query_params:
        entries = []
        for q in query_params:
            value = f"{_camel(q['name'])}"
            if _query_type(q.get("schema", {})) != "String":
                value = f"'${{{value}}}'"
            entries.append(f"'{q['name']}': {value}")
        query_expr = f"query: {{{', '.join(entries)}}},"

    args = ", ".join(named_params)
    call_sig = f"{{ {args} }}" if named_params else ""
    return f"""
  /// {method.upper()} {path}
  Future<{resp_type}> {_endpoint_name(method, path)}({call_sig}) => send(Req<{resp_type}>(
    method: '{method.upper()}',
    path: '{path_expr}',
    {body_expr}
    {query_expr}
    parse: {parse},
  ));
"""


def _query_type(schema: dict) -> str:
    return _DART_SCALARS.get(schema.get("type", "string"), "String")


def _query_type_name(name: str) -> str:
    # path params in our spec are always integer ids
    if name in {"building_id"}:
        return "int"
    return "String"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--spec", type=Path, default=ROOT / "backend/openapi.json"
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "apps/mobile/lib/core/api/api_client.g.dart",
    )
    args = parser.parse_args()

    spec = json.loads(args.spec.read_text())
    schemas = spec["components"]["schemas"]
    version = spec["info"]["version"]

    blocks: list[str] = [
        _HEADER_DOC.format(version=version).rstrip(),
        _IMPORTS.rstrip(),
        _HELPERS.rstrip(),
    ]

    # Enums are referenced by DTOs, so emit them first.
    for name, sch in schemas.items():
        if sch.get("type") == "string" and sch.get("enum"):
            blocks.append(_gen_enum(sch["enum"], name).rstrip())

    for name, sch in schemas.items():
        if name in SKIP_SCHEMAS:
            continue
        if sch.get("type") == "object":
            blocks.append(_gen_dto(name, sch, schemas))

    blocks.append(_MANUAL_FOOTER.rstrip())

    for path, ops in spec["paths"].items():
        for method, op in ops.items():
            if method not in {"get", "post", "put", "patch", "delete"}:
                continue
            blocks.append(_gen_endpoint(method, path, op, schemas))

    blocks.append("}")  # closes class ApiClient

    args.out.parent.mkdir(parents=True, exist_ok=True)
    text = "\n\n".join(b for b in blocks if b) + "\n"
    args.out.write_text(text)
    print(f"api-steward: wrote {args.out} ({text.count(chr(10))} lines)")


if __name__ == "__main__":
    main()