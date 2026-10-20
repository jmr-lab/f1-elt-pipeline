# ADR-0002: Full Reload Instead of Incremental Processing

**Date:** 2026-10-20

## Context

The pipeline refreshes twice weekly from Jolpica CSV dumps. The dataset covers
completed seasons only (1950 through the previous year), totalling roughly
890K rows across 19 tables. The largest table, `lap` (~735K rows), is not used
by the current analysis and is excluded from downstream consumption.

Incremental processing is the conventional pattern for scheduled ELT. This ADR
records why it is deliberately not used here.

## Decision

Rebuild every table on every run. No watermarks, no delta detection, no
merge logic.

## Alternatives Considered

1. **Watermark-based incremental.** Track a last-loaded timestamp or maximum ID
   per source table and process only newer rows.
2. **Change data capture.** Not available — Jolpica exposes CSV dumps, not a
   change stream.
3. **Hybrid.** Incremental for fact tables, full reload for dimensions.
4. **Append-only new rounds.** Load only rounds not already present.

## Rationale

Size alone would not settle this — 890K rows is small, but small is not the
same as unimportant. The substantive reason is **retroactive correction**.

Formula 1 results change after the fact. Stewards issue penalties and
disqualifications, championship points are adjusted, and classifications are
occasionally revised weeks after a race. An append-only or watermark-based
strategy would treat an already-loaded round as complete and silently retain
stale values. Detecting corrections would require either upstream change
tracking (unavailable) or periodic full comparison (which is a full reload
wearing a disguise).

Full reload is therefore not merely cheaper — it is *more correct* for this
data.

## Consequences

**Positive**

- No state to corrupt; any run is reproducible from scratch.
- Immune to retroactive corrections by construction.
- No merge logic to test or debug.

**Negative**

- Runtime scales linearly with history.
- Every run republishes all tables to Databricks, consuming free-tier quota.
- No mechanism to resume a partially failed load.

## Revisit Trigger

Runtime exceeding roughly 20 minutes, upstream moving to intra-day granularity,
or `lap` entering the analysis scope. At that point a watermark strategy would
need to be paired with an explicit correction-detection pass, not adopted on
its own.
