import 'dart:convert';

import '../engine/events.dart';
import '../engine/round_view.dart';
import '../engine/ruleset.dart';
import 'tournament_models.dart';

/// One started tournament match with everything needed to reconstruct its
/// round for stats.
class TournamentRoundData {
  const TournamentRoundData({
    required this.match,
    required this.roundRow,
    required this.journal,
    required this.links,
  });

  final TournamentMatch match;
  final Map<String, Object?> roundRow;
  final List<RoundEvent> journal;
  final List<TournamentMemberLink> links;

  RoundView toView(Ruleset ruleset) {
    final view = RoundView(
      ruleset: ruleset,
      redLabels: _strings(roundRow['red_seats']),
      greenLabels: _strings(roundRow['green_seats']),
      redBench: _strings(roundRow['red_bench']),
      greenBench: _strings(roundRow['green_bench']),
    );
    for (final event in journal) {
      view.apply(event);
    }
    return view;
  }

  static List<String> _strings(Object? raw) {
    try {
      final value = json.decode('$raw');
      if (value is List) return [for (final item in value) '$item'];
    } catch (_) {}
    return const [];
  }
}

/// Result of one scheduled match from the tracked team's perspective.
class TournamentMatchStats {
  const TournamentMatchStats({
    required this.match,
    required this.completed,
    required this.scoreFor,
    required this.scoreAgainst,
    this.result,
  });

  final TournamentMatch match;
  final bool completed;
  final int? scoreFor;
  final int? scoreAgainst;

  /// 'W', 'L', 'T', or null before completion.
  final String? result;
}

class TournamentTeamStats {
  int matches = 0;
  int wins = 0;
  int losses = 0;
  int ties = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;
  int teamFouls = 0;
  int timeOuts = 0;
  int challengesUsed = 0;
  int unsuccessfulChallenges = 0;
  int quizOuts = 0;

  int get differential => pointsFor - pointsAgainst;
  double get averagePoints => matches == 0 ? 0 : pointsFor / matches;
  double get winRate => matches == 0 ? 0 : wins / matches;
}

class TournamentMemberStats {
  TournamentMemberStats({required this.member});

  final TournamentMember member;
  int matches = 0;
  int points = 0;
  int correct = 0;
  int incorrect = 0;
  int fouls = 0;
  int quizOuts = 0;
  int strikeOuts = 0;
  int foulOuts = 0;

  double get averagePoints => matches == 0 ? 0 : points / matches;
  double get correctRate =>
      correct + incorrect == 0 ? 0 : correct / (correct + incorrect);
}

class TournamentStats {
  TournamentStats._({
    required this.team,
    required this.members,
    required this.matches,
  });

  final TournamentTeamStats team;
  final List<TournamentMemberStats> members;
  final List<TournamentMatchStats> matches;

  int get completedCount => matches.where((m) => m.completed).length;
  int get inProgressCount =>
      matches.where((m) => !m.completed && m.match.roundId != null).length;
  int get pendingCount =>
      matches.where((m) => m.match.roundId == null && m.match.isPending).length;

  static TournamentStats compute({
    required Tournament tournament,
    required List<TournamentMember> members,
    required List<TournamentMatch> matches,
    required List<TournamentRoundData> rounds,
    required Ruleset ruleset,
  }) {
    final byMatch = <int, TournamentRoundData>{
      for (final round in rounds) round.match.id: round,
    };
    final team = TournamentTeamStats();
    final memberStats = <int, TournamentMemberStats>{
      for (final member in members)
        member.id: TournamentMemberStats(member: member),
    };
    final matchStats = <TournamentMatchStats>[];

    for (final match in matches) {
      final round = byMatch[match.id];
      if (round == null || match.trackedSide == null) {
        matchStats.add(
          TournamentMatchStats(
            match: match,
            completed: false,
            scoreFor: null,
            scoreAgainst: null,
          ),
        );
        continue;
      }
      final view = round.toView(ruleset);
      final complete = _isComplete(view);
      final tracked = match.trackedSide!;
      final opponent = tracked == Side.red ? Side.green : Side.red;
      final forScore = view.scoreOf(tracked);
      final againstScore = view.scoreOf(opponent);
      String? result;
      if (complete) {
        result = forScore > againstScore
            ? 'W'
            : forScore < againstScore
            ? 'L'
            : 'T';
      }
      matchStats.add(
        TournamentMatchStats(
          match: match,
          completed: complete,
          scoreFor: forScore,
          scoreAgainst: againstScore,
          result: result,
        ),
      );

      if (!complete) continue;
      team.matches += 1;
      team.pointsFor += forScore;
      team.pointsAgainst += againstScore;
      switch (result) {
        case 'W':
          team.wins += 1;
        case 'L':
          team.losses += 1;
        case 'T':
          team.ties += 1;
      }
      final teamView = view.teamOf(tracked);
      team.teamFouls += teamView.teamFouls;
      team.timeOuts += teamView.timeOuts;
      team.challengesUsed += teamView.challengesUsed;
      team.unsuccessfulChallenges += teamView.unsuccessfulChallenges;

      for (final link in round.links) {
        if (link.side != tracked) continue;
        final stats = memberStats[link.memberId];
        if (stats == null) continue;
        final roster = view.teamOf(tracked).roster;
        if (link.rosterIndex < 0 || link.rosterIndex >= roster.length) {
          continue;
        }
        final quizzer = roster[link.rosterIndex];
        stats.matches += 1;
        stats.points += quizzer.score;
        stats.correct += quizzer.correct;
        stats.incorrect += quizzer.incorrect;
        stats.fouls += quizzer.fouls;
        if (quizzer.status == 'QUIZ-OUT') {
          stats.quizOuts += 1;
          team.quizOuts += 1;
        } else if (quizzer.status == 'STRIKE-OUT') {
          stats.strikeOuts += 1;
        } else if (quizzer.status == 'FOUL-OUT') {
          stats.foulOuts += 1;
        }
      }
    }

    return TournamentStats._(
      team: team,
      members: [for (final member in members) memberStats[member.id]!],
      matches: matchStats,
    );
  }

  /// A round has a result when every slot has at least one answer and the two
  /// teams are not tied. A tie leaves overtime pending, so it is not complete.
  static bool _isComplete(RoundView view) {
    final count = view.questionValues.length;
    if (count == 0) return false;
    for (var n = 1; n <= count; n++) {
      var answered = false;
      for (final side in Side.values) {
        for (final quizzer in view.teamOf(side).roster) {
          if (view.cellOutcome(side, quizzer.index, n) != null) {
            answered = true;
            break;
          }
        }
        if (answered) break;
      }
      if (!answered) return false;
    }
    return view.scoreOf(Side.red) != view.scoreOf(Side.green);
  }
}
