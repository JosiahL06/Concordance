import 'package:flutter/material.dart';

import '../../app/settings.dart';

/// Modern/Classic choice as two cards. Shared by the standalone setup screen
/// and the tournament match setup so the view picker looks identical in both.
class ScoreboardViewPicker extends StatelessWidget {
  const ScoreboardViewPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ScoreboardView value;
  final ValueChanged<ScoreboardView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _modeCard(
            context,
            mode: ScoreboardView.modern,
            icon: Icons.dashboard_outlined,
            title: 'Modern',
            subtitle: 'Split-field spatial layout.',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modeCard(
            context,
            mode: ScoreboardView.classic,
            icon: Icons.table_chart_outlined,
            title: 'Classic',
            subtitle: 'Paper-style scoresheet ledger.',
          ),
        ),
      ],
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required ScoreboardView mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = value == mode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        enableFeedback: false,
        onTap: () => onChanged(mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
