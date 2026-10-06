---
description: What Concordance is — scope, goals, platform targets, licensing, and the working agreement for this repository.
version: 1.0
tags: ["project", "context", "scope"]
---

# Concordance — Project Overview

**Objective:** Keep every session grounded in what Concordance is, what is in scope, and the hard constraints that must never be violated.

## What it is
An open-source, **offline, touch-first scorekeeper for Bible Quiz matches** — a single client app for running **one round** of scoring, replacing the clunky official EZScore app with a clean, modern interface that a volunteer scorekeeper can use within seconds of being handed it.

## Scope
- **v1 = one round only.** No online sync, no accounts, no server, no API calls (the official biblequiz.com database has no public API — this is a permanent architectural boundary, not a TODO).
- Rulesets are **configurable per session/meet, presented as tabs** — the engine MUST NOT hard-code TBQ or JBQ; ship both as built-in presets and allow future rulesets without code changes.
- Question text/track display is **out of scope for v1** (record per-question outcomes only).
- Tournament/meet management (schedules, brackets, standings) is explicitly **post-v1**.

## Platform targets
- **Primary: Amazon Fire HD 10 (2023, 13th gen)** — Fire OS 8 = Android 11, API 30, 1920×1200, landscape. Fire tablets have **no Google Play services** → the app and ALL its dependencies MUST remain GMS-free. Distribution = sideloaded APK.
- Secondary: Windows (touchscreen laptops), Linux (day-to-day dev/testing), macOS (desktop; `macos/` runner scaffolded — `flutter build macos` requires a Mac with Xcode).
- **Landscape tablet-first** layout; MUST remain usable at 1280×800 logical dp.

## Identity & licensing
- App name **Concordance**; Android package id `org.concordance.app`; launcher label `Concordance`. macOS bundle id is also `org.concordance.app`.
- License: **AGPL-3.0-only** (NOT "or-later"). New files SHOULD NOT carry license headers, but any licensing statement MUST say AGPL-3.0-only.

## Working agreement
- The user performs all `git commit` / push operations — **Cline MUST NOT commit, push, or alter git history.** Present changes and let the user review.
- Remote is the user's personal **Gitea** instance, but CI workflows MUST be written under `.github/workflows/` (Gitea Actions is compatible with that layout).
- Notable changes MUST be recorded in `CHANGELOG.md` under `## [Unreleased]` (Keep a Changelog 1.1.0 + SemVer). Cline SHOULD draft entries as part of a task; the user performs the commit.
- `TODO.md` is the roadmap source of truth — update checkboxes there as phases complete; keep this rules directory in sync with any decision change.
