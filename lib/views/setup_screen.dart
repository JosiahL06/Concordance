import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../app/round_controller.dart';
import '../app/settings.dart';
import '../engine/ruleset.dart';
import 'common/haptics_toggle.dart';
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
  final TextEditingController greenName = TextEditingController(text: 'Green');
  int redCount = 3;
  int greenCount = 3;
  int redBenchCount = 0;
  int greenBenchCount = 0;
  late ScoreboardView _view;
  int rulesetIndex = 0;

  /// Per-quizzer name fields, decoupled from the team name. A blank field
  /// falls back to `<Team> N` at start, so the team name stays a convenient
  /// default rather than the only way to identify a quizzer. Bench quizzers
  /// are named the same way and start behind the table.
  final List<TextEditingController> redSeatNames = [];
  final List<TextEditingController> greenSeatNames = [];
  final List<TextEditingController> redBenchNames = [];
  final List<TextEditingController> greenBenchNames = [];

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
    redBenchCount = _clampBench(r, redCount, redBenchCount);
    greenBenchCount = _clampBench(r, greenCount, greenBenchCount);
    _syncSeatNames(redSeatNames, redCount);
    _syncSeatNames(greenSeatNames, greenCount);
    _syncSeatNames(redBenchNames, redBenchCount);
    _syncSeatNames(greenBenchNames, greenBenchCount);
  }

  /// Clamps a team's bench count to its roster capacity (uncapped when the
  /// rulebook sets no roster maximum).
  int _clampBench(Ruleset r, int seated, int bench) {
    final cap = r.match.benchCapacity(seated);
    if (cap == null) return bench < 0 ? 0 : bench;
    return bench.clamp(0, cap < 0 ? 0 : cap);
  }

  /// Grows/shrinks a per-seat controller list to [count] without losing names
  /// already typed.
  void _syncSeatNames(List<TextEditingController> names, int count) {
    while (names.length < count) {
      names.add(TextEditingController());
    }
    while (names.length > count) {
      names.removeLast().dispose();
    }
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
    for (final list in <List<TextEditingController>>[
      redSeatNames,
      greenSeatNames,
      redBenchNames,
      greenBenchNames,
    ]) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// A quizzer's display name: the entered name, or [fallback] when blank.
  String _name(List<TextEditingController> names, int n, String fallback) {
    final text = names[n - 1].text.trim();
    return text.isEmpty ? fallback : text;
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
          redSeats: [
            for (var i = 1; i <= redCount; i++)
              _name(redSeatNames, i, '$_redLabel $i'),
          ],
          greenSeats: [
            for (var i = 1; i <= greenCount; i++)
              _name(greenSeatNames, i, '$_greenLabel $i'),
          ],
          // Bench quizzers continue the team's numbering after the seated ones.
          redBench: [
            for (var i = 1; i <= redBenchCount; i++)
              _name(redBenchNames, i, '$_redLabel ${redCount + i}'),
          ],
          greenBench: [
            for (var i = 1; i <= greenBenchCount; i++)
              _name(greenBenchNames, i, '$_greenLabel ${greenCount + i}'),
          ],
        ),
        view: _view,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New round'),
        actions: const [ThemeToggleButton(), HapticsToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: _body(presets),
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
          _rulesetSelector(presets),
          const SizedBox(height: 12),
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
                  seatControllers: redSeatNames,
                  count: redCount,
                  min: ruleset.match.minActivePerTeam,
                  max: ruleset.match.maxActivePerTeam,
                  onCount: (v) => setState(() {
                    redCount = v;
                    // A smaller table enlarges the bench capacity, but a larger
                    // one shrinks it, so re-clamp the bench too.
                    redBenchCount = _clampBench(ruleset, v, redBenchCount);
                    _syncSeatNames(redSeatNames, v);
                    _syncSeatNames(redBenchNames, redBenchCount);
                  }),
                  benchControllers: redBenchNames,
                  benchCount: redBenchCount,
                  benchCap: ruleset.match.benchCapacity(redCount),
                  onBenchCount: (v) => setState(() {
                    redBenchCount = v;
                    _syncSeatNames(redBenchNames, v);
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _teamCard(
                  label: 'Green team',
                  color: const Color(0xFF2E7D32),
                  nameController: greenName,
                  seatControllers: greenSeatNames,
                  count: greenCount,
                  min: ruleset.match.minActivePerTeam,
                  max: ruleset.match.maxActivePerTeam,
                  onCount: (v) => setState(() {
                    greenCount = v;
                    greenBenchCount = _clampBench(ruleset, v, greenBenchCount);
                    _syncSeatNames(greenSeatNames, v);
                    _syncSeatNames(greenBenchNames, greenBenchCount);
                  }),
                  benchControllers: greenBenchNames,
                  benchCount: greenBenchCount,
                  benchCap: ruleset.match.benchCapacity(greenCount),
                  onBenchCount: (v) => setState(() {
                    greenBenchCount = v;
                    _syncSeatNames(greenBenchNames, v);
                  }),
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

  /// Ruleset pick as an ordinary settings row (was an AppBar tab bar): it sits
  /// with the rest of the round settings for visual unity. Switching clamps
  /// the roster counts to the new preset's min/max.
  Widget _rulesetSelector(List<Ruleset> presets) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ruleset', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < presets.length; i++)
                    ButtonSegment(
                      value: i,
                      label: Text(
                        '${presets[i].displayName} ${presets[i].season}',
                      ),
                    ),
                ],
                selected: {rulesetIndex},
                onSelectionChanged: (s) => setState(() {
                  rulesetIndex = s.first;
                  _clampCounts(presets[rulesetIndex]);
                }),
              ),
            ),
          ],
        ),
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
                      '${_ordinal(r.limits.notifyTimeOutRequest)}'
                      '${_overtimeTimeOutNote(r.limits)}',
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

  /// Overtime time-out rule appended to the Time-outs row (TBQ: none may be
  /// used in overtime; JBQ: remaining carry plus the extra allotment).
  String _overtimeTimeOutNote(LimitsConfig limits) {
    if (!limits.overtimeTimeOutsCarry) {
      return '; none in overtime';
    }
    if (limits.overtimeExtraTimeOuts > 0) {
      return '; overtime: remaining '
          '+${limits.overtimeExtraTimeOuts}';
    }
    return '; overtime: remaining carry';
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
    required List<TextEditingController> seatControllers,
    required int count,
    required int min,
    required int max,
    required ValueChanged<int> onCount,
    required List<TextEditingController> benchControllers,
    required int benchCount,
    required int? benchCap,
    required ValueChanged<int> onBenchCount,
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
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Seated: '),
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
            // One name field per seat: a quizzer's identity is independent of
            // the team name. A blank field falls back to "<Team> N".
            for (var i = 0; i < seatControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: seatControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Quizzer ${i + 1}',
                    hintText: '$stem ${i + 1}',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Text('Bench: '),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'Fewer bench quizzers',
                  onPressed: benchCount > 0
                      ? () => onBenchCount(benchCount - 1)
                      : null,
                ),
                Text(
                  '$benchCount',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'More bench quizzers',
                  onPressed: (benchCap == null || benchCount < benchCap)
                      ? () => onBenchCount(benchCount + 1)
                      : null,
                ),
              ],
            ),
            Text(
              benchCap == null
                  ? 'Behind the table; substitute in during play.'
                  : 'Behind the table (up to $benchCap); substitute in '
                        'during play.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < benchControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: benchControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Bench ${i + 1}',
                    hintText: '$stem ${count + i + 1}',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                    isDense: true,
                  ),
                ),
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
        enableFeedback: false,
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
