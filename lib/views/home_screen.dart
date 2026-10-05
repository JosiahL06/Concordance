import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../app/round_controller.dart';
import '../app/settings.dart';
import '../data/round_store.dart';
import '../engine/events.dart';
import '../engine/ruleset.dart';
import 'classic_screen.dart';
import 'modern_screen.dart';
import 'setup_screen.dart';

/// Production home: start a new round, resume an autosaved round, or switch
/// the per-device scoreboard view. No demo seeding in prod (decision).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.prefs,
    this.store,
    this.presets,
  });

  final ViewPreference prefs;

  /// Injected store (tests / embedding). When null the screen opens the
  /// on-disk SQLite store itself.
  final RoundStore? store;

  /// Injected ruleset presets (tests); null loads via rootBundle.
  final List<Ruleset>? presets;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RoundStore? _store;
  List<Map<String, Object?>> _rounds = const [];
  ScoreboardView _view = ScoreboardView.modern;

  @override
  void initState() {
    super.initState();
    _view = widget.prefs.view;
    final injected = widget.store;
    if (injected != null) {
      _store = injected;
      _rounds = injected.listRounds();
    } else {
      _openStore();
    }
  }

  Future<void> _openStore() async {
    final store = await RoundStore.open();
    if (!mounted) {
      store.close();
      return;
    }
    setState(() {
      _store = store;
      _rounds = store.listRounds();
    });
  }

  @override
  void dispose() {
    // Only close a store we opened ourselves.
    if (widget.store == null) _store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Concordance')),
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
              SizedBox(
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _store == null ? null : () => _newRound(context),
                  child: const Text('START A NEW ROUND'),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ScoreboardView>(
                segments: const [
                  ButtonSegment(value: ScoreboardView.modern, label: Text('Modern')),
                  ButtonSegment(value: ScoreboardView.classic, label: Text('Classic')),
                ],
                selected: {_view},
                onSelectionChanged: (s) async {
                  setState(() => _view = s.first);
                  await widget.prefs.setView(s.first);
                },
              ),
              const SizedBox(height: 16),
              Text('Resume round', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_rounds.isEmpty)
                const Text('No saved rounds yet.'),
              for (final r in _rounds)
                Card(
                  child: ListTile(
                    title: Text('${r['red_name']} vs ${r['green_name']}'),
                    subtitle: Text('${r['ruleset_id']} \u00b7 ${r['created_at']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _resume(context, r['id'] as int),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newRound(BuildContext context) async {
    final result = await Navigator.of(context).push<SetupResult>(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          initialView: _view,
          presets: widget.presets,
        ),
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
    setState(() => _rounds = _store!.listRounds());
  }

  /// Creates the round row and installs the save hook: every journal change
  /// rewrites the event rows (rounds are tiny; correctness over cleverness).
  void _attachAutosave(RoundController controller) {
    final store = _store!;
    final id = store.createRound(
      rulesetId: controller.ruleset.id,
      redName: controller.redName,
      greenName: controller.greenName,
      redSeats: [
        for (final q in controller.teamOf(Side.red).quizzers) q.label,
      ],
      greenSeats: [
        for (final q in controller.teamOf(Side.green).quizzers) q.label,
      ],
    );
    controller.roundId = id;
    controller.autosave = (c) {
      store.truncateTo(id, 0);
      for (final e in c.view.journal) {
        store.appendEvent(id, e);
      }
    };
  }

  Future<void> _resume(BuildContext context, int id) async {
    final store = _store!;
    final row = store.loadRound(id);
    if (row == null) return;
    // Ruleset preset lookup by id (v1 ships two presets).
    final ruleset = await loadPreset(row['ruleset_id'] as String);
    if (ruleset == null || !context.mounted) return;
    final redSeats = _decodeSeats(row['red_seats'] as String);
    final greenSeats = _decodeSeats(row['green_seats'] as String);
    final controller = RoundController(
      ruleset: ruleset,
      redName: row['red_name'] as String,
      greenName: row['green_name'] as String,
      redSeats: redSeats,
      greenSeats: greenSeats,
    );
    for (final e in store.loadJournal(id)) {
      controller.view.apply(e);
    }
    controller.questionIndex = controller.firstOpenQuestion() - 1;
    controller.recomputeCompletion();
    controller.roundId = id;
    controller.autosave = (c) {
      store.truncateTo(id, 0);
      for (final e in c.view.journal) {
        store.appendEvent(id, e);
      }
    };
    _openLive(context, controller);
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

