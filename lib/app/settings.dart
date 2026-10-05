import 'package:shared_preferences/shared_preferences.dart';

/// Which live-scoring layout a round uses. Persisted per-device, overridable
/// per session on the setup screen.
enum ScoreboardView { modern, classic }

/// Loads/saves the per-device [ScoreboardView] preference.
class ViewPreference {
  ViewPreference(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'scoreboard_view';

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
}
