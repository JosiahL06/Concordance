import 'package:flutter/material.dart';

import '../app/round_controller.dart';
import '../data/export.dart';
import '../engine/events.dart';
import 'common/live_chrome.dart';
import 'common/haptics_toggle.dart';
import 'common/theme_toggle.dart';

/// Round summary: final result, team/individual tallies, question-by-question
/// review, and working PDF/CSV export via the platform share sheet.
/// Mode-agnostic single implementation; Done pops back to home.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.controller});

  final RoundController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final redScore = controller.scoreOf(Side.red);
    final greenScore = controller.scoreOf(Side.green);
    final tied = redScore == greenScore;
    final winnerSide = tied
        ? null
        : (redScore > greenScore ? Side.red : Side.green);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Round summary'),
        actions: const [ThemeToggleButton(), HapticsToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: winnerSide == null
                        ? scheme.surfaceContainerHigh
                        : sideTintFor(winnerSide, scheme),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tied
                            ? 'TIE'
                            : '${(winnerSide == Side.red ? controller.redName : controller.greenName).toUpperCase()} WINS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: winnerSide == null
                              ? scheme.onSurface
                              : sideColor(winnerSide),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$redScore \u2013 $greenScore',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: inkOnTint(scheme, winnerSide != null),
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        rulesetTitle(controller.ruleset),
                        style: TextStyle(
                          color: mutedInkOnTint(scheme, winnerSide != null),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Announcements'),
                _announcements(context),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _teamCard(context, Side.red)),
                    const SizedBox(width: 16),
                    Expanded(child: _teamCard(context, Side.green)),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Individual results'),
                _individualTable(context),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Question-by-question review'),
                _questionReview(context),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Export'),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () => exportPdf(controller, context),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Share PDF score sheet'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => exportCsv(controller, context),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Share CSV results'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: () =>
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The results as the scorekeeper would announce them: 1st and 2nd place
  /// team, and the top two individual scorers across the whole match (both
  /// teams combined).
  Widget _announcements(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teams = <(Side, int)>[
      (Side.red, controller.scoreOf(Side.red)),
      (Side.green, controller.scoreOf(Side.green)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    // Only the top two individual scorers across the whole match are
    // announced; the full breakdown stays in the table below.
    final individuals = <(String, Side, int)>[
      for (final side in Side.values)
        for (final q in controller.teamOf(side).roster)
          (q.label, side, q.score),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    final topIndividuals = individuals.take(2).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _announceCard(
            context,
            title: 'Team placings',
            rows: [
              for (var i = 0; i < teams.length; i++)
                _placement(
                  context,
                  place: _place(i),
                  label: teams[i].$1 == Side.red
                      ? controller.redName
                      : controller.greenName,
                  color: sideAccent(teams[i].$1, scheme),
                  score: teams[i].$2,
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _announceCard(
            context,
            title: 'Individual placings',
            rows: [
              for (var i = 0; i < topIndividuals.length; i++)
                _placement(
                  context,
                  place: _place(i),
                  label:
                      '${topIndividuals[i].$1} '
                      '(${sideName(controller, topIndividuals[i].$2)})',
                  color: scheme.primary,
                  score: topIndividuals[i].$3,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _announceCard(
    BuildContext context, {
    required String title,
    required List<Widget> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _placement(
    BuildContext context, {
    required String place,
    required String label,
    required Color color,
    required int score,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              place,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _place(int index) => index == 0 ? '1st' : '2nd';

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _teamCard(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final team = controller.teamOf(side);
    final fouls = team.roster.fold(0, (a, q) => a + q.fouls);
    return Card(
      color: sideTintFor(side, scheme),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (side == Side.red ? controller.redName : controller.greenName)
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: sideAccent(side, scheme),
              ),
            ),
            Text(
              '${controller.scoreOf(side)}',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: sideInkFor(scheme),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time-outs ${team.timeOuts}/${controller.timeOutDisplayCap(side)}',
              style: TextStyle(color: sideInkMutedFor(scheme)),
            ),
            Text(
              'Fouls $fouls',
              style: TextStyle(color: sideInkMutedFor(scheme)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _individualTable(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('QUIZZER')),
                _cell(context, 'SCORE', w: 70),
                _cell(context, 'CORRECT', w: 80),
                _cell(context, 'WRONG', w: 70),
                _cell(context, 'FOULS', w: 60),
                _cell(context, 'STATUS', w: 110),
              ],
            ),
            const Divider(),
            for (final side in Side.values)
              for (final q in controller.teamOf(side).roster)
                _tableRow(context, q),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(BuildContext context, quizzer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              quizzer.label as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _cell(context, '${quizzer.score}', w: 70, bold: true),
          _cell(context, '${quizzer.correct}', w: 80),
          _cell(context, '${quizzer.incorrect}', w: 70),
          _cell(context, '${quizzer.fouls}', w: 60),
          _cell(context, quizzer.status as String, w: 110),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    required double w,
    bool bold = false,
  }) {
    return SizedBox(
      width: w,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize: bold ? 16 : 14,
        ),
      ),
    );
  }

  Widget _questionReview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: scheme.tertiary,
    );
    final marks = controller.view.questionMarks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            for (var n = 1; n <= controller.questionCount; n++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Q$n',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${controller.currentValue(n)}',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                    Expanded(child: Text(_cellNotes(n))),
                    if (n <= marks.length && marks[n - 1].interrupted)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('INTERRUPTED', style: markStyle),
                      ),
                    if (n <= marks.length && marks[n - 1].contested)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('CONTESTED', style: markStyle),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _cellNotes(int n) {
    final parts = <String>[];
    for (final side in Side.values) {
      final team = controller.teamOf(side);
      for (final q in team.roster) {
        final mark = controller.cellOutcome(side, q.index, n);
        final hasFoul = controller.cellHasFoul(side, q.index, n);
        if (mark == null && !hasFoul) continue;
        final label = q.label;
        switch (mark) {
          case 'correct':
            parts.add('$label +${controller.currentValue(n)}');
          case 'incorrect':
            parts.add('$label -${controller.currentValue(n) ~/ 2}');
          case null:
            break;
        }
        if (hasFoul) {
          parts.add('$label F -${controller.ruleset.scoring.foulDeduction}');
        }
      }
    }
    if (parts.isEmpty) return '\u2014';
    return parts.join('   \u00b7   ');
  }
}
