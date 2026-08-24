# Recharge Backend — Runtime & Toolchain Owner Decision

- ID: **BCK05-OD01-DEC-01**
- Version: **0.1**
- Date: **2026-08-24**
- Status: **Review — explicit owner verdict required**
- Decision target: **BCK05-OD-01**
- Reviewed standard: [BCK05-OD01-TCH-01 v0.3.3](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md)
- Technical review: [BCK05-OD01-TCH-REV-01 v0.2.3](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md)
- R0 slice: [BCK-R0-TCH-01 v0.2.2](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md)
- R0 decision: [BCK-R0-TCH-DEC-01 v0.2](BACKEND_R0_APPROVAL_DECISION_RECORD.md)
- Execution evidence: [BCK-R0-TCH-01 result](../evidence/backend/r0/BCK-R0-TCH-01_RESULT.md)
- Parent: [BCK-05 v0.2.16](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) (Draft)
- Accountable verdict: **Platform Operations + Platform Security**
- Assigned bootstrap owner: **RechargeN / Product owner acting as combined Platform coordinator**
- Runtime effect: **none**

---

## 1. Purpose

This record asks for one narrow owner decision: whether the exact, executed
runtime/toolchain baseline may move from `Proposed` to `Accepted` as
`BCK05-OD-01`.

Acceptance selects a reproducible engineering baseline. It does not approve
BCK-05, pass G1, authorize R1, provision Firebase/GCP, create credentials,
enable billing, deploy code, process personal data or activate a product flow.

## 2. Evidence now available

The decision is no longer based only on a paper candidate:

- exact Node/npm/TypeScript/Firebase/JDK/Terraform pins are recorded;
- package peers and engines resolve without force or compatibility bypasses;
- format, lint, typecheck, unit and Booking contract tests pass;
- demo-only Auth, Functions, Firestore, Storage and Pub/Sub emulators pass;
- default-deny client Rules tests pass;
- Terraform signature/checksum, lock, format, backendless init and validation
  pass without credentials;
- logical build reproducibility passes;
- hosted `ubuntu-24.04` and `windows-2025` parity passes;
- repository boundaries, codegen, lint and mobile tests pass on the current
  draft-PR head;
- R0 has zero cloud project, billing, credential, deployment, Terraform
  mutation, personal-data or production-data effects.

## 3. Exact decision scope

### 3.1 Accepted baseline if approved

| Component | Exact baseline |
|---|---|
| Provider runtime family | Cloud Functions for Firebase 2nd gen, `nodejs22` |
| Local/build runtime | Node.js `22.23.2` |
| Package manager | npm `10.9.8`; committed lockfile; `npm ci --ignore-scripts` first |
| Language/compiler | TypeScript `6.0.3`, strict ESM/`NodeNext` |
| Firebase SDK | `firebase-functions` `7.3.2`; `firebase-admin` `14.3.0` |
| Firebase CLI | project-local `firebase-tools` `15.28.1` |
| Test/lint/format | built-in `node:test`; ESLint `9.39.5`; `typescript-eslint` `8.67.0`; Prettier `3.9.6` |
| Emulator JDK | Eclipse Temurin `21.0.12+8`, verified platform artifact |
| IaC | Terraform `1.15.9`; `hashicorp/google` `7.43.0`; `google-beta` absent by default |
| CI authority | only the three reviewed full-SHA Actions; explicit `ubuntu-24.04` and `windows-2025` labels |

Provider-managed cloud patch versions are not falsely equated with the exact
local Node patch. A future R1 must record the actual deployed runtime revision.

### 3.2 Decision disposition

| Internal decision | Proposed owner disposition | Boundary |
|---|---|---|
| `TCH-OD-01` | Accept Temurin baseline | emulator use only |
| `TCH-OD-02` | Accept exact package matrix | revalidate on lock/direct-pin change |
| `TCH-OD-03` | Accept Linux CI authority plus Windows parity | resolved image remains evidence, not immutable infrastructure |
| `TCH-OD-04` | Accept disabled lifecycle scripts | any allowlist requires a new reviewed decision |
| `TCH-OD-05` | Accept formatter/linter/built-in test runner | no alternate hidden gate |
| `TCH-OD-06` | Defer correctly to OD-07 and an Approved R1 | no remote Terraform state now |
| `TCH-OD-07` | Defer; default `google-beta` absent | exception requires evidence and review |
| `TCH-OD-08` | Defer to BCK05-OD07-REL-01 | no unselected attestor/SBOM tool |

Accepting the first five items does not silently accept the three deferred
items.

## 4. Residual advisory contract

`BCK-R0-TCH-ADV-01` accepts the residual risk from two root Moderate advisories
only for bounded R0 through `2026-09-24`, or until immediately before R1/G1 or
real cloud/public-ingress work, whichever comes first.

Therefore BCK05-OD-01 Acceptance does **not** carry that R0 exception into R1.
Before an executable R1 can use the dependency graph, Platform Operations and
Platform Security must perform a fresh production and complete audit,
reachable-path review and supported-remediation check. High/Critical findings,
an unsupported/EOL component, a changed graph without review or a reachable
uncontrolled Moderate path fail closed.

Forced direct-package downgrades, peer/engine bypasses and unsupported
transitive major overrides are not approved remediation.

## 5. Preserved gates

Regardless of verdict, this record does not authorize:

- merge to `main`;
- G1 or any R1 command;
- Firebase/GCP project creation or selection;
- billing, IAM, WIF, service accounts, keys, secrets or credentials;
- Terraform backend/plan/apply/import/destroy;
- Firebase deploy or a public/non-loopback listener;
- product handlers, domain persistence or mobile adapters;
- production Auth, Booking, Event, notification, media or payment behavior;
- personal or production-derived data.

OD-07, OD-10 and the complete D1 platform set remain separate blockers before
G1. R1 additionally requires its own exact file/command map, rollback, evidence
plan and explicit post-stabilization authorization.

## 6. Owner verdict

Allowed verdicts:

| Verdict | Result |
|---|---|
| `Accept BCK05-OD-01 v0.3.3 with controls` | accepts only §3 and §4; deferred items and every §5 gate remain binding |
| `Accept with amendments` | remains Proposed until every named amendment is incorporated and re-reviewed |
| `Reject` | remains Proposed; owner records replacement direction |
| `Inconclusive` | remains Proposed; missing authority/evidence is named |

Recommended verdict: **Accept BCK05-OD-01 v0.3.3 with controls**.

The effective approval phrase is:

```text
Одобряю BCK05-OD01-DEC-01: Accept BCK05-OD-01 v0.3.3 with controls.
```

Generic continuation, approval of R0, approval of
`BCK-R0-TCH-ADV-01`, silence or document presence is not this decision.

## 7. Status transition after explicit acceptance

Only after the exact owner verdict is recorded:

| Item | Resulting status |
|---|---|
| `BCK05-OD-01` | Accepted at the exact v0.3.3 baseline |
| `TCH-OD-01..05` | Accepted as bounded in §3.2 |
| `TCH-OD-06..08` | Deferred/Open with fail-closed defaults |
| R0 | Pass — bounded tooling feasibility only |
| BCK-05 | Draft; other review blockers unchanged |
| BCK-01 / BCK-03 / BCK-04 / BCK-20 | unchanged |
| G1 / R1 | blocked and unauthorized |
| product/cloud runtime | Absent |

Acceptance permits preparation of a documentation-only R1 candidate plan. It
does not permit execution of that plan.

## 8. Revalidation and supersession

The accepted baseline must be re-reviewed before use when any of these occurs:

1. a direct pin, lockfile, runtime family, JDK, IaC provider or CI Action changes;
2. upstream support/security status changes materially;
3. R1/G1 or any public/cloud execution is proposed;
4. a lifecycle script, beta provider or new external Action becomes necessary;
5. the R0 advisory disposition expires or is revoked;
6. Windows/Linux semantic parity no longer passes.

A replacement records old/new versions, compatibility and migration evidence,
security disposition, rollback and effective date. It never rewrites this
decision silently.

## 9. Acceptance criteria

1. **BCK05-OD01-DEC-AC-01:** one exact toolchain standard is the decision target.
2. **BCK05-OD01-DEC-AC-02:** R0 execution evidence is linked.
3. **BCK05-OD01-DEC-AC-03:** exact runtime, package, JDK and IaC pins are named.
4. **BCK05-OD01-DEC-AC-04:** provider patch and local patch are distinguished.
5. **BCK05-OD01-DEC-AC-05:** TCH-OD-01..05 have explicit dispositions.
6. **BCK05-OD01-DEC-AC-06:** TCH-OD-06..08 remain explicitly deferred.
7. **BCK05-OD01-DEC-AC-07:** the R0 advisory exception does not propagate to R1.
8. **BCK05-OD01-DEC-AC-08:** R1 requires a fresh audit and reachability review.
9. **BCK05-OD01-DEC-AC-09:** unsafe dependency remediation is forbidden.
10. **BCK05-OD01-DEC-AC-10:** combined-role and independent-review limits are visible.
11. **BCK05-OD01-DEC-AC-11:** document presence and generic continuation are not Acceptance.
12. **BCK05-OD01-DEC-AC-12:** only the exact owner phrase changes OD-01 status.
13. **BCK05-OD01-DEC-AC-13:** Acceptance does not approve BCK-05 or G1.
14. **BCK05-OD01-DEC-AC-14:** Acceptance does not authorize R1 or cloud effects.
15. **BCK05-OD01-DEC-AC-15:** OD-07/OD-10/D1 blockers remain independent.
16. **BCK05-OD01-DEC-AC-16:** R1 requires a separate exact Approved slice.
17. **BCK05-OD01-DEC-AC-17:** revalidation triggers fail closed.
18. **BCK05-OD01-DEC-AC-18:** supersession is versioned and evidence-backed.
19. **BCK05-OD01-DEC-AC-19:** product/cloud runtime remains Absent.
20. **BCK05-OD01-DEC-AC-20:** merge to `main` is outside this decision.

---

**Current conclusion:** the evidence supports the recommended bounded
Acceptance, but `BCK05-OD-01` remains **Proposed** until the exact owner verdict
in §6 is explicitly given and recorded. G1/R1 and product/cloud runtime remain
blocked.
