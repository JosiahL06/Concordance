import 'package:flutter/material.dart';

import 'app/settings.dart';
import 'data/round_store.dart';
import 'engine/ruleset.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await ViewPreference.load();
  runApp(ConcordanceApp(prefs: prefs));
}

/// Production entry point: offline, single-round scorekeeping for Bible Quiz.
class ConcordanceApp extends StatelessWidget {
  const ConcordanceApp({super.key, required this.prefs, this.store, this.presets});

  final ViewPreference prefs;

  /// Injected store (tests); null opens the on-disk store at home.
  final RoundStore? store;

  /// Injected ruleset presets (tests); null loads the bundled JSON assets.
  final List<Ruleset>? presets;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Concordance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF37474F)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF37474F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(prefs: prefs, store: store, presets: presets),
    );
  }
}
