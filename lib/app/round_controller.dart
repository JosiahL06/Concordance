import 'package:flutter/foundation.dart';

import '../engine/events.dart';
import '../engine/notifications.dart';
import '../engine/ruleset.dart';
import '../engine/round_view.dart';

/// One journal entry the scoresheet can edit, with its stable journal index.
class RoundAction {
  const RoundAction({required this.index, required this.event});

  final int index;
  final RoundEvent event;
}

/// Result of an attempted action edit.
///
/// [conflicts] is non-empty when the edit was not applied because later
/// actions no longer replay. Callers may show those actions, then retry the
/// same operation with `allowDependentRemoval: true`.
class EditOutcome {
  const EditOutcome.applied()
    : applied = true,
      conflicts = const <JournalIssue>[];

  const EditOutcome.blocked(this.conflicts) : applied = false;

  final bool applied;
  final List<JournalIssue> conflicts;
}

/// An unanswered substitution opportunity: a seated quizzer has quizzed out and
/// their team still has at least one eligible bench quizzer.
class SubstitutionPrompt {
  const SubstitutionPrompt({
    required this.side,
    required this.outIndex,
    required this.outLabel,
    required this.outSeat,
    required this.bench,
  });

  final Side side;
  final int outIndex;
  final String outLabel;
  final int outSeat;

  /// Eligible bench quizzers only (not out for the match).
  final List<QuizzerView> bench;

  int get benchCount => bench.length;
  QuizzerView? get onlyBench => bench.length == 1 ? bench.single : null;
}

/// Production owner of a live round: the engine [RoundView] plus the view
/// state the engine deliberately doesn't track (D6: screen position,
/// selection, alert dismissal).
///
/// Methods mirror the interaction-spec console contract; every mutating
/// method ends with [notifyListeners] so both live views repaint
/// immediately. Scoring advances the screen position (correct/incorrect);
/// fouls stay put. Selection clears after every ruling.
class RoundController extends ChangeNotifier {
  RoundController({
    required this.ruleset,
    required this.redName,
    required this.greenName,
    required List<String> redSeats,
    required List<String> greenSeats,
    List<String> redBench = const <String>[],
    List<String> greenBench = const <String>[],
    List<int?>? questionValues,
  }) : view = RoundView(
         ruleset: ruleset,
         redLabels: redSeats,
         greenLabels: greenSeats,
         redBench: redBench,
         greenBench: greenBench,
         questionValues: questionValues,
       );

  final Ruleset ruleset;
  final String redName;
  final String greenName;
  final RoundView view;

  /// Database row id for the autosaved round; null until created.
  int? roundId;

  /// Save hook installed by the home screen: called with this controller
  /// after every journal change (apply/undo). Null in tests / presave.
  void Function(RoundController)? autosave;

  /// Rewrite hook for direct action edits. The journal no longer only grows or
  /// shrinks at the tail, so an edit needs an atomic whole-journal rewrite. When
  /// null (tests, presave) the regular [autosave] hook is used instead.
  void Function(RoundController)? rewriteAutosave;

  /// Snapshot of the journal before the most recent action edit. Kept only
  /// until the next normal scoring action, so the "UNDO EDIT" strip cannot
  /// rewind actions the keeper has since recorded.
  List<RoundEvent>? _lastEditJournal;
  int? _lastEditQuestionIndex;
  (Side, int)? _lastEditSelection;
  bool? _lastEditFinished;
  String? _lastEditLabel;

  bool get canUndoLastEdit => _lastEditJournal != null;
  String? get lastEditLabel => _lastEditLabel;

  /// Quiz-outs the keeper has explicitly dismissed the substitution prompt for.
  /// Keys are stable roster indices, so a new quiz-out (or an undo/re-out)
  /// re-arms the prompt.
  final Set<(Side, int)> _dismissedSubstitutionPrompts = <(Side, int)>{};

  /// 0-based screen position (D6: view state, never journaled).
  int questionIndex = 0;

  /// Selected quizzer as (side, index); null = none.
  (Side, int)? selected;

  /// Last banner text; null = dismissed/shown nothing.
  String? lastAlert;

  /// Set when the last autosave threw; null while saving is healthy.
  ///
  /// A save failure deliberately does **not** stop scoring — losing an
  /// in-progress match to a disk problem would be worse than losing the
  /// autosave — but it must not be silent either, or the keeper finishes a round
  /// believing it was written. The live chrome shows a persistent warning while
  /// this is non-null.
  String? saveError;

  int get questionNumber => questionIndex + 1;
  int get questionCount => view.questionValues.length;

  /// Current point value of question [n], or null while unset (D11). A voided
  /// slot reports its substitute value, because that is what the next answer
  /// actually scores.
  int? currentValue(int n) => view.effectiveValue(n);

  /// The per-question point values the ruleset allows (the value-picker
  /// options).
  List<int> get valueOptions => ruleset.match.answerValues;

  /// Whether question [n]'s value can be (re)set now (a regulation, unvoided,
  /// unanswered slot).
  bool questionValueEditable(int n) =>
      view.questionValueEditable(n) && !matchComplete;

  bool get canUndo => view.journal.isNotEmpty;

  /// Human label for the undo button, derived from the last journal event.
  String? get undoLabel =>
      view.journal.isEmpty ? null : _describe(view.journal.last);

  String get challengeLabel => ruleset.challengeKind == ChallengeKind.contest
      ? 'Contest'
      : "Coach's Appeal";

  // ── direct action editing ──

  /// The answer currently recorded in one quizzer × question cell, if any.
  ///
  /// The journal is historical: a void leaves the earlier `AnswerEvent` in the
  /// journal while retracting its effect from derived state. Walking forward and
  /// clearing at each void keeps a retracted answer from looking editable in an
  /// empty cell, while still finding the answer recorded on the substitute read.
  /// The answer guardrails permit at most one current answer per cell; the list
  /// shape is kept for the existing caller contract.
  List<RoundAction> answerActionsAtCell(Side side, int quizzerIndex, int n) {
    RoundAction? current;
    for (var i = 0; i < view.journal.length; i++) {
      final event = view.journal[i];
      if (event is VoidQuestionEvent && event.questionNumber == n) {
        current = null;
      } else if (event is AnswerEvent &&
          event.questionNumber == n &&
          event.side == side &&
          event.quizzerIndex == quizzerIndex) {
        current = RoundAction(index: i, event: event);
      }
    }
    return current == null ? const <RoundAction>[] : <RoundAction>[current];
  }

  /// The latest value assignment recorded for [n], if the keeper set one
  /// explicitly (as opposed to a seeded/test value).
  RoundAction? questionValueAction(int n) {
    for (var i = view.journal.length - 1; i >= 0; i--) {
      final event = view.journal[i];
      if (event is QuestionValueEvent && event.questionNumber == n) {
        return RoundAction(index: i, event: event);
      }
    }
    return null;
  }

  List<RoundAction> interruptionActions(int n) => [
    for (var i = 0; i < view.journal.length; i++)
      if (view.journal[i] case final InterruptionEvent e
          when e.questionNumber == n)
        RoundAction(index: i, event: e),
  ];

  List<RoundAction> voidActions(int n) => [
    for (var i = 0; i < view.journal.length; i++)
      if (view.journal[i] case final VoidQuestionEvent e
          when e.questionNumber == n)
        RoundAction(index: i, event: e),
  ];

  /// Legacy separate substitute events (older journals). The current UI folds
  /// the substitute value into the void event; this lookup is only needed when
  /// removing a void so those old events go with it.
  List<RoundAction> _substituteQuestionActions(int n) => [
    for (var i = 0; i < view.journal.length; i++)
      if (view.journal[i] case final SubstituteQuestionEvent e
          when e.questionNumber == n)
        RoundAction(index: i, event: e),
  ];

  /// Whether a question header should open the question editor instead of the
  /// quick value picker: something other than a simple, still-editable value is
  /// recorded (interruption, void, or an already-answered value).
  bool questionNeedsEditor(int n) {
    if (n < 1 || n > questionCount) return false;
    if (n > ruleset.match.regulationQuestions) return false;
    final marks = view.questionMarks[n - 1];
    if (marks.interrupted || marks.voided) return true;
    return !view.questionValueEditable(n);
  }

  /// Whether [n] already has a recorded answer. Used to expose the void action
  /// in the question editor only where clearing a question is meaningful.
  bool questionHasAnswers(int n) => view.journal.any(
    (event) => event is AnswerEvent && event.questionNumber == n,
  );

  /// Whether the footer's single VOID QUESTION button can act on the current
  /// slot: it must have a value (the substitute reads at that value), and the
  /// match must still be in progress.
  bool get canVoidCurrentQuestion =>
      !matchComplete &&
      questionNumber >= 1 &&
      questionNumber <= questionCount &&
      currentValue(questionNumber) != null;

  /// Whether any team currently has both a seated quizzer and an eligible bench
  /// quizzer, so the substitution board has something to do.
  bool get hasSubstitutionOptions => Side.values.any((side) {
    final team = view.teamOf(side);
    return team.seated.isNotEmpty &&
        team.bench.any((quizzer) => quizzer.status.isEmpty);
  });

  /// The most recent quiz-out that still has an eligible bench replacement,
  /// or null when there is nothing to prompt about. Deriving this from state
  /// makes it disappear on substitution/undo and survive transient alerts.
  SubstitutionPrompt? get substitutionPrompt {
    if (matchComplete) return null;
    SubstitutionPrompt? best;
    var bestRecency = -1;
    for (final side in Side.values) {
      final team = view.teamOf(side);
      final bench = [
        for (final quizzer in team.bench)
          if (quizzer.status.isEmpty) quizzer,
      ];
      if (bench.isEmpty) continue;
      for (final quizzer in team.seated) {
        if (quizzer.status != 'QUIZ-OUT') continue;
        if (_dismissedSubstitutionPrompts.contains((side, quizzer.index))) {
          continue;
        }
        final recency = _lastCorrectAnswerIndex(side, quizzer.index);
        if (recency > bestRecency) {
          bestRecency = recency;
          best = SubstitutionPrompt(
            side: side,
            outIndex: quizzer.index,
            outLabel: quizzer.label,
            outSeat: quizzer.seat,
            bench: List<QuizzerView>.unmodifiable(bench),
          );
        }
      }
    }
    return best;
  }

  /// Dismisses the current prompt until that quizzer's state changes (undo or
  /// re-quiz-out), or a different quiz-out becomes the newest prompt.
  void dismissSubstitutionPrompt() {
    final prompt = substitutionPrompt;
    if (prompt == null) return;
    _dismissedSubstitutionPrompts.add((prompt.side, prompt.outIndex));
    // The prompt is the quiz-out notification when a bench replacement exists;
    // dismiss its matching transient alert too instead of letting it pop in
    // afterwards.
    final quizOutAlert =
        '${prompt.side.name.toUpperCase()} ${prompt.outLabel} quizzed out';
    if (lastAlert == quizOutAlert) lastAlert = null;
    notifyListeners();
  }

  /// Replaces one answer in place, preserving its journal position so later
  /// actions (a re-read, substitution, void) replay exactly as they did.
  EditOutcome changeAnswer(
    int journalIndex, {
    required bool correct,
    bool allowDependentRemoval = false,
  }) {
    if (journalIndex < 0 || journalIndex >= view.journal.length) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final event = view.journal[journalIndex];
    if (event is! AnswerEvent) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final candidate = List<RoundEvent>.of(view.journal);
    candidate[journalIndex] = AnswerEvent(
      questionNumber: event.questionNumber,
      side: event.side,
      quizzerIndex: event.quizzerIndex,
      correct: correct,
    );
    return _commitEdit(
      candidate,
      label:
          'Q${event.questionNumber} ${_quizzerName(event.side, event.quizzerIndex)} '
          '${correct ? 'marked correct' : 'marked incorrect'}',
      jumpTo: event.questionNumber,
      selectSide: event.side,
      selectIndex: event.quizzerIndex,
      allowDependentRemoval: allowDependentRemoval,
    );
  }

  /// Removes one answer. The screen moves to the question and selects the
  /// quizzer so the corrected ruling can be recorded immediately.
  EditOutcome removeAnswer(
    int journalIndex, {
    bool allowDependentRemoval = false,
  }) {
    if (journalIndex < 0 || journalIndex >= view.journal.length) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final event = view.journal[journalIndex];
    if (event is! AnswerEvent) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final candidate = List<RoundEvent>.of(view.journal)..removeAt(journalIndex);
    return _commitEdit(
      candidate,
      label:
          'Q${event.questionNumber} ${_quizzerName(event.side, event.quizzerIndex)} '
          'ruling removed',
      jumpTo: event.questionNumber,
      selectSide: event.side,
      selectIndex: event.quizzerIndex,
      allowDependentRemoval: allowDependentRemoval,
    );
  }

  /// Removes every interruption mark on [n] (the bottom-bar button only adds).
  EditOutcome removeInterruption(int n, {bool allowDependentRemoval = false}) {
    final actions = interruptionActions(n);
    if (actions.isEmpty) return const EditOutcome.blocked(<JournalIssue>[]);
    final indexes = {for (final a in actions) a.index};
    final candidate = <RoundEvent>[
      for (var i = 0; i < view.journal.length; i++)
        if (!indexes.contains(i)) view.journal[i],
    ];
    return _commitEdit(
      candidate,
      label: 'Q$n interruption removed',
      allowDependentRemoval: allowDependentRemoval,
    );
  }

  /// Removes the void and any substitute question on [n], restoring the
  /// original question. Later substitute answers are surfaced as dependencies.
  EditOutcome removeVoid(int n, {bool allowDependentRemoval = false}) {
    final indexes = {
      for (final a in [...voidActions(n), ..._substituteQuestionActions(n)])
        a.index,
    };
    if (indexes.isEmpty) return const EditOutcome.blocked(<JournalIssue>[]);
    final candidate = <RoundEvent>[
      for (var i = 0; i < view.journal.length; i++)
        if (!indexes.contains(i)) view.journal[i],
    ];
    return _commitEdit(
      candidate,
      label: 'Q$n void removed',
      allowDependentRemoval: allowDependentRemoval,
    );
  }

  /// Changes a regulation question's value, including after it was answered.
  /// The assignment event is replaced in place (or inserted before the first
  /// answer when the value came from a seeded base list), so later answers
  /// re-fold at the new value.
  EditOutcome changeQuestionValue(
    int n,
    int value, {
    bool allowDependentRemoval = false,
  }) {
    if (n < 1 || n > questionCount) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    if (n > ruleset.match.regulationQuestions) {
      lastAlert = 'Overtime questions have a fixed point value.';
      notifyListeners();
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    if (!ruleset.match.answerValues.contains(value)) {
      lastAlert = 'That point value is not allowed by this ruleset.';
      notifyListeners();
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    if (view.questionMarks[n - 1].voided) {
      lastAlert =
          'This question is void — read a substitute question to set '
          'its value.';
      notifyListeners();
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final event = questionValueAction(n);
    final candidate = List<RoundEvent>.of(view.journal);
    if (event != null) {
      candidate[event.index] = QuestionValueEvent(
        questionNumber: n,
        value: value,
      );
    } else {
      // The value came from a seeded base list. Insert before the first answer
      // on this slot so the answer still folds against it; otherwise append.
      var insertAt = candidate.length;
      for (var i = 0; i < candidate.length; i++) {
        final e = candidate[i];
        if (e is AnswerEvent && e.questionNumber == n) {
          insertAt = i;
          break;
        }
      }
      candidate.insert(
        insertAt,
        QuestionValueEvent(questionNumber: n, value: value),
      );
    }
    return _commitEdit(
      candidate,
      label: 'Q$n value set to $value',
      allowDependentRemoval: allowDependentRemoval,
    );
  }

  /// Applies a candidate journal, optionally dropping the later events it
  /// invalidates. On the first attempt callers receive the conflicts and can
  /// show them before retrying with [allowDependentRemoval].
  EditOutcome _commitEdit(
    List<RoundEvent> candidate, {
    required String label,
    bool allowDependentRemoval = false,
    int? jumpTo,
    Side? selectSide,
    int? selectIndex,
  }) {
    final replay = view.replayCandidate(candidate);
    if (replay.issues.isNotEmpty && !allowDependentRemoval) {
      return EditOutcome.blocked(replay.issues);
    }
    // replayCandidate's state is the fold with the invalid events skipped, so
    // filtering them out yields a journal that replays identically.
    final dropped = {for (final issue in replay.issues) issue.index};
    final cleaned = <RoundEvent>[
      for (var i = 0; i < candidate.length; i++)
        if (!dropped.contains(i)) candidate[i],
    ];
    final cleanReplay = view.replayCandidate(cleaned);
    if (!cleanReplay.ok) {
      return EditOutcome.blocked(cleanReplay.issues);
    }

    _rememberEditForUndo();
    view.replaceJournal(cleaned);
    _afterEdit(
      label: label,
      jumpTo: jumpTo,
      selectSide: selectSide,
      selectIndex: selectIndex,
    );
    return const EditOutcome.applied();
  }

  void _rememberEditForUndo() {
    _lastEditJournal = List<RoundEvent>.of(view.journal);
    _lastEditQuestionIndex = questionIndex;
    _lastEditSelection = selected;
    _lastEditFinished = _finished;
  }

  void _afterEdit({
    required String label,
    int? jumpTo,
    Side? selectSide,
    int? selectIndex,
  }) {
    _lastEditLabel = label;
    _finished = false;
    if (jumpTo != null) questionIndex = jumpTo - 1;
    if (questionIndex > questionCount - 1) questionIndex = questionCount - 1;
    if (selectSide != null && selectIndex != null) {
      final quizzer = view.teamOf(selectSide).roster[selectIndex];
      selected = quizzer.active ? (selectSide, selectIndex) : null;
    } else if (selected != null) {
      final quizzer = view.teamOf(selected!.$1).roster[selected!.$2];
      if (!quizzer.active) selected = null;
    }
    final notices = _notices();
    final completion = _syncCompletionAfterEdit();
    lastAlert = _joinNotices(notices, completion);
    _saved(rewrite: true);
  }

  /// Re-derives match completion after a journal edit. A tied, fully answered
  /// round opens the next overtime question exactly as it would live.
  String? _syncCompletionAfterEdit() {
    if (questionCount == 0) return null;
    for (var n = 1; n <= questionCount; n++) {
      if (!questionAnswered(n)) return null;
    }
    final red = scoreOf(Side.red);
    final green = scoreOf(Side.green);
    if (red != green) {
      _finished = true;
      return null;
    }
    return _openOvertime(red, green);
  }

  /// Restores the journal from immediately before the last action edit.
  bool undoLastEdit() {
    final snapshot = _lastEditJournal;
    if (snapshot == null) return false;
    final replay = view.replaceJournal(snapshot);
    if (!replay.ok) return false;
    questionIndex = _lastEditQuestionIndex ?? questionIndex;
    if (questionIndex > questionCount - 1) questionIndex = questionCount - 1;
    selected = _lastEditSelection;
    _finished = _lastEditFinished ?? false;
    _clearLastEdit();
    lastAlert = 'Edit undone.';
    _reconcileAnnounced();
    _saved(rewrite: true);
    return true;
  }

  void clearLastEdit() {
    _clearLastEdit();
    notifyListeners();
  }

  void _clearLastEdit() {
    _lastEditJournal = null;
    _lastEditQuestionIndex = null;
    _lastEditSelection = null;
    _lastEditFinished = null;
    _lastEditLabel = null;
  }

  /// Plain-language description of a journal event, used in dependency
  /// confirmations and edit labels.
  String describeEvent(RoundEvent event) => switch (event) {
    AnswerEvent(
      :final questionNumber,
      :final side,
      :final quizzerIndex,
      :final correct,
    ) =>
      'Q$questionNumber ${_quizzerName(side, quizzerIndex)} '
          '${correct ? 'correct' : 'incorrect'}',
    FoulEvent(:final questionNumber, :final side, :final quizzerIndex) =>
      'Q${questionNumber ?? '—'} '
          '${quizzerIndex == null ? '${_sideName(side)} team foul' : '${_quizzerName(side, quizzerIndex)} foul'}',
    TimeOutEvent(:final side) => '${_sideName(side)} time-out',
    InterruptionEvent(:final questionNumber) => 'Q$questionNumber interruption',
    ChallengeEvent(:final questionNumber, :final side, :final successful) =>
      'Q$questionNumber ${_sideName(side)} ${successful ? 'successful' : 'unsuccessful'} contest',
    VoidQuestionEvent(:final questionNumber) => 'Q$questionNumber void',
    QuestionValueEvent(:final questionNumber, :final value) =>
      'Q$questionNumber value $value',
    SubstituteQuestionEvent(:final questionNumber, :final value) =>
      'Q$questionNumber substitute ($value pts)',
    SubstituteQuizzerEvent(:final side) => '${_sideName(side)} substitution',
    OvertimeQuestionEvent(:final value) => 'overtime question ($value pts)',
  };

  TeamView teamOf(Side side) => view.teamOf(side);
  int scoreOf(Side side) => view.scoreOf(side);
  String? cellOutcome(Side side, int index, int n) =>
      view.cellOutcome(side, index, n);
  bool cellHasFoul(Side side, int index, int n) =>
      view.cellHasFoul(side, index, n);
  int teamDelta(Side side, int n) => view.teamDelta(side, n);

  /// Reason the selected quizzer cannot score on question [n] under the
  /// answer guardrails (D10), or null when scoring is allowed. The scoring
  /// console disables CORRECT/INCORRECT on a non-null reason and shows it.
  String? scoreBlockedReason(Side side, int index, int n) =>
      view.answerBlockedReason(side, index, n);

  List<QuizzerRef> get redRoster => _roster(Side.red);
  List<QuizzerRef> get greenRoster => _roster(Side.green);

  List<QuizzerRef> _roster(Side side) {
    final team = view.teamOf(side);
    // Only seated quizzers can be selected to answer.
    return [
      for (final q in team.seated)
        QuizzerRef(side: side, index: q.index, view: q),
    ];
  }

  void select(Side side, int index) {
    final q = view.teamOf(side).roster[index];
    if (!q.active) return;
    final ref = (side, index);
    selected = selected == ref ? null : ref;
    notifyListeners();
  }

  /// Selects [side]/[index] without toggling an existing selection off.
  ///
  /// Classic cell navigation uses this: moving from one question to another
  /// while keeping the same quizzer armed must not deselect them. Tapping the
  /// quizzer's label or Modern card still uses [select] and therefore still
  /// toggles.
  void selectIfNeeded(Side side, int index) {
    final q = view.teamOf(side).roster[index];
    if (!q.active) return;
    final ref = (side, index);
    if (selected == ref) return;
    selected = ref;
    notifyListeners();
  }

  void jumpToQuestion(int n) {
    if (n < 1 || n > questionCount) return;
    questionIndex = n - 1;
    notifyListeners();
  }

  void clearAlert() {
    lastAlert = null;
    notifyListeners();
  }

  /// Raises a one-off banner (e.g. a keeper action that could not proceed).
  void showAlert(String message) {
    lastAlert = message;
    notifyListeners();
  }

  bool markCorrect() => _answer(correct: true);
  bool markIncorrect() => _answer(correct: false);

  bool _answer({required bool correct}) {
    final sel = selected;
    if (matchComplete || sel == null) return false;
    final violation = view.apply(
      AnswerEvent(
        questionNumber: questionNumber,
        side: sel.$1,
        quizzerIndex: sel.$2,
        correct: correct,
      ),
    );
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    selected = null;
    // An incorrect answer on an *interrupted* question is re-read to the
    // other team, so the keeper stays on it instead of advancing (no banner —
    // the position not moving is the signal).
    final interrupted = view.questionMarks[questionNumber - 1].interrupted;
    lastAlert = (!correct && interrupted)
        ? _notices()
        : _joinNotices(_notices(), _advance());
    _saved();
    return true;
  }

  /// Records a quizzer foul for the selected quizzer (stays on question).
  bool addQuizzerFoul() {
    final sel = selected;
    if (matchComplete || sel == null) return false;
    final violation = view.apply(
      FoulEvent(
        questionNumber: questionNumber,
        side: sel.$1,
        quizzerIndex: sel.$2,
      ),
    );
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    selected = null;
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Records a team foul for [side] (no quizzer; hits the team total only).
  bool addTeamFoul(Side side) {
    if (matchComplete) return false;
    final violation = view.apply(FoulEvent(side: side));
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Takes a time-out for [side]. Time-outs are capped at the ruleset
  /// allotment: a request beyond the cap is denied, never journaled, and the
  /// keeper is reminded to record the resulting team foul themselves (the app
  /// never auto-assesses it). Returns true when a time-out was granted.
  bool takeTimeOut(Side side) {
    if (matchComplete) {
      lastAlert = 'The match is complete — no more time-outs.';
      notifyListeners();
      return false;
    }
    final violation = view.apply(TimeOutEvent(side: side));
    if (violation != null) {
      // Over-cap request: denied. The rules (both books) make the failed
      // request a team foul, but the keeper assigns it via the foul path —
      // the engine deliberately does not.
      final name = side == Side.red ? redName : greenName;
      lastAlert = inOvertime && !ruleset.limits.overtimeTimeOutsCarry
          ? '$name has no time-outs available in overtime — that request is '
                'denied. Assign a team foul; no time-out is granted.'
          : '$name has used all $timeOutCap time-outs — that request is '
                'denied. Assign a team foul; no time-out is granted.';
      notifyListeners();
      return false;
    }
    // The engine's `collectNotices` is the single source of the time-out limit
    // notice, so it flows through the same once-per-message gate as every
    // other notice and never repeats.
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Toggles the interruption ring on the current question.
  void toggleInterruption() {
    view.apply(InterruptionEvent(questionNumber: questionNumber));
    _saved();
  }

  /// Records a contest/appeal; returns false when rejected (limit reached).
  bool recordChallenge(Side side, {required bool successful}) {
    if (matchComplete) return false;
    final violation = view.apply(
      ChallengeEvent(
        questionNumber: questionNumber,
        side: side,
        successful: successful,
      ),
    );
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Pops the last journal event and restores the screen position.
  bool undo() {
    if (view.journal.isEmpty) return false;
    view.undo();
    // An auto-added overtime question is a *consequence* of the answer that
    // forced the tie, not a separate keeper action - one undo must revert the
    // whole ruling, otherwise the tie would immediately re-open overtime and
    // undo would appear to do nothing.
    while (view.journal.isNotEmpty && _tiedAndComplete()) {
      view.undo();
    }
    _finished = false;
    lastAlert = null;
    // Re-arm any notice the undone ruling had fired (e.g. a quiz-out): its
    // condition no longer holds, so if the quizzer quizzes out again later the
    // keeper must be told again.
    _reconcileAnnounced();
    if (questionIndex > questionCount - 1) {
      questionIndex = questionCount - 1;
    }
    _saved();
    return true;
  }

  /// Next overtime value per the ruleset: TBQ sudden-death 10s; JBQ
  /// 10/20/30 then 20s.
  int nextOvertimeValue() {
    final otCount =
        view.questionValues.length - ruleset.match.regulationQuestions;
    return switch (ruleset.overtime.mode) {
      OvertimeMode.suddenDeath10 => 10,
      OvertimeMode.threePlusSuddenDeath20 =>
        otCount < 3 ? [10, 20, 30][otCount] : 20,
    };
  }

  /// Clears question [n]: its answer points are retracted and it re-opens as a
  /// substitute question at the same point value (D3/D4). One journal entry
  /// carries both effects, so one Undo restores the original ruling.
  EditOutcome voidQuestionAt(int n) {
    if (n < 1 || n > questionCount) {
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final value = currentValue(n);
    if (value == null) {
      lastAlert = 'Set the point value for Q$n before voiding it.';
      notifyListeners();
      return const EditOutcome.blocked(<JournalIssue>[]);
    }
    final candidate = <RoundEvent>[
      ...view.journal,
      VoidQuestionEvent(questionNumber: n, substituteValue: value),
    ];
    return _commitEdit(
      candidate,
      label: 'Q$n voided \u2014 substitute reads at $value',
      jumpTo: n,
    );
  }

  /// Clears the current question (footer button).
  EditOutcome voidQuestion() => voidQuestionAt(questionNumber);

  /// Assigns the keeper-entered point [value] to question [n] (schema decision
  /// D11). Returns false (with a reason in [lastAlert]) when the engine rejects
  /// — an overtime slot (fixed by rule), a voided slot, a slot already
  /// answered, or a value the ruleset does not allow.
  bool setQuestionValue(int n, int value) {
    if (matchComplete) return false;
    final violation = view.apply(
      QuestionValueEvent(questionNumber: n, value: value),
    );
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Substitutes the bench quizzer at [benchIndex] in for the out quizzer at
  /// ([side], [outIndex]). Points already scored under the slot are preserved
  /// (schema decision D7). Returns false when the engine rejects it.
  bool substituteQuizzer({
    required Side side,
    required int outIndex,
    required int benchIndex,
  }) {
    final violation = view.apply(
      SubstituteQuizzerEvent(
        side: side,
        outIndex: outIndex,
        benchIndex: benchIndex,
      ),
    );
    if (violation != null) {
      lastAlert = violation.message;
      notifyListeners();
      return false;
    }
    if (selected?.$1 == side && selected?.$2 == outIndex) {
      selected = null;
    }
    lastAlert = _notices();
    _saved();
    return true;
  }

  /// Re-derives completion after journal replay (resume path). A voided
  /// question with no substitute counts as unanswered, so such rounds stay
  /// open for the keeper to resolve.
  /// Re-derives completion after journal replay (resume path). A tied,
  /// fully-answered round opens overtime here too, so a resumed match lands
  /// in the same state a live one would.
  void recomputeCompletion() {
    _finished = false;
    questionIndex = firstOpenQuestion() - 1;
    if (questionIndex > questionCount - 1) {
      questionIndex = questionCount - 1;
    }
    lastAlert = _joinNotices(_notices(), _evaluateEnd());
  }

  /// First question with no recorded answer, or [questionCount] when all
  /// are answered (resume landing position).
  int firstOpenQuestion() {
    for (var n = 1; n <= questionCount; n++) {
      if (!questionAnswered(n)) return n;
    }
    return questionCount;
  }

  /// Notifies listeners and persists the journal through the installed
  /// [autosave] hook (no-op when no store is attached, e.g. tests). A history
  /// edit passes [rewrite] so the store replaces the journal atomically instead
  /// of using the tail delta path.
  ///
  /// A save failure must never skip [notifyListeners]. The engine has already
  /// accepted the event by the time this runs, so an exception escaping here
  /// would leave the derived state changed but the screen unpainted: the keeper
  /// would see nothing happen, tap again, and score twice. Failures are caught,
  /// recorded in [saveError], and notified like any other change.
  void _saved({bool rewrite = false}) {
    // A normal scoring action invalidates the one-level "undo edit" snapshot:
    // restoring it later would silently discard that new action too.
    if (!rewrite) _clearLastEdit();
    _reconcileSubstitutionPrompts();
    try {
      final hook = rewrite ? rewriteAutosave ?? autosave : autosave;
      hook?.call(this);
      saveError = null;
    } catch (e) {
      saveError = '$e';
    }
    notifyListeners();
  }

  /// Journal index of the last correct answer by one quizzer, used only to put
  /// the newest quiz-out prompt first when a team has more than one.
  int _lastCorrectAnswerIndex(Side side, int quizzerIndex) {
    for (var i = view.journal.length - 1; i >= 0; i--) {
      final event = view.journal[i];
      if (event is AnswerEvent &&
          event.side == side &&
          event.quizzerIndex == quizzerIndex &&
          event.correct) {
        return i;
      }
    }
    return -1;
  }

  /// Re-arms a dismissed prompt when its quizzer is no longer seated/out or the
  /// bench no longer has an eligible replacement.
  void _reconcileSubstitutionPrompts() {
    _dismissedSubstitutionPrompts.removeWhere((key) {
      final (side, index) = key;
      final team = view.teamOf(side);
      if (index < 0 || index >= team.roster.length) return true;
      final quizzer = team.roster[index];
      if (quizzer.status != 'QUIZ-OUT' || quizzer.seat == 0) return true;
      return team.bench.every((bench) => bench.status.isNotEmpty);
    });
  }

  bool questionAnswered(int n) {
    for (final side in Side.values) {
      final team = view.teamOf(side);
      for (final q in team.roster) {
        final mark = view.cellOutcome(side, q.index, n);
        if (mark == 'correct' || mark == 'incorrect') return true;
      }
    }
    return false;
  }

  /// Notices already surfaced to the keeper, so a one-time event (a quizzer's
  /// quiz-out / strike-out / foul-out, or a limit warning) is announced once
  /// and not repeated on every later ruling. `collectNotices` derives the
  /// *currently active* notices from state, which stays true for the rest of
  /// the round — so the controller must remember what it has already shown.
  final Set<String> _announced = <String>{};

  /// Newly active notices for the current ruling, keyed by code + message.
  /// Already-announced notices are suppressed; the rest are recorded so they
  /// fire once. Dismissing the banner does not re-arm them.
  String? _notices() {
    // Forget notices whose condition no longer holds (e.g. a quiz-out undone
    // or a quizzer substituted out), so that if it happens *again* later it is
    // treated as new and announced again. Without this the suppression would
    // be permanent and a re-quiz-out after an undo would go unreported.
    _reconcileAnnounced();
    final notices = collectNotices(ruleset, view.state);
    final fresh = <String>[];
    for (final n in notices) {
      if (_announced.add('${n.code}|${n.message}')) fresh.add(n.message);
    }
    return fresh.isEmpty ? null : fresh.last;
  }

  /// Drops remembered notices that are no longer active under current state,
  /// re-arming them. Keys carry the quizzer label, so a *different* quizzer's
  /// later quiz-out is always a distinct, fresh notice.
  void _reconcileAnnounced() {
    final active = {
      for (final n in collectNotices(ruleset, view.state))
        '${n.code}|${n.message}',
    };
    _announced.removeWhere((key) => !active.contains(key));
  }

  /// Marks every currently-active notice as already announced *without*
  /// showing it. The resume path replays a journal that may already contain
  /// outs and limit warnings; seeding them here keeps a resumed round from
  /// re-announcing settled history on the first new ruling.
  void markCurrentNoticesSeen() {
    for (final n in collectNotices(ruleset, view.state)) {
      _announced.add('${n.code}|${n.message}');
    }
  }

  /// Combines a rulebook notice with the end-of-round announcement so neither
  /// can swallow the other: a quiz-out firing on the overtime ruling must not
  /// hide the fact that overtime started.
  String? _joinNotices(String? first, String? second) {
    if (first == null || first.isEmpty) return second;
    if (second == null || second.isEmpty) return first;
    return '$first  \u00b7  $second';
  }

  /// Advances the screen position after a ruling. On the final question it
  /// evaluates the match end instead - overtime is deterministic, so it opens
  /// automatically rather than waiting for a keeper to press a button.
  String? _advance() {
    if (questionIndex + 1 < questionCount) {
      questionIndex += 1;
      return null;
    }
    return _evaluateEnd();
  }

  bool _finished = false;

  /// Whether the round is over: a lead exists and every question is answered.
  bool get matchComplete => _finished;

  /// Whether the keeper has passed the regulation question count.
  bool get inOvertime => questionCount > ruleset.match.regulationQuestions;

  /// Team time-outs allowed under the current phase: [timeOutsPerTeam] in
  /// regulation; in overtime it follows the ruleset's carry-over rules
  /// (TBQ: none may be used; JBQ: remaining carry plus one extra).
  int get timeOutCap => ruleset.limits.timeOutCap(inOvertime: inOvertime);

  /// Time-out denominator for display: the phase cap, but never below what
  /// [side] has already taken. TBQ overtime voids any remaining time-outs, so
  /// a team that used two reads "2/2" — not the confusing "2/0".
  int timeOutDisplayCap(Side side) {
    final cap = timeOutCap;
    final taken = view.teamOf(side).timeOuts;
    return taken > cap ? taken : cap;
  }

  /// Evaluates the end of the round once the final question is answered. A
  /// tie deterministically opens the next overtime question; a lead ends the
  /// match. Returns the notice to show, or null while the round continues.
  String? _evaluateEnd() {
    if (questionIndex + 1 < questionCount) return null;
    if (!questionAnswered(questionCount)) return null;
    final red = scoreOf(Side.red);
    final green = scoreOf(Side.green);
    if (red != green) {
      _finished = true;
      return '${red > green ? redName : greenName} wins $red-$green - '
          'match complete.';
    }
    return _openOvertime(red, green);
  }

  /// Appends the next overtime question from the ruleset sequence (TBQ
  /// sudden-death 10s; JBQ 10/20/30 then 20s), jumps to it, and returns the
  /// notice shown to the keeper.
  String? _openOvertime(int red, int green) {
    final value = nextOvertimeValue();
    final violation = view.apply(OvertimeQuestionEvent(value: value));
    if (violation != null) {
      return 'Tied $red-$green - overtime needed (${violation.message}).';
    }
    questionIndex = questionCount - 1;
    return 'Tied $red-$green - overtime question $questionCount '
        '($value pts) added automatically.$_overtimeTimeOutNote';
  }

  /// Time-out rule in overtime, appended to the overtime announcement so the
  /// keeper knows what the teams may take before they ask for it.
  String get _overtimeTimeOutNote {
    final limits = ruleset.limits;
    if (!limits.overtimeTimeOutsCarry) {
      return ' No team time-outs may be used in overtime.';
    }
    if (limits.overtimeExtraTimeOuts > 0) {
      return ' Teams may use remaining time-outs plus '
          '${limits.overtimeExtraTimeOuts} overtime time-out.';
    }
    return ' Teams may use any remaining time-outs.';
  }

  /// True while every question carries an answer and the scores are level: the
  /// state in which an auto-added overtime question would re-trigger forever.
  bool _tiedAndComplete() {
    for (var n = 1; n <= questionCount; n++) {
      if (!questionAnswered(n)) return false;
    }
    return scoreOf(Side.red) == scoreOf(Side.green);
  }

  String _sideName(Side side) => side == Side.red ? redName : greenName;

  String _quizzerName(Side side, int index) {
    final roster = view.teamOf(side).roster;
    if (index < 0 || index >= roster.length) return 'quizzer $index';
    return roster[index].label;
  }

  String _describe(RoundEvent event) => switch (event) {
    AnswerEvent(:final correct) =>
      correct ? 'correct answer' : 'incorrect answer',
    FoulEvent(:final quizzerIndex) =>
      quizzerIndex == null ? 'team foul' : 'quizzer foul',
    TimeOutEvent() => 'time-out',
    InterruptionEvent() => 'interruption mark',
    ChallengeEvent() => challengeLabel.toLowerCase(),
    VoidQuestionEvent() => 'void',
    QuestionValueEvent() => 'question value',
    SubstituteQuestionEvent() => 'substitute question',
    SubstituteQuizzerEvent() => 'quizzer substitution',
    OvertimeQuestionEvent() => 'overtime question',
  };
}

/// A quizzer row the views can select: identity + read snapshot.
class QuizzerRef {
  const QuizzerRef({
    required this.side,
    required this.index,
    required this.view,
  });

  final Side side;
  final int index;
  final QuizzerView view;
}
