import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/tournament/tournament_models.dart';

TournamentMatchStart start({
  required List<TournamentMember> members,
  Side side = Side.red,
  String opponent = 'Opponent',
}) {
  final tracked = [for (final member in members) member.name];
  return TournamentMatchStart(
    trackedSide: side,
    opponentName: opponent,
    redName: side == Side.red ? 'Team' : opponent,
    greenName: side == Side.green ? 'Team' : opponent,
    redSeats: side == Side.red ? tracked : const ['O1', 'O2', 'O3'],
    greenSeats: side == Side.green ? tracked : const ['O1', 'O2', 'O3'],
    redBench: const [],
    greenBench: const [],
    links: [
      for (var i = 0; i < members.length; i++)
        TournamentMemberLinkInput(
          side: side,
          rosterIndex: i,
          memberId: members[i].id,
        ),
    ],
  );
}

void main() {
  test('creates a tournament, members, and pending match slots', () {
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'Fall Invitational',
      rulesetId: 'tbq-25-26',
      matchCount: 3,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );

    final tournament = store.loadTournament(id)!;
    expect(tournament.name, 'Fall Invitational');
    expect(tournament.matchCount, 3);
    expect(tournament.completedAt, isNull);
    expect(store.listTournaments(), hasLength(1));
    expect(store.loadTournamentMembers(id), hasLength(3));
    final matches = store.loadTournamentMatches(id);
    expect(matches, hasLength(3));
    expect(matches.every((m) => m.isPending), isTrue);
    expect(matches.map((m) => m.matchNumber), [1, 2, 3]);
  });

  test('starts a match atomically, links members, and hides the round', () {
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'T',
      rulesetId: 'tbq-25-26',
      matchCount: 2,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );
    final members = store.loadTournamentMembers(id);
    final match = store.loadTournamentMatches(id).first;
    final roundId = store.startTournamentMatch(
      matchId: match.id,
      rulesetId: 'tbq-25-26',
      start: start(members: members),
    );

    final started = store.loadTournamentMatches(id).first;
    expect(started.roundId, roundId);
    expect(started.isInProgress, isTrue);
    expect(started.trackedSide, Side.red);
    expect(started.opponentName, 'Opponent');
    expect(store.loadTournamentRoundMembers(roundId), hasLength(3));
    expect(store.listRounds(excludeTournament: true), isEmpty);
    expect(store.listRounds(), hasLength(1));
  });

  test('completes the tournament after every match is complete', () {
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'T',
      rulesetId: 'tbq-25-26',
      matchCount: 2,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );
    final members = store.loadTournamentMembers(id);
    final matches = store.loadTournamentMatches(id);
    for (final match in matches) {
      store.startTournamentMatch(
        matchId: match.id,
        rulesetId: 'tbq-25-26',
        start: start(members: members),
      );
      store.completeTournamentMatch(match.id);
    }
    expect(store.loadTournament(id)!.completedAt, isNotNull);
    expect(store.loadTournamentMatches(id).every((m) => m.isCompleted), isTrue);
  });

  test('reset deletes the round and returns the slot to pending', () {
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'T',
      rulesetId: 'tbq-25-26',
      matchCount: 1,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );
    final members = store.loadTournamentMembers(id);
    final match = store.loadTournamentMatches(id).first;
    final roundId = store.startTournamentMatch(
      matchId: match.id,
      rulesetId: 'tbq-25-26',
      start: start(members: members),
    );
    store.completeTournamentMatch(match.id);
    expect(store.loadRound(roundId), isNotNull);

    store.resetTournamentMatch(match.id);
    expect(store.loadRound(roundId), isNull);
    final reset = store.loadTournamentMatches(id).first;
    expect(reset.isPending, isTrue);
    expect(reset.roundId, isNull);
    expect(store.loadTournament(id)!.completedAt, isNull);
  });

  test('deleting a tournament deletes its rounds and links', () {
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'T',
      rulesetId: 'tbq-25-26',
      matchCount: 1,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );
    final members = store.loadTournamentMembers(id);
    final match = store.loadTournamentMatches(id).first;
    final roundId = store.startTournamentMatch(
      matchId: match.id,
      rulesetId: 'tbq-25-26',
      start: start(members: members),
    );

    store.deleteTournament(id);
    expect(store.loadTournament(id), isNull);
    expect(store.loadRound(roundId), isNull);
    expect(store.loadJournal(roundId), isEmpty);
    expect(store.loadTournamentRoundMembers(roundId), isEmpty);
    expect(store.listTournaments(), isEmpty);
  });
}
