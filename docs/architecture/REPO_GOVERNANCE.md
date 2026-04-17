# Repo Governance

## Scope

This document formalizes repository workflow controls for branch management, PR review, and merge authority.

Primary reference: [CONTRIBUTING.md](../../CONTRIBUTING.md)

## Governance Rules

1. PR size rule is mandatory and enforced in review.
2. Review approvals are mandatory according to risk class (standard vs critical).
3. Merge rights are restricted to maintainers.
4. Default merge mode is squash; rebase only with explicit reason.
5. No bypass of required CI checks for non-emergency PRs.

## Critical Paths (Require 2 Approvals)

- `app/di`, routing, core infrastructure, security, telemetry;
- `.github/workflows/*`;
- architecture docs (`docs/architecture/*`, `docs/adr/*`);
- API contract boundary changes.

## Exception Handling

- Allowed only as temporary exception with issue link and expiry date.
- Exceptions without expiry are invalid.
