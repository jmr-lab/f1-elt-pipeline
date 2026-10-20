# ADR-0001: SQLite as the Intermediate Data Format

**Date:** 2026-10-20

## Context

Jolpica publishes the F1 dataset as a set of CSV dumps. The pipeline needs a
working representation between extraction and publication that supports:

- validating referential integrity before any cloud operation
- developing and testing transform logic without a network round-trip
- handing a single artefact between CI jobs and attaching it to a release

## Decision

Land the raw data in a normalised SQLite database (`dist/jolpica.db`) as the
canonical intermediate representation. Derive the analytics database
(`dist/formula1.db`) from it with SQL, and publish to Databricks from it.

## Alternatives Considered

1. **Publish CSVs straight to Databricks and transform there.** Rejected: no
   local validation, every development iteration requires cloud compute, and
   the loop becomes dependent on a quota-limited free tier.
2. **Parquet as the intermediate format.** Rejected: no ad-hoc query interface,
   so validation would need bespoke code rather than a `sqlite3` invocation.
3. **DuckDB.** A credible alternative with stronger typing and better analytical
   performance. Rejected for familiarity and because the workload is small
   enough that the difference is immaterial. Worth revisiting if the transform
   grows heavier.
4. **PostgreSQL.** Rejected: operational overhead (a running server) is not
   justified for a single-file dataset refreshed twice weekly.
5. **In-memory pandas only.** Rejected: no persistence between CI jobs, and the
   artefact handoff requires a file.

## Consequences

**Positive**

- Foreign-key relationships validated locally before any cloud operation.
- Transform logic exercisable offline; Databricks is a destination, not a
  development environment.
- A single file is trivial to pass between jobs and attach to a release.

**Negative**

- SQLite does not enforce declared types. An `INTEGER` column can hold text, so
  the publish script inspects actual storage classes with `typeof()` and widens
  affected columns to `STRING`. This is handled but adds complexity.
- Foreign-key enforcement requires `PRAGMA foreign_keys = ON` per connection.
- `dist/jolpica.db` is committed to the repository, so a ~44 MB binary is added
  to git history on each run. Acceptable at this scale; it would not be at ten
  times the size.

## Revisit Trigger

Dataset growth beyond comfortable single-file handling, concurrent writer
requirements, or a transform heavy enough that DuckDB's performance advantage
becomes material.
