# BCK05-OD-07 — Owner Decision Record

- ID: **BCK05-OD07-DEC-01**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Accepted — BCK05-REL-A1-DUAL-PROV-v1 with controls**
- Decision owner: **RechargeN / Product owner**
- Security reviewers: **Release Operations and Platform Security**
- Candidate: **BCK05-REL-A1-DUAL-PROV-v1**
- Evidence: [BCK05-OD07-REL-01 v0.2.1](BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md)
- Parent: [BCK-05 v0.2.23](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Accountable verdict: **Release Operations + Platform Security**
- Assigned bootstrap owner: **RechargeN / Product owner acting as combined Platform coordinator**
- Independent production review: **not supplied**
- Runtime effect: **none**

---

## 0. Recorded owner verdict

The Product owner supplied the exact effective phrase:

```text
Одобряю BCK05-OD07-DEC-01: Accept BCK05-REL-A1-DUAL-PROV-v1 with controls.
```

| Field | Recorded value |
|---|---|
| Decision | **Accept BCK05-REL-A1-DUAL-PROV-v1 with controls** |
| Owner identity / actual role | `RechargeN / Product owner acting as combined Platform coordinator` |
| Release/Security scope | Accepted under the disclosed combined-role bootstrap model; independent production review is not claimed |
| Accepted baseline | BCK05-OD07-REL-01 v0.2.1 and every retained control in this record |
| Deferred unchanged | executable schemas/workflows/policies, GitHub settings, WIF/cloud resources, D1/G1/R0/R1 and production |
| Runtime authority | none |
| Signature evidence | exact owner reply in the controlling Codex task |
| Signed UTC | `2026-08-25T12:36:58Z` |

This transition records architecture-and-controls Acceptance only. It creates
no release, attestation, repository/cloud mutation, deployment, production
processing or `main` merge authority.

## 1. Decision requested

Accept `BCK05-REL-A1-DUAL-PROV-v1` as the architecture-and-controls baseline
for backend release identity, provenance, environment promotion, provider
deployment receipts, last-known-healthy tracking, rollback and quarantine.

The candidate establishes:

- one environment-neutral, content-addressed release manifest;
- a separately hashed deployment plan for each environment;
- post-deploy provider receipts rather than predicted provider outputs;
- append-only promotion records and a guarded healthy pointer;
- GitHub keyless attestations for caller-controlled assets plus separate
  provider-build evidence for Firebase/Cloud Functions;
- immutable GitHub release assets as canonical caller storage and exact-byte
  environment-local Artifact Registry mirrors;
- Functions v2/Rules/index/config as the initial R1 inventory, with direct OCI
  and Binary Authorization deferred to an amendment;
- fail-closed approvals, verification, reconciliation, rollback and quarantine.

## 2. Controls retained after Acceptance

Acceptance does **not** authorize implementation. All of these remain blocked
until their own Approved executable or infrastructure slice and evidence gate:

1. editing or enabling a GitHub release/deploy workflow;
2. changing branch protection, Actions policy, environments or immutable-release
   repository settings;
3. granting `id-token`, `attestations`, release-publisher or deploy permissions;
4. creating a GitHub release, attestation, Artifact Registry repository/mirror,
   WIF/IAM binding, cloud resource, Binary Authorization policy or secret;
5. deploying Firebase/Google Cloud resources or processing production data;
6. enabling repository-wide SHA enforcement before mobile Action references are
   migrated and verified;
7. treating ordinary Actions artifacts as durable rollback authority;
8. claiming provider provenance, SLSA level or Binary Authorization without
   direct evidence from the selected component/deployment mode;
9. production promotion before G5/G6, BCK dependencies, security thresholds,
   recovery rehearsal and separation-of-persons evidence pass;
10. merging this branch into `main` without a separate repository-owner action.

`Selected, unproved` remains evidence debt, not a Pass. An unsupported or
unavailable mandatory control fails closed.

## 3. Exact decision phrase — recorded

The exact controlling-task evidence is preserved in §0. It matches the
candidate and all controls without qualification.

## 4. Effect of the recorded signature

After repository documents are reconciled:

- this record is `Accepted with controls`;
- BCK05-OD-07 is `Accepted with controls` at candidate
  `BCK05-REL-A1-DUAL-PROV-v1`;
- R0 release tooling may be planned, but may start only through a separately
  Approved, bounded, non-production executable slice;
- every runtime/cloud/production boundary in section 2 remains unchanged.

Any change to digest semantics, canonical storage, attestation identity,
environment separation, initial component inventory, approval separation or
healthy-pointer rules requires a new decision revision or superseding record.

## 5. Acceptance criteria

1. **BCK05-OD07-DEC-AC-01:** candidate ID is exact and unambiguous.
2. **BCK05-OD07-DEC-AC-02:** evidence document/version is pinned.
3. **BCK05-OD07-DEC-AC-03:** decision phrase is exact and single-purpose.
4. **BCK05-OD07-DEC-AC-04:** unsigned status cannot imply Acceptance.
5. **BCK05-OD07-DEC-AC-05:** Acceptance selects architecture and controls only.
6. **BCK05-OD07-DEC-AC-06:** manifest and environment plan remain separate.
7. **BCK05-OD07-DEC-AC-07:** provider outputs remain post-deploy evidence.
8. **BCK05-OD07-DEC-AC-08:** caller and provider provenance remain distinct.
9. **BCK05-OD07-DEC-AC-09:** immutable asset digests remain release authority.
10. **BCK05-OD07-DEC-AC-10:** mutable workflow artifacts are not rollback authority.
11. **BCK05-OD07-DEC-AC-11:** initial R1 component boundary is explicit.
12. **BCK05-OD07-DEC-AC-12:** direct OCI/Binary Authorization needs an amendment.
13. **BCK05-OD07-DEC-AC-13:** GitHub settings require separate authorization.
14. **BCK05-OD07-DEC-AC-14:** cloud/IAM/resources require separate authorization.
15. **BCK05-OD07-DEC-AC-15:** deploy/production processing remains blocked.
16. **BCK05-OD07-DEC-AC-16:** unproved evidence remains fail-closed debt.
17. **BCK05-OD07-DEC-AC-17:** production requires separation-of-persons evidence.
18. **BCK05-OD07-DEC-AC-18:** executable R0 needs its own Approved slice.
19. **BCK05-OD07-DEC-AC-19:** this record does not authorize a `main` merge.
20. **BCK05-OD07-DEC-AC-20:** material semantic change requires a new decision.
