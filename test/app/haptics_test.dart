// Opt-in haptics: OFF on a fresh install, ON only after the scorekeeper
// flips the toggle, and the app NEVER plays audio (SystemSound) in any
// state — an official match must stay quiet.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:concordance/app/haptics.dart';
import 'package:concordance/app/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Iterable<MethodCall> vibrateCalls() =>
      platformCalls.where((c) => c.method == 'HapticFeedback.vibrate');

  Iterable<MethodCall> soundCalls() =>
      platformCalls.where((c) => c.method == 'SystemSound.play');

  test('haptics preference defaults to off and persists the choice', () async {
    final prefs = await ViewPreference.load();
    expect(prefs.hapticsOn, isFalse);

    await prefs.setHaptics(true);
    expect((await ViewPreference.load()).hapticsOn, isTrue);

    await prefs.setHaptics(false);
    expect((await ViewPreference.load()).hapticsOn, isFalse);
  });

  test('controller ticks only when enabled and never plays sound', () async {
    final prefs = await ViewPreference.load();
    final controller = HapticsController(prefs);
    addTearDown(controller.dispose);
    expect(controller.enabled, isFalse);

    // Default (match-safe): no vibration channel traffic at all.
    controller.tick();
    await pumpEventQueue();
    expect(vibrateCalls(), isEmpty);

    // Opted in: exactly the gentlest selection tick.
    await controller.setEnabled(true);
    expect(controller.enabled, isTrue);
    controller.tick();
    await pumpEventQueue();
    expect(vibrateCalls(), hasLength(1));
    expect(
      vibrateCalls().single.arguments,
      'HapticFeedbackType.selectionClick',
    );

    // Back off: no further ticks.
    await controller.setEnabled(false);
    controller.tick();
    await pumpEventQueue();
    expect(vibrateCalls(), hasLength(1));

    // Audio stays out of the picture in every state.
    expect(soundCalls(), isEmpty);
    expect(
      platformCalls.map((c) => c.method),
      isNot(contains('SystemSound.play')),
    );
  });
}
