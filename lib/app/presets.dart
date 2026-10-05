import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../engine/ruleset.dart';

/// Built-in ruleset preset ids (ruleset-as-data: new rulebooks arrive as
/// JSON assets, no code changes).
const presetIds = <String>['tbq-25-26', 'jbq-2026'];

/// Loads the built-in ruleset presets. Throws a [PresetLoadFailure] when an
/// asset is missing or malformed so callers can show it, not crash.
Future<List<Ruleset>> loadPresets([List<String> ids = presetIds]) async {
  final loaded = <Ruleset>[];
  for (final id in ids) {
    try {
      final raw = await rootBundle.loadString('assets/rulesets/$id.json');
      loaded.add(Ruleset.fromJson(json.decode(raw) as Map<String, Object?>));
    } catch (e) {
      throw PresetLoadFailure('Could not load ruleset "$id": $e');
    }
  }
  return loaded;
}

/// Loads a single preset by id (resume path).
Future<Ruleset?> loadPreset(String id) async {
  try {
    final presets = await loadPresets(<String>[id]);
    return presets.first;
  } on PresetLoadFailure {
    return null;
  }
}

class PresetLoadFailure implements Exception {
  const PresetLoadFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
