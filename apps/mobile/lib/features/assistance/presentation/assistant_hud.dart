import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/assistant_controller.dart';

/// Bottom sheet content: the live copilot conversation with a hold-to-talk
/// voice button and a text fallback for when speech is unavailable.
class AssistantHud extends ConsumerStatefulWidget {
  const AssistantHud({super.key});

  @override
  ConsumerState<AssistantHud> createState() => _AssistantHudState();
}

class _AssistantHudState extends ConsumerState<AssistantHud> {
  final TextEditingController _text = TextEditingController();
  var _holding = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    final notifier = ref.read(assistantControllerProvider.notifier);
    if (_holding) {
      await notifier.stopListening();
    } else {
      await notifier.startListening();
    }
    if (mounted) setState(() => _holding = !_holding);
  }

  Future<void> _submitText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    await ref.read(assistantControllerProvider.notifier).submit(text);
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(assistantControllerProvider);
    final messages = conversation.messages;

    final canVoice = switch (conversation) {
      ConversationIdle() => true,
      ConversationListening() => true,
      _ => false,
    };

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppColors.accentDark.withValues(alpha: 0.35),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              status: switch (conversation) {
                ConversationListening() => 'Listening…',
                ConversationThinking() => 'Thinking…',
                _ => 'Copilot',
              },
              onClear: () =>
                  ref.read(assistantControllerProvider.notifier).clear(),
            ),
            if (conversation is ConversationUnavailable)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  conversation.reason,
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
            if (messages.isNotEmpty) _MessageList(messages: messages),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitText(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ask anything…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: (_text.text.trim().isEmpty && messages.isEmpty)
                      ? null
                      : _submitText,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                ),
                const SizedBox(width: AppSpacing.sm),
                _VoiceButton(
                  listening: conversation is ConversationListening,
                  enabled: canVoice &&
                      conversation is! ConversationUnavailable,
                  onPressed: _toggleListening,
                ),
              ],
            ),
            if (conversation is! ConversationUnavailable)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  conversation is ConversationListening
                      ? 'Release to stop'
                      : 'Hold to talk',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.onClear});

  final String status;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: AppColors.glowGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClear,
          tooltip: 'Clear conversation',
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.white54, size: 20),
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<AssistantMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isUser = message.role == 'user';
          return Align(
            alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: AppColors.heroGradient
                            .map((c) => c.withValues(alpha: 0.55))
                            .toList(),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white, height: 1.3),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Circular hold/release button that drives voice capture.
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.listening,
    required this.enabled,
    required this.onPressed,
  });

  final bool listening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Hold to talk',
      child: GestureDetector(
        onLongPress: enabled ? onPressed : null,
        onLongPressEnd: enabled && listening ? (_) => onPressed() : null,
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: listening
                ? const LinearGradient(colors: AppColors.glowGradient)
                : null,
            color: listening ? null : Colors.white.withValues(alpha: 0.14),
            border: Border.all(
              color: listening ? Colors.white : AppColors.accentDark,
              width: 2,
            ),
            boxShadow: listening
                ? [
                    BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            listening ? Icons.graphic_eq : Icons.mic,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}