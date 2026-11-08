// The small decision menus (contest outcome, foul assignment, point value)
// share the substitution-board dialog language: rounded shell, strong title,
// icon-led choice cards, and the live 1.3x text cap.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

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

const kValues = <int>[
  10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
  30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
];

RoundController fresh({bool withValues = true}) => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
  questionValues: withValues ? kValues : null,
);

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1.0,
}) async {
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('contest menu uses the shared choice cards', (
    WidgetTester tester,
  ) async {
    final round = fresh();
    await pump(tester, ClassicScreen(controller: round));

    await tester.tap(find.text('CONTEST 0/3').first);
    await tester.pumpAndSettle();
    expect(find.text('Record Contest'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
    expect(find.text('Denied'), findsOneWidget);

    await tester.tap(find.text('Granted'));
    await tester.pumpAndSettle();
    expect(round.teamOf(Side.red).challengesUsed, 1);
    expect(round.teamOf(Side.red).unsuccessfulChallenges, 0);
    expect(find.text('Record Contest'), findsNothing);
  });

  testWidgets('foul menu uses the shared choice cards', (
    WidgetTester tester,
  ) async {
    final round = fresh();
    await pump(tester, ClassicScreen(controller: round));

    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FOUL'));
    await tester.pumpAndSettle();
    expect(find.text('Record foul'), findsOneWidget);
    expect(find.text('Quizzer foul'), findsOneWidget);
    expect(find.text('Team foul'), findsOneWidget);
    expect(find.textContaining('Red 1 \u00b7 \u22125 points'), findsOneWidget);

    await tester.tap(find.text('Quizzer foul'));
    await tester.pumpAndSettle();
    expect(round.cellHasFoul(Side.red, 0, 1), isTrue);
    expect(find.text('Record foul'), findsNothing);
  });

  testWidgets('header SET VALUE opens the shared value picker', (
    WidgetTester tester,
  ) async {
    final round = fresh(withValues: false);
    await pump(tester, ClassicScreen(controller: round));

    await tester.tap(find.text('SET VALUE'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('value-picker-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('value-picker-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('value-picker-30')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('value-picker-20')));
    await tester.pumpAndSettle();
    expect(round.currentValue(1), 20);
    expect(find.text('Question 1'), findsNothing);
  });

  testWidgets('Modern navigator value cell opens the same picker', (
    WidgetTester tester,
  ) async {
    final round = fresh(withValues: false);
    await pump(tester, ModernScreen(controller: round));

    await tester.tap(find.text('set').first);
    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('value-picker-30')));
    await tester.pumpAndSettle();
    expect(round.currentValue(1), 30);
  });

  testWidgets('point value cards highlight on hover and press', (
    WidgetTester tester,
  ) async {
    final round = fresh(withValues: false);
    await pump(tester, ClassicScreen(controller: round));
    await tester.tap(find.text('SET VALUE'));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('value-picker-20'));
    Material material() => tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    );
    final initial = material().color;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(card));
    await tester.pump();
    final hovered = material().color;
    expect(hovered, isNot(initial));

    await gesture.down(tester.getCenter(card));
    await tester.pump();
    final pressed = material().color;
    expect(pressed, isNot(hovered));

    await gesture.up();
    await tester.pumpAndSettle();
    await gesture.removePointer();
    expect(round.currentValue(1), 20);
  });

  testWidgets('console answer and foul buttons use the large bold type', (
    WidgetTester tester,
  ) async {
    final round = fresh();
    await pump(tester, ClassicScreen(controller: round));

    final correct = tester.widget<Text>(find.text('CORRECT  +10'));
    final incorrect = tester.widget<Text>(find.text('INCORRECT  \u22125'));
    final foul = tester.widget<Text>(find.text('FOUL'));
    for (final text in [correct, incorrect, foul]) {
      expect(text.style!.fontSize, 20);
      expect(text.style!.fontWeight, FontWeight.w900);
    }
  });

  testWidgets('the small menus fit the live text-scale cap', (
    WidgetTester tester,
  ) async {
    final round = fresh(withValues: false);
    await pump(tester, ClassicScreen(controller: round), textScale: 2.0);

    await tester.tap(find.text('SET VALUE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('value-picker-30')), findsOneWidget);
  });
}
