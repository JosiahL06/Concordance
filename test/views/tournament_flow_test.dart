import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/haptics.dart';
import 'package:concordance/app/settings.dart';
import 'package:concordance/app/theme.dart';
import 'package:concordance/data/round_store.dart';
import 'package:concordance/engine/events.dart';
import 'package:concordance/engine/ruleset.dart';
import 'package:concordance/main.dart';
import 'package:concordance/views/classic_screen.dart';
import 'package:concordance/views/tournament_screen.dart';
import 'package:concordance/views/tournament_setup_screen.dart';
import 'package:concordance/views/tournament_match_setup_screen.dart';
import 'package:concordance/tournament/tournament_models.dart';

List<Ruleset> presets() => [
  for (final id in const ['tbq-25-26', 'jbq-2026'])
    Ruleset.fromJson(
      json.decode(File('assets/rulesets/$id.json').readAsStringSync())
          as Map<String, Object?>,
    ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home creates a tournament and opens its dashboard', (
    WidgetTester tester,
  ) async {
    final prefs = await ViewPreference.load();
    final store = RoundStore.inMemory();
    await tester.pumpWidget(
      ConcordanceApp(prefs: prefs, store: store, presets: presets()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START A TOURNAMENT'));
    await tester.pumpAndSettle();
    expect(find.text('New tournament'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Fall Invitational');
    final create = find.text('CREATE TOURNAMENT');
    for (var i = 0; i < 8 && create.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(store.listTournaments(), hasLength(1));
    expect(find.text('Fall Invitational'), findsOneWidget);
    expect(find.text('START MATCH 1'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Team totals'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Individual totals'), findsOneWidget);
  });

  testWidgets('dashboard reads a completed match from the store', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final prefs = await ViewPreference.load();
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'Fall Invitational',
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
      start: TournamentMatchStart(
        trackedSide: Side.red,
        opponentName: 'Rivals',
        redName: 'Team',
        greenName: 'Rivals',
        redSeats: const ['Alice', 'Bob', 'Cara'],
        greenSeats: const ['R1', 'R2', 'R3'],
        redBench: const [],
        greenBench: const [],
        links: [
          for (var i = 0; i < members.length; i++)
            TournamentMemberLinkInput(
              side: Side.red,
              rosterIndex: i,
              memberId: members[i].id,
            ),
        ],
      ),
    );
    final journal = <RoundEvent>[];
    for (var n = 1; n <= 20; n++) {
      journal.add(QuestionValueEvent(questionNumber: n, value: 10));
      if (n <= 15) {
        journal.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.red,
            quizzerIndex: (n - 1) ~/ 5,
            correct: true,
          ),
        );
      } else {
        journal.add(
          AnswerEvent(
            questionNumber: n,
            side: Side.green,
            quizzerIndex: 0,
            correct: true,
          ),
        );
      }
    }
    store.replaceJournal(roundId, journal);
    store.completeTournamentMatch(match.id);

    await tester.pumpWidget(
      MaterialApp(
        home: TournamentScreen(
          store: store,
          tournamentId: id,
          view: ScoreboardView.modern,
          prefs: prefs,
          presets: presets(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('COMPLETE'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.textContaining('Rivals'), findsOneWidget);
    expect(find.text('Team totals'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Export results'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(prefs, isNotNull);
  });

  testWidgets('tournament setup fits at 1024x700 and 1.3x', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(home: TournamentSetupScreen(presets: presets())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New tournament'), findsOneWidget);
  });

  testWidgets('match setup fits at 1024x700 and 1.3x', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final tournament = Tournament(
      id: 1,
      name: 'T',
      rulesetId: 'tbq-25-26',
      matchCount: 1,
      teamName: 'Team',
      createdAt: DateTime.utc(2026, 11, 9),
    );
    final match = TournamentMatch(
      id: 1,
      tournamentId: 1,
      matchNumber: 1,
      status: 'pending',
    );
    final members = [
      TournamentMember(
        id: 1,
        tournamentId: 1,
        name: 'Alice',
        rosterIndex: 0,
        defaultSeat: 1,
      ),
      TournamentMember(
        id: 2,
        tournamentId: 1,
        name: 'Bob',
        rosterIndex: 1,
        defaultSeat: 2,
      ),
      TournamentMember(
        id: 3,
        tournamentId: 1,
        name: 'Cara',
        rosterIndex: 2,
        defaultSeat: 3,
      ),
    ];
    final prefs = await ViewPreference.load();
    final theme = ThemeController(prefs);
    final haptics = HapticsController(prefs);
    addTearDown(theme.dispose);
    addTearDown(haptics.dispose);
    await tester.pumpWidget(
      ThemeScope(
        notifier: theme,
        child: HapticsScope(
          notifier: haptics,
          child: MaterialApp(
            home: TournamentMatchSetupScreen(
              tournament: tournament,
              match: match,
              ruleset: presets().first,
              members: members,
              initialView: ScoreboardView.modern,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Choose your side'), findsOneWidget);
    final red = tester.getSize(
      find.byKey(const ValueKey('tournament-team-red')),
    );
    final green = tester.getSize(
      find.byKey(const ValueKey('tournament-team-green')),
    );
    expect(red.height, green.height);
  });

  testWidgets('home deletes a tournament with confirmation', (
    WidgetTester tester,
  ) async {
    final prefs = await ViewPreference.load();
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'Fall Invitational',
      rulesetId: 'tbq-25-26',
      matchCount: 1,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
      ],
    );
    await tester.pumpWidget(
      ConcordanceApp(prefs: prefs, store: store, presets: presets()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Fall Invitational'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete tournament'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this tournament?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.listTournaments(), isEmpty);
    expect(find.text('No tournaments yet.'), findsOneWidget);
    expect(id, greaterThan(0));
  });

  testWidgets('match setup prefills the saved team and asks for a side', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await ViewPreference.load();
    final store = RoundStore.inMemory();
    final id = store.createTournament(
      name: 'Fall Invitational',
      rulesetId: 'tbq-25-26',
      matchCount: 2,
      teamName: 'Team',
      members: const [
        TournamentMemberInput(name: 'Alice', rosterIndex: 0, defaultSeat: 1),
        TournamentMemberInput(name: 'Bob', rosterIndex: 1, defaultSeat: 2),
        TournamentMemberInput(name: 'Cara', rosterIndex: 2, defaultSeat: 3),
      ],
    );
    await tester.pumpWidget(
      ConcordanceApp(prefs: prefs, store: store, presets: presets()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fall Invitational'));
    await tester.pumpAndSettle();
    expect(find.text('START MATCH 1'), findsOneWidget);

    await tester.tap(find.text('START MATCH 1'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your side'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Opponent team name'), findsOneWidget);

    // Move Alice off this match; the saved team is unchanged for the next one.
    final lineupDropdowns = find.byType(DropdownButton<int>);
    expect(lineupDropdowns, findsNWidgets(3));
    await tester.tap(lineupDropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not playing').last);
    await tester.pumpAndSettle();
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('OPPONENT'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Team name'), findsNothing);
    expect(find.text('Applies to this match only.'), findsNothing);

    final classic = find.text('Classic');
    await tester.ensureVisible(classic);
    await tester.pumpAndSettle();
    await tester.tap(classic);
    await tester.pumpAndSettle();

    final start = find.text('START MATCH');
    for (var i = 0; i < 12 && start.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
    }
    expect(start, findsOneWidget);
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.byType(ClassicScreen), findsOneWidget);
    expect(prefs.view, ScoreboardView.classic);
    expect(find.byTooltip('Back to tournament'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to tournament'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE MATCH 1'), findsOneWidget);

    final started = store.loadTournamentMatches(id).first;
    final round = store.loadRound(started.roundId!)!;
    expect(json.decode(round['red_seats'] as String), ['Bob', 'Cara']);
    expect(store.loadTournamentRoundMembers(started.roundId!), hasLength(2));
    expect(id, greaterThan(0));
  });
}
