import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/domain/services/haptics.dart';
import '../../../core/domain/services/speech_recognizer.dart';
import '../../../core/domain/services/speech_synthesizer.dart';
import '../../offline/domain/offline_controller.dart';
import '../../onboarding/domain/app_client_providers.dart';
import '../../onboarding/domain/session_controller.dart';

/// One message in the copilot conversation.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.action,
  });

  final String role; // 'user' | 'copilot'
  final String text;
  final api.Action? action;
}

/// Live state of the copilot conversation.
sealed class AssistantConversation {
  const AssistantConversation();

  /// The messages accumulated so far (all states carry them).
  List<AssistantMessage> get messages => const [];
}

class ConversationIdle extends AssistantConversation {
  const ConversationIdle();
}

class ConversationListening extends AssistantConversation {
  const ConversationListening();
}

class ConversationThinking extends AssistantConversation {
  const ConversationThinking(this.messages);

  @override
  final List<AssistantMessage> messages;
}

class ConversationReplied extends AssistantConversation {
  const ConversationReplied({required this.messages});

  @override
  final List<AssistantMessage> messages;
}

class ConversationUnavailable extends AssistantConversation {
  const ConversationUnavailable({required this.reason, this.messages = const []});

  final String reason;

  @override
  final List<AssistantMessage> messages;
}

/// Short-lived voice error that the UI may surface.
class AssistantError {
  const AssistantError(this.message);
  final String message;
}

/// Drives the copilot conversation: captures a spoken or typed command,
/// sends it to the assistant endpoint, attaches the resulting action, and
/// speaks the reply aloud according to the user's delivery preferences.
class AssistantController extends Notifier<AssistantConversation> {
  AssistantController();

  final List<AssistantMessage> _messages = [];

  @override
  AssistantConversation build() {
    final speech = ref.read(speechRecognizerProvider);
    Future.microtask(speech.initialize);
    return const ConversationIdle();
  }

  /// Returns the recognised text so silence can be treated as a no-op.
  List<AssistantMessage> get messages => List.unmodifiable(_messages);

  /// Begins voice capture (hold-to-talk).
  Future<bool> startListening() async {
    final speech = ref.read(speechRecognizerProvider);
    if (!speech.isAvailable) {
      state = ConversationUnavailable(
        reason: 'Voice input is not available here — type your question instead.',
        messages: _messages,
      );
      return false;
    }
    final started = await speech.startListening(
      onResult: (text, isFinal) {
        if (isFinal && text.trim().isNotEmpty) {
          unawaited(submit(text.trim()));
        }
      },
      onDone: () {
        if (ref.mounted && state is ConversationListening) {
          state = const ConversationIdle();
        }
      },
    );
    if (started) state = const ConversationListening();
    return started;
  }

  /// Stops voice capture without submitting anything.
  Future<void> stopListening() async {
    await ref.read(speechRecognizerProvider).stop();
    if (ref.mounted && state is ConversationListening) {
      state = const ConversationIdle();
    }
  }

  /// Submits a command (from voice or from the text fallback).
  Future<void> submit(String text) async {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();
    _messages.add(AssistantMessage(role: 'user', text: trimmed));
    state = ConversationThinking(_messages);

    final session = ref.read(sessionControllerProvider);
    final client = ref.read(apiClientProvider);
    try {
      final response = await client.assistantQuery(
        body: api.AssistantQuery(
          sessionId: session.sessionId,
          text: trimmed,
        ),
      );
      if (!ref.mounted) return;

      final action = response.action;
      _messages.add(
        AssistantMessage(role: 'copilot', text: response.reply, action: action),
      );
      state = ConversationReplied(messages: _messages);

      ref.read(connectivityProvider.notifier).noteSuccess();
      await _flushQueue();

      if (action != null && action.haptics != null) {
        try {
          await ref.read(hapticsProvider).forAction(action.haptics!);
        } catch (_) {
          // Non-haptic platforms ignore action pulses.
        }
      }
      final tts = ref.read(speechSynthesizerProvider);
      if (tts.isAvailable) await tts.speak(response.reply);
    } on Exception {
      if (!ref.mounted) return;
      // The command is queued and will be replayed when the network
      // comes back instead of being silently dropped.
      ref.read(connectivityProvider.notifier).noteFailure();
      await ref.read(eventQueueProvider.notifier).enqueue(
        CachedEvent(
          id: '',
          kind: 'assistant',
          payload: {'text': trimmed},
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      state = ConversationUnavailable(
        reason: 'You are offline. Your question is saved and will be sent '
            'automatically when the connection returns.',
        messages: _messages,
      );
    }
  }

  /// Replays any queued assistant commands once connectivity is back.
  Future<void> _flushQueue() async {
    final queue = ref.read(eventQueueProvider.notifier);
    if (queue.length == 0) return;

    final session = ref.read(sessionControllerProvider);
    final client = ref.read(apiClientProvider);
    final replies = <String>[];
    await queue.flush((event) async {
      if (event.kind != 'assistant') return true;
      try {
        final response = await client.assistantQuery(
          body: api.AssistantQuery(
            sessionId: session.sessionId,
            text: event.payload['text'] as String? ?? '',
          ),
        );
        replies.add(response.reply);
        return true;
      } on Exception {
        return false;
      }
    });
    if (!ref.mounted) return;
    if (replies.isNotEmpty) {
      _messages.addAll(
        replies.map((r) => AssistantMessage(role: 'copilot', text: r)),
      );
      state = ConversationReplied(messages: _messages);
      final tts = ref.read(speechSynthesizerProvider);
      if (tts.isAvailable) await tts.speak(replies.last);
    }
  }

  /// Clears the conversation history.
  void clear() {
    _messages.clear();
    state = const ConversationIdle();
  }
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantConversation>(
      AssistantController.new,
    );

final assistantMessagesProvider = Provider<List<AssistantMessage>>(
  (ref) => ref.watch(assistantControllerProvider.select((s) => s.messages)),
);