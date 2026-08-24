# BCK-R0-TCH-01 — Execution Result

- Slice: **BCK-R0-TCH-01 v0.2**
- Decision: **BCK-R0-TCH-DEC-01 v0.1 — Approved bounded execution**
- Execution date: **2026-08-24**
- Status: **Local and hosted execution complete; Amendments Required before R0 Pass**
- Product/cloud runtime: **Absent**
- Base commit: `a6b04cbb079c330dd9ddc23d17ac42f9d31669e5`
- Branch: `codex/backend-r0-toolchain`
- Execution hosts: Windows x64 worktree plus GitHub-hosted `ubuntu-24.04` and
  `windows-2025`; machine-specific paths omitted
- Rollback owner: `RechargeN / Product owner`

## 1. Approval evidence

The Product owner replied `одобряю` directly to the exact bounded R0 v0.2
approval request. BCK-R0-TCH-DEC-01 records the four combined-role bootstrap
verdicts at `2026-08-23T23:43:37Z`. Independent production security/legal
review is not claimed.

## 2. Entry absence evidence

Before scaffold creation:

- sensitive cloud-context environment names present: 0;
- repository `.firebaserc`: absent;
- root `firebase.json`: absent;
- `apps/backend`: absent;
- backend R0 workflow: absent;
- cloud login, project creation, API enablement, billing, deployment and
  Terraform mutation commands executed: 0.

## 3. Pre-existing dirty paths

The following 37 documentation paths existed before physical R0 work and must
not be overwritten, discarded or silently included as generated backend work:

```text
M docs/architecture/LAUNCH_STATUS.md
M docs/product/BACKEND_API_CONTRACT_STANDARD.md
M docs/product/BACKEND_DEPLOYMENT_OPERATIONS_COVERAGE_MATRIX.md
M docs/product/BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md
M docs/product/BACKEND_MASTER_RECONCILIATION_REPORT.md
M docs/product/BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md
M docs/product/BACKEND_SECURITY_PRIVACY_SPEC.md
M docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md
M docs/product/EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md
M docs/product/EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md
M docs/product/EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md
M docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md
M docs/product/RECHARGE_BACKEND_MASTER_SPEC.md
M docs/product/REFERENCE_DATA_LOCALIZATION_COVERAGE_MATRIX.md
M docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md
?? docs/product/BACKEND_BACKUP_RECOVERY_MODEL.md
?? docs/product/BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md
?? docs/product/BACKEND_INFRASTRUCTURE_COST_MODEL.md
?? docs/product/BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md
?? docs/product/BACKEND_OD_09_EVENT_DELIVERY_EVIDENCE.md
?? docs/product/BACKEND_OD_10_LOCALIZATION_EVIDENCE.md
?? docs/product/BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md
?? docs/product/BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md
?? docs/product/BACKEND_PLATFORM_D1_COMBINED_OWNER_REVIEW_WORKBOOK.md
?? docs/product/BACKEND_PLATFORM_D1_DECISION_PACKAGE.md
?? docs/product/BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md
?? docs/product/BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md
?? docs/product/BACKEND_R0_APPROVAL_DECISION_RECORD.md
?? docs/product/BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md
?? docs/product/BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md
?? docs/product/BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md
?? docs/product/BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md
?? docs/product/BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md
?? docs/product/BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md
?? docs/product/BACKEND_SECURITY_INCIDENT_TABLETOP_RUN_001.md
?? docs/product/BACKEND_SECURITY_THREAT_MODEL.md
?? docs/product/BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md
```

## 4. Source revalidation

At execution entry on 2026-08-24:

| Input | Expected | Observed | Result |
|---|---|---|---|
| `actions/checkout` | v7.0.1 / `3d3c42e…` | unchanged | Pass |
| `actions/setup-node` | v7.0.0 / `82076278…` | unchanged | Pass |
| `actions/setup-java` | v5.7.0 / `b6effb05…` | unchanged | Pass |
| Terraform | stable 1.15.9 | unchanged | Pass |

The workflow executes only full 40-character SHAs; shortened values above are
display-only evidence labels.

## 5. Host tool observation

The pre-existing Windows host does not satisfy the exact R0 toolchain:

| Tool | Required | Observed at entry | Verdict |
|---|---:|---:|---|
| Node.js | 22.23.2 | 20.17.0; bundled Codex runtime 24.19.0 | Inconclusive for R0 |
| npm | 10.9.8 | 10.8.2 | Inconclusive for R0 |
| Java | Temurin 21.0.12+8 | Oracle Java 17.0.1 | Inconclusive for R0 |
| Terraform | 1.15.9 | absent | Inconclusive for R0 |
| GPG | signature verification required | absent | Inconclusive for R0 |

No observed substitute was counted as Pass. Exact portable tools were then
downloaded to disposable locations and verified independently:

| Tool | Exact local evidence | Verdict |
|---|---|---|
| Node.js/npm | 22.23.2 / 10.9.8; Node archive SHA-256 `1177b4137ba5adaa56354ae40f1080c7450e8ae09cecb47da459d1c52ac99f97` matched the publisher manifest | Pass |
| Eclipse Temurin | 21.0.12+8; Windows archive SHA-256 `9ba963ee2371874a74185d18bc7bb2ab9407df7683300855ed7606e0662321d0` matched publisher metadata | Pass |
| Terraform | 1.15.9; signed checksum manifest verified against primary fingerprint `C874011F0AB405110D02105534365D9472D7468F`; archive SHA-256 `b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6` matched | Pass |
| Google provider | 7.43.0, Windows/Linux checksums added by `terraform providers lock`; provider signature reported as HashiCorp-signed | Pass |

The repository composite toolchain script could not spawn version subprocesses
inside the local coding sandbox and therefore remains locally Inconclusive as
one combined gate. The exact binaries were each invoked and verified directly;
the combined gate then passed on both hosted CI legs.

## 6. Execution results

| Evidence | Status | Command/result |
|---|---|---|
| exact package lock | Pass | generated by Node 22.23.2/npm 10.9.8; `npm ci --ignore-scripts` and `npm ls --all` exited 0 |
| lifecycle inventory | Pass | only `@firebase/util@1.15.3:postinstall`, `protobufjs@7.6.5:postinstall` and `re2@1.26.1:install`; all remained disabled and the complete local matrix passed without them |
| license inventory | Pass | installed manifests contain only reviewed permissive license identifiers; four missing manifest fields have packaged license files |
| format/lint/typecheck | Pass | Prettier check, ESLint and strict TypeScript `--noEmit` exited 0 |
| unit tests | Pass | 2/2 probe tests |
| Booking fixture parity | Pass | 2/2 canonical schema/fixture tests; source contracts unchanged |
| emulator isolation | Pass | 3/3: loopback/demo identity, no credential variables and live emulator-only Functions probe |
| default-deny Rules | Pass | 4/4: anonymous, own-scope, cross-user/page and unknown-path reads/writes denied through client REST paths |
| emulator child cleanup | Pass | no configured emulator port remained listening after the final Windows run |
| Terraform lock/fmt/init/validate | Pass | exact CLI/provider, signed checksums, backendless read-only lock init and valid empty provider skeleton |
| two-build reproducibility | Pass locally | logical digest `628112d2b89584ec57fc33b83917f38a04d8579a8fe4b23c9db8ccefd20580aa` |
| Windows/Linux hosted CI parity | Pass | draft PR [#7](https://github.com/RechargeN/Recharge/pull/7), run [32684234236](https://github.com/RechargeN/Recharge/actions/runs/32684234236): Ubuntu job `97306221865` and Windows job `97306221917` completed successfully; all mandatory steps passed |
| repository boundary gate | Pass | checker v1.0.0: 380 Dart files, 71 existing suppressions, 0 violations, 0 stale/expired exceptions |

## 7. Dependency advisory evidence

Direct pins were rechecked after installation and remain the latest published
`firebase-admin` 14.3.0, `firebase-functions` 7.3.2 and `firebase-tools`
15.28.1 versions. No peer/engine override or lifecycle script was enabled.

The dated npm advisory checks found:

- production graph: 7 Moderate, 0 High, 0 Critical;
- complete graph: 10 Moderate, 0 High, 0 Critical;
- `GHSA-w5hq-g745-h8pq` through upstream `uuid` paths;
- `GHSA-8988-4f7v-96qf` through the development-only Firebase CLI Pub/Sub path;
- npm offers only forced, breaking direct-package downgrades; none was applied.

The High/Critical CI threshold passes, but BCK05-OD01 §3 also says a vulnerable
pin blocks R0 until amendment. Because that wording has not been weakened or
silently reinterpreted, the overall R0 verdict is **Amendments Required** until
an explicit dated Moderate-risk disposition is approved or clean upstream
releases replace these paths.

## 8. Cloud effect ledger

| Effect | Count |
|---|---:|
| real Firebase/Google projects selected or created | 0 |
| APIs enabled | 0 |
| billing links changed | 0 |
| credentials, service accounts, keys or WIF created | 0 |
| Firebase deployments | 0 |
| Terraform plan/apply/import/destroy | 0 |
| personal or production-derived records processed | 0 |

## 9. Current verdict

**Local and hosted implementation evidence is complete and technically
operational, but R0 is not Pass.** Windows/Linux parity is Pass; the remaining
blocker is the unresolved Moderate advisory disposition under the stricter
BCK05-OD01 wording.

Scaffold presence and local/hosted green tests are not production backend readiness.
BCK05-OD-01 remains Proposed; R1/G1 and all cloud/product backend activation
remain blocked.
