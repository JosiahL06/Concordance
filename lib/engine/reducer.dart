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
      final q = state.question(event.questionNumber);
      q.voided = true;
      // Retract the slot's answer points (D3): reverse each recorded answer,
      // then re-evaluate the affected quizzers' out flags so a voided crossing
      // can't leave a stale quiz-out / strike-out (and its bonus) behind.
      // Fouls stand (D3) and the ledger clears so the substitute reads fresh
      // (D4).
      final scoring = ruleset.scoring;
      final affected = <(Side, int)>{};
      for (final a in q.answers) {
        final quizzer = state.teams[a.side]!.quizzers[a.quizzerIndex];
        quizzer.score -= a.delta;
        if (a.correct) {
          quizzer.correct -= 1;
        } else {
          quizzer.incorrect -= 1;
        }
        affected.add((a.side, a.quizzerIndex));
      }
      for (final (side, index) in affected) {
        final quizzer = state.teams[side]!.quizzers[index];
        if (quizzer.quizzedOut && quizzer.correct < scoring.quizOutCorrect) {
          quizzer.quizzedOut = false;
          quizzer.score -= scoring.quizOutBonus;
          if (scoring.quizOutLeavesMatch) quizzer.leftMatch = false;
        }
        if (quizzer.struckOut &&
            quizzer.incorrect < scoring.strikeOutIncorrect) {
          quizzer.struckOut = false;
          if (scoring.quizOutLeavesMatch) quizzer.leftMatch = false;
        }
      }
      q.answers.clear();
      return FoldResult.ok(state);
    case QuestionValueEvent():
      return questionValueFold(ruleset, state, event.questionNumber, event.value);
    case SubstituteQuestionEvent():
      return substituteQuestionFold(state, event.questionNumber, event.value);
    case SubstituteQuizzerEvent():
      return substituteQuizzerFold(
        state,
        event.side,
        event.outIndex,
        event.benchIndex,
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

/// Answer guardrails (schema decision D10). A question slot admits at most
/// one answer per quizzer, one answer per team, and one *correct* answer
/// overall — a correct answer closes the question to both teams. An
/// *interrupted* miss is re-read to the opposing team, so wrong+right and
/// wrong+wrong are the only legal two-answer sequences there; a
/// *non-interrupted* miss is not re-read and closes the question too. Returns
/// the violation for a disallowed answer, or null when the answer is allowed.
///
/// Both shipped rulebooks share these mechanics, so this is fixed engine
/// behaviour (like `inRange`), not ruleset config.
RuleViolation? answerGuardrail(
  RoundState state,
  int n,
  Side side,
  int quizzerIndex,
) {
  // A question with no value assigned cannot be scored (D11): the rulebooks
  // fix no per-question order, so the keeper sets the value as the question is
  // read. Surfaces to the console as a blocked reason before the keeper taps.
  final slotValue = state.questions[n]?.substituteValue ?? state.valueOf(n);
  if (slotValue == null) {
    return RuleViolation(
      'question-value-unset',
      'Set the point value for Q$n first',
    );
  }
  final q = state.questions[n];
  if (q == null || q.answers.isEmpty) return null; // nothing recorded yet
  final teamName = side == Side.red ? 'Red' : 'Green';
  if (q.answers.any((a) => a.side == side && a.quizzerIndex == quizzerIndex)) {
    final label = state.teams[side]!.quizzers[quizzerIndex].label;
    return RuleViolation('answer-quizzer-twice', '$label already answered Q$n');
  }
  if (q.answers.any((a) => a.side == side)) {
    return RuleViolation(
      'answer-team-twice',
      '$teamName already answered Q$n — one answer per team',
    );
  }
  if (q.answers.any((a) => a.correct)) {
    return RuleViolation(
      'answer-question-closed',
      'Q$n already has a correct answer',
    );
  }
  // A miss on a NON-interrupted question is not reread to the opposing team, so
  // it closes the question too. An interrupted miss IS reread (the other team
  // may answer), which is why the interruption flag is consulted here.
  if (!q.interrupted && q.answers.any((a) => !a.correct)) {
    return RuleViolation(
      'answer-no-reread',
      'Q$n was missed without an interruption, so it is not reread',
    );
  }
  return null;
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
  if (!quizzer.active) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-inactive', 'quizzer cannot answer'),
    );
  }
  final guardrail = answerGuardrail(state, n, side, quizzerIndex);
  if (guardrail != null) return FoldResult.rejected(guardrail);
  final scoring = ruleset.scoring;
  // The guardrail above guarantees a value is present (unset is rejected).
  final value = (q.substituteValue ?? state.valueOf(n))!;
  var bonus = 0;
  late final int delta;
  if (correct) {
    delta = scoring.correctPoints(value);
    quizzer.score += delta;
    quizzer.correct += 1;
    if (quizzer.correct >= scoring.quizOutCorrect && !quizzer.quizzedOut) {
      bonus = scoring.quizOutBonus;
      quizzer.score += bonus;
      quizzer.quizzedOut = true;
      if (scoring.quizOutLeavesMatch) quizzer.leftMatch = true;
    }
  } else {
    delta = -scoring.incorrectLoss(value);
    quizzer.score += delta;
    quizzer.incorrect += 1;
    if (quizzer.incorrect >= scoring.strikeOutIncorrect && !quizzer.struckOut) {
      quizzer.struckOut = true;
      if (scoring.quizOutLeavesMatch) quizzer.leftMatch = true;
    }
  }
  // Record the answer: it guards later answers on this slot (D10), attributes
  // the ledger delta (Classic RUNNING), and carries the exact score change so
  // a later void can retract it (D3).
  q.answers.add(
    SlotAnswer(
      side: side,
      quizzerIndex: quizzerIndex,
      correct: correct,
      delta: delta,
      bonus: bonus,
    ),
  );
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
    if (n != null) {
      state
          .question(n)
          .fouls
          .add(
            SlotFoul(
              side: side,
              quizzerIndex: null,
              deduction: scoring.teamFoulDeduction,
            ),
          );
    }
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
  // Fouls survive voiding (D3), so the slot keeps them even if answers are
  // later retracted.
  if (n != null) {
    state
        .question(n)
        .fouls
        .add(
          SlotFoul(
            side: side,
            quizzerIndex: quizzerIndex,
            deduction: scoring.foulDeduction,
          ),
        );
  }
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

/// Assigns the keeper-entered point [value] to regulation question [n]
/// (schema decision D11). The rulesets fix no per-question order, so regulation
/// slots start unset and are assigned live as each question is read.
FoldResult questionValueFold(
  Ruleset ruleset,
  RoundState state,
  int n,
  int value,
) {
  final range = inRange(state, n);
  if (!range.ok) return range;
  if (n > ruleset.match.regulationQuestions) {
    return const FoldResult.rejected(
      RuleViolation(
        'question-value-overtime-fixed',
        'overtime questions have a fixed point value',
      ),
    );
  }
  if (!ruleset.match.answerValues.contains(value)) {
    return const FoldResult.rejected(
      RuleViolation(
        'question-value-not-allowed',
        'that point value is not allowed by this ruleset',
      ),
    );
  }
  final q = state.question(n);
  if (q.voided) {
    return const FoldResult.rejected(
      RuleViolation(
        'question-value-voided',
        'read a substitute question to set its value',
      ),
    );
  }
  if (q.answers.isNotEmpty) {
    return FoldResult.rejected(
      RuleViolation(
        'question-value-locked',
        'Q$n is already answered — undo to change its value',
      ),
    );
  }
  state.values[n - 1] = value;
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

/// Swaps a seated quizzer with a bench quizzer (a substitution during or after
/// a time-out). Either may be healthy: a substitution does NOT require anyone
/// to have quizzed out. Both keep their points — the outgoing quizzer sits
/// behind the table (bench) and the incoming one takes the table; stable
/// indices keep every recorded answer attributed to its quizzer.
FoldResult substituteQuizzerFold(
  RoundState state,
  Side side,
  int outIndex,
  int benchIndex,
) {
  final team = state.teams[side]!;
  if (outIndex < 0 || outIndex >= team.quizzers.length) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-range', 'quizzer index out of range'),
    );
  }
  if (benchIndex < 0 || benchIndex >= team.quizzers.length) {
    return const FoldResult.rejected(
      RuleViolation('bench-range', 'no bench quizzer to substitute in'),
    );
  }
  if (outIndex == benchIndex) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-self', 'cannot substitute a quizzer for themself'),
    );
  }
  final out = team.quizzers[outIndex];
  final entrant = team.quizzers[benchIndex];
  if (out.onBench) {
    return const FoldResult.rejected(
      RuleViolation(
        'quizzer-not-seated',
        'only a seated quizzer can be substituted out',
      ),
    );
  }
  if (!entrant.onBench) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-not-benched', 'that quizzer is not on the bench'),
    );
  }
  if (entrant.out) {
    return const FoldResult.rejected(
      RuleViolation('quizzer-out', 'that quizzer is out for the match'),
    );
  }
  // Hand the entrant the outgoing quizzer's seat (so the seated order is
  // unchanged) and put the outgoing quizzer on the bench. Points and history
  // travel with each quizzer (stable roster indices).
  entrant.seat = out.seat;
  out.seat = 0;
  return FoldResult.ok(state);
}
