import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// AppBar info button that opens an About dialog showing the app version and
/// the AGPL-3.0-only notice, with the bundled open-source license list.
class AboutButton extends StatelessWidget {
  const AboutButton({super.key, this.versionLoader});

  /// Injected version loader (tests); defaults to [PackageInfo.fromPlatform].
  final Future<String> Function()? versionLoader;

  Future<String> _version() async {
    if (versionLoader != null) return versionLoader!();
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<void> _show(BuildContext context) async {
    final String version;
    try {
      version = await _version();
    } catch (_) {
      // Never block the dialog on a platform-channel hiccup.
      return;
    }
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Concordance',
      applicationVersion: 'v$version',
      applicationLegalese: '© 2026 Josiah Laakkonen\nAGPL-3.0-only',
      applicationIcon: const Icon(Icons.menu_book_outlined, size: 40),
      children: const [
        SizedBox(height: 12),
        Text('An offline, touch-first scorekeeper for Bible Quiz rounds.'),
        SizedBox(height: 8),
        Text(
          'Not affiliated with Bible Quiz and not yet ready for official '
          'matches. Personal and unofficial use is welcome.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'About Concordance',
      icon: const Icon(Icons.info_outline),
      onPressed: () => _show(context),
    );
  }
}
