// Persistent offline banner: visible whenever the network is down.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../features/offline/domain/offline_controller.dart';

/// Shows a slim banner when the app is offline; hides otherwise.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    if (connectivity is Online) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'You are offline. Your changes are saved locally.',
      child: Container(
        width: double.infinity,
        color: scheme.errorContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 16, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Offline — changes are saved locally',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}