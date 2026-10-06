/// Derived round state: the pure fold of (ruleset, journal).
///
/// State is rebuilt by replaying events, so undo is pop + re-fold and the
/// journal is the persistence unit. Views read through `RoundView`
/// (serves both Modern and Classic); Classic additionally reads per-cell
/// outcomes for its ledger grid.
library;

import 'events.dart';

/// Per-quizzer standing within a team.
class QuizzerState {
  QuizzerState(this.label, {this.seat = 0});

  final String label;
  int score = 0;
  int correct = 0;
  int incorrect = 0;
  int fouls = 0;
  bool quizzedOut = false;
  bool struckOut = false;
  bool fouledOut = false;
  bool leftMatch = false;

  /// Seat number (1-based) while seated at the table, or 0 while on the bench.
  /// A substitution hands the entrant the vacated seat, so the seated order
  /// (Red 1, Red 2, …) is preserved with the replacement in the outgoing
  /// quizzer's place.
  int seat;

  /// The out flags are permanent for the match (a quizzer who quizzed out,
  /// struck out, fouled out or left cannot answer again).
  bool get out => quizzedOut || struckOut || fouledOut || leftMatch;

  /// True while seated behind the table (the bench).
  bool get onBench => seat == 0;

  /// Eligible to answer: seated and not out.
  bool get active => !out && seat != 0;
}

/// Per-team standing.
class TeamState {
  TeamState(
    this.side,
    List<String> labels, {
    List<String> benchLabels = const [],
  }) {
    for (var i = 0; i < labels.length; i++) {
      quizzers.add(QuizzerState(labels[i], seat: i + 1));
    }
    for (final label in benchLabels) {
      quizzers.add(QuizzerState(label));
    }
  }

  final Side side;

  /// The whole roster in a stable order (seated first, then bench). Indices
  /// never change, so an answer recorded against a quizzer stays attributed to
  /// them even after they are substituted to or from the bench.
  final List<QuizzerState> quizzers = <QuizzerState>[];

  /// Quizzers at the table, in seat order (a replacement keeps the seat it
  /// took over, so the order only changes when the keeper re-seats someone).
  List<QuizzerState> get seated {
    final list = [
      for (final q in quizzers)
        if (!q.onBench) q,
    ];
    list.sort((a, b) => a.seat.compareTo(b.seat));
    return list;
  }

  /// Quizzers not currently at the table (the bench, including anyone the
  /// keeper rotated out during a time-out), in roster order.
  List<QuizzerState> get bench => [
    for (final q in quizzers)
      if (q.onBench) q,
  ];

  int timeOuts = 0;
  int teamFouls = 0;

  /// Cumulative team-foul points (ruleset deduction applied at fold time —
  /// never hard-coded).
  int teamFoulPoints = 0;

  /// Match-wide contest bookkeeping per team (TBQ: 3 unsuccessful then no
  /// further contests; JBQ: 2 Coach's Appeals). Enforced at fold time.
  int unsuccessfulChallenges = 0;
  int challengesUsed = 0;

  int get score {
    var total = 0;
    for (final q in quizzers) {
      total += q.score;
    }
    return total + teamFoulPoints;
  }
}

/// Marks on one question slot (paper equivalents: circle / slash / F).
class QuestionState {
  bool interrupted = false;
  int contests = 0;
  int unsuccessful = 0;
  int appeals = 0;

  /// Per-question, per-team contest cap (each team may contest a question
  /// at most `challengesPerQuestionPerTeam` times).
  final Map<Side, int> contestsBySide = <Side, int>{Side.red: 0, Side.green: 0};

  bool voided = false;
  int? substituteValue;

  /// Answers recorded on this slot, in journal order. Drives the answer
  /// guardrails (D10) and the per-cell / per-question ledger reads; cleared
  /// when the question is voided so its points are retracted and the
  /// substitute reads fresh (D3/D4). Each entry carries the exact score change
  /// so the void can reverse it.
  final List<SlotAnswer> answers = <SlotAnswer>[];

  /// Fouls recorded on this slot (quizzer fouls carry an index; team fouls are
  /// null). Fouls survive voiding (D3), so these are never cleared.
  final List<SlotFoul> fouls = <SlotFoul>[];
}

/// One recorded answer on a question slot. [delta] is the score change to the
/// quizzer excluding the quiz-out bonus; [bonus] is the quiz-out bonus this
/// answer crossed (0 when it did not). Kept so a void can reverse the answer
/// exactly (D3) and the ledger can attribute points per cell.
class SlotAnswer {
  const SlotAnswer({
    required this.side,
    required this.quizzerIndex,
    required this.correct,
    required this.delta,
    required this.bonus,
  });

  final Side side;
  final int quizzerIndex;
  final bool correct;
  final int delta;
  final int bonus;
}

/// One recorded foul on a question slot. [deduction] is the score change
/// already applied (quizzer or team foul). Team fouls have a null
/// [quizzerIndex] and never attach to a cell (D9).
class SlotFoul {
  const SlotFoul({
    required this.side,
    required this.quizzerIndex,
    required this.deduction,
  });

  final Side side;
  final int? quizzerIndex;
  final int deduction;
}

/// Whole-round derived state.
class RoundState {
  RoundState({required this.values});

  /// Point value per question slot (regulation + appended overtime).
  final List<int> values;

  final Map<Side, TeamState> teams = <Side, TeamState>{};

  /// Marks keyed by 1-based question number.
  final Map<int, QuestionState> questions = <int, QuestionState>{};

  QuestionState question(int n) => questions.putIfAbsent(n, QuestionState.new);

  int valueOf(int n) => values[n - 1];
}
