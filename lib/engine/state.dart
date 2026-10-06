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
  QuizzerState(this.label);

  final String label;
  int score = 0;
  int correct = 0;
  int incorrect = 0;
  int fouls = 0;
  bool quizzedOut = false;
  bool struckOut = false;
  bool fouledOut = false;
  bool leftMatch = false;
  bool inactive = false;

  bool get active => !quizzedOut && !struckOut && !fouledOut && !leftMatch;
}

/// Per-team standing.
class TeamState {
  TeamState(this.side, List<String> labels) {
    for (final label in labels) {
      quizzers.add(QuizzerState(label));
    }
  }

  final Side side;
  final List<QuizzerState> quizzers = <QuizzerState>[];
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

  /// Answer ledger for this slot: quizzer indexes that have answered, per
  /// team. Rebuilt from the journal on re-fold and cleared when the question
  /// is voided (the substitute reads fresh, D4). Drives the answer guardrails
  /// (D10).
  final Map<Side, Set<int>> answered = <Side, Set<int>>{
    Side.red: <int>{},
    Side.green: <int>{},
  };

  /// Whether a correct answer has been recorded on this slot. A correct
  /// answer closes the question to both teams (D10).
  bool answeredCorrect = false;
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
