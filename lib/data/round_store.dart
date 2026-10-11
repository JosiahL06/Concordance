import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../engine/events.dart';

/// SQLite autosave: rounds + journal rows (event JSON). Save on every event;
/// resume re-folds the journal. sqlite3 direct (no codegen) — the journal is
/// append-only JSON and needs no ORM.
///
/// Writes are **delta** writes inside a single transaction ([saveJournal]): a
/// scoring tap appends one row, an undo deletes one row, and no path ever
/// rewrites the whole round. A kill mid-write therefore leaves either the old or
/// the new journal on disk, never a gap (locked decision 4).
///
/// Durability is configured at open (see [_configureJournal]): WAL plus
/// `synchronous = NORMAL`, so a tap costs one sequential append rather than the
/// several fsyncs the rollback-journal defaults charged — autosave runs on the
/// UI isolate, so that cost was landing on every tap. Foreign keys are enforced
/// (see [_enableForeignKeys]), which is what makes the `events.round_id`
/// reference in [_createTables] real rather than decorative.
class RoundStore {
  RoundStore._(this._db);

  final Database _db;

  /// The schema version this build expects. Bump together with [_migrations].
  static const int schemaVersion = 3;

  static Future<RoundStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return openAt(File(p.join(dir.path, 'concordance.db')).path);
  }

  /// Opens (or creates) the database at [path]. Split out from [open] so tests
  /// (and desktop tooling) can name a file.
  static RoundStore openAt(String path) {
    final db = sqlite3.open(path);
    final store = RoundStore._(db);
    try {
      store._init(persistent: true);
    } catch (_) {
      // An open that refuses to proceed (a database from a newer build, or a
      // migration that threw) must not leave the file handle open.
      db.dispose();
      rethrow;
    }
    return store;
  }

  /// In-memory store for tests (no path_provider / platform channels).
  static RoundStore inMemory() {
    final store = RoundStore._(sqlite3.openInMemory());
    store._init(persistent: false);
    return store;
  }

  /// Shared open path.
  ///
  /// The version guard runs first, before anything is written: a database this
  /// build does not understand must not be modified on the way to refusing it.
  ///
  /// Order matters in two further ways. `auto_vacuum` is only honoured while the
  /// database is still empty, so it is configured before any table exists, and
  /// migrations run once the tables do.
  ///
  /// Foreign keys are switched on only *after* migrations. SQLite's documented
  /// table-rebuild procedure requires enforcement to be **off** while a table is
  /// rebuilt, and `PRAGMA foreign_keys` is a no-op inside a transaction — so it
  /// cannot be toggled per migration when each migration runs as one
  /// transaction. Enabling it last makes a migration-time rebuild correct by
  /// construction rather than by remembering to toggle.
  ///
  /// [persistent] is false for in-memory stores, which have no file to reclaim
  /// and no WAL to keep.
  void _init({required bool persistent}) {
    _refuseIfNewer();
    if (persistent) {
      _configureAutoVacuum();
      _configureJournal();
    }
    _createTables(_db);
    _enableForeignKeys(verify: _migrate());
  }

  /// Throws when the file was written by a newer build, before *any* write to
  /// it. `user_version` is a header field, so this is safe to read on a file
  /// whose tables we have not created or migrated yet.
  void _refuseIfNewer() {
    final from = _db.userVersion;
    if (from > schemaVersion) {
      throw StateError(
        'concordance.db is at schema v$from but this build only knows '
        'v$schemaVersion — it was written by a newer version of Concordance.',
      );
    }
  }

  /// The `PRAGMA user_version` recorded in the open database.
  int get storedSchemaVersion => _db.userVersion;

  /// Reads a single-value integer `PRAGMA` through this store's own connection.
  ///
  /// Exists because the per-connection settings — `synchronous`, `busy_timeout`,
  /// `foreign_keys` — are invisible to any *other* connection, so a test cannot
  /// read them back through a second handle the way it can with `journal_mode`
  /// or `auto_vacuum`. Also useful for on-device diagnostics.
  ///
  /// The pragma name is interpolated (SQLite takes no bound parameter there), so
  /// never pass anything user-supplied.
  int pragmaInt(String pragma) =>
      _db.select('PRAGMA $pragma').first.columnAt(0) as int;

  /// 0 = NONE — the default, and what every build before this one left behind.
  static const int _autoVacuumNone = 0;

  /// 2 = INCREMENTAL: freed pages go on a free list that [reclaimSpace] hands
  /// back to the OS, instead of the file growing forever.
  static const int _autoVacuumIncremental = 2;

  /// Switches a NONE database to INCREMENTAL. A no-op on every open after the
  /// first, and it never touches a database that already reclaims.
  void _configureAutoVacuum() {
    final mode = _db.select('PRAGMA auto_vacuum').first.columnAt(0) as int;
    if (mode != _autoVacuumNone) return;
    _db.execute('PRAGMA auto_vacuum = $_autoVacuumIncremental');
    // `auto_vacuum` is normally only honoured at creation time, so a database
    // that already has tables needs a `VACUUM` to rewrite it. Free on the empty
    // file a fresh install starts from, and one-time for a pre-existing one.
    _db.execute('VACUUM');
  }

  /// 1 = NORMAL. The WAL is written on commit but not fsynced until a
  /// checkpoint, which keeps the flash off the hot path. Survives app kill and
  /// process crash — what locked decision 4 actually requires — so only power
  /// loss or an OS-level crash can drop the most recent commits. Set to 2 (FULL)
  /// to close that window at the cost of an fsync on every tap.
  static const int _synchronousNormal = 1;

  /// How long a writer waits on a competing lock before giving up. The default
  /// (0) fails instantly with SQLITE_BUSY, which is the wrong trade for a
  /// scorekeeper: waiting a moment is always better than losing a tap.
  static const int _busyTimeoutMs = 5000;

  /// Durability and concurrency settings for a file-backed database.
  ///
  /// WAL replaces the rollback journal's per-commit rewrite of the main file
  /// with a single sequential append. That matters here specifically because
  /// autosave runs on the UI isolate on every scoring tap, so the old
  /// `journal_mode = delete` + `synchronous = FULL` default paid several fsyncs
  /// per tap on the app's hottest interaction.
  ///
  /// Only `journal_mode` is stored in the file header; the rest are
  /// per-connection, so all three are re-applied on every open.
  void _configureJournal() {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = $_synchronousNormal');
    _db.execute('PRAGMA busy_timeout = $_busyTimeoutMs');
  }

  /// Turns on foreign-key enforcement for the rest of this connection's life,
  /// making `events.round_id REFERENCES rounds(id)` real rather than a comment.
  ///
  /// When [verify] is set (a migration actually ran) this also runs
  /// `PRAGMA foreign_key_check`, the post-rebuild validation SQLite's
  /// table-rebuild procedure requires, and refuses to open if the migration left
  /// an orphan behind. Our write paths cannot produce one — events are only ever
  /// written for a round that exists, and [deleteRound] removes the children —
  /// so this is a tripwire for a bad migration, not an expected state. Refusing
  /// is safe because the home screen already renders an open failure.
  void _enableForeignKeys({required bool verify}) {
    _db.execute('PRAGMA foreign_keys = ON');
    if (!verify) return;
    final orphans = _db.select('PRAGMA foreign_key_check').toList();
    if (orphans.isNotEmpty) {
      throw StateError(
        'concordance.db has ${orphans.length} orphaned row(s) after migration; '
        'refusing to open with foreign keys enabled.',
      );
    }
  }

  /// Returns pages freed by deleted rows to the OS. Outside any transaction
  /// (SQLite ignores it inside one) and only after bulk deletes — never on the
  /// per-tap path, where freeing a single row is not worth the I/O.
  void reclaimSpace() => _db.execute('PRAGMA incremental_vacuum');

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
        round_id INTEGER NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
        seq INTEGER NOT NULL,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (round_id, seq)
      ) WITHOUT ROWID;
    ''');
  }

  /// Applies every migration newer than [storedSchemaVersion], one transaction
  /// each, stamping `user_version` as it goes — so a database interrupted
  /// part-way through an upgrade resumes at the last completed step instead of
  /// re-running migrations that already applied.
  ///
  /// Returns whether any step ran. The caller uses that to decide whether the
  /// schema it is about to trust was just rewritten, and therefore whether the
  /// post-migration integrity check is worth running.
  bool _migrate() {
    // The newer-build guard lives in [_refuseIfNewer], which runs before any
    // write, so this only has to walk forward from wherever the file is.
    final from = _db.userVersion;
    for (var v = from; v < schemaVersion; v++) {
      transaction(() {
        _migrations[v](_db);
        // PRAGMA cannot take a bound parameter; v + 1 is an int from code.
        _db.execute('PRAGMA user_version = ${v + 1}');
      });
    }
    return schemaVersion > from;
  }

  /// `_migrations[i]` upgrades schema version `i` to `i + 1`.
  ///
  /// Version 0 is ambiguous — it is both a fresh database and one written before
  /// versioning existed (v1.0.0-beta) — so every migration must be a **no-op
  /// when its change is already present**. That is the reconciling shape
  /// EZScore's `EnsureTableHasSchema` uses, and why migration 1 reads `PRAGMA
  /// table_info` rather than assuming the columns are absent. A fresh install
  /// therefore runs it and finds nothing to do.
  static final List<void Function(Database)> _migrations =
      <void Function(Database)>[
        _addBenchColumns,
        _rebuildEventsWithoutRowid,
        _normalizeCreatedAtToUtc,
      ];

  /// v0 → v1: the bench roster columns, so a round saved by an older build still
  /// opens.
  static void _addBenchColumns(Database db) {
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

  /// v1 → v2: `events` becomes a `WITHOUT ROWID` table whose rows cascade from
  /// their round.
  ///
  /// `PRIMARY KEY (round_id, seq)` is not an INTEGER PRIMARY KEY, so SQLite
  /// stores the table as an ordinary rowid B-tree **plus** a separate
  /// `sqlite_autoindex` B-tree for the key — every event written to two B-trees,
  /// with the key stored twice. `WITHOUT ROWID` keeps exactly one B-tree keyed
  /// by `(round_id, seq)`, which is precisely how the journal is read
  /// (`WHERE round_id = ? ORDER BY seq` — one contiguous range scan).
  ///
  /// `ON DELETE CASCADE` then lets [deleteRound] be a single statement.
  ///
  /// This is a rebuild rather than an `ALTER`: SQLite cannot change a table's
  /// rowid-ness, or its key, in place. The recreate/copy/drop/rename sequence is
  /// SQLite's documented table-rebuild procedure, and it is correct here because
  /// [_init] runs migrations with foreign keys **off** (see the ordering note
  /// there) — the condition that procedure requires. `withoutRowid` detection
  /// keeps this a no-op on a fresh database, which [_createTables] already
  /// creates in the new shape.
  static void _rebuildEventsWithoutRowid(Database db) {
    final existing =
        db
                .select(
                  "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'events'",
                )
                .first['sql']
            as String?;
    if (existing != null && existing.contains('WITHOUT ROWID')) return;

    db.execute('''
      CREATE TABLE events_rebuilt (
        round_id INTEGER NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
        seq INTEGER NOT NULL,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (round_id, seq)
      ) WITHOUT ROWID;
    ''');
    // Copy the journal verbatim, `seq` included, so resume re-folds identically.
    db.execute(
      'INSERT INTO events_rebuilt (round_id, seq, type, payload) '
      'SELECT round_id, seq, type, payload FROM events',
    );
    db.execute('DROP TABLE events');
    db.execute('ALTER TABLE events_rebuilt RENAME TO events');
  }

  /// v2 → v3: `created_at` becomes an unambiguous UTC timestamp.
  ///
  /// Earlier builds wrote `DateTime.now().toIso8601String()` — local time with
  /// **no** offset, e.g. `2026-10-10T14:23:45.123456`. A naive timestamp is not
  /// comparable across devices and silently changes meaning when the device's
  /// zone or DST changes, so new rows are written as UTC with a `Z` suffix
  /// (see [createRound]) and this normalises what is already stored.
  ///
  /// The normalisation **interprets** the stored local time as UTC rather than
  /// converting it, because the offset it was written in was never recorded and
  /// cannot be recovered. That shift is accepted deliberately: it is confined to
  /// pre-1.0 rounds, `created_at` is only ever displayed, and the alternative —
  /// leaving ambiguous values in place — makes the ambiguity permanent.
  static void _normalizeCreatedAtToUtc(Database db) {
    db.execute(
      "UPDATE rounds SET created_at = created_at || 'Z' "
      "WHERE created_at NOT LIKE '%Z'",
    );
  }

  /// Runs [body] inside one `BEGIN IMMEDIATE` transaction: committed on
  /// success, rolled back if [body] throws. Every multi-row write goes through
  /// here, which is what makes autosave atomic (locked decision 4).
  T transaction<T>(T Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Persists [journal] for [roundId], writing only the difference from
  /// [persistedCount], and returns the number of events now on disk.
  ///
  /// The journal only ever grows by one event or shrinks by the tail (undo), so
  /// the delta is "append the new suffix" or "delete the removed tail" — never
  /// the whole round. Both paths run in one transaction, so a mid-save kill
  /// leaves the previous journal intact instead of a half-written one. A no-op
  /// save (nothing changed) writes nothing at all.
  ///
  /// Callers keep the returned count and pass it back on the next save.
  int saveJournal(int roundId, List<RoundEvent> journal, int persistedCount) {
    if (journal.length == persistedCount) return persistedCount;
    transaction(() {
      if (journal.length < persistedCount) {
        truncateTo(roundId, journal.length);
      } else {
        _appendRange(roundId, journal, persistedCount);
      }
    });
    return journal.length;
  }

  /// Inserts `journal[startSeq..]` with explicit `seq` values through one
  /// prepared statement — no per-row `MAX(seq)` scan.
  void _appendRange(int roundId, List<RoundEvent> journal, int startSeq) {
    final stmt = _db.prepare(
      'INSERT INTO events (round_id, seq, type, payload) VALUES (?, ?, ?, ?)',
    );
    try {
      for (var seq = startSeq; seq < journal.length; seq++) {
        final e = journal[seq];
        stmt.execute([
          roundId,
          seq,
          e.runtimeType.toString(),
          json.encode(_encode(e)),
        ]);
      }
    } finally {
      stmt.dispose();
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
        // UTC with a `Z` suffix: a local-naive timestamp is ambiguous across
        // devices and across a DST change (migration 3 normalised the old ones).
        DateTime.now().toUtc().toIso8601String(),
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

  /// Deletes the round and its journal. `events` carries `ON DELETE CASCADE`
  /// (migration 2) and foreign keys are enforced, so one statement removes both.
  /// The pages that frees are handed back to the OS straight away — this is the
  /// one bulk-free path, and the user is not mid-match when they use it.
  void deleteRound(int id) {
    transaction(() => _db.execute('DELETE FROM rounds WHERE id = ?', [id]));
    // Outside the transaction: SQLite ignores `incremental_vacuum` inside one.
    reclaimSpace();
  }

  /// Closes the database. `PRAGMA optimize` is SQLite's recommended
  /// end-of-connection step: it refreshes planner statistics once they have gone
  /// stale and is a no-op when there is nothing to do. Closing the last
  /// connection also checkpoints and removes the WAL.
  void close() {
    _db.execute('PRAGMA optimize');
    _db.dispose();
  }

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
