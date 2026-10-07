import 'package:flutter/material.dart';

import '../../app/haptics.dart';
import '../../app/round_controller.dart';

/// The paper scoresheet's marks, rendered as a compact 20-cell navigator:
/// current question highlighted, interruption = ring around the number,
/// contest = "C" mark, void = strike-through.
class QuestionNavigator extends StatelessWidget {
  const QuestionNavigator({super.key, required this.round, this.height = 56});

  final RoundController round;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // Equal-width cells: the whole 20-question strip (plus any overtime
        // slots) always fits the width, so the navigator never scrolls.
        child: Row(
          children: [
            for (var i = 0; i < round.questionCount; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _cell(context, i + 1)),
            ],
          ],
        ),
      ),
    );
  }

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
