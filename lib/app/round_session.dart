import '../data/round_store.dart';
import '../engine/events.dart';
import 'round_controller.dart';

/// Shared round lifecycle helpers used by both standalone rounds (Home) and
/// tournament matches. Keeping the autosave wiring here means both entry points
/// write the journal through the same delta/rewrite hooks.
abstract final class RoundSession {
  /// Creates a normal round row from [controller]'s current roster and installs
  /// its autosave hooks. Returns the round id.
  static int create(RoundStore store, RoundController controller) {
    final id = store.createRound(
      rulesetId: controller.ruleset.id,
      redName: controller.redName,
      greenName: controller.greenName,
      redSeats: [for (final q in controller.teamOf(Side.red).seated) q.label],
      greenSeats: [
        for (final q in controller.teamOf(Side.green).seated) q.label,
      ],
      redBench: controller.view.redBenchSeed,
      greenBench: controller.view.greenBenchSeed,
    );
    attach(store, controller, id, 0);
    return id;
  }

  /// Attaches delta/rewrite autosave hooks to an existing round row. [persisted]
  /// is how many events are already on disk (0 for a fresh round).
  static void attach(
    RoundStore store,
    RoundController controller,
    int roundId,
    int persisted,
  ) {
    controller.roundId = roundId;
    var onDisk = persisted;
    controller.autosave = (c) {
      onDisk = store.saveJournal(roundId, c.view.journal, onDisk);
    };
    controller.rewriteAutosave = (c) {
      onDisk = store.replaceJournal(roundId, c.view.journal);
    };
  }
}
