/// Ruleset configuration model: ruleset-as-data (pure Dart).
library;

enum ChallengeLimitMode { unsuccessful, used }

enum OvertimeMode { suddenDeath10, threePlusSuddenDeath20 }

enum ChallengeKind { contest, appeal }

OvertimeMode _overtimeModeFrom(String raw) => switch (raw) {
  'suddenDeath10' => OvertimeMode.suddenDeath10,
  'threePlusSuddenDeath20' => OvertimeMode.threePlusSuddenDeath20,
  _ => throw FormatException('unknown overtime mode: $raw'),
};

ChallengeLimitMode _challengeLimitModeFrom(String raw) => switch (raw) {
  'unsuccessful' => ChallengeLimitMode.unsuccessful,
  'used' => ChallengeLimitMode.used,
  _ => throw FormatException('unknown challenge limit mode: $raw'),
};

ChallengeKind _challengeKindFrom(String raw) => switch (raw) {
  'contest' => ChallengeKind.contest,
  'appeal' => ChallengeKind.appeal,
  _ => throw FormatException('unknown challenge kind: $raw'),
};

/// Full ruleset configuration. Field semantics and citations live in
/// `docs/ruleset-schema.md`; this file is the shape + JSON parsing.
class Ruleset {
  const Ruleset({
    required this.schemaVersion,
    required this.id,
    required this.displayName,
    required this.season,
    required this.challengeKind,
    required this.match,
    required this.scoring,
    required this.limits,
    required this.overtime,
  });

  final int schemaVersion;
  final String id;
  final String displayName;
  final String season;
  final ChallengeKind challengeKind;
  final MatchConfig match;
  final ScoringConfig scoring;
  final LimitsConfig limits;
  final OvertimeConfig overtime;

  factory Ruleset.fromJson(Map<String, Object?> json) {
    T req<T>(String key) {
      final v = json[key];
      if (v == null) throw FormatException('ruleset missing "$key"');
      return v as T;
    }

    final schemaVersion = req<num>('schemaVersion').toInt();
    if (schemaVersion != 2) {
      throw FormatException('unsupported schemaVersion $schemaVersion');
    }
    return Ruleset(
      schemaVersion: schemaVersion,
      id: req<String>('id'),
      displayName: req<String>('displayName'),
      season: req<String>('season'),
      challengeKind: _challengeKindFrom(req<String>('challengeKind')),
      match: MatchConfig.fromJson(req<Map<String, Object?>>('match')),
      scoring: ScoringConfig.fromJson(req<Map<String, Object?>>('scoring')),
      limits: LimitsConfig.fromJson(req<Map<String, Object?>>('limits')),
      overtime: OvertimeConfig.fromJson(req<Map<String, Object?>>('overtime')),
    );
  }
}

/// Match structure.
class MatchConfig {
  const MatchConfig({
    required this.regulationQuestions,
    required this.answerValues,
    required this.valueCounts,
    required this.valueRules,
    required this.minActivePerTeam,
    required this.maxActivePerTeam,
    required this.teamsPerMatch,
    this.maxRosterPerTeam,
  });

  final int regulationQuestions;

  /// The point values a question may be scored at (sorted, distinct). Drives
  /// the live value picker and the `question-value-not-allowed` guardrail.
  /// The rulebooks no longer fix a per-question order: the keeper sets each
  /// question's value live as it is read (schema decision D11), so this is a
  /// *set*, not a sequence.
  final List<int> answerValues;

  /// The book's question-value distribution (e.g. TBQ eight 10s, nine 20s,
  /// three 30s). Informational: shown on the setup card and asserted by the
  /// golden tests against the rulebook. Never used to pre-set a question.
  final Map<int, int> valueCounts;

  final int minActivePerTeam;
  final int maxActivePerTeam;
  final int teamsPerMatch;

  /// Maximum quizzers a team may register (seated + bench), or null when the
  /// rulebook sets no cap. JBQ caps a team at 8; TBQ's match guidelines only
  /// fix the seated count (1–3 active), so its roster is uncapped here.
  final int? maxRosterPerTeam;

  /// Advisory per-question value constraints (schema decision D12). Never
  /// blocks a value — violations are surfaced as scorekeeper notices.
  final ValueRules valueRules;

  /// Bench capacity for a team with [seated] quizzers: the roster cap beyond
  /// the table, or null when the roster is uncapped.
  int? benchCapacity(int seated) =>
      maxRosterPerTeam == null ? null : maxRosterPerTeam! - seated;

  factory MatchConfig.fromJson(Map<String, Object?> json) {
    final values = (json['answerValues'] as List).cast<num>();
    for (final v in values) {
      if (v % 2 != 0) {
        throw FormatException('point value $v is not even (D5)');
      }
    }
    final counts = (json['valueCounts'] as Map).cast<String, Object?>();
    return MatchConfig(
      regulationQuestions: json['regulationQuestions'] as int,
      answerValues: ([for (final v in values) v.toInt()]..sort()),
      valueCounts: {
        for (final e in counts.entries) int.parse(e.key): (e.value as num).toInt(),
      },
      valueRules: json['valueRules'] == null
          ? const ValueRules()
          : ValueRules.fromJson(
              (json['valueRules'] as Map).cast<String, Object?>(),
            ),
      minActivePerTeam: json['minActivePerTeam'] as int,
      maxActivePerTeam: json['maxActivePerTeam'] as int,
      teamsPerMatch: json['teamsPerMatch'] as int,
      maxRosterPerTeam: json['maxRosterPerTeam'] as int?,
    );
  }
}

/// Per-question value constraints for the constructed set (schema decision
/// D12). Everything here is **advisory**: the engine journals whatever value
/// the keeper enters, but a violation raises a scorekeeper notice so a
/// mis-transcribed set is caught. Absent in a ruleset ⇒ no constraints.
class ValueRules {
  const ValueRules({
    this.noValueAtEnds = const <int>{},
    this.noConsecutiveValues = const <int>{},
    this.halfMinimums = const <HalfMinimum>[],
  });

  /// Values that may not be the first or the last regulation question.
  final Set<int> noValueAtEnds;

  /// Values that may not be asked on two consecutive questions.
  final Set<int> noConsecutiveValues;

  /// Minimum count of a value required in *each* half of the match.
  final List<HalfMinimum> halfMinimums;

  factory ValueRules.fromJson(Map<String, Object?> json) => ValueRules(
    noValueAtEnds: _intSet(json['noValueAtEnds']),
    noConsecutiveValues: _intSet(json['noConsecutiveValues']),
    halfMinimums: [
      for (final m in (json['halfMinimums'] as List? ?? const <Object?>[]))
        HalfMinimum(
          value: ((m as Map)['value'] as num).toInt(),
          count: (m['count'] as num).toInt(),
        ),
    ],
  );

  static Set<int> _intSet(Object? raw) => {
    for (final v in (raw as List? ?? const <Object?>[])) (v as num).toInt(),
  };
}

/// One per-half minimum: each half must contain at least [count] questions of
/// [value].
class HalfMinimum {
  const HalfMinimum({required this.value, required this.count});

  final int value;
  final int count;
}

/// Scoring numbers.
class ScoringConfig {
  const ScoringConfig({
    required this.correctPoints,
    required this.incorrectLoss,
    required this.quizOutCorrect,
    required this.quizOutBonus,
    required this.quizOutLeavesMatch,
    required this.strikeOutIncorrect,
    required this.foulDeduction,
    required this.foulsToFoulOut,
    required this.teamFoulDeduction,
  });

  /// Awarded for a correct answer on a question of [value].
  final int Function(int value) correctPoints;

  /// Deducted for an incorrect answer on a question of [value].
  final int Function(int value) incorrectLoss;
  final int quizOutCorrect;
  final int quizOutBonus;
  final bool quizOutLeavesMatch;
  final int strikeOutIncorrect;
  final int foulDeduction;
  final int foulsToFoulOut;
  final int teamFoulDeduction;

  factory ScoringConfig.fromJson(Map<String, Object?> json) {
    num reqNum(String key) => json[key] as num;
    // Multipliers applied with integer math (all values even, D5).
    final correctMult = reqNum('correctMultiplier').toDouble();
    final incorrectMult = reqNum('incorrectMultiplier').toDouble();
    final quizOut = json['quizOut'] as Map<String, Object?>;
    final strikeOut = json['strikeOut'] as Map<String, Object?>;
    final foul = json['foul'] as Map<String, Object?>;
    return ScoringConfig(
      correctPoints: (v) => (v * correctMult).toInt(),
      incorrectLoss: (v) => (v * incorrectMult).toInt(),
      quizOutCorrect: quizOut['correctNeeded'] as int,
      quizOutBonus: quizOut['bonus'] as int,
      quizOutLeavesMatch: quizOut['leavesMatch'] as bool,
      strikeOutIncorrect: strikeOut['incorrectNeeded'] as int,
      foulDeduction: foul['deduction'] as int,
      foulsToFoulOut: foul['foulsToFoulOut'] as int,
      teamFoulDeduction: foul['teamDeduction'] as int,
    );
  }
}

/// Bookkeeping limits and scorekeeper notification thresholds.
class LimitsConfig {
  const LimitsConfig({
    required this.timeOutsPerTeam,
    required this.notifyTimeOutRequest,
    required this.overtimeTimeOutsCarry,
    required this.overtimeExtraTimeOuts,
    required this.challengeLimitMode,
    required this.challengeLimitCount,
    required this.challengesPerQuestionPerTeam,
    required this.challengeAllotmentPerTeam,
  });

  final int timeOutsPerTeam;
  final int notifyTimeOutRequest;
  final bool overtimeTimeOutsCarry;
  final int overtimeExtraTimeOuts;
  final ChallengeLimitMode challengeLimitMode;
  final int challengeLimitCount;
  final int? challengesPerQuestionPerTeam;
  final int? challengeAllotmentPerTeam;

  /// Team time-outs allowed, given whether the match has reached overtime.
  ///
  /// Regulation grants [timeOutsPerTeam] (Time-outs §2 both books). In
  /// overtime the rulebooks diverge:
  /// - TBQ Time-outs §4: "Remaining team time-outs may not be used in
  ///   overtime" and no extra is granted → **no** team time-out may be taken
  ///   (`overtimeTimeOutsCarry` false, `overtimeExtraTimeOuts` 0).
  /// - JBQ Time-outs §§4–5: remaining time-outs carry over *and* each team is
  ///   granted [overtimeExtraTimeOuts] more → cap = [timeOutsPerTeam] +
  ///   [overtimeExtraTimeOuts].
  ///
  /// Both books also declare a free one-minute time-out at the start of
  /// overtime; that is the Quizmaster's declaration, not a team time-out, so
  /// it is not counted here.
  int timeOutCap({required bool inOvertime}) {
    if (!inOvertime) return timeOutsPerTeam;
    return (overtimeTimeOutsCarry ? timeOutsPerTeam : 0) +
        overtimeExtraTimeOuts;
  }

  factory LimitsConfig.fromJson(Map<String, Object?> json) {
    final challengeLimit = json['challengeLimit'] as Map<String, Object?>;
    return LimitsConfig(
      timeOutsPerTeam: json['timeOutsPerTeam'] as int,
      notifyTimeOutRequest: json['notifyTimeOutRequest'] as int,
      overtimeTimeOutsCarry: json['overtimeTimeOutsCarry'] as bool,
      overtimeExtraTimeOuts: json['overtimeExtraTimeOuts'] as int,
      challengeLimitMode: _challengeLimitModeFrom(
        challengeLimit['mode'] as String,
      ),
      challengeLimitCount: challengeLimit['count'] as int,
      challengesPerQuestionPerTeam:
          json['challengesPerQuestionPerTeam'] as int?,
      challengeAllotmentPerTeam: json['challengeAllotmentPerTeam'] as int?,
    );
  }
}

/// Overtime format.
class OvertimeConfig {
  const OvertimeConfig({
    required this.mode,
    required this.declaresReopenTimeout,
    required this.foulPartOfQuestion,
  });

  final OvertimeMode mode;
  final bool declaresReopenTimeout;
  final bool foulPartOfQuestion;

  factory OvertimeConfig.fromJson(Map<String, Object?> json) => OvertimeConfig(
    mode: _overtimeModeFrom(json['mode'] as String),
    declaresReopenTimeout: json['declaresReopenTimeout'] as bool,
    foulPartOfQuestion: json['foulPartOfQuestion'] as bool,
  );
}
