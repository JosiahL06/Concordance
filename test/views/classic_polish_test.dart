// Polish-pass coverage for the Classic ledger: the interruption ring on the
// column header (paper "circle") and the intersect highlight of the selected
// quizzer x current question cell.
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

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Representative value list (no built-in order — D11); matches the old TBQ
/// default so display assertions are unchanged.
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

Future<void> pumpClassic(
  WidgetTester tester,
  RoundController round, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await ViewPreference.load();
  final theme = ThemeController(prefs);
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    ThemeScope(
      notifier: theme,
      child: MaterialApp(home: ClassicScreen(controller: round)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Rings are painted as BoxDecoration borders on ancestor Containers, so look
/// outward from the header text for the orange ring.
bool hasAncestorBorderWithColor(Element textElement, Color color) {
  var found = false;
  textElement.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Container && widget.decoration is BoxDecoration) {
      final decoration = widget.decoration as BoxDecoration;
      final border = decoration.border;
      if (border is Border) {
        for (final side in <BorderSide>[
          border.top,
          border.bottom,
          border.left,
          border.right,
        ]) {
          if (side.color == color) {
            found = true;
            return false;
          }
        }
      }
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets('interrupted question header gets the orange ring', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.toggleInterruption();
    await pumpClassic(tester, round);

    final header = find.text('1').first;
    expect(header, findsOneWidget);
    final element = header.evaluate().single;
    expect(
      hasAncestorBorderWithColor(element, const Color(0xFFEF6C00)),
      isTrue,
      reason: 'Q1 header should carry the interruption ring',
    );

    final other = find.text('2').first.evaluate().single;
    expect(
      hasAncestorBorderWithColor(other, const Color(0xFFEF6C00)),
      isFalse,
      reason: 'Q2 header should not carry the ring',
    );
  });

  testWidgets('score cell keeps its mark with an F badge after a foul', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    round.select(Side.red, 0);
    round.markCorrect();
    // Answers advance to Q2; jump back so the foul shares Q1's cell.
    round.jumpToQuestion(1);
    round.select(Side.red, 0);
    round.addQuizzerFoul();
    // Wide viewport so a ledger cell is much wider than the score text: the
    // badge must pin to the CELL's top-right corner (the pre-fix bug pinned
    // it to the shrink-wrapped score text, drawing it over the score).
    await pumpClassic(tester, round, size: const Size(2560, 800));

    // The score mark survives alongside the foul.
    expect(find.text('+10'), findsOneWidget);
    final cellBox = tester.getRect(
      find.ancestor(
        of: find.text('+10'),
        matching: find.byType(Container),
      ).first,
    );
    final scoreBox = tester.getRect(find.text('+10'));
    final badgeBox = tester.getRect(find.text('F'));

    // Badge hugs the cell corner (Positioned top:2, right:3).
    expect(badgeBox.right, closeTo(cellBox.right - 3, 1.0));
    expect(badgeBox.top, closeTo(cellBox.top + 2, 1.0));
    // ...and sits clear to the right of the score text, never over it.
    expect(badgeBox.left, greaterThanOrEqualTo(scoreBox.right));
    expect(scoreBox.overlaps(badgeBox), isFalse);
    expect(round.cellHasFoul(Side.red, 0, 1), isTrue);
    expect(
      round.view.teamDelta(Side.red, 1),
      10 - round.ruleset.scoring.foulDeduction,
    );
  });

  testWidgets('team header shows the team-only foul tally and contests', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round);

    expect(find.text('TEAM FOUL 0'), findsNWidgets(2));
    expect(find.text('CONTEST 0/3'), findsNWidgets(2));

    // A personal foul lands on the quizzer's cell and must NOT move the
    // team tally — the header counts team fouls only.
    round.select(Side.red, 0);
    round.addQuizzerFoul();
    await tester.pumpAndSettle();
    expect(find.text('TEAM FOUL 0'), findsNWidgets(2));
    expect(round.cellHasFoul(Side.red, 0, 1), isTrue);

    // A team foul moves only the team tally, and never marks a cell.
    round.addTeamFoul(Side.red);
    await tester.pumpAndSettle();
    expect(find.text('TEAM FOUL 1'), findsOneWidget);
    expect(round.cellOutcome(Side.red, 0, 1), isNull);
    expect(round.cellHasFoul(Side.red, 0, 1), isTrue, reason: 'personal foul');
    expect(round.cellHasFoul(Side.red, 1, 1), isFalse, reason: 'not Red 2');
    expect(
      round.scoreOf(Side.red),
      -round.ruleset.scoring.teamFoulDeduction -
          round.ruleset.scoring.foulDeduction,
    );
  });

  testWidgets('selected quizzer x current question cell is highlighted', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    await pumpClassic(tester, round);

    // No selection yet: no primary-bordered cell.
    final scheme = Theme.of(
      tester.element(find.byType(ClassicScreen).first),
    ).colorScheme;
    bool hasPrimaryBorder() {
      var found = false;
      for (final e in find.byType(Container).evaluate()) {
        final widget = e.widget as Container;
        final decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          final border = decoration.border as Border;
          if (border.top.color == scheme.primary &&
              border.top.width == 3) {
            found = true;
            break;
          }
        }
      }
      return found;
    }

    expect(hasPrimaryBorder(), isFalse);

    round.select(Side.red, 0);
    await tester.pumpAndSettle();
    expect(hasPrimaryBorder(), isTrue,
        reason: 'Red 1 x Q1 intersect should highlight');
  });

  testWidgets('console blocks and explains a guarded answer (D10)', (
    WidgetTester tester,
  ) async {
    final round = freshRound();
    // Red 1 answers Q1 correctly (advances to Q2), then the keeper looks back
    // at Q1 and selects the teammate: the team already answered, so the
    // console must disable CORRECT/INCORRECT and say why.
    round.select(Side.red, 0);
    round.markCorrect();
    round.jumpToQuestion(1);
    round.select(Side.red, 1);
    await pumpClassic(tester, round);

    expect(find.textContaining('BLOCKED'), findsOneWidget);
    final correct = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'CORRECT  +10'),
    );
    expect(correct.onPressed, isNull, reason: 'guarded answer is disabled');

    // FOUL stays live — fouls are not answer-guarded.
    final foul = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'FOUL'),
    );
    expect(foul.onPressed, isNotNull);
  });
}
