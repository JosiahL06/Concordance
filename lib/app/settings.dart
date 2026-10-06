import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Which live-scoring layout a round uses. Persisted per-device, overridable
/// per session on the setup screen.
enum ScoreboardView { modern, classic }

/// Loads/saves the per-device [ScoreboardView] preference.
class ViewPreference {
  ViewPreference(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'scoreboard_view';
  static const themeKey = 'theme_mode';

  static Future<ViewPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ViewPreference(prefs);
  }

  ScoreboardView get view {
    final raw = _prefs.getString(key);
    return ScoreboardView.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => ScoreboardView.modern,
    );
  }

  Future<void> setView(ScoreboardView view) =>
      _prefs.setString(key, view.name);

  /// Persisted light/dark/system choice; defaults to following the system.
  ThemeMode get themeMode => switch (_prefs.getString(themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(themeKey, mode.name);
}
