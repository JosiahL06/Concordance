// Quiz-out substitution prompts: a seated quizzer who quizzes out while an
// eligible bench quizzer exists produces a persistent prompt; dismissing it,
// substituting, and undoing the quiz-out all behave predictably.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

const kTbqValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundController fresh({
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
  questionValues: kTbqValues,
);

void quizOutRedOne(RoundController c) {
  for (var n = 1; n <= 5; n++) {
    c.jumpToQuestion(n);
    c.select(Side.red, 0);
    c.markCorrect();
  }
}

void main() {
  test('a quiz-out with a bench quizzer creates a prompt', () {
    final c = fresh();
    expect(c.substitutionPrompt, isNull);
    quizOutRedOne(c);

    final prompt = c.substitutionPrompt;
    expect(prompt, isNotNull);
    expect(prompt!.side, Side.red);
    expect(prompt.outIndex, 0);
    expect(prompt.outLabel, 'Red 1');
    expect(prompt.outSeat, 1);
    expect(prompt.benchCount, 2);
    expect(prompt.onlyBench, isNull);
    expect(c.hasSubstitutionOptions, isTrue);
  });

  test('no bench means no prompt', () {
    final c = fresh(redBench: const [], greenBench: const []);
    quizOutRedOne(c);
    expect(c.substitutionPrompt, isNull);
    expect(c.hasSubstitutionOptions, isFalse);
  });

  test('dismissing hides the prompt until the quiz-out changes', () {
    final c = fresh();
    quizOutRedOne(c);
    expect(c.substitutionPrompt, isNotNull);

    c.dismissSubstitutionPrompt();
    expect(c.substitutionPrompt, isNull);
    expect(c.lastAlert, isNull, reason: 'the prompt is the quiz-out notice');

    // Undo the fifth correct: the quizzer is no longer out, which re-arms the
    // dismissal. Quiz out again and the prompt returns.
    c.undo();
    expect(c.substitutionPrompt, isNull);
    c.jumpToQuestion(5);
    c.select(Side.red, 0);
    c.markCorrect();
    expect(c.substitutionPrompt, isNotNull);
  });

  test('substituting the quizzed-out quizzer clears the prompt', () {
    final c = fresh();
    quizOutRedOne(c);
    expect(c.substitutionPrompt, isNotNull);

    expect(
      c.substituteQuizzer(side: Side.red, outIndex: 0, benchIndex: 2),
      isTrue,
    );
    expect(c.substitutionPrompt, isNull);
    expect(c.teamOf(Side.red).bench.first.label, 'Red 1');
    expect(c.teamOf(Side.red).seated.first.label, 'Red 3');
  });

  test('a second quiz-out replaces the prompt with the newest', () {
    final c = fresh();
    quizOutRedOne(c);
    final first = c.substitutionPrompt!;
    expect(first.outLabel, 'Red 1');

    // Red 2 quizzes out later; the newest prompt should win.
    for (var n = 6; n <= 10; n++) {
      c.jumpToQuestion(n);
      c.select(Side.red, 1);
      c.markCorrect();
    }
    final second = c.substitutionPrompt;
    expect(second, isNotNull);
    expect(second!.outIndex, 1);
    expect(second.outLabel, 'Red 2');
  });
}
