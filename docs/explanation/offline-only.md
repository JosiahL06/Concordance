# Offline-only, no accounts

**The question this answers:** will this app need the internet, or send anything
about my match anywhere?

## The choice

Concordance works on one device, with no server and no account. This is not a
feature missing from the app that might arrive later — it is a boundary the app
is built to keep. The official Bible Quiz records system does not offer a public
way for another program to connect, so sharing scores online was never
something the project could rely on.

## What that gives you

- It works without any signal at all.
- There is nothing to sign in to.
- There is nothing to leak, because nothing leaves the device.
- A dropped connection or a hotel-style sign-in page cannot interrupt a match.

## The cost

A round lives on the one device it was recorded on. To share a result, save it
as a PDF or a spreadsheet file and send that file. See
[Match summary](../guide/match-summary.md).

## Privacy in practice

There is no usage tracking, no analytics, and no crash reports. The app does not
even ask the device for permission to use the internet, so it cannot connect
even by accident. See [Data & storage](../reference/data-and-storage.md) for
exactly what is kept and where.

## If an online version ever exists

If the project ever adds an online way to share results, the main job of scoring
a round on one device would stay offline.

## Related

- [Data & storage](../reference/data-and-storage.md)
- [Why Concordance works this way](index.md)
