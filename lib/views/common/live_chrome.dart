import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../app/round_controller.dart';
import '../../engine/events.dart';
import '../../engine/ruleset.dart';
import '../summary_screen.dart';
import 'common_bits.dart';
import 'quiet_controls.dart';

/// Fixed red/green identity: sides come from the physical quiz box.
const redColor = Color(0xFFC62828);
const greenColor = Color(0xFF2E7D32);

/// Light-mode team tints (pale pastels).
const redTint = Color(0xFFFCE8E6);
const greenTint = Color(0xFFE6F4EA);

/// Dark-mode team tints. The pale pastels above glare as large blocks against
/// a dark surface, so dark mode uses these deep, desaturated tints instead.
const redTintDark = Color(0xFF3A1E1E);
const greenTintDark = Color(0xFF17301C);

Color sideColor(Side side) => side == Side.red ? redColor : greenColor;

/// The light team tint. Prefer [sideTintFor] on any surface whose surrounding
/// theme can vary.
Color sideTint(Side side) => side == Side.red ? redTint : greenTint;

/// Team tint for the *current* theme: pale in light mode, deep in dark mode.
Color sideTintFor(Side side, ColorScheme scheme) {
  if (scheme.brightness == Brightness.light) return sideTint(side);
  return side == Side.red ? redTintDark : greenTintDark;
}

/// Dark-mode variants of the team accents. [sideColor] is a deep red/green
/// that disappears against dark theme surfaces (score cards, the bottom bar,
/// the time-out rail), so on a dark surface the side accent is lightened
/// instead. Light mode keeps the exact same accent, so light-mode rendering is
/// untouched.
const redAccentDark = Color(0xFFFF8A80);
const greenAccentDark = Color(0xFF81C784);

/// Side accent that stays legible on the *current* theme surface: the fixed
/// [sideColor] in light mode, a lightened accent in dark mode. Use this for
/// side labels/borders drawn on `scheme.surface*` or on a [sideTintFor]
/// surface; content sitting on a tint must use [sideInkFor]/[sideInkMutedFor]
/// for its body text.
Color sideAccent(Side side, ColorScheme scheme) {
  if (scheme.brightness == Brightness.light) return sideColor(side);
  return side == Side.red ? redAccentDark : greenAccentDark;
}

/// Ink for content sitting directly on a team tint: near-black on the pale
/// light tints, near-white on the deep dark tints, so it clears contrast in
/// either theme. Use the `…For` variants with the active [ColorScheme].
const sideInk = Color(0xFF1F2426);
const sideInkMuted = Color(0xFF495156);
const sideInkDark = Color(0xFFF2F4F5);
const sideInkDarkMuted = Color(0xFFC6CDD0);

Color sideInkFor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light ? sideInk : sideInkDark;
Color sideInkMutedFor(ColorScheme scheme) =>
    scheme.brightness == Brightness.light ? sideInkMuted : sideInkDarkMuted;

/// Theme-aware ink: legible on a tinted surface, normal on-surface otherwise.
Color inkOnTint(ColorScheme scheme, bool onTint) =>
    onTint ? sideInkFor(scheme) : scheme.onSurface;
Color mutedInkOnTint(ColorScheme scheme, bool onTint) =>
    onTint ? sideInkMutedFor(scheme) : scheme.outline;

/// Ruling colors for the scoring console: green = correct, red = incorrect.
/// Deliberately the same Material shades as the team colors so the palette
/// stays small; the labels and placement carry the team-vs-ruling meaning.
const correctColor = greenColor;
const incorrectColor = redColor;
String sideName(RoundController round, Side side) =>
    side == Side.red ? round.redName : round.greenName;

String rulesetTitle(Ruleset r) => '${r.displayName} ${r.season}';

/// Returns from a live-scoring screen to the starting screen (Home). Every
/// ruling autosaves, so leaving mid-match is safe — the round resumes from
/// Home. Mirrors the Summary screen's back affordance, and pops to the first
/// route rather than just one step so it works from the resume path too.
class LiveBackButton extends StatelessWidget {
  const LiveBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back to start',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }
}

/// Shared scoring console: quizzer picker is the parent screen; this row
/// records the ruling for the selected quizzer (or team foul).
class ScoringConsole extends StatelessWidget {
  const ScoringConsole({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = round.selected;
    final blocked = sel == null
        ? null
        : round.scoreBlockedReason(sel.$1, sel.$2, round.questionNumber);
    // A quizzer must be selected for any ruling; a guarded answer additionally
    // disables CORRECT/INCORRECT. FOUL is never answer-guarded, so it stays
    // live whenever a quizzer is selected.
    final selected = sel != null && !round.matchComplete;
    final canAnswer = selected && blocked == null;
    // Semantic hint on the disabled ruling buttons: TalkBack reads it with
    // the label so a screen-reader user learns *why* a button is dimmed.
    final answerHint = round.matchComplete
        ? 'Match complete'
        : blocked ?? (sel == null ? 'Select a quizzer first' : null);
    final value = round.currentValue(round.questionNumber);
    final sideSuffix = sel == null ? '' : ' to ${sideName(round, sel.$1)}';
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            sel == null
                ? 'TAP A QUIZZER, THEN RECORD THE RULING — CORRECT / '
                      'INCORRECT ADVANCE; FOUL STAYS'
                : blocked != null
                ? 'BLOCKED — $blocked'
                : '${sideName(round, sel.$1).toUpperCase()} '
                      '${round.view.teamOf(sel.$1).roster[sel.$2].label.split(' ').last} '
                      'ON Q${round.questionNumber} — RECORD THE RULING',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: blocked != null ? scheme.error : scheme.onSurface,
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
                  onPressed: canAnswer
                      ? () {
                          hapticTick(context);
                          round.markCorrect();
                        }
                      : null,
                  child: Semantics(
                    label: 'Correct answer, adds $value points$sideSuffix',
                    hint: answerHint,
                    excludeSemantics: true,
                    child: Text('CORRECT  +$value'),
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
                  onPressed: canAnswer
                      ? () {
                          hapticTick(context);
                          round.markIncorrect();
                        }
                      : null,
                  child: Semantics(
                    label:
                        'Incorrect answer, subtracts ${value ~/ 2} points'
                        '$sideSuffix',
                    hint: answerHint,
                    excludeSemantics: true,
                    child: Text('INCORRECT  \u2212${value ~/ 2}'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 68,
                width: 220,
                child: OutlinedButton(
                  onPressed: selected
                      ? () {
                          hapticTick(context);
                          _recordFoul(context);
                        }
                      : null,
                  child: Semantics(
                    label:
                        'Foul, subtracts '
                        '${round.ruleset.scoring.foulDeduction} points'
                        '$sideSuffix',
                    hint: answerHint,
                    excludeSemantics: true,
                    child: const Text('FOUL'),
                  ),
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
          QuietDialogOption(
            onPressed: () => Navigator.pop(context, 'quizzer'),
            child: const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quizzer foul (selected quizzer, −5)'),
              ),
            ),
          ),
          QuietDialogOption(
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

/// Shared bottom bar: undo, interruption, contest/appeal, overflow, summary.
/// Team time-outs live beside the team names (Classic rail + Modern header),
/// not here — the bottom-right duplicates were removed in the polish pass.
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
                onPressed: round.canUndo
                    ? () {
                        hapticTick(context);
                        round.undo();
                      }
                    : null,
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
              onPressed: () {
                hapticTick(context);
                round.toggleInterruption();
              },
              icon: const Icon(Icons.radio_button_checked),
              label: const Text('Interruption'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: PopupMenuButton<String>(
              tooltip: 'More actions',
              enableFeedback: false,
              onSelected: (v) => _more(context, v),
              itemBuilder: (context) {
                final marks = round.view.questionMarks;
                final voided =
                    round.questionNumber <= marks.length &&
                    marks[round.questionNumber - 1].voided;
                final anyVoided = marks.any((m) => m.voided);
                return [
                  QuietMenuItem(
                    value: 'void',
                    enabled: !voided,
                    child: Text(
                      voided
                          ? 'Void question (Q${round.questionNumber} already void)'
                          : 'Void question',
                    ),
                  ),
                  QuietMenuItem(
                    value: 'sub-question',
                    // The engine rejects a substitute without a voided slot.
                    enabled: anyVoided,
                    child: Text(
                      anyVoided
                          ? 'Read substitute question'
                          : 'Read substitute question (void a question first)',
                    ),
                  ),
                  const QuietMenuItem(
                    value: 'sub-quizzer',
                    child: Text('Substitute quizzer'),
                  ),
                ];
              },
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
              onPressed: round.matchComplete
                  ? () => _openSummary(context)
                  : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Summary'),
            ),
          ),
        ],
      ),
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
            QuietDialogOption(
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
    // Any seated quizzer may be substituted — during or after a time-out — and
    // a substitution does NOT require anyone to have quizzed out. The outgoing
    // quizzer sits behind the table and the chosen bench quizzer takes it.
    final slots = <(Side, int)>[];
    final labels = <String>[];
    for (final side in Side.values) {
      for (final q in round.teamOf(side).seated) {
        slots.add((side, q.index));
        labels.add(
          q.status.isEmpty
              ? '${sideName(round, side)} — ${q.label}'
              : '${sideName(round, side)} — ${q.label} (${q.status})',
        );
      }
    }
    if (slots.isEmpty) {
      round.showAlert('No seated quizzer to substitute.');
      return;
    }
    final anyBench = Side.values.any(
      (s) => round.teamOf(s).bench.any((q) => q.status.isEmpty),
    );
    if (!anyBench) {
      round.showAlert('No bench quizzer is available to substitute in.');
      return;
    }
    final pick = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Substitute out which quizzer?'),
        children: [
          for (var i = 0; i < slots.length; i++)
            QuietDialogOption(
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
    final slot = slots[pick];
    // Only bench quizzers who are still eligible (not out) can come in.
    final bench = [
      for (final q in round.teamOf(slot.$1).bench)
        if (q.status.isEmpty) q,
    ];
    if (bench.isEmpty) {
      round.showAlert(
        'No eligible bench quizzer for ${sideName(round, slot.$1)}.',
      );
      return;
    }
    final benchPick = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Substitute in — ${sideName(round, slot.$1)} bench'),
        children: [
          for (var i = 0; i < bench.length; i++)
            QuietDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${bench[i].label}  (${bench[i].score} pts)'),
                ),
              ),
            ),
        ],
      ),
    );
    if (benchPick == null) return;
    round.substituteQuizzer(
      side: slot.$1,
      outIndex: slot.$2,
      benchIndex: bench[benchPick].index,
    );
  }
}

/// Persistent end-of-round strip. Shows the winner once the round is decided,
/// or the live overtime state while overtime is in progress. Overtime opens
/// automatically when regulation ends tied, so there is deliberately no
/// button here for the keeper to press.
/// Team-level buttons beside the team name: team foul (coach/assistant/
/// inactive — hits the team total only) and contest/appeal tally + entry.
/// Mirrors the time-out pattern: the tally reads like the paper sheet and the
/// button is the entry point. Personal fouls are recorded per-quizzer and show
/// on the cells, so they are deliberately not counted here.
class TeamHeaderButtons extends StatelessWidget {
  const TeamHeaderButtons({super.key, required this.round, required this.side});

  final RoundController round;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final team = round.teamOf(side);
    final limits = round.ruleset.limits;
    // TBQ tracks unsuccessful contests (3rd ends them); JBQ tracks used
    // appeals against the 2-per-team allotment.
    final challenges = limits.challengeAllotmentPerTeam != null
        ? '${team.challengesUsed}/${limits.challengeAllotmentPerTeam}'
        : '${team.unsuccessfulChallenges}/${limits.challengeLimitCount}';
    final style = OutlinedButton.styleFrom(
      side: BorderSide(color: sideAccent(side, scheme), width: 1.5),
      foregroundColor: sideAccent(side, scheme),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: style,
            onPressed: round.matchComplete
                ? null
                : () {
                    hapticTick(context);
                    round.addTeamFoul(side);
                  },
            child: Semantics(
              label:
                  'Team foul for ${sideName(round, side)}, subtracts '
                  '${round.ruleset.scoring.foulDeduction} points',
              excludeSemantics: true,
              child: Text('TEAM FOUL ${team.teamFouls}'),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: style,
            onPressed: round.matchComplete
                ? null
                : () {
                    hapticTick(context);
                    _recordChallenge(context);
                  },
            child: Semantics(
              label:
                  '${round.challengeLabel} for ${sideName(round, side)} '
                  '($challenges)',
              excludeSemantics: true,
              child: Text('${round.challengeLabel.toUpperCase()} $challenges'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _recordChallenge(BuildContext context) async {
    final successful = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          'Record ${round.challengeLabel} — ${sideName(round, side)}',
        ),
        children: [
          for (final s in const <bool>[true, false])
            QuietDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s ? 'Granted (successful)' : 'Denied (unsuccessful)',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (successful == null) return;
    round.recordChallenge(side, successful: successful);
  }
}

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

/// Single, unified home for every notice a keeper must not miss: the
/// end-of-round strip (persistent) and the transient [AlertBanner]. Both live
/// views place this in the same slot directly above the scoring console, so a
/// notice always appears in one prominent, predictable place instead of
/// bouncing between the header and the console area.
class NoticeSlot extends StatelessWidget {
  const NoticeSlot({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (round.matchComplete || round.inOvertime)
          EndOfRoundBar(round: round),
        AlertBanner(round: round),
      ],
    );
  }
}
