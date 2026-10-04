import 'package:flutter/material.dart';

import 'common_bits.dart';
import 'fake_round.dart';
import 'summary_screen.dart';

/// Direction B — "Scoresheet ledger": a digital take on the traditional
/// paper scoresheet. Two team blocks (quizzer rows × question columns with
/// running totals), a time-out rail, and the same scoring console as the
/// other direction. Layout only — no sheet text or imagery is reproduced.
class DirectionBScreen extends StatefulWidget {
  const DirectionBScreen({super.key, required this.config});

  final RoundConfig config;

  @override
  State<DirectionBScreen> createState() => _DirectionBScreenState();
}

/// Fixed geometry for the ledger grid. 20 question columns plus a label and
/// total column must fit 1280 logical dp: 20 x 48 + 140 + 64 = 1164.
const double _kLabelWidth = 140;
const double _kCellSize = 48;
const double _kTotalWidth = 64;

class _DirectionBScreenState extends State<DirectionBScreen> {
  late final FakeRound round = FakeRound(widget.config);

  /// Question columns shown (regulation 20; grows with overtime slots).
  List<int> get _visibleQuestions =>
      List<int>.generate(round.values.length, (i) => i + 1);

  /// Column width: 48dp while the grid fits (20 columns × 48 + label +
  /// total = 1164dp, fits 1280), shrinking only for overtime columns or
  /// narrower windows.
  double _cellW = _kCellSize;

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
          seedColor: const Color(0xFF263238),
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
                  Expanded(child: _ledger(context)),
                  round.matchComplete
                      ? _matchCompleteBar(context)
                      : _console(context),
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
      height: 64,
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
                '${round.rulesetTitle} · scoresheet ledger',
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
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${round.currentValue} PTS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledger(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fit every question column to the available width; stays at the
          // 48dp maximum (touch target) for 20 columns on a 1280dp screen
          // and only shrinks for overtime slots or narrower windows.
          final gridAvail = constraints.maxWidth - 84; // rail 76 + gap 8
          final fit =
              (gridAvail - _kLabelWidth - _kTotalWidth) /
              _visibleQuestions.length;
          _cellW = fit.clamp(8.0, _kCellSize);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _columnHeaders(context),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _teamBlock(context, round.red),
                            const SizedBox(height: 4),
                            _teamBlock(context, round.green),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _timeOutRail(context),
            ],
          );
        },
      ),
    );
  }

  Widget _columnHeaders(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: _kLabelWidth,
          child: Text(
            'QUESTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: scheme.outline,
            ),
          ),
        ),
        for (final n in _visibleQuestions)
          Container(
            width: _cellW,
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
          ),
        Container(
          width: _kTotalWidth - 6,
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

  Widget _teamBlock(BuildContext context, Team team) {
    return Container(
      decoration: BoxDecoration(
        color: team.tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: team.color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _teamTitleRow(context, team),
          const SizedBox(height: 2),
          for (final q in team.quizzers) _quizzerRow(context, team, q),
          const SizedBox(height: 2),
          _runningTotalRow(context, team),
        ],
      ),
    );
  }

  Widget _teamTitleRow(BuildContext context, Team team) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: _kLabelWidth,
          child: Text(
            team.name.toUpperCase(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: team.color,
            ),
          ),
        ),
        InkWell(
          onTap: () {
            round.select(
              team.quizzers.firstWhere(
                (q) => q.active,
                orElse: () => team.quizzers.first,
              ),
            );
            round.addFoul();
          },
          child: Container(
            width: _kCellSize * 2,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'FOUL ${team.quizzers.fold(0, (s, q) => s + q.fouls)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        InkWell(
          onTap: round.toggleInterruption,
          child: Container(
            width: _kCellSize * 2,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'CONTEST ${round.marks.values.where((m) => m.contested).length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(
          'SCORE ${round.scoreOf(team)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            color: team.color,
          ),
        ),
        SizedBox(width: _kTotalWidth, child: Container()),
      ],
    );
  }

  Widget _quizzerRow(BuildContext context, Team team, Quizzer q) {
    final scheme = Theme.of(context).colorScheme;
    final selected = round.selected == q;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          InkWell(
            onTap: q.active ? () => round.select(selected ? null : q) : null,
            child: Container(
              width: _kLabelWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? team.color : scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? team.color : scheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? scheme.onPrimary : team.color,
                    ),
                  ),
                  Text(
                    q.active
                        ? '\u2713${q.correct} \u2717${q.incorrect}'
                        : q.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.onPrimary : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final n in _visibleQuestions) _ledgerCell(context, q, n),
          Container(
            width: _kTotalWidth - 6,
            alignment: Alignment.center,
            child: Text(
              '${q.score}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerCell(BuildContext context, Quizzer q, int n) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = n == round.questionNumber;
    final mark = round.ledgerMark(q, n);
    String text = '';
    var textColor = scheme.outline;
    if (mark == 'correct') {
      text = '+${round.cellValue(n)}';
      textColor = const Color(0xFF2E7D32);
    } else if (mark == 'incorrect') {
      text = '\u2212${round.cellValue(n) ~/ 2}';
      textColor = const Color(0xFFC62828);
    } else if (mark == 'foul') {
      text = 'F';
      textColor = const Color(0xFFEF6C00);
    }
    final contested = round.ledgerContested(n);
    final interrupted = round.ledgerInterrupted(n);
    Widget cell = InkWell(
      onTap: () => round.jumpToQuestion(n),
      child: Container(
        width: _cellW,
        height: _kCellSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCurrent ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCurrent ? scheme.primary : scheme.outlineVariant,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isCurrent ? scheme.onPrimaryContainer : textColor,
          ),
        ),
      ),
    );
    if (contested || interrupted) {
      cell = Container(
        width: _cellW,
        height: _kCellSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: contested ? scheme.tertiary : const Color(0xFFEF6C00),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: cell,
      );
    }
    return cell;
  }

  Widget _runningTotalRow(BuildContext context, Team team) {
    final scheme = Theme.of(context).colorScheme;
    var running = 0;
    return Row(
      children: [
        SizedBox(
          width: _kLabelWidth,
          child: Text(
            'RUNNING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: scheme.outline,
            ),
          ),
        ),
        for (final n in _visibleQuestions)
          Container(
            width: _cellW,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Builder(
              builder: (context) {
                running += round.ledgerDelta(team, n);
                final done = n <= round.questionNumber;
                return Text(
                  done ? '$running' : '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                    color: scheme.onSurface,
                  ),
                );
              },
            ),
          ),
        Container(
          width: _kTotalWidth - 6,
          alignment: Alignment.center,
          child: Text(
            '${round.scoreOf(team)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: team.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeOutRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget railButton(Team team) {
      return SizedBox(
        width: 76,
        height: _kCellSize * 2,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: team.color, width: 2),
            foregroundColor: team.color,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => round.takeTimeOut(team),
          child: Text(
            '${team.name.toUpperCase()}\n${team.timeOuts}/${round.timeOutLimit}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            'TIME\nOUT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          railButton(round.red),
          const SizedBox(height: 8),
          railButton(round.green),
        ],
      ),
    );
  }

  Widget _console(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = round.selected;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            sel == null
                ? 'TAP A QUIZZER CELL, THEN RECORD THE RULING — CORRECT / INCORRECT ADVANCE; FOUL STAYS'
                : '${sel.label.toUpperCase()} JUMPED ON Q${round.questionNumber} \u2014 RECORD THE RULING',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 68,
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
                  height: 68,
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
                    child: Text('INCORRECT  \u2212${round.currentValue ~/ 2}'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 68,
                width: 150,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF6C00), width: 2),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 48,
                width: 150,
                child: OutlinedButton.icon(
                  onPressed: round.toggleInterruption,
                  icon: const Icon(Icons.radio_button_checked),
                  label: const Text('Interruption'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: round.matchComplete ? null : _recordChallenge,
                  icon: const Icon(Icons.gavel_outlined),
                  label: Text(round.challengeLabel),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                width: 340,
                child: FilledButton.tonalIcon(
                  onPressed: round.canUndo ? round.undo : null,
                  icon: const Icon(Icons.undo),
                  label: Text(
                    round.canUndo ? 'UNDO \u2014 ${round.undoLabel}' : 'Undo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Replaces the console once the round is finished. Undo stays reachable
  /// here because the console (which normally hosts it) is hidden.
  Widget _matchCompleteBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Give the final score to the quizmaster.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            width: 320,
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
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: round.addOvertimeQuestion,
              child: const Text('Add overtime question'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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
      height: 60,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            round.rulesetTitle,
            style: TextStyle(fontSize: 13, color: scheme.outline),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _openSummary,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Summary'),
            ),
          ),
        ],
      ),
    );
  }
}
