import '../engine/events.dart';

/// Status values for a scheduled tournament match.
abstract final class TournamentMatchStatus {
  static const pending = 'pending';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const skipped = 'skipped';
}

/// Tournament header row.
class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.rulesetId,
    required this.matchCount,
    required this.teamName,
    required this.createdAt,
    this.completedAt,
  });

  final int id;
  final String name;
  final String rulesetId;
  final int matchCount;
  final String teamName;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;
}

/// A stable member identity inside a tournament. [rosterIndex] never changes;
/// [defaultSeat] is 0 for bench or 1-based for a seat.
class TournamentMember {
  const TournamentMember({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.rosterIndex,
    required this.defaultSeat,
    this.archivedAt,
  });

  final int id;
  final int tournamentId;
  final String name;
  final int rosterIndex;
  final int defaultSeat;
  final DateTime? archivedAt;

  bool get archived => archivedAt != null;
  bool get onBench => defaultSeat == 0;
}

/// One scheduled match. [roundId] is null until the match starts.
class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.matchNumber,
    required this.status,
    this.roundId,
    this.trackedSide,
    this.opponentName,
    this.createdAt,
    this.completedAt,
  });

  final int id;
  final int tournamentId;
  final int matchNumber;
  final String status;
  final int? roundId;
  final Side? trackedSide;
  final String? opponentName;
  final DateTime? createdAt;
  final DateTime? completedAt;

  bool get isPending => status == TournamentMatchStatus.pending;
  bool get isInProgress => status == TournamentMatchStatus.inProgress;
  bool get isCompleted => status == TournamentMatchStatus.completed;
}

/// A link from a tournament member to one round roster slot.
class TournamentMemberLink {
  const TournamentMemberLink({
    required this.roundId,
    required this.side,
    required this.rosterIndex,
    required this.memberId,
  });

  final int roundId;
  final Side side;
  final int rosterIndex;
  final int memberId;
}

/// Input for a member at tournament creation.
class TournamentMemberInput {
  const TournamentMemberInput({
    required this.name,
    required this.rosterIndex,
    required this.defaultSeat,
  });

  final String name;
  final int rosterIndex;
  final int defaultSeat;
}

/// Input for a member → round roster link at match start.
class TournamentMemberLinkInput {
  const TournamentMemberLinkInput({
    required this.side,
    required this.rosterIndex,
    required this.memberId,
  });

  final Side side;
  final int rosterIndex;
  final int memberId;
}

/// Everything needed to atomically create a tournament round + match.
class TournamentMatchStart {
  const TournamentMatchStart({
    required this.trackedSide,
    required this.opponentName,
    required this.redName,
    required this.greenName,
    required this.redSeats,
    required this.greenSeats,
    required this.redBench,
    required this.greenBench,
    required this.links,
  });

  final Side trackedSide;
  final String opponentName;
  final String redName;
  final String greenName;
  final List<String> redSeats;
  final List<String> greenSeats;
  final List<String> redBench;
  final List<String> greenBench;
  final List<TournamentMemberLinkInput> links;
}
