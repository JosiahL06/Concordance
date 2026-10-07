// Contrast regression: team tints are theme-aware — pale in light mode with
// dark ink, deep in dark mode with light ink. Text sitting directly on a tint
// must switch ink with the theme; this is asserted explicitly in dark mode.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/views/common/theme_toggle.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/common/live_chrome.dart';
import 'package:concordance/views/summary_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Representative value list (no built-in order — D11).
const kValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundController freshRound() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  questionValues: kValues,
);

Future<void> pumpDark(WidgetTester tester, Widget home) async {
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
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF37474F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('tints are light and the tint ink is dark (palette contract)', () {
    for (final side in Side.values) {
      expect(
        sideTint(side).computeLuminance(),
        greaterThan(0.5),
        reason: '${side.name} tint is expected to be a light surface',
      );
    }
    expect(sideInk.computeLuminance(), lessThan(0.2));
    expect(sideInkMuted.computeLuminance(), lessThan(0.4));
  });

  testWidgets('summary team card text stays readable in dark mode', (
    WidgetTester tester,
  ) async {
    await pumpDark(tester, SummaryScreen(controller: freshRound()));

    final timeOuts = tester.widget<Text>(
      find.textContaining('Time-outs').first,
    );
    final fouls = tester.widget<Text>(find.textContaining('Fouls').first);

    expect(timeOuts.style?.color, sideInkDarkMuted);
    expect(fouls.style?.color, sideInkDarkMuted);

    // And genuinely light against the deep dark tint it sits on.
    expect(timeOuts.style!.color!.computeLuminance(), greaterThan(0.4));
    expect(fouls.style!.color!.computeLuminance(), greaterThan(0.4));
  });

  testWidgets('theme toggle cycles modes and persists the choice', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await ViewPreference.load();
    final theme = ThemeController(prefs);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      ThemeScope(
        notifier: theme,
        child: const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
      ),
    );
    await tester.pumpAndSettle();

    expect(theme.mode, ThemeMode.system);
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.light);
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(prefs.themeMode, ThemeMode.dark);
  });
}
