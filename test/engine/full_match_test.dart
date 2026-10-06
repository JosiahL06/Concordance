// Full-match simulations with hand-computed expectations (facts only).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/round_view.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadPreset(String id) {
  final raw = File('assets/rulesets/$id.json').readAsStringSync();
  return Ruleset.fromJson(json.decode(raw) as Map<String, Object?>);
}

RoundView freshView(String id, List<int> values) => RoundView(
  ruleset: loadPreset(id),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
  redBench: const ['Red 3', 'Red 4'],
  greenBench: const ['Green 3', 'Green 4'],
  questionValues: values,
);

void main() {
  group('full regulation match', () {
    test('TBQ: mixed answers incl. quiz-out, strike-out, fouls', () {
      // Q values: 10,20,10,20,30,10,20,10,20,10, 30,20,10,20,10,20,30,10,20,10
      final view = freshView('tbq-25-26', [
        10,
        20,
        10,
        20,
        30,
        10,
        20,
        10,
        20,
        10,
        30,
        20,
        10,
        20,
        10,
        20,
        30,
        10,
        20,
        10,
      ]);
      // Red 1: Q1 correct(+10), Q2 correct(+20), Q4 correct(+20),
      // Q6 correct(+10), Q8 correct(+10) → 5 correct → +20 bonus = 90.
      for (final n in [1, 2, 4, 6, 8]) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
      // Green 1: Q3, Q5, Q7 wrong → strike out: −5 −15 −10 = −30.
      for (final n in [3, 5, 7]) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: 0,
            correct: false,
          ),
        );
      }
      // Red 2: Q9 wrong(−10), Q10 correct(+10) → 0.
      view.apply(
        const AnswerEvent(
          questionNumber: 9,
          side: Side.red,
          quizzerIndex: 1,
          correct: false,
        ),
      );
      view.apply(
        const AnswerEvent(
          questionNumber: 10,
          side: Side.red,
          quizzerIndex: 1,
          correct: true,
        ),
      );
      // Green 2: Q11 correct(+30), foul on Q12 (−5) → 25.
      view.apply(
        const AnswerEvent(
          questionNumber: 11,
          side: Side.green,
          quizzerIndex: 1,
          correct: true,
        ),
      );
      view.apply(
        const FoulEvent(questionNumber: 12, side: Side.green, quizzerIndex: 1),
      );
      // Red team foul (coach) → −5 team.
      view.apply(const FoulEvent(side: Side.red));
      // Remaining questions unanswered (no-response).
      expect(view.scoreOf(Side.red), 90 + 0 - 5);
      expect(view.scoreOf(Side.green), -30 + 25);
      // Ledger spot-checks (Classic reads).
      expect(view.cellOutcome(Side.red, 0, 1), 'correct');
      expect(view.teamDelta(Side.red, 8), 10 + 20); // value + bonus crossing
      expect(view.teamDelta(Side.green, 5), -15);
      expect(view.teamOf(Side.red).roster[0].status, 'QUIZ-OUT');
      expect(view.teamOf(Side.green).roster[0].status, 'STRIKE-OUT');
    });

    test('JBQ: quiz-out at six with +10 and leave', () {
      final view = freshView('jbq-2026', List.filled(20, 10));
      for (var n = 1; n <= 6; n++) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
      expect(view.teamOf(Side.red).roster[0].score, 70);
      // A bench quizzer comes in and answers Q7 correctly → team keeps
      // scoring. (Red 3 is roster index 2 and was on the bench.)
      view.apply(
        const SubstituteQuizzerEvent(
          side: Side.red,
          outIndex: 0,
          benchIndex: 2,
        ),
      );
      view.apply(
        const AnswerEvent(
          questionNumber: 7,
          side: Side.red,
          quizzerIndex: 2,
          correct: true,
        ),
      );
      expect(view.scoreOf(Side.red), 80);
    });
  });

  group('dual-mode consistency (same journal, both views)', () {
    test('Modern totals equal Classic ledger sums', () {
      final view = freshView('tbq-25-26', List.filled(20, 20));
      view.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      view.apply(
        const AnswerEvent(
          questionNumber: 2,
          side: Side.green,
          quizzerIndex: 0,
          correct: false,
        ),
      );
      view.apply(
        const FoulEvent(questionNumber: 3, side: Side.red, quizzerIndex: 1),
      );
      for (final side in Side.values) {
        var ledgerSum = 0;
        for (var n = 1; n <= 3; n++) {
          ledgerSum += view.teamDelta(side, n);
        }
        // Modern team score == sum of Classic RUNNING deltas.
        expect(ledgerSum, view.scoreOf(side));
      }
    });
  });
}
