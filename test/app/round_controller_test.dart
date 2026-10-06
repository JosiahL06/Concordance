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

/// Plays a legal route to a 145-145 tie with the keeper on deck at Q20: Red
/// answers Q1..Q9 correctly (+150); Green answers Q10..Q17 correctly and
/// misses Q18 (10pt) and Q19 (20pt) for 145. Under the D10 guardrails each
/// question carries exactly one answer, so the old "both teams score every
/// question" tie is no longer reachable. A Red miss on Q20 (10pt, -5) then
/// forces the tie.
void playToTie(RoundController c) {
  for (var n = 1; n <= 9; n++) {
    c.jumpToQuestion(n);
    c.select(Side.red, (n - 1) % 4);
    expect(c.markCorrect(), isTrue);
  }
  for (var n = 10; n <= 19; n++) {
    c.jumpToQuestion(n);
    c.select(Side.green, (n - 1) % 4);
    if (n <= 17) {
      expect(c.markCorrect(), isTrue);
    } else {
      expect(c.markIncorrect(), isTrue);
    }
  }
}

RoundController freshJbq() => RoundController(
  ruleset: loadPreset('jbq-2026'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2', 'Red 3'],
  greenSeats: const ['Green 1', 'Green 2', 'Green 3'],
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

    test('incorrect on an interrupted question does NOT advance', () {
      final c = freshTbq();
      c.toggleInterruption(); // Q1 is interrupted
      c.select(Side.red, 0);
      expect(c.markIncorrect(), isTrue);
      // Interrupted questions are re-read to the other team: stay on Q1 so
      // the keeper can record the other team's re-read.
      expect(c.questionNumber, 1);
      expect(c.scoreOf(Side.red), -5);
      // Staying put is the only signal — no banner/alert.
      expect(c.lastAlert, isNull);
      expect(c.selected, isNull);
    });

    test('correct on an interrupted question still advances', () {
      final c = freshTbq();
      c.toggleInterruption();
      c.select(Side.red, 0);
      expect(c.markCorrect(), isTrue);
      expect(c.questionNumber, 2);
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

    test('time-outs cap at the allotment; a 4th request is denied', () {
      final c = freshTbq();
      expect(c.takeTimeOut(Side.red), isTrue);
      expect(c.takeTimeOut(Side.red), isTrue);
      expect(c.takeTimeOut(Side.red), isTrue);
      expect(c.teamOf(Side.red).timeOuts, 3);

      // Over-cap request: denied, not counted, and the keeper is told to
      // assign the team foul themselves.
      expect(c.takeTimeOut(Side.red), isFalse);
      expect(c.teamOf(Side.red).timeOuts, 3);
      expect(c.lastAlert, contains('denied'));
      expect(c.lastAlert, contains('team foul'));

      // The denied attempt is not journaled, so undo has nothing to revert.
      expect(c.undoLabel, 'time-out');
      expect(c.undo(), isTrue);
      expect(c.teamOf(Side.red).timeOuts, 2);
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

  group('notices do not repeat', () {
    test('quiz-out is announced once and stays silent on later answers', () {
      final c = freshTbq();
      for (var n = 1; n <= 5; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, 0);
        c.markCorrect();
      }
      expect(c.lastAlert, contains('quizzed out'));

      // The keeper may dismiss the banner; the notice must not come back.
      c.clearAlert();
      expect(c.lastAlert, isNull);

      // A later answer by a different quizzer must not re-fire the quiz-out.
      c.select(Side.green, 0);
      c.markCorrect();
      expect(c.lastAlert, isNull);
    });

    test('strike-out is announced once', () {
      final c = wideTbq();
      // Three incorrect answers strike a quizzer out (TBQ).
      for (var n = 1; n <= 3; n++) {
        c.jumpToQuestion(n);
        c.select(Side.green, 1);
        c.markIncorrect();
      }
      expect(c.teamOf(Side.green).quizzers[1].status, 'STRIKE-OUT');
      expect(c.lastAlert, contains('struck out'));

      c.select(Side.red, 0);
      c.markCorrect();
      expect(c.lastAlert, isNull);
    });

    test('denied time-out reminder does not repeat on later rulings', () {
      final c = freshTbq();
      // The first three are granted silently.
      for (var i = 0; i < 3; i++) {
        expect(c.takeTimeOut(Side.red), isTrue);
      }
      expect(c.lastAlert, isNull);

      // The 4th request is denied and the keeper is prompted to foul.
      expect(c.takeTimeOut(Side.red), isFalse);
      expect(c.lastAlert, contains('denied'));

      // The keeper dismisses it; a later ruling must not bring it back.
      c.clearAlert();
      c.select(Side.red, 0);
      c.markCorrect();
      expect(c.lastAlert, isNull);

      c.addTeamFoul(Side.green);
      expect(c.lastAlert, isNull);
    });

    test('an undone quiz-out is re-announced when it happens again', () {
      final c = freshTbq();
      for (var n = 1; n <= 5; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, 0);
        c.markCorrect();
      }
      expect(c.lastAlert, contains('quizzed out'));
      c.clearAlert();

      // Undo the 5th correct answer: the quiz-out is no longer in effect.
      c.undo();
      expect(c.teamOf(Side.red).quizzers[0].status, '');

      // The quizzer quizzes out again at a later question -> announced again.
      c.jumpToQuestion(6);
      c.select(Side.red, 0);
      c.markCorrect();
      expect(c.lastAlert, contains('quizzed out'));
    });

    test('a replaced quizzer substitute quizzes out and is announced', () {
      final c = freshTbq();
      for (var n = 1; n <= 5; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, 0);
        c.markCorrect();
      }
      expect(c.lastAlert, contains('quizzed out'));
      c.clearAlert();

      expect(
        c.substituteQuizzer(side: Side.red, outIndex: 0, label: 'Red 4'),
        isTrue,
      );
      expect(c.lastAlert, isNull);

      // The substitute (a distinct quizzer) quizzes out -> fresh notice.
      final sub = c.teamOf(Side.red).quizzers.length - 1;
      for (var n = 6; n <= 10; n++) {
        c.jumpToQuestion(n);
        c.select(Side.red, sub);
        c.markCorrect();
      }
      expect(c.lastAlert, contains('Red 4'));
      expect(c.lastAlert, contains('quizzed out'));
    });
    test('resume settles history so settled outs are not re-announced', () {
      final c = freshTbq();
      // Journal replay, exactly as the resume path does before any keeper
      // action: this controller never "saw" these rulings.
      for (var n = 1; n <= 5; n++) {
        c.view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
      expect(c.teamOf(Side.red).quizzers[0].status, 'QUIZ-OUT');

      c.markCurrentNoticesSeen();
      expect(c.lastAlert, isNull);

      // A later ruling on a *fresh* question must not replay the settled
      // quiz-out. (Q1 already carries Red 1's answer, so the D10 guardrails
      // would block a second answer there — jump on first.)
      c.jumpToQuestion(6);
      c.select(Side.green, 0);
      expect(c.markCorrect(), isTrue);
      expect(c.lastAlert, isNull);
    });
  });

  group('overtime (deterministic, no button)', () {
    test('regulation tie opens overtime automatically', () {
      final c = wideTbq();
      playToTie(c);
      // Red carries a 5-point lead into the final question.
      expect(c.scoreOf(Side.red) - c.scoreOf(Side.green), 5);

      // Q20 is worth 10: red answers wrong, erasing the 5-point lead.
      c.jumpToQuestion(20);
      c.select(Side.red, 3);
      expect(c.markIncorrect(), isTrue);

      expect(c.scoreOf(Side.red), c.scoreOf(Side.green), reason: 'tied');
      expect(c.questionCount, 21, reason: 'overtime question appended');
      expect(c.inOvertime, isTrue);
      expect(c.matchComplete, isFalse, reason: 'match continues in OT');
      expect(
        c.questionNumber,
        21,
        reason: 'already positioned on the OT question',
      );
      expect(
        c.currentValue(21),
        10,
        reason: 'TBQ sudden-death is a 10-pointer',
      );
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
      playToTie(c);
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
      playToTie(c);
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

  group('overtime time-outs (Time-outs §4)', () {
    test('JBQ carries remaining time-outs plus one extra in overtime', () {
      final c = freshJbq();
      expect(c.timeOutCap, 3);
      expect(c.timeOutDisplayCap(Side.red), 3);

      // Two used in regulation.
      c.takeTimeOut(Side.red);
      c.takeTimeOut(Side.red);
      expect(c.timeOutDisplayCap(Side.red), 3);

      // Enter overtime (append the overtime question as the fold does).
      c.view.apply(const OvertimeQuestionEvent(value: 10));
      expect(c.inOvertime, isTrue);
      expect(c.timeOutCap, 4); // remaining 1 + 1 extra
      expect(c.timeOutDisplayCap(Side.red), 4);

      // Two more are granted (totalling 4); the next is denied.
      expect(c.takeTimeOut(Side.red), isTrue);
      expect(c.takeTimeOut(Side.red), isTrue);
      expect(c.teamOf(Side.red).timeOuts, 4);
      expect(c.takeTimeOut(Side.red), isFalse);
      expect(c.teamOf(Side.red).timeOuts, 4);
    });

    test('TBQ allows no team time-out in overtime, with a clear denial', () {
      final c = freshTbq();
      c.takeTimeOut(Side.red); // one used, two "remaining"
      c.view.apply(const OvertimeQuestionEvent(value: 10));
      expect(c.inOvertime, isTrue);

      expect(c.timeOutCap, 0);
      // Display never drops below what was taken, so it reads "1/1".
      expect(c.timeOutDisplayCap(Side.red), 1);

      expect(c.takeTimeOut(Side.red), isFalse);
      expect(c.teamOf(Side.red).timeOuts, 1);
      expect(c.lastAlert, contains('overtime'));
      expect(c.lastAlert, contains('team foul'));
    });
  });
}
