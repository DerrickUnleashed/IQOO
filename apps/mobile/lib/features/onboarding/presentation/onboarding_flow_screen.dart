import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import 'onboarding_pager.dart';

/// Orchestrates the onboarding experience.
///
/// Flow: pager (3 product pages) -> preferences -> complete.
/// After completion the router redirects to the home screen.
class OnboardingFlowScreen extends ConsumerWidget {
  const OnboardingFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPager(onFinished: () => context.go(AppRoute.preferences));
  }
}
