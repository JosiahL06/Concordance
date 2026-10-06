// Answer guardrails (schema decision D10). A question slot admits at most one
// answer per quizzer, one answer per team, and one correct answer overall — a
// correct answer closes the question to both teams. Facts only, no rulebook
// prose.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/round_view.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadTbq() => Ruleset.fromJson(
  json.decode(File('assets/rulesets/tbq-25-26.json').readAsStringSync())
      as Map<String, Object?>,
);

RoundView fresh({List<int>? values}) => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
  questionValues: values,
);

AnswerEvent ans(Side side, int qi, {required bool correct, int q = 1}) =>
    AnswerEvent(
      questionNumber: q,
      side: side,
      quizzerIndex: qi,
      correct: correct,
    );

void main() {
  group('one answer per quizzer', () {
    test('the same quizzer cannot answer twice after a wrong answer', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: false)), isNull);
      final again = v.apply(ans(Side.red, 0, correct: true));
      expect(again, isNotNull);
      expect(again!.code, 'answer-quizzer-twice');
    });

    test('the same quizzer cannot answer twice after a correct answer', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      final again = v.apply(ans(Side.red, 0, correct: true));
      expect(again!.code, 'answer-quizzer-twice');
    });
  });

  group('one answer per team', () {
    test('a teammate cannot answer after a teammate answered correctly', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      final mate = v.apply(ans(Side.red, 1, correct: false));
      expect(mate!.code, 'answer-team-twice');
    });

    test('a teammate cannot answer after a teammate answered incorrectly', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: false)), isNull);
      final mate = v.apply(ans(Side.red, 1, correct: true));
      expect(mate!.code, 'answer-team-twice');
    });

    test('an interrupted miss lets the opposing team answer', () {
      final v = fresh();
      v.apply(const InterruptionEvent(questionNumber: 1));
      expect(v.apply(ans(Side.red, 0, correct: false)), isNull);
      expect(v.apply(ans(Side.green, 0, correct: true)), isNull);
    });

    test('a non-interrupted miss closes the question to the other team', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: false)), isNull);
      // A miss without an interruption is not reread -> the other team is out.
      final other = v.apply(ans(Side.green, 0, correct: true));
      expect(other!.code, 'answer-no-reread');
      // Marking the miss interrupted (the correction path) re-opens it.
      v.apply(const InterruptionEvent(questionNumber: 1));
      expect(v.apply(ans(Side.green, 0, correct: true)), isNull);
    });
  });

  group('one correct answer per question', () {
    test('a second positive anywhere is rejected', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      final green = v.apply(ans(Side.green, 0, correct: true));
      expect(green!.code, 'answer-question-closed');
    });

    test('a correct answer closes the question to a wrong answer too', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      final green = v.apply(ans(Side.green, 0, correct: false));
      expect(green!.code, 'answer-question-closed');
    });

    test('up to two negatives (one per team) are allowed, and no more', () {
      final v = fresh();
      // An interrupted miss is reread, so both teams get a shot.
      v.apply(const InterruptionEvent(questionNumber: 1));
      expect(v.apply(ans(Side.red, 0, correct: false)), isNull);
      expect(v.apply(ans(Side.green, 0, correct: false)), isNull);
      // Both teams have answered: a third answer is blocked for either side.
      expect(
        v.apply(ans(Side.red, 1, correct: true))!.code,
        'answer-team-twice',
      );
      expect(
        v.apply(ans(Side.green, 1, correct: false))!.code,
        'answer-team-twice',
      );
    });
  });

  group('ledger lifecycle', () {
    test('undo clears the answer so the question opens again', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      expect(v.undo(), isTrue);
      expect(v.apply(ans(Side.red, 1, correct: true)), isNull);
    });

    test('a voided question clears its answers for the substitute read', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true, q: 4)), isNull);
      expect(v.apply(const VoidQuestionEvent(questionNumber: 4)), isNull);
      expect(
        v.apply(const SubstituteQuestionEvent(questionNumber: 4, value: 20)),
        isNull,
      );
      // The substitute reads fresh: the pre-void answer no longer blocks.
      expect(v.apply(ans(Side.red, 0, correct: true, q: 4)), isNull);
    });

    test('a blocked answer does not move the score', () {
      final v = fresh();
      v.apply(ans(Side.red, 0, correct: true));
      final before = v.scoreOf(Side.red);
      expect(v.apply(ans(Side.green, 0, correct: true)), isNotNull);
      expect(v.scoreOf(Side.green), 0);
      expect(v.scoreOf(Side.red), before);
    });

    test('answerBlockedReason names the blocking rule for the console', () {
      final v = fresh();
      v.apply(ans(Side.red, 0, correct: true));
      expect(v.answerBlockedReason(Side.red, 0, 1), contains('Red 1'));
      expect(v.answerBlockedReason(Side.green, 0, 1), contains('correct'));
      expect(v.answerBlockedReason(Side.green, 0, 2), isNull);
    });
  });

  group('void retracts answer points (D3)', () {
    test('a voided correct answer leaves the score and the cell', () {
      final v = fresh();
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      expect(v.scoreOf(Side.red), 10);
      expect(v.teamDelta(Side.red, 1), 10);

      expect(v.apply(const VoidQuestionEvent(questionNumber: 1)), isNull);
      expect(v.scoreOf(Side.red), 0, reason: 'points retracted');
      expect(v.cellOutcome(Side.red, 0, 1), isNull);
      expect(v.teamDelta(Side.red, 1), 0);
    });

    test('a voided wrong answer is retracted too', () {
      final v = fresh(values: List.filled(20, 20)); // Q1 = 20pt
      v.apply(ans(Side.red, 0, correct: false));
      expect(v.scoreOf(Side.red), -10);
      v.apply(const VoidQuestionEvent(questionNumber: 1));
      expect(v.scoreOf(Side.red), 0);
    });

    test('fouls on the slot survive voiding', () {
      final v = fresh();
      v.apply(ans(Side.red, 0, correct: true, q: 4)); // Q4 = 20pt → +20
      v.apply(
        const FoulEvent(questionNumber: 4, side: Side.red, quizzerIndex: 0),
      );
      expect(v.scoreOf(Side.red), 15); // +20 − 5
      v.apply(const VoidQuestionEvent(questionNumber: 4));
      expect(v.scoreOf(Side.red), -5, reason: 'answer retracted, foul kept');
      expect(v.cellOutcome(Side.red, 0, 4), isNull);
      expect(v.cellHasFoul(Side.red, 0, 4), isTrue, reason: 'foul survives');
    });

    test('voiding the quiz-out crossing revokes the out and its bonus', () {
      final v = fresh();
      for (var n = 1; n <= 5; n++) {
        v.apply(ans(Side.red, 0, correct: true, q: n));
      }
      expect(v.teamOf(Side.red).quizzers[0].status, 'QUIZ-OUT');
      expect(v.scoreOf(Side.red), 110); // 90 + 20 bonus

      v.apply(const VoidQuestionEvent(questionNumber: 5)); // Q5 = 30pt
      final quizzer = v.teamOf(Side.red).quizzers[0];
      expect(quizzer.status, '', reason: 'no longer quizzed out');
      expect(quizzer.correct, 4);
      expect(v.scoreOf(Side.red), 60, reason: 'Q5 (30) + bonus (20) removed');
    });

    test('undo restores a voided answer via a full re-fold', () {
      final v = fresh();
      v.apply(ans(Side.red, 0, correct: true));
      v.apply(const VoidQuestionEvent(questionNumber: 1));
      expect(v.scoreOf(Side.red), 0);
      expect(v.undo(), isTrue);
      expect(v.scoreOf(Side.red), 10);
      expect(v.cellOutcome(Side.red, 0, 1), 'correct');
    });

    test('a substitute read after a void scores fresh', () {
      final v = fresh();
      v.apply(ans(Side.red, 0, correct: true, q: 4)); // 20pt → +20
      v.apply(const VoidQuestionEvent(questionNumber: 4));
      v.apply(const SubstituteQuestionEvent(questionNumber: 4, value: 20));
      expect(v.apply(ans(Side.green, 0, correct: true, q: 4)), isNull);
      expect(v.scoreOf(Side.red), 0, reason: 'red answer retracted');
      expect(v.scoreOf(Side.green), 20);
      expect(v.teamDelta(Side.green, 4), 20);
    });
  });
}
