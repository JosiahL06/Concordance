// The single-surface substitution board: team tabs, at-the-table and bench
// columns, preselection from the quiz-out prompt, and its persistent prompt.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

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

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

const kValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundController freshRound({
  List<String> redBench = const ['Red 3', 'Red 4'],
  List<String> greenBench = const ['Green 3', 'Green 4'],
}) => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  redBench: redBench,
  greenBench: greenBench,
  questionValues: kValues,
);

Future<void> pumpClassic(
  WidgetTester tester,
  RoundController round, {
  Size size = const Size(1280, 800),
  double textScale = 1.0,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ClassicScreen(controller: round),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpBoardHarness(
  WidgetTester tester,
  RoundController round, {
  Size size = const Size(1280, 800),
  double textScale = 1.0,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showSubstitutionBoard(context, round),
                child: const Text('OPEN BOARD'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN BOARD'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('footer opens one swap board with team tabs and columns', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round);

    await tester.tap(find.text('Substitute quizzer'));
    await tester.pumpAndSettle();

    final board = find.byType(SubstitutionBoard);
    expect(board, findsOneWidget);
    expect(
      find.descendant(of: board, matching: find.text('Substitute quizzer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('AT THE TABLE (2)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('BENCH (2)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('RED')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('GREEN')),
      findsOneWidget,
    );
  });

  testWidgets('selecting out and in updates the summary and swaps seats', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round);
    await tester.tap(find.text('Substitute quizzer'));
    await tester.pumpAndSettle();
    final board = find.byType(SubstitutionBoard);

    await tester.tap(find.descendant(of: board, matching: find.text('Red 1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('leaving seat 1'), findsOneWidget);

    await tester.tap(find.descendant(of: board, matching: find.text('Red 3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Red 1 (seat 1)'), findsOneWidget);
    expect(find.textContaining('Red 3 \u2192 seat 1'), findsOneWidget);

    await tester.tap(find.text('CONFIRM SUBSTITUTION'));
    await tester.pumpAndSettle();

    expect(board, findsNothing);
    expect(
      round.teamOf(Side.red).seated.map((quizzer) => quizzer.label),
      contains('Red 3'),
    );
    expect(
      round.teamOf(Side.red).bench.map((quizzer) => quizzer.label),
      contains('Red 1'),
    );
  });

  testWidgets(
    'quiz-out prompt is persistent and preselects the outgoing quizzer',
    (WidgetTester tester) async {
      final round = freshRound(redBench: const ['Red 3']);
      for (var n = 1; n <= 5; n++) {
        round.jumpToQuestion(n);
        round.select(Side.red, 0);
        round.markCorrect();
      }
      await pumpClassic(tester, round);

      final promptBar = find.byType(SubstitutionPromptBar);
      expect(promptBar, findsOneWidget);
      expect(
        find.descendant(
          of: promptBar,
          matching: find.textContaining('Red: Red 1 quizzed out'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: promptBar,
          matching: find.textContaining('Red 3 (0 pts) can replace them'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('SUBSTITUTE'));
      await tester.pumpAndSettle();
      final board = find.byType(SubstitutionBoard);
      expect(board, findsOneWidget);
      expect(
        find.descendant(
          of: board,
          matching: find.textContaining('Red 1 quizzed out'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('leaving seat 1'), findsOneWidget);
      // The team is locked, so the other team's tab is not offered.
      expect(
        find.descendant(of: board, matching: find.text('GREEN')),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: board, matching: find.text('Red 3')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRM SUBSTITUTION'));
      await tester.pumpAndSettle();

      expect(round.substitutionPrompt, isNull);
      expect(board, findsNothing);
    },
  );

  testWidgets('the prompt can be dismissed and clears its matching notice', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    for (var n = 1; n <= 5; n++) {
      round.jumpToQuestion(n);
      round.select(Side.red, 0);
      round.markCorrect();
    }
    await pumpClassic(tester, round);
    expect(round.substitutionPrompt, isNotNull);

    await tester.tap(find.byTooltip('Dismiss substitution prompt'));
    await tester.pumpAndSettle();

    expect(round.substitutionPrompt, isNull);
    expect(find.textContaining('quizzed out'), findsNothing);
    expect(find.textContaining('can replace them'), findsNothing);
    expect(round.lastAlert, isNull);
  });

  testWidgets('no bench means the footer reports it instead of opening', (
    WidgetTester tester,
  ) async {
    final round = freshRound(redBench: const [], greenBench: const []);
    await pumpClassic(tester, round);

    await tester.tap(find.text('Substitute quizzer'));
    await tester.pumpAndSettle();

    expect(find.byType(SubstitutionBoard), findsNothing);
    expect(round.lastAlert, contains('No bench quizzer'));
  });

  testWidgets('the live screen with a quiz-out prompt fits at 1.3x', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    for (var n = 1; n <= 5; n++) {
      round.jumpToQuestion(n);
      round.select(Side.red, 0);
      round.markCorrect();
    }
    await pumpClassic(tester, round, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.byType(SubstitutionPromptBar), findsOneWidget);
  });

  testWidgets('the quiz-out prompt is announced as a live region', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound(redBench: const ['Red 3']);
    for (var n = 1; n <= 5; n++) {
      round.jumpToQuestion(n);
      round.select(Side.red, 0);
      round.markCorrect();
    }
    await pumpClassic(tester, round);

    final bar = tester.getSemantics(find.byType(SubstitutionPromptBar));
    expect(bar.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('board cards and team tabs are tappable semantic controls', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pumpBoardHarness(tester, round);

    final card = tester.getSemantics(
      find.bySemanticsLabel('Red seat 1, Red 1, 0 points'),
    );
    expect(card.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(card.getSemanticsData().flagsCollection.isButton, isTrue);

    final tab = tester.getSemantics(
      find.bySemanticsLabel('Red team, 0 points, 2 on bench'),
    );
    expect(tab.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('the board fits the minimum size', (WidgetTester tester) async {
    final round = freshRound();
    await pumpClassic(tester, round, size: const Size(1024, 700));

    await tester.tap(find.text('Substitute quizzer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SubstitutionBoard), findsOneWidget);
  });

  testWidgets('the board fits the live text-scale cap', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round, textScale: 1.3);

    await tester.tap(find.text('Substitute quizzer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SubstitutionBoard), findsOneWidget);
  });
}
