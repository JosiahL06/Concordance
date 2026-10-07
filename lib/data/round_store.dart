import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../engine/events.dart';

/// SQLite autosave: rounds + journal rows (event JSON). Save on every event;
/// resume re-folds the journal. sqlite3 direct (no codegen) — the journal is
/// append-only JSON and needs no ORM.
class RoundStore {
  RoundStore._(this._db);

  final Database _db;

  static Future<RoundStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'concordance.db'));
    final db = sqlite3.open(file.path);
    _createTables(db);
    return RoundStore._(db);
  }

  /// In-memory store for tests (no path_provider / platform channels).
  static RoundStore inMemory() {
    final db = sqlite3.openInMemory();
    _createTables(db);
    return RoundStore._(db);
  }

  static void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS rounds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ruleset_id TEXT NOT NULL,
        red_name TEXT NOT NULL,
        green_name TEXT NOT NULL,
        red_seats TEXT NOT NULL,
        green_seats TEXT NOT NULL,
        red_bench TEXT NOT NULL DEFAULT '[]',
        green_bench TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        round_id INTEGER NOT NULL REFERENCES rounds(id),
        seq INTEGER NOT NULL,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (round_id, seq)
      );
    ''');
    _ensureBenchColumns(db);
  }

  /// Adds the bench columns to a database created before benches existed, so a
  /// saved round from an older build still opens.
  static void _ensureBenchColumns(Database db) {
    final cols = <String>{
      for (final r in db.select('PRAGMA table_info(rounds)'))
        r['name'] as String,
    };
    if (!cols.contains('red_bench')) {
      db.execute(
        "ALTER TABLE rounds ADD COLUMN red_bench TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (!cols.contains('green_bench')) {
      db.execute(
        "ALTER TABLE rounds ADD COLUMN green_bench TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  int createRound({
    required String rulesetId,
    required String redName,
    required String greenName,
    required List<String> redSeats,
    required List<String> greenSeats,
    List<String> redBench = const <String>[],
    List<String> greenBench = const <String>[],
  }) {
    _db.execute(
      'INSERT INTO rounds (ruleset_id, red_name, green_name, red_seats, green_seats, red_bench, green_bench, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        rulesetId,
        redName,
        greenName,
        json.encode(redSeats),
        json.encode(greenSeats),
        json.encode(redBench),
        json.encode(greenBench),
        DateTime.now().toIso8601String(),
      ],
    );
    return _db.lastInsertRowId;
  }

  void appendEvent(int roundId, RoundEvent event) {
    final seq =
        _db.select(
              'SELECT COALESCE(MAX(seq), -1) + 1 AS next FROM events WHERE round_id = ?',
              [roundId],
            ).first['next']
            as int;
    _db.execute(
      'INSERT INTO events (round_id, seq, type, payload) VALUES (?, ?, ?, ?)',
      [roundId, seq, event.runtimeType.toString(), json.encode(_encode(event))],
    );
  }

  void truncateTo(int roundId, int length) {
    _db.execute('DELETE FROM events WHERE round_id = ? AND seq >= ?', [
      roundId,
      length,
    ]);
  }

  List<Map<String, Object?>> listRounds() {
    return _db.select('SELECT * FROM rounds ORDER BY id DESC').toList();
  }

  Map<String, Object?>? loadRound(int id) {
    final rows = _db.select('SELECT * FROM rounds WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  List<RoundEvent> loadJournal(int roundId) {
    final rows = _db.select(
      'SELECT type, payload FROM events WHERE round_id = ? ORDER BY seq',
      [roundId],
    );
    return [
      for (final r in rows)
        _decode(
          r['type'] as String,
          json.decode(r['payload'] as String) as Map<String, Object?>,
        ),
    ];
  }

  void deleteRound(int id) {
    _db.execute('DELETE FROM events WHERE round_id = ?', [id]);
    _db.execute('DELETE FROM rounds WHERE id = ?', [id]);
  }

  void close() => _db.dispose();

  static Map<String, Object?> _encode(RoundEvent e) => switch (e) {
    AnswerEvent(
      questionNumber: var q,
      side: var s,
      quizzerIndex: var i,
      correct: var c,
    ) =>
      {'q': q, 'side': s.name, 'index': i, 'correct': c},
    FoulEvent(questionNumber: var q, side: var s, quizzerIndex: var i) => {
      'q': q,
      'side': s.name,
      'index': i,
    },
    TimeOutEvent(side: var s) => {'side': s.name},
    InterruptionEvent(questionNumber: var q) => {'q': q},
    ChallengeEvent(questionNumber: var q, side: var s, successful: var ok) => {
      'q': q,
      'side': s.name,
      'successful': ok,
    },
    VoidQuestionEvent(questionNumber: var q) => {'q': q},
    QuestionValueEvent(questionNumber: var q, value: var v) => {
      'q': q,
      'value': v,
    },
    SubstituteQuestionEvent(questionNumber: var q, value: var v) => {
      'q': q,
      'value': v,
    },
    SubstituteQuizzerEvent(side: var s, outIndex: var o, benchIndex: var b) => {
      'side': s.name,
      'out': o,
      'bench': b,
    },
    OvertimeQuestionEvent(value: var v) => {'value': v},
  };

  static RoundEvent _decode(String type, Map<String, Object?> m) {
    Side side(Object? v) => Side.values.byName(v as String);
    return switch (type) {
      'AnswerEvent' => AnswerEvent(
        questionNumber: m['q'] as int,
        side: side(m['side']),
        quizzerIndex: m['index'] as int,
        correct: m['correct'] as bool,
      ),
      'FoulEvent' => FoulEvent(
        questionNumber: m['q'] as int?,
        side: side(m['side']),
        quizzerIndex: m['index'] as int?,
      ),
      'TimeOutEvent' => TimeOutEvent(side: side(m['side'])),
      'InterruptionEvent' => InterruptionEvent(questionNumber: m['q'] as int),
      'ChallengeEvent' => ChallengeEvent(
        questionNumber: m['q'] as int,
        side: side(m['side']),
        successful: m['successful'] as bool,
      ),
      'VoidQuestionEvent' => VoidQuestionEvent(questionNumber: m['q'] as int),
      'QuestionValueEvent' => QuestionValueEvent(
        questionNumber: m['q'] as int,
        value: m['value'] as int,
      ),
      'SubstituteQuestionEvent' => SubstituteQuestionEvent(
        questionNumber: m['q'] as int,
        value: m['value'] as int,
      ),
      'SubstituteQuizzerEvent' => SubstituteQuizzerEvent(
        side: side(m['side']),
        outIndex: m['out'] as int,
        benchIndex: m['bench'] as int,
      ),
      'OvertimeQuestionEvent' => OvertimeQuestionEvent(
        value: m['value'] as int,
      ),
      _ => throw StateError('unknown event type $type'),
    };
  }
}
