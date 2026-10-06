import 'package:flutter/material.dart';

import 'settings.dart';

/// Single brand seed for the whole app. The live-scoring screens used to carry
/// their own seed, which let the palette drift between screens.
const kSeed = Color(0xFF37474F);

/// Builds the app theme for [brightness] from the one shared seed.
ThemeData buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kSeed, brightness: brightness),
  useMaterial3: true,
);

/// User-chosen theme mode: follow the system, or force light/dark.
/// Persisted, so it survives a restart.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) : _mode = _prefs.themeMode;

  final ViewPreference _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setThemeMode(mode);
  }

  /// Cycles system -> light -> dark -> system.
  Future<void> cycle() => setMode(switch (_mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });
}

/// Makes a [ThemeController] reachable from anywhere in the tree. The live
/// screens have no AppBar, so the toggle must be reachable from their headers.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing above this context');
    return scope!.notifier!;
  }
}
