import 'package:flutter/foundation.dart';

import '../engine/events.dart';
import '../engine/notifications.dart';
import '../engine/ruleset.dart';
import '../engine/round_view.dart';

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
  }) : view = RoundView(
         ruleset: ruleset,
         redLabels: redSeats,
         greenLabels: greenSeats,
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

  /// 0-based screen position (D6: view state, never journaled).
  int questionIndex = 0;

  /// Selected quizzer as (side, index); null = none.
  (Side, int)? selected;

  /// Last banner text; null = dismissed/shown nothing.
  String? lastAlert;

  int get questionNumber => questionIndex + 1;
  int get questionCount => view.questionValues.length;
  int currentValue(int n) => view.questionValues[n - 1];

  bool get canUndo => view.journal.isNotEmpty;

  /// Human label for the undo button, derived from the last journal event.
  String? get undoLabel =>
      view.journal.isEmpty ? null : _describe(view.journal.last);

  String get challengeLabel =>
      ruleset.challengeKind == ChallengeKind.contest
          ? 'Contest'
          : "Coach's Appeal";

  TeamView teamOf(Side side) => view.teamOf(side);
  int scoreOf(Side side) => view.scoreOf(side);
  String? cellOutcome(Side side, int index, int n) =>
      view.cellOutcome(side, index, n);
  int teamDelta(Side side, int n) => view.teamDelta(side, n);

  List<QuizzerRef> get redRoster => _roster(Side.red);
  List<QuizzerRef> get greenRoster => _roster(Side.green);

  List<QuizzerRef> _roster(Side side) {
    final team = view.teamOf(side);
    return [
      for (var i = 0; i < team.quizzers.length; i++)
        QuizzerRef(side: side, index: i, view: team.quizzers[i]),
    ];
  }

  void select(Side side, int index) {
    final q = view.teamOf(side).quizzers[index];
    if (!q.active) return;
    final ref = (side, index);
    selected = selected == ref ? null : ref;
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

  bool markCorrect() =>
      _answer(correct: true);
  bool markIncorrect() =>
      _answer(correct: false);

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
    final endNotice = _advance();
    lastAlert = _joinNotices(_notices(), endNotice);
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

  /// Takes a time-out for [side]; always accepted, 4th request alerts.
  void takeTimeOut(Side side) {
    if (matchComplete) {
      lastAlert = 'The match is complete — no more time-outs.';
      notifyListeners();
      return;
    }
    view.apply(TimeOutEvent(side: side));
    final count = view.teamOf(side).timeOuts;
    lastAlert = count >= ruleset.limits.notifyTimeOutRequest
        ? '${_sideName(side)} requested a ${count}th time-out — '
            'notify the quizmaster.'
        : _notices();
    _saved();
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

  /// Voids the current question: answer points are retracted, fouls stand
  /// (schema decision D3).
  void voidQuestion() {
    if (matchComplete) return;
    view.apply(VoidQuestionEvent(questionNumber: questionNumber));
    lastAlert = _notices();
    _saved();
  }

  /// Reads a substitute question of [value] for the voided current question
  /// (same slot, schema decision D4). Returns false when the engine rejects.
  bool substituteQuestion(int value) {
    final violation = view.apply(
      SubstituteQuestionEvent(questionNumber: questionNumber, value: value),
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

  /// Substitutes the quizzer at ([side], [outIndex]) with [label]. Points
  /// already scored under the slot are preserved (schema decision D7).
  /// Returns false when the engine rejects the substitution.
  bool substituteQuizzer({
    required Side side,
    required int outIndex,
    required String label,
  }) {
    if (label.trim().isEmpty) return false;
    final violation = view.apply(
      SubstituteQuizzerEvent(
        side: side,
        outIndex: outIndex,
        label: label.trim(),
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
  /// [autosave] hook (no-op when no store is attached, e.g. tests).
  void _saved() {
    autosave?.call(this);
    notifyListeners();
  }

  bool questionAnswered(int n) {
    for (final side in Side.values) {
      final team = view.teamOf(side);
      for (var i = 0; i < team.quizzers.length; i++) {
        final mark = view.cellOutcome(side, i, n);
        if (mark == 'correct' || mark == 'incorrect') return true;
      }
    }
    return false;
  }

  String _sideName(Side side) =>
      side == Side.red ? redName : greenName;

  String? _notices() {
    final notices = collectNotices(ruleset, view.state);
    return notices.isEmpty ? null : notices.last.message;
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
        '($value pts) added automatically.';
  }

  /// True while every question carries an answer and the scores are level: the
  /// state in which an auto-added overtime question would re-trigger forever.
  bool _tiedAndComplete() {
    for (var n = 1; n <= questionCount; n++) {
      if (!questionAnswered(n)) return false;
    }
    return scoreOf(Side.red) == scoreOf(Side.green);
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

