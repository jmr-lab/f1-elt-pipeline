# ADR-0003: Parallel Transform and Publish Jobs

**Date:** 2026-10-20

## Context

The workflow originally ran `extract → load → transform → publish_databricks`
as a linear chain, with `publish_databricks` declaring `needs: [transform]`.

`publish_databricks` reads `dist/jolpica.db`, which is produced by `load`. It
consumes nothing from `transform`. The dependency was incidental rather than
real.

This mattered because the Databricks personal access token expires periodically
and cannot be extended. A lapsed token failed `publish_databricks`, which — by
virtue of the chain — skipped `transform`, and therefore also skipped the
release and the documentation deployment. A credential problem in one component
took down the entire pipeline.

## Decision

`transform` and `publish_databricks` both depend only on `load`. Neither depends
on the other. They execute concurrently.

```yaml
transform:
  needs: [load]

publish_databricks:
  needs: [load]
```

Note that the position of job blocks within the YAML file has no bearing on execution order; GitHub derives the graph solely from needs. Blocks may be arranged for readability without affecting behaviour.

## Alternatives Considered

1. **Linear chain (the previous arrangement).** Rejected: couples an external dependency's failure to the core pipeline.
2. **Publish before transform.** Arbitrary; `publish_databricks` does not need transform to have run, but ordering them serially gains nothing.
3. **Make `publish_databricks` non-blocking via continue-on-error: true.** Rejected: hides genuine failures rather than isolating them. The job should fail visibly; it just should not take other jobs with it.

## Consequences

### Positive

- Failure isolation. A Databricks authentication or connectivity failure leaves the SQLite build, the release, and the docs untouched.
- Wall-clock reduction, since the two jobs overlap.
- Each job's success criterion is independent and legible in the Actions UI.

### Negative

- No ordering guarantee between the two. A consumer that assumes Databricks is updated before the release is published cannot rely on that.
- Both jobs download the `jolpica-db` artefact concurrently. Harmless — artefacts support multiple downloads — but worth knowing when reading logs.

## Revisit Trigger

A downstream consumer requiring a defined ordering between the release and the Databricks publish.
