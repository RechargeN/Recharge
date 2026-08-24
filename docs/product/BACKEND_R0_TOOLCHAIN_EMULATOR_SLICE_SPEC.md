# Recharge Backend — R0 Toolchain & Emulator Feasibility Slice

- Slice ID: **BCK-R0-TCH-01**
- Version: **0.2**
- Date: **2026-08-24**
- Status: **Approved and implemented locally — Amendments Required before Pass**
- Runtime status: **R0 tooling scaffold Present locally; product/cloud runtime Absent**
- Parent operations spec: [BCK-05 v0.2.13](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Toolchain standard: [BCK05-OD01-TCH-01 v0.3.1](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md)
- Technical pre-review: [BCK05-OD01-TCH-REV-01 v0.2.1](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md)
- Approval record: [BCK-R0-TCH-DEC-01 v0.1](BACKEND_R0_APPROVAL_DECISION_RECORD.md)
- Architecture authority: [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md)
- Accountable owner: **Platform Operations owner**
- Required reviewers: **Platform Security owner, Architecture owner**
- Runtime effect of this document: **none**

---

## 0. Changelog

### v0.2 — 2026-08-23

- fixed three permitted Actions to full verified commit SHAs;
- removed `hashicorp/setup-terraform` and selected direct signed-archive
  Terraform installation;
- advanced Terraform to stable 1.15.9 with exact Windows/Linux checksums;
- fixed `ubuntu-24.04`/`windows-2025` runner labels and required resolved image
  evidence;
- added secure action inputs and linked the unsigned owner decision record;
- retained Review/Absent state and all physical-execution blockers.

### v0.1 — 2026-08-23

- created the documentation-only R0 feasibility boundary and 52 AC.

## 1. Objective

R0 proves only that Recharge can create a deterministic local backend
toolchain, compile a minimal TypeScript/ESM Functions probe, run isolated
Firebase emulators, validate a credential-free Terraform skeleton and obtain
the same semantic result on Windows x64 and Linux x64.

R0 does not implement the Recharge backend. It creates no real project,
database, identity, endpoint, region-bound resource, billing link or production
data path.

## 2. Plain-language outcome

If R0 passes, the team knows:

- exact tools install reproducibly;
- TypeScript/ESM and selected Firebase SDK versions actually work together;
- a local-only Function can run against local emulators;
- default-deny Rules can be tested locally;
- Windows developers and Linux CI execute one command contract;
- Terraform configuration can be formatted and validated without credentials;
- no tool silently contacted or changed production.

R0 does **not** prove real Firebase IAM, latency, indexes, backup, residency,
cost, scaling, App Check, WIF, deployment or Booking correctness.

## 3. Authorization boundary

This v0.2 file defines the exact execution boundary. Bounded physical execution
was Approved in [BCK-R0-TCH-DEC-01](BACKEND_R0_APPROVAL_DECISION_RECORD.md) on
2026-08-24. The approval covers exactly §6 and no broader backend work.

Even after Approval, R0 may not:

- run `firebase login`, `firebase use`, `firebase projects:create` or deploy;
- run `gcloud auth`, create/enable a project/API, or attach billing;
- run `terraform plan/apply/import/destroy` against a remote backend;
- request `id-token: write` or use a service-account key/ADC;
- create `.firebaserc` with a real alias;
- modify `apps/mobile`, Create Hub, EventCreateBlock or Flutter dependencies;
- implement Booking, Event, identity, notification or another product flow;
- add a production secret, personal data, paid service or provider integration.

Unexpected authentication, project selection, deployment, billing or provider
mutation immediately stops the slice and records a boundary incident.

## 4. Preconditions

| ID | Requirement | Current state |
|---|---|---|
| R0-PRE-01 | BCK-R0-TCH-01 exact version explicitly Approved | Pass; owner decision recorded 2026-08-24 |
| R0-PRE-02 | Platform Operations owner named | Pass; combined-role bootstrap owner recorded |
| R0-PRE-03 | Platform Security owner reviews credential/egress boundaries | Pass for local R0 bootstrap; independent production review absent |
| R0-PRE-04 | Architecture owner confirms file map under ADR 0019 | Pass for exact v0.2 boundary |
| R0-PRE-05 | tool pins rechecked for support/security | Amendments Required; direct pins remain current, but dated npm audit reports unresolved Moderate transitive advisories and the stricter BCK05-OD01 wording has no approved disposition |
| R0-PRE-06 | exact base commit and pre-existing dirty files recorded | Pass; base `a6b04cbb…`, 37 documentation paths preserved in result record |
| R0-PRE-07 | no cloud/Firebase credentials are exposed to the job | Pass at entry; 0 sensitive context names, no `.firebaserc`/root `firebase.json` |
| R0-PRE-08 | rollback owner and evidence directory agreed | Pass; Product owner, `docs/evidence/backend/r0/` |
| R0-PRE-09 | every permitted GitHub Action repository and immutable full commit SHA are specified for `toolchain.lock.json` | Pass; three-action manifest revalidated 2026-08-24 |

Failure of any precondition keeps R0 blocked.

## 5. In-scope capability

R0 contains only:

1. toolchain metadata and exact public dependencies;
2. strict TypeScript/ESM compilation;
3. a non-product, emulator-only health probe;
4. default-deny Firestore/Storage Rules fixtures;
5. local Auth/Functions/Firestore/Storage/Pub/Sub emulator checks;
6. existing Booking schema/fixture parity read tests without backend behavior;
7. backendless Terraform format/init/validate;
8. Windows/Linux CI parity;
9. reproducibility, lifecycle, egress and absence evidence;
10. documentation/status reconciliation.

## 6. Exact file map

Only the following paths may be created or modified by an Approved R0:

```text
.gitignore                                      # only R0 artifact patterns
.github/workflows/backend-r0.yml                # no OIDC/secrets/deploy

apps/backend/
  README.md                                     # local-only commands/status
  firebase.json                                # demo emulator config + deny-deploy hook
  .firebaserc.example                          # demo alias only; no real project
  .tool-versions                               # Node/JDK/Terraform metadata
  toolchain.lock.json                          # schema v1 exact pins/digests
  firestore.rules                              # default deny
  storage.rules                                # default deny
  firestore.indexes.json                       # empty valid index contract
  functions/
    package.json
    package-lock.json
    tsconfig.json
    eslint.config.mjs
    .prettierrc.json
    src/
      index.ts                                 # exports only r0ToolchainProbe
      r0_toolchain_probe.ts                    # refuses non-emulator execution
    test/
      unit/
        r0_toolchain_probe.test.ts
      contract/
        booking_fixture_parity.test.ts
      emulator/
        r0_emulator_isolation.test.ts
        rules_default_deny.test.ts
  scripts/
    verify-toolchain.mjs
    verify-no-cloud-context.mjs
    verify-generated-clean.mjs
    verify-reproducibility.mjs
    install-terraform.mjs
    deny-cloud-deploy.mjs
    run-emulator-tests.mjs
  infra/
    terraform/
      versions.tf
      providers.tf                             # provider declaration; no credentials
      .terraform.lock.hcl

docs/evidence/backend/r0/
  README.md                                     # evidence schema/instructions
  BCK-R0-TCH-01_RESULT.md                       # completed result, no raw logs/secrets

docs/product/
  BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md
  BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md
  BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md
  BACKEND_R0_APPROVAL_DECISION_RECORD.md
  BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md
  BACKEND_DEPLOYMENT_OPERATIONS_COVERAGE_MATRIX.md
  RECHARGE_BACKEND_MASTER_SPEC.md
  RECHARGE_BACKEND_DELIVERY_MAP.md

docs/architecture/LAUNCH_STATUS.md
```

Anything else is out of scope. Generated `node_modules/`, `functions/lib/`,
emulator caches/logs, `.terraform/`, coverage and temporary evidence are
ignored and never staged.

## 7. Exact dependency candidates

Target direct manifest:

| Class | Package | Exact version |
|---|---|---:|
| runtime | `firebase-functions` | `7.3.2` |
| runtime | `firebase-admin` | `14.3.0` |
| development | `@types/node` | `22.20.1` |
| development | `typescript` | `6.0.3` |
| development | `firebase-tools` | `15.28.1` |
| development | `eslint` | `9.39.5` |
| development | `typescript-eslint` | `8.67.0` |
| development | `prettier` | `3.9.6` |

Host tools:

| Tool | Exact candidate |
|---|---:|
| Node.js | `22.23.2` |
| npm | `10.9.8` |
| Eclipse Temurin JDK | `21.0.12+8` |
| Terraform CLI | `1.15.9` |
| Google Terraform provider | `7.43.0` |

No dependency is added if npm reports an unsupported engine, unresolved peer,
deprecated security-critical path or indispensable unreviewed lifecycle script.
The result then becomes Failed/Amendments Required.

## 8. Minimal probe contract

`r0ToolchainProbe` exists only to prove Functions emulator/ESM wiring. It:

- is the only exported Function;
- has no repository, Admin SDK mutation or domain dependency;
- accepts no personal data and returns a fixed versioned object;
- returns a typed unavailable response unless `FUNCTIONS_EMULATOR=true`;
- never reads secrets, user claims, network or filesystem state;
- is marked non-product/non-deployable in code and tests;
- is removed or replaced under the first Approved backend capability slice.

Expected logical response:

```json
{
  "schemaVersion": 1,
  "status": "emulator_only",
  "runtimeMajor": 22
}
```

No timestamp, hostname or random value participates in the reproducibility
digest.

## 9. Default-deny Rules contract

R0 Rules deny every Firestore and Storage client read/write. Tests prove:

- unauthenticated access denied;
- synthetic authenticated access denied;
- cross-user/cross-page access denied by default;
- unknown paths denied;
- emulator Admin SDK bypass is not misreported as a Rules pass;
- no production ruleset is claimed.

These are safe scaffolding defaults, not BCK-04 Rules implementation.

## 10. Cloud-context denial

Before install, emulator or Terraform validation, `verify-no-cloud-context`
fails if it detects:

- `GOOGLE_APPLICATION_CREDENTIALS`;
- Firebase/Google access/refresh tokens;
- a non-demo project environment variable;
- `.firebaserc` or active project alias;
- metadata-server reachability in the CI context;
- GitHub `id-token: write` permission;
- a Terraform backend or credential variable;
- deploy-approval variables.

The script reports variable names only, never their values.

## 11. Install and lifecycle sequence

The Approved execution uses a disposable clean worktree/job:

```text
node --version
npm --version
java -version
terraform version
npm install --package-lock-only --ignore-scripts
npm ci --ignore-scripts
npm ls --all
npm audit --omit=dev
npm audit
```

Rules:

- resolved manifest/lock diff is reviewed before any script is enabled;
- lifecycle inventory records package, version, script name and reason;
- if no lifecycle script is indispensable, scripts remain disabled;
- an indispensable script is run only for the exact reviewed package and then
  the clean install is repeated and compared;
- `npm audit fix`, force upgrades and floating remediation are forbidden;
- registry/cache outage is Inconclusive, not a reason to relax the lock.

## 12. Build and test command contract

The package exposes stable scripts:

```text
npm run verify:cloud-context
npm run verify:toolchain
npm run format:check
npm run lint
npm run typecheck
npm run test:unit
npm run test:contract
npm run build
npm run test:emulator
npm run verify:generated
npm run verify:reproducibility
```

Semantics:

- `typecheck` uses `tsc --noEmit`;
- `build` uses plain `tsc`, no bundler/transpiler loader;
- tests compile and execute through built-in `node:test`;
- coverage uses the Node built-in facility and a recorded initial threshold;
- emulator command is implemented in Node for Windows/Linux parity;
- every failure is non-zero; no warning-only gate is counted Pass.

## 13. Emulator command

The wrapper invokes the project-local Firebase CLI with conceptually:

```text
npm exec --offline -- firebase emulators:exec
  --project demo-recharge
  --only auth,functions,firestore,storage,pubsub
  "npm run test:emulator:inside"
```

The Node wrapper supplies cross-platform quoting, fixed/validated ports,
timeout, child cleanup and bounded logs. It rejects an emulator warning that a
non-emulated service call may reach production unless the suite's network guard
proves the call impossible.

No imported seed contains personal or production-derived data.

## 14. Terraform feasibility contract

R0 Terraform contains only:

- `required_version = "= 1.15.9"`;
- `hashicorp/google = "= 7.43.0"`;
- provider metadata without project/credentials;
- the committed provider lock hashes.

Commands:

```text
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

R0 does not define a backend block or resource, run `plan/apply`, download a
beta provider, authenticate or create state outside disposable local files.

Terraform is not installed through a GitHub Action. `install-terraform.mjs`
downloads only the official platform archive and signed checksum manifest,
verifies the publisher signature according to HashiCorp guidance, verifies the
exact platform SHA below, extracts into a disposable R0-owned tools directory
and confirms `terraform version` equals 1.15.9:

| Platform archive | Required SHA-256 |
|---|---|
| `terraform_1.15.9_linux_amd64.zip` | `76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1` |
| `terraform_1.15.9_windows_amd64.zip` | `b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6` |

Signature, checksum, version or archive-name mismatch fails before extraction.
R0 never accepts a package-manager Terraform, an unverified mirror or a
floating download URL.

## 15. CI workflow contract

`backend-r0.yml`:

- triggers only for the exact R0 paths and manual read-only rerun;
- uses only `ubuntu-24.04` and `windows-2025` x64 matrix jobs; `*-latest` and
  preview runner labels are forbidden;
- has `permissions: contents: read` only;
- has no environment, secret, OIDC or cloud authentication step;
- may use only the exact manifest below; tags, branches and shortened SHAs are
  forbidden:

| Action | Informational release | Required `uses` SHA |
|---|---:|---|
| `actions/checkout` | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | `v7.0.0` | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/setup-java` | `v5.7.0` | `b6effb05e454b25005698d916606bdc6ffcbf961` |

Required action inputs:

- checkout: `persist-credentials: false`, `clean: false`,
  `set-safe-directory: false`, `fetch-depth: 1`, `fetch-tags: false`,
  `lfs: false`, `submodules: false`;
- setup-node: exact `node-version: 22.23.2`, `check-latest: false`,
  `package-manager-cache: false`, with no registry/mirror/token override;
- setup-java: `distribution: temurin`, exact `java-version: 21.0.12+8`,
  `check-latest: false`, `verify-signature: true`, with no cache, publishing,
  GPG private-key or repository credentials and `overwrite-settings: false`;
- `hashicorp/setup-terraform` and every upload/cache/login/deploy action are
  absent; Terraform follows §14.

The job records the resolved Actions runner version, `ImageOS` and
`ImageVersion` before executing repository code. An unsupported Node 24 action
runtime or image migration is Inconclusive/Failed, never silently downgraded.

The workflow additionally:

- verifies downloaded tool checksums/digests;
- runs the same npm scripts as local development;
- writes only a sanitized step summary; artifact-upload Actions are not allowed
  in R0, and `node_modules`, tokens, raw emulator data, Terraform plan/state or
  full environment dumps are never persisted;
- has bounded timeout and concurrency cancellation;
- cannot deploy on success.

CI success is R0 feasibility evidence, not production release evidence.
This exact v0.2 boundary was Approved and executed locally. Hosted CI evidence
and the Moderate-advisory disposition remain required before R0 Pass; neither
changes the production/cloud authorization boundary.

## 16. Reproducibility contract

Two fresh Linux jobs from the same commit must produce:

- identical direct manifest and lock digest;
- identical normalized `functions/lib` logical digest;
- identical contract/fixture result digest;
- identical toolchain-lock digest;
- no untracked source/generated change.

Windows must produce the same semantic test/fixture results. Platform-specific
binary/cache digests are recorded separately and are not falsely required to be
byte-identical.

## 17. Evidence record

`BCK-R0-TCH-01_RESULT.md` records:

- base commit and scoped diff;
- UTC start/end and runner OS/architecture;
- exact commands and exit codes;
- resolved direct/transitive version and integrity summary;
- lifecycle-script inventory/verdict;
- tool/binary checksums or immutable image digests;
- unit/contract/emulator/rules/Terraform results;
- reproducibility comparison;
- absence checks for credentials, project, billing and deployment;
- limitations and Inconclusive items;
- owner/security/architecture verdicts.

It contains no token, environment dump, payload, absolute home path or raw
personal data.

## 18. Failure handling

| Failure | Outcome |
|---|---|
| unsupported peer/engine | fail; amend candidate, never force install |
| required unreviewed lifecycle script | fail; review exact package/script |
| non-demo project detected | abort before emulator start |
| credential/ADC detected | abort and sanitize environment |
| real API/network attempt | security failure; preserve bounded evidence |
| Windows/Linux semantic difference | fail parity gate |
| non-reproducible logical output | fail; identify nondeterministic input |
| Terraform requests credential/backend | fail boundary gate |
| dependency/tool download unavailable | Inconclusive; retry later without relaxing pins |
| unexpected file changed | fail scope gate and restore only R0-owned files |

## 19. Rollback

R0 is isolated in one scoped commit after preserving all pre-existing user
changes. Rollback removes/reverts only the exact R0-owned paths from §6 and
restores the three documentation revisions to their prior recorded versions.

Rollback never uses `git reset --hard`, broad checkout or recursive deletion of
the repository/workspace. Generated caches are removed only after resolving and
verifying their absolute paths beneath `apps/backend` or the job temp directory.

Because R0 creates no cloud state, no cloud rollback is expected. Detection of
cloud state means the slice boundary was violated and incident reconciliation
is required.

## 20. Definition of Done

R0 is Done only when:

- every precondition has an explicit Pass;
- exact file scope is preserved in one reviewable change set;
- all package/tool pins resolve without forced peer/engine override;
- lifecycle policy is evidenced;
- Windows and Linux gates pass;
- two clean Linux builds reconcile;
- emulator isolation and default-deny Rules tests pass;
- Terraform backendless validation passes;
- 0 real project, credential, resource, deployment or billing effects exist;
- result record is complete and reviewed;
- BCK05-OD-01 receives a separate explicit owner decision.

R0 completion alone does not approve R1/G1.

## 21. Acceptance criteria

1. **BCK-R0-TCH-AC-01:** this v0.2 document creates no runtime file.
2. **BCK-R0-TCH-AC-02:** physical work requires exact-version Approval.
3. **BCK-R0-TCH-AC-03:** R0 scope is toolchain/emulator feasibility only.
4. **BCK-R0-TCH-AC-04:** the file map is exhaustive and fail-closed.
5. **BCK-R0-TCH-AC-05:** pre-existing user changes are preserved.
6. **BCK-R0-TCH-AC-06:** R0 creates one backend scaffold under `apps/backend`.
7. **BCK-R0-TCH-AC-07:** R0 adds no second backend application.
8. **BCK-R0-TCH-AC-08:** mobile/Create/Event runtime is untouched.
9. **BCK-R0-TCH-AC-09:** exact direct package versions are fixed.
10. **BCK-R0-TCH-AC-10:** transitive versions are lockfile-owned.
11. **BCK-R0-TCH-AC-11:** unsupported peer/engine resolution fails.
12. **BCK-R0-TCH-AC-12:** lifecycle scripts start disabled.
13. **BCK-R0-TCH-AC-13:** lifecycle exceptions are exact and reviewed.
14. **BCK-R0-TCH-AC-14:** force/floating package remediation is forbidden.
15. **BCK-R0-TCH-AC-15:** Node/npm/JDK/CLI versions are verified.
16. **BCK-R0-TCH-AC-16:** TypeScript uses strict ESM/NodeNext.
17. **BCK-R0-TCH-AC-17:** built-in `node:test` is the only test runner.
18. **BCK-R0-TCH-AC-18:** no bundler/runtime transpiler is added.
19. **BCK-R0-TCH-AC-19:** the probe is emulator-only and non-product.
20. **BCK-R0-TCH-AC-20:** the probe processes no personal data.
21. **BCK-R0-TCH-AC-21:** Firestore/Storage Rules deny all by default.
22. **BCK-R0-TCH-AC-22:** Admin SDK bypass is not a Rules pass.
23. **BCK-R0-TCH-AC-23:** only `demo-*` project identity is allowed.
24. **BCK-R0-TCH-AC-24:** canonical R0 contains no credential/ADC.
25. **BCK-R0-TCH-AC-25:** cloud-context checks disclose no secret values.
26. **BCK-R0-TCH-AC-26:** non-emulated real API access fails.
27. **BCK-R0-TCH-AC-27:** Firebase CLI is project-local.
28. **BCK-R0-TCH-AC-28:** deploy commands are denied.
29. **BCK-R0-TCH-AC-29:** no real `.firebaserc` alias exists.
30. **BCK-R0-TCH-AC-30:** CI has no OIDC or secret permission.
31. **BCK-R0-TCH-AC-31:** GitHub Actions are full-SHA pinned.
32. **BCK-R0-TCH-AC-32:** Linux and Windows run one semantic script contract.
33. **BCK-R0-TCH-AC-33:** two clean Linux builds reconcile.
34. **BCK-R0-TCH-AC-34:** platform binaries are compared appropriately.
35. **BCK-R0-TCH-AC-35:** Terraform version/provider are exact.
36. **BCK-R0-TCH-AC-36:** Terraform uses no remote backend in R0.
37. **BCK-R0-TCH-AC-37:** Terraform plan/apply/import/destroy are forbidden.
38. **BCK-R0-TCH-AC-38:** `google-beta` is absent.
39. **BCK-R0-TCH-AC-39:** no project/API/billing/resource is created.
40. **BCK-R0-TCH-AC-40:** no service account, key, secret or WIF is created.
41. **BCK-R0-TCH-AC-41:** evidence contains exact commands/results/limitations.
42. **BCK-R0-TCH-AC-42:** evidence contains no token/payload/environment dump.
43. **BCK-R0-TCH-AC-43:** timeout/unavailable dependency is Inconclusive.
44. **BCK-R0-TCH-AC-44:** unexpected file change fails scope.
45. **BCK-R0-TCH-AC-45:** rollback targets only R0-owned paths.
46. **BCK-R0-TCH-AC-46:** rollback uses no destructive repository reset.
47. **BCK-R0-TCH-AC-47:** R0 implements no product/domain capability.
48. **BCK-R0-TCH-AC-48:** R0 success does not prove production readiness.
49. **BCK-R0-TCH-AC-49:** OD-01 requires a separate explicit owner decision.
50. **BCK-R0-TCH-AC-50:** R1/G1 remain separately blocked after R0.
51. **BCK-R0-TCH-AC-51:** only the three named GitHub Action repositories are allowed.
52. **BCK-R0-TCH-AC-52:** exact reviewed action SHAs are a blocking Approval precondition.
53. **BCK-R0-TCH-AC-53:** runner OS labels are explicit and non-preview.
54. **BCK-R0-TCH-AC-54:** resolved runner/image versions are recorded as evidence.
55. **BCK-R0-TCH-AC-55:** checkout credential/clean/global edits and automatic dependency caches are disabled.
56. **BCK-R0-TCH-AC-56:** setup Actions receive no publishing/cloud credential.
57. **BCK-R0-TCH-AC-57:** Terraform is not installed through a GitHub Action.
58. **BCK-R0-TCH-AC-58:** Terraform checksum-manifest signature is verified before extraction.
59. **BCK-R0-TCH-AC-59:** exact Windows/Linux Terraform archive checksums are enforced.
60. **BCK-R0-TCH-AC-60:** R0 uploads no artifact and persists only sanitized summary evidence.

---

**Current conclusion:** bounded R0 v0.2 is implemented and locally operational.
Exact local build, emulator, Rules, Terraform and reproducibility evidence is
present, but hosted Windows/Linux parity is Pending and the Moderate advisory
disposition is unresolved. R0 is therefore Amendments Required, not Pass.
Product/cloud backend capability, R1/G1, credentials, provisioning, deployment
and production data processing remain unauthorized.
