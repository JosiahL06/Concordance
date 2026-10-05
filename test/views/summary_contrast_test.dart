// Contrast regression: the team tints are fixed LIGHT colors, so text sitting
// directly on them must be dark regardless of theme brightness. This bug is
// invisible in light mode, so it is asserted explicitly in dark mode.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/app/round_controller.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/views/common/live_chrome.dart';
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

Future<void> pumpDark(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF37474F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: home,
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

    expect(timeOuts.style?.color, sideInkMuted);
    expect(fouls.style?.color, sideInkMuted);

    // And genuinely dark against the light tint it sits on.
    expect(timeOuts.style!.color!.computeLuminance(), lessThan(0.4));
    expect(fouls.style!.color!.computeLuminance(), lessThan(0.4));
  });
}
