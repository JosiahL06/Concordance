/// Scorekeeper notifications: "things to tell the quizmaster", derived from
/// state under the active ruleset. Mirrors the Scorekeeper duties sections
/// in both rulebooks (notify on outs, limit warnings, closing announcements).
library;

import 'events.dart';
import 'ruleset.dart';
import 'state.dart';

/// One notification for the scorekeeper to relay.
class Notice {
  const Notice(this.code, this.message);

  final String code;
  final String message;
}

/// Collects all currently active notifications.
List<Notice> collectNotices(Ruleset ruleset, RoundState state) {
  final notices = <Notice>[];
  _collectValueNotices(ruleset, state, notices);
  for (final side in Side.values) {
    final team = state.teams[side];
    if (team == null) continue;
    final name = side.name.toUpperCase();
    for (final q in team.quizzers) {
      if (q.quizzedOut) {
        notices.add(Notice('quiz-out', '$name ${q.label} quizzed out'));
      }
      if (q.struckOut) {
        notices.add(Notice('strike-out', '$name ${q.label} struck out'));
      }
      if (q.fouledOut) {
        notices.add(Notice('foul-out', '$name ${q.label} fouled out'));
      }
    }
    // Scorekeeper duty: notify on the team's `notifyTimeOutRequest`-th
    // request. Time-outs are capped at `timeOutsPerTeam` (see `reducer.dart`),
    // so when `notifyTimeOutRequest` exceeds the cap a denied over-cap request
    // never increments the count — the controller raises that notification
    // itself at the moment of the denied attempt (it is an *attempt*, not a
    // state, so this state-derived notice cannot represent it).
    if (team.timeOuts >= ruleset.limits.notifyTimeOutRequest) {
      notices.add(
        Notice(
          'time-out-limit',
          '$name requested a ${team.timeOuts}th time-out',
        ),
      );
    }
    final limits = ruleset.limits;
    if (limits.challengeLimitMode == ChallengeLimitMode.unsuccessful &&
        team.unsuccessfulChallenges >= limits.challengeLimitCount) {
      notices.add(
        Notice(
          'challenge-limit',
          '$name has ${team.unsuccessfulChallenges} unsuccessful contests',
        ),
      );
    }
    if (limits.challengeLimitMode == ChallengeLimitMode.used &&
        limits.challengeAllotmentPerTeam != null &&
        team.challengesUsed >= limits.challengeAllotmentPerTeam!) {
      notices.add(Notice('challenge-limit', '$name appeal allotment used'));
    }
  }
  return notices;
}

/// Question-set value notices (schema decision D12). Advisory only — the engine
/// never blocks a value, but a rulebook stipulation broken by the values the
/// keeper has entered raises a one-time notice. Every check reads regulation
/// slots (overtime is exempt) and is derived from state, so undo/resume
/// reconcile it like any other notice.
void _collectValueNotices(Ruleset ruleset, RoundState state, List<Notice> out) {
  final regulation = ruleset.match.regulationQuestions;
  final values = state.values;
  if (values.length < regulation) return;
  final rules = ruleset.match.valueRules;

  // Assigned counts over the regulation slots.
  final counts = <int, int>{};
  for (var i = 0; i < regulation; i++) {
    final v = values[i];
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }

  // More of a value than the set contains (catches any mismatch, since the
  // totals sum to the question count).
  ruleset.match.valueCounts.forEach((value, allowed) {
    final have = counts[value] ?? 0;
    if (have > allowed) {
      out.add(
        Notice(
          'value-count',
          '$have $value-point questions set, but the set allows only '
              '$allowed.',
        ),
      );
    }
  });

  // A forbidden value at either end of regulation (start / conclusion).
  for (final v in rules.noValueAtEnds) {
    if (values.first == v || values[regulation - 1] == v) {
      out.add(
        Notice(
          'value-at-end',
          'A match must not start or end with a $v-point question.',
        ),
      );
      break;
    }
  }

  // Two consecutive forbidden-value questions.
  for (final v in rules.noConsecutiveValues) {
    for (var i = 0; i < regulation - 1; i++) {
      if (values[i] == v && values[i + 1] == v) {
        out.add(
          Notice(
            'value-consecutive',
            '$v-point questions must not be consecutive '
                '(Q${i + 1} and Q${i + 2}).',
          ),
        );
        break;
      }
    }
  }

  // Per-half minimums — only judged once every slot in the half is assigned.
  final halfSize = regulation ~/ 2;
  for (var h = 0; h < 2; h++) {
    final start = h * halfSize;
    final end = h == 1 ? regulation : start + halfSize;
    var complete = true;
    final halfCounts = <int, int>{};
    for (var i = start; i < end; i++) {
      final v = values[i];
      if (v == null) {
        complete = false;
        break;
      }
      halfCounts[v] = (halfCounts[v] ?? 0) + 1;
    }
    if (!complete) continue;
    for (final m in rules.halfMinimums) {
      if ((halfCounts[m.value] ?? 0) < m.count) {
        out.add(
          Notice(
            'value-half-minimum',
            'The ${h == 0 ? 'first' : 'second'} half needs at least '
                '${m.count} ${m.value}-point '
                'question${m.count == 1 ? '' : 's'}.',
          ),
        );
      }
    }
  }
}
