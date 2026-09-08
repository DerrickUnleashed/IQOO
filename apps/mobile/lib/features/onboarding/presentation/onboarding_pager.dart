import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/index.dart';

class OnboardingPageView {
  const OnboardingPageView({required this.icon, required this.eyebrow, required this.title, required this.body});
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}

const onboardingPages = [
  OnboardingPageView(icon: Icons.travel_explore_rounded, eyebrow: 'ACCESSIBILITY, MADE PERSONAL', title: 'Your AI accessibility copilot.', body: 'Your AI companion sees, understands and helps you move through the world — with you, for you.'),
  OnboardingPageView(icon: Icons.visibility_rounded, eyebrow: 'A CALMER WAY TO MOVE', title: 'See what matters\nmost.', body: 'Understand your surroundings, find safer routes, and get clear guidance when you need it.'),
  OnboardingPageView(icon: Icons.auto_awesome_rounded, eyebrow: 'DESIGNED AROUND YOU', title: 'Support that\nfeels human.', body: 'Choose the assistance that suits you. You are always in control of your journey.'),
];

class OnboardingPager extends StatefulWidget {
  const OnboardingPager({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override State<OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<OnboardingPager> {
  final _controller = PageController();
  int _index = 0;
  @override void dispose() { _controller.dispose(); super.dispose(); }
  void _next() => _index == onboardingPages.length - 1 ? widget.onFinished() : _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      const Positioned.fill(child: AmbientBackground()),
      SafeArea(child: Column(children: [
        Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: TextButton(onPressed: widget.onFinished, child: const Text('Skip for now')))),
        Expanded(child: PageView.builder(controller: _controller, itemCount: onboardingPages.length, onPageChanged: (value) => setState(() => _index = value), itemBuilder: (context, i) => _OnboardingContent(page: onboardingPages[i], isWelcome: i == 0))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(onboardingPages.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4), width: i == _index ? 28 : 7, height: 7, decoration: BoxDecoration(color: i == _index ? AppColors.gold : Colors.white24, borderRadius: BorderRadius.circular(99))))),
        Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl), child: PrimaryButton(onPressed: _next, icon: _index == onboardingPages.length - 1 ? Icons.arrow_forward_rounded : null, child: Text(_index == onboardingPages.length - 1 ? 'Get started' : 'Continue'))),
      ])),
    ]),
  );
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({required this.page, required this.isWelcome});
  final OnboardingPageView page;
  final bool isWelcome;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: isWelcome ? const _WelcomeArtwork() : Center(child: _PageIcon(icon: page.icon))),
      Text(page.eyebrow, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.6)),
      const SizedBox(height: AppSpacing.md),
      Text(page.title, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, height: 1.08)),
      const SizedBox(height: AppSpacing.md),
      Text(page.body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: .82))),
      const SizedBox(height: AppSpacing.xxl),
    ]),
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
    child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/onboarding-path.png', fit: BoxFit.cover),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE60B1020)]))),
      const Positioned(left: 22, right: 22, bottom: 26, child: Text('“Every path deserves\na way forward.”', style: TextStyle(color: Colors.white, fontSize: 21, fontStyle: FontStyle.italic, height: 1.2))),
    ])),
  );
}

class _PageIcon extends StatelessWidget {
  const _PageIcon({required this.icon}); final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: 124, height: 124, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: AppColors.heroGradient), boxShadow: [BoxShadow(color: AppColors.rose.withValues(alpha: .35), blurRadius: 38)]), child: Icon(icon, color: Colors.white, size: 56));
}
