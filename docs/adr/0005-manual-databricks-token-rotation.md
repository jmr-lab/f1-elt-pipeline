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
