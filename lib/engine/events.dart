/// Scoring-engine event journal (pure Dart — no Flutter imports).
///
/// Every scoring event carries an explicit [questionNumber] (schema decision
/// D1): the Classic view lets the keeper score a non-current question, so
/// events target a question explicitly and the view supplies the current
/// question as the default. Pure navigation (tapping a cell to look) is
/// view state and is never journaled.
///
/// Replaying the journal through the reducer reproduces state exactly, so
/// undo is pop + re-fold and persistence is the serialized journal.
library;

/// Which side of the table acted.
enum Side { red, green }

/// Base type for all journal entries.
sealed class RoundEvent {
  const RoundEvent();
}

/// A quizzer answered question [questionNumber].
class AnswerEvent extends RoundEvent {
  const AnswerEvent({
    required this.questionNumber,
    required this.side,
    required this.quizzerIndex,
    required this.correct,
  });

  final int questionNumber;
  final Side side;
  final int quizzerIndex;
  final bool correct;
}

/// A foul: assessed to a quizzer, or to the team when [quizzerIndex] is null
/// (coach / assistant / inactive / other-person fouls).
class FoulEvent extends RoundEvent {
  const FoulEvent({this.questionNumber, required this.side, this.quizzerIndex});

  final int? questionNumber;
  final Side side;
  final int? quizzerIndex;
}

/// A team time-out was taken.
class TimeOutEvent extends RoundEvent {
  const TimeOutEvent({required this.side});

  final Side side;
}

/// Question [questionNumber] was interrupted (mark only — paper "circle").
class InterruptionEvent extends RoundEvent {
  const InterruptionEvent({required this.questionNumber});

  final int questionNumber;
}

/// A contest (TBQ) or Coach's Appeal (JBQ) by [side] on [questionNumber].
/// Unified as `challenge` per schema decision D2.
class ChallengeEvent extends RoundEvent {
  const ChallengeEvent({
    required this.questionNumber,
    required this.side,
    required this.successful,
  });

  final int questionNumber;
  final Side side;
  final bool successful;
}

/// Question [questionNumber] was voided: answer points are retracted, fouls
/// stand (schema decision D3).
class VoidQuestionEvent extends RoundEvent {
  const VoidQuestionEvent({required this.questionNumber});

  final int questionNumber;
}

/// A substitute question of [value] replaces voided [questionNumber]
/// (same slot, schema decision D4).
class SubstituteQuestionEvent extends RoundEvent {
  const SubstituteQuestionEvent({
    required this.questionNumber,
    required this.value,
  });

  final int questionNumber;
  final int value;
}

/// The bench quizzer at [benchIndex] immediately replaces the
/// quizzed/striked/fouled-out quizzer at [outIndex] — no time-out needed.
/// The entrant is a first-class bench member (`RoundView` seeds the bench);
/// the out quizzer stays in the roster as inactive so their points keep
/// counting (schema decision D7).
class SubstituteQuizzerEvent extends RoundEvent {
  const SubstituteQuizzerEvent({
    required this.side,
    required this.outIndex,
    required this.benchIndex,
  });

  final Side side;
  final int outIndex;
  final int benchIndex;
}

/// An overtime question of [value] is appended as a new slot
/// (schema decision D4).
class OvertimeQuestionEvent extends RoundEvent {
  const OvertimeQuestionEvent({required this.value});

  final int value;
}
