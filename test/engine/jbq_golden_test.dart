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

/// A representative JBQ regulation value list for the goldens (no built-in
/// per-question order — D11).
const kJbqValues = <int>[
  10, 10, 20, 10, 20, 30, 10, 20, 10, 10, //
  20, 10, 30, 20, 10, 10, 20, 30, 10, 20,
];

RoundView freshJbq({List<int>? values}) => RoundView(
  ruleset: loadJbq(),
  redLabels: const ['Red 1', 'Red 2', 'Red 3', 'Red 4'],
  greenLabels: const ['Green 1', 'Green 2', 'Green 3', 'Green 4'],
  redBench: const ['Red 5', 'Red 6'],
  greenBench: const ['Green 5'],
  questionValues: values ?? kJbqValues,
);

void main() {
  group('JBQ preset loads', () {
    test('schema parses and values match the book distribution', () {
      final ruleset = loadJbq();
      expect(ruleset.id, 'jbq-2026');
      expect(ruleset.match.answerValues, [10, 20, 30]);
      final counts = ruleset.match.valueCounts;
      expect(counts[10], 10); // Q-sets §2
      expect(counts[20], 7);
      expect(counts[30], 3);
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
      expect(team.roster[0].correct, 6);
      expect(team.roster[0].score, 70); // 6×10 + 10
      expect(team.roster[0].status, 'QUIZ-OUT');
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
      expect(view.teamOf(Side.green).roster[1].status, '');
      expect(view.teamOf(Side.green).roster[1].score, 50);
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
      expect(view.teamOf(Side.red).roster[2].status, 'STRIKE-OUT');
      expect(view.state.teams[Side.red]!.quizzers[2].leftMatch, isTrue);
      view.apply(const FoulEvent(side: Side.green));
      expect(view.scoreOf(Side.green), -5);
    });

    test('a substitution keeps the seat order (replacement takes the seat)', () {
      final view = freshJbq(values: List.filled(20, 20));
      // Seated Red 1..Red 4 (seats 1–4), bench Red 5/Red 6. Sub Red 2 → Red 5.
      expect(
        view.apply(
          const SubstituteQuizzerEvent(
            side: Side.red,
            outIndex: 1,
            benchIndex: 4,
          ),
        ),
        isNull,
      );
      // Red 5 sits in Red 2's seat; the other seats are untouched.
      expect(view.teamOf(Side.red).seated.map((q) => q.label), [
        'Red 1',
        'Red 5',
        'Red 3',
        'Red 4',
      ]);
      expect(view.teamOf(Side.red).bench.map((q) => q.label), [
        'Red 2',
        'Red 6',
      ]);
    });

    test('a substitution swaps a seated quizzer with a bench quizzer', () {
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
      // Red 1 is struck out. Swap them with the bench quizzer Red 5 (roster
      // index 4): Red 5 takes the table, Red 1 sits behind it.
      expect(
        view.apply(
          const SubstituteQuizzerEvent(
            side: Side.red,
            outIndex: 0,
            benchIndex: 4,
          ),
        ),
        isNull,
      );
      // The roster keeps a stable size and order (stable indices).
      expect(view.state.teams[Side.red]!.quizzers.length, 6);
      // Red 5 takes Red 1's vacated seat (seat order is preserved).
      expect(view.teamOf(Side.red).seated.map((q) => q.label), [
        'Red 5',
        'Red 2',
        'Red 3',
        'Red 4',
      ]);
      // Red 1 is on the bench now (their out flag carries with them).
      expect(view.teamOf(Side.red).bench.map((q) => q.label), [
        'Red 1',
        'Red 6',
      ]);
      // Red 1's 3 wrong (−30) still count toward the team total.
      expect(view.scoreOf(Side.red), -30);

      // A HEALTHY seated quizzer can be substituted too — no need to be out:
      // swap Red 2 (index 1) with Red 6 (index 5).
      expect(
        view.apply(
          const SubstituteQuizzerEvent(
            side: Side.red,
            outIndex: 1,
            benchIndex: 5,
          ),
        ),
        isNull,
      );
      // Red 6 takes Red 2's seat: the seated order is unchanged apart from the
      // swap in place.
      expect(view.teamOf(Side.red).seated.map((q) => q.label), [
        'Red 5',
        'Red 6',
        'Red 3',
        'Red 4',
      ]);

      // Substituting a seated quizzer for another seated quizzer is rejected.
      final notBenched = view.apply(
        const SubstituteQuizzerEvent(
          side: Side.red,
          outIndex: 2,
          benchIndex: 3,
        ),
      );
      expect(notBenched!.code, 'quizzer-not-benched');

      // A quizzer already on the bench cannot be substituted out.
      final notSeated = view.apply(
        const SubstituteQuizzerEvent(
          side: Side.red,
          outIndex: 0,
          benchIndex: 2,
        ),
      );
      expect(notSeated!.code, 'quizzer-not-seated');
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
