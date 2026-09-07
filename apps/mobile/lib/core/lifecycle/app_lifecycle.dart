import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/speech_synthesizer.dart';

/// The latest application lifecycle state, published centrally so widget
/// trees and providers can react to backgrounding/resume.
///
/// Starts as `null` until the operating system reports the first transition.
final appLifecycleProvider =
    NotifierProvider<AppLifecycleController, AppLifecycleState?>(
      AppLifecycleController.new,
    );

class AppLifecycleController extends Notifier<AppLifecycleState?> {
  @override
  AppLifecycleState? build() => null;

  /// Records a lifecycle transition and halts speech output when the app
  /// moves to the background so cues do not keep talking over other apps.
  Future<void> update(AppLifecycleState next) async {
    final previous = state;
    state = next;
    if (next == AppLifecycleState.paused ||
        next == AppLifecycleState.hidden ||
        next == AppLifecycleState.detached) {
      if (previous != next) {
        await ref.read(speechSynthesizerProvider).stop();
      }
    }
  }
}