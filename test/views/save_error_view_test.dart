// Autosave-failure UI: a keeper must be told when the round is no longer being
// written to disk. The warning is persistent and appears in both live views,
// because both place the shared NoticeSlot above the console.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/classic_screen.dart';
import 'package:concordance/views/modern_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// A short round; the warning has nothing to do with question count.
RoundController fresh() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  questionValues: const [10, 20, 30],
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
    ThemeScope(
      notifier: theme,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// The headline of the save warning, matched loosely so the test does not
/// restate the full sentence.
const String kWarning = 'NOT SAVING';

void main() {
  /// Scores one correct answer, which is one autosave attempt.
  void scoreOnce(RoundController round) {
    round.select(Side.red, 0);
    round.markCorrect();
  }

  testWidgets('Modern: a failed autosave warns the keeper', (tester) async {
    final round = fresh()..autosave = (c) => throw StateError('disk full');
    await pump(tester, ModernScreen(controller: round));

    // Nothing to say while saving is healthy.
    expect(find.textContaining(kWarning), findsNothing);

    scoreOnce(round);
    await tester.pumpAndSettle();

    expect(find.textContaining(kWarning), findsOneWidget);
    // The ruling still counts: a disk problem must not stop the match.
    expect(round.scoreOf(Side.red), greaterThan(0));
  });

  testWidgets('Classic: a failed autosave warns the keeper', (tester) async {
    final round = fresh()..autosave = (c) => throw StateError('disk full');
    await pump(tester, ClassicScreen(controller: round));

    scoreOnce(round);
    await tester.pumpAndSettle();

    expect(find.textContaining(kWarning), findsOneWidget);
  });

  testWidgets('the warning clears once saving recovers', (tester) async {
    var failing = true;
    final round = fresh()
      ..autosave = (c) {
        if (failing) throw StateError('disk full');
      };
    await pump(tester, ModernScreen(controller: round));

    scoreOnce(round);
    await tester.pumpAndSettle();
    expect(find.textContaining(kWarning), findsOneWidget);

    // Space freed / volume writable again: the warning must not outlive it.
    failing = false;
    scoreOnce(round);
    await tester.pumpAndSettle();
    expect(find.textContaining(kWarning), findsNothing);
  });

  testWidgets('the warning offers no dismiss control', (tester) async {
    final round = fresh()..autosave = (c) => throw StateError('disk full');
    await pump(tester, ModernScreen(controller: round));

    scoreOnce(round);
    await tester.pumpAndSettle();

    // AlertBanner has a Dismiss tooltip; the save warning deliberately has none,
    // so a keeper cannot hide the one signal that the round is not on disk.
    expect(find.byTooltip('Dismiss'), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
  });
}
