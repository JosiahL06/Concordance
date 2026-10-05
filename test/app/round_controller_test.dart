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
}
