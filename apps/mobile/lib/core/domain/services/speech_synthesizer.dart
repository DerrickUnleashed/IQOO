import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks guidance out loud for the user.
abstract class SpeechSynthesizer {
  /// Whether speech output is available on this platform.
  bool get isAvailable;

  /// Speaks the given text, cancelling any in-flight utterance.
  Future<void> speak(String text);

  /// Stops any in-flight utterance.
  Future<void> stop();
}

/// Default synthesizer backed by the `flutter_tts` plugin.
class NativeSpeechSynthesizer implements SpeechSynthesizer {
  NativeSpeechSynthesizer();

  final FlutterTts _tts = FlutterTts();
  var _available = true;

  @override
  bool get isAvailable => _available;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.awaitSpeakCompletion(false);
      await _tts.speak(text);
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to stop; safe to ignore.
    }
  }
}

/// Fallback synthesizer for platforms without TTS — never throws.
class UnavailableSpeechSynthesizer implements SpeechSynthesizer {
  const UnavailableSpeechSynthesizer();

  @override
  bool get isAvailable => false;

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

/// Injectable provider; tests override with a fake synthesizer.
final speechSynthesizerProvider = Provider<SpeechSynthesizer>((ref) {
  return NativeSpeechSynthesizer();
});