# Architecture Change Policy

This policy defines how to request and approve deviations from the frozen architecture baseline.

Baseline reference: [ARCHITECTURE_BASELINE.md](./ARCHITECTURE_BASELINE.md)  
Freeze ADR reference: [0011-architecture-freeze.md](../adr/0011-architecture-freeze.md)

## When This Policy Applies

Use this flow when a change affects:

- project/module structure;
- feature boundaries;
- layer contracts (`domain/data/application/presentation`);
- ownership of `design_system` or `api_contracts`;
- generated-code policy or CI architecture gates.

## Required Process

1. Create a mini-RFC (max 1 page).
2. Get team approval (at least one architecture owner + one feature owner).
3. Create/approve a new ADR.
4. Implement only after ADR is `Accepted`.

## Mini-RFC Template (1 page max)

1. Problem statement.
2. Proposed change.
3. Alternatives considered.
4. Impact on modules/layers/import boundaries.
5. Impact on CI, tests, and rollout.
6. Migration plan and rollback plan.
7. Risks and mitigations.

## Emergency Path

For urgent production incidents, temporary deviation is allowed only if:

- it is documented in PR description;
- a follow-up ADR issue is created in the same day;
- architecture is reconciled to baseline or formalized by ADR within one sprint.
