import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/common/live_chrome.dart';

Ruleset loadTbq() => Ruleset.fromJson(
  json.decode(File('assets/rulesets/tbq-25-26.json').readAsStringSync())
      as Map<String, Object?>,
);

RoundController finishedMatch() {
  final controller = RoundController(
    ruleset: loadTbq(),
    redName: 'Red',
    greenName: 'Green',
    redSeats: const ['Red 1', 'Red 2', 'Red 3'],
    greenSeats: const ['Green 1', 'Green 2', 'Green 3'],
  );
  for (var n = 1; n <= 20; n++) {
    controller.view.apply(QuestionValueEvent(questionNumber: n, value: 10));
    if (n <= 15) {
      controller.view.apply(
        AnswerEvent(
          questionNumber: n,
          side: Side.red,
          quizzerIndex: (n - 1) ~/ 5,
          correct: true,
        ),
      );
    } else {
      controller.view.apply(
        AnswerEvent(
          questionNumber: n,
          side: Side.green,
          quizzerIndex: 0,
          correct: true,
        ),
      );
    }
  }
  controller.recomputeCompletion();
  return controller;
}

void main() {
  testWidgets('a finished match shows one result notice, with the summary', (
    WidgetTester tester,
  ) async {
    final round = finishedMatch();
    expect(round.matchComplete, isTrue);
    expect(round.lastAlert, contains('match complete'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoticeSlot(round: round)),
      ),
    );

    expect(find.text('View summary'), findsOneWidget);
    expect(find.textContaining('WINS'), findsOneWidget);
    expect(find.textContaining('match complete'), findsNothing);
  });
}
