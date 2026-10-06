import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/settings.dart';
import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/main.dart';

/// Presets read straight from disk (the engine tests' pattern): rootBundle
/// asset loads do not resolve on the widget-test fake async clock.
List<Ruleset> _presets() => [
  for (final id in const ['tbq-25-26', 'jbq-2026'])
    Ruleset.fromJson(
      json.decode(File('assets/rulesets/$id.json').readAsStringSync())
          as Map<String, Object?>,
    ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home offers new round entry point and view toggle', (
    WidgetTester tester,
  ) async {
    final prefs = await ViewPreference.load();
    await tester.pumpWidget(
      ConcordanceApp(
        prefs: prefs,
        store: RoundStore.inMemory(),
        presets: _presets(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('START A NEW ROUND'), findsOneWidget);
    expect(find.text('Modern'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
  });

  testWidgets('setup flow loads real preset tabs and starts Classic mode', (
    WidgetTester tester,
  ) async {
    await _startClassic(tester);

    // Classic live-scoring screen, fresh round: question 1 of 20.
    expect(find.text('QUESTION 1 OF 20'), findsOneWidget);
    expect(find.textContaining('TAP A QUIZZER'), findsOneWidget);
    expect(find.text('SCORE 0'), findsNWidgets(2));
  });

  testWidgets('Classic: correct answer scores and advances the question', (
    WidgetTester tester,
  ) async {
    await _startClassic(tester);

    // Q1 is worth 10 in TBQ; Red 1 answers correctly.
    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CORRECT  +10'));
    await tester.pumpAndSettle();

    expect(find.text('QUESTION 2 OF 20'), findsOneWidget);
    expect(find.text('SCORE 10'), findsOneWidget);
    expect(find.textContaining('CORRECT  +20'), findsOneWidget); // Q2 is 20pt
  });

  testWidgets('Classic: incorrect answer deducts half the value', (
    WidgetTester tester,
  ) async {
    await _startClassic(tester);

    await tester.tap(find.text('Green 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('INCORRECT'));
    await tester.pumpAndSettle();

    expect(find.text('QUESTION 2 OF 20'), findsOneWidget);
    expect(find.text('SCORE -5'), findsOneWidget);
  });

  testWidgets('Classic: undo reverts the score and the question', (
    WidgetTester tester,
  ) async {
    await _startClassic(tester);

    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CORRECT  +10'));
    await tester.pumpAndSettle();
    expect(find.text('QUESTION 2 OF 20'), findsOneWidget);

    await tester.tap(find.textContaining('UNDO'));
    await tester.pumpAndSettle();
    expect(find.text('SCORE 0'), findsNWidgets(2));
  });

  testWidgets('Modern: correct answer scores and advances the question', (
    WidgetTester tester,
  ) async {
    await _start(tester, classic: false);

    expect(find.text('QUESTION 1 OF 20'), findsOneWidget);
    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CORRECT  +10'));
    await tester.pumpAndSettle();

    expect(find.text('QUESTION 2 OF 20'), findsOneWidget);
  });

  testWidgets('storage failure shows an actionable, retryable error', (
    WidgetTester tester,
  ) async {
    var fail = true;
    final prefs = await ViewPreference.load();

    await tester.pumpWidget(
      ConcordanceApp(
        prefs: prefs,
        presets: _presets(),
        storeOpener: () async {
          if (fail) throw StateError('database is locked');
          return RoundStore.inMemory();
        },
      ),
    );
    await tester.pumpAndSettle();

    // The failure is explained instead of leaving a dead disabled button.
    expect(find.text('Storage unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'START A NEW ROUND'),
    );
    expect(start.onPressed, isNull, reason: 'blocked until storage opens');

    // Retry with a working opener clears the error and enables scoring.
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Storage unavailable'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'START A NEW ROUND'),
    );
    expect(enabled.onPressed, isNotNull);
  });
}

/// Drives the real flow Home -> Setup -> live scoring at the Fire HD 10
/// landscape design size, in the requested scoreboard view.
Future<void> _start(WidgetTester tester, {required bool classic}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await ViewPreference.load();
  await tester.pumpWidget(
    ConcordanceApp(
      prefs: prefs,
      store: RoundStore.inMemory(),
      presets: _presets(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('START A NEW ROUND'));
  await tester.pumpAndSettle();

  // Preset tabs come from the real assets/rulesets/*.json (the name appears
  // twice: once as a tab, once as the rules summary heading).
  expect(find.text('Teen Bible Quiz 2025-26'), findsNWidgets(2));
  expect(find.text('Junior Bible Quiz 2026'), findsOneWidget);

  if (classic) {
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    find.text('START ROUND'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('START ROUND'));
  await tester.pumpAndSettle();
}

Future<void> _startClassic(WidgetTester tester) =>
    _start(tester, classic: true);
