# Architecture Decision Records

This directory records the significant design decisions behind the F1 ELT
pipeline: what was decided, what alternatives were rejected, and what the
consequences are.

The purpose is not documentation of what the system does — the main
[README](../../README.md) covers that. It is documentation of **why**, including
the roads not taken and the gaps knowingly left open.

## Index

| ADR | Title | Status | Decision in brief |
|-----|-------|--------|-------------------|
| [0001](0001-sqlite-as-intermediate-format.md) | SQLite as the Intermediate Data Format | Accepted | Land raw data in a normalised SQLite database as the canonical intermediate representation |
| [0002](0002-full-reload-instead-of-incremental.md) | Full Reload Instead of Incremental Processing | Accepted | Rebuild every table on every run; no watermarks or merge logic |
| [0003](0003-parallel-transform-and-publish.md) | Parallel Transform and Publish Jobs | Accepted | `transform` and `publish_databricks` both depend only on `load` |
| [0004](0004-mutable-release-pointer.md) | Mutable Release Pointer for Data Distribution | Accepted, with a known gap | Publish a single updatable `data-latest` release rather than versioned tags |
| [0005](0005-manual-databricks-token-rotation.md) | Manual Databricks Token Rotation | Accepted | Rotate the Databricks token by hand; do not automate |
| [0006](0006-qualified-drop-statements.md) | Qualify DROP Statements When Multiple Schemas Are Attached | Accepted — fix applied | Qualify every DDL target with `main.`; incident record |

## Reading Order

If you are new to the project, read in this order:

1. **[0002](0002-full-reload-instead-of-incremental.md)** — establishes the central
   trade-off. Most other decisions follow from the choice to rebuild everything
   each run.
2. **[0001](0001-sqlite-as-intermediate-format.md)** — explains the storage
   choice that makes the full-reload approach affordable.
3. **[0003](0003-parallel-transform-and-publish.md)** — the job graph, and why
   failure isolation matters here.
4. **[0006](0006-qualified-drop-statements.md)** — an incident record. Worth
   reading for the diagnostic reasoning rather than the fix.
5. **[0005](0005-manual-databricks-token-rotation.md)** — an operational
   constraint imposed by the account tier.
6. **[0004](0004-mutable-release-pointer.md)** — the one decision with an
   acknowledged gap.

## Deliberate Omissions

Some things are absent from this pipeline by choice rather than oversight. These
are recorded so that their absence reads as a decision rather than an
oversight:

- **Incremental processing** — see [0002](0002-full-reload-instead-of-incremental.md)
- **Schema drift detection** — not implemented; an upstream column change would
  surface as a dbt test failure rather than a clear diagnostic
- **Immutable release versioning** — see [0004](0004-mutable-release-pointer.md)
- **Automated token rotation** — see [0005](0005-manual-databricks-token-rotation.md)

## Adding a New ADR

1. Copy [`template.md`](template.md) to `NNNN-short-title.md`, where `NNNN` is
   the next number in sequence.
2. Fill in Context, Decision, Alternatives Considered, and Consequences.
3. Add a row to the index above.
4. Commit alongside the change it describes, not afterwards.

Numbers are assigned monotonically and never reused. If a decision is reversed,
write a new ADR that supersedes the old one and update both statuses — do not
edit the original. The record of a decision that turned out to be wrong is more
useful than a tidy history.

## Convention Notes

Each ADR follows a light adaptation of the
[Michael Nygard format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions),
with two additions used here:

- **Revisit Trigger** — the condition under which the decision should be
  reopened. Without this, "accepted" tends to calcify into "permanent."
- **Known Gap** — used where a limitation is understood and consciously not
  addressed, so the omission is visible rather than latent.

ADRs describe decisions, not intentions. A feature that is planned but not built
belongs in the main README's roadmap, not here.
