import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// How an export left the app.
enum ExportDelivery { shared, saved, cancelled }

/// Result of sharing or saving an export file.
class ExportOutcome {
  const ExportOutcome._(this.delivery, [this.path]);

  const ExportOutcome.shared() : this._(ExportDelivery.shared);
  const ExportOutcome.saved(String path) : this._(ExportDelivery.saved, path);
  const ExportOutcome.cancelled() : this._(ExportDelivery.cancelled);

  final ExportDelivery delivery;

  /// Where the file was saved, for [ExportDelivery.saved].
  final String? path;
}

/// Shares the file via the platform share sheet where file sharing is
/// implemented, and falls back to a Save-as dialog elsewhere.
///
/// Linux's share_plus implementation deliberately does not implement
/// `shareXFiles`, and the old-Windows fallback throws as well. Those platforms
/// get a native Save-as dialog instead of an unhandled exception. Android,
/// iOS, macOS, and modern Windows keep the share sheet.
Future<ExportOutcome> shareOrSaveFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String shareText,
  required String typeLabel,
  required String extension,
}) async {
  if (!Platform.isLinux) {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path, mimeType: mimeType),
      ], text: shareText);
      return const ExportOutcome.shared();
    } on UnimplementedError {
      // Old-Windows fallback: no file share implementation. Save instead.
    } on MissingPluginException {
      // A platform without the share plugin: save instead.
    }
  }

  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      XTypeGroup(
        label: typeLabel,
        extensions: [extension],
        mimeTypes: [mimeType],
      ),
    ],
  );
  if (location == null) return const ExportOutcome.cancelled();
  await File(location.path).writeAsBytes(bytes);
  return ExportOutcome.saved(location.path);
}
