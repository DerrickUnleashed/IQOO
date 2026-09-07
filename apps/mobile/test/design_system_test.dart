// Tests for the AccessCopilot design system components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/shared/widgets/index.dart';

void main() {
  group('Design system components', () {
    testWidgets('PrimaryButton renders and responds to taps', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              child: const Text('Start'),
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Start'), findsOneWidget);
      await tester.tap(find.text('Start'));
      expect(tapped, isTrue);
    });

    testWidgets('AccessibilityBadge shows icon and label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityBadge(
              label: 'Accessible',
              status: AccessibilityStatus.accessible,
            ),
          ),
        ),
      );

      expect(find.text('Accessible'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('InstructionCard shows action and detail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstructionCard(
              action: 'Turn right',
              detail: 'Walk approximately 8 metres',
            ),
          ),
        ),
      );

      expect(find.text('Turn right'), findsOneWidget);
      expect(find.text('Walk approximately 8 metres'), findsOneWidget);
      expect(find.text('NEXT ACTION'), findsOneWidget);
    });

    testWidgets('ConfidenceIndicator shows percentage semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ConfidenceIndicator(confidence: 0.91)),
        ),
      );

      expect(find.text('91%'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('VoiceButton has an accessible label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VoiceButton(onPressed: null))),
      );

      final semantics = tester.getSemantics(find.byType(VoiceButton));
      expect(find.byType(VoiceButton), findsOneWidget);
      expect(semantics.label, contains('Hold to talk'));
    });
  });
}
