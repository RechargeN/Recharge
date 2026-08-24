# Recharge Backend — Runtime & Toolchain Technical Review

- ID: **BCK05-OD01-TCH-REV-01**
- Version: **0.2.2**
- Date: **2026-08-24**
- Status: **Draft technical review — local/hosted evidence present; advisory verdict pending**
- Reviewed artifact: [BCK05-OD01-TCH-01 v0.3.2](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md)
- Parent: [BCK-05 v0.2.14](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Executed slice: [BCK-R0-TCH-01 v0.2.1](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md) (Amendments Required)
- Approval record: [BCK-R0-TCH-DEC-01 v0.1](BACKEND_R0_APPROVAL_DECISION_RECORD.md)
- Runtime status: **Local R0 tooling scaffold Present; product/cloud runtime Absent**
- Review author role: **technical pre-review; not Platform Operations or Platform Security sign-off**
- Runtime effect: **none**

---

## 0. Changelog

### v0.2.2 — 2026-08-24

- recorded successful hosted R0 parity on `ubuntu-24.04` and `windows-2025` in
  draft PR #7, run `32684234236`;
- closed Windows setup-java, MSYS-GPG/tar path and checkout-EOL defects without
  weakening signature, checksum or formatting gates;
- retained only the explicit Moderate transitive-advisory disposition as the
  R0 Pass blocker.

### v0.2.1 — 2026-08-24

- linked the completed local R0 evidence rather than claiming the plan remains
  unexecuted;
- retained the review blocker for hosted Windows/Linux parity and the explicit
  disposition of Moderate transitive advisories;
- preserved the no-cloud/no-product boundary.

### v0.2 — 2026-08-23

- verified latest official action releases, tag commit SHAs, action runtimes
  and commit-verification state;
- admitted three verified full-SHA Actions and rejected the unsigned reviewed
  `hashicorp/setup-terraform` commit;
- selected direct signed/checksummed Terraform 1.15.9 archives and explicit
  non-floating Windows/Linux runner labels;
- retained owner/security/architecture verdicts and runtime as pending/Absent.

### v0.1 — 2026-08-23

- reviewed the base runtime/package/JDK/Firebase/Terraform candidate.

## 1. Verdict

**Technical verdict: Amendments Required.**

The v0.3.2 candidate completed the bounded local and hosted R0 feasibility
matrix. Exact install, peer/engine resolution, compilation, tests, emulators,
default-deny Rules, reproducibility and backendless Terraform validation passed
on both supported hosted runner labels.

This verdict does **not** accept `BCK05-OD-01` because the dated Moderate
transitive-advisory disposition is unresolved. Therefore:

- `BCK05-OD-01` remains **Proposed**;
- BCK-05 remains **Draft**;
- R0 remains **Amendments Required**, although its bounded slice is Approved
  and executed;
- G1/R1, Firebase projects, billing, credentials and deployment remain blocked.

## 2. Review scope

The pre-review covers:

- provider support and upstream lifecycle;
- exact candidate version logic;
- language/module/package-manager coherence;
- dependency minimization and supply-chain exposure;
- local emulator isolation;
- Terraform/Firebase CLI/`gcloud` writer boundaries;
- cross-platform and reproducibility requirements;
- the exact evidence needed for Acceptance.

It excludes:

- actual install/build/emulator execution;
- cloud project, region, edition, IAM or billing decisions;
- domain/backend implementation;
- legal/privacy/finance conclusions;
- production release approval.

## 3. Sources revalidated on 2026-08-23

| Source | Revalidated fact | Result |
|---|---|---|
| [Firebase runtime management](https://firebase.google.com/docs/functions/manage-functions) | Node.js 22 and ESM are supported; runtime declaration precedence is documented. | Pass |
| [Node.js 22 archive](https://nodejs.org/en/download/archive/v22) | 22.23.2 with npm 10.9.8 remains the latest reviewed Node 22 patch. | Pass |
| [Firebase CLI releases](https://github.com/firebase/firebase-tools/releases) | 15.28.1 remains the latest stable release; preview SEA builds are excluded. | Pass |
| [Terraform 1.15.9](https://github.com/hashicorp/terraform/releases/tag/v1.15.9) | 1.15.9 is the latest stable release at the review time. | Pass |
| [Checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) | security/escaping fixes are present; tag resolves to the reviewed SHA. | Candidate accepted for manifest |
| [Setup Node v7.0.0](https://github.com/actions/setup-node/releases/tag/v7.0.0) | ESM/current dependencies; automatic cache must be disabled for R0. | Candidate accepted for manifest |
| [Setup Java v5.7.0](https://github.com/actions/setup-java/releases/tag/v5.7.0) | current v5 fixes; signature-verification input is available. | Candidate accepted for manifest |
| [GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | explicit `ubuntu-24.04` and `windows-2025` x64 labels are supported. | Select explicit labels; record resolved image |
| [HashiCorp archive verification](https://developer.hashicorp.com/terraform/tutorials/cli/verify-archive) | signed checksum-manifest verification is the supported archive path. | Prefer direct verified archive over unsigned setup action commit |
| [Firebase Functions package](https://www.npmjs.com/package/firebase-functions) | 7.3.2 is the current stable Functions SDK package. | Candidate |
| [Firebase Admin package](https://www.npmjs.com/package/firebase-admin) | 14.3.0 is the current stable Admin SDK package. | Candidate |
| [ESLint package](https://www.npmjs.com/package/eslint) | 9.39.5 is maintained; 10.8.1 is a newer major. | Select maintained 9.x pending compatibility |
| [typescript-eslint package](https://www.npmjs.com/package/typescript-eslint) | 8.67.0 is the current stable lint integration. | Candidate |
| [Prettier package](https://www.npmjs.com/package/prettier) | 3.9.6 is the current stable formatter candidate. | Candidate |
| [Temurin support](https://adoptium.net/support/) | JDK 21 is LTS; 21.0.12+8 is the current reviewed release. | Candidate |

Registry freshness is not compatibility proof. R0 must resolve exact package
metadata from the committed lock and retain the registry-integrity hashes.

## 4. Findings

| ID | Severity | Finding | Required treatment |
|---|---|---|---|
| TCH-TR-01 | Required | Firebase still lists Node 20, but upstream Node 20 is EOL. | Keep Node 22; no compatibility fallback to Node 20. |
| TCH-TR-02 | Required | Cloud Functions accepts a runtime major, not the local 22.23.2 patch. | Record provider runtime/revision separately; never claim patch identity. |
| TCH-TR-03 | Required | TypeScript 6.0.3 is an intentional compatibility baseline, not the newest compiler generation. | Prove SDK/linter/type compatibility; upgrade only through a separate evidence change. |
| TCH-TR-04 | Required | ESLint 10 is newer, but adopting a fresh major adds avoidable peer/config risk. | Use maintained 9.39.5 for R0; reconsider after a green isolated compatibility trial. |
| TCH-TR-05 | Resolved for bounded R0 | Exact npm peer/engine and lifecycle behavior was observed locally and on both hosted legs with scripts disabled; three hooks remain non-indispensable for R0. | Keep lifecycle scripts disabled. |
| TCH-TR-06 | Resolved for bounded R0 | Exact Temurin 21.0.12+8 archive evidence was verified; both hosted legs passed using the platform-specific setup-java selector for the same build. | Preserve the recorded hosted run and revalidate on pin changes. |
| TCH-TR-07 | Required | A globally installed Firebase CLI could shadow the project pin. | Invoke project-local CLI and assert its version before every command. |
| TCH-TR-08 | Improvement | Jest/Vitest would add dependency and transform complexity without R0 value. | Use compiled tests with built-in `node:test` and built-in coverage. |
| TCH-TR-09 | Required | Terraform releases can advance between review passes. | Pin stable 1.15.9; reject silent upgrades and alpha/beta/RC inputs. |
| TCH-TR-10 | Required | Multiple tools can mutate overlapping Google/Firebase resources. | Preserve one-writer matrix; `gcloud` is inspection/bootstrap exception only. |
| TCH-TR-11 | Resolved for bounded R0 | Demo-only project identity, loopback hosts, absent credential variables, live probe and default-deny client tests passed locally and on both hosted legs. | This remains non-production evidence. |
| TCH-TR-12 | Process | A local scaffold could be misread as product/backend authorization. | State tooling scaffold Present separately from product/cloud runtime Absent in every parent ledger and LAUNCH_STATUS. |
| TCH-TR-16 | Blocking R0 Pass | Dated audit reports 7 production / 10 total Moderate transitive advisories while direct Firebase pins remain latest. | Obtain an explicit Moderate-risk disposition or replace with clean supported upstream releases; never force/downgrade silently. |
| TCH-TR-13 | Blocking Approval | Reviewed `hashicorp/setup-terraform` v4.0.1 resolves to an unsigned commit and exposes unused credential inputs. | Exclude it; install exact official Terraform archives after signature and SHA verification. |
| TCH-TR-14 | Required | GitHub hosted OS labels do not freeze the underlying weekly image. | Use explicit OS labels and record resolved runner/image versions; claim semantic parity only. |
| TCH-TR-15 | Required | setup-node can automatically enable dependency caching. | Set `package-manager-cache: false`; R0 proves cold locked installs. |

No contradiction with Accepted ADR 0019 was found. The R0 target remains one
bounded scaffold under `apps/backend`; infrastructure files stay nested there
and do not create a second top-level backend application.

## 5. Candidate dependency decision

Recommended exact R0 manifest:

```json
{
  "dependencies": {
    "firebase-admin": "14.3.0",
    "firebase-functions": "7.3.2"
  },
  "devDependencies": {
    "@types/node": "22.20.1",
    "eslint": "9.39.5",
    "firebase-tools": "15.28.1",
    "prettier": "3.9.6",
    "typescript": "6.0.3",
    "typescript-eslint": "8.67.0"
  }
}
```

This fragment became the Approved R0 manifest. The generated
`package-lock.json` is authoritative for all transitive versions and integrity
hashes; it provides no production deployment authority.

Explicitly excluded from R0:

- Jest, Vitest, ts-node, tsx and Babel;
- Express/Nest/Fastify or another server framework;
- bundlers such as esbuild/webpack/rollup;
- production telemetry SDKs;
- schema/code generators not required for the existing Booking fixture parity;
- any domain implementation dependency.

### 5.1 CI dependency disposition

| Dependency | Exact immutable identity | Verification | Disposition |
|---|---|---|---|
| `actions/checkout` v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | GitHub commit verification `valid`; Node 24 runtime inspected | Allow with `persist-credentials: false` |
| `actions/setup-node` v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` | GitHub commit verification `valid`; Node 24 runtime inspected | Allow with automatic cache disabled |
| `actions/setup-java` v5.7.0 | `b6effb05e454b25005698d916606bdc6ffcbf961` | GitHub commit verification `valid`; Node 24 runtime inspected | Allow with exact Temurin build and signature verification |
| `hashicorp/setup-terraform` v4.0.1 | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | GitHub commit verification reports `unsigned` | Reject from R0 |

Terraform replacement:

- version: 1.15.9;
- Linux x64 SHA-256:
  `76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1`;
- Windows x64 SHA-256:
  `b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6`;
- download source: `releases.hashicorp.com` only;
- detached checksum-manifest signature and selected archive SHA both verify
  before extraction;
- no HashiCorp/HCP credential, wrapper or mirror is configured.

The local and hosted results establish bounded toolchain compatibility on
Windows and Linux, not production compatibility. Every identity is rechecked
before execution; a moved/deleted tag, verification regression or digest
mismatch blocks the run.

## 6. Proposed disposition of TCH decisions

| Decision | Technical recommendation | Owner status before evidence |
|---|---|---|
| TCH-OD-01 | Temurin 21.0.12+8; exact platform checksum/digest in R0 | Proposed resolution |
| TCH-OD-02 | use the exact package matrix in §5 | Proposed resolution |
| TCH-OD-03 | Linux x64 CI authority plus Windows x64 parity | Proposed resolution |
| TCH-OD-04 | install with scripts disabled; allow only proven indispensable exact-package scripts | Proposed resolution |
| TCH-OD-05 | Prettier + ESLint/typescript-eslint + built-in `node:test` | Proposed resolution |
| TCH-OD-06 | defer state topology to accepted platform OD-07/R1 | Open, correctly deferred |
| TCH-OD-07 | no `google-beta`; require separate evidence if a resource forces it | Open, fail-closed default fixed |
| TCH-OD-08 | defer attestor/SBOM/verifier selection to BCK05-OD07-REL-01 | Open, correctly deferred |

Owner acceptance of the recommendation records a decision; only R0 evidence
resolves `TCH-OD-01..05` and permits `BCK05-OD-01` Acceptance.

## 7. R0 authorization boundary

An Approved R0 slice may only:

- create the exact local scaffold named in BCK-R0-TCH-01;
- install locked public packages without credentials;
- compile/lint/format/test locally;
- execute Firebase emulators against `demo-recharge`;
- validate Terraform with `-backend=false` and no provider credentials;
- generate bounded non-secret evidence.

It may not:

- authenticate to Firebase/Google;
- create/select a real Firebase project;
- enable an API or billing;
- deploy or apply Terraform;
- add OIDC, service accounts, secrets or `.firebaserc`;
- modify Flutter/mobile/Create/Event runtime;
- implement Booking or another product capability.

Any command asking for login, project creation, billing, ADC or deployment is
an unexpected boundary violation and stops the slice.

## 8. Required R0 evidence

| Evidence ID | Required result |
|---|---|
| TCH-EV-01 | exact version/checksum resolution for Node, npm, JDK and CLIs |
| TCH-EV-02 | two clean installs from the same package/lock with no drift |
| TCH-EV-03 | peer/engine compatibility report with zero unsupported combination |
| TCH-EV-04 | lifecycle-script inventory and deny/allow evidence |
| TCH-EV-05 | strict TypeScript/ESM compile and load |
| TCH-EV-06 | lint/format and negative fixture result |
| TCH-EV-07 | built-in unit/contract test and coverage result |
| TCH-EV-08 | isolated emulator test with no credential or real API access |
| TCH-EV-09 | Windows x64 and Linux x64 semantic parity |
| TCH-EV-10 | two clean logical output digests reconcile |
| TCH-EV-11 | Terraform fmt/init-backendless/validate without credential |
| TCH-EV-12 | no non-document/runtime changes outside the Approved R0 map |
| TCH-EV-13 | exact GitHub Action SHA, verification state and action runtime revalidated |
| TCH-EV-14 | resolved hosted-runner/image versions recorded for both matrix legs |
| TCH-EV-15 | Terraform checksum signature and platform archive SHA verified before extraction |

Timeout, dependency-source outage or a test that did not execute is
**Inconclusive**, never Pass.

## 9. Review and sign-off record

| Role | Required verdict | Current state |
|---|---|---|
| Technical pre-review | Pass / amendments / fail | Amendments required after local and hosted execution: advisory disposition only |
| Platform Operations owner | Accept / amendments / reject | Accepted for bounded R0 bootstrap; OD-01 not accepted |
| Platform Security owner | Accept / amendments / reject | Accepted for bounded local R0 bootstrap; independent production review absent |
| Architecture owner | confirms ADR/file-map boundary | Accepted for exact v0.2 map only |
| Product owner | approves bounded R0 scope | Approved 2026-08-24 |

No cell may be filled automatically from the existence of this document.

## 10. Acceptance criteria

1. **BCK05-TCH-REV-AC-01:** review identifies the exact artifact version.
2. **BCK05-TCH-REV-AC-02:** official sources are dated and current.
3. **BCK05-TCH-REV-AC-03:** registry freshness is not compatibility evidence.
4. **BCK05-TCH-REV-AC-04:** Node 22 remains the only runtime candidate.
5. **BCK05-TCH-REV-AC-05:** cloud and build patch identity are separated.
6. **BCK05-TCH-REV-AC-06:** stable tools are selected over prereleases.
7. **BCK05-TCH-REV-AC-07:** exact direct dependency candidates are listed.
8. **BCK05-TCH-REV-AC-08:** transitive dependencies remain lockfile-owned.
9. **BCK05-TCH-REV-AC-09:** TypeScript 6 is identified as a compatibility choice.
10. **BCK05-TCH-REV-AC-10:** ESLint 9 is identified as a maintained compatibility choice.
11. **BCK05-TCH-REV-AC-11:** no extra test framework is admitted.
12. **BCK05-TCH-REV-AC-12:** no runtime transpiler is admitted.
13. **BCK05-TCH-REV-AC-13:** no server framework is admitted.
14. **BCK05-TCH-REV-AC-14:** Firebase CLI is project-local.
15. **BCK05-TCH-REV-AC-15:** JDK distribution and build are explicit.
16. **BCK05-TCH-REV-AC-16:** platform checksums/digests remain mandatory.
17. **BCK05-TCH-REV-AC-17:** lifecycle scripts start disabled.
18. **BCK05-TCH-REV-AC-18:** lifecycle exceptions are exact and evidenced.
19. **BCK05-TCH-REV-AC-19:** peer/engine mismatch blocks R0.
20. **BCK05-TCH-REV-AC-20:** emulator project identity is `demo-*` only.
21. **BCK05-TCH-REV-AC-21:** canonical R0 uses no cloud credential.
22. **BCK05-TCH-REV-AC-22:** non-emulated egress is a failure.
23. **BCK05-TCH-REV-AC-23:** Windows/Linux parity is required.
24. **BCK05-TCH-REV-AC-24:** reproducibility uses two clean builds.
25. **BCK05-TCH-REV-AC-25:** Terraform validation is backendless in R0.
26. **BCK05-TCH-REV-AC-26:** Terraform apply is forbidden in R0.
27. **BCK05-TCH-REV-AC-27:** `gcloud` has no routine writer authority.
28. **BCK05-TCH-REV-AC-28:** R0 creates no project, API or billing link.
29. **BCK05-TCH-REV-AC-29:** R0 creates no identity, secret or OIDC trust.
30. **BCK05-TCH-REV-AC-30:** R0 changes no mobile/Create/Event runtime.
31. **BCK05-TCH-REV-AC-31:** R0 implements no domain capability.
32. **BCK05-TCH-REV-AC-32:** unexpected login/deploy prompt stops the slice.
33. **BCK05-TCH-REV-AC-33:** all evidence has exact command and result.
34. **BCK05-TCH-REV-AC-34:** Inconclusive is never Pass.
35. **BCK05-TCH-REV-AC-35:** technical review is not owner sign-off.
36. **BCK05-TCH-REV-AC-36:** proposed resolution is not resolved evidence.
37. **BCK05-TCH-REV-AC-37:** OD-01 remains Proposed before R0 evidence.
38. **BCK05-TCH-REV-AC-38:** BCK-05 remains Draft.
39. **BCK05-TCH-REV-AC-39:** document existence creates no runtime authority.
40. **BCK05-TCH-REV-AC-40:** physical work requires explicit R0 Approval.
41. **BCK05-TCH-REV-AC-41:** every admitted Action has an exact verified full SHA.
42. **BCK05-TCH-REV-AC-42:** the unsigned reviewed Terraform Action is rejected.
43. **BCK05-TCH-REV-AC-43:** Terraform uses a signed official checksum manifest.
44. **BCK05-TCH-REV-AC-44:** both supported Terraform archives have exact SHA-256 pins.
45. **BCK05-TCH-REV-AC-45:** automatic dependency caching is disabled for R0.
46. **BCK05-TCH-REV-AC-46:** runner labels are explicit and non-preview.
47. **BCK05-TCH-REV-AC-47:** resolved runner/image versions remain evidence inputs.
48. **BCK05-TCH-REV-AC-48:** supply-chain identity is revalidated immediately before execution.

---

**Conclusion:** the bounded local and hosted implementation is technically
operational. Hosted Windows/Linux parity is Pass. R0 Pass remains blocked by
the explicit Moderate-advisory disposition. BCK05-OD-01 remains Proposed;
product/cloud runtime, credentials and deployment remain absent.
