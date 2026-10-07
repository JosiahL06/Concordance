// Question-set value guardrails (schema decision D12). The rulebooks fix the
// value distribution and (JBQ) how the set may be arranged; the engine never
// blocks a value, but a broken stipulation raises a one-time scorekeeper
// notice. Facts only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/engine/notifications.dart';
import 'package:concordance/engine/round_view.dart';
import 'package:concordance/engine/ruleset.dart';

Ruleset loadPreset(String id) => Ruleset.fromJson(
  json.decode(File('assets/rulesets/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// A valid TBQ regulation set: eight 10s, nine 20s, three 30s.
const kTbqValidSet = <int>[
  10, 20, 10, 20, 30, 20, 10, 20, 10, 20, //
  30, 20, 10, 20, 30, 20, 10, 20, 10, 10,
];

/// A valid JBQ regulation set: ten 10s, seven 20s, three 30s; each half has
/// ≥3 twenties and ≥1 thirty; no 30 first/last; no consecutive 30s.
const kJbqValidSet = <int>[
  10, 20, 10, 30, 10, 20, 10, 20, 10, 10, //
  30, 20, 20, 10, 20, 30, 20, 10, 10, 10,
];

List<Notice> noticesFor(Ruleset ruleset, List<int?> values) {
  final view = RoundView(
    ruleset: ruleset,
    redLabels: const ['Red 1', 'Red 2'],
    greenLabels: const ['Green 1', 'Green 2'],
    questionValues: values,
  );
  return collectNotices(ruleset, view.state);
}

bool has(List<Notice> ns, String code) => ns.any((n) => n.code == code);

void main() {
  final tbq = loadPreset('tbq-25-26');
  final jbq = loadPreset('jbq-2026');

  group('schema', () {
    test('JBQ declares its set stipulations; TBQ declares none', () {
      expect(jbq.match.valueRules.noValueAtEnds, contains(30));
      expect(jbq.match.valueRules.noConsecutiveValues, contains(30));
      expect(
        jbq.match.valueRules.halfMinimums.map((m) => '${m.count}x${m.value}'),
        containsAll(<String>['3x20', '1x30']),
      );
      expect(tbq.match.valueRules.noValueAtEnds, isEmpty);
      expect(tbq.match.valueRules.noConsecutiveValues, isEmpty);
      expect(tbq.match.valueRules.halfMinimums, isEmpty);
    });
  });

  group('distribution counts (TBQ 8/9/3, JBQ 10/7/3)', () {
    test('TBQ: a 4th 30-point question is flagged', () {
      final values = List<int?>.filled(20, 10);
      values[0] = 30;
      values[2] = 30;
      values[4] = 30;
      values[6] = 30;
      expect(has(noticesFor(tbq, values), 'value-count'), isTrue);
    });

    test('JBQ: an 11th 10-point question is flagged', () {
      final values = List<int>.of(kJbqValidSet);
      values[1] = 10; // a 20 becomes a 10
      expect(has(noticesFor(jbq, values), 'value-count'), isTrue);
    });

    test('a valid set raises no notice', () {
      expect(noticesFor(jbq, kJbqValidSet), isEmpty);
      expect(noticesFor(tbq, kTbqValidSet), isEmpty);
    });
  });

  group('JBQ positional rules', () {
    test('a 30 must not start the match', () {
      final values = List<int>.of(kJbqValidSet);
      values[0] = 30;
      expect(has(noticesFor(jbq, values), 'value-at-end'), isTrue);
    });

    test('a 30 must not conclude regulation', () {
      final values = List<int>.of(kJbqValidSet);
      values[19] = 30;
      expect(has(noticesFor(jbq, values), 'value-at-end'), isTrue);
    });

    test('30s must not be consecutive', () {
      final values = List<int>.of(kJbqValidSet);
      values[3] = 30; // Q4
      values[4] = 30; // Q5 → consecutive
      expect(has(noticesFor(jbq, values), 'value-consecutive'), isTrue);
    });

    test('TBQ carries no positional rules', () {
      final values = List<int>.of(kTbqValidSet);
      values[0] = 30; // would be a JBQ "start" violation
      values[1] = 30; // would be a JBQ "consecutive" violation
      final ns = noticesFor(tbq, values);
      expect(has(ns, 'value-at-end'), isFalse);
      expect(has(ns, 'value-consecutive'), isFalse);
    });

    test('overtime slots are exempt', () {
      final values = <int?>[...kJbqValidSet, 30]; // overtime Q21 = 30
      expect(noticesFor(jbq, values), isEmpty);
    });
  });

  group('JBQ per-half minimums', () {
    test('a completed half short of its minimum is flagged', () {
      final values = List<int?>.filled(20, 10);
      values[10] = 20; // second half is valid...
      values[11] = 20;
      values[12] = 20;
      values[13] = 30;
      // ...the all-10 first half is short of three 20s and one 30.
      expect(has(noticesFor(jbq, values), 'value-half-minimum'), isTrue);
    });

    test('an incomplete half is not judged', () {
      final values = List<int?>.filled(20, null);
      values[0] = 10;
      expect(has(noticesFor(jbq, values), 'value-half-minimum'), isFalse);
    });
  });
}
