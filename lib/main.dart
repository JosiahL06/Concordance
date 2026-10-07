import 'package:flutter/material.dart';

import 'app/haptics.dart';
import 'app/settings.dart';
import 'app/theme.dart';
import 'data/round_store.dart';
import 'engine/ruleset.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await ViewPreference.load();
  runApp(ConcordanceApp(prefs: prefs));
}

/// Production entry point: offline, single-round scorekeeping for Bible Quiz.
class ConcordanceApp extends StatefulWidget {
  const ConcordanceApp({
    super.key,
    required this.prefs,
    this.store,
    this.presets,
    this.storeOpener,
  });

  final ViewPreference prefs;

  /// Injected store (tests); null opens the on-disk store at home.
  final RoundStore? store;

  /// Injected ruleset presets (tests); null loads the bundled JSON assets.
  final List<Ruleset>? presets;

  /// Injected store opener (tests); null uses [RoundStore.open].
  final Future<RoundStore> Function()? storeOpener;

  @override
  State<ConcordanceApp> createState() => _ConcordanceAppState();
}

class _ConcordanceAppState extends State<ConcordanceApp> {
  late final ThemeController _theme;
  late final HapticsController _haptics;

  @override
  void initState() {
    super.initState();
    _theme = ThemeController(widget.prefs);
    _haptics = HapticsController(widget.prefs);
  }

  @override
  void dispose() {
    _theme.dispose();
    _haptics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      notifier: _theme,
      child: HapticsScope(
        notifier: _haptics,
        child: ListenableBuilder(
          listenable: _theme,
          builder: (context, _) => MaterialApp(
            title: 'Concordance',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: _theme.mode,
            home: HomeScreen(
              prefs: widget.prefs,
              store: widget.store,
              presets: widget.presets,
              storeOpener: widget.storeOpener,
            ),
          ),
        ),
      ),
    );
  }
}
