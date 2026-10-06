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

  String get challengeLabel => ruleset.challengeKind == ChallengeKind.contest
      ? 'Contest'
      : "Coach's Appeal";

  TeamView teamOf(Side side) => view.teamOf(side);
  int scoreOf(Side side) => view.scoreOf(side);
  String? cellOutcome(Side side, int index, int n) =>
      view.cellOutcome(side, index, n);
  bool cellHasFoul(Side side, int index, int n) =>
      view.cellHasFoul(side, index, n);
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
    // other team, so the keeper must stay on it instead of advancing.
    final interrupted = view.questionMarks[questionNumber - 1].interrupted;
    lastAlert = (!correct && interrupted)
        ? _joinNotices(
            _notices(),
            'Incorrect on interrupted Q$questionNumber — question stays for '
            "the other team's re-read.",
          )
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
