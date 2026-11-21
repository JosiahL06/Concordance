import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/data/tournament_export.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/tournament/tournament_models.dart';
import 'package:concordance/tournament/tournament_stats.dart';

Ruleset loadTbq() => Ruleset.fromJson(
  json.decode(File('assets/rulesets/tbq-25-26.json').readAsStringSync())
      as Map<String, Object?>,
);

void main() {
  test(
    'CSV and PDF builders include tournament, match, and individual data',
    () async {
      final ruleset = loadTbq();
      final tournament = Tournament(
        id: 1,
        name: 'Fall Invitational',
        rulesetId: 'tbq-25-26',
        matchCount: 1,
        teamName: 'Team',
        createdAt: DateTime.utc(2026, 11, 12),
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
      final match = TournamentMatch(
        id: 1,
        tournamentId: 1,
        matchNumber: 1,
        status: TournamentMatchStatus.completed,
        roundId: 1,
        trackedSide: Side.red,
        opponentName: 'Rivals',
      );
      final journal = <RoundEvent>[];
      for (var n = 1; n <= 20; n++) {
        journal.add(QuestionValueEvent(questionNumber: n, value: 10));
        if (n <= 15) {
          journal.add(
            AnswerEvent(
              questionNumber: n,
              side: Side.red,
              quizzerIndex: (n - 1) ~/ 5,
              correct: true,
            ),
          );
        } else {
          journal.add(
            AnswerEvent(
              questionNumber: n,
              side: Side.green,
              quizzerIndex: 0,
              correct: true,
            ),
          );
        }
      }
      final stats = TournamentStats.compute(
        tournament: tournament,
        members: members,
        matches: [match],
        rounds: [
          TournamentRoundData(
            match: match,
            roundRow: {
              'red_seats': json.encode(const ['Alice', 'Bob', 'Cara']),
              'green_seats': json.encode(const ['R1', 'R2', 'R3']),
              'red_bench': '[]',
              'green_bench': '[]',
            },
            journal: journal,
            links: [
              for (var i = 0; i < 3; i++)
                TournamentMemberLink(
                  roundId: 1,
                  side: Side.red,
                  rosterIndex: i,
                  memberId: i + 1,
                ),
            ],
          ),
        ],
        ruleset: ruleset,
      );

      final csv = tournamentCsv(tournament, ruleset, stats);
      expect(csv, contains('tournament,Fall Invitational'));
      expect(csv, contains('team,Team'));
      expect(csv, contains('wins,1'));
      expect(csv, contains('match,opponent,side,result,status'));
      expect(csv, contains('1,Rivals,red,W,complete'));
      expect(csv, contains('quizzer,matches,points'));
      expect(csv, contains('Alice,1,'));

      final pdf = await tournamentPdfDocument(
        tournament,
        ruleset,
        stats,
      ).save();
      expect(pdf, isNotEmpty);
    },
  );
}
