import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/tournament/tournament_models.dart';
import 'package:concordance/tournament/tournament_stats.dart';

Ruleset loadTbq() => Ruleset.fromJson(
  json.decode(File('assets/rulesets/tbq-25-26.json').readAsStringSync())
      as Map<String, Object?>,
);

Map<String, Object?> roundRow() => {
  'red_name': 'Team',
  'green_name': 'Opponent',
  'red_seats': json.encode(const ['Alice', 'Bob', 'Cara']),
  'green_seats': json.encode(const ['Opponent 1', 'Opponent 2', 'Opponent 3']),
  'red_bench': '[]',
  'green_bench': '[]',
};

List<RoundEvent> journal({required bool redWins}) {
  final events = <RoundEvent>[];
  for (var n = 1; n <= 20; n++) {
    events.add(QuestionValueEvent(questionNumber: n, value: 10));
    if (redWins) {
      if (n <= 15) {
        events.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: (n - 1) ~/ 5,
            correct: true,
          ),
        );
      } else {
        events.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
    } else {
      if (n <= 15) {
        events.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: (n - 1) ~/ 5,
            correct: true,
          ),
        );
      } else {
        events.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
    }
  }
  return events;
}

void main() {
  final ruleset = loadTbq();
  final tournament = Tournament(
    id: 1,
    name: 'T',
    rulesetId: 'tbq-25-26',
    matchCount: 3,
    teamName: 'Team',
    createdAt: DateTime.utc(2026, 11, 9),
  );
  final members = [
    TournamentMember(
      id: 1,
      tournamentId: 1,
      name: 'Alice',
      rosterIndex: 0,
      defaultSeat: 1,
    ),
    TournamentMember(
      id: 2,
      tournamentId: 1,
      name: 'Bob',
      rosterIndex: 1,
      defaultSeat: 2,
    ),
    TournamentMember(
      id: 3,
      tournamentId: 1,
      name: 'Cara',
      rosterIndex: 2,
      defaultSeat: 3,
    ),
  ];
  final links = [
    for (var i = 0; i < 3; i++)
      TournamentMemberLink(
        roundId: i + 1,
        side: Side.red,
        rosterIndex: i,
        memberId: i + 1,
      ),
  ];
  TournamentMatch match(int n, {int? roundId, String status = 'pending'}) =>
      TournamentMatch(
        id: n,
        tournamentId: 1,
        matchNumber: n,
        status: status,
        roundId: roundId,
        trackedSide: roundId == null ? null : Side.red,
      );

  test('aggregates completed matches from both sides of the record', () {
    final win = match(1, roundId: 1, status: 'completed');
    final loss = match(2, roundId: 2, status: 'completed');
    final pending = match(3);
    final rounds = [
      TournamentRoundData(
        match: win,
        roundRow: roundRow(),
        journal: journal(redWins: true),
        links: links,
      ),
      TournamentRoundData(
        match: loss,
        roundRow: roundRow(),
        journal: journal(redWins: false),
        links: links,
      ),
    ];

    final stats = TournamentStats.compute(
      tournament: tournament,
      members: members,
      matches: [win, loss, pending],
      rounds: rounds,
      ruleset: ruleset,
    );

    expect(stats.completedCount, 2);
    expect(stats.pendingCount, 1);
    expect(stats.inProgressCount, 0);
    expect(stats.team.matches, 2);
    expect(stats.team.wins, 1);
    expect(stats.team.losses, 1);
    expect(stats.team.ties, 0);
    expect(stats.team.quizOuts, 4);
    expect(stats.matches[0].result, 'W');
    expect(stats.matches[1].result, 'L');
    expect(
      stats.matches[0].scoreFor,
      greaterThan(stats.matches[0].scoreAgainst!),
    );

    expect(stats.members[0].matches, 2);
    expect(stats.members[0].correct, 10);
    expect(stats.members[0].quizOuts, 2);
    expect(stats.members[1].matches, 2);
    expect(stats.members[1].correct, 5);
    expect(stats.members[2].matches, 2);
    expect(stats.members[2].correct, 5);
    expect(stats.members[0].points, greaterThan(0));
  });

  test('an unfinished round stays out of the aggregate', () {
    final inProgress = match(1, roundId: 1, status: 'in_progress');
    final rounds = [
      TournamentRoundData(
        match: inProgress,
        roundRow: roundRow(),
        journal: [
          const QuestionValueEvent(questionNumber: 1, value: 10),
          const AnswerEvent(
            questionNumber: 1,
            side: Side.red,
            quizzerIndex: 0,
            correct: true,
          ),
        ],
        links: links,
      ),
    ];
    final stats = TournamentStats.compute(
      tournament: tournament,
      members: members,
      matches: [inProgress],
      rounds: rounds,
      ruleset: ruleset,
    );
    expect(stats.completedCount, 0);
    expect(stats.inProgressCount, 1);
    expect(stats.team.matches, 0);
    expect(stats.members.every((m) => m.matches == 0), isTrue);
  });
}
