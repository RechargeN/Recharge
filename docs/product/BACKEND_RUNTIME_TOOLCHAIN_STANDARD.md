# Recharge Backend — Runtime & Toolchain Standard

- ID: **BCK05-OD01-TCH-01**
- Version: **0.3.3**
- Date: **2026-08-24**
- Status: **Draft evidence — BCK05-OD-01 Proposed; bounded R0 Pass with expiring controls**
- Runtime status: **Local R0 tooling scaffold Present; product/cloud runtime Absent**
- Accountable owner: **Platform Operations owner**
- Security reviewer: **Platform Security owner**
- Parent: [BCK-05 v0.2.15](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Architecture authority: [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md) (Accepted target; no runtime authorization)
- IAM dependency: [BCK05-OD02-IAM-01](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md)
- Release dependency: [BCK05-OD07-REL-01](BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md)
- Technical review: [BCK05-OD01-TCH-REV-01](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md) v0.2.3
- Executed R0 slice: [BCK-R0-TCH-01](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md) v0.2.2 (Pass — bounded tooling feasibility only)
- R0 decision record: [BCK-R0-TCH-DEC-01](BACKEND_R0_APPROVAL_DECISION_RECORD.md) v0.2
- Runtime effect: **none**
- Canonical repository path: `docs/product/BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md`

---

## 0. Changelog

### v0.3.3 — 2026-08-24

- recorded owner acceptance of `BCK-R0-TCH-ADV-01` for the two audited root
  Moderate advisories under demo-only, loopback-only and no-cloud controls;
- closed the final bounded R0 evidence blocker with expiry on `2026-09-24` or
  immediately before R1/G1 or cloud/public-ingress work, whichever is earlier;
- retained `BCK05-OD-01` as Proposed and product/cloud runtime as Absent.

### v0.3.2 — 2026-08-24

- recorded successful `ubuntu-24.04` and `windows-2025` hosted R0 matrices in
  draft PR #7, including emulator, Rules, reproducibility and Terraform gates;
- documented the Windows setup-java selector, MSYS-GPG path normalization,
  trusted system tar and checkout-EOL-neutral format check;
- retained the unresolved Moderate advisory disposition as the only R0
  evidence blocker and preserved product/cloud runtime as Absent.

### v0.3.1 — 2026-08-24

- reconciled the Approved bounded R0 implementation and exact local execution
  evidence without accepting BCK05-OD-01;
- recorded green local build/emulator/Rules/Terraform/reproducibility results,
  Pending hosted parity and unresolved Moderate transitive advisories;
- retained product/cloud runtime, credentials, provisioning and deployment as
  Absent/unauthorized.

### v0.3 — 2026-08-23

- pinned the only three permitted GitHub Actions to reviewed full commit SHAs;
- rejected `hashicorp/setup-terraform` from R0 after its selected official
  release commit was found unsigned and replaced it with verified direct
  HashiCorp archive installation;
- advanced Terraform from 1.15.8 to stable 1.15.9 and pinned the exact
  Linux/Windows archive checksums;
- fixed non-floating runner labels and security-sensitive action inputs;
- linked the R0 approval decision record while retaining Proposed/Absent state.

### v0.2 — 2026-08-23

- revalidated the primary pins against current official sources;
- proposed exact Firebase SDK, Node types, lint and format dependencies plus
  Temurin JDK 21.0.12+8 for the bounded R0 compatibility slice;
- selected the built-in Node test runner to avoid another framework and linked
  the technical review and exact documentation-only R0 plan;
- retained BCK05-OD-01 as Proposed and runtime as Absent; no package was
  installed and no backend file or resource was created.

### v0.1 — 2026-08-21

- selected the initial Node.js 22/TypeScript/npm/Firebase CLI/Terraform
  candidate and deterministic build/emulator/IaC contract.

## 0.1 Verdict

This document selects a concrete, reproducible **candidate** backend toolchain
for Recharge and moves `BCK05-OD-01` from Open to **Proposed**. It does not
create `apps/backend`, change the Flutter application, install a dependency,
authenticate to Google, provision Firebase, create billing, or deploy code.

The candidate is:

- Cloud Functions for Firebase **2nd gen**;
- provider runtime **Node.js 22**;
- local/build Node.js **22.23.2** with bundled npm **10.9.8**;
- TypeScript **6.0.3**, strict ESM/`NodeNext` compilation;
- Firebase CLI **15.28.1** installed as an exact project dev dependency;
- Terraform CLI **1.15.9** with `hashicorp/google` **7.43.0** for GA control
  plane resources;
- Google Cloud CLI **581.0.0** only for bootstrap, inspection and narrowly
  approved provider operations;
- Firebase Local Emulator Suite via the pinned Firebase CLI, with Eclipse
  Temurin JDK **21.0.12+8** and platform artifact checksums/digests captured at
  executable R0.

These are point-in-time candidate pins reverified on 2026-08-23. Acceptance
requires compatibility installation, build, emulator, negative-security and
reproducibility evidence in an **Approved documentation/tooling-only R0 slice**.
No floating `latest`, caret or tilde becomes release authority.

## 1. Scope and non-goals

This standard defines:

- runtime, language, module system and package manager;
- exact point-in-time tool candidates and the authoritative lock record;
- repository layout and ownership of Firebase CLI, Terraform and `gcloud`;
- deterministic install/build/test/emulator command contracts;
- dependency, generated-output, cache and upgrade policy;
- cross-platform developer and CI expectations;
- evidence required before OD-01 can become Accepted.

It does **not** decide:

- Firebase project IDs, billing, Firestore edition or locations (`OD-07`);
- exact IAM roles, claims or GitHub environment controls (`BCK05-OD-02`);
- function inventory, transport deadlines or domain implementations;
- schema semantics owned by BCK-03 or Booking contracts;
- production rollout, attestation or promotion acceptance (`BCK05-OD-07`);
- search, email, notification or provider choices;
- product backend implementation or cloud activation beyond the separately
  Approved R0 tooling scaffold.

## 2. Current repository reality

As of 2026-08-24:

- the exact local-only R0 scaffold exists under `apps/backend`;
- `package-lock.json`, backendless Terraform provider lock and the R0 workflow
  are Present;
- exact portable Node/npm/Temurin/Terraform tools and Firebase emulators were
  executed with no credentials against `demo-recharge`;
- local build, lint, typecheck, unit/contract, live Functions probe,
  default-deny Rules, Terraform and reproducibility gates passed;
- hosted Windows/Linux workflow evidence is Pass in draft PR #7, run
  `32684234236`;
- no real `.firebaserc`, Firebase/Google project, credential, state, deploy
  workflow authority or product backend capability exists.

The versions in §4 are therefore implemented R0 pins and remain candidates
for later product/cloud runtime adoption.

## 3. Dated source record

| Source | Fact used | Design consequence |
|---|---|---|
| [Firebase runtime management](https://firebase.google.com/docs/functions/manage-functions) | Cloud Functions for Firebase supports Node.js 20 and 22, supports CJS and ESM, and lets `firebase.json` override `package.json` runtime selection. | Choose Node.js 22 and require both declarations to agree; choose ESM explicitly. |
| [Node.js release schedule](https://nodejs.org/en/about/previous-releases) | Production should use supported LTS lines; Node 20 is EOL while Node 22 remains LTS. | Node 20 is rejected even though Firebase still lists it. |
| [Node.js 22 archive](https://nodejs.org/en/download/archive/v22) | The current v22 point release is 22.23.2 and bundles npm 10.9.8. | Use those exact local/build candidates; cloud runtime patch remains provider-managed. |
| [Firebase TypeScript guide](https://firebase.google.com/docs/functions/typescript) | TypeScript must be compiled before emulator execution/deploy; a predeploy build hook is supported. | Build is an explicit gate and deploy cannot compile an unverified tree implicitly. |
| [TypeScript 6.0.3 release](https://github.com/microsoft/TypeScript/releases/tag/v6.0.3) | 6.0.3 is a stable compiler release from the established TypeScript compiler line. | Use it as the conservative R0 compatibility candidate; adoption of the newer compiler-generation line requires its own compatibility evidence. |
| [Firebase CLI releases](https://github.com/firebase/firebase-tools/releases) | Firebase CLI 15.28.1 is the latest stable release at the review date. | Pin it locally and invoke with `npm exec --offline -- firebase`; no global/floating release authority. |
| [Local Emulator Suite install/config](https://firebase.google.com/docs/emulator-suite/install_and_configure) | CI-oriented `emulators:exec` is supported; Java-based emulators require JDK 11+. | Standardize JDK 21 LTS and one bounded emulator command; emulator proof remains non-production. |
| [Eclipse Temurin support](https://adoptium.net/support/) | Temurin 21 is an LTS line and 21.0.12+8 is the current July 2026 release. | Select Temurin 21.0.12+8 for R0; record per-platform artifact checksum/digest. |
| [npm ci](https://docs.npmjs.com/cli/v11/commands/npm-ci/) | `npm ci` requires a matching lockfile, never rewrites it and is intended for automated clean installs. | CI uses frozen install and rejects package/lock drift. |
| [Terraform 1.15.9 release](https://github.com/hashicorp/terraform/releases/tag/v1.15.9) | 1.15.9 is the current stable patch selected at the review date. | Pin the stable CLI and reject alpha/beta/RC tools in release workflows. |
| [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | `ubuntu-24.04` and `windows-2025` are explicit x64 hosted-runner labels. | Use explicit labels, record the resolved image version and never use `*-latest` as reproducibility identity. |
| [Terraform archive verification](https://developer.hashicorp.com/terraform/tutorials/cli/verify-archive) | HashiCorp publishes signed checksum manifests for Terraform archives. | Verify the detached signature and exact archive SHA before execution. |
| [Terraform GCS backend](https://developer.hashicorp.com/terraform/language/backend/gcs) | GCS remote state supports locking and recommends bucket object versioning. | Use isolated GCS state only after bootstrap; never commit local state. |
| [Terraform style/state guidance](https://developer.hashicorp.com/terraform/language/style) | `.terraform.lock.hcl` is committed; state, plans and `.terraform/` are not. | Lock providers, protect state and treat plans as sensitive ephemeral evidence. |
| [Google provider registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs) | `hashicorp/google` 7.43.0 is the current GA provider at the review date. | Pin GA provider; `google-beta` is absent unless separately justified. |
| [Google Cloud CLI release notes](https://docs.cloud.google.com/sdk/docs/release-notes) | Google Cloud CLI 581.0.0 was released 2026-08-18. | Pin inspection/bootstrap tooling; do not make it an overlapping deploy authority. |

Source freshness is rechecked at R0 start. A newer version does not silently
replace a pin; an unsupported or vulnerable pin blocks R0 until this record is
amended.

## 4. Candidate version matrix

| Component | Candidate pin | Authority in target | Pin rule |
|---|---:|---|---|
| Cloud Functions generation | 2nd gen | trusted server command/effect runtime | explicit v2 SDK APIs only |
| Cloud Node runtime | `nodejs22` | provider runtime major | identical in `firebase.json` and `engines.node` |
| Local/build Node | `22.23.2` | compiler/test/emulator host | exact version plus CI image digest |
| npm | `10.9.8` | sole backend package manager | exact `packageManager`; committed lockfile |
| TypeScript | `6.0.3` | compiler | exact dev dependency |
| Firebase CLI | `15.28.1` | emulators and Firebase-owned deployments | exact dev dependency; no global authority |
| Terraform CLI | `1.15.9` | declarative Google control plane | exact signed archive checksum |
| Google provider | `7.43.0` | GA Google/Firebase-supporting resources | exact constraint and lock hashes |
| Google beta provider | absent | none | separate decision and expiring exception required |
| Google Cloud CLI | `581.0.0` | bootstrap/read-only inspection/approved gaps | exact image/package; no routine deploy overlap |
| Java | Eclipse Temurin `21.0.12+8` | Java-based local emulators only | exact build; per-platform checksum/digest captured in R0 |

### 4.1 R0 package candidate matrix

| Package | Candidate pin | Scope | Reason |
|---|---:|---|---|
| `firebase-functions` | `7.3.2` | production dependency | current stable v2 Functions SDK candidate |
| `firebase-admin` | `14.3.0` | production dependency | current stable privileged server SDK candidate |
| `@types/node` | `22.20.1` | development dependency | latest reviewed Node 22 type line, not Node 26 types |
| `typescript` | `6.0.3` | development dependency | conservative established-compiler compatibility baseline |
| `firebase-tools` | `15.28.1` | development dependency | project-local emulator/deployment CLI |
| `eslint` | `9.39.5` | development dependency | maintained line chosen over a fresh major until peer compatibility is proven |
| `typescript-eslint` | `8.67.0` | development dependency | typed flat-config lint integration candidate |
| `prettier` | `3.9.6` | development dependency | deterministic formatter candidate with no runtime dependency |

R0 uses the Node.js built-in `node:test` runner and built-in coverage rather
than Jest/Vitest. No bundler, runtime transpiler, dependency-injection framework
or server framework is admitted by this slice. Clean local install and
peer/engine compatibility and hosted parity passed. The residual Moderate
advisories are covered by the expiring `BCK-R0-TCH-ADV-01` disposition for the
bounded R0 context only; a fresh decision is required after any listed trigger.

### 4.2 Provider-managed patch boundary

Firebase accepts a Node **major**, not an exact cloud patch. Recharge controls
the exact local/build patch and records the deployed provider runtime/revision,
but must not claim that Cloud Functions runs the same `22.23.2` patch.
Compatibility proof therefore covers:

1. exact local/build Node;
2. `nodejs22` emulator behavior;
3. stage deployment runtime metadata after R1 authorization;
4. a provider patch-change regression path.

### 4.3 R0 CI supply-chain manifest

Only these external Actions may appear in `backend-r0.yml`:

| Action | Release label | Immutable commit SHA | Review fact |
|---|---:|---|---|
| `actions/checkout` | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | GitHub commit verification `valid`; Node 24 action runtime |
| `actions/setup-node` | `v7.0.0` | `820762786026740c76f36085b0efc47a31fe5020` | GitHub commit verification `valid`; Node 24 action runtime |
| `actions/setup-java` | `v5.7.0` | `b6effb05e454b25005698d916606bdc6ffcbf961` | GitHub commit verification `valid`; Node 24 action runtime |

`hashicorp/setup-terraform` is not admitted to R0. The reviewed v4.0.1 tag
resolved to unsigned commit
`dfe3c3f87815947d99a8997f908cb6525fc44e9e`, and the action also exposes
optional credential inputs R0 does not need. Terraform is installed directly
from the official release archive after signature/checksum validation:

| Archive | SHA-256 |
|---|---|
| `terraform_1.15.9_linux_amd64.zip` | `76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1` |
| `terraform_1.15.9_windows_amd64.zip` | `b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6` |

The canonical runners are `ubuntu-24.04` and `windows-2025`, never floating
`*-latest`. Hosted images still evolve behind those OS labels, so every result
records `ImageOS`, `ImageVersion` and Actions runner version; semantic parity,
not byte identity of the VM, is the R0 cross-platform claim.

## 5. Language and module contract

Target `functions/package.json`:

```json
{
  "private": true,
  "type": "module",
  "engines": {"node": "22"},
  "packageManager": "npm@10.9.8"
}
```

Target compiler policy:

- `module` and `moduleResolution`: `NodeNext`;
- `target`: `ES2023`;
- `lib`: `ES2023`;
- `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`,
  `noImplicitOverride`, `noFallthroughCasesInSwitch`: enabled;
- source maps enabled for diagnosis, with source content and release access
  controlled by BCK-04/BCK-05;
- output goes only to `lib/`; source never imports from `lib/`;
- relative ESM imports include emitted `.js` extensions;
- no `allowJs`, runtime transpilation, `ts-node` production entrypoint or
  path-alias requiring an untracked loader;
- `skipLibCheck` is false unless a documented, expiring dependency exception
  proves why the upstream declaration cannot yet be replaced.

Generated files are deterministic, carry generator/version provenance and are
never hand-edited. Domain behavior remains outside transport handlers.

## 6. Target repository layout

This map is conditional and unauthorized until the executable slice is
Approved:

```text
apps/backend/
  README.md
  firebase.json
  .firebaserc.example
  .tool-versions
  toolchain.lock.json
  functions/
    package.json
    package-lock.json
    tsconfig.json
    eslint.config.js
    src/
      platform/
      domains/
      generated/
      index.ts
    test/
      unit/
      contract/
      emulator/
      rules/
    lib/                         # generated; ignored, never committed
  scripts/
    verify-toolchain.mjs
    verify-generated.mjs
    verify-emulator-isolation.mjs
  infra/
    terraform/
      bootstrap/                # separately privileged and one-time
      modules/
      environments/
        dev/
        stage/
        prod/
      versions.tf
      .terraform.lock.hcl
```

The backend is not added to the Flutter/Melos dependency graph. Node and
Terraform commands run from their explicit directories. One root convenience
wrapper may dispatch commands but cannot create a second lockfile or package
authority.

## 7. `toolchain.lock.json` contract

The executable slice creates one machine-readable record with at least:

```json
{
  "schemaVersion": 1,
  "verifiedAt": "<UTC timestamp>",
  "node": {"runtimeMajor": 22, "buildVersion": "22.23.2"},
  "npm": "10.9.8",
  "typescript": "6.0.3",
  "firebaseTools": "15.28.1",
  "terraform": {
    "version": "1.15.9",
    "linuxAmd64Sha256": "76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1",
    "windowsAmd64Sha256": "b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6"
  },
  "terraformGoogle": "7.43.0",
  "gcloud": "581.0.0",
  "java": {"version": "21.0.12+8", "distribution": "eclipse-temurin"},
  "githubActions": {
    "checkout": "3d3c42e5aac5ba805825da76410c181273ba90b1",
    "setupNode": "820762786026740c76f36085b0efc47a31fe5020",
    "setupJava": "b6effb05e454b25005698d916606bdc6ffcbf961"
  },
  "runners": ["ubuntu-24.04", "windows-2025"],
  "images": {"build": "<resolved image version>", "gcloud": "<digest>"}
}
```

Rules:

- unknown/newer schema fails closed;
- versions are exact; images use immutable digests;
- all human-readable declarations reconcile with this record;
- the build records its digest in `BackendReleaseManifest`;
- editing the record requires compatibility evidence and review;
- no credential, project secret, token or private registry password is stored.

## 8. Package and dependency policy

1. npm is the only backend package manager; Yarn, pnpm and Bun are rejected
   unless OD-01 is reopened.
2. `package.json` uses exact dependency versions; `^`, `~`, `*`, tags, Git
   branches and unpinned URLs are forbidden for release inputs.
3. `package-lock.json` is committed and is the install authority.
4. CI uses `npm ci`; package/lock mismatch is a hard failure.
5. Dependency updates arrive as narrow reviewable changes with changelog,
   license, vulnerability, build, contract and emulator evidence.
6. Lifecycle scripts are deny-by-default in CI except an explicit reviewed
   allowlist recorded in project `.npmrc`/policy evidence.
7. Production dependencies and dev dependencies are separated; test/build
   tools are not shipped when the provider build supports pruning.
8. Registry integrity hashes and resolved URLs come only from the lockfile;
   cache never overrides lock integrity.
9. Cache is an optimization, never evidence; cold-cache build is mandatory.
10. `firebase-admin`, `firebase-functions`, linters/test runners and schema
    tools receive exact pins during R0 compatibility work, not invented here.

## 9. Deterministic command contract

The executable package must expose stable scripts; CI calls scripts, not
duplicated platform-specific command strings:

```text
npm ci
npm run verify:toolchain
npm run format:check
npm run lint
npm run typecheck
npm run test:unit
npm run test:contract
npm run build
npm run verify:generated
npm run test:emulator
npm run evidence:manifest
```

Required semantics:

- `typecheck` uses `tsc --noEmit`;
- `build` cleans only the known `functions/lib` output and compiles once;
- tests cannot write to production endpoints or select a real project;
- each script returns non-zero for Failed or Inconclusive;
- warnings requiring human interpretation cannot be silently counted Pass;
- logs are UTF-8, redact secrets/payloads and identify exact tool versions;
- PowerShell and Linux CI invoke identical npm scripts.

Deploy commands are not part of R0 and remain absent until a separately
Approved release slice.

## 10. Emulator isolation contract

The canonical CI form is conceptually:

```text
npm exec --offline -- firebase emulators:exec \
  --project demo-recharge \
  --only auth,functions,firestore,storage,pubsub \
  "npm run test:emulator:inside"
```

The exact cross-platform wrapper is selected in R0. It must:

- force a `demo-*` project ID and reject any production/stage alias;
- set every supported emulator host explicitly;
- fail if Application Default Credentials or a service-account key are
  required for the suite;
- prevent non-emulated API calls through test doubles/network controls;
- use fixed ports or collision-safe allocated ports with a recorded map;
- seed deterministic, versioned non-personal fixtures;
- start from clean state unless a named fixture import is under test;
- terminate all child processes and preserve bounded logs on failure;
- record emulator binary/cache hashes where available;
- state that emulator success does not prove IAM, indexes, latency, backup,
  billing, region or provider behavior.

Firebase documentation shows optional key-based credentials for access to
non-emulated APIs. Recharge forbids that path for the canonical suite; a test
that needs a real API belongs to a separately authorized stage test using WIF.

## 11. Infrastructure-as-code ownership

Terraform owns the Google control plane after OD-07/R1 approval:

- projects/folders and required APIs where organizational authority permits;
- IAM, WIF pools/providers, service accounts and policy bindings;
- Artifact Registry, state buckets, KMS and supported monitoring resources;
- resource-level retention/protection settings supported by the GA provider;
- outputs consumed as non-secret deployment inputs.

Firebase CLI owns Firebase application-plane deployables:

- Cloud Functions source deployment;
- Firestore and Storage Rules;
- Firestore indexes;
- Firebase-specific configuration supported by the chosen CLI path.

`gcloud` owns neither desired state nor routine deployment. It is limited to:

- bootstrap steps Terraform cannot perform before its own state/identity exists;
- read-only inspection and post-deploy reconciliation;
- an explicitly approved provider gap with owner, expiry and import-back plan;
- incident/break-glass actions governed by BCK05-OD02-IAM-01.

One resource has one writer. Console changes are emergency exceptions and must
be reconciled or reverted; they never become silent desired state.

## 12. Terraform state and execution

- one isolated state root per environment/control scope; prod never shares a
  state object or apply identity with dev/stage;
- GCS backend uses locking, object versioning, retention/access controls and an
  accepted region before state creation;
- state, plans, `.terraform/`, credentials and sensitive `.tfvars` are never
  committed;
- `.terraform.lock.hcl` is committed and provider hashes are verified;
- PR gate: `terraform fmt -check`, `terraform init -backend=false`,
  `terraform validate` and static/policy checks;
- environment plan: initialized with the exact remote backend and WIF identity,
  then `terraform plan -out=<ephemeral>`;
- apply uses the reviewed saved plan only, within a bounded approval window;
- plan files are sensitive, encrypted/short-lived and never public artifacts;
- `-target`, `-refresh=false`, local state and manual import are forbidden in
  routine delivery; exceptions require a reconciliation record;
- destroy is a separate destructive workflow with exact scope and approvals;
- drift detection is read-only and blocks promotion on unknown/high-risk drift.

## 13. Firebase configuration rules

- `firebase.json` declares `nodejs22`; `functions/package.json` declares Node
  `22`; mismatch fails `verify:toolchain`;
- 2nd-gen APIs are used explicitly; mixed generation needs a migration plan;
- runtime options live in source/config as the declared source of truth;
  `preserveExternalChanges` is false;
- project aliases contain IDs only and no credentials; CI always passes an
  exact environment-derived project ID;
- partial component deploy is generated from the reviewed release manifest;
  a human ad-hoc `firebase deploy` is not production authority;
- build/test evidence precedes deploy and provider-triggered rebuild output is
  reconciled to the source bundle and provider revision per BCK05-OD07-REL-01;
- CLI telemetry/prompting is disabled in CI; all commands are non-interactive;
- deletion prompts or unexpected function discovery fail closed.

## 14. Local development and cross-platform parity

Supported developer hosts are Windows 11 PowerShell and the Linux image used
by CI. macOS may work but is not a release gate until explicitly added.

Parity rules:

- versions come from the lock record, not the machine `PATH`;
- CI is the release authority; a local pass cannot replace a CI pass;
- scripts are Node programs or npm scripts, not duplicated `.ps1`/`.sh`
  business logic;
- paths use repository-relative normalized paths;
- line endings, locale and timezone are deterministic (`UTC`, UTF-8);
- tests use fake time/clock injection and cannot depend on local Latvia time;
- native dependencies require Windows/Linux evidence or are rejected;
- Docker/OCI may provide build isolation, but a floating base image is banned;
- developer convenience global CLIs may exist, but verification rejects a
  version different from the project pin.

## 15. Build, generated output and reproducibility

A reproducible build proves:

1. clean checkout plus committed inputs;
2. exact Node/npm/toolchain record;
3. cold `npm ci` from the committed lock;
4. deterministic contract/code generation;
5. lint, typecheck, unit and contract success;
6. identical logical bundle/source digest across two clean builders, or a
   documented nondeterminism field excluded from the logical digest;
7. SBOM and provenance subject match the release manifest;
8. no untracked source/generated diff after build;
9. no secret or absolute workstation path in outputs;
10. output can be traced to commit, lockfile and toolchain digests.

Timestamps, source maps and archives must use a canonical epoch/order when they
participate in the digest. Provider-created Function images are recorded, not
misrepresented as locally reproducible OCI artifacts.

## 16. Security and supply-chain gates

- the three allowed GitHub Actions are full-SHA pinned and revalidated against
  their official repositories before execution;
- checkout uses `persist-credentials: false`, `clean: false` and does not edit
  global safe-directory state; setup-node uses
  `package-manager-cache: false`; setup-java uses `check-latest: false` and
  signature verification without overwriting Maven settings; no action
  receives a registry, publishing or cloud credential;
- Node, Firebase CLI, Terraform, providers, JDK and CI images have verified
  checksums/signatures/digests where the publisher supplies them;
- dependency, license, secret, IaC and source scans run before promotion;
- Critical/High findings follow the explicit BCK-05 exception policy; missing
  evidence is Inconclusive, not Pass;
- install/build jobs have no cloud deploy token;
- deploy jobs consume verified immutable inputs and do not run arbitrary
  dependency lifecycle scripts;
- package registry and provider download egress are bounded/audited;
- mutable cache poisoning cannot change a verified lock/digest;
- toolchain provenance is included in `BackendReleaseManifest`;
- compromise of a tool/version quarantines every affected manifest until
  rebuilt and reverified.

## 17. Version lifecycle and upgrade policy

| Trigger | Required action |
|---|---|
| monthly scheduled review | check runtime support, security releases and provider/CLI notes |
| Critical actively exploitable issue | freeze affected builds; patch/rebuild under emergency review |
| 180 days before Node runtime EOL | Accepted migration plan and stage compatibility evidence |
| Firebase deprecation notice | dated impact record and migration deadline |
| tool major release | no automatic adoption; compatibility branch/evidence |
| provider weekly release | do not chase latest; batch only justified changes |
| lockfile-only unexplained diff | fail and investigate |
| unsupported candidate at R0 | amend OD-01 before any scaffold is created |

An upgrade change records old/new pins, sources, breaking changes, dependency
and emulator results, generated diff, rollout, rollback and owner verdict. A
rollback cannot restore a known-vulnerable/EOL toolchain.

## 18. Failure and rollback semantics

| Failure | Required outcome |
|---|---|
| tool missing/wrong version | `toolchain_mismatch`; no build |
| lock/package mismatch | `dependency_lock_mismatch`; no install mutation |
| registry/provider unavailable | `dependency_source_unavailable`; no floating fallback |
| compiler/generator nondeterminism | `non_reproducible_build`; quarantine output |
| emulator calls non-emulated API | `emulator_isolation_breach`; fail and investigate |
| Terraform state lock unavailable | `state_lock_unavailable`; no force-unlock without incident process |
| plan changed after approval | `plan_digest_mismatch`; re-plan/review |
| CLI/provider unknown outcome | `provider_outcome_unknown`; reconcile before retry |
| tool compromise/advisory | quarantine affected manifests; patch/rebuild |
| unsupported runtime | mutations remain disabled; migration before enablement |

Toolchain rollback means restoring the previous **supported and non-vulnerable**
lock with its own green evidence. It does not roll back cloud data or bypass
schema compatibility.

## 19. Evidence matrix

| Evidence | Minimum proof | Gate |
|---|---|---|
| Version resolution | every binary/library equals lock; no global substitution | R0 |
| Clean install | two cold `npm ci` runs from clean checkout | R0 |
| TypeScript | strict compilation and negative type fixtures | R0 |
| Module system | ESM load/start in Node and Functions emulator | R0 |
| Determinism | two clean logical bundle digests reconcile | R0 |
| Cross-platform | Windows and Linux run the same script set | R0 |
| Emulator isolation | demo project, no credentials, no real endpoints | R0 |
| Contract parity | Booking fixtures and generated consumers remain equivalent | R0 |
| Terraform validation | exact CLI/provider lock, offline/backendless PR validation | R0 |
| State controls | isolated locked/versioned GCS state and WIF | R1 |
| Stage runtime | deployed metadata shows `nodejs22`; smoke/negative tests | R1/G1 |
| Release trace | manifest records source/lock/toolchain/provider revision | R1 |
| Upgrade drill | one patch/minor update and rollback rehearsal | before OD-01 Acceptance |
| Vulnerability/license | dated scan plus exception state | every build |
| Drift | declared/app/provider runtime versions reconcile | every promotion |

Every record includes UTC timestamp, commit, toolchain-lock digest, command,
environment, result, owner and limitations. Timeout or unavailable dependency is
Inconclusive, not green.

## 20. Remaining decisions

| ID | Status | Decision | Blocks |
|---|---|---|---|
| TCH-OD-01 | Proposed resolution | Eclipse Temurin 21.0.12+8; platform checksums/digests captured by R0 | emulator R0 |
| TCH-OD-02 | Proposed resolution | exact Firebase SDK/package candidate matrix in §4.2; install/peer evidence pending | R0 completion |
| TCH-OD-03 | Proposed resolution | GitHub-hosted Linux x64 authority plus Windows x64 parity; immutable build image digest recorded during R0 | reproducibility evidence |
| TCH-OD-04 | Proposed resolution | `npm ci --ignore-scripts` first; reviewed exact-package lifecycle allowlist only if compatibility proves it necessary | clean install acceptance |
| TCH-OD-05 | Proposed resolution | Prettier 3.9.6, ESLint 9.39.5/typescript-eslint 8.67.0 and built-in `node:test`; compatibility pending | R0 completion |
| TCH-OD-06 | Open | Terraform bootstrap boundary and exact remote-state topology after platform OD-07 | R1 |
| TCH-OD-07 | Open | whether any required resource truly needs `google-beta`; default is no | R1 |
| TCH-OD-08 | Open | exact release attestor/SBOM/verifier tools under BCK05-OD07-REL-01 | trusted promotion |

Proposed resolutions do not equal evidence. `TCH-OD-01..05` become resolved
only after the exact R0 checks pass. `TCH-OD-06..08` remain later Open
decisions. The runtime, language, package manager and primary CLIs/IaC path are
still concretely Proposed, not Accepted.

## 21. Acceptance and implementation sequence

```text
BCK05-OD01-TCH-01 Proposed
  -> owner/security review of dated candidate pins
  -> Approved docs/tooling-only R0 file plan
  -> create only the authorized scaffold/tool lock
  -> resolve TCH-OD-01..05
  -> clean install/build/unit/contract/emulator/determinism evidence
  -> Windows + Linux parity evidence
  -> BCK05-OD-01 Accepted
  -> reconcile IAM/release exact tool dependencies
  -> separate Approved R1 before any cloud resource or deployment
```

Acceptance of OD-01 authorizes no production deployment by itself. If R0 starts
after a support/security change, the candidate matrix is re-reviewed first.

## 22. Acceptance criteria

1. **BCK05-TCH-AC-01:** Cloud Functions 2nd gen is the selected target runtime.
2. **BCK05-TCH-AC-02:** provider runtime is explicitly `nodejs22`.
3. **BCK05-TCH-AC-03:** Node 20 is rejected because upstream support ended.
4. **BCK05-TCH-AC-04:** local/build Node has an exact point version.
5. **BCK05-TCH-AC-05:** provider-managed Node patch is not falsely equated to the build patch.
6. **BCK05-TCH-AC-06:** npm is the sole backend package manager.
7. **BCK05-TCH-AC-07:** npm and TypeScript are exact-pinned.
8. **BCK05-TCH-AC-08:** ESM/NodeNext is explicit and tested.
9. **BCK05-TCH-AC-09:** strict compiler safety flags are enabled.
10. **BCK05-TCH-AC-10:** runtime transpilation is forbidden.
11. **BCK05-TCH-AC-11:** Firebase CLI is a project dependency, not global release authority.
12. **BCK05-TCH-AC-12:** Firebase CLI version is exact-pinned.
13. **BCK05-TCH-AC-13:** Terraform CLI and Google provider are exact-pinned.
14. **BCK05-TCH-AC-14:** `google-beta` is absent by default.
15. **BCK05-TCH-AC-15:** `gcloud` has no overlapping routine deployment authority.
16. **BCK05-TCH-AC-16:** JDK is used only for local emulator components.
17. **BCK05-TCH-AC-17:** tool versions and image digests have one machine-readable record.
18. **BCK05-TCH-AC-18:** unknown toolchain-lock schema fails closed.
19. **BCK05-TCH-AC-19:** package and lockfile mismatch fails closed.
20. **BCK05-TCH-AC-20:** CI uses a frozen clean install.
21. **BCK05-TCH-AC-21:** release dependencies use no floating ranges/tags/branches.
22. **BCK05-TCH-AC-22:** lifecycle scripts follow an explicit reviewed policy.
23. **BCK05-TCH-AC-23:** cold-cache build evidence is mandatory.
24. **BCK05-TCH-AC-24:** generated outputs are deterministic and never hand-edited.
25. **BCK05-TCH-AC-25:** untracked build diff fails the gate.
26. **BCK05-TCH-AC-26:** Windows and Linux invoke the same semantic scripts.
27. **BCK05-TCH-AC-27:** locale, encoding, timezone and path behavior are deterministic.
28. **BCK05-TCH-AC-28:** emulator tests force a `demo-*` project.
29. **BCK05-TCH-AC-29:** canonical emulator tests use no cloud credential.
30. **BCK05-TCH-AC-30:** non-emulated network access fails the suite.
31. **BCK05-TCH-AC-31:** emulator success is not production evidence.
32. **BCK05-TCH-AC-32:** Terraform and Firebase CLI resource ownership do not overlap.
33. **BCK05-TCH-AC-33:** every managed resource has one desired-state writer.
34. **BCK05-TCH-AC-34:** Terraform remote state is environment-isolated.
35. **BCK05-TCH-AC-35:** remote state uses locking and recovery/versioning.
36. **BCK05-TCH-AC-36:** state, plan, credentials and sensitive variables are never committed.
37. **BCK05-TCH-AC-37:** reviewed saved plan and applied plan digests match.
38. **BCK05-TCH-AC-38:** force-unlock and targeted apply are exceptional, audited actions.
39. **BCK05-TCH-AC-39:** `firebase.json` and package runtime declarations agree.
40. **BCK05-TCH-AC-40:** provider external changes are not silently preserved.
41. **BCK05-TCH-AC-41:** production deploy is manifest-derived and non-interactive.
42. **BCK05-TCH-AC-42:** reproducibility evidence binds source, lock and toolchain digests.
43. **BCK05-TCH-AC-43:** SBOM/provenance subjects match the release manifest.
44. **BCK05-TCH-AC-44:** compromised toolchain inputs quarantine affected releases.
45. **BCK05-TCH-AC-45:** upgrades require compatibility, security and rollback evidence.
46. **BCK05-TCH-AC-46:** unsupported/EOL runtime blocks activation.
47. **BCK05-TCH-AC-47:** unknown provider outcome requires reconciliation before retry.
48. **BCK05-TCH-AC-48:** Inconclusive tooling evidence is never Pass.
49. **BCK05-TCH-AC-49:** Proposed status creates no backend file, resource or dependency.
50. **BCK05-TCH-AC-50:** runtime requires a separate Approved executable slice.
51. **BCK05-TCH-AC-51:** R0 admits only the three full-SHA Actions in §4.3.
52. **BCK05-TCH-AC-52:** checkout credential/clean/global edits and automatic package caching are disabled.
53. **BCK05-TCH-AC-53:** floating hosted-runner labels are forbidden.
54. **BCK05-TCH-AC-54:** resolved hosted-runner image versions are evidence, not hidden inputs.
55. **BCK05-TCH-AC-55:** R0 Terraform is installed from the signed official archive, not a GitHub Action.
56. **BCK05-TCH-AC-56:** Terraform Linux/Windows archive checksums are exact and fail closed.

---

**Current conclusion:** the primary backend toolchain now has a concrete,
locally and hosted-executed R0 scaffold. R0 is **Pass — bounded tooling
feasibility only**, with `BCK-R0-TCH-ADV-01` controls expiring on `2026-09-24`
or before scope expansion. `BCK05-OD-01` remains **Proposed**, not Accepted.
Product backend behavior, cloud state, credentials and deployment remain
absent and unauthorized.
