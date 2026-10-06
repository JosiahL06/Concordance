// Persistence: the journal is the save unit. Events serialize to SQLite rows
// and re-fold into an identical round (autosave / resume contract).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/engine/round_view.dart';

Ruleset loadTbq() {
  final raw = File('assets/rulesets/tbq-25-26.json').readAsStringSync();
  return Ruleset.fromJson(json.decode(raw) as Map<String, Object?>);
}

RoundView freshView() => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
);

void main() {
  test('journal round-trips through SQLite and re-folds identically', () {
    final store = RoundStore.inMemory();
    final id = store.createRound(
      rulesetId: 'tbq-25-26',
      redName: 'Red',
      greenName: 'Green',
      redSeats: const ['Red 1', 'Red 2'],
      greenSeats: const ['Green 1', 'Green 2'],
    );

    final events = <RoundEvent>[
      const AnswerEvent(
        questionNumber: 1,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
      const FoulEvent(questionNumber: 2, side: Side.green, quizzerIndex: 0),
      const TimeOutEvent(side: Side.red),
      const InterruptionEvent(questionNumber: 1),
      const ChallengeEvent(
        questionNumber: 3,
        side: Side.red,
        successful: false,
      ),
      const VoidQuestionEvent(questionNumber: 4),
      const SubstituteQuestionEvent(questionNumber: 4, value: 20),
      const AnswerEvent(
        questionNumber: 4,
        side: Side.red,
        quizzerIndex: 1,
        correct: true,
      ),
      const OvertimeQuestionEvent(value: 10),
    ];

    for (final e in events) {
      store.appendEvent(id, e);
    }

    final loaded = store.loadJournal(id);
    expect(loaded.length, events.length);
    expect(loaded.first, isA<AnswerEvent>());

    // Re-fold the persisted journal into a fresh view: state must match.
    final view = freshView();
    for (final e in loaded) {
      expect(view.apply(e), isNull, reason: 'replay rejected $e');
    }

    // Q1 10pt correct (+10) and Q4 substitute 20pt correct (+20) for Red.
    expect(view.scoreOf(Side.red), 30);
    // Green quizzer foul on Q2 = -5.
    expect(view.scoreOf(Side.green), -5);
    expect(view.teamOf(Side.red).timeOuts, 1);
    expect(view.questionMarks[0].interrupted, isTrue);
    expect(view.questionMarks[3].voided, isTrue);
    expect(view.questionValues.length, 21); // 20 regulation + overtime
  });

  test('bench roster and a substitute round-trip through SQLite', () {
    final store = RoundStore.inMemory();
    final id = store.createRound(
      rulesetId: 'tbq-25-26',
      redName: 'Red',
      greenName: 'Green',
      redSeats: const ['Red 1', 'Red 2'],
      greenSeats: const ['Green 1', 'Green 2'],
      redBench: const ['Red 3'],
      greenBench: const ['Green 3'],
    );
    final row = store.loadRound(id)!;
    expect(row['red_bench'], '["Red 3"]');
    expect(row['green_bench'], '["Green 3"]');

    // Red 1 answers three wrong, then is swapped to the bench for Red 3
    // (roster index 2). Red 1's points must still count.
    for (var n = 1; n <= 3; n++) {
      store.appendEvent(
        id,
        AnswerEvent(
          questionNumber: n,
          side: Side.red,
          quizzerIndex: 0,
          correct: false,
        ),
      );
    }
    store.appendEvent(
      id,
      const SubstituteQuizzerEvent(side: Side.red, outIndex: 0, benchIndex: 2),
    );

    final view = RoundView(
      ruleset: loadTbq(),
      redLabels: const ['Red 1', 'Red 2'],
      greenLabels: const ['Green 1', 'Green 2'],
      redBench: const ['Red 3'],
      greenBench: const ['Green 3'],
    );
    for (final e in store.loadJournal(id)) {
      expect(view.apply(e), isNull, reason: 'replay rejected $e');
    }
    // Red 3 takes Red 1's vacated seat (seat order preserved).
    expect(view.teamOf(Side.red).seated.map((q) => q.label), [
      'Red 3',
      'Red 2',
    ]);
    expect(view.teamOf(Side.red).bench.map((q) => q.label), ['Red 1']);
    expect(view.scoreOf(Side.red), -20); // Red 1's misses survive the swap
  });

  test('truncateTo drops trailing events (undo persistence)', () {
    final store = RoundStore.inMemory();
    final id = store.createRound(
      rulesetId: 'tbq-25-26',
      redName: 'Red',
      greenName: 'Green',
      redSeats: const ['Red 1', 'Red 2'],
      greenSeats: const ['Green 1', 'Green 2'],
    );
    store.appendEvent(
      id,
      const AnswerEvent(
        questionNumber: 1,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
    );
    store.appendEvent(id, const TimeOutEvent(side: Side.red));
    expect(store.loadJournal(id).length, 2);

    store.truncateTo(id, 1);
    final remaining = store.loadJournal(id);
    expect(remaining.length, 1);
    expect(remaining.single, isA<AnswerEvent>());
  });

  test('listRounds and deleteRound manage the round index', () {
    final store = RoundStore.inMemory();
    final id = store.createRound(
      rulesetId: 'jbq-2026',
      redName: 'Alpha',
      greenName: 'Beta',
      redSeats: const ['Alpha 1', 'Alpha 2'],
      greenSeats: const ['Beta 1', 'Beta 2'],
    );
    expect(store.listRounds(), hasLength(1));
    expect(store.loadRound(id)!['ruleset_id'], 'jbq-2026');

    store.deleteRound(id);
    expect(store.listRounds(), isEmpty);
    expect(store.loadRound(id), isNull);
  });
}
