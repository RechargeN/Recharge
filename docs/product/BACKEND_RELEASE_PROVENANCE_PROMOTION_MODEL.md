# Recharge Backend — Release Provenance, Promotion and Rollback Model

- ID: **BCK05-OD07-REL-01**
- Version: **0.1**
- Date: **2026-08-21**
- Status: **Draft evidence — BCK05-OD-07 Proposed**
- Runtime status: **Absent**
- Accountable owners: **Release Operations and Platform Security**
- Review coordinator: **RechargeN / Product owner**
- Parent: [BCK-05 v0.2.12](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- IAM dependency: [BCK05-OD02-IAM-01 v0.1](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md)
- Infrastructure dependency: [OD-07 evidence v0.4](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md)
- CI policy: [CI_GATES_POLICY](../architecture/CI_GATES_POLICY.md)
- Runtime effect: **none**

---

## 1. Naming boundary

`BCK05-OD-07` in this document is the BCK-05 decision for **artifact
provenance, promotion and rollback tooling**. It is not the platform-wide
`OD-07`, which selects projects, editions, regions and resource topology.
Release tooling depends on accepted platform OD-07 but cannot silently decide
it.

## 2. Verdict first

Recharge's proposed release contract is **build once, verify once, promote the
same immutable manifest**:

- release output is content-addressed and bound to source commit, workflow,
  dependencies, toolchain, tests, SBOM and provenance;
- dev, stage and prod never rebuild an allegedly identical release;
- every promotion verifies provenance, policy, approval, expected current
  revision and environment compatibility before obtaining deploy authority;
- direct Cloud Run images use immutable digests and may use Binary Authorization
  when the selected topology supports enforceable attestations;
- Firebase/Cloud Functions source deployment is represented honestly as a
  signed source-bundle digest plus provider-build/deployed-revision evidence,
  not falsely claimed as caller-controlled container signing;
- rollback selects a previous verified manifest, but data migrations, indexes,
  rules and provider-managed builds use component-specific recovery plans;
- an unknown or partially applied deployment is `unknown_outcome` or
  `recovery_required`, never success.

This concrete candidate advances `BCK05-OD-07` from Open to **Proposed**. It
creates no workflow, artifact, registry, attestation, signing key, deployment
or runtime authority.

## 3. Normative inputs and dated vendor facts

Vendor facts were rechecked on 2026-08-21 and must be revalidated by the
executable slice.

| Source | Verified fact | Recharge consequence |
|---|---|---|
| [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations) | Attestations bind an artifact to repository/workflow/commit/environment evidence; generating an attestation has no security value unless consumers verify it. | Promotion must verify provenance against a policy, not merely upload an attestation. |
| [GitHub attestation usage](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) | Attestations can cover binaries/container images, but availability for private repositories depends on GitHub plan. | GitHub attestations are a candidate, not an assumed capability; plan evidence is required. |
| [GitHub deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) | Environments can restrict sources, require reviewers and prevent self-review; availability varies by plan/visibility. | Production approval must prove the available enforcement or use an equivalent gate. |
| [Google Binary Authorization attestations](https://docs.cloud.google.com/binary-authorization/docs/attestations) | Binary Authorization can verify signed image-digest attestations before Cloud Run/GKE deployment. | Direct container deployment can be digest/attestation-gated where supported. |
| [Binary Authorization for Cloud Run](https://docs.cloud.google.com/binary-authorization/docs/run/overview) | Cloud Run services/jobs can enforce policy, but Functions deployed through the Cloud Run source-deploy repository require an exemption; policy changes are not retroactive. | Functions provenance must preserve the source-to-provider-build mapping; no false universal Binary Authorization claim. |
| [Enable Binary Authorization for Cloud Run](https://docs.cloud.google.com/binary-authorization/docs/run/enabling-binauthz-cloud-run) | Organization policy is recommended because a service-level setting can otherwise be disabled; breakglass is logged and prior healthy revision can continue after a failed deployment. | Enforcement and breakglass require independent policy/audit evidence; existing revisions must be inventoried. |
| [GitHub Actions repository settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository) | Repository policy can require actions to be pinned to full commit SHAs. | Third-party action pinning is a release prerequisite. |

## 4. Scope and non-goals

Included:

- release artifact/manifest identity and provenance contract;
- dependency, action, toolchain, SBOM and vulnerability gates;
- build, attest, dev/stage/prod promotion state machine;
- approval, concurrency, drift and revocation semantics;
- component-aware deploy/rollback/recovery behavior;
- Functions source-deploy and direct-container distinction;
- evidence/test matrix and conditional file map.

Excluded:

- BCK05-OD01-TCH-01 is Proposed, but no installed/verified backend runtime,
  package manager or deploy CLI exists;
- no registry, KMS key, Sigstore issuer or Binary Authorization resource;
- no actual GitHub plan/visibility assumption;
- no universal image-signing claim for provider-built Functions;
- no database schema/data migration owned by a domain BCK;
- no automatic production rollback before representative evidence;
- no production mobile-store release policy;
- no deployment, billing or cloud resource authorization.

### 4.1 Current repository reality

The current `.github/workflows` files verify mobile code and upload ordinary CI
artifacts. They do not build a backend release manifest, generate/verify SBOM or
provenance, attest a backend artifact, promote between environments or deploy
cloud resources. Existing actions use version tags such as `@v4`/`@v2`, not
full commit SHAs, so they do not yet satisfy this proposed production release
gate. No workflow is modified by this documentation slice.

`apps/backend`, Artifact Registry releases, signing/attestation resources and
deployed backend revisions remain absent.

## 5. Release unit and immutable manifest

The release unit is `BackendReleaseManifest v1`, an immutable,
content-addressed record. The manifest digest is the promotion identity.

Minimum fields:

```text
manifestVersion
releaseId
manifestDigest
sourceRepositoryId
sourceCommitSha
sourceTreeDigest
workflowIdentity
workflowDigest
builderIdentity
buildRunId
buildStartedAt / buildCompletedAt
toolchain[]
dependencyLockDigests[]
contractFixtureDigest
components[]
sbomDigest
provenance[]
securityScanEvidence[]
testEvidence[]
compatibilityPlanRevision
minimumConfigRevision
targetEnvironmentClass[]
createdAt
```

Each component records:

```text
componentId
componentType
artifactUri
artifactDigest
sourceBundleDigest?
providerBuildId?
providerOutputDigest?
configurationDigest
deploymentOrder
rollbackClass
dataCompatibilityWindow
```

Mutable tags (`latest`, branch, semantic version) are display/discovery aliases
only. Deployment resolves and records the immutable digest before approval.

## 6. Artifact classes

| Class | Immutable subject | Required evidence |
|---|---|---|
| direct OCI service/job | registry path + image digest | source/build provenance, SBOM, scan, image attestation and deploy verification |
| Firebase/Functions source deploy | normalized source bundle digest | source provenance, dependency lock, provider build ID/output revision mapping and deployed revision evidence |
| Firestore/Storage Rules | normalized file-set digest | emulator/negative tests, compatibility plan and deployed checksum/export |
| Firestore indexes/TTL/config | normalized descriptor digest | validation, additive/long-running operation evidence and observed state |
| environment/config schemas | schema and data digest | fail-closed validation and compatibility evidence |
| contract fixtures/generated validators | source schema/fixture and generated digest | codegen/fixture parity and no manual edit |
| migration package | immutable migration ID/digest | domain owner, forward/rollback/reconciliation and backup gate |

The manifest may contain multiple classes, but partial success never produces a
new healthy release pointer.

## 7. Functions and container enforcement boundary

For a direct OCI deployment, the target state is:

```text
verified source
  -> reproducible image digest
  -> provenance + policy attestations
  -> verified digest in release manifest
  -> Binary Authorization/policy check where supported
  -> deployed revision digest reconciliation
```

For Firebase/Cloud Functions source deployment, the platform may build the
container after source upload. Current Google guidance requires Binary
Authorization exemption for the Cloud Run Functions source-deploy repository.
Therefore Recharge requires:

```text
verified normalized source bundle digest
  -> immutable release manifest
  -> environment-specific source deployment
  -> provider build operation ID
  -> provider output/revision identity
  -> observed deployed revision mapped back to source bundle/manifest
```

The exemption is documented as residual supply-chain risk. A source bundle
digest, GitHub attestation or provider build provenance is not mislabeled as a
Binary Authorization guarantee. If Functions later supports stronger
caller-enforced provenance, a reviewed revision may adopt it.

## 8. Build reproducibility and dependency policy

- checkout exact commit SHA; no moving branch state after manifest creation;
- accept and prove the proposed runtime, package manager, compiler and deploy
  tooling in [BCK05-OD01-TCH-01](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md);
- use immutable lockfiles and frozen/clean dependency installation;
- forbid manual edits to generated artifacts;
- record action/reusable-workflow full commit SHAs;
- isolate release builder from production data and deployment authority;
- normalize archive ordering, timestamps and excluded files before source-bundle
  hashing;
- record non-reproducible provider inputs explicitly rather than claiming byte
  reproducibility;
- build scripts cannot download unpinned executable code after verification;
- secret values are never inputs to the artifact digest or embedded output.

A second clean build of caller-controlled artifacts must reproduce the same
digest or produce a documented, bounded non-determinism finding. Provider-built
Functions use source-bundle reproducibility plus provider operation evidence.

## 9. SBOM, vulnerability and policy evidence

Every production candidate includes:

- machine-readable SBOM for shipped runtime dependencies;
- dependency/license inventory for reviewed policy;
- secret scan, SAST and dependency vulnerability results;
- generated/lockfile integrity result;
- malware/package-registry provenance controls where available;
- explicit exceptions registry with owner, reason, scope and expiry.

Fail-closed rules:

- unavailable or stale required scan is `Inconclusive` and blocks promotion;
- a security-policy failure cannot use the generic CI incident override because
  the accepted CI policy prohibits overriding failed security checks;
- exact severity/exploitability/license thresholds are `REL-OD-04` and must be
  Accepted before production;
- an accepted exception is digest/package/version scoped and expires; it does
  not suppress future versions automatically.

## 10. Provenance and attestation policy

Minimum provenance binds:

- artifact/source-bundle digest;
- immutable repository and commit identity;
- workflow/reusable-workflow identity and digest;
- builder identity and build run;
- input/source/lockfile/toolchain digests;
- build timestamps and environment class;
- declared predicate/schema version.

Accepted implementations may use GitHub artifact attestations, cloud-native
provenance, in-toto/DSSE, Sigstore or KMS-backed attestations after BCK05-OD-01
and `REL-OD-01/02` select one interoperable verification path.

Requirements independent of tool:

- build and attestation duties are separated where supported;
- verifier trusts an explicit issuer/builder/workflow policy;
- verification happens again immediately before each promotion;
- attestation subject digest exactly matches manifest component digest;
- revoked/quarantined signer, workflow or artifact fails closed;
- absence of transparency log in a private service is disclosed and compensated
  by repository/audit evidence; it is not silently called public transparency;
- signing key material, if any, is non-exportable/managed and never in GitHub;
- keyless/OIDC identity follows BCK05-OD02-IAM-01.

## 11. Release state machine

```text
built
  -> verified
  -> attested
  -> approved_dev
  -> deployed_dev
  -> approved_stage
  -> deployed_stage
  -> validated_stage
  -> approved_prod
  -> deploying_prod
  -> deployed_prod
```

Exceptional terminal/side states:

```text
rejected | expired | revoked | quarantined | superseded
rolled_back | degraded | unknown_outcome | recovery_required
```

Transitions require expected current state/revision. Approval expires and is
invalidated by digest, policy, workflow, source, compatibility plan or target
environment change.

## 12. Promotion contract

### 12.1 Build once, promote same digest

- environment-specific configuration is a separately versioned manifest input,
  not a code rebuild;
- stage and prod consume the same component/source-bundle digests;
- provider-generated revision IDs may differ by environment, but each must map
  to the same approved source bundle and compatibility plan;
- artifacts never flow backward from prod to stage/dev;
- local/emulator artifacts are not promotable.

### 12.2 Gates

| Transition | Minimum gate |
|---|---|
| source -> built | protected source, clean builder, pinned dependencies/toolchain |
| built -> verified | tests, contracts, SBOM, scans, digest and manifest validation |
| verified -> attested | approved issuer/builder/workflow policy and exact digest |
| attested -> dev | dev IAM, config and drift checks |
| dev -> stage | same digest, stage approval, compatibility/emulator evidence |
| stage -> validated_stage | smoke/integration/load/rollback evidence against predeclared thresholds |
| validated_stage -> approved_prod | all non-deferrable BCK/OD gates, change record, two distinct approvals, budget/recovery readiness |
| approved_prod -> deployed_prod | reverify digest/provenance/policy/IAM/drift/expected revision immediately before deploy |

GitHub plan-dependent protections require capability evidence. If unavailable,
an equivalent independently reviewed approval mechanism is required; chat or a
workflow input alone is insufficient.

### 12.3 Concurrency and idempotency

- one active deployment lease per environment;
- promotion key: environment + target manifest digest + change/release ID;
- same key/same digest returns the committed result;
- same key/different digest is `idempotency_conflict`;
- stale environment revision is `revision_conflict`;
- timeout after provider call is `unknown_outcome` until observed state is
  reconciled;
- no retry starts a second provider deployment while the first may be active.

## 13. Compatibility and component ordering

No universal hardcoded order is safe for every release. Each manifest carries
an reviewed compatibility DAG with preconditions and rollback class.

Rules:

- prefer expand/migrate/contract compatibility;
- deploy additive schema/index/config capability before code that requires it;
- preserve current and explicitly supported previous contract revisions during
  staged mobile rollout;
- Security Rules changes pass negative tests and cannot create an authorization
  gap between old/new code;
- long-running indexes are ready before dependent query traffic;
- destructive data/schema changes require domain-owned migration, backup and
  reconciliation evidence;
- flags default new risky mutations off until post-deploy validation;
- partial DAG completion enters `degraded/recovery_required` and blocks the
  healthy pointer.

## 14. Post-deploy validation and traffic

Deployment success is not release success. The pipeline verifies:

- observed component/revision/config/rules/index identity;
- environment and runtime service identity;
- health/readiness and typed synthetic user journeys;
- error, latency, invariant, cost and security signals;
- no unexpected IAM/config drift;
- safe cancellation/release/degraded paths remain available;
- market flags keep EE/LT disabled unless separately accepted.

Traffic increase is explicit and reversible. Unknown health freezes rollout;
it does not infer success from process exit code.

## 15. Rollback and recovery classes

| Class | Examples | Default action |
|---|---|---|
| R0 reversible artifact | direct service image/function source with compatible state | promote previous verified manifest/revision |
| R1 configuration/rules | flags, Rules, config | apply reviewed previous compatible digest; preserve security floor |
| R2 additive/long-running | indexes, TTL, queues | stop dependent traffic; do not assume instant deletion rollback |
| R3 data mutation | schema/data migration, repair | domain recovery/forward fix/restore/reconciliation plan |
| R4 compromised artifact/identity | malicious dependency, signer/workflow compromise | quarantine/revoke/freeze; deploy only separately verified clean manifest |

Rollback constraints:

- never deploy a known-vulnerable previous artifact merely because it is last;
- previous code must be compatible with current data/config/rules;
- rules rollback cannot reopen access removed for security/privacy reasons;
- migration rollback is not inferred from code rollback;
- provider rollback uses immutable revision identity, not mutable tag/name;
- automated rollback is allowed only for predeclared unambiguous health signals
  and a rehearsed R0/R1 plan;
- suspected corruption, authorization failure or unknown outcome freezes writes
  and invokes incident/recovery, not blind oscillation;
- rollback result receives the same observation/reconciliation and evidence as
  forward deployment.

## 16. Revocation, quarantine and compromise

Any of these blocks new promotion of the affected manifest:

- source repository/workflow/builder/attestor compromise;
- signer/key/issuer revocation;
- critical policy violation or malicious dependency;
- manifest/digest mismatch;
- missing/invalid provenance;
- unexplained deployed-state drift;
- incident/legal hold requiring quarantine.

Response:

1. freeze promotion and traffic expansion;
2. revoke WIF/identity/attestor or key as applicable;
3. mark manifest and derived artifacts quarantined;
4. inventory every environment/revision using the digest/source bundle;
5. preserve evidence and assess user/data impact;
6. build a new clean artifact from reviewed source; never mutate the old one;
7. require fresh approvals and staged validation.

Deleting or overwriting the compromised evidence is prohibited.

## 17. Evidence record and retention boundary

Every build/promotion/rollback record includes:

```text
operationId
manifestDigest
componentDigests[]
sourceCommitSha
workflow/build/attestation IDs
environment
actor/federated/deploy identity
approvers[]
expectedPreviousRevision
providerOperation/revision IDs
startedAt / completedAt
result / typedFailure
observedStateDigest
validationEvidence[]
incident/change references
```

Release manifest, provenance, approval, deployment and rollback evidence cannot
be deleted while the artifact is deployed, rollback-eligible, quarantined,
under incident investigation or legal hold. Exact retention is delegated to
BCK-04/BCK-05 accepted tables; this proposal does not invent a legal duration.

Evidence excludes credentials, raw tokens, secrets and unnecessary production
payloads.

## 18. Conditional implementation map

Only a separately Approved executable slice may create:

```text
apps/backend/
  infra/release/
    manifest.schema.json
    compatibility-plan.schema.json
    provenance-policy.*
    promotion-policy.*
    rollback-policy.*
    vulnerability-policy.*
  scripts/
    build-release.*
    generate-sbom.*
    create-provenance.*
    verify-release-manifest.*
    verify-provenance.*
    promote-release.*
    reconcile-deployment.*
    rollback-release.*
    quarantine-release.*

.github/workflows/
  backend-verify.yml
  backend-release.yml
  backend-deploy.yml

docs/runbooks/
  backend-release.md
  backend-rollback.md
  backend-supply-chain-incident.md
```

R0 replaces `*` with one pinned cross-platform implementation. This file map is
not permission to edit existing mobile CI or create backend runtime now.

## 19. Evidence and test matrix

| Evidence | Required proof | Gate |
|---|---|---|
| Manifest schema | unknown/missing critical field fails closed | R0 |
| Digest | archive/image/config digest is stable and verified before promotion | R0 |
| Clean rebuild | caller-controlled output reproduces or bounded non-determinism is recorded | R0/R1 |
| Action/tool pinning | workflow has no unapproved mutable action/tool reference | R0 |
| SBOM/scan | complete shipped dependency inventory and accepted policy result | R0/R1 |
| Provenance positive | approved issuer/builder/workflow/source/digest verifies | R0 |
| Provenance negative | wrong repo/workflow/digest/issuer/revoked subject fails | R0 |
| Functions mapping | source digest maps to provider build and deployed revision | R1 |
| Binary Authorization | direct OCI non-attested digest is denied where selected | R1 |
| Same-artifact | dev/stage/prod use the same approved artifact/source-bundle digest | R1 |
| Approval binding | changed digest/environment/revision invalidates approval | R1 |
| Concurrency | two promotions cannot mutate one environment concurrently | R1 |
| Unknown outcome | timeout reconciles provider/observed state before retry | R1 |
| Compatibility DAG | partial step enters recovery state; no false success | R1 |
| Rollback | each R0/R1 class rehearsed on stage with post-validation | G5/G6 |
| Data boundary | code rollback cannot pretend to reverse migration/data | every migration |
| Revocation | quarantined/revoked artifact cannot promote | G5 |
| Plan capability | required GitHub protections/attestations exist or equivalent gate | before prod |

Timed-out, skipped, manual-without-record or unsupported checks are
`Inconclusive`, never Pass.

## 20. Open evidence and decisions

| ID | State | Required answer | Blocks |
|---|---|---|---|
| REL-OD-01 | Open | exact builder/package/deploy integration and compatibility evidence for proposed BCK05-OD01-TCH-01 | BCK05-OD-07 Acceptance |
| REL-OD-02 | Open | provenance/attestation format, issuer, verifier and immutable storage | BCK05-OD-07 Acceptance |
| REL-OD-03 | Open | artifact registry/source-bundle store and cross-environment access model | R0/R1 |
| REL-OD-04 | Open | exact vulnerability/license acceptance policy and exception process | production |
| REL-OD-05 | Open | GitHub visibility/plan support for attestations, approvals and self-review prevention | stage/prod |
| REL-OD-06 | Open | direct OCI versus Functions source-deploy component inventory and Binary Authorization applicability | R1 |
| REL-OD-07 | Open | per-component compatibility/rollback classes and first release DAG | first deploy |
| REL-OD-08 | Open | exact release/evidence retention aligned with BCK-04/Legal | production |

Fail-closed default: no unverified artifact, unavailable scan, mutable tag,
unapproved manifest, incompatible component, unknown outcome or quarantined
release may progress.

## 21. Acceptance sequence

```text
BCK05-OD07-REL-01 Proposed
  -> Release Operations + Platform Security exact-version review
  -> resolve REL-OD-01..08 and BCK05-OD-01/02 dependencies
  -> BCK05-OD-07 Accepted
  -> separately Approved R0 non-production pipeline scaffold
  -> manifest/provenance/negative/rollback evidence
  -> R1 dev/stage provider mapping and drift evidence
  -> production remains blocked until G5/G6 and all D1 dependencies pass
```

## 22. Acceptance criteria

1. **BCK05-REL-AC-01:** release identity is an immutable manifest digest.
2. **BCK05-REL-AC-02:** mutable tags are never deployment authority.
3. **BCK05-REL-AC-03:** source commit/tree/workflow identity is recorded.
4. **BCK05-REL-AC-04:** toolchain and lockfile digests are recorded.
5. **BCK05-REL-AC-05:** every component has an immutable subject digest.
6. **BCK05-REL-AC-06:** build output and production data are isolated.
7. **BCK05-REL-AC-07:** build and deploy duties are separated.
8. **BCK05-REL-AC-08:** attestation and deployment are independently verifiable.
9. **BCK05-REL-AC-09:** attestations are verified, not merely generated.
10. **BCK05-REL-AC-10:** verifier constrains issuer/builder/workflow/source.
11. **BCK05-REL-AC-11:** revoked or quarantined provenance fails closed.
12. **BCK05-REL-AC-12:** signing material is never stored in GitHub.
13. **BCK05-REL-AC-13:** third-party actions use full commit SHAs.
14. **BCK05-REL-AC-14:** dependencies/toolchain are pinned by accepted policy.
15. **BCK05-REL-AC-15:** generated artifacts are not manually edited.
16. **BCK05-REL-AC-16:** shipped dependencies have an SBOM.
17. **BCK05-REL-AC-17:** unavailable security evidence blocks promotion.
18. **BCK05-REL-AC-18:** failed security checks cannot use generic override.
19. **BCK05-REL-AC-19:** exceptions are scoped, owned and expiring.
20. **BCK05-REL-AC-20:** dev/stage/prod promote the same artifact digest.
21. **BCK05-REL-AC-21:** environment config does not rebuild code.
22. **BCK05-REL-AC-22:** local/emulator artifacts are not promotable.
23. **BCK05-REL-AC-23:** Functions use source-to-provider-revision evidence.
24. **BCK05-REL-AC-24:** Functions are not falsely claimed as universal image enforcement.
25. **BCK05-REL-AC-25:** direct OCI uses digest enforcement where accepted.
26. **BCK05-REL-AC-26:** Binary Authorization limitations remain explicit.
27. **BCK05-REL-AC-27:** policy changes do not retroactively bless old revisions.
28. **BCK05-REL-AC-28:** approvals bind digest, environment and expected revision.
29. **BCK05-REL-AC-29:** production prevents self-approval.
30. **BCK05-REL-AC-30:** plan-dependent controls require capability evidence.
31. **BCK05-REL-AC-31:** one deployment lease exists per environment.
32. **BCK05-REL-AC-32:** promotion and rollback are idempotent.
33. **BCK05-REL-AC-33:** stale revisions fail with typed conflict.
34. **BCK05-REL-AC-34:** unknown provider outcome requires reconciliation.
35. **BCK05-REL-AC-35:** partial deployment is never healthy success.
36. **BCK05-REL-AC-36:** compatibility order is manifest-specific and reviewed.
37. **BCK05-REL-AC-37:** Security Rules cannot create an auth compatibility gap.
38. **BCK05-REL-AC-38:** indexes are ready before dependent traffic.
39. **BCK05-REL-AC-39:** risky mutations start default-off.
40. **BCK05-REL-AC-40:** deploy success requires post-deploy validation.
41. **BCK05-REL-AC-41:** traffic expansion is explicit and reversible.
42. **BCK05-REL-AC-42:** rollback uses a previous verified compatible manifest.
43. **BCK05-REL-AC-43:** rollback never restores known-vulnerable authority.
44. **BCK05-REL-AC-44:** code rollback is not data migration rollback.
45. **BCK05-REL-AC-45:** ambiguous corruption/security failure avoids blind auto-rollback.
46. **BCK05-REL-AC-46:** quarantined evidence is preserved.
47. **BCK05-REL-AC-47:** release evidence contains no credential or raw payload.
48. **BCK05-REL-AC-48:** inconclusive evidence is never Pass.
49. **BCK05-REL-AC-49:** Proposed status creates no workflow/artifact/resource.
50. **BCK05-REL-AC-50:** runtime requires a separate Approved executable slice.
