# Recharge Backend — R0 Approval Decision Record

- ID: **BCK-R0-TCH-DEC-01**
- Version: **0.2**
- Date: **2026-08-24**
- Status: **Approved — bounded R0 v0.2 execution and time-bounded advisory disposition only**
- Runtime status: **R0 tooling feasibility Pass; product/cloud runtime remains Absent**
- Original execution target: [BCK-R0-TCH-01 v0.2](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md)
- Current status reconciliation: [BCK-R0-TCH-01 v0.2.2](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md)
- Advisory evidence reviewed: BCK05-OD01-TCH-01 v0.3.2,
  BCK05-OD01-TCH-REV-01 v0.2.2 and the completed R0 result
- Current toolchain record: [BCK05-OD01-TCH-01 v0.3.3](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md)
- Current technical review: [BCK05-OD01-TCH-REV-01 v0.2.3](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md)
- Parent operations spec: [BCK-05 v0.2.15](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Architecture authority: [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md)
- Accountable approver: **RechargeN / Product owner acting as combined Platform coordinator**
- Required boundary reviewers: **Platform Operations, Platform Security, Architecture**
- Runtime effect: **none**

---

## 0. Recorded decision

The Product owner responded `одобряю` on 2026-08-24 directly to the immediately
preceding exact request to approve bounded `BCK-R0-TCH-01 v0.2` under this
record and accept the disclosed combined-role bootstrap risk. The approval is
therefore recorded only for that exact scope; it is not generic backend,
Firebase, cloud, domain, deployment or production authorization.

| Field | Recorded value |
|---|---|
| Decision | **Approve bounded R0 v0.2** |
| Owner identity / actual role | `RechargeN / Product owner`; combined Platform coordinator |
| Accepted scope | exact paths, commands, evidence and rollback in BCK-R0-TCH-01 v0.2 |
| Explicit exclusions | mobile, product/domain behavior, real Firebase/Google project, credentials, IAM, billing, deploy, Terraform plan/apply and production data |
| Combined-role risk | accepted for local/tooling R0 bootstrap; no independent production review claimed |
| Blocking amendments | none before scaffold creation; execution stop conditions remain binding |
| Rollback owner | `RechargeN / Product owner`; exact R0-owned paths only |
| Base commit | `a6b04cbb079c330dd9ddc23d17ac42f9d31669e5` |
| Execution branch | `codex/backend-r0-toolchain` |
| Signature evidence | owner reply in the controlling Codex task |
| Signed UTC | `2026-08-23T23:43:37Z` |

### 0.1 BCK-R0-TCH-ADV-01 — residual advisory disposition

The Product owner explicitly responded `Одобряю BCK-R0-TCH-ADV-01` on
2026-08-24 after receiving the dated dependency audit, reachable-path
assessment, rejected unsafe remediation options and the exact bounded-risk
request. This records **Accept with controls** for the residual npm advisory
risk in R0 only.

| Field | Recorded value |
|---|---|
| Decision ID | `BCK-R0-TCH-ADV-01` |
| Verdict | **Accept with controls** |
| Risk owner | `RechargeN / Product owner acting as combined Platform coordinator` |
| Scope | bounded, demo-only R0 toolchain/emulator scaffold on the existing local and hosted test paths |
| Root advisories | `GHSA-w5hq-g745-h8pq` / `CVE-2026-41907`; `GHSA-8988-4f7v-96qf` / `CVE-2026-54285` |
| Audit effect chains | production graph: 7 Moderate; complete graph: 10 Moderate; 0 High and 0 Critical in both |
| Residual-risk rating | **Low for the bounded R0 context only**; not a rating for stage, production or a public backend |
| Validity | through `2026-09-24`, or until immediately before R1/G1 or any real cloud/public-ingress work, whichever occurs first |
| Signature evidence | exact owner reply `Одобряю BCK-R0-TCH-ADV-01` in the controlling Codex task |
| Signed UTC | `2026-08-24T10:49:37Z` |

The acceptance is valid only while all controls below remain true:

1. R0 stays demo-only, loopback-only and isolated from public ingress.
2. No real Firebase/Google project, credential, identity, billing link,
   deployment, personal data or production-derived data enters the slice.
3. Dependency lifecycle scripts remain disabled and no forced downgrade,
   unsupported override or peer/engine bypass is introduced.
4. CI continues to fail on any High or Critical advisory and retains both
   production-graph and complete-graph audit evidence.
5. The audit and reachable-path assessment are repeated on every direct-pin or
   lockfile change and before expiry, R1/G1 or any scope expansion.

The disposition expires immediately if severity rises to High/Critical, an
affected path becomes reachable, a listener becomes public/non-loopback, a
cloud credential/project or non-demo data is introduced, the dependency graph
changes without reassessment, or the validity deadline is reached. Expiry
returns R0 to `Amendments Required`; it never silently renews.

This decision closes the final bounded R0 evidence blocker and permits the R0
result to be recorded as **Pass — bounded tooling feasibility only**. It does
not accept `BCK05-OD-01`, approve BCK-05, start R1/G1, or authorize a cloud or
product backend.

## 1. Purpose

This is the single formal record for deciding whether the exact
`BCK-R0-TCH-01 v0.2` documentation/tooling-only slice may be executed.

It does not itself approve R0. It binds the proposed scope, immutable CI
dependencies, security inputs, exclusions, rollback and evidence obligations
so that a later owner verdict cannot silently authorize broader backend work.

## 2. Decision requested

The accountable owner chooses exactly one verdict:

| Verdict | Meaning |
|---|---|
| `Approve bounded R0 v0.2` | authorize only the physical paths and commands in the exact slice version after all §9 preconditions are satisfied |
| `Approve with amendments` | no execution until every named blocking amendment is incorporated into a new exact version and re-reviewed |
| `Reject` | R0 does not execute; owner records reason and replacement path |
| `Inconclusive` | authority or evidence is insufficient; never treated as Approval |

Silence, “дальше”, general backend authorization or acceptance of this
document is not `Approve bounded R0 v0.2`.

## 3. Technical recommendation

**Recommendation: Approve only after the four named role verdicts in §8 are
explicitly recorded.**

The proposed slice is narrow enough for stabilization because it creates only
a local emulator/toolchain feasibility scaffold, touches no mobile runtime,
processes no personal data, creates no cloud resource and cannot deploy.

The recommendation is conditional. Actual npm compatibility, lifecycle
behavior, emulator isolation, runner parity and Terraform validation remain
unknown until R0 executes. Those unknowns are the purpose of R0 and must be
reported as Passed, Failed or Inconclusive without relaxing the boundary.

## 4. Immutable GitHub Actions manifest

Only these `uses:` identities are allowed:

| Repository | Informational release | Required full commit SHA | Upstream verification observed 2026-08-23 | Required R0 inputs |
|---|---:|---|---|---|
| [`actions/checkout`](https://github.com/actions/checkout) | [`v7.0.1`](https://github.com/actions/checkout/releases/tag/v7.0.1) | [`3d3c42e5aac5ba805825da76410c181273ba90b1`](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1) | `verified=true`, reason `valid`; Node 24 runtime | no persisted credentials, clean/reset or global safe-directory edit; shallow source only; no tags/LFS/submodules |
| [`actions/setup-node`](https://github.com/actions/setup-node) | [`v7.0.0`](https://github.com/actions/setup-node/releases/tag/v7.0.0) | [`820762786026740c76f36085b0efc47a31fe5020`](https://github.com/actions/setup-node/commit/820762786026740c76f36085b0efc47a31fe5020) | `verified=true`, reason `valid`; Node 24 runtime | Node 22.23.2; no latest check, automatic cache, registry or mirror override |
| [`actions/setup-java`](https://github.com/actions/setup-java) | [`v5.7.0`](https://github.com/actions/setup-java/releases/tag/v5.7.0) | [`b6effb05e454b25005698d916606bdc6ffcbf961`](https://github.com/actions/setup-java/commit/b6effb05e454b25005698d916606bdc6ffcbf961) | `verified=true`, reason `valid`; Node 24 runtime | Temurin 21.0.12+8; signature verification; no cache/publishing/private key/Maven settings overwrite |

Tags are explanatory only. Workflow authority is the complete 40-character
SHA. The workflow contains no other local, Docker or Marketplace action.

Before execution, the reviewer repeats official repository tag-to-SHA,
commit-verification and `action.yml` runtime inspection. Any mismatch,
revocation, unsupported runner runtime or unexplained source change blocks R0.

## 5. Rejected Action and Terraform replacement

[`hashicorp/setup-terraform@v4.0.1`](https://github.com/hashicorp/setup-terraform/releases/tag/v4.0.1)
is explicitly rejected from R0:

- its reviewed tag resolves to
  `dfe3c3f87815947d99a8997f908cb6525fc44e9e`;
- GitHub commit verification reported `verified=false`, reason `unsigned`;
- it exposes optional HCP/Terraform Enterprise credential inputs that this
  credential-free feasibility slice does not need;
- adding it would enlarge supply-chain and configuration surface without
  providing a necessary capability.

[Terraform 1.15.9](https://github.com/hashicorp/terraform/releases/tag/v1.15.9)
is installed by repository-owned cross-platform Node logic from
`https://releases.hashicorp.com/terraform/1.15.9/` only, following the
[official archive-verification procedure](https://developer.hashicorp.com/terraform/tutorials/cli/verify-archive).

| Archive | Required SHA-256 |
|---|---|
| `terraform_1.15.9_linux_amd64.zip` | `76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1` |
| `terraform_1.15.9_windows_amd64.zip` | `b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6` |

The installer verifies the official detached signature over
`terraform_1.15.9_SHA256SUMS`, the exact archive name/SHA and the extracted
version before the binary enters `PATH`. It accepts no mirror, package-manager
substitution, wrapper, credential or floating version. Verification tooling
unavailable means Inconclusive, not checksum bypass.

## 6. Runner and workflow decision

| Field | Exact R0 value |
|---|---|
| Linux runner | `ubuntu-24.04` x64 |
| Windows runner | `windows-2025` x64 |
| Floating/preview labels | forbidden |
| Workflow permission | `contents: read` only |
| OIDC | absent; no `id-token: write` |
| Environments/secrets | absent |
| Dependency cache | disabled |
| Artifact uploads | absent |
| Cloud login/deploy | absent and denied |
| Job timeout | bounded in workflow; timeout is Inconclusive/Failed |
| Evidence persistence | sanitized step summary plus repository result record after review |

GitHub-hosted images are not immutable. Each matrix leg records Actions runner
version, `ImageOS` and `ImageVersion`. R0 requires semantic equality of tests
and logical outputs; it does not claim byte-identical operating systems.

## 7. Architecture and scope assessment

| Check | Technical assessment | Formal verdict |
|---|---|---|
| single backend target | all proposed runtime paths live under `apps/backend`; no competing backend app | Architecture owner Pending |
| mobile boundary | `apps/mobile`, packages, Create Hub and EventCreateBlock excluded | Architecture owner Pending |
| domain boundary | probe has no Recharge domain behavior or persistence | Architecture owner Pending |
| cloud boundary | no project, Auth, IAM, API, billing, state, resource or deployment | Security/Operations Pending |
| data/privacy boundary | demo fixtures only; no personal/production-derived data | Security Pending |
| credential boundary | no ADC, service account, secret, WIF, login or token input | Security Pending |
| rollback boundary | only exact R0-owned paths; no reset-hard or broad deletion | Operations Pending |

This assessment found no contradiction with Accepted ADR 0019. It is a
technical statement, not an owner signature.

## 8. Required verdict record

| Role | Named reviewer | Required scope | Verdict | Signed UTC |
|---|---|---|---|---|
| Product/Platform owner | `RechargeN / Product owner` | exact v0.2 scope and stabilization exception | Accept bounded R0 v0.2 | `2026-08-23T23:43:37Z` |
| Platform Operations | `RechargeN / combined-role bootstrap owner` | tool lifecycle, runners, evidence, rollback | Accept for local R0 bootstrap | `2026-08-23T23:43:37Z` |
| Platform Security | `RechargeN / combined-role bootstrap owner` | action SHA, egress, credentials, signatures, cache | Accept with all fail-closed controls retained; independent review absent | `2026-08-23T23:43:37Z` |
| Architecture | `RechargeN / combined-role bootstrap owner` | ADR 0019 and exhaustive file map | Accept exact v0.2 file-map boundary | `2026-08-23T23:43:37Z` |

Combined-role concentration and absence of independent security review are
disclosed, not hidden. The owner may accept that bootstrap risk for local R0,
but this does not satisfy future production independence or Legal/Privacy
review gates.

## 9. Approval preconditions

All must be true before the first physical file is created:

1. exact `BCK-R0-TCH-01 v0.2` approval statement is recorded in §10;
2. all four §8 verdicts are non-Pending and none is Reject/Inconclusive;
3. latest source/security recheck finds no unsupported or compromised pin;
4. the three action SHAs and inputs still match §4;
5. Terraform signed checksum manifest and both selected SHAs still match §5;
6. exact base commit and pre-existing dirty paths are recorded;
7. execution occurs in an isolated branch/worktree without staging unrelated
   user changes;
8. no cloud credential, Firebase alias, OIDC permission or real project is
   exposed;
9. rollback owner and result-record path are assigned;
10. any requested path/command outside R0 is rejected and escalated as a new
    slice, not inferred from Approval.

## 10. Approval statement

The effective owner decision must use this complete form:

```text
Decision: Approve bounded R0 v0.2 | Approve with amendments | Reject | Inconclusive
Owner identity and actual role:
Reviewed artifacts: BCK-R0-TCH-01 v0.2; BCK05-OD01-TCH-01 v0.3;
  BCK05-OD01-TCH-REV-01 v0.2; BCK-R0-TCH-DEC-01 v0.1
Accepted scope and explicit exclusions:
Security/Operations/Architecture verdict references:
Blocking amendments, if any:
Rollback owner:
Base commit or rule for selecting it:
Signature and UTC date:
```

A version change after signature invalidates Approval unless a new bounded
diff acceptance explicitly names both versions.

## 11. Post-approval execution stop conditions

Execution stops without improvisation if:

- an action SHA, signature, checksum or version does not match;
- package peers/engines require force, legacy-peer-deps or a floating upgrade;
- an unreviewed lifecycle script is necessary;
- a real project/credential/metadata server/cloud endpoint is selected;
- any command requests login, billing, API enablement, deploy, plan or apply;
- emulator isolation is not provable;
- a new file falls outside the exhaustive map;
- user-owned dirty work overlaps a target;
- Windows/Linux results differ without an explained, accepted platform field;
- evidence cannot distinguish Failed from Inconclusive.

## 12. Result and status rule

If executed, R0 result is one of:

- `Passed`: every R0 AC and evidence item passed;
- `Failed`: a deterministic requirement failed;
- `Inconclusive`: the required check did not complete or authority/evidence was
  insufficient;
- `Rolled back`: exact R0-owned physical changes were removed after a recorded
  stop decision.

Even `Passed` does not mean the Recharge backend exists as a product backend.
It proves only local toolchain/emulator feasibility. `BCK05-OD-01` still needs
a separate Accepted owner decision; R1/G1 and all cloud work remain blocked.

## 13. Acceptance criteria

1. **BCK-R0-DEC-AC-01:** this record names one exact R0 version.
2. **BCK-R0-DEC-AC-02:** document existence is not Approval.
3. **BCK-R0-DEC-AC-03:** generic continuation language is not Approval.
4. **BCK-R0-DEC-AC-04:** four explicit role verdicts are required.
5. **BCK-R0-DEC-AC-05:** combined-role risk is disclosed.
6. **BCK-R0-DEC-AC-06:** independent production review is not falsely claimed.
7. **BCK-R0-DEC-AC-07:** exactly three external Actions are allowed.
8. **BCK-R0-DEC-AC-08:** every allowed Action uses a full commit SHA.
9. **BCK-R0-DEC-AC-09:** tag labels have no execution authority.
10. **BCK-R0-DEC-AC-10:** action commit verification is rechecked before run.
11. **BCK-R0-DEC-AC-11:** checkout persists no credential and performs no clean/reset or global safe-directory edit.
12. **BCK-R0-DEC-AC-12:** automatic dependency caching is disabled.
13. **BCK-R0-DEC-AC-13:** no action receives publishing/cloud credentials.
14. **BCK-R0-DEC-AC-14:** the reviewed unsigned Terraform Action is rejected.
15. **BCK-R0-DEC-AC-15:** Terraform comes only from the official release host.
16. **BCK-R0-DEC-AC-16:** Terraform checksum-manifest signature is mandatory.
17. **BCK-R0-DEC-AC-17:** Linux and Windows Terraform SHAs are exact.
18. **BCK-R0-DEC-AC-18:** signature/checksum mismatch fails before extraction.
19. **BCK-R0-DEC-AC-19:** runners use explicit stable OS labels.
20. **BCK-R0-DEC-AC-20:** resolved runner/image versions are recorded.
21. **BCK-R0-DEC-AC-21:** R0 uploads no artifact.
22. **BCK-R0-DEC-AC-22:** workflow permissions are contents-read only.
23. **BCK-R0-DEC-AC-23:** no secret, OIDC or cloud login is available.
24. **BCK-R0-DEC-AC-24:** no mobile/product-domain runtime is in scope.
25. **BCK-R0-DEC-AC-25:** no real project/resource/billing/deploy is in scope.
26. **BCK-R0-DEC-AC-26:** pre-existing dirty work is recorded and preserved.
27. **BCK-R0-DEC-AC-27:** rollback targets only R0-owned paths.
28. **BCK-R0-DEC-AC-28:** every unexpected expansion stops execution.
29. **BCK-R0-DEC-AC-29:** Failed and Inconclusive are distinct.
30. **BCK-R0-DEC-AC-30:** R0 Pass is not backend production readiness.
31. **BCK-R0-DEC-AC-31:** OD-01 Acceptance remains a separate decision.
32. **BCK-R0-DEC-AC-32:** R1/G1 remain blocked after this decision record.
33. **BCK-R0-DEC-AC-33:** residual-risk acceptance has a stable decision ID,
    owner, timestamp and exact scope.
34. **BCK-R0-DEC-AC-34:** advisory effect-chain counts are not represented as
    distinct vulnerability counts.
35. **BCK-R0-DEC-AC-35:** the accepted risk rating applies only to bounded R0.
36. **BCK-R0-DEC-AC-36:** the disposition has a calendar expiry and an earlier
    scope-expansion expiry.
37. **BCK-R0-DEC-AC-37:** severity, reachability, ingress, credentials, data and
    dependency-graph changes revoke the disposition fail-closed.
38. **BCK-R0-DEC-AC-38:** direct-pin or lockfile change requires a fresh audit.
39. **BCK-R0-DEC-AC-39:** forced downgrade and unsupported transitive override
    are not accepted remediation.
40. **BCK-R0-DEC-AC-40:** bounded R0 Pass does not accept OD-01, BCK-05, R1/G1
    or cloud/product runtime.

---

**Current conclusion:** bounded BCK-R0-TCH-01 execution and
`BCK-R0-TCH-ADV-01` are Approved under the combined-role bootstrap disclosure.
The completed local/hosted evidence is therefore **Pass — bounded tooling
feasibility only**, subject to the controls and expiry in §0.1. Product/cloud
backend runtime, `BCK05-OD-01`, R1/G1, credentials, provisioning and deployment
remain unauthorized.
