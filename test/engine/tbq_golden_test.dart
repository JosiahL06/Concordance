// Golden tests: TBQ 25-26 preset. Every expectation traces to a rule
// citation in docs/ruleset-schema.md (facts only — no rulebook prose).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/notifications.dart';
import 'package:concordance/engine/round_view.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadTbq() {
  final raw = File('assets/rulesets/tbq-25-26.json').readAsStringSync();
  return Ruleset.fromJson(json.decode(raw) as Map<String, Object?>);
}

/// A representative TBQ regulation value list for the goldens. The engine has
/// no built-in per-question order any more (D11); tests that care about a
/// question's value pass it explicitly, and this default stands in for the
/// scorekeeper having set each question.
const kTbqValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundView freshTbq({List<int>? values}) => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2', 'Red 3'],
  greenLabels: const ['Green 1', 'Green 2', 'Green 3'],
  questionValues: values ?? kTbqValues,
);

void main() {
  group('TBQ preset loads', () {
    test('schema parses and values match the book distribution', () {
      final ruleset = loadTbq();
      expect(ruleset.id, 'tbq-25-26');
      expect(ruleset.match.regulationQuestions, 20);
      expect(ruleset.match.answerValues, [10, 20, 30]);
      final counts = ruleset.match.valueCounts;
      expect(counts[10], 8); // Scoring §1
      expect(counts[20], 9);
      expect(counts[30], 3);
      expect(ruleset.scoring.quizOutCorrect, 5); // Scoring §2
      expect(ruleset.scoring.quizOutBonus, 20);
      expect(ruleset.scoring.strikeOutIncorrect, 3); // Scoring §3
    });
  });

  group('scoring (Scoring §§1-4)', () {
    test('correct answer awards full value', () {
      final view = freshTbq(values: List.filled(20, 20));
      expect(
        view.apply(
          const AnswerEvent(
            questionNumber: 1,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        ),
        isNull,
      );
      expect(view.scoreOf(Side.red), 20);
    });

    test('30-pointer wrong loses half (15)', () {
      final view = freshTbq(values: List.filled(20, 30));
      view.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.green,
          quizzerIndex: 1,
          correct: false,
        ),
      );
      expect(view.scoreOf(Side.green), -15);
    });

    test('fifth correct triggers quiz-out +20 and stays at table', () {
      final view = freshTbq(values: List.filled(20, 20));
      for (var n = 1; n <= 5; n++) {
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
      expect(team.roster[0].correct, 5);
      // 5×20 + 20 bonus.
      expect(team.roster[0].score, 120);
      expect(team.roster[0].status, 'QUIZ-OUT');
      expect(team.roster[0].active, isFalse);
      // TBQ: stays at the table (leavesMatch false).
      expect(view.state.teams[Side.red]!.quizzers[0].leftMatch, isFalse);
      // Sixth answer rejected: quizzer cannot answer.
      final violation = view.apply(
        const AnswerEvent(
          questionNumber: 6,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(violation, isNotNull);
      expect(violation!.code, 'quizzer-inactive');
    });

    test('third incorrect strikes out', () {
      final view = freshTbq(values: List.filled(20, 20));
      for (var n = 1; n <= 3; n++) {
        view.apply(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: 2,
            correct: false,
          ),
        );
      }
      final team = view.teamOf(Side.green);
      expect(team.roster[2].incorrect, 3);
      expect(team.roster[2].status, 'STRIKE-OUT');
      expect(team.roster[2].score, -30);
    });

    test('quizzer foul −5; third foul fouls out; team foul −5', () {
      final view = freshTbq();
      view.apply(
        const FoulEvent(questionNumber: 1, side: Side.red, quizzerIndex: 0),
      );
      expect(view.teamOf(Side.red).roster[0].score, -5);
      view.apply(
        const FoulEvent(questionNumber: 2, side: Side.red, quizzerIndex: 0),
      );
      view.apply(
        const FoulEvent(questionNumber: 3, side: Side.red, quizzerIndex: 0),
      );
      expect(view.teamOf(Side.red).roster[0].status, 'FOUL-OUT');
      view.apply(const FoulEvent(side: Side.green));
      expect(view.scoreOf(Side.green), -5);
    });
  });

  group('bookkeeping + notifications (Scorekeeper §§2-5)', () {
    test('interruption marks the question', () {
      final view = freshTbq();
      view.apply(const InterruptionEvent(questionNumber: 3));
      expect(
        view.questionMarks.firstWhere((q) => q.number == 3).interrupted,
        isTrue,
      );
    });

    test('time-outs are capped; a 4th request is rejected, not counted', () {
      final view = freshTbq();
      for (var i = 0; i < 3; i++) {
        expect(view.apply(const TimeOutEvent(side: Side.red)), isNull);
      }
      expect(view.teamOf(Side.red).timeOuts, 3);

      final violation = view.apply(const TimeOutEvent(side: Side.red));
      expect(violation, isNotNull);
      expect(violation!.code, 'timeout-limit');
      expect(view.teamOf(Side.red).timeOuts, 3);
      expect(view.journal.whereType<TimeOutEvent>().length, 3);
    });

    test('overtime: remaining time-outs may not be used (Time-outs §4)', () {
      final view = freshTbq();
      // One used in regulation, two remain — but overtime voids them.
      view.apply(const TimeOutEvent(side: Side.red));
      expect(view.apply(const OvertimeQuestionEvent(value: 10)), isNull);

      final violation = view.apply(const TimeOutEvent(side: Side.red));
      expect(violation, isNotNull);
      expect(violation!.code, 'timeout-limit');
      expect(view.teamOf(Side.red).timeOuts, 1);

      // Even a team that used none cannot take one in overtime.
      final other = freshTbq();
      other.apply(const OvertimeQuestionEvent(value: 10));
      expect(
        other.apply(const TimeOutEvent(side: Side.green))!.code,
        'timeout-limit',
      );
    });

    test('time-out limit notice fires at the ruleset threshold', () {
      // A ruleset whose notify threshold sits at the cap, so the state-derived
      // notice is reachable. TBQ/JBQ notify at 4 with a cap of 3: the denied
      // 4th request is announced by RoundController instead of by this notice.
      final raw = json.decode(
        File('assets/rulesets/tbq-25-26.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final limits = Map<String, Object?>.of(
        raw['limits'] as Map<String, Object?>,
      );
      limits['notifyTimeOutRequest'] = 3;
      raw['limits'] = limits;
      final view = RoundView(
        ruleset: Ruleset.fromJson(raw),
        redLabels: const ['Red 1', 'Red 2', 'Red 3'],
        greenLabels: const ['Green 1', 'Green 2', 'Green 3'],
      );
      for (var i = 0; i < 3; i++) {
        view.apply(const TimeOutEvent(side: Side.red));
      }
      final notices = collectNotices(view.ruleset, view.state);
      expect(notices.any((n) => n.code == 'time-out-limit'), isTrue);
    });

    test('3rd unsuccessful contest notifies', () {
      final view = freshTbq();
      for (var n = 1; n <= 3; n++) {
        view.apply(
          ChallengeEvent(
            questionNumber: n,
            side: Side.green,
            successful: false,
          ),
        );
      }
      final notices = collectNotices(view.ruleset, view.state);
      expect(notices.any((n) => n.code == 'challenge-limit'), isTrue);
    });

    test('per-question contest cap rejects the 3rd on one question', () {
      final view = freshTbq();
      view.apply(
        const ChallengeEvent(
          questionNumber: 1,
          side: Side.red,
          successful: false,
        ),
      );
      view.apply(
        const ChallengeEvent(
          questionNumber: 1,
          side: Side.red,
          successful: true,
        ),
      );
      final violation = view.apply(
        const ChallengeEvent(
          questionNumber: 1,
          side: Side.red,
          successful: false,
        ),
      );
      expect(violation, isNotNull);
      expect(violation!.code, 'challenge-per-question-cap');
    });

    test('void + substitute: same slot, substitute value scores', () {
      final view = freshTbq(values: List.filled(20, 20));
      view.apply(const VoidQuestionEvent(questionNumber: 4));
      final rejected = view.apply(
        const AnswerEvent(
          questionNumber: 4,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(rejected!.code, 'question-voided');
      view.apply(const SubstituteQuestionEvent(questionNumber: 4, value: 10));
      expect(
        view.apply(
          const AnswerEvent(
            questionNumber: 4,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        ),
        isNull,
      );
      expect(view.scoreOf(Side.red), 10);
    });

    test('undo pops the journal and re-folds', () {
      final view = freshTbq(values: List.filled(20, 20));
      view.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(view.scoreOf(Side.red), 20);
      expect(view.undo(), isTrue);
      expect(view.scoreOf(Side.red), 0);
      expect(view.undo(), isFalse);
    });

    test('out-of-order correction targets an explicit question (D1)', () {
      final view = freshTbq(values: List.filled(20, 20));
      view.apply(
        const AnswerEvent(
          questionNumber: 5,
          side: Side.green,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(view.cellOutcome(Side.green, 0, 5), 'correct');
      expect(view.teamDelta(Side.green, 5), 20);
      expect(view.scoreOf(Side.green), 20);
    });
  });
}
