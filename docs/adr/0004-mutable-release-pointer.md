# ADR-0004: Mutable Release Pointer for Data Distribution

**Status:** Accepted, with a known gap
**Date:** 2026-10-20

## Context

The transformed database is distributed to consumers, principally the companion
Formula-1 Analytics R project. Options differ in how a consumer refers to a
particular dataset version.

## Decision

Publish a single release tagged `data-latest`, with `allowUpdates: true`, so
each run overwrites the previous release's assets rather than accumulating
releases.

## Alternatives Considered

1. **Immutable per-run tags plus a moving pointer.** Publish
   `data-20261019T063556Z` for every run and additionally update `data-latest`.
   Consumers wanting reproducibility pin the timestamped tag; consumers wanting
   current data follow the pointer.
2. **Artefacts only, no releases.** Rejected: artefact retention is 7 days,
   which is too short for a twice-weekly pipeline and unusable for a consumer
   that pulls data on its own schedule.
3. **Commit the database to the repository.** Rejected: binary growth in git
   history, and the same objection that applies to `jolpica.db` applies more
   strongly to a file consumers are expected to fetch.

## Consequences

**Positive**

- A stable, memorable URL for consumers.
- Exactly one release to manage; no accumulation of tags.

**Negative**

- Consumers cannot pin a specific dataset version.
- No audit trail of what the data looked like on a given date.
- A bad publish overwrites the previous good one with no rollback path. The
  prior asset is gone.

## Known Gap

Immutable versioned releases are **not implemented**. The gap is recorded rather
than closed because no current consumer requires reproducibility. Adding it
would mean publishing a timestamped tag alongside the pointer and retaining
those assets — straightforward, but pointless until something needs it.

## Revisit Trigger

A consumer requiring reproducible inputs, or the first bad publish that needs
rolling back.
