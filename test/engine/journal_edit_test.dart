// Direct action editing: a candidate journal is replayed from the captured
// seeds, invalid later actions are reported, and only a clean candidate is
// committed. Covers the engine primitive behind the Classic cell editors.
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

const kValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundView fresh({List<String> redBench = const ['Red 3']}) => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
  redBench: redBench,
  questionValues: kValues,
);

void main() {
  group('candidate replay', () {
    test('reports a later action that the edit invalidates', () {
      final v = fresh();
      v.apply(const InterruptionEvent(questionNumber: 1));
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: false,
        ),
      );
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.green,
          quizzerIndex: 0,
          correct: true,
        ),
      );

      // Drop the interruption only: the re-read answer no longer applies.
      final candidate = <RoundEvent>[
        for (final e in v.journal)
          if (e is! InterruptionEvent) e,
      ];
      final replay = v.replayCandidate(candidate);
      expect(replay.ok, isFalse);
      expect(replay.issues, hasLength(1));
      expect(replay.issues.single.event, isA<AnswerEvent>());
      expect((replay.issues.single.event as AnswerEvent).side, Side.green);
      // The returned state is the fold with that answer skipped.
      expect(replay.state.teams[Side.green]!.score, 0);
      expect(replay.state.teams[Side.red]!.score, -5);
    });

    test('a valid candidate commits and replaces the derived state', () {
      final v = fresh();
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(v.scoreOf(Side.red), 10);

      final replay = v.replaceJournal(<RoundEvent>[]);
      expect(replay.ok, isTrue);
      expect(v.journal, isEmpty);
      expect(v.scoreOf(Side.red), 0);
    });

    test('an invalid candidate does not touch the committed journal', () {
      final v = fresh();
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      final before = List<RoundEvent>.of(v.journal);

      // A second answer on the closed question cannot replay.
      final replay = v.replaceJournal([
        ...v.journal,
        const AnswerEvent(
          questionNumber: 1,
          side: Side.green,
          quizzerIndex: 0,
          correct: true,
        ),
      ]);
      expect(replay.ok, isFalse);
      expect(v.journal, before);
      expect(v.scoreOf(Side.red), 10);
      expect(v.scoreOf(Side.green), 0);
    });
  });

  group('refold seeds', () {
    test('undo keeps the bench roster', () {
      final v = fresh(redBench: const ['Red 3', 'Red 4']);
      expect(v.teamOf(Side.red).bench, hasLength(2));
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(v.undo(), isTrue);
      expect(v.teamOf(Side.red).bench.map((q) => q.label), ['Red 3', 'Red 4']);
    });

    test('effectiveValue follows a substitute question', () {
      final v = fresh();
      v.apply(const VoidQuestionEvent(questionNumber: 1));
      v.apply(const SubstituteQuestionEvent(questionNumber: 1, value: 30));
      expect(v.effectiveValue(1), 30);
      expect(v.questionValues[0], 10);
    });

    test('a combined void clears and reopens the slot at the same value', () {
      final v = fresh();
      v.apply(
        const AnswerEvent(
          questionNumber: 1,
          side: Side.red,
          quizzerIndex: 0,
          correct: true,
        ),
      );
      expect(v.scoreOf(Side.red), 10);

      expect(
        v.apply(
          const VoidQuestionEvent(questionNumber: 1, substituteValue: 10),
        ),
        isNull,
      );
      expect(v.scoreOf(Side.red), 0);
      expect(v.questionMarks[0].voided, isTrue);
      expect(v.effectiveValue(1), 10);
      expect(v.substituteValue(1), 10);

      // The slot is immediately scoreable again at the same value.
      expect(
        v.apply(
          const AnswerEvent(
            questionNumber: 1,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        ),
        isNull,
      );
      expect(v.scoreOf(Side.red), 10);

      // One undo removes the substitute answer, one more restores the original.
      expect(v.undo(), isTrue);
      expect(v.scoreOf(Side.red), 0);
      expect(v.questionMarks[0].voided, isTrue);
      expect(v.undo(), isTrue);
      expect(v.scoreOf(Side.red), 10);
      expect(v.questionMarks[0].voided, isFalse);
    });
  });
}
