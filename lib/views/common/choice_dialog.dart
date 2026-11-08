import 'package:flutter/material.dart';

/// One selectable row in [showChoiceDialog].
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.icon,
    required this.label,
    this.description,
    this.color,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
}

/// Compact decision dialog matching the substitution board / question editor:
/// rounded surface, strong title, icon-led option cards, 48dp targets.
Future<T?> showChoiceDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<ChoiceOption<T>> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) =>
        _ChoiceDialog<T>(title: title, subtitle: subtitle, options: options),
  );
}

/// Point-value selector used by the header `SET VALUE` button, an empty
/// Classic column header, the Modern navigator's value row, and the Classic
/// question editor.
Future<int?> showValuePicker(
  BuildContext context, {
  required int questionNumber,
  required List<int> options,
  int? current,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _ValuePickerDialog(
      questionNumber: questionNumber,
      options: options,
      current: current,
    ),
  );
}

class _ChoiceDialog<T> extends StatelessWidget {
  const _ChoiceDialog({
    required this.title,
    required this.subtitle,
    required this.options,
  });

  final String title;
  final String? subtitle;
  final List<ChoiceOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: title,
      subtitle: subtitle,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ChoiceRow<T>(option: options[i]),
        ],
      ],
    );
  }
}

class _ChoiceRow<T> extends StatefulWidget {
  const _ChoiceRow({required this.option});

  final ChoiceOption<T> option;

  @override
  State<_ChoiceRow<T>> createState() => _ChoiceRowState<T>();
}

class _ChoiceRowState<T> extends State<_ChoiceRow<T>> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final option = widget.option;
    final color = option.color ?? scheme.primary;
    final background = _pressed
        ? scheme.primary.withValues(alpha: 0.14)
        : _hovered
        ? scheme.surfaceContainerHigh
        : scheme.surface;
    final border = _pressed || _hovered
        ? color.withValues(alpha: 0.65)
        : scheme.outlineVariant;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        enableFeedback: false,
        onTap: () => Navigator.pop(context, option.value),
        onHover: (hovering) => setState(() => _hovered = hovering),
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: Semantics(
          button: true,
          label: [
            option.label,
            if (option.description != null) option.description!,
          ].join(', '),
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _hovered ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(option.icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (option.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            option.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValuePickerDialog extends StatelessWidget {
  const _ValuePickerDialog({
    required this.questionNumber,
    required this.options,
    this.current,
  });

  final int questionNumber;
  final List<int> options;
  final int? current;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Question $questionNumber',
      subtitle: 'Choose the point value for this question.',
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final value in options)
              PointValueCard(
                key: ValueKey('value-picker-$value'),
                value: value,
                selected: value == current,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ],
    );
  }
}

/// Large point-value card shared by the value picker and the Classic question
/// editor. The Material owns the fill so the InkWell splash remains visible;
/// hover and press states change both the fill and the border.
class PointValueCard extends StatefulWidget {
  const PointValueCard({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
    this.width = 120,
    this.height = 76,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  State<PointValueCard> createState() => _PointValueCardState();
}

class _PointValueCardState extends State<PointValueCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.selected
        ? scheme.primaryContainer
        : _pressed
        ? scheme.primary.withValues(alpha: 0.16)
        : _hovered
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surface;
    final borderColor = widget.selected || _pressed
        ? scheme.primary
        : _hovered
        ? scheme.primary.withValues(alpha: 0.6)
        : scheme.outlineVariant;
    final borderWidth = widget.selected || _pressed ? 3.0 : 1.5;
    final textColor = widget.selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        enableFeedback: false,
        onTap: widget.onTap,
        onHover: (hovering) => setState(() => _hovered = hovering),
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: 'Set question to ${widget.value} points',
          excludeSemantics: true,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.value}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                    color: textColor,
                  ),
                ),
                Text(
                  'PTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: widget.selected
                        ? scheme.onPrimaryContainer
                        : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared compact shell. Keeps the live-screen 1.3x text cap and the same
/// rounded surface/padding as the substitution board.
class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
