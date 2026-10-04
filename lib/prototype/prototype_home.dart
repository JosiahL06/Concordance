import 'package:flutter/material.dart';

import 'setup_screen.dart';

/// App home for the Phase 1 prototype: start a fresh round or load the
/// mid-match demo. Both paths go through the setup screen so the ruleset
/// tabs and view-mode pick are part of every flow.
class PrototypeHome extends StatelessWidget {
  const PrototypeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Concordance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  'Touch-first scorekeeping for Bible Quiz rounds.',
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => _open(context, const SetupScreen()),
                  child: const Text('START A NEW ROUND'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () =>
                      _open(context, const SetupScreen(demo: true)),
                  child: const Text('Load demo round (mid-match)'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Prototype: Modern + Classic scoreboard modes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
