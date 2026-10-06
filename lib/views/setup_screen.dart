import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../app/round_controller.dart';
import '../app/settings.dart';
import '../engine/ruleset.dart';
import 'common/theme_toggle.dart';

/// Result of setup: the ready-to-run round plus the view the keeper picked
/// for this session (overrides the per-device setting for the round).
class SetupResult {
  const SetupResult({required this.controller, required this.view});

  final RoundController controller;
  final ScoreboardView view;
}

/// Production New Round setup: ruleset tabs from the real presets, team
/// names, roster counts clamped to the ruleset min/max, and the
/// Modern/Classic pick (per-session override of the per-device setting).
/// Returns a [SetupResult] via Navigator.pop (no demo seeding in prod).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.initialView, this.presets});

  final ScoreboardView initialView;

  /// Injected presets (tests). When null the screen loads
  /// `assets/rulesets/*.json` via rootBundle.
  final List<Ruleset>? presets;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController redName = TextEditingController(text: 'Red');
  final TextEditingController greenName = TextEditingController(
    text: 'Green',
  );
  int redCount = 3;
  int greenCount = 3;
  late ScoreboardView _view;
  int rulesetIndex = 0;

  List<Ruleset>? _presets;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    final injected = widget.presets;
    if (injected != null) {
      _presets = injected;
      _clampCounts(injected[rulesetIndex]);
    } else {
      _load();
    }
  }

  void _clampCounts(Ruleset r) {
    redCount = redCount.clamp(
      r.match.minActivePerTeam,
      r.match.maxActivePerTeam,
    );
    greenCount = greenCount.clamp(
      r.match.minActivePerTeam,
      r.match.maxActivePerTeam,
    );
  }

  Future<void> _load() async {
    try {
      final loaded = await loadPresets();
      if (!mounted) return;
      setState(() {
        _presets = loaded;
        _clampCounts(loaded[rulesetIndex]);
      });
    } on PresetLoadFailure catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  void dispose() {
    redName.dispose();
    greenName.dispose();
    super.dispose();
  }

  String get _redLabel =>
      redName.text.trim().isEmpty ? 'Red' : redName.text.trim();
  String get _greenLabel =>
      greenName.text.trim().isEmpty ? 'Green' : greenName.text.trim();

  void _start() {
    final ruleset = _presets![rulesetIndex];
    Navigator.of(context).pop(
      SetupResult(
        controller: RoundController(
          ruleset: ruleset,
          redName: _redLabel,
          greenName: _greenLabel,
          redSeats: [for (var i = 1; i <= redCount; i++) '$_redLabel $i'],
          greenSeats: [
            for (var i = 1; i <= greenCount; i++) '$_greenLabel $i',
          ],
        ),
        view: _view,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets;
    return DefaultTabController(
      length: presetIds.length,
      initialIndex: rulesetIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New round'),
          actions: const [ThemeToggleButton()],
          bottom: presets == null
              ? null
              : TabBar(
                  onTap: (i) => setState(() {
                    rulesetIndex = i;
                    _clampCounts(presets[i]);
                  }),
                  tabs: [
                    for (final r in presets)
                      Tab(text: '${r.displayName} ${r.season}'),
                  ],
                ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: _body(presets),
          ),
        ),
      ),
    );
  }

  Widget _body(List<Ruleset>? presets) {
    if (_loadError != null) return Center(child: Text(_loadError!));
    if (presets == null) {
      // Static placeholder, not a spinner: an indeterminate animation would
      // never settle (and the project favors no decorative motion).
      return const Center(child: Text('Loading rulesets…'));
    }
    final ruleset = presets[rulesetIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rulesCard(ruleset),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _teamCard(
                  label: 'Red team',
                  color: const Color(0xFFC62828),
                  nameController: redName,
                  count: redCount,
                  min: ruleset.match.minActivePerTeam,
                  max: ruleset.match.maxActivePerTeam,
                  onCount: (v) => setState(() => redCount = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _teamCard(
                  label: 'Green team',
                  color: const Color(0xFF2E7D32),
                  nameController: greenName,
                  count: greenCount,
                  min: ruleset.match.minActivePerTeam,
                  max: ruleset.match.maxActivePerTeam,
                  onCount: (v) => setState(() => greenCount = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  mode: ScoreboardView.modern,
                  icon: Icons.dashboard_outlined,
                  title: 'Modern',
                  subtitle: 'Split-field spatial layout.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _modeCard(
                  mode: ScoreboardView.classic,
                  icon: Icons.table_chart_outlined,
                  title: 'Classic',
                  subtitle: 'Paper-style scoresheet ledger.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: _start,
              child: const Text(
                'START ROUND',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard(Ruleset r) {
    final tens = r.match.pointValues.where((v) => v == 10).length;
    final twenties = r.match.pointValues.where((v) => v == 20).length;
    final thirties = r.match.pointValues.where((v) => v == 30).length;
    final challenge = r.challengeKind == ChallengeKind.contest
        ? 'Contests'
        : "Coach's Appeals";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.displayName} ${r.season}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _ruleRow(
                  'Questions',
                  '${r.match.regulationQuestions} '
                  '($tens/10s $twenties/20s $thirties/30s)',
                ),
                _ruleRow(
                  'Quiz-out',
                  '${r.scoring.quizOutCorrect} correct '
                  '+${r.scoring.quizOutBonus}',
                ),
                _ruleRow(
                  'Strike-out',
                  '${r.scoring.strikeOutIncorrect} incorrect',
                ),
                _ruleRow('Foul', '-${r.scoring.foulDeduction}'),
                _ruleRow(
                  'Time-outs',
                  '${r.limits.timeOutsPerTeam} per team, notify on '
                  '${_ordinal(r.limits.notifyTimeOutRequest)}',
                ),
                _ruleRow(challenge, _challengeSummary(r)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _challengeSummary(Ruleset r) {
    if (r.challengeKind == ChallengeKind.contest) {
      return 'notify on ${_ordinal(r.limits.challengeLimitCount)} '
          'unsuccessful';
    }
    final max =
        r.limits.challengeAllotmentPerTeam ?? r.limits.challengeLimitCount;
    return 'max $max per team';
  }

  Widget _ruleRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _teamCard({
    required String label,
    required Color color,
    required TextEditingController nameController,
    required int count,
    required int min,
    required int max,
    required ValueChanged<int> onCount,
  }) {
    final fallback = label.split(' ').first;
    final stem = nameController.text.trim().isEmpty
        ? fallback
        : nameController.text.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Team name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quizzers: '),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'Fewer quizzers',
                  onPressed: count > min ? () => onCount(count - 1) : null,
                ),
                Text('$count', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'More quizzers',
                  onPressed: count < max ? () => onCount(count + 1) : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 1; i <= count; i++)
                  Chip(
                    label: Text('$stem $i'),
                    side: BorderSide(color: color),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard({
    required ScoreboardView mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _view == mode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _view = mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ordinal(int n) => switch (n) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    4 => '4th',
    _ => '${n}th',
  };
}
