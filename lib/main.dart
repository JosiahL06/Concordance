import 'package:flutter/material.dart';

import 'prototype/prototype_home.dart';

void main() {
  runApp(const ConcordancePrototypeApp());
}

/// Entry point for the Phase 1 design prototype.
///
/// The production entry point returns in Phase 3 once the interaction design
/// has been signed off (see TODO.md).
class ConcordancePrototypeApp extends StatelessWidget {
  const ConcordancePrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Concordance prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF37474F)),
        useMaterial3: true,
      ),
      home: const PrototypeHome(),
    );
  }
}
