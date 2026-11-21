import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../engine/events.dart';
import '../engine/ruleset.dart';
import '../tournament/tournament_models.dart';
import 'common/haptics_toggle.dart';
import 'common/scoreboard_view_picker.dart';
import 'common/theme_toggle.dart';

/// What the dashboard needs after the match setup is confirmed.
class TournamentMatchSetupResult {
  const TournamentMatchSetupResult({required this.start, required this.view});

  final TournamentMatchStart start;
  final ScoreboardView view;
}

/// Match setup: pick the tracked team's side, confirm the pre-filled lineup,
/// and enter the opponent. Returns a [TournamentMatchSetupResult] for the
/// tournament screen to persist atomically.
class TournamentMatchSetupScreen extends StatefulWidget {
  const TournamentMatchSetupScreen({
    super.key,
    required this.tournament,
    required this.match,
    required this.ruleset,
    required this.members,
    required this.initialView,
  });

  final Tournament tournament;
  final TournamentMatch match;
  final Ruleset ruleset;
  final List<TournamentMember> members;
  final ScoreboardView initialView;

  @override
  State<TournamentMatchSetupScreen> createState() =>
      _TournamentMatchSetupScreenState();
}

class _TournamentMatchSetupScreenState
    extends State<TournamentMatchSetupScreen> {
  final TextEditingController opponentName = TextEditingController(
    text: 'Opponent',
  );
  final List<TextEditingController> opponentSeatNames = [];
  final List<TextEditingController> opponentBenchNames = [];
  Side side = Side.red;
  int seatedCount = 3;
  int benchCount = 0;
  late ScoreboardView _view;
  final Map<int, int> _positions = <int, int>{};

  List<TournamentMember> get _seatedMembers {
    final list = [
      for (final member in widget.members)
        if (!member.archived && (_positions[member.id] ?? 0) > 0) member,
    ];
    list.sort((a, b) => _positions[a.id]!.compareTo(_positions[b.id]!));
    return list;
  }

  List<TournamentMember> get _benchMembers {
    final list = [
      for (final member in widget.members)
        if (!member.archived && (_positions[member.id] ?? 0) == 0) member,
    ];
    list.sort((a, b) => a.rosterIndex.compareTo(b.rosterIndex));
    return list;
  }

  List<TournamentMember> get _activeMembers => [
    for (final member in widget.members)
      if (!member.archived) member,
  ];

  bool get _lineupValid =>
      _seatedMembers.length >= widget.ruleset.match.minActivePerTeam &&
      _seatedMembers.length <= widget.ruleset.match.maxActivePerTeam;

  void _setPosition(int memberId, int next) {
    final current = _positions[memberId] ?? 0;
    if (next > 0) {
      final occupant = _positions.entries
          .where((entry) => entry.key != memberId && entry.value == next)
          .firstOrNull;
      if (occupant != null) {
        _positions[occupant.key] = current;
      }
    }
    setState(() => _positions[memberId] = next);
  }

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    for (final member in widget.members) {
      if (member.archived) continue;
      _positions[member.id] = member.defaultSeat.clamp(
        0,
        widget.ruleset.match.maxActivePerTeam,
      );
    }
    seatedCount = _seatedMembers.length.clamp(
      widget.ruleset.match.minActivePerTeam,
      widget.ruleset.match.maxActivePerTeam,
    );
    final cap = widget.ruleset.match.benchCapacity(seatedCount);
    benchCount = _benchMembers.length;
    if (cap != null) benchCount = benchCount.clamp(0, cap < 0 ? 0 : cap);
    _syncNames(opponentSeatNames, seatedCount);
    _syncNames(opponentBenchNames, benchCount);
  }

  @override
  void dispose() {
    opponentName.dispose();
    for (final controller in [...opponentSeatNames, ...opponentBenchNames]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncNames(List<TextEditingController> list, int count) {
    while (list.length < count) {
      list.add(TextEditingController());
    }
    while (list.length > count) {
      list.removeLast().dispose();
    }
  }

  String get _opponentLabel =>
      opponentName.text.trim().isEmpty ? 'Opponent' : opponentName.text.trim();

  String _name(List<TextEditingController> list, int index, String fallback) {
    final text = list[index].text.trim();
    return text.isEmpty ? fallback : text;
  }

  void _start() {
    final seated = _seatedMembers;
    final bench = _benchMembers;
    if (!_lineupValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seat at least ${widget.ruleset.match.minActivePerTeam} quizzers.',
          ),
        ),
      );
      return;
    }
    final trackedSeats = [for (final member in seated) member.name];
    final trackedBench = [for (final member in bench) member.name];
    final opponentSeats = [
      for (var i = 0; i < seatedCount; i++)
        _name(opponentSeatNames, i, '$_opponentLabel ${i + 1}'),
    ];
    final opponentBench = [
      for (var i = 0; i < benchCount; i++)
        _name(opponentBenchNames, i, '$_opponentLabel ${seatedCount + i + 1}'),
    ];
    final links = <TournamentMemberLinkInput>[
      for (var i = 0; i < seated.length; i++)
        TournamentMemberLinkInput(
          side: side,
          rosterIndex: i,
          memberId: seated[i].id,
        ),
      for (var i = 0; i < bench.length; i++)
        TournamentMemberLinkInput(
          side: side,
          rosterIndex: seated.length + i,
          memberId: bench[i].id,
        ),
    ];
    final trackedName = widget.tournament.teamName;
    Navigator.of(context).pop(
      TournamentMatchSetupResult(
        view: _view,
        start: TournamentMatchStart(
          trackedSide: side,
          opponentName: _opponentLabel,
          redName: side == Side.red ? trackedName : _opponentLabel,
          greenName: side == Side.green ? trackedName : _opponentLabel,
          redSeats: side == Side.red ? trackedSeats : opponentSeats,
          greenSeats: side == Side.green ? trackedSeats : opponentSeats,
          redBench: side == Side.red ? trackedBench : opponentBench,
          greenBench: side == Side.green ? trackedBench : opponentBench,
          links: links,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Match ${widget.match.matchNumber} setup'),
        actions: const [ThemeToggleButton(), HapticsToggleButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.tournament.name} \u00b7 '
                  'Match ${widget.match.matchNumber}',
                  style: TextStyle(color: scheme.outline),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your side',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _sideCard(
                        context,
                        Side.red,
                        'RED',
                        const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _sideCard(
                        context,
                        Side.green,
                        'GREEN',
                        const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 880;
                    final red = _teamColumn(
                      context,
                      Side.red,
                      const Color(0xFFC62828),
                    );
                    final green = _teamColumn(
                      context,
                      Side.green,
                      const Color(0xFF2E7D32),
                    );
                    if (!wide) {
                      return Column(
                        children: [red, const SizedBox(height: 12), green],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: red),
                          const SizedBox(width: 12),
                          Expanded(child: green),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Starting view',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ScoreboardViewPicker(
                  value: _view,
                  onChanged: (view) => setState(() => _view = view),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _lineupValid ? _start : null,
                    child: const Text('START MATCH'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamColumn(BuildContext context, Side teamSide, Color color) {
    final tracked = side == teamSide;
    final scheme = Theme.of(context).colorScheme;
    final label = teamSide == Side.red ? 'RED TEAM' : 'GREEN TEAM';
    return Card(
      key: ValueKey('tournament-team-${teamSide.name}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: tracked ? 0.55 : 0.3),
          width: tracked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tracked
                        ? color.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tracked
                          ? color.withValues(alpha: 0.5)
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    tracked ? 'YOU' : 'OPPONENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: tracked ? color : scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tracked) _trackedTeam(context) else _opponentTeam(context),
          ],
        ),
      ),
    );
  }

  Widget _trackedTeam(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.tournament.teamName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Lineup for this match',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final member in _activeMembers)
          Row(
            children: [
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownButton<int>(
                value: _positions[member.id] ?? 0,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text('Not playing'),
                  ),
                  const DropdownMenuItem<int>(value: 0, child: Text('Bench')),
                  for (
                    var seat = 1;
                    seat <= widget.ruleset.match.maxActivePerTeam;
                    seat++
                  )
                    DropdownMenuItem<int>(
                      value: seat,
                      child: Text('Seat $seat'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _setPosition(member.id, value);
                  }
                },
              ),
            ],
          ),
        if (!_lineupValid)
          Text(
            'Seat at least '
            '${widget.ruleset.match.minActivePerTeam} quizzers.',
            style: TextStyle(color: scheme.error),
          ),
      ],
    );
  }

  Widget _opponentTeam(BuildContext context) {
    final ruleset = widget.ruleset;
    final benchCap = ruleset.match.benchCapacity(seatedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: opponentName,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Opponent team name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Seated: '),
                IconButton(
                  tooltip: 'Fewer seated quizzers',
                  onPressed: seatedCount > ruleset.match.minActivePerTeam
                      ? () => setState(() {
                          seatedCount -= 1;
                          _syncNames(opponentSeatNames, seatedCount);
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
                          _syncNames(opponentSeatNames, seatedCount);
                        })
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bench: '),
                IconButton(
                  tooltip: 'Fewer bench quizzers',
                  onPressed: benchCount > 0
                      ? () => setState(() {
                          benchCount -= 1;
                          _syncNames(opponentBenchNames, benchCount);
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
                          _syncNames(opponentBenchNames, benchCount);
                        })
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        for (var i = 0; i < seatedCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: opponentSeatNames[i],
              decoration: InputDecoration(
                labelText: 'Opponent seat ${i + 1}',
                hintText: '$_opponentLabel ${i + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        for (var i = 0; i < benchCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: opponentBenchNames[i],
              decoration: InputDecoration(
                labelText: 'Opponent bench ${i + 1}',
                hintText: '$_opponentLabel ${seatedCount + i + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sideCard(
    BuildContext context,
    Side value,
    String label,
    Color color,
  ) {
    final selected = side == value;
    final scheme = Theme.of(context).colorScheme;
    final spoken = value == Side.red ? 'Red' : 'Green';
    return Semantics(
      button: true,
      selected: selected,
      label: '$spoken side for ${widget.tournament.teamName}',
      excludeSemantics: true,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => side = value),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
