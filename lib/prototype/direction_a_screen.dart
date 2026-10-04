import 'package:flutter/material.dart';

import 'common_bits.dart';
import 'fake_round.dart';
import 'summary_screen.dart';

/// Direction A — "Split field": a spatial layout. Red occupies the left
/// half of the screen and green the right, mirroring the physical table.
/// Each team band hosts its score; quizzer cards sit beneath it.
class DirectionAScreen extends StatefulWidget {
  const DirectionAScreen({super.key, required this.config});

  final RoundConfig config;

  @override
  State<DirectionAScreen> createState() => _DirectionAScreenState();
}

class _DirectionAScreenState extends State<DirectionAScreen> {
  late final FakeRound round = FakeRound(widget.config);

  @override
  void dispose() {
    round.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF455A64),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      child: Scaffold(
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
                        Expanded(child: _teamHalf(context, round.red)),
                        const VerticalDivider(width: 2, thickness: 2),
                        Expanded(child: _teamHalf(context, round.green)),
                      ],
                    ),
                  ),
                  round.matchComplete
                      ? _matchCompleteBar(context)
                      : _scoringZone(context),
                  QuestionNavigator(round: round),
                  _bottomBar(context),
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
                round.rulesetTitle,
                style: TextStyle(fontSize: 13, color: scheme.outline),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'QUESTION ${round.questionNumber} OF ${round.values.length}',
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
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${round.currentValue} PTS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 96),
        ],
      ),
    );
  }

  Widget _teamHalf(BuildContext context, Team team) {
    return Container(
      color: team.tint,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                team.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: team.color,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'TIME-OUTS ${team.timeOuts}/${round.timeOutLimit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: team.color,
                ),
              ),
              const Spacer(),
              Text(
                '${round.scoreOf(team)}',
                style: TextStyle(
                  fontSize: 46,
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
          Expanded(
            child: Row(
              children: [
                for (final q in team.quizzers)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _quizzerCard(context, q),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizzerCard(BuildContext context, Quizzer q) {
    final selected = round.selected == q;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => round.select(selected ? null : q),
        child: Opacity(
          opacity: q.active ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? q.team.color : Colors.black12,
                width: selected ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  q.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: q.team.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${q.score}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('✓ ${q.correct}', const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _stat('✗ ${q.incorrect}', const Color(0xFFC62828)),
                    if (q.fouls > 0) ...[
                      const SizedBox(width: 8),
                      _stat('F ${q.fouls}', const Color(0xFFEF6C00)),
                    ],
                  ],
                ),
                if (!q.active) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      q.status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
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

  Widget _scoringZone(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = round.selected;
    return Container(
      height: 104,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: sel == null
          ? Center(
              child: Text(
                'Tap a quizzer, then record the ruling',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.outline,
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 76,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: round.markCorrect,
                      child: Text('CORRECT  +${round.currentValue}'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 76,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: round.markIncorrect,
                      child: Text('INCORRECT  −${round.currentValue ~/ 2}'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 76,
                  width: 150,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFEF6C00),
                        width: 2,
                      ),
                      foregroundColor: const Color(0xFFEF6C00),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: round.addFoul,
                    child: Text('FOUL  \u2212${round.foulDeduction}'),
                  ),
                ),
              ],
            ),
    );
  }

  /// Replaces the scoring zone once the round is finished: the scorekeeper
  /// gives the score to the quizmaster, reviews, or opens overtime.
  Widget _matchCompleteBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 104,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCH COMPLETE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Give the final score to the quizmaster, or review the round.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 64,
            child: OutlinedButton(
              onPressed: round.addOvertimeQuestion,
              child: const Text('Add overtime question'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 64,
            child: FilledButton.tonal(
              onPressed: _openSummary,
              child: const Text('View summary'),
            ),
          ),
        ],
      ),
    );
  }

  /// Rare-action dialog: pick team + outcome for a Contest / Coach's Appeal.
  Future<void> _recordChallenge() async {
    final teams = round.teams;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Record ${round.challengeLabel}'),
        children: [
          for (var i = 0; i < teams.length; i++)
            for (final successful in const <bool>[true, false])
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, '$i|${successful ? 1 : 0}'),
                child: SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${teams[i].name} — '
                      '${successful ? 'granted (successful)' : 'denied (unsuccessful)'}',
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final parts = choice.split('|');
    round.recordChallenge(
      teams[int.parse(parts[0])],
      successful: parts[1] == '1',
    );
  }

  void _openSummary() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SummaryScreen(round: round)),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 380,
            height: 48,
            child: FilledButton.tonalIcon(
              onPressed: round.canUndo ? round.undo : null,
              icon: const Icon(Icons.undo),
              label: Text(
                round.canUndo ? 'UNDO — ${round.undoLabel}' : 'Undo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: round.toggleInterruption,
              icon: const Icon(Icons.radio_button_checked),
              label: const Text('Interruption'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: round.matchComplete ? null : _recordChallenge,
              icon: const Icon(Icons.gavel_outlined),
              label: Text(round.challengeLabel),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openSummary,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Summary'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: round.red.color, width: 2),
                foregroundColor: round.red.color,
              ),
              onPressed: () => round.takeTimeOut(round.red),
              child: Text('RED TO ${round.red.timeOuts}/${round.timeOutLimit}'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: round.green.color, width: 2),
                foregroundColor: round.green.color,
              ),
              onPressed: () => round.takeTimeOut(round.green),
              child: Text(
                'GREEN TO ${round.green.timeOuts}/${round.timeOutLimit}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
