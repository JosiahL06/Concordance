import 'package:flutter/material.dart';

import '../app/presets.dart';
import '../engine/ruleset.dart';
import '../tournament/tournament_models.dart';

/// Result of tournament setup. The caller persists this draft and opens the
/// tournament dashboard.
class TournamentDraft {
  const TournamentDraft({
    required this.name,
    required this.ruleset,
    required this.matchCount,
    required this.teamName,
    required this.members,
  });

  final String name;
  final Ruleset ruleset;
  final int matchCount;
  final String teamName;
  final List<TournamentMemberInput> members;
}

/// New-tournament form: ruleset, fixed match count, and the tracked team's
/// stable roster/seat order. The opponent is entered per match later.
class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key, this.presets});

  final List<Ruleset>? presets;

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final TextEditingController tournamentName = TextEditingController();
  final TextEditingController teamName = TextEditingController(text: 'Team');
  final List<TextEditingController> seatNames = <TextEditingController>[];
  final List<TextEditingController> benchNames = <TextEditingController>[];

  List<Ruleset>? _presets;
  String? _loadError;
  int rulesetIndex = 0;
  int matchCount = 6;
  int seatedCount = 3;
  int benchCount = 0;

  @override
  void initState() {
    super.initState();
    final injected = widget.presets;
    if (injected != null) {
      _presets = injected;
      _clampToRuleset(injected[rulesetIndex]);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final loaded = await loadPresets();
      if (!mounted) return;
      setState(() {
        _presets = loaded;
        _clampToRuleset(loaded[rulesetIndex]);
      });
    } on PresetLoadFailure catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  void dispose() {
    tournamentName.dispose();
    teamName.dispose();
    for (final controller in [...seatNames, ...benchNames]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clampToRuleset(Ruleset ruleset) {
    seatedCount = seatedCount.clamp(
      ruleset.match.minActivePerTeam,
      ruleset.match.maxActivePerTeam,
    );
    final benchCap = ruleset.match.benchCapacity(seatedCount);
    if (benchCap != null) {
      benchCount = benchCount.clamp(0, benchCap < 0 ? 0 : benchCap);
    }
    _syncNames(seatNames, seatedCount);
    _syncNames(benchNames, benchCount);
  }

  void _syncNames(List<TextEditingController> list, int count) {
    while (list.length < count) {
      list.add(TextEditingController());
    }
    while (list.length > count) {
      list.removeLast().dispose();
    }
  }

  String get _teamLabel =>
      teamName.text.trim().isEmpty ? 'Team' : teamName.text.trim();

  String _name(List<TextEditingController> list, int index, String fallback) {
    final text = list[index].text.trim();
    return text.isEmpty ? fallback : text;
  }

  void _create() {
    final presets = _presets;
    if (presets == null) return;
    final members = <TournamentMemberInput>[
      for (var i = 0; i < seatedCount; i++)
        TournamentMemberInput(
          name: _name(seatNames, i, '$_teamLabel ${i + 1}'),
          rosterIndex: i,
          defaultSeat: i + 1,
        ),
      for (var i = 0; i < benchCount; i++)
        TournamentMemberInput(
          name: _name(benchNames, i, '$_teamLabel ${seatedCount + i + 1}'),
          rosterIndex: seatedCount + i,
          defaultSeat: 0,
        ),
    ];
    Navigator.of(context).pop(
      TournamentDraft(
        name: tournamentName.text.trim().isEmpty
            ? 'Tournament'
            : tournamentName.text.trim(),
        ruleset: presets[rulesetIndex],
        matchCount: matchCount,
        teamName: _teamLabel,
        members: members,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final presets = _presets;
    return Scaffold(
      appBar: AppBar(title: const Text('New tournament')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loadError != null)
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load rulesets: $_loadError',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (presets == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Loading rulesets…')),
                )
              else ...[
                TextField(
                  controller: tournamentName,
                  decoration: const InputDecoration(
                    labelText: 'Tournament name',
                    hintText: 'e.g. Fall Invitational',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _matchCountCard(scheme),
                const SizedBox(height: 16),
                _rulesetCard(context, presets),
                const SizedBox(height: 16),
                _teamCard(context),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _create,
                    child: const Text('CREATE TOURNAMENT'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _matchCountCard(ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Matches',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text('The tournament has this many scheduled matches.'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fewer matches',
              onPressed: matchCount > 1
                  ? () => setState(() => matchCount -= 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              '$matchCount',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            IconButton(
              tooltip: 'More matches',
              onPressed: matchCount < 50
                  ? () => setState(() => matchCount += 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesetCard(BuildContext context, List<Ruleset> presets) {
    final scheme = Theme.of(context).colorScheme;
    final ruleset = presets[rulesetIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruleset',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < presets.length; i++)
                  ButtonSegment<int>(
                    value: i,
                    label: Text(presets[i].displayName),
                  ),
              ],
              selected: {rulesetIndex},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  rulesetIndex = selection.single;
                  _clampToRuleset(presets[rulesetIndex]);
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${ruleset.displayName} ${ruleset.season} · '
              '${ruleset.match.regulationQuestions} questions · '
              '${ruleset.match.minActivePerTeam}–'
              '${ruleset.match.maxActivePerTeam} seated per team',
              style: TextStyle(color: scheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              'Values: ${ruleset.match.valueCounts.entries.map((e) => '${e.key}×${e.value}').join(', ')}',
              style: TextStyle(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ruleset = _presets![rulesetIndex];
    final benchCap = ruleset.match.benchCapacity(seatedCount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your team',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'This team is carried into every match. You will choose Red or '
              'Green and enter the opponent each time.',
              style: TextStyle(color: scheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teamName,
              decoration: const InputDecoration(
                labelText: 'Team name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Seated: '),
                IconButton(
                  tooltip: 'Fewer seated quizzers',
                  onPressed: seatedCount > ruleset.match.minActivePerTeam
                      ? () => setState(() {
                          seatedCount -= 1;
                          _clampToRuleset(ruleset);
                        })
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$seatedCount'),
                IconButton(
                  tooltip: 'More seated quizzers',
                  onPressed: seatedCount < ruleset.match.maxActivePerTeam
                      ? () => setState(() {
                          seatedCount += 1;
                          _clampToRuleset(ruleset);
                        })
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                const Text('Bench: '),
                IconButton(
                  tooltip: 'Fewer bench quizzers',
                  onPressed: benchCount > 0
                      ? () => setState(() {
                          benchCount -= 1;
                          _clampToRuleset(ruleset);
                        })
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$benchCount'),
                IconButton(
                  tooltip: 'More bench quizzers',
                  onPressed: benchCap == null || benchCount < benchCap
                      ? () => setState(() {
                          benchCount += 1;
                          _clampToRuleset(ruleset);
                        })
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < seatedCount; i++)
              _memberField(
                label: 'Seat ${i + 1}',
                hint: '$_teamLabel ${i + 1}',
                controller: seatNames[i],
              ),
            if (benchCount > 0) ...[
              const Divider(height: 24),
              Text(
                'BENCH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < benchCount; i++)
                _memberField(
                  label: 'Bench ${i + 1}',
                  hint: '$_teamLabel ${seatedCount + i + 1}',
                  controller: benchNames[i],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
