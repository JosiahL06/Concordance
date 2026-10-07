import 'package:flutter/material.dart';

import 'package:concordance/engine/ruleset.dart';

/// Which live-scoring layout a round uses. Phase 3 persists this as the
/// `ScoreboardView` setting; the prototype picks it on the setup screen.
enum ViewMode { modern, classic }

/// Everything a prototype round needs. The setup screen builds this from the
/// REAL ruleset presets (assets/rulesets/*.json), so thresholds, values and
/// limits shown in the prototype come from the same data the engine uses.
class RoundConfig {
  RoundConfig({
    required this.ruleset,
    required this.redName,
    required this.greenName,
    required List<String> redSeats,
    required List<String> greenSeats,
    required this.viewMode,
    this.demo = false,
  }) : redSeats = List<String>.unmodifiable(redSeats),
       greenSeats = List<String>.unmodifiable(greenSeats);

  final Ruleset ruleset;
  final String redName;
  final String greenName;
  final List<String> redSeats;
  final List<String> greenSeats;
  final ViewMode viewMode;
  final bool demo;
}

class Team {
  Team(this.name, this.color, this.tint, List<String> seats) {
    for (final seat in seats) {
      quizzers.add(Quizzer(this, seat));
    }
  }

  final String name;
  final Color color;
  final Color tint;
  final List<Quizzer> quizzers = <Quizzer>[];
  int timeOuts = 0;

  /// Match-wide challenge bookkeeping (contest / Coach's Appeal), per team —
  /// mirrors engine decision D8.
  int challengesUsed = 0;
  int unsuccessfulChallenges = 0;
}

class Quizzer {
  Quizzer(this.team, this.label);

  final Team team;
  final String label; // e.g. "Red 1"
  int score = 0;
  int correct = 0;
  int incorrect = 0;
  int fouls = 0;
  bool quizzedOut = false;
  bool struckOut = false;
  bool fouledOut = false;

  bool get active => !quizzedOut && !struckOut && !fouledOut;

  String get status {
    if (quizzedOut) return 'QUIZ-OUT';
    if (struckOut) return 'STRIKE-OUT';
    if (fouledOut) return 'FOUL-OUT';
    return '';
  }
}

class QuestionMark {
  bool interrupted = false;
  bool contested = false;
  bool voided = false;

  bool get any => interrupted || contested || voided;
}

/// One recorded outcome in a question slot (paper: the mark in a cell).
class LedgerCell {
  LedgerCell(this.quizzer, this.team, this.kind);

  final Quizzer quizzer;
  final Team team;
  final String kind; // 'correct' | 'incorrect' | 'foul'
}

/// One undoable action. Captures the pre-action screen position, completion
/// state and alert so undo restores them exactly (D6: position is view
/// state, but undo must rewind the view to where the action happened).
class UndoEntry {
  UndoEntry(this.label, this.revert, this.index, this.complete, this.alert);

  final String label;
  final void Function() revert;
  final int index;
  final bool complete;
  final String? alert;
}

class FakeRound extends ChangeNotifier {
  FakeRound(this.config) : ruleset = config.ruleset {
    red = Team(
      config.redName,
      const Color(0xFFC62828),
      const Color(0xFFFCE8E6),
      config.redSeats,
    );
    green = Team(
      config.greenName,
      const Color(0xFF2E7D32),
      const Color(0xFFE6F4EA),
      config.greenSeats,
    );
    teams = <Team>[red, green];
    // Prototype-only demo order (the production engine has no built-in
    // per-question order — D11). Repeated/truncated to the question count.
    values = List<int>.generate(
      ruleset.match.regulationQuestions,
      (i) => _demoValues[i % _demoValues.length],
    );
    if (config.demo) _seed();
  }

  /// A representative regulation value list for the prototype demo.
  static const List<int> _demoValues = [
    10, 20, 10, 20, 30, 10, 20, 10, 20, 20, //
    30, 20, 10, 20, 10, 20, 30, 10, 20, 10,
  ];

  final RoundConfig config;
  final Ruleset ruleset;
  late final Team red;
  late final Team green;
  late final List<Team> teams;

  /// Point values for every question slot (regulation; overtime appends).
  late final List<int> values;

  int questionIndex = 0;
  bool matchComplete = false;
  Quizzer? selected;
  final Map<int, QuestionMark> marks = <int, QuestionMark>{};
  final List<UndoEntry> _undoStack = <UndoEntry>[];

  /// Static banner text (quiz-out, limit warnings). No animation by design.
  String? lastAlert;

  // ── ruleset-driven values (never hard-coded — see engine decision D9) ──

  int get quizOutCorrect => ruleset.scoring.quizOutCorrect;
  int get quizOutBonus => ruleset.scoring.quizOutBonus;
  int get strikeOutNeeded => ruleset.scoring.strikeOutIncorrect;
  int get foulDeduction => ruleset.scoring.foulDeduction;
  int get foulsToFoulOut => ruleset.scoring.foulsToFoulOut;
  int get timeOutLimit => ruleset.limits.timeOutsPerTeam;
  int get timeOutNotify => ruleset.limits.notifyTimeOutRequest;

  /// 'Contest' (TBQ) or "Coach's Appeal" (JBQ).
  String get challengeLabel => ruleset.challengeKind == ChallengeKind.contest
      ? 'Contest'
      : "Coach's Appeal";

  String get rulesetTitle =>
      '${ruleset.displayName} ${ruleset.season}${config.demo ? ' · demo' : ''}';

  int get questionNumber => questionIndex + 1;
  int get currentValue => values[questionIndex];

  int scoreOf(Team team) {
    var total = 0;
    for (final q in team.quizzers) {
      total += q.score;
    }
    return total;
  }

  /// Null on a tie (summary screen shows 'TIE').
  Team? get winner {
    final r = scoreOf(red);
    final g = scoreOf(green);
    if (r == g) return null;
    return r > g ? red : green;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  String? get undoLabel => _undoStack.isEmpty ? null : _undoStack.last.label;

  QuestionMark markFor(int questionNumber) =>
      marks.putIfAbsent(questionNumber, QuestionMark.new);

  void select(Quizzer? q) {
    if (q != null && !q.active) return;
    selected = q;
    notifyListeners();
  }

  void takeTimeOut(Team team) {
    team.timeOuts += 1;
    _push('${team.name} time-out', () => team.timeOuts -= 1);
    if (team.timeOuts >= timeOutNotify) {
      lastAlert =
          '${team.name} requested a ${_ordinal(team.timeOuts)} '
          'time-out — notify the quizmaster';
    }
    notifyListeners();
  }

  /// Records a challenge (TBQ Contest / JBQ Coach's Appeal) for [team] on
  /// the current question. Returns false when the team's limit is exhausted
  /// (rejected + alert fires instead).
  bool recordChallenge(Team team, {required bool successful}) {
    if (matchComplete) return false;
    if (_challengeExhausted(team)) {
      lastAlert =
          '${team.name} has no ${challengeLabel}s left — rejected. '
          'Notify the quizmaster.';
      notifyListeners();
      return false;
    }
    final n = questionNumber;
    markFor(n).contested = true;
    team.challengesUsed += 1;
    if (!successful) team.unsuccessfulChallenges += 1;
    _push('${team.name} ${challengeLabel.toLowerCase()} '
        '${successful ? 'granted' : 'denied'}', () {
      team.challengesUsed -= 1;
      if (!successful) team.unsuccessfulChallenges -= 1;
      markFor(n).contested = false;
    });
    if (_challengeExhausted(team)) {
      lastAlert =
          '${team.name} has used its $challengeLabel limit — '
          'notify the quizmaster.';
    }
    notifyListeners();
    return true;
  }

  bool _challengeExhausted(Team team) {
    final limits = ruleset.limits;
    if (limits.challengeLimitMode == ChallengeLimitMode.unsuccessful) {
      return team.unsuccessfulChallenges >= limits.challengeLimitCount;
    }
    final allotment = limits.challengeAllotmentPerTeam;
    return allotment != null && team.challengesUsed >= allotment;
  }

  /// Appends a sudden-death overtime question after completion.
  /// Prototype approximation: always 10 points; Phase 3 follows the
  /// ruleset's overtime mode (sudden-death 10 vs. 3 + sudden-death 20).
  void addOvertimeQuestion() {
    if (!matchComplete) return;
    _push('Overtime question added', () => values.removeLast());
    values.add(10);
    matchComplete = false;
    lastAlert = null;
    questionIndex = values.length - 1;
    notifyListeners();
  }

  void clearAlert() {
    lastAlert = null;
    notifyListeners();
  }

  void jumpToQuestion(int n) {
    if (n < 1 || n > values.length) return;
    questionIndex = n - 1;
    selected = null;
    // Reviewing or correcting a past question reopens the round view;
    // completing Q20 again re-fires the completion alert (D6: the screen
    // position is view state).
    matchComplete = false;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    entry.revert();
    questionIndex = entry.index.clamp(0, values.length - 1);
    matchComplete = entry.complete;
    lastAlert = entry.alert;
    selected = null;
    notifyListeners();
  }

  /// Guardrail (polish pass): at most one answer outcome (correct or
  /// incorrect) per quizzer per question, and at most one correct answer
  /// per team per question — a question can't be answered both right and
  /// wrong by the same side.
  bool canScore(Quizzer q, int n) {
    final cells = _cells[n] ?? const <LedgerCell>[];
    if (cells.any((c) => identical(c.quizzer, q) && c.kind != 'foul')) {
      return false;
    }
    return true;
  }

  String? scoreBlockedReason(Quizzer q, int n) {
    final cells = _cells[n] ?? const <LedgerCell>[];
    if (cells.any((c) => identical(c.quizzer, q) && c.kind != 'foul')) {
      return '${q.label} already has an answer recorded on Q$n — '
          'one answer per quizzer per question.';
    }
    if (cells.any((c) => c.team == q.team && c.kind == 'correct')) {
      return '${q.team.name} already has a correct answer on Q$n — '
          'only one correct answer per team per question.';
    }
    return null;
  }

  void _push(String label, void Function() revert) {
    _undoStack.add(
      UndoEntry(label, revert, questionIndex, matchComplete, lastAlert),
    );
  }

  void _advance() {
    selected = null;
    if (questionIndex < values.length - 1) {
      questionIndex += 1;
    } else {
      matchComplete = true;
      lastAlert = 'Match complete — give the score to the quizmaster';
    }
  }

  static String _ordinal(int n) => switch (n) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    4 => '4th',
    _ => '${n}th',
  };

  void markCorrect() {
    final q = selected;
    if (matchComplete || q == null || !q.active) return;
    final n = questionNumber;
    final blocked = scoreBlockedReason(q, n);
    if (blocked != null) {
      lastAlert = blocked;
      notifyListeners();
      return;
    }
    final v = currentValue;
    final bonus = q.correct + 1 >= quizOutCorrect;
    final cellsPrev = _snapshotCells(n);
    q.score += v;
    q.correct += 1;
    if (bonus) {
      q.score += quizOutBonus;
      q.quizzedOut = true;
    }
    _setCell(n, LedgerCell(q, q.team, 'correct'));
    _push('${q.label} correct +$v', () {
      q.score -= v;
      q.correct -= 1;
      if (bonus) {
        q.score -= quizOutBonus;
        q.quizzedOut = false;
      }
      _cells[n] = cellsPrev;
    });
    if (bonus) lastAlert = '${q.label} quizzed out (+$quizOutBonus bonus)';
    selected = null;
    _advance();
    notifyListeners();
  }

  void markIncorrect() {
    final q = selected;
    if (matchComplete || q == null || !q.active) return;
    final n = questionNumber;
    final blocked = scoreBlockedReason(q, n);
    if (blocked != null) {
      lastAlert = blocked;
      notifyListeners();
      return;
    }
    final half = currentValue ~/ 2;
    final strike = q.incorrect + 1 >= strikeOutNeeded;
    final cellsPrev = _snapshotCells(n);
    q.score -= half;
    q.incorrect += 1;
    if (strike) q.struckOut = true;
    _setCell(n, LedgerCell(q, q.team, 'incorrect'));
    _push('${q.label} incorrect -$half', () {
      q.score += half;
      q.incorrect -= 1;
      if (strike) q.struckOut = false;
      _cells[n] = cellsPrev;
    });
    if (strike) lastAlert = '${q.label} has struck out';
    selected = null;
    _advance();
    notifyListeners();
  }

  void addFoul() {
    final q = selected;
    if (matchComplete || q == null || !q.active) return;
    final n = questionNumber;
    final out = q.fouls + 1 >= foulsToFoulOut;
    final cellsPrev = _snapshotCells(n);
    q.score -= foulDeduction;
    q.fouls += 1;
    if (out) q.fouledOut = true;
    _setCell(n, LedgerCell(q, q.team, 'foul'));
    _push('${q.label} foul -$foulDeduction', () {
      q.score += foulDeduction;
      q.fouls -= 1;
      if (out) q.fouledOut = false;
      _cells[n] = cellsPrev;
    });
    if (out) lastAlert = '${q.label} has fouled out';
    selected = null;
    notifyListeners();
  }

  void toggleInterruption() {
    final mark = markFor(questionNumber);
    mark.interrupted = !mark.interrupted;
    _push(
      mark.interrupted
          ? 'Q$questionNumber interrupted'
          : 'Q$questionNumber interruption removed',
      () => mark.interrupted = !mark.interrupted,
    );
    notifyListeners();
  }

  // ── Scoresheet-ledger helpers (Direction B + summary screen) ──────────

  final Map<int, List<LedgerCell>> _cells = <int, List<LedgerCell>>{};

  int cellValue(int n) => n <= values.length ? values[n - 1] : 10;

  List<LedgerCell> cellsFor(int n) =>
      List<LedgerCell>.unmodifiable(_cells[n] ?? const <LedgerCell>[]);

  /// The mark to show in [q]'s cell on question [n], or null.
  String? ledgerMark(Quizzer q, int n) {
    for (final cell in _cells[n] ?? const <LedgerCell>[]) {
      if (identical(cell.quizzer, q)) return cell.kind;
    }
    return null;
  }

  bool ledgerContested(int n) => marks[n]?.contested ?? false;

  bool ledgerInterrupted(int n) => marks[n]?.interrupted ?? false;

  /// Signed point delta for one team on one question (RUNNING row).
  int ledgerDelta(Team team, int n) {
    var delta = 0;
    for (final cell in _cells[n] ?? const <LedgerCell>[]) {
      if (cell.team != team) continue;
      switch (cell.kind) {
        case 'correct':
          delta += cellValue(n);
        case 'incorrect':
          delta -= cellValue(n) ~/ 2;
        case 'foul':
          delta -= foulDeduction;
      }
    }
    return delta;
  }

  List<LedgerCell> _snapshotCells(int n) =>
      List<LedgerCell>.of(_cells[n] ?? const <LedgerCell>[]);

  void _setCell(int n, LedgerCell cell) {
    final list = _cells.putIfAbsent(n, () => <LedgerCell>[]);
    list.removeWhere((c) => identical(c.quizzer, cell.quizzer));
    list.add(cell);
  }

  /// Seeds a plausible mid-round demo (Q13 in progress) by REPLAYING cell
  /// outcomes through the same ruleset logic as live play, so summary
  /// totals always equal the sum of the visible ledger cells — and the
  /// JBQ preset (quiz-out at 6) correctly shows NO quiz-out chip, proving
  /// the thresholds come from the preset, not from hard-coded TBQ values.
  void _seed() {
    // (question, team: 0 = red / 1 = green, quizzer index, kind)
    const rows = <(int, int, int, String)>[
      (1, 0, 1, 'correct'), // Red 2 +10
      (2, 1, 0, 'incorrect'), // Green 1 jumped on interrupted Q2
      (2, 0, 1, 'correct'), // Red 2 +20
      (3, 1, 0, 'correct'), // Green 1 +10
      (4, 0, 1, 'correct'), // Red 2 +20 (Q4 contested)
      (5, 1, 1, 'correct'), // Green 2 +30
      (6, 0, 1, 'correct'), // Red 2 +10
      (7, 1, 0, 'correct'), // Green 1 +20
      (7, 0, 0, 'foul'), // Red 1 F -5
      (8, 0, 1, 'correct'), // Red 2 +10 → 5th correct → quiz-out
      (9, 1, 1, 'correct'), // Green 2 +20
      (10, 1, 1, 'correct'), // Green 2 +10
      (11, 0, 2, 'correct'), // Red 3 +30
      (11, 1, 2, 'foul'), // Green 3 F -5
      (12, 1, 0, 'incorrect'), // Green 1 jumped on interrupted Q12
      (12, 0, 2, 'correct'), // Red 3 +20
    ];
    for (final (n, side, index, kind) in rows) {
      if (n > values.length) continue;
      final team = side == 0 ? red : green;
      if (index >= team.quizzers.length) continue;
      final q = team.quizzers[index];
      switch (kind) {
        case 'correct':
          final bonus = q.correct + 1 >= quizOutCorrect;
          q.score += values[n - 1];
          q.correct += 1;
          if (bonus) {
            q.score += quizOutBonus;
            q.quizzedOut = true;
          }
        case 'incorrect':
          q.score -= values[n - 1] ~/ 2;
          q.incorrect += 1;
          if (q.incorrect >= strikeOutNeeded) q.struckOut = true;
        case 'foul':
          q.score -= foulDeduction;
          q.fouls += 1;
          if (q.fouls >= foulsToFoulOut) q.fouledOut = true;
      }
      _setCell(n, LedgerCell(q, team, kind));
    }
    markFor(2).interrupted = true;
    markFor(12).interrupted = true;
    markFor(4).contested = true;
    red.timeOuts = 1;
    green.timeOuts = 2;
    questionIndex = 12; // Q13 in progress
  }
}
