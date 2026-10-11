/// Formatting for the one timestamp the app stores: a round's `created_at`.
///
/// [RoundStore] writes UTC with a trailing `Z`, so every value has a known
/// instant and only needs converting to the keeper's local time for display.
///
/// Hand-rolled rather than pulling in `intl`: the app is English-only, shows
/// exactly one date format, and has no localization setup, so a dependency plus
/// its locale data is not justified. Revisit if a second locale ever appears.
library;

/// Month abbreviations, indexed by `DateTime.month - 1`.
const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Parses a stored `created_at` into an instant, or null when unreadable.
///
/// A value missing its timezone designator is read as **UTC**, matching the
/// interpretation migration 3 applied to the naive local timestamps older builds
/// left behind. Dart's own default for a zone-less string is *local* time, which
/// is precisely the ambiguity v3 exists to remove.
DateTime? parseTimestamp(String stored) =>
    DateTime.tryParse(stored.endsWith('Z') ? stored : '${stored}Z');

/// Renders a stored `created_at` in the device's local time, e.g.
/// `10 Oct 2026, 14:23`.
///
/// Anything unparseable is returned verbatim rather than throwing: a date the
/// app cannot read is not a reason to hide the round from the list.
String formatTimestamp(String stored) {
  final instant = parseTimestamp(stored);
  if (instant == null) return stored;
  final local = instant.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '$hour:$minute';
}
