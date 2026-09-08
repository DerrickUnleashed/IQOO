// Widget tests for the assistant home screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/features/home/presentation/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders greeting, CTA and voice entry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(child: const MaterialApp(home: HomeScreen())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('A calmer, clearer way to explore the world around you.'),
        findsOneWidget,
      );
      expect(find.text('Start Assistance'), findsOneWidget);
      expect(find.text('Ask Copilot'), findsOneWidget);
      expect(find.text('Find Accessible Route'), findsOneWidget);
      expect(find.text('Scan Environment'), findsOneWidget);
      expect(find.text('Hold to talk'), findsOneWidget);
    });

    testWidgets('primary CTA is full width and reasonably tall', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(child: const MaterialApp(home: HomeScreen())),
      );
      await tester.pumpAndSettle();

      // The primary CTA is a custom gradient InkWell card, not a stock
      // FilledButton — matches the current visual design.
      final buttonFinder = find.ancestor(
        of: find.text('Start Assistance'),
        matching: find.byType(InkWell),
      );
      expect(buttonFinder, findsOneWidget);

      final rect = tester.getRect(buttonFinder);
      expect(rect.width, greaterThanOrEqualTo(200));
      expect(rect.height, greaterThanOrEqualTo(48));
    });
  });
}
