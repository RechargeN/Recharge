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
   - canonical: `dart tools/scripts/check_boundaries.dart --repo-root . --format text`
   - Windows compatibility wrapper:
     `powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/check-boundaries.ps1`
2. CI check:
   - `.github/workflows/mobile-ci.yml` -> `boundaries` job.

Only the Dart file contains scan/policy logic. The PowerShell file is a thin
wrapper and must return the Dart process exit code unchanged.

## 4) Scope Of Automated Check

The checker validates:

- `import` and `export` statements;
- multiline, deferred and conditional directive URIs;
- package-style imports containing `/features/<name>/...`;
- relative imports resolved to physical files in `features`.
- domain dependencies on framework/infrastructure packages;
- domain dependencies on `core` pending primitive reconciliation;
- feature dependencies on `app/di` and `app/presentation`;
- stale, expired, duplicate or over-budget exceptions.

The checker reports:

- cross-feature imports;
- forbidden layer direction imports within the same feature.
- machine-readable JSON and deterministic Markdown inventory.

Exit codes are contractual:

- `0` — pass;
- `1` — architecture, stale, expired or budget violation;
- `2` — missing runtime/root, invalid config or parser/tooling error.

Only `0` is a pass. Semantic placement that imports alone cannot prove remains
an explicit review responsibility under Mobile Architecture AC-61–62.

## 5) Exceptions

Exceptions are not allowed by default.
If an exception is needed, follow:

1. mini-RFC (max 1 page),
2. approval,
3. ADR update/creation,
4. temporary scope and expiry date. Only the frozen M1 legacy baseline may use
   `expiresOn: null`, and then only with an explicit approved rationale and a
   named remediation slice; this exception cannot be copied to new debt.

Reference: [CHANGE_POLICY.md](./CHANGE_POLICY.md)

## 6) Structured Legacy Registry

Current debt is stored only in `tools/scripts/boundary-exceptions.json`:

- 106 exact entries, no wildcards;
- stable ID, rule, source, target, owner, reason and remediation slice;
- budget 106, which may decrease but cannot increase inside ordinary slices;
- stale/expired entries fail the gate and must be removed;
- a new entry requires mini-RFC, explicit approval and applicable ADR path;
- `docs/architecture/MOBILE_BOUNDARY_INVENTORY.md` is generator-owned and
  checked for drift in CI.

The legacy `boundaries-allowlist.txt` no longer exists. The release goal remains
gradual, evidence-backed reduction to zero through bounded remediation slices.
