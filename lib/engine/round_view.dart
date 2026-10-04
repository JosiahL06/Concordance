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
    required this.label,
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.fouls,
    required this.status,
    required this.active,
  });

  final String label;
  final int score;
  final int correct;
  final int incorrect;
  final int fouls;

  /// '' when active, else QUIZ-OUT / STRIKE-OUT / FOUL-OUT.
  final String status;
  final bool active;
}

/// Per-team read snapshot.
class TeamView {
  const TeamView({
    required this.side,
    required this.score,
    required this.timeOuts,
    required this.quizzers,
  });

  final Side side;
  final int score;
  final int timeOuts;
  final List<QuizzerView> quizzers;
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
  final int value;
  final bool interrupted;
  final bool contested;
  final bool voided;
}

/// The engine facade owned by the live-scoring screens.
class RoundView {
  RoundView({
    required this.ruleset,
    required List<String> redLabels,
    required List<String> greenLabels,
    List<int>? questionValues,
  }) : _redLabels = List<String>.unmodifiable(redLabels),
       _greenLabels = List<String>.unmodifiable(greenLabels),
       _baseValues = List<int>.of(questionValues ?? ruleset.match.pointValues),
       state = RoundState(
         values: List<int>.of(questionValues ?? ruleset.match.pointValues),
       ) {
    state.teams[Side.red] = TeamState(Side.red, _redLabels);
    state.teams[Side.green] = TeamState(Side.green, _greenLabels);
  }

  final Ruleset ruleset;
  final RoundState state;
  final List<RoundEvent> journal = <RoundEvent>[];

  /// Roster labels + base question sequence captured at construction: undo
  /// re-folds from these, so structural changes (quizzer substitutes,
  /// overtime questions) replay exactly as they originally applied.
  final List<String> _redLabels;
  final List<String> _greenLabels;
  final List<int> _baseValues;

  /// Applies [event], journaling it on success. Returns the violation when
  /// rejected (views decide how to surface; override = record anyway).
  RuleViolation? apply(RoundEvent event) {
    final result = applyEvent(ruleset, state, event);
    if (!result.ok) return result.violation;
    journal.add(event);
    return null;
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
    state.values
      ..clear()
      ..addAll(_baseValues);
    state.questions.clear();
    state.teams[Side.red] = TeamState(Side.red, _redLabels);
    state.teams[Side.green] = TeamState(Side.green, _greenLabels);
    for (final event in List.of(journal)) {
      applyEvent(ruleset, state, event);
    }
  }

  // ── shared reads ──

  List<int> get questionValues => List.unmodifiable(state.values);

  int scoreOf(Side side) => state.teams[side]!.score;

  TeamView teamOf(Side side) {
    final team = state.teams[side]!;
    return TeamView(
      side: side,
      score: team.score,
      timeOuts: team.timeOuts,
      quizzers: [
        for (final q in team.quizzers)
          QuizzerView(
            label: q.label,
            score: q.score,
            correct: q.correct,
            incorrect: q.incorrect,
            fouls: q.fouls,
            status: q.quizzedOut
                ? 'QUIZ-OUT'
                : q.struckOut
                ? 'STRIKE-OUT'
                : q.fouledOut
                ? 'FOUL-OUT'
                : '',
            active: q.active,
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

  // ── Classic-only ledger reads ──

  /// Signed point delta for [side] on question [n] (RUNNING row).
  /// Derived by replaying answer/foul events per question from the journal
  /// (the fold accumulates per-quizzer totals; the ledger needs per-cell
  /// attribution, including quiz-out bonus on the crossing event).
  int teamDelta(Side side, int n) {
    var delta = 0;
    for (final event in journal) {
      if (event is AnswerEvent &&
          event.questionNumber == n &&
          event.side == side) {
        final q = state.question(n);
        final value = q.substituteValue ?? state.valueOf(n);
        delta += event.correct
            ? ruleset.scoring.correctPoints(value)
            : -ruleset.scoring.incorrectLoss(value);
        if (event.correct) {
          var prior = 0;
          for (final e in journal) {
            if (identical(e, event)) break;
            if (e is AnswerEvent &&
                e.correct &&
                e.side == side &&
                e.quizzerIndex == event.quizzerIndex) {
              prior += 1;
            }
          }
          if (prior + 1 == ruleset.scoring.quizOutCorrect) {
            delta += ruleset.scoring.quizOutBonus;
          }
        }
      } else if (event is FoulEvent &&
          event.side == side &&
          event.questionNumber == n) {
        if (event.quizzerIndex == null) {
          delta -= ruleset.scoring.teamFoulDeduction;
        } else {
          delta -= ruleset.scoring.foulDeduction;
        }
      }
    }
    return delta;
  }

  /// Outcome mark for one quizzer cell: 'correct' | 'incorrect' | 'foul' |
  /// null. Last-write-wins per cell from the journal.
  String? cellOutcome(Side side, int quizzerIndex, int n) {
    String? mark;
    for (final event in journal) {
      if (event is AnswerEvent &&
          event.questionNumber == n &&
          event.side == side &&
          event.quizzerIndex == quizzerIndex) {
        mark = event.correct ? 'correct' : 'incorrect';
      } else if (event is FoulEvent &&
          event.side == side &&
          event.quizzerIndex == quizzerIndex &&
          event.questionNumber == n) {
        mark = 'foul';
      }
    }
    return mark;
  }
}
