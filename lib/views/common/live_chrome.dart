import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../app/round_controller.dart';
import '../../engine/events.dart';
import '../../engine/round_view.dart';
import '../../engine/ruleset.dart';
import '../summary_screen.dart';
import 'choice_dialog.dart';
import 'common_bits.dart';

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

/// A small team-colored **seat title** pill. Deliberately quieter than the
/// quizzer's name: uppercase, small, letter-spaced, and visually distinct from
/// ordinary text. The parent row supplies the screen-reader label, so the badge
/// itself is excluded from semantics.
class SeatBadge extends StatelessWidget {
  const SeatBadge({
    super.key,
    required this.side,
    required this.seat,
    this.bench = false,
    this.compact = false,
  });

  final Side side;
  final int seat;
  final bool bench;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBench = bench || seat == 0;
    final teamLabel = side == Side.red ? 'RED' : 'GREEN';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onBench
            ? scheme.surfaceContainerHighest
            : sideTintFor(side, scheme),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: onBench ? scheme.outlineVariant : sideAccent(side, scheme),
        ),
      ),
      child: Text(
        onBench ? 'BENCH' : '$teamLabel $seat',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.1,
          color: onBench ? scheme.onSurfaceVariant : sideAccent(side, scheme),
        ),
      ),
    );
  }
}

/// Compact card for one benched quizzer. Replaces the old one-line text list so
/// bench membership reads at a glance without competing with the seated rows.
class BenchCard extends StatelessWidget {
  const BenchCard({
    super.key,
    required this.side,
    required this.quizzer,
    this.compact = false,
  });

  final Side side;
  final QuizzerView quizzer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 1 : 5,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: sideAccent(side, scheme).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sideTintFor(side, scheme),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: sideAccent(side, scheme).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'B',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: sideAccent(side, scheme),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 140 : 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizzer.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (quizzer.status.isNotEmpty)
                  Text(
                    quizzer.status,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: scheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${quizzer.score}',
            style: TextStyle(
              fontSize: compact ? 11.5 : 13,
              fontWeight: FontWeight.w900,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

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
    // With a quizzer selected on an unassigned question (D11), the console
    // becomes the value picker: the keeper must set 10/20/30 before a ruling
    // can be recorded. This is a required next step, not a blocked error.
    final needsValue =
        sel != null &&
        value == null &&
        round.questionValueEditable(round.questionNumber);
    final sideSuffix = sel == null ? '' : ' to ${sideName(round, sel.$1)}';
    // A question with no value assigned yet (D11) cannot be scored — the
    // guardrail blocks it above — so the buttons drop the point delta and the
    // status line carries the reason.
    final correctLabel = value == null ? 'CORRECT' : 'CORRECT  +$value';
    final incorrectLabel = value == null
        ? 'INCORRECT'
        : 'INCORRECT  \u2212${value ~/ 2}';
    final correctSpoken = value == null
        ? 'Correct answer$sideSuffix'
        : 'Correct answer, adds $value points$sideSuffix';
    final incorrectSpoken = value == null
        ? 'Incorrect answer$sideSuffix'
        : 'Incorrect answer, subtracts ${value ~/ 2} points$sideSuffix';
    final status = sel == null
        ? 'TAP A QUIZZER, THEN RECORD THE RULING — CORRECT / '
              'INCORRECT ADVANCE; FOUL STAYS'
        : needsValue
        ? '${sideName(round, sel.$1).toUpperCase()} '
              '${round.view.teamOf(sel.$1).roster[sel.$2].label.split(' ').last} '
              'ON Q${round.questionNumber} — CHOOSE THE POINT VALUE'
        : blocked != null
        ? 'BLOCKED — $blocked'
        : '${sideName(round, sel.$1).toUpperCase()} '
              '${round.view.teamOf(sel.$1).roster[sel.$2].label.split(' ').last} '
              'ON Q${round.questionNumber} — RECORD THE RULING';
    final statusColor = needsValue
        ? scheme.primary
        : blocked != null
        ? scheme.error
        : scheme.onSurface;
    Widget valueButton(int option) {
      return SizedBox(
        height: 68,
        width: 180,
        child: FilledButton.tonal(
          onPressed: () {
            hapticTick(context);
            round.setQuestionValue(round.questionNumber, option);
          },
          child: Semantics(
            label: 'Set question ${round.questionNumber} to $option points',
            excludeSemantics: true,
            child: Text(
              '$option PTS',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    Widget foulButton() {
      return SizedBox(
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
            hint: selected ? null : 'Select a quizzer first',
            excludeSemantics: true,
            child: const Text(
              'FOUL',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    Widget correctButton() {
      return SizedBox(
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
            label: correctSpoken,
            hint: answerHint,
            excludeSemantics: true,
            child: Text(
              correctLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    Widget incorrectButton() {
      return SizedBox(
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
            label: incorrectSpoken,
            hint: answerHint,
            excludeSemantics: true,
            child: Text(
              incorrectLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (needsValue)
                for (var i = 0; i < round.valueOptions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  valueButton(round.valueOptions[i]),
                ]
              else ...[
                correctButton(),
                const SizedBox(width: 12),
                incorrectButton(),
              ],
              const SizedBox(width: 12),
              foulButton(),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _recordFoul(BuildContext context) async {
    final sel = round.selected;
    if (sel == null) return;
    final quizzer = round.teamOf(sel.$1).roster[sel.$2];
    final deduction = round.ruleset.scoring.foulDeduction;
    final choice = await showChoiceDialog<String>(
      context: context,
      title: 'Record foul',
      subtitle: '${sideName(round, sel.$1)} \u00b7 ${quizzer.label} selected',
      options: [
        ChoiceOption(
          value: 'quizzer',
          icon: Icons.person_outline,
          label: 'Quizzer foul',
          description: '${quizzer.label} \u00b7 \u2212$deduction points',
          color: incorrectColor,
        ),
        ChoiceOption(
          value: 'team',
          icon: Icons.groups_outlined,
          label: 'Team foul',
          description:
              '${sideName(round, sel.$1)} total \u00b7 \u2212$deduction points',
          color: incorrectColor,
        ),
      ],
    );
    if (choice == 'quizzer') {
      round.addQuizzerFoul();
    } else if (choice == 'team') {
      round.addTeamFoul(sel.$1);
    }
  }
}

/// Shared bottom bar: undo, interruption, void, substitute quizzer, summary.
/// Team time-outs live beside the team names (Classic rail + Modern header),
/// not here — the bottom-right duplicates were removed in the polish pass.
class LiveBottomBar extends StatelessWidget {
  const LiveBottomBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Container(
      height: 60,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
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
          Expanded(
            flex: 2,
            child: action(
              icon: Icons.radio_button_checked,
              label: 'Interruption',
              onPressed: () {
                hapticTick(context);
                round.toggleInterruption();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: action(
              icon: Icons.block,
              label: 'Void question',
              onPressed: round.canVoidCurrentQuestion
                  ? () {
                      hapticTick(context);
                      round.voidQuestion();
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: action(
              icon: Icons.swap_horiz,
              label: 'Substitute quizzer',
              onPressed: () => _openSubstitution(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: action(
              icon: Icons.receipt_long,
              label: 'Summary',
              onPressed: round.matchComplete
                  ? () => _openSummary(context)
                  : null,
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

  void _openSubstitution(BuildContext context) {
    if (!round.hasSubstitutionOptions) {
      round.showAlert('No bench quizzer is available to substitute in.');
      return;
    }
    hapticTick(context);
    showSubstitutionBoard(context, round);
  }
}

/// Opens the single substitution surface. [preselect] is used by the quiz-out
/// prompt: the team is locked and the outgoing quizzer is already chosen.
Future<void> showSubstitutionBoard(
  BuildContext context,
  RoundController round, {
  SubstitutionPrompt? preselect,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SubstitutionBoard(round: round, preselect: preselect),
  );
}

class SubstitutionBoard extends StatefulWidget {
  const SubstitutionBoard({super.key, required this.round, this.preselect});

  final RoundController round;
  final SubstitutionPrompt? preselect;

  @override
  State<SubstitutionBoard> createState() => _SubstitutionBoardState();
}

class _SubstitutionBoardState extends State<SubstitutionBoard> {
  late Side _side;
  int? _outIndex;
  int? _benchIndex;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preselect = widget.preselect;
    if (preselect != null) {
      _side = preselect.side;
      _outIndex = preselect.outIndex;
    } else {
      _side =
          widget.round.selected?.$1 ??
          widget.round.substitutionPrompt?.side ??
          Side.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ListenableBuilder(
          listenable: widget.round,
          builder: (context, _) {
            final round = widget.round;
            final team = round.teamOf(_side);
            final seated = team.seated;
            final bench = team.bench;
            final eligibleBench = [
              for (final quizzer in bench)
                if (quizzer.status.isEmpty) quizzer,
            ];
            final outgoing = _find(team.roster, _outIndex);
            final incoming = _find(team.roster, _benchIndex);
            final canConfirm =
                outgoing != null &&
                !outgoing.onBench &&
                incoming != null &&
                incoming.onBench &&
                incoming.status.isEmpty;
            final preselect = widget.preselect;
            final subtitle = preselect == null
                ? 'Choose who leaves the table, then who takes the seat.'
                : '${sideName(round, preselect.side)} team \u00b7 '
                      '${preselect.outLabel} quizzed out. '
                      'Choose who takes seat ${preselect.outSeat}.';
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleRow(context),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (preselect == null)
                      Row(
                        children: [
                          for (final side in Side.values) ...[
                            if (side != Side.values.first)
                              const SizedBox(width: 12),
                            Expanded(child: _teamTab(context, side)),
                          ],
                        ],
                      )
                    else
                      _teamTab(context, _side, locked: true),
                    const SizedBox(height: 16),
                    _columnHeaders(context, seated.length, bench.length),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _seatedColumn(context, seated)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 28,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _benchColumn(
                              context,
                              bench,
                              eligibleBench.isEmpty,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summary(context, outgoing, incoming),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canConfirm
                                ? () => _confirm(context, outgoing, incoming)
                                : null,
                            child: const Text('CONFIRM SUBSTITUTION'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Substitute quizzer',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          tooltip: 'Close substitution',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _teamTab(BuildContext context, Side side, {bool locked = false}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = side == _side;
    final team = widget.round.teamOf(side);
    final benchCount = team.bench.length;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? sideTintFor(side, scheme) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? sideAccent(side, scheme) : scheme.outlineVariant,
          width: selected ? 3 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            sideName(widget.round, side).toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: sideAccent(side, scheme),
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.round.scoreOf(side)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                  color: selected ? sideInkFor(scheme) : scheme.onSurface,
                ),
              ),
              Text(
                '$benchCount on bench',
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? sideInkMutedFor(scheme) : scheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (locked) {
      return Semantics(
        label:
            '${sideName(widget.round, side)} team, '
            '${widget.round.scoreOf(side)} points, $benchCount on bench',
        excludeSemantics: true,
        child: content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectSide(side),
        child: Semantics(
          button: true,
          selected: selected,
          label:
              '${sideName(widget.round, side)} team, '
              '${widget.round.scoreOf(side)} points, $benchCount on bench',
          excludeSemantics: true,
          child: content,
        ),
      ),
    );
  }

  Widget _columnHeaders(BuildContext context, int seated, int bench) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
      color: Theme.of(context).colorScheme.outline,
    );
    return Row(
      children: [
        Expanded(child: Text('AT THE TABLE ($seated)', style: style)),
        const SizedBox(width: 52),
        Expanded(
          child: Text(
            'BENCH ($bench)',
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _seatedColumn(BuildContext context, List<QuizzerView> seated) {
    if (seated.isEmpty) {
      return _emptyState(context, 'No seated quizzers.');
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final quizzer in seated)
            _quizzerCard(
              context,
              quizzer,
              bench: false,
              selected: _outIndex == quizzer.index,
              onTap: () => setState(() {
                _outIndex = quizzer.index;
                _error = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _benchColumn(
    BuildContext context,
    List<QuizzerView> bench,
    bool noEligible,
  ) {
    if (bench.isEmpty) {
      return _emptyState(
        context,
        'No bench quizzers for ${sideName(widget.round, _side)}.',
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (noEligible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No eligible bench quizzers.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          for (final quizzer in bench)
            _quizzerCard(
              context,
              quizzer,
              bench: true,
              selected: _benchIndex == quizzer.index,
              onTap: quizzer.status.isEmpty
                  ? () => setState(() {
                      _benchIndex = quizzer.index;
                      _error = null;
                    })
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _quizzerCard(
    BuildContext context,
    QuizzerView quizzer, {
    required bool bench,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final onTint = selected;
    final card = Opacity(
      opacity: enabled || selected ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? sideTintFor(_side, scheme) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? sideAccent(_side, scheme) : scheme.outlineVariant,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: Row(
          children: [
            SeatBadge(side: _side, seat: quizzer.seat, bench: bench),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quizzer.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onTint ? sideInkFor(scheme) : scheme.onSurface,
                    ),
                  ),
                  if (quizzer.status.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quizzer.status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${quizzer.score}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: onTint ? sideInkFor(scheme) : scheme.onSurface,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: 20,
                color: sideAccent(_side, scheme),
              ),
            ],
          ],
        ),
      ),
    );
    final label = bench
        ? '${sideName(widget.round, _side)} bench, ${quizzer.label}, '
              '${quizzer.score} points'
        : '${sideName(widget.round, _side)} seat ${quizzer.seat}, '
              '${quizzer.label}, ${quizzer.score} points';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Semantics(
          button: enabled,
          enabled: enabled,
          selected: selected,
          label: quizzer.status.isEmpty ? label : '$label, ${quizzer.status}',
          hint: !enabled
              ? 'Unavailable'
              : selected
              ? 'Selected'
              : 'Tap to choose',
          excludeSemantics: true,
          child: card,
        ),
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    QuizzerView? outgoing,
    QuizzerView? incoming,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final text = outgoing == null
        ? 'Select the quizzer leaving the table.'
        : incoming == null
        ? '${outgoing.label} is leaving seat ${outgoing.seat}. '
              'Choose who takes it.'
        : '${outgoing.label} (seat ${outgoing.seat}) \u2192 bench   '
              '\u00b7   ${incoming.label} \u2192 seat ${outgoing.seat}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: scheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.event_seat, color: scheme.outline),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }

  QuizzerView? _find(List<QuizzerView> roster, int? index) {
    if (index == null || index < 0 || index >= roster.length) return null;
    return roster[index];
  }

  void _selectSide(Side side) {
    if (widget.preselect != null || side == _side) return;
    setState(() {
      _side = side;
      _outIndex = null;
      _benchIndex = null;
      _error = null;
    });
  }

  void _confirm(
    BuildContext context,
    QuizzerView outgoing,
    QuizzerView incoming,
  ) {
    final ok = widget.round.substituteQuizzer(
      side: _side,
      outIndex: outgoing.index,
      benchIndex: incoming.index,
    );
    if (!ok) {
      setState(() {
        _error = widget.round.lastAlert ?? 'That substitution is not allowed.';
      });
      return;
    }
    hapticTick(context);
    Navigator.pop(context);
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
    final successful = await showChoiceDialog<bool>(
      context: context,
      title: 'Record ${round.challengeLabel}',
      subtitle: '${sideName(round, side)} \u00b7 choose the outcome',
      options: [
        ChoiceOption(
          value: true,
          icon: Icons.check_circle_outline,
          label: 'Granted',
          description: 'Successful ${round.challengeLabel.toLowerCase()}',
          color: correctColor,
        ),
        ChoiceOption(
          value: false,
          icon: Icons.cancel_outlined,
          label: 'Denied',
          description: 'Unsuccessful ${round.challengeLabel.toLowerCase()}',
          color: incorrectColor,
        ),
      ],
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
              '${round.currentValue(round.questionNumber) ?? 0} PTS \u00b7 '
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

/// The current question's point value, shown in both live headers (D11).
/// Tappable to set it (the shared value dialog); overtime slots and a completed
/// match render as a read-out. A prominent "SET VALUE" (error tint) when the
/// current question has no value yet, so the keeper can see scoring is
/// blocked until it is set.
class CurrentValueButton extends StatelessWidget {
  const CurrentValueButton({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = round.questionNumber;
    final value = round.currentValue(n);
    final editable = round.questionValueEditable(n);

    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: value == null ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value == null ? scheme.error : scheme.primary,
          width: 2,
        ),
      ),
      child: Text(
        value == null ? 'SET VALUE' : '$value PTS',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: value == null
              ? scheme.onErrorContainer
              : scheme.onPrimaryContainer,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );

    if (!editable) {
      return Semantics(
        label: 'Question $n point value ${value == null ? 'unset' : '$value'}',
        excludeSemantics: true,
        child: box,
      );
    }
    return InkWell(
      enableFeedback: false,
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showValuePicker(
          context,
          questionNumber: n,
          options: round.valueOptions,
          current: value,
        );
        if (picked != null) round.setQuestionValue(n, picked);
      },
      child: Semantics(
        button: true,
        label: 'Question $n point value ${value == null ? 'unset' : '$value'}',
        hint: 'Tap to set the point value',
        excludeSemantics: true,
        child: box,
      ),
    );
  }
}

/// Single, unified home for every notice a keeper must not miss: the
/// end-of-round strip, the autosave-failure warning, the last-edit undo,
/// the transient [AlertBanner], and the persistent substitution prompt. Both
/// live views place this in the same slot directly above the scoring console,
/// so a notice always appears in one prominent, predictable place instead of
/// bouncing between the header and the console area.
class NoticeSlot extends StatelessWidget {
  const NoticeSlot({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final prompt = round.substitutionPrompt;
    // The persistent prompt is the notification for a quiz-out that can be
    // substituted. Hide the duplicate transient alert in that one case; other
    // notices (and quiz-outs without a bench) still use the alert banner.
    final quizOutAlert = prompt == null
        ? null
        : '${prompt.side.name.toUpperCase()} ${prompt.outLabel} quizzed out';
    final hideQuizOutAlert =
        prompt != null && (round.lastAlert ?? '').startsWith(quizOutAlert!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (round.matchComplete || round.inOvertime)
          EndOfRoundBar(round: round),
        SaveErrorBar(round: round),
        LastEditBar(round: round),
        if (!hideQuizOutAlert) AlertBanner(round: round),
        SubstitutionPromptBar(round: round),
      ],
    );
  }
}

/// Static one-level safety net for direct action edits. It disappears on the
/// next normal scoring action (the controller drops the snapshot) so it can
/// never rewind rulings recorded after the edit.
class LastEditBar extends StatelessWidget {
  const LastEditBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    if (!round.canUndoLastEdit) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${round.lastEditLabel ?? 'Action edited'} — undo this edit?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: () {
                hapticTick(context);
                round.undoLastEdit();
              },
              child: const Text('UNDO EDIT'),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss edit undo',
            onPressed: round.clearLastEdit,
            icon: Icon(Icons.close, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Persistent quiz-out substitution opportunity. Unlike the transient alert,
/// this survives later notices and stays until the keeper substitutes,
/// dismisses it, or undoes the quiz-out.
class SubstitutionPromptBar extends StatelessWidget {
  const SubstitutionPromptBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final prompt = round.substitutionPrompt;
    if (prompt == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final bench = prompt.onlyBench;
    final benchText = bench == null
        ? '${prompt.benchCount} bench quizzers can replace them.'
        : '${bench.label} (${bench.score} pts) can replace them.';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: sideTintFor(prompt.side, scheme),
          border: Border(
            left: BorderSide(color: sideAccent(prompt.side, scheme), width: 4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(
          children: [
            Icon(Icons.swap_horiz, color: sideAccent(prompt.side, scheme)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${sideName(round, prompt.side)}: ${prompt.outLabel} '
                'quizzed out. $benchText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sideInkFor(scheme),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: sideAccent(prompt.side, scheme),
                  side: BorderSide(color: sideAccent(prompt.side, scheme)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  hapticTick(context);
                  showSubstitutionBoard(context, round, preselect: prompt);
                },
                child: const Text('SUBSTITUTE'),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss substitution prompt',
              onPressed: round.dismissSubstitutionPrompt,
              icon: Icon(Icons.close, color: sideInkMutedFor(scheme)),
            ),
          ],
        ),
      ),
    );
  }
}
