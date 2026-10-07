import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:concordance/views/common/about_button.dart';

void main() {
  testWidgets('About button opens a dialog with version and license notice', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              // Inject the version so the test never hits the platform channel.
              AboutButton(versionLoader: () async => '1.0.0-beta'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('About Concordance'));
    await tester.pumpAndSettle();

    expect(find.text('Concordance'), findsOneWidget);
    expect(find.text('v1.0.0-beta'), findsOneWidget);
    expect(find.textContaining('AGPL-3.0-only'), findsOneWidget);
    expect(find.textContaining('Not affiliated with Bible Quiz'), findsOneWidget);
  });
}
