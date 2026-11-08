// Second polishing pass: the ruleset pick moved into setup, the roster is now
// seated + bench (with a bench strip in both live views), and the summary
// announces 1st/2nd place team and individual standings.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/classic_screen.dart';
import 'package:concordance/views/common/live_chrome.dart';
import 'package:concordance/views/modern_screen.dart';
import 'package:concordance/views/setup_screen.dart';
import 'package:concordance/views/summary_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

List<Ruleset> presets() => [loadPreset('tbq-25-26'), loadPreset('jbq-2026')];

/// Representative value list (no built-in order — D11).
const kValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundController freshRound() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  redBench: const ['Red 3'],
  greenBench: const ['Green 3'],
  questionValues: kValues,
);

RoundController namedRound() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Alice', 'Bob'],
  greenSeats: const ['Cara', 'Dana'],
  redBench: const ['Eve'],
  greenBench: const ['Fay'],
  questionValues: kValues,
);

Future<void> pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await ViewPreference.load();
  final theme = ThemeController(prefs);
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    ThemeScope(
      notifier: theme,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kSeed),
          useMaterial3: true,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('setup folds the ruleset pick into the settings body', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      SetupScreen(initialView: ScoreboardView.classic, presets: presets()),
    );

    // In-body ruleset selector + a bench roster control per team; no tab bar.
    expect(find.text('Ruleset'), findsOneWidget);
    expect(find.text('Bench: '), findsNWidgets(2));
    expect(find.text('Seated: '), findsNWidgets(2));
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('Classic shows a bench strip per team', (
    WidgetTester tester,
  ) async {
    await pump(tester, ClassicScreen(controller: freshRound()));
    expect(find.text('BENCH'), findsNWidgets(2));
    expect(find.byType(BenchCard), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(BenchCard).first).width,
      lessThan(400),
      reason: 'bench cards should size to their content, not stretch',
    );
    expect(find.textContaining('Red 3'), findsOneWidget);
    expect(find.textContaining('Green 3'), findsOneWidget);
  });

  testWidgets('Modern shows a bench strip per team', (
    WidgetTester tester,
  ) async {
    await pump(tester, ModernScreen(controller: freshRound()));
    expect(find.text('BENCH'), findsNWidgets(2));
    expect(find.byType(BenchCard), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(BenchCard).first).width,
      lessThan(300),
      reason: 'bench cards should size to their content, not stretch',
    );
  });

  testWidgets('Classic seat titles are softer and quieter than names', (
    WidgetTester tester,
  ) async {
    await pump(tester, ClassicScreen(controller: namedRound()));

    expect(find.text('RED 1'), findsOneWidget);
    expect(find.text('GREEN 1'), findsOneWidget);
    expect(find.text('RED 2'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Alice'));
    final badge = tester.widget<Text>(find.text('RED 1'));
    expect(
      name.style!.fontWeight!.value,
      greaterThan(badge.style!.fontWeight!.value),
    );
    expect(badge.style!.fontSize, 10);
    expect(badge.style!.color, redColor);
    final badgeBox = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SeatBadge).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect((badgeBox.decoration! as BoxDecoration).color, redTint);
  });

  testWidgets('Modern seat titles are softer and quieter than names', (
    WidgetTester tester,
  ) async {
    await pump(tester, ModernScreen(controller: namedRound()));

    expect(find.text('RED 1'), findsOneWidget);
    expect(find.text('GREEN 1'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Alice'));
    final badge = tester.widget<Text>(find.text('RED 1'));
    expect(
      name.style!.fontWeight!.value,
      greaterThan(badge.style!.fontWeight!.value),
    );
    expect(badge.style!.fontSize, 11);
    expect(badge.style!.color, redColor);
    final badgeBox = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SeatBadge).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect((badgeBox.decoration! as BoxDecoration).color, redTint);
  });

  testWidgets('bench strip tracks the points of a rotated-out quizzer', (
    WidgetTester tester,
  ) async {
    final c = freshRound(); // Red bench is ['Red 3'] (roster index 2).
    c.jumpToQuestion(1);
    c.select(Side.red, 0);
    c.markCorrect(); // Red 1 scores +10.
    // Substituting a HEALTHY quizzer is allowed (no one quizzed out).
    c.substituteQuizzer(side: Side.red, outIndex: 0, benchIndex: 2);

    await pump(tester, ClassicScreen(controller: c));
    // Red 1 is on the bench in a card, with their 10 points beside the name.
    final benchCard = find.ancestor(
      of: find.text('Red 1'),
      matching: find.byType(BenchCard),
    );
    expect(benchCard, findsOneWidget);
    expect(
      find.descendant(of: benchCard, matching: find.text('10')),
      findsOneWidget,
    );
    // Red 3 took the table (shown as a seated row, not the bench).
    expect(find.text('Red 3'), findsOneWidget);
  });

  testWidgets('summary announces 1st/2nd place team and individuals', (
    WidgetTester tester,
  ) async {
    final c = freshRound();
    // Red 1 scores twice (10 + 20 = 30); Green 1 scores once (10).
    c.jumpToQuestion(1);
    c.select(Side.red, 0);
    c.markCorrect();
    c.select(Side.red, 0);
    c.markCorrect();
    c.select(Side.green, 0);
    c.markCorrect();

    await pump(tester, SummaryScreen(controller: c));

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Team placings'), findsOneWidget);
    expect(find.text('Individual placings'), findsOneWidget);
    expect(find.text('1st'), findsNWidgets(2));
    expect(find.text('2nd'), findsNWidgets(2));
    // Red leads the team standings; Red 1 leads individuals.
    expect(find.text('Red'), findsWidgets);
  });
}
