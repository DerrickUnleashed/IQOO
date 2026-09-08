import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';
import '../../demo/domain/demo_mode.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  String _greeting() { final hour = DateTime.now().hour; return hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening'; }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(body: Stack(children: [
      const Positioned.fill(child: AmbientBackground()),
      // LayoutBuilder + ConstrainedBox(minHeight) + IntrinsicHeight lets the
      // Spacer()s below fill the screen exactly as before on a normal-height
      // viewport, but become scrollable instead of overflowing when content
      // doesn't fit (a short window, or a larger accessibility text scale).
      SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: IntrinsicHeight(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), gradient: const LinearGradient(colors: AppColors.heroGradient), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .38), blurRadius: 18)]), child: const Icon(Icons.accessible_forward_rounded, color: Colors.white)),
          const SizedBox(width: AppSpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('COPILOT', style: text.labelMedium?.copyWith(color: AppColors.gold, letterSpacing: 1.7)), Text('Your way forward', style: text.labelMedium)]),
          const Spacer(),
          IconButton.filledTonal(onPressed: () => context.go(AppRoute.profile), tooltip: 'Profile', icon: const Icon(Icons.tune_rounded)),
        ]),
        const SizedBox(height: AppSpacing.xxl),
        Text(_greeting(), style: text.headlineSmall?.copyWith(color: AppColors.gold)),
        Text('You are never\nnavigating alone.', style: text.headlineLarge?.copyWith(color: Colors.white, height: 1.08)),
        const SizedBox(height: AppSpacing.sm),
        Text('A calmer, clearer way to explore the world around you.', style: text.bodyMedium?.copyWith(color: Colors.white70)),
        if (ref.watch(demoModeProvider)) const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: _DemoChip()),
        const SizedBox(height: AppSpacing.xl),
        _StartCard(onTap: () => context.push(AppRoute.assistance)),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(child: _ActionTile(icon: Icons.map_outlined, title: 'Find Accessible Route', subtitle: 'Move freely', accent: AppColors.gold, onTap: () => context.push(AppRoute.buildings))),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _ActionTile(icon: Icons.visibility_outlined, title: 'Scan Environment', subtitle: 'Know more', accent: AppColors.accent, onTap: () => context.push(AppRoute.assistance))),
        ]),
        const Spacer(),
        Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.md), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .12))), child: Row(children: [const Icon(Icons.auto_awesome_rounded, color: AppColors.gold), const SizedBox(width: AppSpacing.sm), Expanded(child: Text('“A more inclusive world moves with you.”', style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.white70)))])),
        const SizedBox(height: AppSpacing.lg),
        Center(child: Semantics(label: 'Hold to talk to your accessibility copilot', child: VoiceButton(onPressed: () => context.push(AppRoute.assistance)))),
        const SizedBox(height: AppSpacing.xs), Center(child: Text('Hold to talk', style: text.labelMedium?.copyWith(color: Colors.white60))),
        const SizedBox(height: AppSpacing.lg),
      ])))))),
    ]));
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onTap}); final VoidCallback onTap;
  @override Widget build(BuildContext context) => Semantics(button: true, label: 'Start Assistance', child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Ink(
    padding: const EdgeInsets.all(AppSpacing.lg), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: AppColors.heroGradient), boxShadow: [BoxShadow(color: AppColors.rose.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 10))]),
    child: Row(children: [Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary)), const SizedBox(width: AppSpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Start Assistance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)), const SizedBox(height: 3), Row(children: [Text('Ask Copilot', style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12)), const Text('  •  Real-time support', style: TextStyle(color: Colors.white70, fontSize: 12))])])), const Icon(Icons.arrow_forward_rounded, color: Colors.white)]),
  )));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap}); final IconData icon; final String title, subtitle; final Color accent; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Ink(padding: const EdgeInsets.all(AppSpacing.md), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .13))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .16)), child: Icon(icon, color: accent)), const SizedBox(height: AppSpacing.md), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12))])));
}

class _DemoChip extends StatelessWidget { const _DemoChip(); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)), child: const Text('Demo mode', style: TextStyle(color: AppColors.gold))); }
