import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:concordance/engine/ruleset.dart';

import 'direction_a_screen.dart';
import 'direction_b_screen.dart';
import 'fake_round.dart';

/// New Round setup: ruleset tabs loaded from the REAL presets, team rosters
/// with seat labels, and the Modern/Classic view pick. Builds a
/// [RoundConfig] and starts the live scoring screen (connected flow).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.demo = false});

  final bool demo;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _presetIds = <String>['tbq-25-26', 'jbq-2026'];

  final TextEditingController redName = TextEditingController(text: 'Red');
  final TextEditingController greenName = TextEditingController(text: 'Green');
  int redCount = 3;
  int greenCount = 3;
  ViewMode viewMode = ViewMode.modern;
  int rulesetIndex = 0;

  List<Ruleset>? _presets;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final loaded = <Ruleset>[];
      for (final id in _presetIds) {
        final raw = await rootBundle.loadString('assets/rulesets/$id.json');
        loaded.add(Ruleset.fromJson(json.decode(raw) as Map<String, Object?>));
      }
      if (mounted) setState(() => _presets = loaded);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load presets: $e');
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
    final config = RoundConfig(
      ruleset: ruleset,
      redName: _redLabel,
      greenName: _greenLabel,
      redSeats: [for (var i = 1; i <= redCount; i++) '$_redLabel $i'],
      greenSeats: [for (var i = 1; i <= greenCount; i++) '$_greenLabel $i'],
      viewMode: viewMode,
      demo: widget.demo,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => viewMode == ViewMode.modern
            ? DirectionAScreen(config: config)
            : DirectionBScreen(config: config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets;
    return DefaultTabController(
      length: _presetIds.length,
      initialIndex: rulesetIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.demo ? 'Load demo round' : 'New round'),
          bottom: presets == null
              ? null
              : TabBar(
                  onTap: (i) => setState(() => rulesetIndex = i),
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
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_loadError!, textAlign: TextAlign.center),
      );
    }
    if (presets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ruleset = presets[rulesetIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Ruleset'),
          _rulesetCard(ruleset),
          const SizedBox(height: 20),
          _sectionTitle('Teams'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _teamPanel(
                  ruleset: ruleset,
                  color: const Color(0xFFC62828),
                  tint: const Color(0xFFFCE8E6),
                  controller: redName,
                  count: redCount,
                  onAdd: () => setState(() => redCount += 1),
                  onRemove: () => setState(
                    () => redCount = redCount > 1 ? redCount - 1 : 1,
                  ),
                  label: _redLabel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _teamPanel(
                  ruleset: ruleset,
                  color: const Color(0xFF2E7D32),
                  tint: const Color(0xFFE6F4EA),
                  controller: greenName,
                  count: greenCount,
                  onAdd: () => setState(() => greenCount += 1),
                  onRemove: () => setState(
                    () => greenCount = greenCount > 1 ? greenCount - 1 : 1,
                  ),
                  label: _greenLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('Scoreboard view'),
          Row(
            children: [
              Expanded(
                child: _modeCard(
                  mode: ViewMode.modern,
                  icon: Icons.view_column_outlined,
                  title: 'Modern',
                  subtitle: 'Split field: red left, green right',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _modeCard(
                  mode: ViewMode.classic,
                  icon: Icons.grid_on_outlined,
                  title: 'Classic',
                  subtitle: 'Scoresheet ledger: quizzers × questions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _start,
                    child: Text(
                      widget.demo ? 'START DEMO ROUND' : 'START ROUND',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 64,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _rulesetCard(Ruleset r) {
    final vals = r.match.pointValues;
    final tens = vals.where((v) => v == 10).length;
    final twenties = vals.where((v) => v == 20).length;
    final thirties = vals.where((v) => v == 30).length;
    final challenge = r.challengeKind == ChallengeKind.contest
        ? 'Contests'
        : "Coach's Appeals";
    final challengeRule =
        r.limits.challengeLimitMode == ChallengeLimitMode.unsuccessful
        ? "notify on a team's 3rd unsuccessful; then rejected"
        : '${r.limits.challengeAllotmentPerTeam} per team; then rejected';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final v in vals) _valueChip(v)],
            ),
            const SizedBox(height: 12),
            Text(
              '${vals.length} questions · $tens×10 · '
              '$twenties×20 · $thirties×30',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _ruleRow(
              'Quiz out',
              '${r.scoring.quizOutCorrect} correct '
                  '→ +${r.scoring.quizOutBonus} bonus'
                  '${r.scoring.quizOutLeavesMatch ? ' (leaves the match)' : ''}',
            ),
            _ruleRow('Strike out', '${r.scoring.strikeOutIncorrect} incorrect'),
            _ruleRow(
              'Fouls',
              '-${r.scoring.foulDeduction} each; '
                  '${r.scoring.foulsToFoulOut} = foul out; '
                  'team foul -${r.scoring.teamFoulDeduction}',
            ),
            _ruleRow(
              'Time-outs',
              '${r.limits.timeOutsPerTeam} per team — notify on the '
                  '${_ordinal(r.limits.notifyTimeOutRequest)} request',
            ),
            _ruleRow(challenge, challengeRule),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }

  Widget _valueChip(int v) {
    return Container(
      width: 44,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$v',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _teamPanel({
    required Ruleset ruleset,
    required Color color,
    required Color tint,
    required TextEditingController controller,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    required String label,
  }) {
    final max = ruleset.match.maxActivePerTeam;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Team name',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'QUIZZERS — $count of $max at the table',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 1; i <= count; i++)
                Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$label $i',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (count > 1)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 20,
                          onPressed: onRemove,
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove $label $i',
                        ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: count < max ? onAdd : null,
                icon: const Icon(Icons.add),
                label: const Text('Add quizzer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required ViewMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = viewMode == mode;
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
        onTap: () => setState(() => viewMode = mode),
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
