import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// Converts a single camera image into a base64 JPEG payload suitable for
/// the perception endpoint's `encoded_frame` field.
///
/// Kept as a seam so tests can inject a fake producer and so the pipeline
/// never depends on native encoding specifics for its unit tests.
typedef FrameEncoder = String? Function(CameraImage image);

/// Provider exposing the frame encoder so it can be swapped in tests and
/// so the pipeline only depends on strings, not on the camera plugin.
final frameEncoderProvider = Provider<FrameEncoder>((ref) => defaultEncodeFrame);

/// The default encoder. Returns null when the image can't be encoded.
String? defaultEncodeFrame(CameraImage image) {
  try {
    final bytes = encodeCameraImage(image);
    if (bytes == null) return null;
    return base64Encode(bytes);
  } catch (_) {
    return null;
  }
}

/// Encodes a camera image plane into JPEG bytes, or null when the source
/// format is unsupported.
Uint8List? encodeCameraImage(CameraImage image) {
  final width = image.width;
  final height = image.height;

  switch (image.format.group) {
    case ImageFormatGroup.bgra8888:
      return encodeBgra(
        image.planes.first.bytes,
        width: width,
        height: height,
        stride: image.planes.first.bytesPerRow,
      );
    case ImageFormatGroup.yuv420:
      return encodeYuv420(image);
    default:
      return null;
  }
}

/// Packs an interleaved BGRA buffer into a JPEG.
Uint8List encodeBgra(
  Uint8List bytes, {
  required int width,
  required int height,
  required int stride,
}) {
  final frame = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    final row = y * stride;
    for (var x = 0; x < width; x++) {
      final i = row + x * 4;
      frame.setPixelRgba(x, y, bytes[i + 2], bytes[i + 1], bytes[i], bytes[i + 3]);
    }
  }
  return Uint8List.fromList(img.encodeJpg(frame, quality: 80));
}

/// Converts a (semi-)planar YUV420 image to JPEG. Accuracy over speed:
/// frames are throttled client-side so a naive conversion is acceptable.
Uint8List encodeYuv420(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes.length > 1 ? image.planes[1] : null;
  final vPlane = image.planes.length > 2 ? image.planes[2] : null;

  // If only a single plane exists, fall back to luma-only grayscale.
  final frame = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final luma = yPlane.bytes[y * yPlane.bytesPerRow + x];
      var u = 128;
      var v = 128;
      if (uPlane != null && vPlane != null) {
        final uvX = x >> 1;
        final uvY = y >> 1;
        u = uPlane.bytes[uvY * uPlane.bytesPerRow + uvX];
        v = vPlane.bytes[uvY * vPlane.bytesPerRow + uvX];
      }
      final r = luma + 1.402 * (v - 128);
      final g = luma - 0.344136 * (u - 128) - 0.714136 * (v - 128);
      final b = luma + 1.772 * (u - 128);
      frame.setPixelRgb(
        x,
        y,
        r.clamp(0, 255).round(),
        g.clamp(0, 255).round(),
        b.clamp(0, 255).round(),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(frame, quality: 80));
}