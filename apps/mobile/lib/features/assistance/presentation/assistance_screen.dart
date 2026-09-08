import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';
import '../../guidance/domain/guidance_engine.dart';
import '../domain/camera_controller.dart';
import '../domain/scene_overlay.dart';
import '../domain/scene_pipeline.dart';
import 'assistant_hud.dart';

/// The most important screen in the app: full-screen camera with a
/// minimal, calm overlay. Always answers "what do I do now?".
class AssistanceScreen extends ConsumerWidget {
  const AssistanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraState = ref.watch(cameraStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (cameraState) {
        CameraInitializing() => const _InitializingView(),
        CameraPermissionRequired() => const _PermissionView(),
        CameraUnavailable(message: final message) => _UnavailableView(
          message: message,
        ),
        CameraReady(controller: final controller, isTorchOn: final torch) =>
          _CameraView(controller: controller, isTorchOn: torch),
      },
    );
  }
}

class _InitializingView extends StatelessWidget {
  const _InitializingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _PermissionView extends ConsumerWidget {
  const _PermissionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _FullScreenMessage(
      icon: Icons.no_photography_outlined,
      title: 'Camera access is needed',
      body: 'AccessCopilot uses your camera to understand the environment and decide your safest next action.',
      actionLabel: 'Grant camera access',
      onAction: () => ref.read(cameraStateProvider.notifier).initialize(),
    );
  }
}

class _UnavailableView extends ConsumerWidget {
  const _UnavailableView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _FullScreenMessage(
      icon: Icons.videocam_off_outlined,
      title: 'Camera unavailable',
      body: message,
      actionLabel: 'Try again',
      onAction: () => ref.read(cameraStateProvider.notifier).initialize(),
    );
  }
}

class _FullScreenMessage extends StatelessWidget {
  const _FullScreenMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white70),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _CameraView extends ConsumerStatefulWidget {
  const _CameraView({required this.controller, required this.isTorchOn});

  final CameraController controller;
  final bool isTorchOn;

  @override
  ConsumerState<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<_CameraView>
    with WidgetsBindingObserver {
  // Captured once, up front: `ref` is unsafe to read inside dispose() —
  // by the time it runs the widget may already be unmounted, which
  // Riverpod treats as a fatal error and previously brought the whole
  // app down when leaving this screen. Riverpod's own guidance for this
  // is exactly this: save the provider state in a field instead.
  late final ScenePipelineController _pipeline;

  @override
  void initState() {
    super.initState();
    _pipeline = ref.read(scenePipelineStateProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    // Start the perception pipeline against the live camera feed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pipeline.attachCamera(widget.controller);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipeline.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // Stop analyzing frames while the feed is not visible.
      _pipeline.detach();
    } else if (state == AppLifecycleState.resumed) {
      // Re-wire the perception pipeline on return to the foreground.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pipeline.attachCamera(widget.controller);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isTorchOn = widget.isTorchOn;
    final notifier = ref.read(cameraStateProvider.notifier);
    final annotations = ref.watch(sceneAnnotationsProvider);

    // Spoken + haptic alerts for urgent objects in the live scene.
    ref.listen(scenePipelineStateProvider, (previous, next) {
      if (next is SceneLive) {
        ref
            .read(guidanceEngineProvider)
            .announceUrgentScene(next.sceneObjects);
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        _SceneOverlay(annotations: annotations),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _PrivacyIndicator(),
            ),
          ),
        ),
        const OfflineBanner(),
        SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  _OverlayIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Close assistance',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const _ListeningPill(),
                  const Spacer(),
                  _OverlayIconButton(
                    icon: isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    tooltip: isTorchOn ? 'Turn torch off' : 'Turn torch on',
                    onPressed: notifier.toggleTorch,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _OverlayIconButton(
                    icon: Icons.cameraswitch_rounded,
                    tooltip: 'Switch camera',
                    onPressed: notifier.switchCamera,
                  ),
                ],
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _AssistantSheet(),
        ),
      ],
    );
  }
}

/// Collapsible assistant conversation anchored over the camera feed.
class _AssistantSheet extends StatelessWidget {
  const _AssistantSheet();

  @override
  Widget build(BuildContext context) {
    return const AssistantHud();
  }
}

/// Renders the profile-aware scene annotations over the camera feed.
class _SceneOverlay extends StatelessWidget {
  const _SceneOverlay({required this.annotations});

  final List<SceneAnnotation> annotations;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl * 2, right: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final a in annotations)
                _AnnotationChip(
                  label: a.label,
                  color: a.color,
                  urgent: a.urgent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnotationChip extends StatelessWidget {
  const _AnnotationChip({
    required this.label,
    required this.color,
    required this.urgent,
  });

  final String label;
  final Color color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: urgent ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.warning_amber_rounded : Icons.circle,
            size: 12,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Small non-interactive circle button floating over the camera feed.
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass pill used for HUD status chrome over the camera feed.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ListeningPill extends StatelessWidget {
  const _ListeningPill();

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accentDark,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Monitoring',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// "Camera active" badge that is always visible while the feed is live.
/// Privacy-first: the user always knows the camera is on.
class _PrivacyIndicator extends StatelessWidget {
  const _PrivacyIndicator();

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Camera active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
