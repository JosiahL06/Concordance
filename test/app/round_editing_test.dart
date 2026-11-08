// Controller coverage for direct answer/question edits: in-place replacement,
// removal, dependency confirmation, value changes after an answer, and the
// one-level undo-edit snapshot.
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

RoundController fresh() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  redBench: const ['Red 3'],
  greenBench: const ['Green 3'],
  questionValues: kTbqValues,
);

void score(RoundController c, Side side, int index, {bool correct = true}) {
  c.select(side, index);
  if (correct) {
    c.markCorrect();
  } else {
    c.markIncorrect();
  }
}

void main() {
  group('answer editing', () {
    test('change correct to incorrect replaces the event in place', () {
      final c = fresh();
      score(c, Side.red, 0);
      final index = c.answerActionsAtCell(Side.red, 0, 1).single.index;

      final outcome = c.changeAnswer(index, correct: false);
      expect(outcome.applied, isTrue);
      expect(c.scoreOf(Side.red), -5);
      expect(c.cellOutcome(Side.red, 0, 1), 'incorrect');
      expect(c.view.journal, hasLength(1));
      expect((c.view.journal.single as AnswerEvent).correct, isFalse);
      expect(c.lastEditLabel, contains('marked incorrect'));
      expect(c.canUndoLastEdit, isTrue);
    });

    test(
      'removing an answer returns to the question and selects the quizzer',
      () {
        final c = fresh();
        score(c, Side.red, 0);
        expect(c.questionNumber, 2);
        final index = c.answerActionsAtCell(Side.red, 0, 1).single.index;

        final outcome = c.removeAnswer(index);
        expect(outcome.applied, isTrue);
        expect(c.scoreOf(Side.red), 0);
        expect(c.view.journal, isEmpty);
        expect(c.questionNumber, 1);
        expect(c.selected, (Side.red, 0));
        expect(c.cellOutcome(Side.red, 0, 1), isNull);
      },
    );

    test('an out quizzer\'s recorded answer remains editable', () {
      final c = fresh();
      for (var n = 1; n <= 5; n++) {
        c.jumpToQuestion(n);
        score(c, Side.red, 0);
      }
      expect(c.teamOf(Side.red).roster[0].status, 'QUIZ-OUT');
      final index = c.answerActionsAtCell(Side.red, 0, 1).single.index;
      expect(c.changeAnswer(index, correct: false).applied, isTrue);
      expect(c.cellOutcome(Side.red, 0, 1), 'incorrect');
    });

    test('undo edit restores the journal and is cleared by normal scoring', () {
      final c = fresh();
      score(c, Side.red, 0);
      final index = c.answerActionsAtCell(Side.red, 0, 1).single.index;
      c.changeAnswer(index, correct: false);
      expect(c.scoreOf(Side.red), -5);

      expect(c.undoLastEdit(), isTrue);
      expect(c.scoreOf(Side.red), 10);
      expect(c.cellOutcome(Side.red, 0, 1), 'correct');
      expect(c.canUndoLastEdit, isFalse);

      // A fresh edit snapshot is dropped as soon as a normal ruling is made.
      c.changeAnswer(index, correct: false);
      expect(c.canUndoLastEdit, isTrue);
      c.jumpToQuestion(2);
      score(c, Side.green, 0);
      expect(c.canUndoLastEdit, isFalse);
    });

    test('a rewrite hook is used instead of the delta autosave', () {
      final c = fresh();
      var deltas = 0;
      var rewrites = 0;
      c.autosave = (_) => deltas++;
      c.rewriteAutosave = (_) => rewrites++;
      score(c, Side.red, 0);
      final index = c.answerActionsAtCell(Side.red, 0, 1).single.index;
      c.changeAnswer(index, correct: false);
      expect(deltas, 1);
      expect(rewrites, 1);
    });
  });

  group('question editing', () {
    test('void clears the question and reopens it at the same value', () {
      final c = fresh();
      score(c, Side.red, 0);
      c.jumpToQuestion(1);
      expect(c.scoreOf(Side.red), 10);

      final outcome = c.voidQuestion();
      expect(outcome.applied, isTrue);
      expect(c.scoreOf(Side.red), 0);
      expect(c.view.questionMarks[0].voided, isTrue);
      expect(c.currentValue(1), 10);
      expect(c.view.substituteValue(1), 10);
      expect(c.view.journal.last, isA<VoidQuestionEvent>());
      expect((c.view.journal.last as VoidQuestionEvent).substituteValue, 10);
      expect(c.lastEditLabel, contains('substitute reads at 10'));
      // The retracted answer is historical journal data, not an editable cell.
      expect(c.answerActionsAtCell(Side.red, 0, 1), isEmpty);

      // The cleared slot is immediately scoreable again.
      expect(c.markCorrect(), isFalse, reason: 'no quizzer selected');
      c.select(Side.green, 0);
      expect(c.markCorrect(), isTrue);
      expect(c.scoreOf(Side.green), 10);
      expect(c.answerActionsAtCell(Side.green, 0, 1), hasLength(1));
      expect(c.answerActionsAtCell(Side.red, 0, 1), isEmpty);

      // One Undo reverses the substitute answer; the void remains. A second
      // Undo restores the original answer because the void was one event.
      expect(c.undo(), isTrue);
      expect(c.view.questionMarks[0].voided, isTrue);
      expect(c.undo(), isTrue);
      expect(c.view.questionMarks[0].voided, isFalse);
      expect(c.scoreOf(Side.red), 10);
    });

    test('the footer only offers void when the current slot has a value', () {
      final c = RoundController(
        ruleset: loadPreset('tbq-25-26'),
        redName: 'Red',
        greenName: 'Green',
        redSeats: const ['Red 1'],
        greenSeats: const ['Green 1'],
      );
      expect(c.currentValue(1), isNull);
      expect(c.canVoidCurrentQuestion, isFalse);
      c.setQuestionValue(1, 20);
      expect(c.canVoidCurrentQuestion, isTrue);
      c.voidQuestionAt(1);
      expect(c.currentValue(1), 20);
      expect(c.canVoidCurrentQuestion, isTrue);
    });

    test('value can change after the question was answered', () {
      final c = fresh();
      score(c, Side.red, 0);
      expect(c.scoreOf(Side.red), 10);
      expect(c.questionValueEditable(1), isFalse);

      final outcome = c.changeQuestionValue(1, 30);
      expect(outcome.applied, isTrue);
      expect(c.currentValue(1), 30);
      expect(c.scoreOf(Side.red), 30);
      expect(c.cellOutcome(Side.red, 0, 1), 'correct');
    });

    test('removing an interruption reports the dependent re-read', () {
      final c = fresh();
      c.toggleInterruption();
      score(c, Side.red, 0, correct: false);
      score(c, Side.green, 0);
      expect(c.scoreOf(Side.green), 10);

      final blocked = c.removeInterruption(1);
      expect(blocked.applied, isFalse);
      expect(blocked.conflicts, hasLength(1));
      expect(
        c.describeEvent(blocked.conflicts.single.event),
        contains('Green'),
      );

      final applied = c.removeInterruption(1, allowDependentRemoval: true);
      expect(applied.applied, isTrue);
      expect(c.view.questionMarks[0].interrupted, isFalse);
      expect(c.cellOutcome(Side.green, 0, 1), isNull);
      expect(c.scoreOf(Side.green), 0);
      expect(c.scoreOf(Side.red), -5);
    });

    test(
      'removing a void restores the original answer and drops the substitute',
      () {
        final c = fresh();
        score(c, Side.red, 0);
        c.jumpToQuestion(1);
        c.voidQuestion();
        expect(c.scoreOf(Side.red), 0);
        score(c, Side.green, 0);
        expect(c.scoreOf(Side.green), 10);

        final blocked = c.removeVoid(1);
        expect(blocked.applied, isFalse);
        expect(blocked.conflicts, isNotEmpty);

        final applied = c.removeVoid(1, allowDependentRemoval: true);
        expect(applied.applied, isTrue);
        expect(c.view.questionMarks[0].voided, isFalse);
        expect(c.cellOutcome(Side.red, 0, 1), 'correct');
        expect(c.cellOutcome(Side.green, 0, 1), isNull);
        expect(c.scoreOf(Side.red), 10);
        expect(c.scoreOf(Side.green), 0);
      },
    );

    test('voiding again clears the substitute read at the same value', () {
      final c = fresh();
      score(c, Side.red, 0);
      c.jumpToQuestion(1);
      c.voidQuestion();
      score(c, Side.green, 0);
      expect(c.scoreOf(Side.green), 10);
      expect(c.answerActionsAtCell(Side.green, 0, 1), hasLength(1));

      final applied = c.voidQuestionAt(1);
      expect(applied.applied, isTrue);
      expect(c.view.questionMarks[0].voided, isTrue);
      expect(c.currentValue(1), 10);
      expect(c.scoreOf(Side.green), 0);
      expect(c.answerActionsAtCell(Side.green, 0, 1), isEmpty);
      expect(c.view.journal.whereType<VoidQuestionEvent>(), hasLength(2));
    });

    test('a voided question cannot change its own value', () {
      final c = fresh();
      c.voidQuestion();
      final outcome = c.changeQuestionValue(1, 20);
      expect(outcome.applied, isFalse);
      expect(c.currentValue(1), 10);
      expect(c.lastAlert, contains('void'));
    });
  });
}
