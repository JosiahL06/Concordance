// Accessibility + haptics pass: screen-reader labels for controls and the
// scoresheet marks, a live region for auto alerts, and the opt-in haptics
// toggle gating real platform vibration (with audio never allowed).
import 'dart:convert';
import 'dart:io' show File;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/haptics.dart';
import 'package:concordance/app/round_controller.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/main.dart';
import 'package:concordance/views/classic_screen.dart';
import 'package:concordance/views/common/common_bits.dart';
import 'package:concordance/views/modern_screen.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

List<Ruleset> presets() => [loadPreset('tbq-25-26'), loadPreset('jbq-2026')];

RoundController freshRound() => RoundController(
  ruleset: loadPreset('tbq-25-26'),
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
);

/// Pumps a live screen inside the same scopes the app mounts, optionally
/// overriding the text scale for the no-scroll overflow audit.
Future<void> pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(1280, 800),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await ViewPreference.load();
  final theme = ThemeController(prefs);
  addTearDown(theme.dispose);
  final haptics = HapticsController(prefs);
  addTearDown(haptics.dispose);
  await tester.pumpWidget(
    ThemeScope(
      notifier: theme,
      child: HapticsScope(
        notifier: haptics,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: kSeed),
            useMaterial3: true,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scoring console announces effect and disabled reason', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pump(tester, ClassicScreen(controller: round));

    // Nothing selected: the disabled CORRECT button carries a hint that
    // explains itself instead of being mute.
    final idle = tester.getSemantics(
      find.bySemanticsLabel('Correct answer, adds 10 points'),
    );
    expect(idle.getSemanticsData().hint, 'Select a quizzer first');

    // With a quizzer armed the label gains the side and the hint clears,
    // and the button exposes a tap action.
    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    final armed = tester.getSemantics(
      find.bySemanticsLabel('Correct answer, adds 10 points to Red'),
    );
    expect(armed.getSemanticsData().hint, anyOf(isNull, isEmpty));
    expect(armed.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('quizzer card is one merged tappable node with tallies', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pump(tester, ModernScreen(controller: round));

    const label = 'Red 1, 0 points, 0 correct, 0 incorrect, 0 fouls';
    final card = tester.getSemantics(find.bySemanticsLabel(label));
    expect(card.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(card.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      card.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(),
      isFalse,
    );

    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(find.bySemanticsLabel(label));
    expect(
      selected.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('question navigator speaks the styling-only marks', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pump(tester, ModernScreen(controller: round));

    expect(find.bySemanticsLabel('Question 1, current'), findsOneWidget);

    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CORRECT  +10'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Question 2, current'), findsOneWidget);
    expect(find.bySemanticsLabel('Question 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('classic ledger cells and totals carry spoken labels', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pump(tester, ClassicScreen(controller: round));

    expect(
      find.bySemanticsLabel('Question 1, Red 1, current question'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Red 1 total, 0 points'), findsOneWidget);
    expect(find.bySemanticsLabel('Red score 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Green score 0'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('auto quiz-out alert is announced as a live region', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final round = freshRound();
    await pump(tester, ClassicScreen(controller: round));

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Red 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CORRECT  +'));
      await tester.pumpAndSettle();
    }
    expect(round.lastAlert, isNotNull);
    final banner = tester.getSemantics(find.byType(AlertBanner));
    expect(banner.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('every icon button exposes a tooltip label', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await ViewPreference.load();
    await tester.pumpWidget(
      ConcordanceApp(
        prefs: prefs,
        store: RoundStore.inMemory(),
        presets: presets(),
      ),
    );
    await tester.pumpAndSettle();

    void expectTooltips(String where) {
      final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(buttons, isNotEmpty, reason: 'no icon buttons found on $where');
      for (final button in buttons) {
        expect(button.tooltip, isNotNull, reason: 'unlabeled icon on $where');
        expect(button.tooltip, isNotEmpty, reason: 'empty label on $where');
      }
    }

    expectTooltips('home');
    await tester.tap(find.text('START A NEW ROUND'));
    await tester.pumpAndSettle();
    expectTooltips('setup');
    await tester.scrollUntilVisible(
      find.text('START ROUND'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('START ROUND'));
    await tester.pumpAndSettle();
    expectTooltips('modern live');

    final classicRound = freshRound();
    await pump(tester, ClassicScreen(controller: classicRound));
    expectTooltips('classic live');
  });

  testWidgets('haptics toggle gates real vibration; no audio ever', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await ViewPreference.load();
    await tester.pumpWidget(
      ConcordanceApp(
        prefs: prefs,
        store: RoundStore.inMemory(),
        presets: presets(),
      ),
    );
    await tester.pumpAndSettle();

    // Off by default — a fresh install cannot buzz a match.
    expect(find.byTooltip('Haptics: off - tap to turn on'), findsOneWidget);

    // The scorekeeper opts in from the header.
    await tester.tap(find.byTooltip('Haptics: off - tap to turn on'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Haptics: on - tap to turn off'), findsOneWidget);

    // Drive Home -> Setup -> Modern live (the default view).
    await tester.tap(find.text('START A NEW ROUND'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('START ROUND'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('START ROUND'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Red 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CORRECT  +'));
    await tester.pumpAndSettle();
    List<MethodCall> vibrate() => platformCalls
        .where((c) => c.method == 'HapticFeedback.vibrate')
        .toList();
    // Two: selecting the quizzer, then the CORRECT ruling.
    expect(vibrate(), hasLength(2));

    // Toggled off mid-match: the next ruling stays still.
    await tester.tap(find.byTooltip('Haptics: on - tap to turn off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CORRECT  +'));
    await tester.pumpAndSettle();
    expect(vibrate(), hasLength(2));

    // Audio never enters the picture in any state.
    expect(platformCalls.where((c) => c.method == 'SystemSound.play'), isEmpty);
  });

  testWidgets('live screens fit at large text scales (no overflow)', (
    WidgetTester tester,
  ) async {
    for (final scale in const [1.5, 2.0]) {
      await pump(
        tester,
        ModernScreen(controller: freshRound()),
        textScale: scale,
      );
      expect(tester.takeException(), isNull, reason: 'modern at $scale');
      await pump(
        tester,
        ClassicScreen(controller: freshRound()),
        textScale: scale,
      );
      expect(tester.takeException(), isNull, reason: 'classic at $scale');
    }
  });
}
