import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../engine/ruleset.dart';
import '../tournament/tournament_models.dart';
import '../tournament/tournament_stats.dart';
import 'export_share.dart';

/// Shares the tournament's aggregate results as a printable PDF.
Future<ExportOutcome> exportTournamentPdf(
  Tournament tournament,
  Ruleset ruleset,
  TournamentStats stats,
) async {
  return shareOrSaveFile(
    bytes: await tournamentPdfDocument(tournament, ruleset, stats).save(),
    fileName: 'concordance-tournament.pdf',
    mimeType: 'application/pdf',
    shareText: 'Concordance tournament results - ${tournament.name}',
    typeLabel: 'PDF',
    extension: 'pdf',
  );
}

/// Builds the PDF without writing or sharing it (unit-testable).
pw.Document tournamentPdfDocument(
  Tournament tournament,
  Ruleset ruleset,
  TournamentStats stats,
) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => [
        pw.Text(
          'Concordance - Tournament Results',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${tournament.name} - ${tournament.teamName}',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('${ruleset.displayName} ${ruleset.season}'),
        pw.SizedBox(height: 10),
        pw.Text(
          '${stats.completedCount} of ${tournament.matchCount} matches complete | '
          'Record ${stats.team.wins}-${stats.team.losses}-${stats.team.ties} | '
          'Points ${stats.team.pointsFor} for / '
          '${stats.team.pointsAgainst} against',
          style: pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 16),
        _section('Match results'),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Match',
            'Opponent',
            'Side',
            'Result',
            'Status',
            'Score',
          ],
          data: [
            for (final match in stats.matches)
              [
                '${match.match.matchNumber}',
                match.match.opponentName ?? 'TBD',
                match.match.trackedSide?.name.toUpperCase() ?? '-',
                match.result ?? '-',
                _status(match),
                match.completed
                    ? '${match.scoreFor}-${match.scoreAgainst}'
                    : '-',
              ],
          ],
        ),
        pw.SizedBox(height: 16),
        _section('Team totals'),
        pw.TableHelper.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: [
            ['Matches played', '${stats.team.matches}'],
            [
              'Record',
              '${stats.team.wins}-${stats.team.losses}-${stats.team.ties}',
            ],
            ['Points for', '${stats.team.pointsFor}'],
            ['Points against', '${stats.team.pointsAgainst}'],
            ['Differential', '${stats.team.differential}'],
            ['Average points', stats.team.averagePoints.toStringAsFixed(1)],
            ['Quiz-outs', '${stats.team.quizOuts}'],
            ['Team fouls', '${stats.team.teamFouls}'],
            ['Time-outs', '${stats.team.timeOuts}'],
            ['Contests / appeals', '${stats.team.challengesUsed}'],
          ],
        ),
        pw.SizedBox(height: 16),
        _section('Individual totals'),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Quizzer',
            'M',
            'PTS',
            'C',
            'I',
            'F',
            'QO',
            'SO',
            'FO',
            'AVG',
          ],
          data: [
            for (final member in stats.members)
              [
                member.member.name,
                '${member.matches}',
                '${member.points}',
                '${member.correct}',
                '${member.incorrect}',
                '${member.fouls}',
                '${member.quizOuts}',
                '${member.strikeOuts}',
                '${member.foulOuts}',
                member.averagePoints.toStringAsFixed(1),
              ],
          ],
        ),
      ],
    ),
  );
  return doc;
}

/// Shares the same tournament data as a spreadsheet-friendly CSV.
Future<ExportOutcome> exportTournamentCsv(
  Tournament tournament,
  Ruleset ruleset,
  TournamentStats stats,
) async {
  return shareOrSaveFile(
    bytes: utf8.encode(tournamentCsv(tournament, ruleset, stats)),
    fileName: 'concordance-tournament.csv',
    mimeType: 'text/csv',
    shareText: 'Concordance tournament results - ${tournament.name}',
    typeLabel: 'CSV',
    extension: 'csv',
  );
}

/// Builds the CSV without writing or sharing it (unit-testable).
String tournamentCsv(
  Tournament tournament,
  Ruleset ruleset,
  TournamentStats stats,
) {
  final rows = <List<Object>>[
    ['tournament', tournament.name],
    ['team', tournament.teamName],
    ['ruleset', '${ruleset.displayName} ${ruleset.season}'],
    ['matches_complete', stats.completedCount],
    ['matches_total', tournament.matchCount],
    ['wins', stats.team.wins],
    ['losses', stats.team.losses],
    ['ties', stats.team.ties],
    ['points_for', stats.team.pointsFor],
    ['points_against', stats.team.pointsAgainst],
    ['differential', stats.team.differential],
    ['average_points', stats.team.averagePoints.toStringAsFixed(1)],
    ['quiz_outs', stats.team.quizOuts],
    ['team_fouls', stats.team.teamFouls],
    ['time_outs', stats.team.timeOuts],
    ['contests', stats.team.challengesUsed],
    const [],
    const [
      'match',
      'opponent',
      'side',
      'result',
      'status',
      'score_for',
      'score_against',
    ],
    for (final match in stats.matches)
      [
        match.match.matchNumber,
        match.match.opponentName ?? 'TBD',
        match.match.trackedSide?.name ?? '-',
        match.result ?? '',
        _status(match),
        match.completed ? match.scoreFor ?? '' : '',
        match.completed ? match.scoreAgainst ?? '' : '',
      ],
    const [],
    const [
      'quizzer',
      'matches',
      'points',
      'correct',
      'incorrect',
      'fouls',
      'quiz_outs',
      'strike_outs',
      'foul_outs',
      'average_points',
    ],
    for (final member in stats.members)
      [
        member.member.name,
        member.matches,
        member.points,
        member.correct,
        member.incorrect,
        member.fouls,
        member.quizOuts,
        member.strikeOuts,
        member.foulOuts,
        member.averagePoints.toStringAsFixed(1),
      ],
  ];
  return const ListToCsvConverter().convert(rows);
}

pw.Widget _section(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(
    title,
    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
  ),
);

String _status(TournamentMatchStats match) {
  if (match.completed) return 'complete';
  if (match.match.roundId != null) return 'in progress';
  return 'not started';
}
