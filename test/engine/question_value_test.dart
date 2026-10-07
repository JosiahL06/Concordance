// Live question values (schema decision D11). The rulebooks fix no
// per-question order: a regulation question starts unset and the keeper sets
// its value as it is read. The value locks once the question is answered,
// overtime slots are fixed by rule, and a voided slot takes its value from the
// substitute. Facts only.
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

/// A round with every regulation question left *unset* (the default).
RoundView unset() => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
);

AnswerEvent ans(Side side, int qi, {required bool correct, int q = 1}) =>
    AnswerEvent(
      questionNumber: q,
      side: side,
      quizzerIndex: qi,
      correct: correct,
    );

void main() {
  group('unset question blocks scoring', () {
    test('an answer on an unset question is rejected', () {
      final v = unset();
      final violation = v.apply(ans(Side.red, 0, correct: true));
      expect(violation, isNotNull);
      expect(violation!.code, 'question-value-unset');
      expect(v.scoreOf(Side.red), 0);
    });

    test('the console reads the same blocked reason', () {
      final v = unset();
      expect(v.answerBlockedReason(Side.red, 0, 1), contains('Set the point'));
    });
  });

  group('setting a value', () {
    test('a question scores at its assigned value', () {
      final v = unset();
      expect(
        v.apply(const QuestionValueEvent(questionNumber: 1, value: 30)),
        isNull,
      );
      expect(v.questionValues[0], 30);
      expect(v.apply(ans(Side.red, 0, correct: true)), isNull);
      expect(v.scoreOf(Side.red), 30);
    });

    test('half deduction follows the assigned value (30 -> -15)', () {
      final v = unset();
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 30));
      v.apply(ans(Side.green, 0, correct: false));
      expect(v.scoreOf(Side.green), -15);
    });

    test('re-setting before an answer changes the scored value', () {
      final v = unset();
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 10));
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 20));
      expect(v.questionValues[0], 20);
      v.apply(ans(Side.red, 0, correct: true));
      expect(v.scoreOf(Side.red), 20);
    });
  });

  group('guardrails', () {
    test('the value locks once the question is answered', () {
      final v = unset();
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 10));
      v.apply(ans(Side.red, 0, correct: true));
      final locked = v.apply(
        const QuestionValueEvent(questionNumber: 1, value: 30),
      );
      expect(locked!.code, 'question-value-locked');
      expect(v.questionValues[0], 10); // unchanged
    });

    test('a value outside the ruleset set is rejected', () {
      final v = unset();
      final bad = v.apply(
        const QuestionValueEvent(questionNumber: 1, value: 25),
      );
      expect(bad!.code, 'question-value-not-allowed');
      expect(v.questionValues[0], isNull);
    });

    test('an overtime question value is fixed by rule', () {
      final v = unset();
      v.apply(const OvertimeQuestionEvent(value: 10)); // appends Q21
      final fixed = v.apply(
        const QuestionValueEvent(questionNumber: 21, value: 20),
      );
      expect(fixed!.code, 'question-value-overtime-fixed');
      expect(v.questionValues[20], 10);
    });

    test('a voided question takes its value from the substitute', () {
      final v = unset();
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 10));
      v.apply(const VoidQuestionEvent(questionNumber: 1));
      final voided = v.apply(
        const QuestionValueEvent(questionNumber: 1, value: 20),
      );
      expect(voided!.code, 'question-value-voided');
    });

    test('an out-of-range question is rejected', () {
      final v = unset();
      final bad = v.apply(
        const QuestionValueEvent(questionNumber: 999, value: 10),
      );
      expect(bad!.code, 'question-range');
    });
  });

  group('editable read + undo', () {
    test('questionValueEditable tracks the guards', () {
      final v = unset();
      expect(v.questionValueEditable(1), isTrue);
      v.apply(const QuestionValueEvent(questionNumber: 1, value: 10));
      expect(v.questionValueEditable(1), isTrue); // still un-answered
      v.apply(ans(Side.red, 0, correct: true));
      expect(v.questionValueEditable(1), isFalse); // locked by an answer
      v.apply(const OvertimeQuestionEvent(value: 10));
      expect(v.questionValueEditable(21), isFalse); // overtime is fixed
    });

    test('undo reverts a value change', () {
      final v = unset();
      v.apply(const QuestionValueEvent(questionNumber: 3, value: 30));
      expect(v.questionValues[2], 30);
      expect(v.undo(), isTrue);
      expect(v.questionValues[2], isNull);
    });
  });
}
