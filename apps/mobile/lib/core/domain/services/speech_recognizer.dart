import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lifecycle status of speech recognition.
enum SpeechStatus { idle, initializing, listening, unavailable }

/// Transcribes spoken commands into text.
///
/// Always safe to call: implementations degrade to `unavailable` rather
/// than throwing, so the UI can show a sensible fallback (type instead
/// of hold-to-talk).
abstract class SpeechRecognizer {
  /// Whether the platform currently supports speech recognition.
  bool get isAvailable;

  /// Current lifecycle status.
  SpeechStatus get status;

  /// Prepares the recognizer (permissions, warm-up). No-op if already
  /// initialized or unsupported.
  Future<void> initialize();

  /// Begins listening; results are delivered via [onResult], final results
  /// via [onDone]. Returns false when unavailable.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  });

  /// Stops listening and finalizes the current utterance.
  Future<void> stop();
}

/// Default recognizer backed by the `speech_to_text` plugin.
class NativeSpeechRecognizer implements SpeechRecognizer {
  NativeSpeechRecognizer();

  final SpeechToText _speech = SpeechToText();
  SpeechStatus _status = SpeechStatus.idle;
  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onDone;

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  SpeechStatus get status => _status;

  @override
  Future<void> initialize() async {
    if (_status == SpeechStatus.initializing ||
        _status == SpeechStatus.listening) {
      return;
    }
    _status = SpeechStatus.initializing;
    final available = await _speech.initialize(
      onStatus: (value) {
        if (value == 'listening') {
          _status = SpeechStatus.listening;
        } else if (value == 'notListening' || value == 'done') {
          _status = SpeechStatus.idle;
        }
      },
      onError: (_) => _status = SpeechStatus.unavailable,
    );
    _status = available ? SpeechStatus.idle : SpeechStatus.unavailable;
  }

  @override
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!isAvailable) return false;
    _onResult = onResult;
    _onDone = onDone;
    final started = await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        _onResult?.call(result.recognizedWords, result.finalResult);
        if (result.finalResult) _onDone?.call();
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    if (started) _status = SpeechStatus.listening;
    return started;
  }

  @override
  Future<void> stop() async {
    if (_status == SpeechStatus.listening) {
      await _speech.stop();
    }
    _status = SpeechStatus.idle;
    _onDone?.call();
  }
}

/// Fallback recognizer for platforms without speech support (web build,
/// simulators) — never throws, always reports unavailable.
class UnavailableSpeechRecognizer implements SpeechRecognizer {
  const UnavailableSpeechRecognizer();

  @override
  bool get isAvailable => false;

  @override
  SpeechStatus get status => SpeechStatus.unavailable;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    return false;
  }

  @override
  Future<void> stop() async {}
}

/// Injectable provider; tests override with a fake recognizer.
final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  return NativeSpeechRecognizer();
});