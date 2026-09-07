// Smoke test verifying the AccessCopilot application starts and renders.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/main.dart';

void main() {
  testWidgets('App builds and shows the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AccessCopilotApp()));
    await tester.pumpAndSettle();

    expect(find.byType(AccessCopilotApp), findsOneWidget);
  });
}
