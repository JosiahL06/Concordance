import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app/round_controller.dart';
import '../engine/events.dart';

Future<void> exportPdf(RoundController c, BuildContext context) async {
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
                ['$n', '${c.currentValue(n)}', _notes(c, n)],
            ],
          ),
        ],
      ),
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/concordance-round.pdf');
  await file.writeAsBytes(await doc.save());
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Concordance round score sheet');
}

Future<void> exportCsv(RoundController c, BuildContext context) async {
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
      [n, c.currentValue(n), _notes(c, n)],
  ];
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/concordance-round.csv');
  await file.writeAsString(const ListToCsvConverter().convert(rows));
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Concordance round results');
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
