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
