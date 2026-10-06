// Golden tests: JBQ 2026 preset (facts only — no rulebook prose).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/round_view.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadJbq() {
  final raw = File('assets/rulesets/jbq-2026.json').readAsStringSync();
  return Ruleset.fromJson(json.decode(raw) as Map<String, Object?>);
}

RoundView freshJbq({List<int>? values}) => RoundView(
  ruleset: loadJbq(),
  redLabels: const ['Red 1', 'Red 2', 'Red 3', 'Red 4'],
  greenLabels: const ['Green 1', 'Green 2', 'Green 3', 'Green 4'],
  questionValues: values,
);

void main() {
  group('JBQ preset loads', () {
    test('schema parses and values match the book distribution', () {
      final ruleset = loadJbq();
      expect(ruleset.id, 'jbq-2026');
      final tens = ruleset.match.pointValues.where((v) => v == 10).length;
      final twenties = ruleset.match.pointValues.where((v) => v == 20).length;
      final thirties = ruleset.match.pointValues.where((v) => v == 30).length;
      expect(tens, 10); // Q-sets §2
      expect(twenties, 7);
      expect(thirties, 3);
      expect(ruleset.scoring.quizOutCorrect, 6); // Scoring §1
      expect(ruleset.scoring.quizOutBonus, 10);
      expect(ruleset.scoring.quizOutLeavesMatch, isTrue); // must leave
      expect(ruleset.scoring.strikeOutIncorrect, 3); // Scoring §2
      expect(ruleset.limits.challengeAllotmentPerTeam, 2); // Skpr §5
    });
  });

  group('scoring differences vs TBQ', () {
    test('sixth correct triggers quiz-out +10 and leaves the match', () {
      final view = freshJbq(values: List.filled(20, 10));
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
      final team = view.teamOf(Side.red);
      expect(team.quizzers[0].correct, 6);
      expect(team.quizzers[0].score, 70); // 6×10 + 10
      expect(team.quizzers[0].status, 'QUIZ-OUT');
      expect(view.state.teams[Side.red]!.quizzers[0].leftMatch, isTrue);
    });

    test('fifth correct is NOT yet a quiz-out', () {
      final view = freshJbq(values: List.filled(20, 10));
      for (var n = 1; n <= 5; n++) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: 1,
            correct: true,
          ),
        );
      }
      expect(view.teamOf(Side.green).quizzers[1].status, '');
      expect(view.teamOf(Side.green).quizzers[1].score, 50);
    });

    test('strike-out leaves the match; other-person foul −5 team', () {
      final view = freshJbq(values: List.filled(20, 20));
      for (var n = 1; n <= 3; n++) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 2,
            correct: false,
          ),
        );
      }
      expect(view.teamOf(Side.red).quizzers[2].status, 'STRIKE-OUT');
      expect(view.state.teams[Side.red]!.quizzers[2].leftMatch, isTrue);
      view.apply(const FoulEvent(side: Side.green));
      expect(view.scoreOf(Side.green), -5);
    });

    test('substitute quizzer replaces an out quizzer immediately', () {
      final view = freshJbq(values: List.filled(20, 20));
      for (var n = 1; n <= 3; n++) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 0,
            correct: false,
          ),
        );
      }
      // The substitute ENTERS (appended): the out quizzer stays in the
      // roster so their points keep counting toward the team total.
      expect(
        view.apply(
          const SubstituteQuizzerEvent(
            side: Side.red,
            outIndex: 0,
            label: 'Red 5',
          ),
        ),
        isNull,
      );
      expect(view.state.teams[Side.red]!.quizzers.length, 5);
      // Red 1's 3 wrong (−30) still count after leaving.
      expect(view.scoreOf(Side.red), -30);
      // Replacing an active quizzer is rejected.
      final violation = view.apply(
        const SubstituteQuizzerEvent(
          side: Side.red,
          outIndex: 1,
          label: 'Red 6',
        ),
      );
      expect(violation!.code, 'quizzer-still-active');
      // Re-substituting the same slot is rejected too.
      final again = view.apply(
        const SubstituteQuizzerEvent(
          side: Side.red,
          outIndex: 0,
          label: 'Red 7',
        ),
      );
      expect(again!.code, 'quizzer-already-replaced');
    });
  });

  group('time-outs (Time-outs §§2, 4-5)', () {
    test('regulation allows three per team', () {
      final view = freshJbq();
      for (var i = 0; i < 3; i++) {
        expect(view.apply(const TimeOutEvent(side: Side.red)), isNull);
      }
      expect(view.teamOf(Side.red).timeOuts, 3);
      expect(
        view.apply(const TimeOutEvent(side: Side.red))!.code,
        'timeout-limit',
      );
      expect(view.teamOf(Side.red).timeOuts, 3);
    });

    test('overtime carries remaining time-outs plus one extra', () {
      final view = freshJbq();
      // Use two in regulation: one remains.
      for (var i = 0; i < 2; i++) {
        view.apply(const TimeOutEvent(side: Side.red));
      }
      // Enter overtime.
      expect(view.apply(const OvertimeQuestionEvent(value: 10)), isNull);
      // Remaining 1 + 1 extra = 2 more available → 4 total.
      expect(view.apply(const TimeOutEvent(side: Side.red)), isNull);
      expect(view.apply(const TimeOutEvent(side: Side.red)), isNull);
      expect(view.teamOf(Side.red).timeOuts, 4);
      expect(
        view.apply(const TimeOutEvent(side: Side.red))!.code,
        'timeout-limit',
      );
      expect(view.teamOf(Side.red).timeOuts, 4);
    });

    test('an unused regulation allotment still caps overtime at 4', () {
      final view = freshJbq();
      view.apply(const OvertimeQuestionEvent(value: 10));
      for (var i = 0; i < 4; i++) {
        expect(view.apply(const TimeOutEvent(side: Side.green)), isNull);
      }
      expect(view.teamOf(Side.green).timeOuts, 4); // 3 + 1
      expect(
        view.apply(const TimeOutEvent(side: Side.green))!.code,
        'timeout-limit',
      );
    });
  });
}
