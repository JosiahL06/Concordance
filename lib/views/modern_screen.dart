import 'package:flutter/material.dart';

import '../app/round_controller.dart';
import '../engine/events.dart';
import 'common/common_bits.dart';
import 'common/live_chrome.dart';
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
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: round,
          builder: (context, _) {
            return Column(
              children: [
                _header(context),
                AlertBanner(round: round),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _teamHalf(context, Side.red)),
                      const VerticalDivider(width: 2, thickness: 2),
                      Expanded(child: _teamHalf(context, Side.green)),
                    ],
                  ),
                ),
                if (round.matchComplete || round.inOvertime)
                  EndOfRoundBar(round: round),
                ScoringConsole(round: round),
                QuestionNavigator(round: round),
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
      height: 76,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
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
                rulesetTitle(round.ruleset),
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
        ],
      ),
    );
  }

  Widget _teamHalf(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final team = round.teamOf(side);
    return Container(
      color: sideTint(side),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sideColor(side), width: 3),
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
                Text(
                  '${round.scoreOf(side)}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
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
                  : () => round.takeTimeOut(side),
              child: Text(
                'TIME-OUT  ${team.timeOuts}/${round.timeOutDisplayCap(side)}',
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < team.quizzers.length; i++)
            _quizzerCard(context, side, i),
        ],
      ),
    );
  }

  Widget _quizzerCard(BuildContext context, Side side, int index) {
    final scheme = Theme.of(context).colorScheme;
    final q = round.teamOf(side).quizzers[index];
    final selected = round.selected == (side, index);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: q.active ? () => round.select(side, index) : null,
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
