/// Read model both live-scoring views program against.
///
/// `RoundView` is the contract between the engine and the Modern + Classic
/// layouts: shared reads, Classic-only ledger reads, and the single event
/// list both views emit. View-local state (selection, screen position,
/// overtime disclosure) stays in the widgets, never here.
library;

import 'events.dart';
import 'reducer.dart';
import 'ruleset.dart';
import 'state.dart';

/// Per-quizzer read snapshot.
class QuizzerView {
  const QuizzerView({
    required this.index,
    required this.label,
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.fouls,
    required this.status,
    required this.active,
    required this.seat,
  });

  /// Stable roster index (seated first, then bench). Views pass this to
  /// `select` / `cellOutcome` so attributes are matched to the right quizzer
  /// across substitutions.
  final int index;
  final String label;
  final int score;
  final int correct;
  final int incorrect;
  final int fouls;

  /// '' when active, else QUIZ-OUT / STRIKE-OUT / FOUL-OUT.
  final String status;
  final bool active;

  /// Seat number (1-based) while seated, or 0 while on the bench.
  final int seat;

  /// True while seated behind the table (the bench).
  bool get onBench => seat == 0;
}

/// Per-team read snapshot.
class TeamView {
  const TeamView({
    required this.side,
    required this.score,
    required this.timeOuts,
    required this.teamFouls,
    required this.challengesUsed,
    required this.unsuccessfulChallenges,
    required this.roster,
  });

  final Side side;
  final int score;
  final int timeOuts;

  /// Coach/assistant/inactive fouls: hit the team total only, never a cell.
  final int teamFouls;

  /// Match-wide contest/appeal bookkeeping (TBQ: unsuccessful cap; JBQ: used
  /// allotment).
  final int challengesUsed;
  final int unsuccessfulChallenges;

  /// The whole roster (seated first, then bench), stable order.
  final List<QuizzerView> roster;

  /// Quizzers currently at the table, in seat order.
  List<QuizzerView> get seated {
    final list = [
      for (final q in roster)
        if (!q.onBench) q,
    ];
    list.sort((a, b) => a.seat.compareTo(b.seat));
    return list;
  }

  /// Quizzers currently behind the table (the bench).
  List<QuizzerView> get bench => [
    for (final q in roster)
      if (q.onBench) q,
  ];
}

/// Per-question mark snapshot (paper: circle / slash / F language).
class QuestionView {
  const QuestionView({
    required this.number,
    required this.value,
    required this.interrupted,
    required this.contested,
    required this.voided,
  });

  final int number;
  final int? value;
  final bool interrupted;
  final bool contested;
  final bool voided;
}

/// One event that no longer applies to a candidate journal.
class JournalIssue {
  const JournalIssue({
    required this.index,
    required this.event,
    required this.violation,
  });

  /// Index in the candidate journal (not the committed journal).
  final int index;
  final RoundEvent event;
  final RuleViolation violation;
}

/// Result of replaying a candidate journal. [state] is the fold produced by
/// applying every event that still applies — invalid events are reported in
/// [issues] and skipped, which is exactly the state after removing them.
class JournalReplay {
  const JournalReplay({required this.state, required this.issues});

  final RoundState state;
  final List<JournalIssue> issues;

  bool get ok => issues.isEmpty;
}

/// The engine facade owned by the live-scoring screens.
class RoundView {
  RoundView({
    required this.ruleset,
    required List<String> redLabels,
    required List<String> greenLabels,
    List<String> redBench = const <String>[],
    List<String> greenBench = const <String>[],
    List<int?>? questionValues,
  }) : _redLabels = List<String>.unmodifiable(redLabels),
       _greenLabels = List<String>.unmodifiable(greenLabels),
       _redBench = List<String>.unmodifiable(redBench),
       _greenBench = List<String>.unmodifiable(greenBench),
       // No built-in per-question order (D11): regulation slots start unset
       // (null) and are assigned live. A caller (tests, a future pre-loaded
       // set) may supply explicit values instead.
       _baseValues = List<int?>.of(
         questionValues ??
             List<int?>.filled(ruleset.match.regulationQuestions, null),
       ) {
    state = _freshState();
  }

  final Ruleset ruleset;

  /// Derived state. Replaced wholesale when a journal edit is committed.
  late RoundState state;
  final List<RoundEvent> journal = <RoundEvent>[];

  /// Roster labels + base question sequence captured at construction: undo
  /// re-folds from these, so structural changes (quizzer substitutes,
  /// overtime questions) replay exactly as they originally applied.
  final List<String> _redLabels;
  final List<String> _greenLabels;
  final List<String> _redBench;
  final List<String> _greenBench;
  final List<int?> _baseValues;

  /// Applies [event], journaling it on success. Returns the violation when
  /// rejected (views decide how to surface; override = record anyway).
  RuleViolation? apply(RoundEvent event) {
    final result = applyEvent(ruleset, state, event);
    if (!result.ok) return result.violation;
    journal.add(event);
    return null;
  }

  /// Replays [candidate] against a fresh state without touching the committed
  /// journal. Events that no longer apply are reported in [JournalReplay.issues]
  /// and skipped, so the returned state is the fold after removing exactly those
  /// events. This is what lets the UI preview and confirm a history edit.
  JournalReplay replayCandidate(List<RoundEvent> candidate) {
    final fresh = _freshState();
    final issues = <JournalIssue>[];
    for (var i = 0; i < candidate.length; i++) {
      final event = candidate[i];
      final result = applyEvent(ruleset, fresh, event);
      if (!result.ok) {
        issues.add(
          JournalIssue(index: i, event: event, violation: result.violation!),
        );
      }
    }
    return JournalReplay(state: fresh, issues: issues);
  }

  /// Commits [candidate] when every event applies, replacing derived state with
  /// the fresh fold. Returns the replay report; on an invalid candidate the
  /// committed journal/state are left untouched.
  JournalReplay replaceJournal(List<RoundEvent> candidate) {
    final replay = replayCandidate(candidate);
    if (!replay.ok) return replay;
    journal
      ..clear()
      ..addAll(candidate);
    state = replay.state;
    return replay;
  }

  /// Pops the last event and re-folds from scratch (rounds are tiny).
  bool undo() {
    if (journal.isEmpty) return false;
    journal.removeLast();
    _refold();
    return true;
  }

  void _refold() {
    // Full reconstruction: rebuild rosters from the captured labels and
    // replay the journal, so roster changes (substitutes) and appended
    // overtime questions re-fold exactly as they originally applied.
    state = _freshState();
    for (final event in List.of(journal)) {
      applyEvent(ruleset, state, event);
    }
  }

  /// A fresh state seeded with the captured roster (seated + bench) and base
  /// question values. Every replay starts here.
  RoundState _freshState() {
    final fresh = RoundState(values: List<int?>.of(_baseValues));
    fresh.teams[Side.red] = TeamState(
      Side.red,
      _redLabels,
      benchLabels: _redBench,
    );
    fresh.teams[Side.green] = TeamState(
      Side.green,
      _greenLabels,
      benchLabels: _greenBench,
    );
    return fresh;
  }

  // ── roster seeds (persistence) ──

  /// Original bench roster labels captured at construction, so a resumed round
  /// re-seeds the same bench before replaying substitutions.
  List<String> get redBenchSeed => List.unmodifiable(_redBench);
  List<String> get greenBenchSeed => List.unmodifiable(_greenBench);

  // ── shared reads ──

  List<int?> get questionValues => List.unmodifiable(state.values);

  /// The value an answer on [n] actually scores at: a voided slot's substitute
  /// value wins, otherwise the slot's assigned value. The console and ledger
  /// must read this, not [questionValues], or a substitute read displays the
  /// original question's value.
  int? effectiveValue(int n) {
    if (n < 1 || n > state.values.length) return null;
    return state.questions[n]?.substituteValue ?? state.valueOf(n);
  }

  /// The explicit substitute value recorded for [n], or null when no substitute
  /// question has been read (a void-only slot still has a slot value, so this is
  /// deliberately distinct from [effectiveValue]).
  int? substituteValue(int n) {
    if (n < 1 || n > state.values.length) return null;
    return state.questions[n]?.substituteValue;
  }

  int scoreOf(Side side) => state.teams[side]!.score;

  /// Whether question [n]'s value may be (re)set by the keeper (D11): only a
  /// *regulation* slot that is neither voided (its value comes from the
  /// substitute) nor already answered (the value locks once scored). Overtime
  /// slots are fixed by the rulebook and never editable.
  bool questionValueEditable(int n) {
    if (n < 1 || n > state.values.length) return false;
    if (n > ruleset.match.regulationQuestions) return false;
    final q = state.questions[n];
    if (q == null) return true;
    if (q.voided || q.answers.isNotEmpty) return false;
    return true;
  }

  TeamView teamOf(Side side) {
    final team = state.teams[side]!;
    return TeamView(
      side: side,
      score: team.score,
      timeOuts: team.timeOuts,
      teamFouls: team.teamFouls,
      challengesUsed: team.challengesUsed,
      unsuccessfulChallenges: team.unsuccessfulChallenges,
      roster: [
        for (var i = 0; i < team.quizzers.length; i++)
          QuizzerView(
            index: i,
            label: team.quizzers[i].label,
            score: team.quizzers[i].score,
            correct: team.quizzers[i].correct,
            incorrect: team.quizzers[i].incorrect,
            fouls: team.quizzers[i].fouls,
            status: team.quizzers[i].quizzedOut
                ? 'QUIZ-OUT'
                : team.quizzers[i].struckOut
                ? 'STRIKE-OUT'
                : team.quizzers[i].fouledOut
                ? 'FOUL-OUT'
                : '',
            active: team.quizzers[i].active,
            seat: team.quizzers[i].seat,
          ),
      ],
    );
  }

  List<QuestionView> get questionMarks => [
    for (var n = 1; n <= state.values.length; n++)
      QuestionView(
        number: n,
        value: state.valueOf(n),
        interrupted: state.questions[n]?.interrupted ?? false,
        contested: (state.questions[n]?.contests ?? 0) > 0,
        voided: state.questions[n]?.voided ?? false,
      ),
  ];

  /// Human-readable reason an answer by ([side], [quizzerIndex]) on question
  /// [n] would be rejected by the answer guardrails (D10), or null when the
  /// answer is allowed. The console disables CORRECT/INCORRECT on a non-null
  /// reason and shows it, so the keeper sees why before tapping.
  String? answerBlockedReason(Side side, int quizzerIndex, int n) =>
      answerGuardrail(state, n, side, quizzerIndex)?.message;

  // ── Classic-only ledger reads ──

  /// Signed point delta for [side] on question [n] (RUNNING row). Read from
  /// the slot's recorded answers/fouls so a voided question reports zero once
  /// its answers are retracted (D3); the quiz-out bonus is attributed to the
  /// slot where it was crossed.
  int teamDelta(Side side, int n) {
    final q = state.questions[n];
    if (q == null) return 0;
    var delta = 0;
    for (final a in q.answers) {
      if (a.side == side) delta += a.delta + a.bonus;
    }
    for (final f in q.fouls) {
      if (f.side == side) delta -= f.deduction;
    }
    return delta;
  }

  /// Outcome mark for one quizzer cell: 'correct' | 'incorrect' | null.
  /// A personal foul does not overwrite the answer mark — the cell shows the
  /// score plus an `F` badge (see [cellHasFoul]). Read from the slot so a void
  /// retracts the mark (D3).
  String? cellOutcome(Side side, int quizzerIndex, int n) {
    final q = state.questions[n];
    if (q == null) return null;
    String? mark;
    for (final a in q.answers) {
      if (a.side == side && a.quizzerIndex == quizzerIndex) {
        mark = a.correct ? 'correct' : 'incorrect';
      }
    }
    return mark;
  }

  /// Whether [side]'s quizzer has a personal foul on question [n]. Shown as
  /// a capital-F badge alongside the answer mark, never instead of it. Fouls
  /// survive voiding (D3), so retraction never clears them.
  bool cellHasFoul(Side side, int quizzerIndex, int n) {
    final q = state.questions[n];
    if (q == null) return false;
    return q.fouls.any((f) => f.side == side && f.quizzerIndex == quizzerIndex);
  }
}
