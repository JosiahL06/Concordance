import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Light / dark / follow-system toggle. Present on every screen so the theme
/// can be changed mid-round without leaving the match.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final (icon, tooltip) = switch (controller.mode) {
      ThemeMode.system => (
        Icons.brightness_auto,
        'Theme: follow system - tap for light',
      ),
      ThemeMode.light => (Icons.light_mode, 'Theme: light - tap for dark'),
      ThemeMode.dark => (Icons.dark_mode, 'Theme: dark - tap to follow system'),
    };
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: controller.cycle,
    );
  }
}
