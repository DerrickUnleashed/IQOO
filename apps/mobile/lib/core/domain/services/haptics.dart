import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Confirms a command succeeded.
abstract class Haptics {
  const Haptics();

  /// Subtle acknowledgment.
  Future<void> light();

  /// Notifies the user to act now.
  Future<void> heavy();

  /// Double-pulse: used for confirmed directions.
  Future<void> doubleTap();

  /// A sequence of strong pulses flagging danger.
  Future<void> alert();

  /// Play the haptic pattern appropriate for a named action haptic.
  Future<void> forAction(String kind) async {
    switch (kind) {
      case 'light':
        return light();
      case 'double':
        return doubleTap();
      case 'strong':
      case 'heavy':
        return heavy();
      case 'alert':
        return alert();
      default:
        throw UnsupportedError('Unknown haptic action: $kind');
    }
  }
}

class NativeHaptics extends Haptics {
  const NativeHaptics();

  @override
  Future<void> light() => HapticFeedback.lightImpact();

  @override
  Future<void> heavy() => HapticFeedback.heavyImpact();

  @override
  Future<void> doubleTap() => HapticFeedback.mediumImpact();

  @override
  Future<void> alert() => HapticFeedback.vibrate();
}

class SilentHaptics extends Haptics {
  const SilentHaptics();

  @override
  Future<void> light() async {}

  @override
  Future<void> heavy() async {}

  @override
  Future<void> doubleTap() async {}

  @override
  Future<void> alert() async {}
}

/// Injectable provider; override in tests to record pulses.
final hapticsProvider = Provider<Haptics>((ref) => const NativeHaptics());