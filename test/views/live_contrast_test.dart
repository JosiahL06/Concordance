// Contrast regression for the live scoring views: the team tints are fixed
// LIGHT colors, so anything sitting directly on them must be dark ink
// regardless of theme brightness; conversely the deep side accents vanish on
// dark theme surfaces, so those must use the lightened dark-mode accent. Both
// bugs are invisible in light mode, so they are asserted in dark mode.
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
import 'package:concordance/views/common/live_chrome.dart';
import 'package:concordance/views/modern_screen.dart';
import 'package:concordance/views/summary_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

RoundController freshRound() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
);

Future<void> pumpBrightness(
  WidgetTester tester,
  Widget home,
  Brightness brightness,
) async {
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
            seedColor: kSeed,
            brightness: brightness,
          ),
          useMaterial3: true,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Contrast ratio per WCAG 2.1 (relative luminance, 1.0 = no contrast).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color textColor(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style!.color!;

/// The colour an accent should render as for [brightness].
Color expectedAccent(Side side, Brightness brightness) => sideAccent(
  side,
  ColorScheme.fromSeed(seedColor: kSeed, brightness: brightness),
);

void main() {
  test('light tints are pale with dark ink (palette contract)', () {
    final light = ColorScheme.fromSeed(seedColor: kSeed);
    for (final side in Side.values) {
      expect(
        sideTint(side).computeLuminance(),
        greaterThan(0.5),
        reason: '${side.name} light tint is expected to be a light surface',
      );
      // Light mode is untouched: the theme-aware tint equals the pale tint.
      expect(sideTintFor(side, light).toARGB32(), sideTint(side).toARGB32());
    }
    expect(sideInk.computeLuminance(), lessThan(0.2));
    expect(sideInkMuted.computeLuminance(), lessThan(0.4));
    expect(sideInkFor(light), sideInk);
    expect(sideInkMutedFor(light), sideInkMuted);
  });

  test('dark tints are deep with light ink (dark-mode palette)', () {
    final dark = ColorScheme.fromSeed(
      seedColor: kSeed,
      brightness: Brightness.dark,
    );
    for (final side in Side.values) {
      final tint = sideTintFor(side, dark);
      expect(
        tint.computeLuminance(),
        lessThan(0.15),
        reason: '${side.name} dark tint should be a deep surface',
      );
      expect(
        contrastRatio(sideInkFor(dark), tint),
        greaterThan(4.5),
        reason: '${side.name} dark-tint ink must clear 4.5:1',
      );
      expect(
        contrastRatio(sideInkMutedFor(dark), tint),
        greaterThan(3.0),
        reason: '${side.name} dark-tint muted ink must clear 3:1',
      );
    }
  });

  test('side accent is deep in light mode and lightened in dark mode', () {
    final light = ColorScheme.fromSeed(seedColor: kSeed);
    final dark = ColorScheme.fromSeed(
      seedColor: kSeed,
      brightness: Brightness.dark,
    );
    for (final side in Side.values) {
      expect(
        sideAccent(side, light).toARGB32(),
        sideColor(side).toARGB32(),
        reason: '${side.name} keeps its deep accent in light mode',
      );
      final accent = sideAccent(side, dark);
      expect(
        accent.computeLuminance(),
        greaterThan(0.4),
        reason: '${side.name} accent must be light enough for dark surfaces',
      );
      expect(
        contrastRatio(accent, dark.surfaceContainerHighest),
        greaterThan(4.5),
        reason: '${side.name} accent must clear 4.5:1 on dark surfaces',
      );
    }
  });

  testWidgets('summary team card text stays readable in dark mode', (
    WidgetTester tester,
  ) async {
    await pumpBrightness(
      tester,
      SummaryScreen(controller: freshRound()),
      Brightness.dark,
    );

    final timeOuts = tester.widget<Text>(
      find.textContaining('Time-outs').first,
    );
    final fouls = tester.widget<Text>(find.textContaining('Fouls').first);

    expect(timeOuts.style?.color, sideInkMutedFor(_darkScheme));
    expect(fouls.style?.color, sideInkMutedFor(_darkScheme));

    // And genuinely light against the deep dark tint it sits on.
    expect(timeOuts.style!.color!.computeLuminance(), greaterThan(0.4));
    expect(fouls.style!.color!.computeLuminance(), greaterThan(0.4));
  });

  group('Modern live view', () {
    testWidgets('team accent and score stay readable in dark mode', (
      WidgetTester tester,
    ) async {
      await pumpBrightness(
        tester,
        ModernScreen(controller: freshRound()),
        Brightness.dark,
      );

      // Side header accent drawn on a dark surface card.
      final teamName = tester.widget<Text>(find.text('RED').first);
      expect(teamName.style?.color, expectedAccent(Side.red, Brightness.dark));
      expect(teamName.style!.color!.computeLuminance(), greaterThan(0.4));

      // The score sits on `scheme.surface`, so it must not be dark ink (it
      // inherits the theme's onSurface — near-white in dark mode, which is
      // what we want here).
      final score = tester.widget<Text>(find.text('0').first);
      expect(score.style?.color, isNull);
      expect(
        Theme.of(tester.element(find.text('0').first)).colorScheme.onSurface
            .computeLuminance(),
        greaterThan(0.4),
      );

      // The time-out button sits in the team half below the tinted band and
      // carries the side accent as its foreground (button text inherits it).
      final timeOuts = find.textContaining('TIME-OUT');
      expect(timeOuts, findsNWidgets(2));
    });

    testWidgets('light mode keeps the deep team accent', (
      WidgetTester tester,
    ) async {
      await pumpBrightness(
        tester,
        ModernScreen(controller: freshRound()),
        Brightness.light,
      );
      final teamName = tester.widget<Text>(find.text('RED').first);
      expect(teamName.style?.color, sideColor(Side.red));
    });
  });

  group('Classic live view', () {
    testWidgets('ledger ink on tints stays legible in dark mode', (
      WidgetTester tester,
    ) async {
      await pumpBrightness(
        tester,
        ClassicScreen(controller: freshRound()),
        Brightness.dark,
      );

      // SCORE sits on the deep dark team tint, so it must be light ink and
      // must clear contrast against that tint.
      expect(
        textColor(tester, find.textContaining('SCORE').first),
        sideInkDark,
      );
      expect(sideInkDark.computeLuminance(), greaterThan(0.4));
      for (final side in Side.values) {
        expect(
          contrastRatio(sideInkDark, sideTintFor(side, _darkScheme)),
          greaterThan(4.5),
        );
      }
    });

    testWidgets('time-out rail accent clears contrast in dark mode', (
      WidgetTester tester,
    ) async {
      await pumpBrightness(
        tester,
        ClassicScreen(controller: freshRound()),
        Brightness.dark,
      );

      // The rail label is the "TIME OUT"-adjacent RED/GREEN caption in the
      // right-hand rail, not the ledger team title (which correctly keeps the
      // deep accent on its fixed light tint).
      final railLabel = tester.widget<Text>(find.text('RED').last);
      expect(railLabel.style?.color, expectedAccent(Side.red, Brightness.dark));
      expect(railLabel.style!.color!.computeLuminance(), greaterThan(0.4));
    });

    testWidgets('Modern header time-out uses the lightened dark-mode accent', (
      WidgetTester tester,
    ) async {
      await pumpBrightness(
        tester,
        ModernScreen(controller: freshRound()),
        Brightness.dark,
      );

      // Each team half now carries its own TIME-OUT button beside the team
      // name (the shared bottom-bar duplicates were removed). The button
      // text inherits the OutlinedButton foreground, which must be the
      // lightened accent on the dark surface.
      final buttons = find.textContaining('TIME-OUT');
      expect(buttons, findsNWidgets(2));
      final redButton = tester.widget<OutlinedButton>(
        find.ancestor(of: buttons.first, matching: find.byType(OutlinedButton)),
      );
      final greenButton = tester.widget<OutlinedButton>(
        find.ancestor(of: buttons.last, matching: find.byType(OutlinedButton)),
      );
      WidgetStateProperty<Color?>? fg(OutlinedButton b) =>
          b.style?.foregroundColor;
      expect(
        fg(redButton)?.resolve(<WidgetState>{}),
        expectedAccent(Side.red, Brightness.dark),
      );
      expect(
        fg(greenButton)?.resolve(<WidgetState>{}),
        expectedAccent(Side.green, Brightness.dark),
      );
      expect(redAccentDark.computeLuminance(), greaterThan(0.4));
      expect(greenAccentDark.computeLuminance(), greaterThan(0.4));
      expect(
        contrastRatio(redAccentDark, _darkScheme.surfaceContainerHighest),
        greaterThan(4.5),
      );
      expect(
        contrastRatio(greenAccentDark, _darkScheme.surfaceContainerHighest),
        greaterThan(4.5),
      );
    });
  });
}

final _darkScheme = ColorScheme.fromSeed(
  seedColor: kSeed,
  brightness: Brightness.dark,
);
