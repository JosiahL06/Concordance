import 'package:flutter/material.dart';

import '../app/haptics.dart';
import '../app/round_controller.dart';
import '../engine/events.dart';
import '../engine/round_view.dart';
import 'common/choice_dialog.dart';
import 'common/live_chrome.dart';
import 'common/haptics_toggle.dart';
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
                  Expanded(child: _ledger(context)),
                  NoticeSlot(round: round),
                  ScoringConsole(round: round),
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
      height: 64,
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
                  '${rulesetTitle(round.ruleset)} \u00b7 scoresheet ledger',
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
          CurrentValueButton(round: round),
          const SizedBox(width: 8),
          const ThemeToggleButton(),
          const HapticsToggleButton(),
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
    return Row(
      children: [
        const SizedBox(width: _kLabelWidth),
        for (final n in _visibleQuestions)
          Expanded(child: _headerCell(context, n)),
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

  /// One question column header: the number with an interruption ring (paper
  /// circle) and the question's point value underneath (D11). A normal slot
  /// opens the quick value picker. A slot with something to edit (interruption,
  /// void/substitute, or an answered value) opens the question editor instead,
  /// so a late question-level mistake can be corrected directly.
  Widget _headerCell(BuildContext context, int n) {
    final scheme = Theme.of(context).colorScheme;
    final marks = round.view.questionMarks;
    final mark = n <= marks.length ? marks[n - 1] : null;
    final interrupted = mark?.interrupted ?? false;
    final voided = mark?.voided ?? false;
    final current = n == round.questionNumber;
    final value = round.currentValue(n);
    final editable = round.questionValueEditable(n);
    final needsEditor = round.questionNeedsEditor(n);

    Widget cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: current ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$n',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: current ? scheme.onPrimary : scheme.onSurface,
              decoration: voided ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            voided
                ? 'void'
                : value == null
                ? 'set'
                : '$value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: current
                  ? scheme.onPrimary
                  : voided || value == null
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (interrupted) {
      // Paper sheet circles the interrupted question number — same orange
      // ring as QuestionNavigator.
      cell = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEF6C00), width: 2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: cell,
      );
    }

    final spoken = <String>['Question $n'];
    if (current) spoken.add('current');
    if (interrupted) spoken.add('interrupted');
    if (voided) spoken.add('voided');
    if (value != null && !voided) spoken.add('$value points');

    if (needsEditor) {
      return Semantics(
        button: true,
        label: spoken.join(', '),
        hint: 'Tap to edit this question',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
            hapticTick(context);
            _showQuestionEditor(n);
          },
          child: cell,
        ),
      );
    }

    if (!editable) {
      return Semantics(
        label: 'Question $n value ${value == null ? 'unset' : '$value'}',
        excludeSemantics: true,
        child: cell,
      );
    }
    return InkWell(
      enableFeedback: false,
      borderRadius: BorderRadius.circular(9),
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
        child: cell,
      ),
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

  /// Bench strip inside the team block: compact cards, one per benched
  /// quizzer, so the bench reads as a distinct group rather than a text line.
  Widget _benchLine(BuildContext context, Side side) {
    final scheme = Theme.of(context).colorScheme;
    final bench = round.teamOf(side).bench;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < bench.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    BenchCard(side: side, quizzer: bench[i], compact: true),
                  ],
                ],
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
        Semantics(
          label: '${sideName(round, side)} score ${round.scoreOf(side)}',
          excludeSemantics: true,
          child: Text(
            'SCORE ${round.scoreOf(side)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: sideInkFor(scheme),
            ),
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
    // One merged utterance: name + status with selection state. The score
    // lives in the TOTAL column and gets its own label below.
    final spoken = <String>[quizzer.label];
    if (quizzer.seat != 0) spoken.add('seat ${quizzer.seat}');
    if (quizzer.status.isNotEmpty) spoken.add(quizzer.status.toLowerCase());
    final label = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        enableFeedback: false,
        onTap: quizzer.active
            ? () {
                hapticTick(context);
                round.select(side, index);
              }
            : null,
        child: Semantics(
          button: quizzer.active,
          enabled: quizzer.active,
          selected: selected,
          label: spoken.join(', '),
          excludeSemantics: true,
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
                Row(
                  children: [
                    SeatBadge(side: side, seat: quizzer.seat, compact: true),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quizzer.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
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
              child: Semantics(
                label: '${quizzer.label} total, ${quizzer.score} points',
                excludeSemantics: true,
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
      text = '+${round.currentValue(n) ?? 0}';
      color = scheme.primary;
      weight = FontWeight.w800;
    } else if (mark == 'incorrect') {
      text = '\u2212${(round.currentValue(n) ?? 0) ~/ 2}';
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
    // Spell out what the cell's styling conveys (delta, F, ring) so a
    // screen reader gets the same information sighted keepers see.
    final spoken = <String>['Question $n', quizzer.label];
    if (mark == 'correct') {
      spoken.add('correct, plus ${round.currentValue(n) ?? 0}');
    } else if (mark == 'incorrect') {
      spoken.add('incorrect, minus ${(round.currentValue(n) ?? 0) ~/ 2}');
    }
    if (hasFoul) spoken.add('foul');
    if (interrupted) spoken.add('interrupted');
    if (contested) spoken.add('contested');
    if (n == round.questionNumber) spoken.add('current question');
    // A marked answer is directly editable even when the quizzer is out: the
    // ruling still needs correcting. Empty cells keep navigate-and-select.
    final answerActions = round.answerActionsAtCell(side, index, n);
    final canEdit = answerActions.isNotEmpty;
    final canTap = canEdit || quizzer.active;
    return InkWell(
      enableFeedback: false,
      onTap: canTap
          ? () {
              hapticTick(context);
              if (canEdit) {
                _editAnswerCell(side, index, n);
              } else {
                round.jumpToQuestion(n);
                round.selectIfNeeded(side, index);
              }
            }
          : null,
      child: Semantics(
        button: canTap,
        enabled: canTap,
        selected: isTarget,
        label: spoken.join(', '),
        hint: canEdit ? 'Tap to edit this answer' : null,
        excludeSemantics: true,
        child: cell,
      ),
    );
  }

  /// Compact editor for a recorded answer cell. Change replaces the answer in
  /// place; remove leaves the screen on this question with the quizzer selected
  /// so the corrected ruling can be recorded immediately.
  Future<void> _editAnswerCell(Side side, int index, int n) async {
    final actions = round.answerActionsAtCell(side, index, n);
    if (actions.isEmpty) return;
    final action = actions.last;
    final event = action.event as AnswerEvent;
    final quizzer = round.teamOf(side).roster[index];
    final value = round.currentValue(n) ?? 0;
    final ruling = event.correct
        ? 'CORRECT  +$value'
        : 'INCORRECT  \u2212${value ~/ 2}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _editorDialog(
        dialogContext,
        title: 'Q$n \u00b7 ${sideName(round, side).toUpperCase()}',
        subtitle: quizzer.label,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (event.correct ? correctColor : incorrectColor).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ruling,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: event.correct ? correctColor : incorrectColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => _applyEdit(
                dialogContext,
                (allowDependentRemoval) => round.changeAnswer(
                  action.index,
                  correct: !event.correct,
                  allowDependentRemoval: allowDependentRemoval,
                ),
              ),
              child: Text(event.correct ? 'MARK INCORRECT' : 'MARK CORRECT'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _applyEdit(
                dialogContext,
                (allowDependentRemoval) => round.removeAnswer(
                  action.index,
                  allowDependentRemoval: allowDependentRemoval,
                ),
              ),
              child: const Text('REMOVE RULING'),
            ),
          ),
        ],
      ),
    );
  }

  /// Question-level editor: value changes (including after an answer),
  /// interruption removal, repeated voids, and void removal.
  Future<void> _showQuestionEditor(int n) async {
    final marks = round.view.questionMarks[n - 1];
    final value = round.currentValue(n);
    final editable = round.questionValueEditable(n);
    final isVoid = marks.voided;
    final interruptions = round.interruptionActions(n);
    final hasAnswers = round.questionHasAnswers(n);
    final isOvertime = n > round.ruleset.match.regulationQuestions;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _editorDialog(
        dialogContext,
        title: 'Question $n',
        subtitle: isOvertime ? 'Overtime value ${value ?? '\u2014'} pts' : null,
        children: [
          if (isVoid) ...[
            Text(
              value == null
                  ? 'This question is void.'
                  : 'This question is void; the substitute reads at $value pts. '
                        'Voiding again clears any answers on the substitute read.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (value != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                  onPressed: () =>
                      _applyEdit(dialogContext, (_) => round.voidQuestionAt(n)),
                  child: const Text('VOID QUESTION AGAIN'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _applyEdit(
                  dialogContext,
                  (allowDependentRemoval) => round.removeVoid(
                    n,
                    allowDependentRemoval: allowDependentRemoval,
                  ),
                ),
                child: const Text('REMOVE VOID'),
              ),
            ),
          ] else if (!isOvertime) ...[
            const Text(
              'Point value',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final v in round.valueOptions)
                  PointValueCard(
                    key: ValueKey('editor-value-$v'),
                    value: v,
                    selected: v == value,
                    onTap: () => _applyEdit(
                      dialogContext,
                      (allowDependentRemoval) => round.changeQuestionValue(
                        n,
                        v,
                        allowDependentRemoval: allowDependentRemoval,
                      ),
                    ),
                  ),
              ],
            ),
            if (!editable)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This question is already answered; changing the value '
                  'recalculates that answer.',
                ),
              ),
          ],
          if (!isVoid && hasAnswers) ...[
            const SizedBox(height: 12),
            const Text(
              'Voiding clears the answers; a substitute at the same point '
              'value is read.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
                onPressed: () =>
                    _applyEdit(dialogContext, (_) => round.voidQuestionAt(n)),
                child: const Text('VOID QUESTION'),
              ),
            ),
          ],
          if (interruptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _applyEdit(
                  dialogContext,
                  (allowDependentRemoval) => round.removeInterruption(
                    n,
                    allowDependentRemoval: allowDependentRemoval,
                  ),
                ),
                child: const Text('REMOVE INTERRUPTION'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Applies an edit; if later actions no longer replay, shows exactly which
  /// ones would be removed and retries only after confirmation.
  Future<void> _applyEdit(
    BuildContext dialogContext,
    EditOutcome Function(bool allowDependentRemoval) run,
  ) async {
    var outcome = run(false);
    if (!outcome.applied && outcome.conflicts.isNotEmpty) {
      if (!dialogContext.mounted) return;
      final confirmed = await _confirmDependents(
        dialogContext,
        outcome.conflicts,
      );
      if (confirmed != true) return;
      outcome = run(true);
    }
    if (outcome.applied && dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
  }

  Future<bool?> _confirmDependents(
    BuildContext context,
    List<JournalIssue> conflicts,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => _cappedDialog(
        context,
        AlertDialog(
          title: const Text('This also removes later actions'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'These recorded actions no longer apply after the edit:',
                  ),
                  const SizedBox(height: 8),
                  for (final issue in conflicts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('\u2022 ${round.describeEvent(issue.event)}'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('REMOVE THESE TOO'),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps an editor dialog within the live screens' text-scale cap. Dialogs
  /// are pushed above the screen's own MediaQuery, so without this they would
  /// scale past the no-scroll contract.
  Widget _cappedDialog(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
      child: child,
    );
  }

  /// Shared compact dialog shell for the direct editors.
  Widget _editorDialog(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return _cappedDialog(
      context,
      Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  onPressed: () {
                    hapticTick(context);
                    round.takeTimeOut(side);
                  },
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
