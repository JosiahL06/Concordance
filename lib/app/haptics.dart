import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

/// Opt-in haptics for scoring taps.
///
/// The app NEVER plays audio — no `SystemSound`, no sound assets — so a
/// device stays silent in an official match; the only possible noises are
/// this vibration tick (off by default) and the OS screen reader's own
/// speech. Widgets call [hapticTick], never `HapticFeedback` directly:
/// this file is the single chokepoint that honors the per-device toggle.
class HapticsController extends ChangeNotifier {
  HapticsController(this._prefs) : _enabled = _prefs.hapticsOn;

  final ViewPreference _prefs;
  bool _enabled;

  /// True only when the scorekeeper explicitly opted in.
  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await _prefs.setHaptics(value);
  }

  /// One gentle tick — the lightest impact level the platform offers.
  void tick() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}

/// Makes the [HapticsController] reachable from anywhere in the tree
/// (mirrors `ThemeScope` in `theme.dart`).
class HapticsScope extends InheritedNotifier<HapticsController> {
  const HapticsScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  /// Null outside a [HapticsScope] (e.g. a bare widget test): callers
  /// treat that as OFF, keeping the default match-safe.
  static HapticsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HapticsScope>()?.notifier;
}

/// Fires one opt-in tick from an onPressed/onTap handler. No-op while
/// haptics are off (the default) or when no [HapticsScope] is mounted.
void hapticTick(BuildContext context) => HapticsScope.maybeOf(context)?.tick();
