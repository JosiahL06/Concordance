import 'package:flutter/material.dart';

import 'package:concordance/engine/ruleset.dart';

import 'fake_round.dart';

/// Round summary: final result, team/individual tallies, question-by-question
/// review, and export affordances (visual only until Phase 3 wires the real
/// engine's PDF/CSV export). Reached from the live screen's Summary button;
/// Done returns all the way home (the live round stays beneath on the stack).
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.round});

  final FakeRound round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final winner = round.winner;
    final redScore = round.scoreOf(round.red);
    final greenScore = round.scoreOf(round.green);
    return Scaffold(
      appBar: AppBar(title: const Text('Round summary')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── result banner ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: winner?.tint ?? scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        winner == null
                            ? 'TIE'
                            : '${winner.name.toUpperCase()} WINS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: winner?.color ?? scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$redScore – $greenScore',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        '${round.ruleset.displayName} ${round.ruleset.season}'
                        '${round.config.demo ? ' · demo' : ''}',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── team cards ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _teamCard(context, round.red)),
                    const SizedBox(width: 16),
                    Expanded(child: _teamCard(context, round.green)),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Individual results'),
                _individualTable(context),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Question by question'),
                _questionReview(context),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: () => _export(context, 'PDF score sheet'),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF score sheet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: () => _export(context, 'CSV'),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('CSV'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('DONE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _export(BuildContext context, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$format export arrives with the real engine (Phase 3)'),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _teamCard(BuildContext context, Team team) {
    final limits = round.ruleset.limits;
    final challengeLimit =
        limits.challengeLimitMode == ChallengeLimitMode.unsuccessful
        ? '${limits.challengeLimitCount} unsuccessful'
        : '${limits.challengeAllotmentPerTeam} total';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: team.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: team.color,
                  ),
                ),
              ),
              Text(
                '${round.scoreOf(team)}',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: team.color,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Time-outs used: ${team.timeOuts} of ${limits.timeOutsPerTeam}'),
          Text(
            '${round.challengeLabel}s: ${team.challengesUsed} '
            '(${team.unsuccessfulChallenges} unsuccessful, limit $challengeLimit)',
          ),
          Text('Quizzers: ${team.quizzers.length}'),
        ],
      ),
    );
  }

  Widget _individualTable(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _tableHeader(context),
            for (final team in round.teams) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: team.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      team.name.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: team.color,
                      ),
                    ),
                  ],
                ),
              ),
              for (final q in team.quizzers)
                Container(
                  color: q.active ? null : scheme.surfaceContainerHigh,
                  child: _tableRow(context, q),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Row(
      children: [
        const Expanded(child: Text('QUIZZER', style: style)),
        _cell(context, 'SCORE', w: 70),
        _cell(context, 'CORRECT', w: 80),
        _cell(context, 'WRONG', w: 70),
        _cell(context, 'FOULS', w: 60),
        _cell(context, 'STATUS', w: 110),
      ],
    );
  }

  Widget _tableRow(BuildContext context, Quizzer q) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              q.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _cell(context, '${q.score}', w: 70, bold: true),
          _cell(context, '${q.correct}', w: 80),
          _cell(context, '${q.incorrect}', w: 70),
          _cell(context, '${q.fouls}', w: 60),
          _cell(context, q.status, w: 110),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            for (var n = 1; n <= round.values.length; n++)
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
                        '${round.cellValue(n)}',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                    Expanded(child: Text(_cellNotes(n))),
                    if (round.ledgerInterrupted(n))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('INTERRUPTED', style: markStyle),
                      ),
                    if (round.ledgerContested(n))
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
    final cells = round.cellsFor(n);
    if (cells.isEmpty) return '—';
    final parts = <String>[];
    for (final cell in cells) {
      switch (cell.kind) {
        case 'correct':
          parts.add('${cell.quizzer.label} +${round.cellValue(n)}');
        case 'incorrect':
          parts.add('${cell.quizzer.label} -${round.cellValue(n) ~/ 2}');
        case 'foul':
          parts.add('${cell.quizzer.label} F -${round.foulDeduction}');
      }
    }
    return parts.join('   ·   ');
  }
}
