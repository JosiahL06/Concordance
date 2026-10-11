// The one date the app shows a keeper: a saved round's start time.
import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/app/timestamps.dart';

void main() {
  group('formatTimestamp', () {
    test('renders a stored instant readably in local time', () {
      // Round-tripped through UTC the way the store writes it, so the
      // expectation holds in any machine zone.
      final local = DateTime(2026, 10, 10, 14, 23);
      expect(
        formatTimestamp(local.toUtc().toIso8601String()),
        '10 Oct 2026, 14:23',
      );
    });

    test('pads single-digit hours and minutes', () {
      final local = DateTime(2026, 1, 5, 9, 7);
      expect(
        formatTimestamp(local.toUtc().toIso8601String()),
        '5 Jan 2026, 09:07',
      );
    });

    test('renders a stored UTC instant in local time', () {
      final utc = DateTime.utc(2026, 7, 4, 12, 0);
      final local = utc.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      expect(
        formatTimestamp(utc.toIso8601String()),
        '${local.day} Jul ${local.year}, $hour:$minute',
      );
    });

    test('returns an unreadable value verbatim instead of throwing', () {
      // A date the app cannot read must not hide the round from the list.
      expect(formatTimestamp('not a date'), 'not a date');
      expect(formatTimestamp(''), '');
    });
  });

  group('parseTimestamp', () {
    test('reads a zone-less legacy value as UTC, not as local time', () {
      // The naive form builds before schema v3 wrote. Reading it as local time
      // (Dart's default for a zone-less string) would reintroduce exactly the
      // ambiguity migration 3 removed — and this assertion holds regardless of
      // the machine's zone, unlike comparing rendered strings.
      expect(
        parseTimestamp('2026-03-01T06:30:00.000'),
        DateTime.utc(2026, 3, 1, 6, 30),
      );
    });

    test('reads a Z-suffixed value as the instant it names', () {
      expect(
        parseTimestamp('2026-03-01T06:30:00.000Z'),
        DateTime.utc(2026, 3, 1, 6, 30),
      );
    });

    test('returns null rather than throwing on garbage', () {
      expect(parseTimestamp('nonsense'), isNull);
    });
  });
}
