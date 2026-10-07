import 'package:flutter/material.dart';

import '../app/haptics.dart';
import '../app/round_controller.dart';
import '../engine/events.dart';
import 'common/common_bits.dart';
import 'common/live_chrome.dart';
import 'common/haptics_toggle.dart';
import 'common/theme_toggle.dart';

/// Modern live-scoring view: split-field spatial layout over RoundController.
/// Thin layout only — all scoring goes through [RoundController] + shared
/// [ScoringConsole] / [LiveBottomBar].
class ModernScreen extends StatefulWidget {
  const ModernScreen({super.key, required this.controller});

  final RoundController controller;

  @override
  State<ModernScreen> createState() => _ModernScreenState();
}

class _ModernScreenState extends State<ModernScreen> {
  RoundController get round => widget.controller;

  @override
  Widget build(BuildContext context) {
    // No-scroll contract (interaction spec): the live layout is fixed, so
    // OS text scaling is capped here to keep large accessibility sizes from
    // breaking the fit. Home/Setup/Summary scroll and scale without a cap.
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: round,
            builder: (context, _) {
              return Column(
                children: [
                  _header(context),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _teamHalf(context, Side.red)),
                        const VerticalDivider(width: 2, thickness: 2),
                        Expanded(child: _teamHalf(context, Side.green)),
                      ],
                    ),
                  ),
                  NoticeSlot(round: round),
                  ScoringConsole(round: round),
                  QuestionNavigator(round: round),
                  LiveBottomBar(round: round),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 76,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const LiveBackButton(),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONCORDANCE',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: scheme.outline,
                  ),
                ),
                Text(
                  rulesetTitle(round.ruleset),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.outline),
                ),
              ],
            ),
          ),
          Text(
            'QUESTION ${round.questionNumber} OF ${round.questionCount}',
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const HapticsToggleButton(),
        ],
      ),
    );
  }

  Widget _teamHalf(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final team = round.teamOf(side);
    return Container(
      color: sideTintFor(side, scheme),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sideAccent(side, scheme), width: 3),
            ),
            child: Row(
              children: [
                Text(
                  sideName(round, side).toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: sideAccent(side, scheme),
                  ),
                ),
                const Spacer(),
                Semantics(
                  label:
                      '${sideName(round, side)} score '
                      '${round.scoreOf(side)}',
                  excludeSemantics: true,
                  child: Text(
                    '${round.scoreOf(side)}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TeamHeaderButtons(round: round, side: side),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: sideAccent(side, scheme), width: 2),
                foregroundColor: sideAccent(side, scheme),
              ),
              onPressed: round.matchComplete
                  ? null
                  : () {
                      hapticTick(context);
                      round.takeTimeOut(side);
                    },
              child: Text(
                'TIME-OUT  ${team.timeOuts}/${round.timeOutDisplayCap(side)}',
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Cards flex to fill the team half, so the field never scrolls.
          Expanded(
            child: Column(
              children: [
                for (final q in team.seated)
                  Expanded(child: _quizzerCard(context, side, q.index)),
              ],
            ),
          ),
          if (team.bench.isNotEmpty) ...[
            const SizedBox(height: 4),
            _benchRow(context, side),
          ],
        ],
      ),
    );
  }

  /// Compact bench strip: each quizzer's name with their running total, so a
  /// rotated quizzer's points stay visible while they sit behind the table.
  /// Substitution happens through the More menu.
  Widget _benchRow(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final bench = round.teamOf(side).bench;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Text(
            'BENCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [for (final q in bench) '${q.label} ${q.score}'].join('   ·   '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizzerCard(BuildContext context, Side side, int index) {
    final scheme = Theme.of(context).colorScheme;
    final q = round.teamOf(side).roster[index];
    final selected = round.selected == (side, index);
    // One merged utterance for screen readers: name, status, tallies, score
    // — instead of TalkBack hopping between six fragment nodes.
    final spoken = <String>[q.label];
    if (q.status.isNotEmpty) spoken.add(q.status.toLowerCase());
    spoken.add('${q.score} points');
    spoken.add('${q.correct} correct');
    spoken.add('${q.incorrect} incorrect');
    spoken.add('${q.fouls} fouls');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        enableFeedback: false,
        onTap: q.active
            ? () {
                hapticTick(context);
                round.select(side, index);
              }
            : null,
        child: Semantics(
          button: q.active,
          enabled: q.active,
          selected: selected,
          label: spoken.join(', '),
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (q.status.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            q.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _stat('C ${q.correct}', scheme.primary),
                const SizedBox(width: 10),
                _stat('I ${q.incorrect}', scheme.error),
                const SizedBox(width: 10),
                _stat('F ${q.fouls}', scheme.tertiary),
                const SizedBox(width: 10),
                Text(
                  '${q.score}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
