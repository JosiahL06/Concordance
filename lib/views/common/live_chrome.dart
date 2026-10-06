import 'package:flutter/material.dart';

import '../../app/round_controller.dart';
import '../../engine/events.dart';
import '../../engine/ruleset.dart';
import '../summary_screen.dart';

/// Fixed red/green identity: sides come from the physical quiz box.
const redColor = Color(0xFFC62828);
const redTint = Color(0xFFFCE8E6);
const greenColor = Color(0xFF2E7D32);
const greenTint = Color(0xFFE6F4EA);

Color sideColor(Side side) => side == Side.red ? redColor : greenColor;
Color sideTint(Side side) => side == Side.red ? redTint : greenTint;

/// Dark-mode variants of the team accents. [sideColor] is a deep red/green
/// that disappears against dark theme surfaces (score cards, the bottom bar,
/// the time-out rail), so on a dark surface the side accent is lightened
/// instead. Light mode keeps the exact same accent, so light-mode rendering is
/// untouched.
const redAccentDark = Color(0xFFFF8A80);
const greenAccentDark = Color(0xFF81C784);

/// Side accent that stays legible on the *current* theme surface: the fixed
/// [sideColor] in light mode, a lightened accent in dark mode. Use this for
/// side labels/borders drawn on `scheme.surface*`; content sitting on a fixed
/// light [sideTint] must use [sideInk]/[sideInkMuted] instead.
Color sideAccent(Side side, ColorScheme scheme) {
  if (scheme.brightness == Brightness.light) return sideColor(side);
  return side == Side.red ? redAccentDark : greenAccentDark;
}

/// Ink for content sitting directly on a [sideTint] surface. The tints are
/// fixed *light* colors, so this text MUST be fixed dark — using
/// `ColorScheme.onSurface` would render near-white text on a pale tint in
/// dark mode.
const sideInk = Color(0xFF1F2426);
const sideInkMuted = Color(0xFF495156);

/// Theme-aware ink: dark on a tinted surface, normal on-surface otherwise.
Color inkOnTint(ColorScheme scheme, bool onTint) =>
    onTint ? sideInk : scheme.onSurface;
Color mutedInkOnTint(ColorScheme scheme, bool onTint) =>
    onTint ? sideInkMuted : scheme.outline;

/// Ruling colors for the scoring console: green = correct, red = incorrect.
/// Deliberately the same Material shades as the team colors so the palette
/// stays small; the labels and placement carry the team-vs-ruling meaning.
const correctColor = greenColor;
const incorrectColor = redColor;
String sideName(RoundController round, Side side) =>
    side == Side.red ? round.redName : round.greenName;

String rulesetTitle(Ruleset r) => '${r.displayName} ${r.season}';

/// Shared scoring console: quizzer picker is the parent screen; this row
/// records the ruling for the selected quizzer (or team foul).
class ScoringConsole extends StatelessWidget {
  const ScoringConsole({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = round.selected;
    final enabled = sel != null && !round.matchComplete;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            sel == null
                ? 'TAP A QUIZZER, THEN RECORD THE RULING — CORRECT / '
                      'INCORRECT ADVANCE; FOUL STAYS'
                : '${sideName(round, sel.$1).toUpperCase()} '
                      '${round.view.teamOf(sel.$1).quizzers[sel.$2].label.split(' ').last} '
                      'ON Q${round.questionNumber} — RECORD THE RULING',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 68,
                width: 300,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: correctColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: enabled ? round.markCorrect : null,
                  child: Text(
                    'CORRECT  +${round.currentValue(round.questionNumber)}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 68,
                width: 300,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: incorrectColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: enabled ? round.markIncorrect : null,
                  child: Text(
                    'INCORRECT  −${round.currentValue(round.questionNumber) ~/ 2}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 68,
                width: 220,
                child: OutlinedButton(
                  onPressed: enabled ? () => _recordFoul(context) : null,
                  child: const Text('FOUL'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _recordFoul(BuildContext context) async {
    final sel = round.selected;
    if (sel == null) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Record foul'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'quizzer'),
            child: const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quizzer foul (selected quizzer, −5)'),
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'team'),
            child: const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Team foul (team total, −5)'),
              ),
            ),
          ),
        ],
      ),
    );
    if (choice == 'quizzer') {
      round.addQuizzerFoul();
    } else if (choice == 'team') {
      round.addTeamFoul(sel.$1);
    }
  }
}

/// Shared bottom bar: undo, interruption, contest/appeal, time-outs, summary.
class LiveBottomBar extends StatelessWidget {
  const LiveBottomBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
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
              onPressed: round.matchComplete
                  ? null
                  : () => _recordChallenge(context),
              icon: const Icon(Icons.gavel_outlined),
              label: Text(round.challengeLabel),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (v) => _more(context, v),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'void', child: Text('Void question')),
                PopupMenuItem(
                  value: 'sub-question',
                  child: Text('Read substitute question'),
                ),
                PopupMenuItem(
                  value: 'sub-quizzer',
                  child: Text('Substitute quizzer'),
                ),
              ],
              child: const SizedBox(
                height: 48,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz),
                    SizedBox(width: 6),
                    Text('More'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openSummary(context),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Summary'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: sideAccent(Side.red, scheme), width: 2),
                foregroundColor: sideAccent(Side.red, scheme),
              ),
              onPressed: () => round.takeTimeOut(Side.red),
              child: Text(
                'RED TO ${round.teamOf(Side.red).timeOuts}/${round.timeOutDisplayCap(Side.red)}',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: sideAccent(Side.green, scheme),
                  width: 2,
                ),
                foregroundColor: sideAccent(Side.green, scheme),
              ),
              onPressed: () => round.takeTimeOut(Side.green),
              child: Text(
                'GREEN TO ${round.teamOf(Side.green).timeOuts}/${round.timeOutDisplayCap(Side.green)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordChallenge(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Record ${round.challengeLabel}'),
        children: [
          for (final side in Side.values)
            for (final successful in const <bool>[true, false])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  '${side.name}|${successful ? 1 : 0}',
                ),
                child: SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${sideName(round, side)} — '
                      '${successful ? 'granted (successful)' : 'denied (unsuccessful)'}',
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (choice == null) return;
    final parts = choice.split('|');
    round.recordChallenge(
      Side.values.byName(parts[0]),
      successful: parts[1] == '1',
    );
  }

  void _openSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SummaryScreen(controller: round)),
    );
  }

  Future<void> _more(BuildContext context, String action) async {
    switch (action) {
      case 'void':
        round.voidQuestion();
      case 'sub-question':
        await _substituteQuestion(context);
      case 'sub-quizzer':
        await _substituteQuizzer(context);
    }
  }

  /// Voiding is refused by the engine while the question stands; the
  /// substitute value then re-opens the slot for scoring.
  Future<void> _substituteQuestion(BuildContext context) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Substitute question value'),
        children: [
          for (final value in const <int>[10, 20, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('$value points'),
                ),
              ),
            ),
        ],
      ),
    );
    if (choice == null) return;
    round.substituteQuestion(choice);
  }

  Future<void> _substituteQuizzer(BuildContext context) async {
    // Only an out quizzer can be replaced (engine enforces too).
    final slots = <(Side, int)>[];
    final labels = <String>[];
    for (final side in Side.values) {
      final team = round.teamOf(side);
      for (var i = 0; i < team.quizzers.length; i++) {
        final q = team.quizzers[i];
        if (!q.active && q.status.isNotEmpty) {
          slots.add((side, i));
          labels.add('${sideName(round, side)} — ${q.label} (${q.status})');
        }
      }
    }
    if (slots.isEmpty) return;
    final pick = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Replace which quizzer?'),
        children: [
          for (var i = 0; i < slots.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(labels[i]),
                ),
              ),
            ),
        ],
      ),
    );
    if (pick == null || !context.mounted) return;
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New quizzer label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Red 4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Substitute'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null || label.trim().isEmpty) return;
    final slot = slots[pick];
    round.substituteQuizzer(side: slot.$1, outIndex: slot.$2, label: label);
  }
}

/// Persistent end-of-round strip. Shows the winner once the round is decided,
/// or the live overtime state while overtime is in progress. Overtime opens
/// automatically when regulation ends tied, so there is deliberately no
/// button here for the keeper to press.
class EndOfRoundBar extends StatelessWidget {
  const EndOfRoundBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final red = round.scoreOf(Side.red);
    final green = round.scoreOf(Side.green);
    final headline = round.matchComplete
        ? '${(red > green ? round.redName : round.greenName).toUpperCase()} '
              'WINS $red\u2013$green'
        : 'OVERTIME \u00b7 Q${round.questionNumber} \u00b7 '
              '${round.currentValue(round.questionNumber)} PTS \u00b7 '
              '$red\u2013$green';
    return Container(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              headline,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SummaryScreen(controller: round),
                ),
              ),
              child: const Text('View summary'),
            ),
          ),
        ],
      ),
    );
  }
}
