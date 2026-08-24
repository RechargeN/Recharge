# Recharge Backend — IAM & Workload Identity Owner Decision

- ID: **BCK05-OD02-DEC-01**
- Version: **0.2**
- Date: **2026-08-24**
- Status: **Accepted — BCK05-IAM-A1-ENV-WIF-v1 with controls**
- Decision target: **BCK05-OD-02**
- Candidate baseline: **BCK05-IAM-A1-ENV-WIF-v1**
- Evidence: [BCK05-OD02-IAM-01 v0.2](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md)
- Infrastructure dependency: [OD07-DEC-01 v0.2](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md) (Accepted)
- Parent: [BCK-05 v0.2.21](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) (Draft)
- Accountable verdict: **Platform Security + Platform Operations**
- Assigned bootstrap owner: **RechargeN / Product owner acting as combined Platform coordinator**
- Independent production review: **not supplied**
- Runtime effect: **none**

---

## 0. Recorded owner verdict

The Product owner supplied the exact effective phrase:

```text
Одобряю BCK05-OD02-DEC-01: Accept BCK05-IAM-A1-ENV-WIF-v1 with controls.
```

| Field | Recorded value |
|---|---|
| Decision | **Accept BCK05-IAM-A1-ENV-WIF-v1 with controls** |
| Owner identity / actual role | `RechargeN / Product owner acting as combined Platform coordinator` |
| Operations/Security scope | Accepted under the disclosed combined-role bootstrap model; independent production review is not claimed |
| Accepted baseline | BCK05-OD02-IAM-01 v0.2 and all §4 controls |
| Deferred unchanged | executable claim fixtures, permission manifests, bindings, JIT/roster, BCK-05, D1/G1 and R1 |
| Runtime authority | none |
| Signature evidence | exact owner reply in the controlling Codex task |
| Signed UTC | `2026-08-24T19:53:07Z` |

## 1. Purpose

This record asks one narrow question: may Recharge accept
`BCK05-IAM-A1-ENV-WIF-v1` as the keyless IAM/workload-identity architecture
policy?

Acceptance does not configure GitHub, create a Google Cloud project, enable an
API, create WIF/IAM/Secret Manager resources, grant a permission, attach
billing, deploy code, process data, pass D1/G1 or authorize R1.

## 2. Exact baseline under review

| Concern | Selected value |
|---|---|
| Project topology | Accepted OD-07 dev/stage/prod only; no fourth control project |
| WIF topology | one environment-local `global` pool/provider per project |
| Deployment identity | one task- and environment-specific service account; same project as target resources |
| Cloud credentials | GitHub OIDC → WIF → short-lived service-account impersonation; no stored service-account key |
| GitHub repository ID | `1213588766` |
| GitHub owner ID | `277012929` |
| GitHub repository | `RechargeN/Recharge`, currently public |
| OIDC subject | opt in to immutable owner/repository IDs before any cloud-bearing job |
| Trusted workflow | future `.github/workflows/backend-deploy.yml@refs/heads/main` only |
| Environments | future `backend-dev`, `backend-stage`, `backend-prod`; currently absent |
| Source protection | protected `main` mandatory; currently absent |
| Production approvals | signed change/release approval plus distinct GitHub environment approval; no self/admin bypass |
| Permission model | exact expanded per-identity manifest before each binding; no basic roles or blanket impersonation |
| Service-account keys | creation/upload forbidden; no routine exception |
| Break-glass | JIT/PAM-equivalent, purpose/incident/TTL/audit scoped; no static-key fallback |
| Secret placement | global Secret Manager resource with user-managed replica only in `europe-west1` |
| Runtime secret binding | disabled until exact Functions v2/Cloud Run compatibility evidence |

## 3. Why this option

Environment-local WIF preserves OD-07's three-project topology and keeps each
deployment service account beside its target resources. It avoids a new shared
cross-project authority while retaining strict provider/identity separation.

Numeric GitHub IDs and immutable subjects prevent repository/owner rename or
name-reuse from becoming cloud authority. Exact workflow, ref, environment,
event, issuer and audience constraints prevent a repository-wide trust grant.

For secrets, Cloud Run does not support regional Secret Manager resources.
Using the global resource model with user-managed `europe-west1` replication
keeps secret payload versions in the selected OD-07 region while preserving a
supported Functions/Cloud Run integration candidate. Global control-plane
behavior remains disclosed.

## 4. Mandatory controls

Acceptance includes all of these controls:

1. no cloud token in pull-request/fork jobs;
2. no `id-token: write` outside the exact future authentication job;
3. immutable GitHub subject enabled and negatively tested before WIF binding;
4. numeric repository/owner IDs, workflow/ref/environment/event/issuer/audience
   all constrained;
5. separate dev/stage/prod providers, service accounts, permissions and state;
6. no environment identity can edit its provider, own IAM policy or source;
7. no service-account key creation/upload or stored deploy credential;
8. no `Owner`, `Editor`, broad `Viewer` or project-wide impersonation shortcut;
9. exact expanded permission manifest and privilege-escalation review before
   every binding;
10. protected `main`, configured environments and approval/bypass evidence
    before any cloud workflow;
11. two distinct production approvals; current single-owner capacity cannot
    satisfy production separation of duty;
12. JIT/PAM-equivalent tool and qualified roster before break-glass/production;
13. global Secret Manager uses only user-managed `europe-west1` replication;
14. no runtime secret until binding/version/rotation/audit/revocation proof;
15. revalidation/supersession triggers fail closed.

## 5. Explicitly preserved gates

This decision does not authorize:

- merge to `main`;
- branch-protection, environment or OIDC-setting mutation in GitHub;
- Firebase/GCP organization, folder or project creation;
- billing, API enablement or chargeable resource;
- workload identity pool/provider or IAM/service-account creation;
- role/binding, impersonation, key, secret or credential;
- Terraform plan/apply/import/destroy or Firebase deploy;
- dev/stage/prod traffic, production data or market activation;
- D1/G1 completion or an executable R1 slice.

BCK05-OD-03/04/05/07/08, BCK-04, OD-09/10/11, qualified Legal/Privacy,
release provenance, cost/recovery and runtime evidence remain independent.

## 6. Known current blockers after architecture Acceptance

| Blocker | Required exit evidence |
|---|---|
| `main` unprotected | read-back of exact protection and required checks |
| no GitHub environments | exact dev/stage/prod environment protection export |
| mutable default OIDC subject | immutable opt-in plus sanitized claim/negative fixtures |
| no cloud projects | Accepted G1 and exact Approved R1 project/bootstrap plan |
| no exact role bindings | expanded permissions, resource scope and simulation per identity |
| unknown organization policy availability | effective key/default-SA policy read-back at project/parent |
| no two-person roster/JIT tool | named qualified roster and rehearsed PAM-equivalent evidence |
| secret integration unproved | non-production Functions v2/Cloud Run binding and rotation proof |

These are executable/production blockers. They do not become fictional proof
and are not bypassed by accepting the fail-closed architecture policy.

## 7. Owner-verdict contract

Allowed verdicts:

| Verdict | Result |
|---|---|
| `Accept BCK05-IAM-A1-ENV-WIF-v1 with controls` | BCK05-OD-02 becomes Accepted only as §§2–6 define; no runtime permission |
| `Accept with amendments` | remains Proposed until amendments are incorporated and re-reviewed |
| `Reject` | remains Proposed; replacement direction is recorded |
| `Inconclusive` | remains Proposed; missing evidence/authority is named |

Recorded verdict: **Accept BCK05-IAM-A1-ENV-WIF-v1 with controls**.

The only effective approval phrase is:

```text
Одобряю BCK05-OD02-DEC-01: Accept BCK05-IAM-A1-ENV-WIF-v1 with controls.
```

The exact phrase above has now been supplied. Generic “да”, “дальше”, approval
of documentation work, silence or file presence remains ineffective for any
future amendment, supersession or executable slice.

## 8. Status after exact acceptance

| Item | Resulting state |
|---|---|
| BCK05-OD-02 | Accepted at `BCK05-IAM-A1-ENV-WIF-v1` with §4 controls |
| BCK-05 | Draft; unchanged |
| BCK-04 / qualified production review | Draft / still required |
| D1 / G1 | blocked or unchanged |
| R1 | blocked until separate exact Approval |
| GitHub cloud-bearing configuration | Absent |
| Firebase/GCP IAM/secrets/runtime | Absent |
| product/cloud backend | Absent |
| `main` | untouched |

## 9. Revalidation and supersession

Re-review is mandatory if GitHub IDs, visibility, owner, OIDC claim behavior,
workflow/ref/environment model, Google WIF semantics, service-account
impersonation, Secret Manager/Cloud Run compatibility, OD-07 topology,
permission needs or production separation of duty changes.

A superseding record names old/new trust, claims, permissions, migration,
revocation, rollback, owner and effective date. Existing configuration never
redefines the decision merely because it exists.

## 10. Acceptance criteria

1. **BCK05-OD02-DEC-AC-01:** one exact IAM baseline is the target.
2. **BCK05-OD02-DEC-AC-02:** OD-07 topology is not silently expanded.
3. **BCK05-OD02-DEC-AC-03:** current GitHub immutable IDs are recorded.
4. **BCK05-OD02-DEC-AC-04:** current missing protections are disclosed.
5. **BCK05-OD02-DEC-AC-05:** OIDC/WIF is keyless and short-lived.
6. **BCK05-OD02-DEC-AC-06:** trust is environment and workflow specific.
7. **BCK05-OD02-DEC-AC-07:** exact permissions precede each binding.
8. **BCK05-OD02-DEC-AC-08:** identity cannot modify its own authority.
9. **BCK05-OD02-DEC-AC-09:** production approval limitations are explicit.
10. **BCK05-OD02-DEC-AC-10:** absent two-person/JIT evidence fails closed.
11. **BCK05-OD02-DEC-AC-11:** secret placement is compatible and bounded.
12. **BCK05-OD02-DEC-AC-12:** global service behavior is not hidden.
13. **BCK05-OD02-DEC-AC-13:** architecture Acceptance is not executable evidence.
14. **BCK05-OD02-DEC-AC-14:** only the exact phrase changes decision status.
15. **BCK05-OD02-DEC-AC-15:** Acceptance does not approve BCK-05 or G1.
16. **BCK05-OD02-DEC-AC-16:** Acceptance does not authorize R1/cloud effects.
17. **BCK05-OD02-DEC-AC-17:** every revalidation trigger fails closed.
18. **BCK05-OD02-DEC-AC-18:** supersession is versioned and revocation-aware.
19. **BCK05-OD02-DEC-AC-19:** product/cloud runtime remains Absent.
20. **BCK05-OD02-DEC-AC-20:** merge to `main` is outside this decision.

---

**Current conclusion:** BCK05-OD-02 is **Accepted** at
`BCK05-IAM-A1-ENV-WIF-v1` with all §4 controls. This is architecture-policy
Acceptance only: every GitHub/GCP mutation, executable IAM/secret action,
cloud runtime, R1 authorization and `main` merge remains blocked.
