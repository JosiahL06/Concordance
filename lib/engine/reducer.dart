/// Pure fold: (ruleset, state, event) -> state or [RuleViolation].
///
/// Validation never throws: invalid events return a violation describing why
/// (views decide how to surface; the quizmaster may override reality and the
/// journal records what was recorded).
library;

import 'events.dart';
import 'ruleset.dart';
import 'state.dart';

/// A rejected event and the reason it was rejected.
class RuleViolation {
  const RuleViolation(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RuleViolation($code): $message';
}

/// Result of applying one event: either the (mutated) state or a violation.
class FoldResult {
  const FoldResult.ok(this.state) : violation = null;
  const FoldResult.rejected(this.violation) : state = null;

  final RoundState? state;
  final RuleViolation? violation;

  bool get ok => violation == null;
}

/// Applies [event] to [state] under [ruleset].
FoldResult applyEvent(Ruleset ruleset, RoundState state, RoundEvent event) {
  switch (event) {
    case AnswerEvent():
      return answerFold(
        state,
        ruleset,
        event.questionNumber,
        event.side,
        event.quizzerIndex,
        event.correct,
      );
    case FoulEvent():
      return foulFold(
        state,
        ruleset,
        event.questionNumber,
        event.side,
        event.quizzerIndex,
      );
    case TimeOutEvent():
      // Time-outs are capped at the ruleset allotment (which differs between
      // regulation and overtime — see `LimitsConfig.timeOutCap`). A request
      // beyond the cap is *denied* (and, per both rulebooks, becomes a team
      // foul the keeper records through the normal foul path) — the engine
      // never auto-assesses the foul, and the rejected request is not
      // journaled. Overtime is the presence of appended question slots.
      final team = state.teams[event.side]!;
      final inOvertime =
          state.values.length > ruleset.match.regulationQuestions;
      if (team.timeOuts >= ruleset.limits.timeOutCap(inOvertime: inOvertime)) {
        return const FoldResult.rejected(
          RuleViolation('timeout-limit', 'no time-outs remaining'),
        );
      }
      team.timeOuts += 1;
      return FoldResult.ok(state);
    case InterruptionEvent():
      final range = inRange(state, event.questionNumber);
      if (!range.ok) return range;
      state.question(event.questionNumber).interrupted = true;
      return FoldResult.ok(state);
    case ChallengeEvent():
      return challengeFold(
        state,
        ruleset,
        event.questionNumber,
        event.side,
        event.successful,
      );
    case VoidQuestionEvent():
      final range = inRange(state, event.questionNumber);
      if (!range.ok) return range;
      state.question(event.questionNumber).voided = true;
      return FoldResult.ok(state);
    case SubstituteQuestionEvent():
      return substituteQuestionFold(state, event.questionNumber, event.value);
    case SubstituteQuizzerEvent():
      return substituteQuizzerFold(
        state,
        event.side,
        event.outIndex,
        event.label,
      );
    case OvertimeQuestionEvent():
      state.values.add(event.value);
      return FoldResult.ok(state);
  }
}

FoldResult inRange(RoundState state, int n) {
  if (n < 1 || n > state.values.length) {
    return const FoldResult.rejected(
      RuleViolation('question-range', 'question number out of range'),
    );
  }
  return FoldResult.ok(state);
}

FoldResult answerFold(
  RoundState state,
  Ruleset ruleset,
  int n,
  Side side,
  int quizzerIndex,
  bool correct,
) {
  final range = inRange(state, n);
  if (!range.ok) return range;
  final q = state.question(n);
  if (q.voided && q.substituteValue == null) {
    return const FoldResult.rejected(
      RuleViolation(
        'question-voided',
        'question voided with no substitute read',
      ),
    );
  }
  final team = state.teams[side]!;
  if (quizzerIndex < 0 || quizzerIndex >= team.quizzers.length) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-range', 'quizzer index out of range'),
    );
  }
  final quizzer = team.quizzers[quizzerIndex];
  if (!quizzer.active || quizzer.inactive) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-inactive', 'quizzer cannot answer'),
    );
  }
  final scoring = ruleset.scoring;
  final value = q.substituteValue ?? state.valueOf(n);
  if (correct) {
    quizzer.score += scoring.correctPoints(value);
    quizzer.correct += 1;
    if (quizzer.correct >= scoring.quizOutCorrect && !quizzer.quizzedOut) {
      quizzer.score += scoring.quizOutBonus;
      quizzer.quizzedOut = true;
      if (scoring.quizOutLeavesMatch) quizzer.leftMatch = true;
    }
  } else {
    quizzer.score -= scoring.incorrectLoss(value);
    quizzer.incorrect += 1;
    if (quizzer.incorrect >= scoring.strikeOutIncorrect && !quizzer.struckOut) {
      quizzer.struckOut = true;
      if (scoring.quizOutLeavesMatch) quizzer.leftMatch = true;
    }
  }
  return FoldResult.ok(state);
}

FoldResult foulFold(
  RoundState state,
  Ruleset ruleset,
  int? n,
  Side side,
  int? quizzerIndex,
) {
  if (n != null) {
    final range = inRange(state, n);
    if (!range.ok) return range;
  }
  final team = state.teams[side]!;
  final scoring = ruleset.scoring;
  if (quizzerIndex == null) {
    team.teamFouls += 1;
    team.teamFoulPoints -= scoring.teamFoulDeduction;
    return FoldResult.ok(state);
  }
  if (quizzerIndex < 0 || quizzerIndex >= team.quizzers.length) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-range', 'quizzer index out of range'),
    );
  }
  final quizzer = team.quizzers[quizzerIndex];
  quizzer.score -= scoring.foulDeduction;
  quizzer.fouls += 1;
  if (quizzer.fouls >= scoring.foulsToFoulOut && !quizzer.fouledOut) {
    quizzer.fouledOut = true;
    if (scoring.quizOutLeavesMatch) quizzer.leftMatch = true;
  }
  return FoldResult.ok(state);
}

FoldResult challengeFold(
  RoundState state,
  Ruleset ruleset,
  int n,
  Side side,
  bool successful,
) {
  final range = inRange(state, n);
  if (!range.ok) return range;
  final limits = ruleset.limits;
  final team = state.teams[side]!;
  // Match-wide team limits: TBQ bars a team's further contests after its
  // 3rd unsuccessful; JBQ allows each team 2 Coach's Appeals.
  if (limits.challengeLimitMode == ChallengeLimitMode.unsuccessful &&
      team.unsuccessfulChallenges >= limits.challengeLimitCount) {
    return const FoldResult.rejected(
      RuleViolation('challenge-team-limit', 'team contest limit reached'),
    );
  }
  if (limits.challengeLimitMode == ChallengeLimitMode.used &&
      limits.challengeAllotmentPerTeam != null &&
      team.challengesUsed >= limits.challengeAllotmentPerTeam!) {
    return const FoldResult.rejected(
      RuleViolation('challenge-team-limit', 'appeal allotment exhausted'),
    );
  }
  final q = state.question(n);
  final perQuestion = limits.challengesPerQuestionPerTeam;
  if (perQuestion != null && (q.contestsBySide[side] ?? 0) >= perQuestion) {
    return const FoldResult.rejected(
      RuleViolation(
        'challenge-per-question-cap',
        'per-question challenge cap reached',
      ),
    );
  }
  q.contests += 1;
  q.contestsBySide[side] = (q.contestsBySide[side] ?? 0) + 1;
  if (!successful) {
    q.unsuccessful += 1;
    team.unsuccessfulChallenges += 1;
  }
  q.appeals += 1;
  team.challengesUsed += 1;
  return FoldResult.ok(state);
}

FoldResult substituteQuestionFold(RoundState state, int n, int value) {
  final range = inRange(state, n);
  if (!range.ok) return range;
  final q = state.question(n);
  if (!q.voided) {
    return const FoldResult.rejected(
      RuleViolation(
        'substitute-without-void',
        'substitute requires a voided question',
      ),
    );
  }
  if (value % 2 != 0) {
    return const FoldResult.rejected(
      RuleViolation('odd-value', 'point value must be even'),
    );
  }
  q.substituteValue = value;
  return FoldResult.ok(state);
}

FoldResult substituteQuizzerFold(
  RoundState state,
  Side side,
  int outIndex,
  String label,
) {
  final team = state.teams[side]!;
  if (outIndex < 0 || outIndex >= team.quizzers.length) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-range', 'quizzer index out of range'),
    );
  }
  final out = team.quizzers[outIndex];
  if (out.active) {
    return const FoldResult.rejected(
      RuleViolation(
        'quizzer-still-active',
        'only an out quizzer can be replaced',
      ),
    );
  }
  if (out.inactive) {
    // Already substituted once: don't let one slot spawn two entrants.
    return const FoldResult.rejected(
      RuleViolation(
        'quizzer-already-replaced',
        'this out quizzer was already replaced',
      ),
    );
  }
  out.inactive = true;
  team.quizzers.add(QuizzerState(label));
  return FoldResult.ok(state);
}
