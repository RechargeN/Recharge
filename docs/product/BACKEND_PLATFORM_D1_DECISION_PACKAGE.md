# Recharge Backend — D1 Reconciliation and Decision Package

- ID: **BCK-D1-DEC-01**
- Version: **0.1**
- Date: **2026-08-20**
- Status: **Accepted reconciliation record — D1 exit remains blocked**
- Runtime status: **Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Parent architecture: [BCK-01 v0.4.3](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.7](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Runtime effect: **none**
- Canonical path: `docs/product/BACKEND_PLATFORM_D1_DECISION_PACKAGE.md`

---

## 1. Purpose

This package records the first evidence-backed D1 reconciliation across
BCK-03, BCK-04, BCK-05, BCK-09 and BCK-20. It closes the Booking v1
`requestId`/`idempotencyKey` contradiction without changing committed wire
shape, and records the exact status of OD-07, OD-09, OD-10 and OD-11.

It is a documentation decision package. It does not create `apps/backend`,
Firebase projects, schemas, generated code, endpoints, credentials,
deployments or production processing. Acceptance of one decision below is not
acceptance of the entire D1 platform set.

## 2. Source hierarchy and scope

Conflict priority remains:

1. Accepted ADR;
2. Approved/Accepted owning domain specification and explicit decision record;
3. BCK-01 architecture;
4. BCK-02 coordination and gates;
5. owning BCK specification;
6. fixture/code evidence for current-state truth.

This package changes no Accepted ADR invariant. The Booking key correction is
an explicit versioned contract reconciliation authorized by the Product owner
and recorded as `ECL03-D11` in the owning Event/Booking decision package.

## 3. Evidence read

The reconciliation uses:

- Booking v1 JSON Schema, valid/invalid/forward fixtures and Dart DTO tests;
- ECL-03 Approved parent, ECL-03B Done evidence and ECL-03C Review plan;
- BCK-09 Review full Booking/Firebase target;
- BCK-03 API standard and BCK-04 security/privacy blocker register;
- BCK-05 operations and BCK-20 reference/localization specifications;
- BCK-01/BCK-02 status, decision and gate registries.

Repository evidence before this decision:

- `booking_command.schema.json` requires both `requestId` and
  `idempotencyKey`;
- committed valid fixtures use distinct values;
- DTO parsing preserves both fields independently;
- BCK-09 and ECL-03C incorrectly required equality;
- no backend runtime or persistence exists, therefore no stored production
  record requires migration.

## 4. Accepted decision D1-DEC-01 / ECL03-D11

### 4.1 Semantic roles

For Booking command contract v1:

- `requestId` identifies one transport/application request attempt and is used
  for correlation and diagnostics;
- `idempotencyKey` identifies one logical mutation across retries and unknown
  outcomes;
- both are required non-empty opaque identifiers within existing Booking v1
  schema bounds;
- values may be equal, but equality is neither required nor inferred;
- a retry reuses the original `idempotencyKey` and normalized semantic payload,
  while it may carry a new `requestId`;
- every new attempt generates a fresh `requestId`; known reuse of one request
  ID with another logical key or semantic command is `invalid_argument` and
  creates no mutation;
- neither field supplies actor identity, authorization or global uniqueness.

### 4.2 Effective key and request hash

The effective idempotency namespace is:

```text
(resolvedActorOrServiceIdentity, commandType, idempotencyKey)
```

The canonical request hash covers schema-known semantic command inputs and
excludes transport-only correlation metadata, including `requestId`.
The exact canonicalization algorithm/version remains `API-DEC-03` and must be
Accepted before mutation runtime.

### 4.3 Replay outcomes

| Condition | Outcome | Mutation |
|---|---|---|
| New effective key | Validate and execute command | At most one committed effect |
| Same key, same canonical hash | Return original committed semantic outcome in an envelope for the current attempt | None |
| Same key, different canonical hash | `idempotency_conflict` | None |
| Same request ID, different idempotency key or semantic command | `invalid_argument` when detected; caller must generate a fresh request ID | None |
| Timeout/unknown outcome | Retry with original idempotency key and payload or query authoritative state | No blind new key |

### 4.4 Safety rules

- idempotency lookup occurs only after verified actor binding;
- request IDs remain traceable but are not deduplication authority;
- replay response echoes the current attempt's `requestId`; the committed
  domain outcome/resource identity/revision remains identical to the original,
  while correlation metadata may be attempt-specific;
- success is returned only after durable commit;
- retry cannot duplicate allocation, ledger, audit or outbox obligation;
- logs do not contain raw payload or personal data;
- retention must exceed the maximum supported retry/offline-result window;
- domain duplicate-active, revision and capacity invariants still apply when a
  caller deliberately uses a new idempotency key.

## 5. Compatibility and migration verdict

The chosen split-key rule is backward compatible with the committed Booking v1
wire format and fixtures:

- no schema field is added, removed or renamed;
- callers that currently send equal values remain valid;
- callers that send distinct values become explicitly valid;
- no fixture rewrite is required;
- future executable tests must add equal-value, distinct-value and retry-with-
  new-request-ID cases;
- no production data migration exists because runtime/persistence is absent.

This is not permission to edit schemas or generate backend consumers. Those
actions remain gated by an Approved executable slice and API-DEC decisions.

## 6. Governed decision dispositions

| Decision | Status after this package | Evidence / reason | Next gate |
|---|---|---|---|
| `D1-DEC-01` / `ECL03-D11` | **Accepted** | Product owner approved split-key reconciliation; matches committed Booking v1 wire/fixtures | Executable contract tests before mutation runtime |
| `OD-07` | **Proposed** | BCK-05 option A is reviewable; exact project edition/resource locations, residency, cost/export and specialist evidence are incomplete | Accepted before G1/R1 provisioning |
| `OD-09` | **Proposed** | BCK-03 defines an envelope and BCK-05 defines the operational boundary; delivery/retention/replay evidence is incomplete | Proposed is sufficient for D1 planning; Accepted before D3 effects/workers |
| `OD-10` | **Proposed, acceptance-ready only after evidence** | BCK-20 defines LocalizedText v1 and deterministic fallback; LV/EE/LT fixtures, Content/Mobile/Legal review and migration evidence are absent | Accepted before BCK-20/BCK-07 Approval and G1 |
| `OD-11` | **Open** | No authorized Legal/Privacy owner decision establishes minors/age policy | Accepted before production account creation and every applicable age-sensitive path |

No Proposed or Open item is promoted by implication.

## 7. BCK status verdict

| Spec | Status after reconciliation | What this package closes | What still blocks next status |
|---|---|---|---|
| BCK-01 | Review | D1 conflict/status traceability updated | Independent specialist Approval and complete D1 sign-off |
| BCK-03 | Draft | Booking split-key conflict closed | Delegated BCK-04/05/18 reviews and API-DEC evidence |
| BCK-04 | Draft | PRE-03 idempotency blocker closed | Legal/Privacy ownership, OD-07/11 and recorded security/privacy decisions |
| BCK-05 | Draft | API dependency now reconciled | Operations specialist, OD-07, SLO/budget/IAM/recovery evidence |
| BCK-20 | Draft | API dependency and OD-10 disposition clarified | OD-10 fixtures and Reference/API/Content/Mobile/Legal review |
| BCK-09 | Review | Target idempotency semantics now match Booking v1 fixtures | Physical implementation remains separately gated |

## 8. D1 exit assessment

D1 is **not complete**. The package closes one semantic blocker and creates a
single sign-off surface, but D1 exit still requires:

1. BCK-03/04/05/20 Review and then Approved evidence under their own DoR/DoD;
2. Accepted OD-07 and OD-10;
3. OD-09 and OD-11 at least at the BCK-02-required D1 status;
4. independent Security/Privacy, Legal, Operations, API, Mobile and affected
   domain acknowledgements rather than Product-owner substitution;
5. a final D1 conflict/sign-off report showing no unresolved double writer or
   incompatible contract.

Until then G1–G7, Firebase provisioning and backend runtime remain forbidden.

## 9. Verification contract

Documentation verification for this revision must prove:

- every equality rule is removed from normative Booking/BCK text;
- every effective key uses `idempotencyKey`, not `requestId`;
- existing Booking schema and fixtures are unchanged;
- local Markdown links resolve;
- AC sequences remain stable and sequential;
- boundary and diff checks pass;
- `apps/backend` remains absent.

Executable verification, only after a separately Approved slice, must include:

- equal request/key values accepted;
- distinct request/key values accepted;
- same logical key/hash with new request ID replays the committed semantic
  outcome in a current-attempt response envelope;
- same logical key with changed semantic payload conflicts;
- new logical key cannot bypass duplicate-active/capacity/revision rules;
- timeout-after-commit retry creates exactly one durable effect.

### 9.1 Documentation-revision evidence (2026-08-20)

- Booking contract package: **9/9 passed**;
- direct Dart analyzer for `apps/mobile/lib`, `test`, `integration_test`:
  **no issues**;
- boundary checker: **380 Dart files, 71 findings, 71 allowed, 0 violations,
  0 stale, 0 expired**;
- 16 changed Markdown files: local links and code fences pass;
- AC sequences pass: D1 1–20, BCK-03 1–64, BCK-04 1–45, BCK-05 1–50,
  BCK-20 1–50 and ECL-03 1–51;
- `git diff --check` passes and the tracked change scope is Markdown-only;
- full Flutter suite is **not green**: 663 tests passed and one existing Route
  golden comparison failed (`2.52%`, 11,229 pixels). The focused retry
  reproduced the same golden mismatch; no code, golden or asset belongs to this
  D1 change. The result is recorded as a repository gate blocker, not hidden or
  misreported as pass.

## 10. Acceptance criteria

1. **BCK-D1-AC-01:** `requestId` and `idempotencyKey` have distinct documented roles.
2. **BCK-D1-AC-02:** equality of the two values is permitted but never required.
3. **BCK-D1-AC-03:** effective deduplication includes resolved actor, command type and idempotency key.
4. **BCK-D1-AC-04:** request ID is excluded from semantic idempotency hash.
5. **BCK-D1-AC-05:** retry may use a new request ID only with the original logical key and payload.
6. **BCK-D1-AC-06:** same key/hash returns the committed semantic outcome in a current-attempt response envelope without mutation.
7. **BCK-D1-AC-07:** same key/different hash returns `idempotency_conflict`.
8. **BCK-D1-AC-08:** a new key never bypasses domain invariants.
9. **BCK-D1-AC-09:** committed Booking v1 wire and fixtures require no migration.
10. **BCK-D1-AC-10:** API-DEC-03 still gates canonical hash implementation.
11. **BCK-D1-AC-11:** OD-07 remains Proposed and blocks provisioning.
12. **BCK-D1-AC-12:** OD-09 remains Proposed and blocks effects/workers until Accepted.
13. **BCK-D1-AC-13:** OD-10 remains Proposed until fixture and owner evidence exists.
14. **BCK-D1-AC-14:** OD-11 remains Open and age-sensitive paths fail closed.
15. **BCK-D1-AC-15:** no Draft spec becomes Review or Approved by implication.
16. **BCK-D1-AC-16:** Product-owner coordination does not replace specialist approval.
17. **BCK-D1-AC-17:** D1 remains incomplete until all BCK-02 exit conditions pass.
18. **BCK-D1-AC-18:** no runtime/schema/Firebase artifact is authorized.
19. **BCK-D1-AC-19:** documentation and executable evidence are reported separately.
20. **BCK-D1-AC-20:** rollback is the previous documentation revision; no data rollback exists.

## 11. Rollback

Before runtime exists, rollback means reverting this documentation revision and
restoring the previous equality proposal. Such rollback would reopen the
known fixture contradiction and therefore requires an explicit new owner
decision; it must not be performed silently.

## 12. Final statement

`D1-DEC-01` is Accepted and closes the Booking v1 key-semantics contradiction.
The backend platform is still documentation-only. D1 exit, G1, physical
Firebase, deployments and production data processing remain blocked by the
statuses and evidence listed above.
