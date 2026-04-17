# ADR 0011: Architecture Freeze

- Status: Accepted
- Date: 2026-04-17
- Deciders: Recharge team
- Baseline: [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md)

## Context

The team agreed on a target architecture that supports product growth, clear module boundaries, and predictable delivery.  
Frequent structural changes at this stage would create churn and slow feature development.

## Decision

We freeze the architecture described in `docs/architecture/ARCHITECTURE_BASELINE.md` as the official project baseline.

From this point:

- New implementation work must follow the baseline tree and mandatory rules.
- Structural changes (new top-level modules, layer changes, boundary rule changes, package responsibility changes) are not allowed without a new ADR.
- Exceptions are temporary and must be documented in PR with a follow-up ADR task.

## Consequences

- Positive: stable implementation path, less rework, better onboarding, clearer review criteria.
- Trade-off: architecture changes become intentionally slower due to explicit decision process.
- Operational rule: if a change impacts architecture, create a mini-RFC first, then merge only after ADR acceptance.
