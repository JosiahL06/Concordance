import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../app/round_controller.dart';
import 'quiet_controls.dart';

/// The paper scoresheet's marks, rendered as a compact navigator: a row of
/// question numbers (current highlighted, interruption = ring, contest = "C",
/// void = strike-through) with a **point-value row** directly beneath it (D11).
/// Each value cell is an anchored popup menu — tap it to set the question's
/// 10/20/30-point value (overtime and already-answered slots are read-only).
class QuestionNavigator extends StatelessWidget {
  const QuestionNavigator({super.key, required this.round, this.height = 100});

  final RoundController round;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _cells((n) => _cell(context, n)),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _cells((n) => _valueCell(context, n)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Equal-width cells: the whole strip (plus any overtime slots) always fits
  /// the width, so the navigator never scrolls.
  List<Widget> _cells(Widget Function(int) build) => [
    for (var i = 0; i < round.questionCount; i++) ...[
      if (i > 0) const SizedBox(width: 6),
      Expanded(child: build(i + 1)),
    ],
  ];

  Widget _cell(BuildContext context, int n) {
    final scheme = Theme.of(context).colorScheme;
    final current = n - 1 == round.questionIndex;
    final past = n - 1 < round.questionIndex;
    final marks = round.view.questionMarks;
    final mark = n <= marks.length ? marks[n - 1] : null;
    final textColor = current
        ? scheme.onPrimary
        : past
        ? scheme.onSurface
        : scheme.outline;
    final bg = current ? scheme.primary : scheme.surfaceContainerHigh;

    Widget cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          text: '$n',
          style: TextStyle(
            fontSize: 16,
            fontWeight: current ? FontWeight.w900 : FontWeight.w600,
            color: textColor,
            decoration: mark?.voided == true
                ? TextDecoration.lineThrough
                : null,
          ),
          children: [
            if (mark?.contested == true)
              TextSpan(
                text: 'C',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: current ? scheme.onPrimary : scheme.tertiary,
                ),
              ),
          ],
        ),
      ),
    );

    if (mark?.interrupted == true) {
      // Paper sheet circles the interrupted question number.
      cell = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEF6C00), width: 2),
          borderRadius: BorderRadius.circular(11),
        ),
        child: cell,
      );
    }
    // The marks are carried by styling (ring, C, strikethrough), so spell
    // them out for screen readers: "Question 7, current, interrupted".
    final spoken = <String>['Question $n'];
    if (current) spoken.add('current');
    if (mark?.interrupted == true) spoken.add('interrupted');
    if (mark?.contested == true) spoken.add('contested');
    if (mark?.voided == true) spoken.add('voided');
    return Semantics(
      label: spoken.join(', '),
      excludeSemantics: true,
      child: cell,
    );
  }

  /// One point-value cell (D11). Editable regulation slots open an anchored
  /// popup menu; overtime / already-answered / voided slots read out only.
  Widget _valueCell(BuildContext context, int n) {
    final scheme = Theme.of(context).colorScheme;
    final value = round.view.questionValues[n - 1];
    final current = n - 1 == round.questionIndex;
    final editable = round.questionValueEditable(n);
    final unset = value == null;

    final bg = current ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final textColor = current
        ? scheme.onPrimaryContainer
        : unset
        ? scheme.outline
        : scheme.onSurfaceVariant;

    final cell = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Text(
        unset ? 'set' : '$value',
        style: TextStyle(
          fontSize: unset ? 12 : 14,
          fontWeight: current ? FontWeight.w900 : FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    if (!editable) {
      return Semantics(
        label: 'Question $n value ${unset ? 'unset' : '$value'}',
        excludeSemantics: true,
        child: cell,
      );
    }
    // Anchored floating menu (Option 2): the ruleset's allowed values.
    return PopupMenuButton<int>(
      tooltip: 'Set question $n point value',
      enableFeedback: false,
      padding: EdgeInsets.zero,
      onSelected: (v) => round.setQuestionValue(n, v),
      itemBuilder: (context) => [
        for (final v in round.valueOptions)
          QuietMenuItem<int>(value: v, child: Text('$v points')),
      ],
      child: cell,
    );
  }
}

/// Static (non-animated) banner for quiz-out alerts and limit warnings.
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    final alert = round.lastAlert;
    if (alert == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // liveRegion: TalkBack announces quiz-out / strike-out / limit alerts
    // once, when they appear — matching the engine's fire-once behavior.
    // The app itself never makes a sound doing so.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        color: scheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alert,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                hapticTick(context);
                round.clearAlert();
              },
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent strip shown while autosave is failing (see
/// [RoundController.saveError]).
///
/// Deliberately has **no** dismiss button: the condition is true until a save
/// actually succeeds, and letting a keeper clear it would let them hide the one
/// thing telling them the round is not on disk. It disappears by itself when the
/// next save works. Scoring stays enabled throughout — the round is still
/// playable, it is just not durable — so the wording says what is at stake
/// rather than telling the keeper to stop.
///
/// The raw exception text stays on the controller for diagnostics; only the
/// consequence is shown here, because a stack-trace fragment is no help to a
/// volunteer mid-match.
class SaveErrorBar extends StatelessWidget {
  const SaveErrorBar({super.key, required this.round});

  final RoundController round;

  @override
  Widget build(BuildContext context) {
    if (round.saveError == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // liveRegion: TalkBack announces the warning when it appears, matching the
    // fire-once behavior of the scoring alerts. The app makes no sound itself.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        color: scheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.save_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'NOT SAVING - this round is only in memory and will be lost '
                'if the app closes.',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
