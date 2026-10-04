import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/main.dart';

void main() {
  testWidgets('home offers new round and demo entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ConcordancePrototypeApp());

    expect(find.text('START A NEW ROUND'), findsOneWidget);
    expect(find.text('Load demo round (mid-match)'), findsOneWidget);
  });

  testWidgets('setup flow loads real preset tabs and starts Classic mode', (
    WidgetTester tester,
  ) async {
    // Design target size (Fire HD 10 landscape logical dp).
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ConcordancePrototypeApp());
    await tester.tap(find.text('START A NEW ROUND'));
    await tester.pumpAndSettle();

    // Ruleset tabs come from the real assets/rulesets/*.json presets.
    expect(find.text('Teen Bible Quiz 2025-26'), findsOneWidget);
    expect(find.text('Junior Bible Quiz 2026'), findsOneWidget);
    expect(find.textContaining('questions'), findsWidgets);

    // Pick the Classic scoreboard view, then start.
    await tester.scrollUntilVisible(
      find.text('Classic'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('START ROUND'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('START ROUND'));
    await tester.pumpAndSettle();

    // Classic live-scoring screen, fresh round: question 1 of 20, empty grid.
    expect(find.text('QUESTION 1 OF 20'), findsOneWidget);
    expect(find.textContaining('TAP A QUIZZER CELL'), findsOneWidget);
    expect(find.text('SCORE 0'), findsNWidgets(2));
  });
}
