import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/accessibility_profile.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/preference_group.dart';
import '../../onboarding/domain/onboarding_providers.dart';

/// The personalized profile screen.
///
/// Central place to review and adjust personal accessibility
/// preferences, guidance style, speech rate and privacy controls.
/// Uses plain language and avoids unnecessary medical terminology.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accessibilityProfileProvider);
    final notifier = ref.read(accessibilityProfileProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _SummaryCard(profile: profile),
            const SizedBox(height: AppSpacing.xxl),

            PreferenceGroup<MobilityAssistance>(
              title: 'Movement',
              description: 'How you move best.',
              values: MobilityAssistance.values,
              selected: profile.mobility,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(mobility: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<VisionAssistance>(
              title: 'Sight',
              description: 'How you see best.',
              values: VisionAssistance.values,
              selected: profile.vision,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(vision: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<HearingAssistance>(
              title: 'Hearing',
              description: 'How you hear best.',
              values: HearingAssistance.values,
              selected: profile.hearing,
              labelOf: (v) => v.label,
              onChanged: (v) => notifier.update(profile.copyWith(hearing: v)),
            ),
            const SizedBox(height: AppSpacing.xl),

            PreferenceGroup<GuidanceStyle>(
              title: 'Guidance style',
              description: 'How much detail in each instruction.',
              values: GuidanceStyle.values,
              selected: profile.guidanceStyle,
              labelOf: (v) => v.label,
              onChanged: (v) =>
                  notifier.update(profile.copyWith(guidanceStyle: v)),
            ),
            const SizedBox(height: AppSpacing.xxl),

            _WalkingSpeedControl(profile: profile, notifier: notifier),
            const SizedBox(height: AppSpacing.xxl),

            _SectionHeader(title: 'Privacy', icon: Icons.privacy_tip_outlined),
            const SizedBox(height: AppSpacing.md),
            const _SettingRow(
              icon: Icons.videocam_outlined,
              title: 'Camera',
              detail: 'Used while assistance is active',
            ),
            const _SettingRow(
              icon: Icons.mic_none_outlined,
              title: 'Microphone',
              detail: 'Used for voice commands',
            ),
            const _SettingRow(
              icon: Icons.location_on_outlined,
              title: 'Location',
              detail: 'Used for routing and navigation',
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Navigation',
              icon: Icons.explore_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            const _SettingSwitch(
              icon: Icons.vibration,
              title: 'Haptics',
              detail: 'Vibrate for instructions and warnings',
              enabled: true,
            ),
            const _SettingSwitch(
              icon: Icons.volume_up_outlined,
              title: 'Sound alerts',
              detail: 'Play a tone when the route changes',
              enabled: true,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.profile});

  final AccessibilityProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your guidance profile',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onPrimary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryLine(
            icon: Icons.accessible_rounded,
            label: profile.mobility.label,
            color: scheme.onPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryLine(
            icon: Icons.visibility_outlined,
            label: profile.vision.label,
            color: scheme.onPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryLine(
            icon: Icons.hearing_outlined,
            label: profile.hearing.label,
            color: scheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _WalkingSpeedControl extends StatelessWidget {
  const _WalkingSpeedControl({required this.profile, required this.notifier});

  final AccessibilityProfile profile;
  final ProfileNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final speed = profile.walkingSpeedMps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Walking speed', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Used to estimate travel time and instruction timing.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Slider(
          value: speed.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${speed.toStringAsFixed(1)} m/s',
          onChanged: (v) =>
              notifier.update(profile.copyWith(walkingSpeedMps: v)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Leisurely', style: Theme.of(context).textTheme.labelSmall),
            Text(
              '${speed.toStringAsFixed(1)} m/s',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text('Quick', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.detail,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
      value: enabled,
      onChanged: null,
    );
  }
}
