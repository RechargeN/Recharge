# Import Boundaries

This document defines mandatory dependency boundaries between feature layers and how they are enforced.

## 1) Layer Dependency Matrix

Allowed directions inside a feature:

- `presentation -> presentation | application | domain`
- `application -> application | domain`
- `data -> data | domain`
- `domain -> domain`

Forbidden directions inside a feature:

- `application -> data`
- `application -> presentation`
- `data -> application`
- `data -> presentation`
- `domain -> data | application | presentation`
- `presentation -> data`

## 2) Cross-Feature Rule

- Direct imports from one feature to another are forbidden.
- Example (forbidden): `features/discover/...` importing `features/auth/...`.
- Cross-feature interaction must go through contracts/facades and app composition wiring.

## 3) Enforcement

Checks are mandatory in both places:

1. Local check:
   - `powershell -ExecutionPolicy Bypass -File tools/scripts/check-boundaries.ps1`
2. CI check:
   - `.github/workflows/mobile-ci.yml` -> `boundaries` job.

## 4) Scope Of Automated Check

The checker validates:

- `import` and `export` statements;
- package-style imports containing `/features/<name>/...`;
- relative imports resolved to physical files in `features`.

The checker reports:

- cross-feature imports;
- forbidden layer direction imports within the same feature.

## 5) Exceptions

Exceptions are not allowed by default.
If an exception is needed, follow:

1. mini-RFC (max 1 page),
2. approval,
3. ADR update/creation,
4. temporary scope and expiry date.

Reference: [CHANGE_POLICY.md](./CHANGE_POLICY.md)

## 6) Legacy Allowlist (MVP Transition)

For current MVP baseline, a temporary allowlist is used:

- file: `tools/scripts/boundaries-allowlist.txt`
- enforced by: `tools/scripts/check-boundaries.ps1`
- policy:
  - only legacy known violations may stay in allowlist;
  - adding new entries requires mini-RFC + approval + ADR update;
  - release goal is gradual reduction of allowlist size to zero.
