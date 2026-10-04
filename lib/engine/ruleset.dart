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
    if (schemaVersion != 1) {
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
    required this.pointValues,
    required this.minActivePerTeam,
    required this.maxActivePerTeam,
    required this.teamsPerMatch,
  });

  final int regulationQuestions;
  final List<int> pointValues;
  final int minActivePerTeam;
  final int maxActivePerTeam;
  final int teamsPerMatch;

  factory MatchConfig.fromJson(Map<String, Object?> json) {
    final values = (json['pointValues'] as List).cast<num>();
    for (final v in values) {
      if (v % 2 != 0) {
        throw FormatException('point value $v is not even (D5)');
      }
    }
    return MatchConfig(
      regulationQuestions: json['regulationQuestions'] as int,
      pointValues: [for (final v in values) v.toInt()],
      minActivePerTeam: json['minActivePerTeam'] as int,
      maxActivePerTeam: json['maxActivePerTeam'] as int,
      teamsPerMatch: json['teamsPerMatch'] as int,
    );
  }
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
