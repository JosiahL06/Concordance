# Concordance — v1 Roadmap

## Target hardware
- **Primary: Amazon Fire HD 10 (2023, 13th gen)** — Fire OS 8 (Android 11, API 30),
  1920×1200 landscape, sideloaded APK (no Google Play services — keep deps GMS-free).
  Test AVD: `fire_hd_10` (API 30 AOSP image, no Google APIs). Flutter default
  `minSdk = 24` covers it with room to spare (also Fire OS 7 / Android 9).
- Secondary: Windows laptops (touchscreen), generic Android tablets, Linux
  (day-to-day dev/testing), and **macOS desktop** (Xcode project scaffolded and
  build-ready; `flutter build macos` requires a Mac with Xcode).
- **iPadOS is explicitly post-v1**: the Flutter code targets it trivially, but
  Apple's toolchain (Mac + Xcode required to build) and distribution model
  (App Store $99/yr + review, and the AGPL-3.0-only vs. App Store ToS conflict)
  are the real gates — not the app code.

## Phase 0 — Toolchain & scaffold
- [x] Flutter 3.47.6 + JDK 17 + Android SDK installed (user-level, `~/sdk/`)
- [x] Project scaffolded (`android`, `windows`, `linux` targets)
- [x] AGPL-3.0 LICENSE, .gitignore, VS Code config
- [x] CHANGELOG.md initialized (Keep a Changelog 1.1.0)
- [x] Verify Android debug build (`app-debug.apk` builds, installs & runs on emulator)

## Phase 1 — UI design & sign-off
- [x] Two visual directions for the live scoring screen (screenshots on `fire_hd_10`)
- [x] User picks a direction → **keep both**: Modern (A: split-field) + Classic (B: scoresheet ledger)
- [x] Build out all three screens (setup, live scoring in both modes, summary)
- [x] Hands-on validation (Linux desktop + `fire_hd_10` screenshots) + revision rounds
- [x] Interaction spec written (`docs/design/interaction.md`) — tap-flow contract
      for Phases 2–3

## Phase 2 — Scoring engine (pure Dart, test-first)
- [x] Rulebook extraction pass (facts matrix from both PDFs, `/tmp` only)
- [x] Ruleset-as-data schema (`docs/ruleset-schema.md`) + `questionNumber`-on-event decision
- [x] `RoundView` view-model interface first (serves both Modern + Classic)
- [x] Event-sourced round model (answer/foul/time-out/contest events)
- [x] TBQ 25-26 preset + JBQ 2026 preset from the official rulebooks
- [x] Golden unit tests worked from both rulebooks + dual-mode consistency test
      (22 tests: scoring, bookkeeping/notifications, full-match sims, presets)
- [x] Read API shaped by the Phase 1 interaction spec (`RoundView` exposes every
      read the spec's console contract needs: scores, per-quizzer breakdown,
      per-question marks, Classic ledger cells/deltas, undo availability)

## Phase 3 — UI implementation
- [x] New Round setup (ruleset tab, teams, quizzers, seats)
- [x] Shared widgets first (`common/`: console, undo, alerts, time-outs, marks,
      live chrome) — both live views compose them
- [x] `ScoreboardView` setting (persisted per-device via `shared_preferences`,
      overridable per session on the setup screen)
- [x] Wire prototype screens to the real engine (`RoundController` over
      `RoundView`; `FakeRound` no longer used by the production app)
- [x] Live scoring screen in both modes (running scores, auto quiz-out/strike-out
      alerts) over the shared `RoundView`
- [x] Round summary + PDF/CSV export (mode-agnostic, single implementation;
      share sheet via `share_plus`)
- [x] SQLite autosave & round resume (`sqlite3` direct, journal-as-rows;
      save-on-event, resume re-folds). Writes are delta writes inside one
      transaction (`RoundStore.saveJournal`), so a kill mid-save leaves the
      previous journal intact rather than a half-written one, and
      `deleteRound` is atomic too.
- [x] Versioned schema migrations (`PRAGMA user_version` + ordered
      `_migrations`, one transaction per step; refuses a database from a newer
      build) and space reclamation (`auto_vacuum = INCREMENTAL`, one-time
      conversion for older databases, `RoundStore.reclaimSpace()` after bulk
      deletes). Migration 2 rebuilds `events` as `WITHOUT ROWID` +
      `ON DELETE CASCADE`; migration 3 normalises `created_at` to UTC.
- [x] SQLite durability/concurrency pragmas at open: WAL + `synchronous = NORMAL`
      (keeps the per-tap fsync off the UI isolate), `busy_timeout`, enforced
      foreign keys (enabled *after* migrations, so a rebuild runs with them off
      as SQLite requires), `PRAGMA optimize` on close. A failed autosave is
      caught, kept off the repaint path (`RoundController.saveError`), and shown
      as a persistent "NOT SAVING" strip in both live views.
- [x] Saved-round timestamps: stored as UTC (`Z`-suffixed) and rendered
      readably (`10 Oct 2026, 14:23`) via `lib/app/timestamps.dart`
- [x] Void / substitute-question / substitute-quizzer UI entry points
      (documented gap in `docs/design/interaction.md` §7)
- [x] Tests: engine goldens + `RoundController` adapter + store round-trip +
      widget flows (setup, Classic scoring/undo, Modern scoring), storage
      failure, dark-mode contrast, theme toggle. The store suite now also covers
      open-time pragmas, the v0→v3 migration paths (including the `events`
      rebuild preserving every journalled event), and the autosave-failure paths
      at both the controller and widget level — 176 passing

## Phase 4 — Packaging & polish
- [x] Overtime is automatic: tie after the final question appends the next
      overtime question from the ruleset sequence with a notice (no button);
      undo reverts the overtime question and the forcing ruling
- [x] Storage failures surface an actionable error card with retry
- [x] Live screens follow the app theme from a single shared seed; theme
      toggle (system → light → dark) on Home, Setup, both live headers,
      and Summary, choice persisted per device
- [x] Polish pass: UI design, usability, intuitiveness, UI logic (button prominence,
      placement, alert placement)
      - [x] Dark-mode text contrast in the live views: fixed-light team tints now
            use the fixed dark `sideInk`/`sideInkMuted`, and the deep red/green
            accents swap to lightened variants (`sideAccent`) on dark surfaces
      - [x] Notifications fire once: quiz/strike/foul-out and limit warnings no
            longer re-announce on every later ruling (`RoundController._announced`)
      - [x] Notifications re-arm on undo: an undone-out quizzer's later re-out
            announces again (substitution-safe); resume settles settled history
      - [x] Time-outs cap at the team allotment (3/3); a 4th request is denied
            and the keeper is prompted to assign the team foul (never automatic)
      - [x] Overtime time-outs per rulebook: TBQ voids remaining (none in OT);
            JBQ carries remaining + 1 extra (cap 4), announced at OT start
      - [x] Timeout buttons in the bottom right are not needed (removed from
            `LiveBottomBar`; Modern takes time-outs from a header button
            beside each team name, Classic keeps its ledger rail)
      - [x] Personal fouls on a quizzer show as a capital-F badge beside the
            score mark (`RoundView.cellHasFoul`), never replacing the cell;
            foul-only cells keep the bare F
      - [x] Team fouls tracked separately (`TeamView.teamFouls`) with a
            `TEAM FOUL n` button beside each team name (team fouls only —
            personal fouls live on the cells)
      - [x] Team contests/appeals visually tracked like time-outs
            (`TeamView.challengesUsed/unsuccessfulChallenges`) with a header
            button beside each team name (TBQ unsuccessful/3, JBQ used/2)
      - [x] Void and substitute question kept under More (needed for
            thrown-out questions); sub-question disabled until a void exists,
            void disabled once the current question is voided
      - [x] Interruptions ring the Classic column header (same orange ring as
            the Modern navigator), matching the paper circle
      - [x] Summary gated until the match is finished (bottom-bar button
            disabled mid-round; end-of-round strip stays the in-flow entry)
      - [x] Selected quizzer x current question intersect highlights (3px
            primary border on the target Classic cell)
      - [x] Footer contest/appeal button removed — the per-team header buttons
            are now the only challenge entry point
      - [x] Incorrect answer on an interrupted question does NOT advance
            (interrupted questions are re-read to the other team; the keeper
            stays put with a notice)
      - [x] Delete saved rounds from the home "Resume round" list, guarded by a
            confirmation dialog (`RoundStore.deleteRound`)
- [x] Guardrail logic pass: block impossible answers in the real engine as
      `RuleViolation`s (D10), surfaced by the scoring console
      (`canScore`/`scoreBlockedReason` prototype → `answerGuardrail`/
      `answerBlockedReason`)
      - [x] A quizzer cannot answer a question twice (`answer-quizzer-twice`)
      - [x] Once a teammate has answered, the team cannot answer again
            (`answer-team-twice`)
      - [x] One correct answer per question; a correct answer closes the
            question to both teams (`answer-question-closed`)
      - [x] A miss on a NON-interrupted question is not reread, so it closes
            the question to the opposing team (`answer-no-reread`); only an
            interrupted miss reopens it (wrong+right / wrong+wrong)
      - [x] Console disables CORRECT/INCORRECT and shows the reason when the
            selected quizzer is guarded (FOUL stays live); voiding a question
            clears its answer ledger (substitute reads fresh, D4)
- [x] Void point-retraction (D3): `VoidQuestionEvent` now reverses each
      answer recorded on the slot (points + correct/incorrect count), clears
      the slot's ledger so the substitute reads fresh (D4), and re-evaluates
      the affected quizzers' quiz-out/strike-out flags (including the quiz-out
      bonus) so a voided crossing cannot leave a stale out. Fouls still stand
      (D3); `cellOutcome`/`teamDelta`/`cellHasFoul` now read the slot records
      so the retraction shows in the Classic ledger too
- [x] Back button on both live screens' headers returns to the starting screen
      (Home); the round autosaves, so it resumes from Home
- [x] Second polishing pass:
      - [x] Unifying notice placement: all notices render in one slot above the
            scoring console, where the end-of-round strip already appeared
            (`NoticeSlot`)
      - [x] Remove unnecessary running team total row (Classic `RUNNING` row
            deleted; the team total stays in the team header)
      - [x] Remove unnecessary modern/classic selection from start screen (the
            view is picked on the setup screen when starting a round)
      - [x] Move rule set selection down from header in new round settings (now
            an in-body segmented row with the other settings)
      - [x] Decouple quizzer names from team name (per-quizzer name fields;
            blank falls back to "<Team> N")
      - [x] Add a bench section for excess quizzers + substitutions from the
            bench (single stable roster with seat numbers so a replacement
            takes the vacated seat and the seated order is preserved; setup
            bench roster; bench strips in both live views showing each quizzer's
            running total; the More menu swaps ANY seated quizzer with a bench
            quizzer — no quiz-out required — via
            `SubstituteQuizzerEvent(outIndex, benchIndex)`; the PDF/CSV export
            carries a Position column so benched points are shown)
      - [x] Dark mode color pass (theme-aware team tints/ink:
            `sideTintFor`/`sideInkFor`; deep tints + light ink in dark mode)
      - [x] Ensure widgets always fit within allowed space (no scrolling in the
            live game: ledger rows, team cards, question navigator and the
            time-out rail all size to the screen)
      - [x] Update summary page for announcements: 1st/2nd place team and the
            top two individual scorers across the whole match
- [x] Live question values (D11): the rulebooks fix a value *distribution* but
      no per-question order, so a regulation question now starts **unset** and
      the keeper sets its 10/20/30 value as the question is read. Entry points:
      the Modern navigator's value sub-row, the Classic column headers, and the
      live header's `N PTS` / `SET VALUE` badge — all open the shared value
      dialog over the ruleset's `answerValues`. Selecting a quizzer on an unset
      question also replaces CORRECT/INCORRECT with value buttons. The value
      locks once answered (`question-value-locked`); overtime slots keep
      their rule value and are read-only; a voided slot takes its value from the
      substitute. Presets drop the built-in sequence for `answerValues` +
      `valueCounts` and bump to schema v2; the change journals as
      `QuestionValueEvent` (autosave / undo / refold)
- [x] Question-set value guardrails (D12), advisory (never blocks a value the
      keeper enters): `collectNotices` raises a one-time notice when the entered
      set breaks a rulebook stipulation — the value distribution (both books)
      plus, for JBQ, the arrangement rules (≥3 twenties and ≥1 thirty per half,
      no 30 first/last, no consecutive 30s). Constraints live in
      `match.valueRules` (ruleset-as-data; absent ⇒ none), read regulation slots
      only (overtime exempt), and judge the per-half minimums only once a half
      is fully assigned. Fired from `setQuestionValue` through the existing
      fire-once / undo-resume notice machinery
- [x] Accessibility (Semantics) + haptics pass: opt-in haptics (off by
      default; `HapticsController`/`HapticsScope` + header toggle), audio
      silenced app-wide (Material `enableFeedback` off in `buildTheme`,
      silent custom option rows, custom InkWells off),
      semantic labels for console/quizzers/marks/scores, live-region alert
      banner, live-screen text scale capped at 1.3× (audited at 1.5/2.0)
- [x] CI workflows (`.github/workflows/`): `ci.yml` (analyze + test on
      push/PR) and `build.yml` (Android APK + Linux + Windows + macOS on `v*`
      tags and manual dispatch, artifacts attached to a GitHub Release)
- [x] macOS desktop scaffolding (`macos/` Xcode runner): bundle id
      `org.concordance.app`, app name "Concordance", landscape-tablet default
      window (1280×800, min 1024×700), sandboxed no-network entitlements,
      AGPL-3.0-only copyright. Build-ready; the actual `flutter build macos`
      and `.dmg` packaging require a Mac with Xcode

## Phase 5 — Distribution trust (raised platform warnings)

- [x] Android release signing driven by GitHub secrets (`ANDROID_KEYSTORE_BASE64`
      / `_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`), decoded into
      the runner temp dir, with a debug-key fallback so local release builds keep
      working; CI prints the APK signer via `apksigner --print-certs`
- [x] Release `SHA256SUMS` published with every release (all four artifacts)
- [x] Desktop identity metadata unified to "Concordance" (Windows `VERSIONINFO`,
      Windows/Linux window titles, AGPL-3.0-only copyright)

## Phase 6 — Beta release prep
- [x] Branded app launcher icons (Android/Windows/macOS) via flutter_launcher_icons
- [x] Linux `.desktop` entry + hicolor icon (installed via `linux/CMakeLists.txt`)
- [x] In-app About dialog (version + AGPL-3.0-only notice + license list)
- [x] Community health files (SECURITY.md, CODE_OF_CONDUCT.md, issue/PR templates)
- [x] README disclaimer (unaffiliated; not for official matches yet)
- [x] Removed dead `lib/prototype/`; reframed `docs/design/interaction.md`
- [x] `.clinerules/` untracked (kept local only; gitignored)
- [x] Version set to `1.0.0-beta`; CHANGELOG `[1.0.0-beta]` cut
- [x] Documentation site scaffolded: Zensical (MkDocs Material's successor;
      `mkdocs-material` kept pinned as a fallback builder until Zensical is
      past 1.0) over the tracked `docs/` folder (`mkdocs.yml`,
      `requirements-docs.txt`), a Diátaxis-style nav (getting started · per-OS
      installation · user guide · rulesets · reference · explanations ·
      troubleshooting/FAQ · project), deployed to GitHub Pages by
      `.github/workflows/wiki.yml` and link-checked by the new `docs` job in
      `ci.yml` (`zensical build --strict`)
- [x] Rulebook PDFs excluded from the published wiki (`plugins: exclude:` +
      `*.pdf` glob in `mkdocs.yml`; both builders had been copying the
      gitignored `docs/*.pdf` files into `site/`, which the Pages deploy
      publishes wholesale)
- [x] Versioned docs published with **mike** (the Zensical-compatible fork
      `squidfunk/mike`, pinned to a commit SHA in `requirements-docs.txt`):
      `mkdocs.yml` sets `extra.version.provider: mike`; `wiki.yml` deploys a
      `v*` tag as `<version>` + `latest` (default), a `main` push as the moving
      `dev` version, or an explicit `version` via manual dispatch — committing
      to a `gh-pages` branch that Pages serves (`mike` builds through
      `zensical`, so the `*.pdf` exclusion still holds)
- [ ] Re-evaluate the docs toolchain after Zensical's 0.1.0 community launch
      (Nov 5, 2026): confirm the pinned `zensical==0.0.69` still builds clean,
      then bump; once Zensical is 1.x and proven across a release cycle or
      two, drop `mkdocs-material` from `requirements-docs.txt` and delete the
      fallback notes in its header / `.clinerules/toolchain-and-commands.md`
- [x] Write out the documentation content — every wiki page is now finished
      prose (home, getting started, per-device installation, the user guide,
      rulesets, reference, explanations, and troubleshooting/FAQ), written in a
      plain voice for a volunteer scorekeeper
- [ ] Capture per-OS installation screenshots (Fire HD 10 from the
      `fire_hd_10` emulator; Windows/macOS on those machines)
- [x] Enable Pages on the GitHub repo (Settings → Pages → Source: **Deploy
      from a branch** → `gh-pages` → `/ (root)`) — required once before the
      versioned deploy workflow can publish (the first `wiki.yml` run creates
      the `gh-pages` branch)
- [x] Publish the `v1.0.0-beta` GitHub Release (signed APK + desktop bundles + SHA256SUMS)
- [ ] Installation, setup, and touch verification pass on a real tablet
- [ ] Live match test; verify that a new user can keep up with a live game and scorekeep accurately
- [ ] Public release of v1.0.0

## Requested improvements — next pass
- [x] **Direct action edit for answers and questions (Classic)**
      - *Tap the mark, edit the mark*: tapping a marked Classic answer cell
        opens a compact editor with `MARK CORRECT` / `MARK INCORRECT` and
        `REMOVE RULING`. Removing jumps to that question and selects the
        quizzer, so the corrected ruling is recorded immediately from the
        console. Empty cells keep navigate/select.
      - Answer replacements happen at the **original journal position**, so a
        later interrupted re-read, substitution, or void still replays
        correctly.
      - Tapping an answered, interrupted, or voided question header opens a
        question editor: change the value (including after an answer), void an
        answered question (clear it and re-read the substitute at the same
        value), void a voided question again, remove an interruption, or remove
        a void (and its legacy substitute event). Normal unanswered headers keep
        the quick value picker.
      - Dependency handling refolds the candidate journal, lists the minimum set
        of later actions that no longer apply (e.g. a re-read answer after an
        interruption removal), and asks once before removing them. Unrelated
        later actions are preserved.
      - Engine: `RoundView.replayCandidate` / `replaceJournal` validate and
        refold from the captured roster/value seeds; the controller exposes
        cell/question lookups plus change/remove operations. A static,
        dismissible `UNDO EDIT` strip restores the pre-edit journal and clears
        on the next normal scoring action.
      - Persistence: `RoundStore.replaceJournal` rewrites the journal in one
        transaction; autosave distinguishes deltas from rewrites. No schema
        migration.
      - Also fixed while refolding: undo/refold now preserves the bench roster,
        and a voided slot's substitute value displays consistently in the
        ledger, navigator, console, and summary.
- [ ] Revisit direct editing for timeouts, contests, team/quizzer fouls,
      substitutions, and the Modern question navigator only if real use shows
      the existing Undo path is not enough.
- [x] **Combine void + substitute question into one "void question" action**
      - Decision: by the rules a voided question is immediately re-read as a
        substitute at the same point value, so there is no separate substitute
        entry point.
      - `VoidQuestionEvent` now optionally carries the substitute value; one
        event retracts the answers, leaves fouls standing (D3), and reopens the
        slot at the same value (D4). A legacy void-only event still replays.
      - The footer button clears the current question when it has a value and
        is enabled only when it can act. The answered-question editor also
        exposes `VOID QUESTION`.
      - A voided question's editor exposes `VOID QUESTION AGAIN`, which clears
        any answers recorded on the current substitute read and re-reads at the
        same value. Multiple voids on one question are supported.
      - There is no separate "remove substitute question" action or UI; the
        substitute value is carried by the void event itself. Legacy separate
        substitute events are still removed with the void.
      - One Undo reverses a void (one event), and the `UNDO EDIT` strip covers
        it like any other direct edit.
- [x] **Move footer actions out of the "More" menu**
      - The More overflow is gone. Footer order: **Undo · Interruption · Void
        question · Substitute quizzer · Summary**, with flexible widths so the
        undo label shrinks instead of clipping.
      - All actions are direct 48dp buttons; the separate "Read substitute
        question" entry point was removed with the combined void action.
      - Verified at 1280x800 and the 1024x700 minimum via widget tests, and the
        live-screen 1.3x text cap remains in force.
- [x] **Redesign quizzer substitution selection**
      - One centered swap board replaces the two-dialog flow: Red/Green team
        tabs, **At the table** and **Bench** columns, seat/badge/status/score
        cards, a live out→in summary, and a single confirm button.
      - Selecting an outgoing quizzer and an eligible bench entrant updates the
        summary immediately; confirm stays disabled until both are valid.
        Switching teams clears the selection. Ineligible bench quizzers stay
        visible, dimmed with their status.
      - Empty states cover no bench quizzers and no eligible bench quizzers;
        the footer reports when neither team has a bench at all.
      - The board is a shared widget used by both live views, capped at the
        live 1.3× text scale, with 48dp+ targets and semantic labels.
      - A seated quizzer who quizzes out while their team has an eligible bench
        quizzer produces a persistent team-tinted substitution prompt in the
        notice slot. `SUBSTITUTE` opens the board with the team locked and the
        outgoing quizzer preselected; dismissing the prompt keeps it out of the
        way until that quiz-out is undone or a newer one appears. While the
        prompt is visible it replaces the duplicate quiz-out alert, and
        dismissing it clears both.
      - Tests: controller prompt lifecycle (create, dismiss, undo/re-arm,
        substitute, newest-out), board selection/confirm/seat swap, preselected
        quiz-out mode, empty state, and 1024×700 + 1.3× fit.
- [x] **Cell navigation preserves the selected quizzer**
      - Tapping another question's ledger cell for the already-selected quizzer
        now keeps them armed instead of toggling them off. The Classic cell tap
        uses a non-toggling selection path; tapping the quizzer label/card still
        toggles as before.

- [x] **Cohesive small decision menus**
      - Contest outcome, foul assignment, and point-value selection now use one
        shared compact dialog shell matching the substitution board/editor:
        rounded surface, strong title and subtitle, icon-led option cards, 48dp
        targets, and the live 1.3x text cap.
      - The value picker uses large 10/20/30 cards with hover/press fill and
        border feedback. The header `SET VALUE`, an empty Classic column header,
        and the Modern navigator value row all open the same dialog; the Classic
        question editor now uses the same value cards instead of pills.
      - Console CORRECT / INCORRECT / FOUL labels use the same large, bold type
        as the console value buttons.
      - Removed the old `SimpleDialog` / anchored popup menu paths and their
        unused quiet-option widgets.

- [x] **Console value selection before scoring**
      - Selecting a quizzer on a question whose point value is unset now replaces
        CORRECT/INCORRECT with `10 PTS` / `20 PTS` / `30 PTS` buttons instead of
        showing a blocked message. Choosing a value records it and restores the
        ruling buttons with the new point delta. The header `SET VALUE` and
        navigator value row remain alternate entry points.
- [x] **Seat-title badges and bench cards**
      - Seated quizzers show a small team-tinted `RED n` / `GREEN n` title pill
        next to their name in Classic row labels, Modern cards, the substitution
        board, and the summary individual table. The fill is the pale team tint
        with a colored border/text, the text is 10–11px for readability, and the
        name remains bolder so the title stays visually secondary.
      - The badge travels with the position, not the quizzer: a substitution
        hands the seat over and the badge updates immediately while the name
        stays with the quizzer.
      - Bench quizzers now appear as compact cards (bench `B` badge, bold name,
        running score, out status when applicable) instead of a text line, in
        both live views. Cards size to their content rather than stretching; a
        long bench scrolls horizontally inside the bench row.
      - Verified at 1024x700 and the live 1.3x text cap; bench cards were
        compacted and the footer kept at 60dp so the prompt still fits.
- [ ] Revisit blank-name fallback naming
      - Auto-generated `<Team> n` names are now visually separated from the
        colored seat badge, but the fallback can still read like a seat title.
        Decide a stable neutral fallback (e.g. roster-position based) and update
        setup copy/tests; the live badge already shows the current seat.

## Post-v1
- [ ] Add settings page accessible from inside a live-game: change rule 
      set, change theme/color, etc

### Deferred (requires accounts / public repo)
- [ ] **Windows Authenticode** via SignPath Foundation (free, OV-level) — apply
      once the GitHub repo goes public; sign the PE files then the package.
      Alternative: Azure Artifact Signing (~$9.99/mo). Note: EV certs no longer
      bypass SmartScreen (removed 2024), so OV is sufficient.
- [ ] macOS distribution pass (on a Mac): `flutter build macos` → wrap the
      `.app` in a `.dmg`; optionally Developer ID sign + notarize for a clean
      Gatekeeper experience (unsigned works via right-click-Open)
- [ ] **macOS notarization** — Apple Developer Program ($99/yr) + Developer ID
      Application cert + `ENABLE_HARDENED_RUNTIME = YES` (currently ad-hoc
      `CODE_SIGN_IDENTITY = "-"`), then `codesign` → `notarytool submit --wait`
      → `stapler staple` in CI (App Store Connect API key as secrets)
- [x] GitHub artifact attestations (free for public repos only)
- [ ] Submit release binaries to AV vendors for false-positive whitelisting
