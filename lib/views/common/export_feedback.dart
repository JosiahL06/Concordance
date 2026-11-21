import 'package:flutter/material.dart';

import '../../data/export_share.dart';

/// Reports a Save-as result. Sharing stays quiet; saving shows where the file
/// went, and cancellation is intentionally silent.
void showExportOutcome(
  BuildContext context,
  ExportOutcome outcome,
  String kind,
) {
  if (outcome.delivery != ExportDelivery.saved) return;
  final path = outcome.path;
  if (path == null) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$kind saved to $path')));
}
