// D11 UI: the live point-value picker. Modern sets a value from the
// navigator's value sub-row; Classic from the ledger's column header; both
// drive the same `QuestionValueEvent`. A question starts unset (scoring
// blocked) and its value can be set through that picker.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/classic_screen.dart';
import 'package:concordance/views/modern_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// A round with every question left unset (the default — D11).
RoundController unset(String id) => RoundController(
  ruleset: loadPreset(id),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
);

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await ViewPreference.load();
  final theme = ThemeController(prefs);
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    ThemeScope(notifier: theme, child: MaterialApp(home: screen)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Modern: an unset question blocks scoring until a value is set', (
    WidgetTester tester,
  ) async {
    final round = unset('tbq-25-26');
    await pump(tester, ModernScreen(controller: round));

    // Header prompts for the value; a selected quizzer is guarded on it.
    expect(find.text('SET VALUE'), findsOneWidget);
    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Set the point value for Q1'),
      findsOneWidget,
    );
    expect(round.markCorrect(), isFalse); // engine-side guard

    // Set Q1 to 30 from the navigator's value sub-row (the first "set" cell).
    await tester.tap(find.text('set').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 points'));
    await tester.pumpAndSettle();

    expect(round.currentValue(1), 30);
    expect(find.text('30 PTS'), findsOneWidget);
    expect(find.text('SET VALUE'), findsNothing);
  });

  testWidgets('Classic: a column header sets the question value', (
    WidgetTester tester,
  ) async {
    final round = unset('tbq-25-26');
    await pump(tester, ClassicScreen(controller: round));

    expect(find.text('SET VALUE'), findsOneWidget);

    // Set Q1 to 20 from its column header (the first "set" caption).
    await tester.tap(find.text('set').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 points'));
    await tester.pumpAndSettle();

    expect(round.currentValue(1), 20);
    expect(find.text('20 PTS'), findsOneWidget);
  });

  testWidgets('a broken value stipulation shows in the alert banner (D12)', (
    WidgetTester tester,
  ) async {
    final round = unset('jbq-2026');
    await pump(tester, ClassicScreen(controller: round));

    // JBQ: a match must not start with a 30-point question. It is recorded (no
    // block) and surfaced as a notice in the shared alert banner.
    expect(round.setQuestionValue(1, 30), isTrue);
    expect(round.currentValue(1), 30);
    await tester.pumpAndSettle();
    expect(find.textContaining('must not start'), findsOneWidget);
  });
}
