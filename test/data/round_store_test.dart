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

/// Representative value list (no built-in order — D11).
const kTbqValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundView freshView() => RoundView(
  ruleset: loadTbq(),
  redLabels: const ['Red 1', 'Red 2'],
  greenLabels: const ['Green 1', 'Green 2'],
  questionValues: kTbqValues,
);

/// A minimal round row for the durability tests.
int newRound(RoundStore store) => store.createRound(
  rulesetId: 'tbq-25-26',
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
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
      const QuestionValueEvent(questionNumber: 7, value: 30),
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
    expect(view.questionValues[6], 30); // QuestionValueEvent round-tripped
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
      questionValues: kTbqValues,
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

  test('saveJournal writes only the delta (append, no-op, undo)', () {
    final store = RoundStore.inMemory();
    final id = newRound(store);
    final journal = <RoundEvent>[
      const AnswerEvent(
        questionNumber: 1,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
      const TimeOutEvent(side: Side.red),
      const InterruptionEvent(questionNumber: 2),
    ];

    var onDisk = store.saveJournal(id, journal, 0);
    expect(onDisk, 3);
    expect(store.loadJournal(id), hasLength(3));

    // Nothing changed: no rows written, count unchanged.
    expect(store.saveJournal(id, journal, onDisk), 3);
    expect(store.loadJournal(id), hasLength(3));

    // Append one: only the new row is written.
    journal.add(
      const FoulEvent(questionNumber: 3, side: Side.green, quizzerIndex: 1),
    );
    onDisk = store.saveJournal(id, journal, onDisk);
    expect(onDisk, 4);
    expect(store.loadJournal(id), hasLength(4));

    // Undo two: only the tail is deleted, the prefix survives in order.
    journal.removeLast();
    journal.removeLast();
    onDisk = store.saveJournal(id, journal, onDisk);
    expect(onDisk, 2);
    final remaining = store.loadJournal(id);
    expect(remaining, hasLength(2));
    expect(remaining[0], isA<AnswerEvent>());
    expect(remaining[1], isA<TimeOutEvent>());
  });

  test('saveJournal and appendEvent agree on seq after an undo', () {
    final store = RoundStore.inMemory();
    final id = newRound(store);
    final journal = <RoundEvent>[
      const AnswerEvent(
        questionNumber: 1,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
      const TimeOutEvent(side: Side.red),
    ];
    var onDisk = store.saveJournal(id, journal, 0);
    expect(onDisk, 2);

    // Undo back to one event, then let the per-row path append the next one:
    // seq must stay dense (0, 1) rather than skip the slot the undo freed.
    journal.removeLast();
    onDisk = store.saveJournal(id, journal, onDisk);
    expect(onDisk, 1);
    store.appendEvent(
      id,
      const FoulEvent(questionNumber: 5, side: Side.red, quizzerIndex: 0),
    );

    final rows = store.loadJournal(id);
    expect(rows, hasLength(2));
    expect(rows.last, isA<FoulEvent>());
  });

  test('a failing save rolls back, leaving the previous journal intact', () {
    final store = RoundStore.inMemory();
    final id = newRound(store);
    store.appendEvent(
      id,
      const AnswerEvent(
        questionNumber: 1,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
    );
    expect(store.loadJournal(id), hasLength(1));

    // Simulates the app dying part-way through a save — the window the old
    // wipe-then-rewrite autosave left open on every single tap. Inside a
    // transaction the whole save is discarded, so the round keeps its journal.
    expect(
      () => store.transaction(() {
        store.truncateTo(id, 0);
        store.appendEvent(id, const TimeOutEvent(side: Side.red));
        throw StateError('simulated kill mid-save');
      }),
      throwsStateError,
    );

    final after = store.loadJournal(id);
    expect(after, hasLength(1));
    expect(after.single, isA<AnswerEvent>());
  });
}
