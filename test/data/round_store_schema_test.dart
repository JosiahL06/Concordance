// Open-time configuration, schema evolution, versioned migrations and space
// reclamation. The journal contract itself (delta writes, round-trips) lives in
// round_store_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:concordance/app/timestamps.dart';
import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/events.dart';

/// Reads a single-value PRAGMA over a separate connection, so a test can observe
/// what is actually on disk rather than what the store believes.
int pragmaInt(String path, String pragma) {
  final db = sqlite3.open(path);
  try {
    return db.select('PRAGMA $pragma').first.columnAt(0) as int;
  } finally {
    db.dispose();
  }
}

/// Text-valued counterpart to [pragmaInt] (`journal_mode` answers 'wal').
String pragmaText(String path, String pragma) {
  final db = sqlite3.open(path);
  try {
    return db.select('PRAGMA $pragma').first.columnAt(0) as String;
  } finally {
    db.dispose();
  }
}

/// Writes a v0 database: the schema as it shipped before versioning existed —
/// no `red_bench`/`green_bench` columns, and `user_version` left at 0.
void writeLegacyDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE rounds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ruleset_id TEXT NOT NULL,
      red_name TEXT NOT NULL,
      green_name TEXT NOT NULL,
      red_seats TEXT NOT NULL,
      green_seats TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE events (
      round_id INTEGER NOT NULL REFERENCES rounds(id),
      seq INTEGER NOT NULL,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      PRIMARY KEY (round_id, seq)
    );
  ''');
  db.execute(
    "INSERT INTO rounds (ruleset_id, red_name, green_name, red_seats, "
    "green_seats, created_at) VALUES ('tbq-25-26', 'Legacy Red', "
    "'Legacy Green', '[\"Red 1\"]', '[\"Green 1\"]', "
    "'2026-01-01T00:00:00.000')",
  );
  db.dispose();
}

int newRound(RoundStore store) => store.createRound(
  rulesetId: 'tbq-25-26',
  redName: 'Red',
  greenName: 'Green',
  redSeats: const ['Red 1', 'Red 2'],
  greenSeats: const ['Green 1', 'Green 2'],
);

/// Writes a v1 database: the shape that shipped before the `events` rebuild —
/// an ordinary rowid `events` table with no cascade — plus a two-event journal,
/// so a migration can be shown to preserve what was already stored.
void writeVersionOneDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE rounds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ruleset_id TEXT NOT NULL,
      red_name TEXT NOT NULL,
      green_name TEXT NOT NULL,
      red_seats TEXT NOT NULL,
      green_seats TEXT NOT NULL,
      red_bench TEXT NOT NULL DEFAULT '[]',
      green_bench TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL
    )
  ''');
  db.execute('''
    CREATE TABLE events (
      round_id INTEGER NOT NULL REFERENCES rounds(id),
      seq INTEGER NOT NULL,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      PRIMARY KEY (round_id, seq)
    )
  ''');
  db.execute(
    "INSERT INTO rounds (ruleset_id, red_name, green_name, red_seats, "
    "green_seats, created_at) VALUES ('tbq-25-26', 'Old Red', 'Old Green', "
    "'[\"Red 1\"]', '[\"Green 1\"]', '2026-01-01T00:00:00.000')",
  );
  db.execute(
    "INSERT INTO events (round_id, seq, type, payload) "
    "VALUES (1, 0, 'TimeOutEvent', '{\"side\":\"red\"}')",
  );
  db.execute(
    "INSERT INTO events (round_id, seq, type, payload) "
    "VALUES (1, 1, 'InterruptionEvent', '{\"q\":3}')",
  );
  db.execute('PRAGMA user_version = 1');
  db.dispose();
}

/// The `CREATE TABLE` text SQLite holds for [table], or null when absent.
String? tableDdl(String path, String table) {
  final db = sqlite3.open(path);
  try {
    final rows = db.select(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isEmpty ? null : rows.first['sql'] as String;
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory tmp;
  late String path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('concordance_schema');
    path = '${tmp.path}/concordance.db';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a fresh database is stamped at the current schema version', () {
    final store = RoundStore.openAt(path);
    expect(store.storedSchemaVersion, RoundStore.schemaVersion);
    store.close();

    // Re-opening is a no-op, not a re-run.
    final again = RoundStore.openAt(path);
    expect(again.storedSchemaVersion, RoundStore.schemaVersion);
    again.close();
  });

  test('a pre-versioning database is migrated forward, keeping its rounds', () {
    writeLegacyDatabase(path);
    expect(pragmaInt(path, 'user_version'), 0);

    final store = RoundStore.openAt(path);
    expect(store.storedSchemaVersion, RoundStore.schemaVersion);

    // The legacy round survived, and picked up the new columns with defaults.
    final row = store.loadRound(1)!;
    expect(row['red_name'], 'Legacy Red');
    expect(row['red_bench'], '[]');
    expect(row['green_bench'], '[]');

    // The migrated columns are usable, not merely present.
    final id = store.createRound(
      rulesetId: 'tbq-25-26',
      redName: 'Red',
      greenName: 'Green',
      redSeats: const ['Red 1', 'Red 2'],
      greenSeats: const ['Green 1', 'Green 2'],
      redBench: const ['Red 3'],
    );
    expect(store.loadRound(id)!['red_bench'], '["Red 3"]');
    store.close();
  });

  test('a database from a newer build is refused, not corrupted', () {
    writeLegacyDatabase(path);
    final raw = sqlite3.open(path);
    raw.execute('PRAGMA user_version = 99');
    raw.dispose();

    expect(() => RoundStore.openAt(path), throwsStateError);
    // Refusing must not damage the data it could not understand.
    expect(pragmaInt(path, 'user_version'), 99);
  });

  test('auto-vacuum is enabled, including on a pre-existing database', () {
    // A file our old builds left behind: auto_vacuum NONE (the SQLite default).
    writeLegacyDatabase(path);
    expect(pragmaInt(path, 'auto_vacuum'), 0);

    final store = RoundStore.openAt(path);
    expect(pragmaInt(path, 'auto_vacuum'), 2); // INCREMENTAL
    store.close();
  });

  test('freed pages are reclaimed instead of growing the file', () {
    final store = RoundStore.openAt(path);
    final id = newRound(store);
    for (var n = 0; n < 500; n++) {
      store.appendEvent(id, const TimeOutEvent(side: Side.red));
    }
    expect(pragmaInt(path, 'freelist_count'), 0);

    // A bulk delete frees pages onto the free list; the file does not shrink on
    // its own, which is what reclaimSpace is for.
    store.truncateTo(id, 0);
    expect(pragmaInt(path, 'freelist_count'), greaterThan(0));

    store.reclaimSpace();
    expect(pragmaInt(path, 'freelist_count'), 0);
    store.close();
  });

  test('deleteRound reclaims the space it frees', () {
    final store = RoundStore.openAt(path);
    final id = newRound(store);
    for (var n = 0; n < 500; n++) {
      store.appendEvent(id, const TimeOutEvent(side: Side.red));
    }

    store.deleteRound(id);

    expect(store.loadJournal(id), isEmpty);
    expect(store.listRounds(), isEmpty);
    expect(pragmaInt(path, 'freelist_count'), 0);
    store.close();
  });

  test('a file database opens in WAL with NORMAL sync and a busy timeout', () {
    final store = RoundStore.openAt(path);

    // journal_mode lives in the file header, so a second connection sees it.
    expect(pragmaText(path, 'journal_mode'), 'wal');

    // synchronous and busy_timeout are per-connection, so they are read back
    // through the store's own handle.
    expect(store.pragmaInt('synchronous'), 1); // NORMAL
    expect(store.pragmaInt('busy_timeout'), 5000);
    store.close();

    // WAL is a property of the file, not the connection, so it survives closing.
    expect(pragmaText(path, 'journal_mode'), 'wal');
  });

  test('foreign keys are enforced on disk and in memory', () {
    final file = RoundStore.openAt(path);
    expect(file.pragmaInt('foreign_keys'), 1);
    file.close();

    // The in-memory store enforces them too, so tests exercise the constraints
    // production runs under rather than a laxer version of them.
    final memory = RoundStore.inMemory();
    expect(memory.pragmaInt('foreign_keys'), 1);
    memory.close();
  });

  test('an event for a round that does not exist is rejected', () {
    final store = RoundStore.openAt(path);

    // This used to write a silently orphaned journal row: `events.round_id` was
    // declared as a foreign key but nothing enforced it.
    expect(
      () => store.appendEvent(9999, const TimeOutEvent(side: Side.red)),
      throwsA(isA<SqliteException>()),
    );
    expect(store.loadJournal(9999), isEmpty);
    store.close();
  });

  test('a fresh database already has the rebuilt events shape', () {
    final store = RoundStore.openAt(path);
    store.close();

    // Migration 2 must find nothing to do on a database this build created.
    final ddl = tableDdl(path, 'events')!;
    expect(ddl, contains('WITHOUT ROWID'));
    expect(ddl, contains('ON DELETE CASCADE'));
  });

  test('a v1 database is rebuilt, keeping every journalled event', () {
    writeVersionOneDatabase(path);
    expect(pragmaInt(path, 'user_version'), 1);
    expect(tableDdl(path, 'events'), isNot(contains('WITHOUT ROWID')));

    final store = RoundStore.openAt(path);
    expect(store.storedSchemaVersion, RoundStore.schemaVersion);

    // The rebuild copies rows verbatim, so resume re-folds identically.
    final journal = store.loadJournal(1);
    expect(journal, hasLength(2));
    expect(journal[0], isA<TimeOutEvent>());
    expect(journal[1], isA<InterruptionEvent>());
    expect((journal[1] as InterruptionEvent).questionNumber, 3);

    // The table really was rebuilt, not merely re-versioned.
    expect(tableDdl(path, 'events'), contains('WITHOUT ROWID'));
    store.close();
  });

  test('a rebuilt journal still appends and truncates in order', () {
    writeVersionOneDatabase(path);
    final store = RoundStore.openAt(path);

    // Appending into a WITHOUT ROWID table has to behave exactly as before.
    store.appendEvent(
      1,
      const AnswerEvent(
        questionNumber: 4,
        side: Side.red,
        quizzerIndex: 0,
        correct: true,
      ),
    );
    expect(store.loadJournal(1), hasLength(3));

    store.truncateTo(1, 2);
    expect(store.loadJournal(1), hasLength(2));
    store.close();
  });

  test('deleting a round cascades into its journal', () {
    final store = RoundStore.openAt(path);
    final id = newRound(store);
    for (var n = 0; n < 5; n++) {
      store.appendEvent(id, const TimeOutEvent(side: Side.red));
    }
    expect(store.loadJournal(id), hasLength(5));

    // `deleteRound` no longer deletes the child rows itself: this asserts the
    // `ON DELETE CASCADE` migration 2 added is what removes them.
    store.deleteRound(id);
    expect(store.loadJournal(id), isEmpty);
    expect(store.listRounds(), isEmpty);
    store.close();
  });

  test('created_at is written as an unambiguous UTC instant', () {
    final store = RoundStore.openAt(path);
    final id = newRound(store);

    // The `Z` is what makes the value comparable across devices and immune to a
    // DST change, unlike the naive local form earlier builds wrote.
    expect(store.loadRound(id)!['created_at'], endsWith('Z'));
    expect(
      parseTimestamp(store.loadRound(id)!['created_at'] as String),
      isNotNull,
    );
    store.close();
  });

  test('a pre-v3 created_at is normalised to UTC', () {
    writeVersionOneDatabase(path); // naive local time, no offset

    final raw = sqlite3.open(path);
    final before =
        raw
                .select('SELECT created_at FROM rounds WHERE id = 1')
                .first['created_at']
            as String;
    raw.dispose();
    expect(before, isNot(endsWith('Z')));

    final store = RoundStore.openAt(path);
    expect(store.loadRound(1)!['created_at'], '${before}Z');
    store.close();
  });
}
