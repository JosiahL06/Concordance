# Security Policy

## Supported versions

Concordance is currently in **beta**. Only the latest published release is
supported with fixes.

## Reporting a vulnerability

Please report suspected security issues **privately** — do not open a public
issue. Use either:

- GitHub's **Security** tab → *Report a vulnerability* (private advisory), or
- Email **Josiah.Laakkonen6@gmail.com**.

Please include the version (About dialog on the home screen), platform, and
steps to reproduce. We aim to acknowledge reports within a reasonable time.

## Scope

Concordance is designed to be **fully offline**: it makes no network requests
and has no accounts, server, or telemetry. Its attack surface is therefore small
and limited to parsing local data — saved rounds in the app's SQLite database
and ruleset configuration JSON. Reports that could corrupt saved rounds, render
untrusted input dangerously, or crash the app are still welcome.
