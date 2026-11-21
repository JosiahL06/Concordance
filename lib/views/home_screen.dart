import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../app/round_controller.dart';
import '../app/round_session.dart';
import '../app/settings.dart';
import '../app/timestamps.dart';
import '../data/round_store.dart';
import '../engine/ruleset.dart';
import '../tournament/tournament_models.dart';
import 'classic_screen.dart';
import 'modern_screen.dart';
import 'setup_screen.dart';
import 'tournament_screen.dart';
import 'tournament_setup_screen.dart';
import 'common/about_button.dart';
import 'common/haptics_toggle.dart';
import 'common/theme_toggle.dart';

/// Production home: start a new round, resume an autosaved round, or switch
/// the per-device scoreboard view. No demo seeding in prod (decision).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.prefs,
    this.store,
    this.presets,
    this.storeOpener,
  });

  final ViewPreference prefs;

  /// Injected store (tests / embedding). When null the screen opens the
  /// on-disk SQLite store itself.
  final RoundStore? store;

  /// Injected ruleset presets (tests); null loads via rootBundle.
  final List<Ruleset>? presets;

  /// Injected store opener (tests); null uses [RoundStore.open].
  final Future<RoundStore> Function()? storeOpener;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RoundStore? _store;
  List<Map<String, Object?>> _rounds = const [];
  List<Tournament> _tournaments = const [];
  String? _storeError;
  ScoreboardView _view = ScoreboardView.modern;

  @override
  void initState() {
    super.initState();
    _view = widget.prefs.view;
    final injected = widget.store;
    if (injected != null) {
      _store = injected;
      _rounds = injected.listRounds(excludeTournament: true);
      _tournaments = injected.listTournaments();
    } else {
      _openStore();
    }
  }

  /// Opens the local store, surfacing failures instead of leaving the Start
  /// button disabled with no explanation. Retryable from the error card.
  Future<void> _openStore() async {
    try {
      final store = await (widget.storeOpener ?? RoundStore.open)();
      if (!mounted) {
        store.close();
        return;
      }
      setState(() {
        _store = store;
        _storeError = null;
        _rounds = store.listRounds(excludeTournament: true);
        _tournaments = store.listTournaments();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _store = null;
        _storeError = '$e';
      });
    }
  }

  @override
  void dispose() {
    // Only close a store we opened ourselves.
    if (widget.store == null) _store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concordance'),
        actions: const [
          ThemeToggleButton(),
          HapticsToggleButton(),
          AboutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Text(
                'Touch-first scorekeeping for Bible Quiz rounds.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_storeError != null) ...[
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Storage unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rounds cannot be saved or resumed until the local '
                          'database opens - scores would be lost if the app '
                          'closed.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _storeError!,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onErrorContainer,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _openStore,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _store == null ? null : () => _newRound(context),
                  child: const Text('START A NEW ROUND'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _store == null
                      ? null
                      : () => _newTournament(context),
                  child: const Text('START A TOURNAMENT'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tournaments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_tournaments.isEmpty) const Text('No tournaments yet.'),
              for (final t in _tournaments)
                Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      '${t.teamName} \u00b7 '
                      '${_tournamentProgress(t.id)} matches',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Delete tournament',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDeleteTournament(context, t),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _openTournament(context, t.id),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Resume round',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_rounds.isEmpty) const Text('No saved rounds yet.'),
              for (final r in _rounds)
                Card(
                  child: ListTile(
                    title: Text('${r['red_name']} vs ${r['green_name']}'),
                    subtitle: Text(
                      '${r['ruleset_id']} \u00b7 '
                      '${formatTimestamp('${r['created_at']}')}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Delete round',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(
                            context,
                            r['id'] as int,
                            '${r['red_name']} vs ${r['green_name']}',
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _resume(context, r['id'] as int),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _tournamentCompleted(int id) =>
      _store!.loadTournamentMatches(id).where((m) => m.isCompleted).length;

  String _tournamentProgress(int id) {
    final tournament = _tournaments.firstWhere((t) => t.id == id);
    return '${_tournamentCompleted(id)}/${tournament.matchCount}';
  }

  Future<void> _newTournament(BuildContext context) async {
    final draft = await Navigator.of(context).push<TournamentDraft>(
      MaterialPageRoute(
        builder: (_) => TournamentSetupScreen(presets: widget.presets),
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      final id = _store!.createTournament(
        name: draft.name,
        rulesetId: draft.ruleset.id,
        matchCount: draft.matchCount,
        teamName: draft.teamName,
        members: draft.members,
      );
      if (!context.mounted) return;
      await _openTournament(context, id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create tournament: $e')),
      );
    }
  }

  Future<void> _openTournament(BuildContext context, int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: TournamentScreen.routeName(id)),
        builder: (_) => TournamentScreen(
          store: _store!,
          tournamentId: id,
          view: _view,
          prefs: widget.prefs,
          presets: widget.presets,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _view = widget.prefs.view;
      _rounds = _store!.listRounds(excludeTournament: true);
      _tournaments = _store!.listTournaments();
    });
  }

  Future<void> _newRound(BuildContext context) async {
    final result = await Navigator.of(context).push<SetupResult>(
      MaterialPageRoute(
        builder: (_) =>
            SetupScreen(initialView: _view, presets: widget.presets),
      ),
    );
    if (result == null || !context.mounted) return;
    // The setup screen's pick wins for this session (and becomes the
    // remembered default for next time).
    setState(() => _view = result.view);
    await widget.prefs.setView(result.view);
    if (!context.mounted) return;
    _attachAutosave(result.controller);
    _openLive(context, result.controller);
    setState(() => _rounds = _store!.listRounds(excludeTournament: true));
  }

  /// Creates the round row and installs the shared autosave hooks.
  void _attachAutosave(RoundController controller) {
    RoundSession.create(_store!, controller);
  }

  Future<void> _resume(BuildContext context, int id) async {
    final store = _store!;
    final row = store.loadRound(id);
    if (row == null) return;
    // Ruleset preset lookup by id (v1 ships two presets).
    final ruleset = await loadPreset(row['ruleset_id'] as String);
    if (!context.mounted) return;
    if (ruleset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load that round - its ruleset is no longer available.',
          ),
        ),
      );
      return;
    }
    final redSeats = _decodeSeats(row['red_seats'] as String);
    final greenSeats = _decodeSeats(row['green_seats'] as String);
    final redBench = _decodeSeats('${row['red_bench'] ?? '[]'}');
    final greenBench = _decodeSeats('${row['green_bench'] ?? '[]'}');
    final controller = RoundController(
      ruleset: ruleset,
      redName: row['red_name'] as String,
      greenName: row['green_name'] as String,
      redSeats: redSeats,
      greenSeats: greenSeats,
      redBench: redBench,
      greenBench: greenBench,
    );
    for (final e in store.loadJournal(id)) {
      controller.view.apply(e);
    }
    // Settle history: outs and limit warnings already in the journal must not
    // re-announce on the first ruling after resume.
    controller.markCurrentNoticesSeen();
    controller.questionIndex = controller.firstOpenQuestion() - 1;
    controller.recomputeCompletion();
    controller.roundId = id;
    // The journal just replayed is exactly what is on disk; only later changes
    // need writing.
    RoundSession.attach(
      _store!,
      controller,
      id,
      controller.view.journal.length,
    );
    _openLive(context, controller);
  }

  /// Confirms, then permanently deletes an autosaved round. The confirmation
  /// guards against an accidental tap on the delete affordance.
  Future<void> _confirmDeleteTournament(
    BuildContext context,
    Tournament tournament,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this tournament?'),
        content: Text(
          'Delete "${tournament.name}" and every round it created? This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _store!.deleteTournament(tournament.id);
    setState(() {
      _tournaments = _store!.listTournaments();
      _rounds = _store!.listRounds(excludeTournament: true);
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tournament deleted.')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    int id,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this round?'),
        content: Text('Delete "$label" permanently? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _store!.deleteRound(id);
    setState(() => _rounds = _store!.listRounds(excludeTournament: true));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Round deleted.')));
  }

  List<String> _decodeSeats(String raw) {
    try {
      final v = json.decode(raw);
      if (v is List) return [for (final e in v) '$e'];
    } catch (_) {}
    return const [];
  }

  void _openLive(BuildContext context, RoundController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _view == ScoreboardView.modern
            ? ModernScreen(controller: controller)
            : ClassicScreen(controller: controller),
      ),
    );
  }
}
