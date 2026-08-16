# API Contracts Workflow

This document defines how API contracts are changed, generated, and consumed.

- Version: 1.1
- Effective date: 2026-08-08
- Related architecture: [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md)

## 1) Source Of Truth

- Canonical Dart-only contracts live in
  `packages/api_contracts/lib/src/contracts/`.
- A cross-language contract authorized by an Accepted ADR uses a
  language-neutral schema under `packages/api_contracts/schema/<domain>/<version>/`
  as its source of truth. ADR 0019 authorizes this exception for Booking.
- Dart and TypeScript DTOs/validators for a cross-language contract are
  generated or fixture-verified from the same schema; neither language model
  may silently redefine wire semantics.
- DTOs and clients are generated from their applicable canonical source.
- Generated output is committed only from codegen, never manually edited.

## 2) Change Types

Contract changes are classified as:

- Non-breaking:
  - adding optional fields;
  - adding new endpoints;
  - broadening accepted values safely.
- Breaking:
  - removing/renaming fields;
  - changing required/optional status incompatibly;
  - changing response semantics or endpoint behavior incompatibly.

## 3) Breaking Change Rules

For every breaking change:

1. Add `BREAKING CHANGE` note in PR.
2. Link migration notes for consumers.
3. Assign a consumer-update owner.
4. Do not merge until impacted consumers have migration plan.

## 4) Required Flow

1. Update contract source.
2. Run code generation.
3. For cross-language contracts, run shared valid/invalid/forward-compatibility
   fixtures against every consumer implementation.
4. Verify no manual generated edits.
5. Update consumer code in app/features.
6. Run tests and CI checks.
7. Merge with explicit change classification.

## 5) Ownership

- Contract owner: API/contracts maintainer.
- Consumer owner: feature owner of impacted module(s).
- Merge requires both perspectives for breaking changes.

## 6) Generated Code Policy

- Files under `generated/` are read-only for manual editing.
- Any manual edit in generated files is a policy violation.
- CI codegen check is required before merge.
- A new generator or generator-version change is an explicit reviewed tooling
  decision; documentation approval never permits hand-authored generated output.

## 7) Versioning

- Use semantic versioning for `api_contracts` package:
  - `MAJOR` for breaking changes,
  - `MINOR` for backward-compatible additions,
  - `PATCH` for fixes that do not alter contract behavior.

## 8) Release Notes Requirement

PR must include:

- change type (`non-breaking` / `breaking`);
- affected endpoints/DTOs;
- migration impact;
- consumer owner confirmation.

## 9) Fast Rollback Guidance

- Keep previous compatible contract artifacts available for one rollback window.
- If consumer migration fails in production, revert contract package version and redeploy.
