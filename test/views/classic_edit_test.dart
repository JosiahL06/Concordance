// Direct editing in the Classic ledger: tap an answer cell to change/remove it,
// tap a marked question header to fix its value/interruption/void, and confirm
// any later actions that the edit invalidates.
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

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

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

void main() {
  testWidgets('tap a marked cell, mark it incorrect, score updates', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);

    expect(find.text('+10'), findsOneWidget);
    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();

    expect(find.text('Q1 \u00b7 RED'), findsOneWidget);
    expect(find.text('Red 1'), findsWidgets);
    await tester.tap(find.text('MARK INCORRECT'));
    await tester.pumpAndSettle();

    expect(round.scoreOf(Side.red), -5);
    expect(round.cellOutcome(Side.red, 0, 1), 'incorrect');
    expect(find.text('\u22125'), findsOneWidget);
    expect(find.text('UNDO EDIT'), findsOneWidget);
  });

  testWidgets('remove a ruling and leave the keeper on the question', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);
    expect(round.questionNumber, 2);

    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE RULING'));
    await tester.pumpAndSettle();

    expect(round.scoreOf(Side.red), 0);
    expect(round.questionNumber, 1);
    expect(round.selected, (Side.red, 0));
    expect(round.cellOutcome(Side.red, 0, 1), isNull);
    expect(find.text('QUESTION 1 OF 20'), findsOneWidget);
  });

  testWidgets('undo edit restores the original ruling', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);

    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MARK INCORRECT'));
    await tester.pumpAndSettle();
    expect(round.scoreOf(Side.red), -5);

    await tester.tap(find.text('UNDO EDIT'));
    await tester.pumpAndSettle();
    expect(round.scoreOf(Side.red), 10);
    expect(round.cellOutcome(Side.red, 0, 1), 'correct');
  });

  testWidgets('an answered question header changes its value', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);
    expect(round.scoreOf(Side.red), 10);

    // Q1's header is the "1" column caption; tapping it opens the editor.
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.textContaining('already answered'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-value-30')));
    await tester.pumpAndSettle();
    expect(round.currentValue(1), 30);
    expect(round.scoreOf(Side.red), 30);
    expect(find.text('+30'), findsOneWidget);
  });

  testWidgets('remove an interruption with no dependent answers', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.toggleInterruption();
    await pumpClassic(tester, round);
    expect(round.view.questionMarks[0].interrupted, isTrue);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE INTERRUPTION'));
    await tester.pumpAndSettle();

    expect(round.view.questionMarks[0].interrupted, isFalse);
  });

  testWidgets('remove a void restores the question', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.voidQuestion();
    await pumpClassic(tester, round);
    expect(round.view.questionMarks[0].voided, isTrue);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE VOID'));
    await tester.pumpAndSettle();

    expect(round.view.questionMarks[0].voided, isFalse);
  });

  testWidgets('removing an interruption confirms the dependent re-read', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.toggleInterruption();
    round.select(Side.red, 0);
    round.markIncorrect();
    round.select(Side.green, 0);
    round.markCorrect();
    expect(round.scoreOf(Side.green), 10);
    await pumpClassic(tester, round);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE INTERRUPTION'));
    await tester.pumpAndSettle();

    expect(find.text('This also removes later actions'), findsOneWidget);
    expect(find.textContaining('Q1 Green 1 correct'), findsOneWidget);
    await tester.tap(find.text('REMOVE THESE TOO'));
    await tester.pumpAndSettle();

    expect(round.view.questionMarks[0].interrupted, isFalse);
    expect(round.cellOutcome(Side.green, 0, 1), isNull);
    expect(round.scoreOf(Side.green), 0);
    expect(round.scoreOf(Side.red), -5);
  });

  testWidgets('a voided slot reopens at the same value', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.voidQuestion();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);

    expect(round.currentValue(1), 10);
    expect(round.view.substituteValue(1), 10);
    expect(find.text('+10'), findsOneWidget);
  });

  testWidgets('footer exposes the More actions directly', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.setQuestionValue(1, 10);
    await pumpClassic(tester, round);

    expect(find.text('More'), findsNothing);
    expect(find.text('Interruption'), findsOneWidget);
    expect(find.text('Void question'), findsOneWidget);
    expect(find.text('Substitute quizzer'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets(
    'footer void clears the question and reopens it at the same value',
    (WidgetTester tester) async {
      final round = freshRound();
      round.setQuestionValue(1, 10);
      await pumpClassic(tester, round);

      await tester.tap(find.text('Void question'));
      await tester.pumpAndSettle();
      expect(round.view.questionMarks[0].voided, isTrue);
      expect(round.currentValue(1), 10);

      // Cleared, but immediately scoreable again at the same value.
      await tester.tap(find.text('Red 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CORRECT  +10'));
      await tester.pumpAndSettle();
      expect(round.scoreOf(Side.red), 10);
      expect(round.cellOutcome(Side.red, 0, 1), 'correct');
    },
  );

  testWidgets('a retracted answer does not make a voided cell editable', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    round.jumpToQuestion(1);
    round.voidQuestion();
    await pumpClassic(tester, round);

    expect(round.answerActionsAtCell(Side.red, 0, 1), isEmpty);
    expect(round.cellOutcome(Side.red, 0, 1), isNull);

    final semantics = tester.ensureSemantics();
    await tester.tap(
      find.bySemanticsLabel('Question 1, Red 1, current question'),
    );
    await tester.pumpAndSettle();

    // The empty cell navigates/selects; it must not open the answer editor.
    expect(find.text('Q1 \u00b7 RED'), findsNothing);
    expect(round.selected, (Side.red, 0));
    semantics.dispose();
  });

  testWidgets('voided editor offers void-again but no remove-substitute', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.voidQuestion();
    round.select(Side.green, 0);
    round.markCorrect();
    expect(round.scoreOf(Side.green), 10);
    await pumpClassic(tester, round);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.text('REMOVE SUBSTITUTE QUESTION'), findsNothing);
    expect(find.text('VOID QUESTION AGAIN'), findsOneWidget);

    await tester.tap(find.text('VOID QUESTION AGAIN'));
    await tester.pumpAndSettle();
    expect(round.view.questionMarks[0].voided, isTrue);
    expect(round.scoreOf(Side.green), 0);
    expect(round.currentValue(1), 10);
  });

  testWidgets('answered question editor exposes void', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round);
    expect(round.scoreOf(Side.red), 10);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.text('VOID QUESTION'), findsOneWidget);
    await tester.tap(find.text('VOID QUESTION'));
    await tester.pumpAndSettle();

    expect(round.view.questionMarks[0].voided, isTrue);
    expect(round.scoreOf(Side.red), 0);
    expect(round.currentValue(1), 10);
  });

  testWidgets('footer fits the 1024x700 minimum', (WidgetTester tester) async {
    final round = freshRound();
    round.setQuestionValue(1, 10);
    await pumpClassic(tester, round, size: const Size(1024, 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Void question'), findsOneWidget);
  });

  testWidgets('moving between cells keeps the same quizzer selected', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round);

    final semantics = tester.ensureSemantics();
    await tester.tap(
      find.bySemanticsLabel('Question 1, Red 1, current question'),
    );
    await tester.pumpAndSettle();
    expect(round.selected, (Side.red, 0));

    await tester.tap(find.bySemanticsLabel('Question 2, Red 1'));
    await tester.pumpAndSettle();
    expect(round.questionNumber, 2);
    expect(round.selected, (
      Side.red,
      0,
    ), reason: 'switching cells must not toggle the selected quizzer off');

    await tester.tap(find.bySemanticsLabel('Question 3, Red 1'));
    await tester.pumpAndSettle();
    expect(round.questionNumber, 3);
    expect(round.selected, (Side.red, 0));
    semantics.dispose();
  });

  testWidgets('the question editor fits at the live text-scale cap', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round, textScale: 2.0);

    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('editor-value-30')), findsOneWidget);
  });

  testWidgets('the editor dialog fits at the live text-scale cap', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    await pumpClassic(tester, round, textScale: 2.0);

    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('MARK INCORRECT'), findsOneWidget);
  });
}
