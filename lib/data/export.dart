import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app/round_controller.dart';
import '../engine/events.dart';
import 'export_share.dart';

Future<ExportOutcome> exportPdf(RoundController c) async {
  final doc = pw.Document();
  final red = c.scoreOf(Side.red);
  final green = c.scoreOf(Side.green);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Concordance - Round Score Sheet',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('${c.ruleset.displayName} ${c.ruleset.season}'),
          pw.SizedBox(height: 8),
          pw.Text(
            '${c.redName} $red - $green ${c.greenName}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          for (final side in Side.values)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  side == Side.red ? c.redName : c.greenName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.TableHelper.fromTextArray(
                  // Every roster quizzer is listed (seated and benched) so a
                  // rotated-out quizzer's points are not lost from the sheet.
                  headers: const [
                    'Quizzer',
                    'Position',
                    'Score',
                    'C',
                    'I',
                    'F',
                    'Status',
                  ],
                  data: [
                    for (final q in c.teamOf(side).roster)
                      [
                        q.label,
                        q.onBench ? 'bench' : 'seat ${q.seat}',
                        '${q.score}',
                        '${q.correct}',
                        '${q.incorrect}',
                        '${q.fouls}',
                        q.status,
                      ],
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          pw.Text('Question-by-question:'),
          pw.TableHelper.fromTextArray(
            headers: const ['Q', 'Value', 'Outcome'],
            data: [
              for (var n = 1; n <= c.questionCount; n++)
                ['$n', c.currentValue(n)?.toString() ?? '-', _notes(c, n)],
            ],
          ),
        ],
      ),
    ),
  );
  return shareOrSaveFile(
    bytes: await doc.save(),
    fileName: 'concordance-round.pdf',
    mimeType: 'application/pdf',
    shareText: 'Concordance round score sheet',
    typeLabel: 'PDF',
    extension: 'pdf',
  );
}

Future<ExportOutcome> exportCsv(RoundController c) async {
  final rows = <List<Object>>[
    const [
      'quizzer',
      'position',
      'team',
      'score',
      'correct',
      'incorrect',
      'fouls',
      'status',
    ],
    for (final side in Side.values)
      for (final q in c.teamOf(side).roster)
        [
          q.label,
          q.onBench ? 'bench' : 'seat ${q.seat}',
          side.name,
          q.score,
          q.correct,
          q.incorrect,
          q.fouls,
          q.status,
        ],
    const [],
    const ['question', 'value', 'outcome'],
    for (var n = 1; n <= c.questionCount; n++)
      [n, c.currentValue(n) ?? '-', _notes(c, n)],
  ];
  return shareOrSaveFile(
    bytes: utf8.encode(const ListToCsvConverter().convert(rows)),
    fileName: 'concordance-round.csv',
    mimeType: 'text/csv',
    shareText: 'Concordance round results',
    typeLabel: 'CSV',
    extension: 'csv',
  );
}

String _notes(RoundController c, int n) {
  final parts = <String>[];
  for (final side in Side.values) {
    final team = c.teamOf(side);
    for (final q in team.roster) {
      final mark = c.cellOutcome(side, q.index, n);
      if (mark != null) {
        parts.add('${q.label}: $mark');
      }
      if (c.cellHasFoul(side, q.index, n)) {
        parts.add('${q.label}: foul');
      }
    }
  }
  return parts.isEmpty ? '-' : parts.join('; ');
}
