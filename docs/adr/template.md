# ADR-NNNN: Title in Sentence Case

**Status:** Proposed | Accepted | Accepted, with a known gap | Superseded by ADR-NNNN | Deprecated
**Date:** YYYY-MM-DD

## Context

What is the situation that forces a decision? Include the constraints that
actually bind — account tier, data volume, upstream behaviour, team size. A
reader arriving cold should understand the problem without reading anything
else.

State facts, not preferences. If the constraint is "tokens expire every 14 days
and cannot be extended," say that; do not say "token management is awkward."

## Decision

What was decided, in the active voice, in one or two sentences. If it can be
expressed as a rule someone could follow, do that.

Include the concrete form where it helps — a YAML fragment, a SQL statement, a
command. Abstract descriptions of specific changes age badly.

## Alternatives Considered

Each alternative with the reason it was rejected. This is the section that
carries the most signal: a decision with no rejected alternatives usually means
none were seriously examined.

Number them. Rejected alternatives are not filler — they are the evidence that
the decision was made rather than defaulted into.

## Consequences

**Positive**

- What this buys.

**Negative**

- What it costs. Be honest; a consequences section with no negatives is a sign
  the decision was not examined critically.

## Known Gap

*(Optional — delete if not applicable.)*

A limitation that is understood and consciously not addressed, with the reason.
Distinguishes a deliberate omission from an oversight.

## Revisit Trigger

The condition under which this decision should be reopened. Be specific and
observable: "runtime exceeding ~20 minutes" rather than "if it becomes slow."
