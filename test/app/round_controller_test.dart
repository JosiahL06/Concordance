// Adapter tests: RoundController maps the interaction-spec console contract
// onto RoundView events + view state (selection/position/alerts/advance).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadPreset(String id) {
  final raw = File('assets/rulesets/$id.json').readAsStringSync();
  return Ruleset.fromJson(json.decode(raw) as Map<String, Object?>);
}

RoundController freshTbq() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
);

RoundController wideTbq() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2', 'Red 3', 'Red 4'],
  greenSeats: const ['Green 1', 'Green 2', 'Green 3', 'Green 4'],
);


void main() {
  group('console contract', () {
    test('correct advances, clears selection, repaints scores', () {
      final c = freshTbq();
      c.select(Side.red, 0);
      expect(c.markCorrect(), isTrue);
      expect(c.questionNumber, 2);
      expect(c.selected, isNull);
      expect(c.scoreOf(Side.red), 10);
      expect(c.undoLabel, 'correct answer');
    });

    test('incorrect advances with half deduction', () {
      final c = freshTbq();
      c.select(Side.green, 0);
      expect(c.markIncorrect(), isTrue);
      expect(c.questionNumber, 2);
      expect(c.scoreOf(Side.green), -5);
    });

    test('quizzer foul stays on question and clears selection', () {
      final c = freshTbq();
      c.select(Side.red, 0);
      expect(c.addQuizzerFoul(), isTrue);
      expect(c.questionNumber, 1);
      expect(c.selected, isNull);
      expect(c.scoreOf(Side.red), -5);
    });

    test('team foul needs no selection, hits team total only', () {
      final c = freshTbq();
      expect(c.addTeamFoul(Side.green), isTrue);
      expect(c.scoreOf(Side.green), -5);
      expect(c.cellOutcome(Side.green, 0, 1), isNull);
    });

    test('fourth time-out request alerts', () {
      final c = freshTbq();
      c.takeTimeOut(Side.red);
      c.takeTimeOut(Side.red);
      c.takeTimeOut(Side.red);
      c.takeTimeOut(Side.red);
      expect(c.teamOf(Side.red).timeOuts, 4);
      expect(c.lastAlert, contains('4th time-out'));
    });

    test('undo restores scores and label clears', () {
      final c = freshTbq();
      c.select(Side.red, 0);
      c.markCorrect();
      expect(c.undo(), isTrue);
      expect(c.scoreOf(Side.red), 0);
      expect(c.canUndo, isFalse);
      expect(c.undoLabel, isNull);
    });

    test('jump moves position without journaling', () {
      final c = freshTbq();
      c.jumpToQuestion(7);
      expect(c.questionNumber, 7);
      expect(c.canUndo, isFalse);
    });

    test('quiz-out fires bonus, flag and alert (TBQ 5th correct)', () {
      final c = freshTbq();
      for (var n = 1; n <= 5; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, 0);
        c.markCorrect();
      }
      final q = c.teamOf(Side.red).quizzers[0];
      expect(q.status, 'QUIZ-OUT');
      expect(c.lastAlert, contains('quizzed out'));
    });
  });

  group('overtime (deterministic, no button)', () {
    test('regulation tie opens overtime automatically', () {
      final c = wideTbq();
      // Green answers Q1 wrong: red leads by 5 (half of a 10-pointer).
      c.select(Side.green, 0);
      expect(c.markIncorrect(), isTrue);
      // Q2..Q19 both teams identical.
      for (var n = 2; n <= 19; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, (n - 1) % 4);
        expect(c.markCorrect(), isTrue);
        c.jumpToQuestion(n);
        c.select(Side.green, (n - 1) % 4);
        expect(c.markCorrect(), isTrue);
      }
      expect(c.scoreOf(Side.red) - c.scoreOf(Side.green), 5);

      // Q20 is worth 10: red answers wrong, erasing the 5-point lead.
      c.jumpToQuestion(20);
      c.select(Side.red, 3);
      expect(c.markIncorrect(), isTrue);

      expect(c.scoreOf(Side.red), c.scoreOf(Side.green), reason: 'tied');
      expect(c.questionCount, 21, reason: 'overtime question appended');
      expect(c.inOvertime, isTrue);
      expect(c.matchComplete, isFalse, reason: 'match continues in OT');
      expect(c.questionNumber, 21, reason: 'already positioned on the OT question');
      expect(c.currentValue(21), 10, reason: 'TBQ sudden-death is a 10-pointer');
      expect(c.lastAlert, contains('overtime question 21'));
    });

    test('a lead at the final question ends the match (no overtime)', () {
      final c = wideTbq();
      c.jumpToQuestion(20);
      c.select(Side.red, 0);
      expect(c.markCorrect(), isTrue);

      expect(c.matchComplete, isTrue);
      expect(c.questionCount, 20, reason: 'no overtime question added');
      expect(c.inOvertime, isFalse);
      expect(c.lastAlert, contains('wins'));
      expect(c.lastAlert, contains('match complete'));
    });

    test('one undo reverts the OT question and the answer that forced it', () {
      final c = wideTbq();
      c.select(Side.green, 0);
      c.markIncorrect();
      for (var n = 2; n <= 19; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, (n - 1) % 4);
        c.markCorrect();
        c.jumpToQuestion(n);
        c.select(Side.green, (n - 1) % 4);
        c.markCorrect();
      }
      c.jumpToQuestion(20);
      c.select(Side.red, 3);
      c.markIncorrect();
      expect(c.questionCount, 21);

      expect(c.undo(), isTrue);

      expect(c.questionCount, 20, reason: 'auto-added OT question removed');
      expect(c.questionNumber, 20, reason: 'screen position clamped back');
      expect(c.matchComplete, isFalse);
      expect(
        c.questionAnswered(20),
        isFalse,
        reason: 'the tie-forcing answer was reverted, so Q20 can be re-scored',
      );
    });

    test('undo keeps undoing after overtime was opened', () {
      final c = wideTbq();
      c.select(Side.green, 0);
      c.markIncorrect();
      for (var n = 2; n <= 19; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, (n - 1) % 4);
        c.markCorrect();
        c.jumpToQuestion(n);
        c.select(Side.green, (n - 1) % 4);
        c.markCorrect();
      }
      c.jumpToQuestion(20);
      c.select(Side.red, 3);
      c.markIncorrect();
      expect(c.questionCount, 21);

      c.undo();
      expect(c.questionCount, 20);
      // Undo is not stuck in a re-open loop: a second undo keeps working.
      expect(c.undo(), isTrue);
      expect(c.questionCount, 20);
      expect(c.canUndo, isTrue);
    });
  });

}
