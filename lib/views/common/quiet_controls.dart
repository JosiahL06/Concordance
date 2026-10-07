import 'package:flutter/material.dart';

/// A [SimpleDialogOption]-equivalent that never triggers platform feedback.
///
/// Material's option (and menu item) widgets hard-wire `InkWell` feedback
/// with no `enableFeedback` switch, so the option plays the Android system
/// click sound on tap — unacceptable mid-match. This keeps the dialog look
/// and semantics of a tappable option while staying silent.
class QuietDialogOption extends StatelessWidget {
  const QuietDialogOption({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      enableFeedback: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: child,
      ),
    );
  }
}

/// A [PopupMenuItem] that never triggers platform feedback, for the same
/// reason as [QuietDialogOption]: `PopupMenuItem` offers no
/// `enableFeedback` switch, and menu routes are where void/substitute
/// actions live during a match.
class QuietMenuItem<T> extends PopupMenuEntry<T> {
  const QuietMenuItem({
    super.key,
    required this.value,
    this.enabled = true,
    required this.child,
  });

  /// Value returned when this item is tapped, mirroring [PopupMenuItem].
  final T value;

  /// False renders the item dimmed, mirroring [PopupMenuItem].
  final bool enabled;

  final Widget? child;

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(T? value) => value == this.value;

  @override
  State<QuietMenuItem<T>> createState() => _QuietMenuItemState<T>();
}

class _QuietMenuItemState<T> extends State<QuietMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Semantics(
        enabled: widget.enabled,
        button: true,
        child: InkWell(
          onTap: widget.enabled
              ? () => Navigator.pop<T>(context, widget.value)
              : null,
          enableFeedback: false,
          child: Container(
            constraints: BoxConstraints(minHeight: widget.height),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AnimatedDefaultTextStyle(
              style: widget.enabled
                  ? theme.textTheme.titleMedium!
                  : theme.textTheme.titleMedium!.copyWith(
                      color: theme.disabledColor,
                    ),
              duration: kThemeChangeDuration,
              child: widget.child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
