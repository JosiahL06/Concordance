import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../app/round_controller.dart';
import '../app/round_session.dart';
import '../app/settings.dart';
import '../data/round_store.dart';
import '../data/tournament_export.dart';
import '../engine/events.dart';
import '../engine/ruleset.dart';
import '../tournament/tournament_models.dart';
import '../tournament/tournament_stats.dart';
import 'classic_screen.dart';
import 'common/export_feedback.dart';
import 'common/live_chrome.dart';
import 'modern_screen.dart';
import 'summary_screen.dart';
import 'tournament_match_setup_screen.dart';

/// Tournament dashboard: progress, match slates, and aggregate team/individual
/// stats. Start/resume/view a match from here; every round remains a normal
/// round underneath.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({
    super.key,
    required this.store,
    required this.tournamentId,
    required this.view,
    required this.prefs,
    this.presets,
  });

  final RoundStore store;
  final int tournamentId;
  final ScoreboardView view;
  final ViewPreference prefs;
  final List<Ruleset>? presets;

  static String routeName(int id) => 'tournament-$id';

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  Tournament? _tournament;
  List<TournamentMember> _members = const [];
  TournamentStats? _stats;
  Ruleset? _ruleset;
  String? _error;
  bool _loading = true;
  late ScoreboardView _view;

  String get _routeName => TournamentScreen.routeName(widget.tournamentId);

  @override
  void initState() {
    super.initState();
    _view = widget.view;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final tournament = widget.store.loadTournament(widget.tournamentId);
      if (tournament == null) throw StateError('Tournament not found');
      final presets =
          widget.presets ?? await loadPresets(<String>[tournament.rulesetId]);
      final ruleset = presets.firstWhere(
        (r) => r.id == tournament.rulesetId,
        orElse: () => throw StateError(
          'Ruleset ${tournament.rulesetId} is not available',
        ),
      );
      final members = widget.store.loadTournamentMembers(tournament.id);
      var matches = widget.store.loadTournamentMatches(tournament.id);
      var stats = _compute(tournament, members, matches, ruleset);

      // Reconcile a finished round whose match row was never marked complete
      // (e.g. the app closed on the summary screen).
      var changed = false;
      for (final match in stats.matches) {
        if (match.completed &&
            match.match.roundId != null &&
            !match.match.isCompleted) {
          widget.store.completeTournamentMatch(match.match.id);
          changed = true;
        }
      }
      if (changed) {
        matches = widget.store.loadTournamentMatches(tournament.id);
        stats = _compute(tournament, members, matches, ruleset);
      }
      final refreshed =
          widget.store.loadTournament(tournament.id) ?? tournament;
      if (!mounted) return;
      setState(() {
        _tournament = refreshed;
        _members = members;
        _ruleset = ruleset;
        _stats = stats;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  TournamentStats _compute(
    Tournament tournament,
    List<TournamentMember> members,
    List<TournamentMatch> matches,
    Ruleset ruleset,
  ) {
    final rounds = <TournamentRoundData>[];
    for (final match in matches) {
      final roundId = match.roundId;
      if (roundId == null) continue;
      final row = widget.store.loadRound(roundId);
      if (row == null) continue;
      rounds.add(
        TournamentRoundData(
          match: match,
          roundRow: row,
          journal: widget.store.loadJournal(roundId),
          links: widget.store.loadTournamentRoundMembers(roundId),
        ),
      );
    }
    return TournamentStats.compute(
      tournament: tournament,
      members: members,
      matches: matches,
      rounds: rounds,
      ruleset: ruleset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tournament?.name ?? 'Tournament'),
        actions: [
          if (_tournament != null)
            IconButton(
              tooltip: 'Delete tournament',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorBody(scheme)
          : _body(context, scheme),
    );
  }

  Widget _errorBody(ColorScheme scheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load tournament',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ColorScheme scheme) {
    final tournament = _tournament!;
    final stats = _stats!;
    final ruleset = _ruleset!;
    final next = _nextMatch(stats);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _headerCard(context, tournament, stats, ruleset, next),
            const SizedBox(height: 16),
            Text('Matches', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final match in stats.matches)
              _matchCard(context, match, tournament, ruleset),
            const SizedBox(height: 20),
            _teamStatsCard(context, stats),
            const SizedBox(height: 16),
            _memberStatsCard(context, stats),
            const SizedBox(height: 16),
            _exportCard(context, stats),
          ],
        ),
      ),
    );
  }

  TournamentMatchStats? _nextMatch(TournamentStats stats) {
    for (final match in stats.matches) {
      if (!match.completed && match.match.roundId != null) return match;
    }
    for (final match in stats.matches) {
      if (!match.completed) return match;
    }
    return null;
  }

  Widget _headerCard(
    BuildContext context,
    Tournament tournament,
    TournamentStats stats,
    Ruleset ruleset,
    TournamentMatchStats? next,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final record = '${stats.team.wins}-${stats.team.losses}-${stats.team.ties}';
    final progress =
        '${stats.completedCount} of ${tournament.matchCount} matches';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.teamName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ruleset.displayName} ${ruleset.season} · $progress',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                _metric(context, 'RECORD', record),
                const SizedBox(width: 18),
                _metric(context, 'POINTS', '${stats.team.pointsFor}'),
              ],
            ),
            const SizedBox(height: 16),
            if (next != null)
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => next.completed
                      ? _viewMatch(next)
                      : next.match.roundId != null
                      ? _resumeMatch(next)
                      : _startMatch(next),
                  icon: Icon(
                    next.match.roundId != null
                        ? Icons.play_arrow
                        : Icons.add_circle_outline,
                  ),
                  label: Text(
                    '${next.match.roundId != null ? 'CONTINUE' : 'START'} '
                    'MATCH ${next.match.matchNumber}',
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tournament complete — ${stats.team.wins} wins, '
                  '${stats.team.losses} losses, ${stats.team.ties} ties.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: scheme.outline,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _matchCard(
    BuildContext context,
    TournamentMatchStats stats,
    Tournament tournament,
    Ruleset ruleset,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final match = stats.match;
    final side = match.trackedSide;
    final opponent = match.opponentName ?? 'Opponent TBD';
    final result = stats.completed ? stats.result ?? '—' : null;
    final score = stats.completed
        ? '${stats.scoreFor}–${stats.scoreAgainst}'
        : null;
    final status = stats.completed
        ? 'COMPLETE'
        : match.roundId != null
        ? 'IN PROGRESS'
        : 'NOT STARTED';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: result == 'W'
              ? correctColor.withValues(alpha: 0.15)
              : result == 'L'
              ? incorrectColor.withValues(alpha: 0.15)
              : scheme.surfaceContainerHigh,
          foregroundColor: result == 'W'
              ? correctColor
              : result == 'L'
              ? incorrectColor
              : scheme.onSurface,
          child: Text(
            '${match.matchNumber}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Row(
          children: [
            if (side != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor(side).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  side == Side.red ? 'RED' : 'GREEN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: sideColor(side),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                'vs $opponent',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (result != null)
              Text(
                result,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: result == 'W'
                      ? correctColor
                      : result == 'L'
                      ? incorrectColor
                      : scheme.outline,
                ),
              ),
          ],
        ),
        subtitle: Text('$status${score == null ? '' : ' · $score'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stats.completed)
              IconButton(
                tooltip: 'Correct match',
                onPressed: () => _resumeMatch(stats),
                icon: const Icon(Icons.edit_note),
              ),
            if (match.roundId != null)
              IconButton(
                tooltip: 'Reset match',
                onPressed: () => _confirmReset(match),
                icon: const Icon(Icons.restart_alt),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          if (stats.completed) {
            _viewMatch(stats);
          } else if (match.roundId != null) {
            _resumeMatch(stats);
          } else {
            _startMatch(stats);
          }
        },
      ),
    );
  }

  Widget _teamStatsCard(BuildContext context, TournamentStats stats) {
    final scheme = Theme.of(context).colorScheme;
    final team = stats.team;
    final rows = <(String, String)>[
      ('Matches', '${team.matches}'),
      ('Record', '${team.wins}-${team.losses}-${team.ties}'),
      ('Points for / against', '${team.pointsFor} / ${team.pointsAgainst}'),
      ('Differential', '${team.differential}'),
      ('Average points', team.averagePoints.toStringAsFixed(1)),
      ('Quiz-outs', '${team.quizOuts}'),
      ('Team fouls', '${team.teamFouls}'),
      ('Time-outs', '${team.timeOuts}'),
      ('Contests / appeals', '${team.challengesUsed}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team totals',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                    Text(
                      row.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _exportCard(BuildContext context, TournamentStats stats) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = stats.completedCount > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Export results',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Share the tournament results as a PDF score sheet or a CSV '
              'file. Only completed matches are included in the totals.',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: enabled ? _exportPdf : null,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export PDF'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: enabled ? _exportCsv : null,
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ),
                ),
              ],
            ),
            if (!enabled) ...[
              const SizedBox(height: 8),
              Text(
                'Complete a match to enable tournament exports.',
                style: TextStyle(color: scheme.outline, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final tournament = _tournament;
    final ruleset = _ruleset;
    final stats = _stats;
    if (tournament == null || ruleset == null || stats == null) return;
    try {
      final outcome = await exportTournamentPdf(tournament, ruleset, stats);
      if (!mounted) return;
      showExportOutcome(context, outcome, 'PDF');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not export PDF: $e')));
    }
  }

  Future<void> _exportCsv() async {
    final tournament = _tournament;
    final ruleset = _ruleset;
    final stats = _stats;
    if (tournament == null || ruleset == null || stats == null) return;
    try {
      final outcome = await exportTournamentCsv(tournament, ruleset, stats);
      if (!mounted) return;
      showExportOutcome(context, outcome, 'CSV');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not export CSV: $e')));
    }
  }

  Widget _memberStatsCard(BuildContext context, TournamentStats stats) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Individual totals',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 22,
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.outline,
                ),
                columns: const [
                  DataColumn(label: Text('QUIZZER')),
                  DataColumn(label: Text('M')),
                  DataColumn(label: Text('PTS')),
                  DataColumn(label: Text('C')),
                  DataColumn(label: Text('I')),
                  DataColumn(label: Text('F')),
                  DataColumn(label: Text('QO')),
                  DataColumn(label: Text('SO')),
                  DataColumn(label: Text('FO')),
                  DataColumn(label: Text('AVG')),
                ],
                rows: [
                  for (final member in stats.members)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${member.member.name}${member.member.archived ? ' (archived)' : ''}',
                          ),
                        ),
                        DataCell(Text('${member.matches}')),
                        DataCell(Text('${member.points}')),
                        DataCell(Text('${member.correct}')),
                        DataCell(Text('${member.incorrect}')),
                        DataCell(Text('${member.fouls}')),
                        DataCell(Text('${member.quizOuts}')),
                        DataCell(Text('${member.strikeOuts}')),
                        DataCell(Text('${member.foulOuts}')),
                        DataCell(Text(member.averagePoints.toStringAsFixed(1))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMatch(TournamentMatchStats stats) async {
    final tournament = _tournament!;
    final ruleset = _ruleset!;
    final result = await Navigator.of(context).push<TournamentMatchSetupResult>(
      MaterialPageRoute(
        builder: (_) => TournamentMatchSetupScreen(
          tournament: tournament,
          match: stats.match,
          ruleset: ruleset,
          members: _members,
          initialView: _view,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final start = result.start;
    try {
      if (result.view != _view) {
        setState(() => _view = result.view);
        await widget.prefs.setView(result.view);
      }
      final controller = RoundController(
        ruleset: ruleset,
        redName: start.redName,
        greenName: start.greenName,
        redSeats: start.redSeats,
        greenSeats: start.greenSeats,
        redBench: start.redBench,
        greenBench: start.greenBench,
      );
      final roundId = widget.store.startTournamentMatch(
        matchId: stats.match.id,
        rulesetId: ruleset.id,
        start: start,
      );
      RoundSession.attach(widget.store, controller, roundId, 0);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _view == ScoreboardView.modern
              ? ModernScreen(
                  controller: controller,
                  returnRouteName: _routeName,
                )
              : ClassicScreen(
                  controller: controller,
                  returnRouteName: _routeName,
                ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not start match: $e')));
    }
  }

  Future<void> _resumeMatch(TournamentMatchStats stats) async {
    final roundId = stats.match.roundId;
    final ruleset = _ruleset;
    if (roundId == null || ruleset == null) return;
    try {
      final controller = _controllerFromRound(roundId, ruleset);
      if (controller == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _view == ScoreboardView.modern
              ? ModernScreen(
                  controller: controller,
                  returnRouteName: _routeName,
                )
              : ClassicScreen(
                  controller: controller,
                  returnRouteName: _routeName,
                ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not resume match: $e')));
    }
  }

  Future<void> _viewMatch(TournamentMatchStats stats) async {
    final roundId = stats.match.roundId;
    final ruleset = _ruleset;
    if (roundId == null || ruleset == null) return;
    try {
      final controller = _controllerFromRound(roundId, ruleset);
      if (controller == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SummaryScreen(
            controller: controller,
            returnRouteName: _routeName,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open summary: $e')));
    }
  }

  RoundController? _controllerFromRound(int roundId, Ruleset ruleset) {
    final row = widget.store.loadRound(roundId);
    if (row == null) return null;
    final controller = RoundController(
      ruleset: ruleset,
      redName: row['red_name'] as String,
      greenName: row['green_name'] as String,
      redSeats: _decodeList(row['red_seats']),
      greenSeats: _decodeList(row['green_seats']),
      redBench: _decodeList(row['red_bench']),
      greenBench: _decodeList(row['green_bench']),
    );
    final journal = widget.store.loadJournal(roundId);
    for (final event in journal) {
      controller.view.apply(event);
    }
    controller.markCurrentNoticesSeen();
    controller.questionIndex = controller.firstOpenQuestion() - 1;
    controller.recomputeCompletion();
    RoundSession.attach(widget.store, controller, roundId, journal.length);
    return controller;
  }

  List<String> _decodeList(Object? raw) {
    try {
      final decoded = json.decode('$raw');
      if (decoded is List) return [for (final item in decoded) '$item'];
    } catch (_) {}
    return const [];
  }

  Future<void> _confirmReset(TournamentMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset match ${match.matchNumber}?'),
        content: const Text(
          'This deletes the match round and its saved journal, and returns the '
          'slot to not started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.store.resetTournamentMatch(match.id);
    await _load();
  }

  Future<void> _confirmDelete() async {
    final tournament = _tournament;
    if (tournament == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tournament?'),
        content: Text(
          'Delete "${tournament.name}" and every round it created? This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.store.deleteTournament(tournament.id);
    Navigator.of(context).pop(true);
  }
}
