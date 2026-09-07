import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/accessibility_profile.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/preference_group.dart';
import '../domain/onboarding_providers.dart';

/// Lets the user describe the assistance they'd like.
///
/// Deliberately non-prescriptive: every question can be left at
/// "No assistance" and the user can continue without personalization.
class AccessibilityPreferencesScreen extends ConsumerWidget {
  const AccessibilityPreferencesScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (context.mounted) {
      context.go(AppRoute.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accessibilityProfileProvider);
    final notifier = ref.read(accessibilityProfileProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Personalize')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'How can I support you?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Answer as much or as little as you like. You can change these at any time in Settings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),

            PreferenceGroup<MobilityAssistance>(
              title: 'Movement',
              description: 'Do you use any mobility assistance?',
              values: MobilityAssistance.values,
              selected: profile.mobility,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(mobility: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<VisionAssistance>(
              title: 'Sight',
              description: 'How is your vision?',
              values: VisionAssistance.values,
              selected: profile.vision,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(vision: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<HearingAssistance>(
              title: 'Hearing',
              description: 'How is your hearing?',
              values: HearingAssistance.values,
              selected: profile.hearing,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(hearing: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<GuidanceStyle>(
              title: 'Guidance style',
              description: 'How much detail do you want in each instruction?',
              values: GuidanceStyle.values,
              selected: profile.guidanceStyle,
              labelOf: (v) => v.label,
              onChanged: (v) =>
                  notifier.update(profile.copyWith(guidanceStyle: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Cognitive load',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.prefersSimpleInstructions
                  ? 'You will get one simple instruction at a time.'
                  : 'You will get a little more context with each instruction.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Simple')),
                ButtonSegment(value: 2, label: Text('Balanced')),
                ButtonSegment(value: 3, label: Text('Detailed')),
              ],
              selected: {profile.cognitiveLoadPreference},
              onSelectionChanged: (selection) {
                notifier.update(
                  profile.copyWith(cognitiveLoadPreference: selection.first),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FilledButton.icon(
            onPressed: () => _finish(context, ref),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
