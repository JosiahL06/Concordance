import 'package:flutter/material.dart';

import '../app/round_controller.dart';
import '../engine/events.dart';
import 'common/live_chrome.dart';
import 'common/theme_toggle.dart';

/// Classic live-scoring view: paper-style scoresheet ledger over
/// [RoundController]. Thin layout only — cells navigate, the shared console
/// scores. Layout only; no sheet text or imagery is reproduced.
class ClassicScreen extends StatefulWidget {
  const ClassicScreen({super.key, required this.controller});

  final RoundController controller;

  @override
  State<ClassicScreen> createState() => _ClassicScreenState();
}

const double _kLabelWidth = 140;
const double _kTotalWidth = 58;

class _ClassicScreenState extends State<ClassicScreen> {
  RoundController get round => widget.controller;

  List<int> get _visibleQuestions =>
      List<int>.generate(round.questionCount, (i) => i + 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: round,
          builder: (context, _) {
            return Column(
              children: [
                _header(context),
                Expanded(child: _ledger(context)),
                NoticeSlot(round: round),
                ScoringConsole(round: round),
                LiveBottomBar(round: round),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const LiveBackButton(),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONCORDANCE',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: scheme.outline,
                ),
              ),
              Text(
                '${rulesetTitle(round.ruleset)} \u00b7 scoresheet ledger',
                style: TextStyle(fontSize: 13, color: scheme.outline),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'QUESTION ${round.questionNumber} OF ${round.questionCount}',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${round.currentValue(round.questionNumber)} PTS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: scheme.onPrimaryContainer,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }

  Widget _ledger(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _columnHeaders(context),
                const SizedBox(height: 4),
                // Each team block shares the remaining height and sizes its
                // quizzer rows to fit, so the ledger never scrolls.
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _teamBlock(context, Side.red)),
                      const SizedBox(height: 4),
                      Expanded(child: _teamBlock(context, Side.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _timeOutRail(context),
        ],
      ),
    );
  }

  Widget _columnHeaders(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marks = round.view.questionMarks;
    return Row(
      children: [
        const SizedBox(width: _kLabelWidth),
        for (final n in _visibleQuestions)
          Expanded(
            child: Builder(
              builder: (context) {
                final interrupted =
                    n <= marks.length && marks[n - 1].interrupted;
                Widget cell = Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: n == round.questionNumber
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: n == round.questionNumber
                          ? scheme.onPrimary
                          : scheme.onSurface,
                    ),
                  ),
                );
                if (interrupted) {
                  // Paper sheet circles the interrupted question number —
                  // same orange ring as QuestionNavigator.
                  cell = Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFEF6C00),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: cell,
                  );
                }
                return cell;
              },
            ),
          ),
        Container(
          width: _kTotalWidth,
          alignment: Alignment.center,
          child: Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: scheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamBlock(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: sideTintFor(side, scheme),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sideAccent(side, scheme), width: 1.5),
      ),
      child: Column(
        children: [
          _teamTitleRow(context, side),
          const SizedBox(height: 2),
          // Rows flex to fill the block, so the ledger fits the screen height.
          Expanded(
            child: Column(
              children: [
                for (final q in round.teamOf(side).seated)
                  Expanded(child: _quizzerRow(context, side, q.index)),
              ],
            ),
          ),
          if (round.teamOf(side).bench.isNotEmpty) _benchLine(context, side),
        ],
      ),
    );
  }

  /// One-line bench strip inside the team block: each quizzer's name with
  /// their running total. Substitution is reached through the More menu.
  Widget _benchLine(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final bench = round.teamOf(side).bench;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: _kLabelWidth,
            child: Text(
              'BENCH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: sideInkMutedFor(scheme),
              ),
            ),
          ),
          Expanded(
            child: Text(
              [for (final q in bench) '${q.label} ${q.score}'].join('   ·   '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: sideInkFor(scheme),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamTitleRow(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: _kLabelWidth,
          child: Text(
            sideName(round, side).toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: sideAccent(side, scheme),
            ),
          ),
        ),
        TeamHeaderButtons(round: round, side: side),
        const Spacer(),
        Text(
          'SCORE ${round.scoreOf(side)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: sideInkFor(scheme),
          ),
        ),
        SizedBox(width: _kTotalWidth, child: Container()),
      ],
    );
  }

  Widget _quizzerRow(BuildContext context, Side side, int index) {
    final quizzer = round.teamOf(side).roster[index];
    final selected = round.selected == (side, index);
    final scheme = Theme.of(context).colorScheme;
    final label = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: quizzer.active ? () => round.select(side, index) : null,
        child: Container(
          width: _kLabelWidth,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quizzer.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (quizzer.status.isNotEmpty)
                Text(
                  quizzer.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          for (final n in _visibleQuestions)
            Expanded(child: _ledgerCell(context, side, index, n)),
          SizedBox(
            width: _kTotalWidth,
            child: Center(
              child: Text(
                '${quizzer.score}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerCell(BuildContext context, Side side, int index, int n) {
    final scheme = Theme.of(context).colorScheme;
    final mark = round.cellOutcome(side, index, n);
    final hasFoul = round.cellHasFoul(side, index, n);
    final quizzer = round.teamOf(side).roster[index];
    String text = hasFoul && mark == null ? 'F' : '';
    var color = scheme.outline;
    var weight = FontWeight.w500;
    if (mark == 'correct') {
      text = '+${round.currentValue(n)}';
      color = scheme.primary;
      weight = FontWeight.w800;
    } else if (mark == 'incorrect') {
      text = '\u2212${round.currentValue(n) ~/ 2}';
      color = scheme.error;
      weight = FontWeight.w800;
    } else if (hasFoul) {
      // Foul-only cell (no answer): bare F in tertiary, as before.
      color = scheme.tertiary;
      weight = FontWeight.w800;
    }
    final contested =
        round.view.questionMarks.length >= n &&
        round.view.questionMarks[n - 1].contested;
    final interrupted =
        round.view.questionMarks.length >= n &&
        round.view.questionMarks[n - 1].interrupted;
    // Highlight the intersect of the selected quizzer and the current
    // question so the keeper can see exactly which cell scores next.
    final isTarget =
        n == round.questionNumber && round.selected == (side, index);
    Widget cell = Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n == round.questionNumber
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTarget ? scheme.primary : scheme.outlineVariant,
          width: isTarget ? 3 : 1,
        ),
      ),
      child: Stack(
        // Expand so the Stack fills the cell: that lets the foul badge pin
        // to the cell corner, and the score is wrapped in [Center] so it
        // still centers within the filled Stack.
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, fontWeight: weight, color: color),
            ),
          ),
          // Personal foul shares the cell with the score: small capital F
          // badge top-right, never replacing the answer mark.
          if (hasFoul && mark != null)
            Positioned(
              top: 2,
              right: 3,
              child: Text(
                'F',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: scheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
    if (contested || interrupted) {
      cell = Container(
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: contested ? scheme.tertiary : const Color(0xFFEF6C00),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: cell,
      );
    }
    return InkWell(
      onTap: quizzer.active
          ? () {
              round.jumpToQuestion(n);
              round.select(side, index);
            }
          : null,
      child: cell,
    );
  }

  Widget _timeOutRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget railButton(Side side) {
      final taken = round.teamOf(side).timeOuts;
      final limit = round.timeOutDisplayCap(side);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sideName(round, side).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: sideAccent(side, scheme),
            ),
          ),
          for (var i = 1; i <= limit; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SizedBox(
                width: 76,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    // A used time-out fills solid in the team color with white
                    // text; an unused one stays an outline. Unmistakable at a
                    // glance from across the table.
                    side: BorderSide(
                      color: sideAccent(side, scheme),
                      width: i <= taken ? 2 : 1.5,
                    ),
                    foregroundColor: i <= taken
                        ? Colors.white
                        : sideAccent(side, scheme),
                    backgroundColor: i <= taken ? sideColor(side) : null,
                    textStyle: TextStyle(
                      fontWeight: i <= taken
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  onPressed: () => round.takeTimeOut(side),
                  child: Text('TO $i'),
                ),
              ),
            ),
          Text(
            '$taken/$limit',
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
        ],
      );
    }

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      // No scrolling: the two team groups share the rail height.
      child: Column(
        children: [
          const Text(
            'TIME',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const Text(
            'OUT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Expanded(child: Center(child: railButton(Side.red))),
          const SizedBox(height: 8),
          Expanded(child: Center(child: railButton(Side.green))),
        ],
      ),
    );
  }
}
