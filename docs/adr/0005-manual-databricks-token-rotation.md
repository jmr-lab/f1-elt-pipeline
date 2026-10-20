# ADR-0005: Manual Databricks Token Rotation

**Status:** Accepted
**Date:** 2026-10-20

## Context

The publish job authenticates to Databricks with a personal access token stored
as a repository secret.

Personal access tokens expire, and expiry is **immutable after creation**. The
Databricks Token API permits updating only a token's comment and scopes; the
`update_mask` accepts `comment,scopes` and nothing else. There is no supported
mechanism to extend a token's lifetime — the only path is to revoke and reissue.
The workspace-level `maxTokenLifetimeDays` setting applies to new tokens only.

On a Free Edition account the default lifetime is short, and the ceiling
available to the user is not documented.

## Decision

Rotate the token manually. Document the procedure in the README's
Troubleshooting section: generate a new token, update the `DATABRICKS_TOKEN`
secret, re-run the workflow.

## Alternatives Considered

1. **Automated rotation.** A scheduled workflow mints a replacement token using
   the currently valid one and writes it to the repository secret via the
   GitHub API. Rejected for now: it requires a second long-lived credential (a
   GitHub PAT with `Secrets: write`) to authorise the secret update. This trades
   a 14-day rotation problem for a longer-lived one, and introduces a failure
   mode where a botched rotation locks out both tokens.
2. **Service principal with OAuth M2M.** The production-grade answer on paid
   tiers. Availability on Free Edition is unverified, and OAuth access tokens
   are themselves short-lived (typically one hour), so this would replace manual
   rotation with client-side refresh logic rather than eliminate it.
3. **Two-token alternation.** Keep two valid tokens and rotate them alternately,
   reducing the chance that a failed rotation leaves no working credential.
   Compatible with the chosen approach; not currently implemented.

## Consequences

**Positive**

- No second long-lived credential exists to be leaked or mismanaged.
- Quota consumption stays intentional — a human decides when the pipeline runs
  against the free tier.
- Rotation is a two-minute manual operation.

**Negative**

- The pipeline fails when the token lapses, with an authentication error rather
  than a clear expiry notice.
- Requires human attention on an irregular schedule.
- Nothing warns in advance that expiry is approaching.

## Mitigation

Failure is contained by ADR-0003: `publish_databricks` runs in parallel with
`transform`, so a lapsed token does not block the SQLite build, the release, or
the documentation deployment. The blast radius is one job.

## Revisit Trigger

Availability of service principals on the account tier, or rotation becoming
frequent enough that manual handling is a nuisance rather than a footnote.
docs/adr/0006-qualified-drop-statements.md
# ADR-0006: Qualify DROP Statements When Multiple Schemas Are Attached

**Status:** Accepted — fix applied
**Date:** 2026-10-20
**Type:** Incident record

## Context

`transform-tables.sql` builds `formula1.db` from `jolpica.db`. It begins by
attaching the source:

```sql
ATTACH DATABASE 'jolpica.db' AS jolpica;
```

and then drops the target tables before recreating them, so the script is idempotent.

During development, the transform step began failing with a cascade of errors:

```
Parse error near line 309: no such table: jolpica.season
Parse error near line 316: no such table: jolpica.circuit
Parse error near line 322: no such table: jolpica.driver
... (twelve in total)
Runtime error near line 452: UNIQUE constraint failed:
  constructor_season.constructor_id, constructor_season.season_id (19)
```

## Hypotheses Investigated

Recorded because the diagnosis path is more instructive than the fix.

1. **Artefact not downloaded, or downloaded after the verification step.** Disproved: the artefact was present at 17.5 MB, and the verification step reported 19 tables in `jolpica.db` immediately before the transform ran.
2. **`jolpica.db` genuinely missing tables.** Disproved: the same verification step counted 19 tables, and the load job's own output showed 44 MB and 19 tables.
3. **Duplicate `INSERT INTO constructor_season` causing an early abort.** Partly correct — there was a duplicated statement, and removing it cleared the `UNIQUE constraint` error. But the no such table errors persisted, which ruled this out as the root cause.
4. **Working-directory or path resolution problem.** Disproved: the script ran from `dist/` and attached `jolpica.db` successfully — the attach did not error, which is itself the clue.

## Root Cause

SQLite resolves an **unqualified** table name by searching temp, then main, then each attached schema in attachment order.

The script attached `jolpica.db`, then executed:

```sql
DROP TABLE IF EXISTS season;
````

At that moment main was `formula1.db` — freshly created and empty — so season did not exist there. Resolution fell through to the attached schema and dropped `**jolpica.season**`, destructively, on disk. Every later reference to `jolpica.season` then failed.

The corroborating evidence is the pattern of which tables failed. Errors occurred only for tables whose names are identical in both schemas:

| Source reference | Errored | Collides with a DROP target |
| --- | --- | --- |
| jolpica.season | yes | season |
| jolpica.circuit | yes | circuit |
| jolpica.driver | yes | driver |
| jolpica.round | yes | round |
| jolpica.session_entry | yes | session_entry |
| jolpica.team | no | DROP target is constructor |
| jolpica.team_driver | no | DROP target is constructor_driver |
| jolpica.roundentry | no | DROP target is round_entry |
| jolpica.base_team | no | DROP target is constructor_base |


Every failure is a name collision; every survivor is a renamed table. That correlation is what identified the mechanism.

## Fix

Qualify every DROP with main.:

```sql
DROP VIEW  IF EXISTS main.f1summary;
DROP TABLE IF EXISTS main.season;
DROP TABLE IF EXISTS main.circuit;
-- ...
```

Moving the DROP block above the ATTACH would also work, since nothing is attached at that point. Qualification was preferred because it remains correct regardless of statement order.

Additionally, .bail on was added as the first line of the script, so execution halts at the first error instead of emitting twelve cascading ones.

## Prevention

- Qualify DDL targets explicitly whenever more than one schema is attached. Unqualified CREATE happens to target main, but relying on that is fragile.
- Put .bail on at the top of any multi-statement SQL script.
- Verify the source database before running destructive operations against it.

## Lesson

The failure mode was **destructive and silent**. The script mutated the database it was reading from, and the resulting errors pointed at the wrong component — the error messages named missing tables, which invites the conclusion that the source was incomplete rather than that it had just been deleted.

Damage was avoided only because the source was re-downloaded from the artefact on every run. Had the transform read from the committed copy in `dist/` or from the release asset, a failed run could have corrupted the source of truth.

This is a concrete argument for treating the CI artefact as the hand-off between jobs rather than reading from any mutable shared location.
