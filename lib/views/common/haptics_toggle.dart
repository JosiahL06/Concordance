import 'package:flutter/material.dart';

import '../../app/haptics.dart';

/// Per-device haptics switch, present on every screen like the theme
/// toggle. OFF by default: an official match must stay quiet until the
/// scorekeeper explicitly opts in.
class HapticsToggleButton extends StatelessWidget {
  const HapticsToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HapticsScope.maybeOf(context);
    final enabled = controller?.enabled ?? false;
    return IconButton(
      tooltip: enabled
          ? 'Haptics: on - tap to turn off'
          : 'Haptics: off - tap to turn on',
      icon: Icon(enabled ? Icons.vibration : Icons.mobile_off),
      onPressed: controller == null
          ? null
          : () => controller.setEnabled(!enabled),
    );
  }
}
