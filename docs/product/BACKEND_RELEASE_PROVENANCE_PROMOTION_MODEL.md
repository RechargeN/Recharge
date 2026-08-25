# Recharge Backend — Release Provenance, Promotion and Rollback Model

- ID: **BCK05-OD07-REL-01**
- Version: **0.2.1**
- Date: **2026-08-25**
- Status: **Accepted evidence — BCK05-OD-07 Accepted with controls**
- Runtime status: **Absent**
- Accountable owners: **Release Operations and Platform Security**
- Review coordinator: **RechargeN / Product owner**
- Parent: [BCK-05 v0.2.23](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- IAM dependency: [BCK05-OD02-IAM-01 v0.2.1](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md) (Accepted with controls)
- Infrastructure dependency: [OD-07 evidence v0.6](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md) (Accepted with controls)
- Toolchain dependency: [BCK05-OD01-TCH-01 v0.3.4](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md) (Accepted baseline v0.3.3 with controls)
- Candidate baseline: **BCK05-REL-A1-DUAL-PROV-v1**
- Owner decision: [BCK05-OD07-DEC-01 v0.2](BACKEND_RELEASE_PROVENANCE_PROMOTION_OWNER_DECISION.md) (Accepted with controls)
- CI policy: [CI_GATES_POLICY](../architecture/CI_GATES_POLICY.md)
- Runtime effect: **none**

---

## 0. Changelog

### v0.2.1 — 2026-08-25

- recorded the exact BCK05-OD07-DEC-01 v0.2 owner verdict and accepted
  `BCK05-REL-A1-DUAL-PROV-v1` with every stated control;
- preserved all executable policy/schema/workflow, GitHub setting,
  WIF/cloud, D1/G1/R0/R1, deployment and production gates;
- created no release, attestation, repository/cloud mutation, runtime or
  `main` merge authority.

### v0.2 — 2026-08-25

- reconciled release policy with Accepted OD-01, BCK05-OD-02 and platform
  OD-07 plus the actual bounded R0 scaffold;
- selected `BCK05-REL-A1-DUAL-PROV-v1`: GitHub keyless provenance for the
  caller-controlled release plus honest Firebase/Cloud Build provider receipts;
- separated release manifest, environment plan, provider receipt and promotion
  record, removing self-referential digest and pre-deploy provider-output gaps;
- selected exact public-repository attestation/action candidates, immutable
  release assets and environment-local Artifact Registry mirrors;
- added the exact unsigned owner-decision contract while retaining every
  workflow/cloud/runtime action as blocked.

## 1. Naming boundary

`BCK05-OD-07` in this document is the BCK-05 decision for **artifact
provenance, promotion and rollback tooling**. It is not the platform-wide
`OD-07`, which selects projects, editions, regions and resource topology.
Release tooling depends on accepted platform OD-07 but cannot silently decide
it.

## 2. Verdict first

The Accepted `BCK05-REL-A1-DUAL-PROV-v1` contract is **build once, verify
once, promote the same immutable release**:

- release output is content-addressed and bound to source commit, workflow,
  dependencies, toolchain, tests, SBOM and provenance;
- dev, stage and prod never rebuild an allegedly identical release;
- every promotion verifies provenance, policy, approval, expected current
  revision and environment compatibility before obtaining deploy authority;
- any future direct Cloud Run image uses immutable digests and may use Binary
  Authorization only after an amended component inventory proves enforceable
  attestations;
- Firebase/Cloud Functions source deployment is represented honestly as a
  signed source-bundle digest plus provider-build/deployed-revision evidence,
  not falsely claimed as caller-controlled container signing;
- rollback selects a previous verified manifest, but data migrations, indexes,
  rules and provider-managed builds use component-specific recovery plans;
- an unknown or partially applied deployment is `unknown_outcome` or
  `recovery_required`, never success.

This is the exact Accepted architecture baseline for `BCK05-OD-07`. It
creates no workflow, release, artifact, registry, attestation, signing key,
deployment or runtime authority. Exact cloud permissions, repository settings,
executable fixtures and provider observations remain mandatory before R1, not
fictional prerequisites for accepting a fail-closed release policy.

## 3. Normative inputs and dated vendor facts

Vendor facts were rechecked on 2026-08-25 and must be revalidated by the
executable slice.

| Source | Verified fact | Recharge consequence |
|---|---|---|
| [RFC 8785 — JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785) | JCS defines deterministic JSON serialization suitable for cryptographic hashing/signing. | Release records use JCS canonical bytes and keep their digest outside the hashed object. |
| [GitHub artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations) | Attestations bind an artifact to repository/workflow/commit/environment evidence; generating an attestation has no security value unless consumers verify it. | Promotion must verify provenance against a policy, not merely upload an attestation. |
| [GitHub attestation usage](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) | Attestations are available for public repositories on all current plans and require `id-token: write` plus `attestations: write`; consumers verify with GitHub CLI. | Current public visibility supports the selected candidate, but release jobs must isolate attestation permissions and verify every subject. |
| [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) | When enabled before publication, a release locks its tag/assets and automatically receives a release attestation. | The durable caller-controlled source bundle/manifest store is an immutable GitHub release, not a 90-day workflow artifact. |
| [GitHub workflow artifact retention](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts) | Public-repository workflow artifacts are retained for at most 90 days and can be deleted with their run. | Ordinary Actions artifacts are transport/debug evidence only, never the rollback authority. |
| [`actions/attest`](https://github.com/actions/attest) | The official action emits SLSA provenance or SBOM/custom attestations; v4.2.2 resolves to signed commit `1e69f48acb82d1966a394da916b4c1698aa569d6`. | The future release workflow uses that full SHA only after a fresh dependency review; `@v4` is not accepted authority. |
| [Artifact Registry generic artifacts](https://docs.cloud.google.com/artifact-registry/docs/generic) | Regional generic repositories store versioned immutable archives/configuration; conflicting uploads return `ALREADY_EXISTS`. | Each OD-07 environment may mirror the exact verified release bytes in its own `europe-west1` repository without cross-project runtime trust. |
| [Cloud Build provenance](https://docs.cloud.google.com/build/docs/securing-builds/generate-validate-build-provenance) | Cloud Build can emit SLSA provenance for supported Artifact Registry outputs, but generation and validation have explicit configuration/format limitations. | Firebase provider provenance is captured and validated when available; its absence is disclosed and cannot be replaced by caller attestation. |
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

- Accepted OD-01/BCK05-OD-02/platform OD-07 do not authorize a release workflow,
  cloud identity, provider build or deployment;
- no registry, KMS key, Sigstore issuer or Binary Authorization resource;
- no actual GitHub plan/visibility assumption;
- no universal image-signing claim for provider-built Functions;
- no database schema/data migration owned by a domain BCK;
- no automatic production rollback before representative evidence;
- no production mobile-store release policy;
- no deployment, billing or cloud resource authorization.

### 4.1 Current repository reality

Read-only repository evidence on 2026-08-25 records:

| Fact | Observed value |
|---|---|
| repository | public `RechargeN/Recharge`; numeric ID `1213588766` |
| bounded backend scaffold | `apps/backend` Present for R0 emulator/toolchain only |
| backend workflow | `.github/workflows/backend-r0.yml`; full-SHA Actions, `contents: read`, explicit no-cloud guard |
| release/deploy workflow | absent |
| release manifest/SBOM/provenance | absent |
| environments / protected `main` | none / absent |
| repository Actions policy | all actions allowed; repository SHA-pinning enforcement disabled |
| immutable-release configuration/evidence | not established; no backend immutable release exists |
| WIF/IAM/Artifact Registry/provider revision | absent |

Mobile workflows still contain tag-based `actions/upload-artifact` references.
Therefore repo-wide SHA enforcement would currently break unrelated CI and must
be preceded by a separately reviewed mobile-workflow pin migration. Every
future backend release workflow pins its own Actions immediately; repository
enforcement remains a fail-closed pre-cloud gate. No workflow is changed by
this documentation slice.

## 5. Immutable records and digest rules

The candidate deliberately separates facts known at release time from facts
known only for one environment or after a provider deployment.

### 5.1 Canonical digest rule

Every record below is UTF-8 JSON, rejects duplicate keys, unknown required
schema revisions and non-finite numbers, and is canonicalized with JSON
Canonicalization Scheme (JCS) before hashing. A digest is lowercase
`sha256:<64 hex>` over the exact canonical bytes. The digest is carried by the
envelope/reference to the record and **never appears inside the bytes it
hashes**. Raw archive bytes are hashed separately and are not JCS-normalized.

### 5.2 `BackendReleaseManifest v1`

This environment-neutral record is the release identity. Minimum fields:

```text
manifestVersion
releaseId
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
sbomSubjects[]
provenanceSubjects[]
securityScanEvidence[]
testEvidence[]
compatibilityPlanRevision
supportedEnvironmentClasses[]
createdAt
```

Each component contains only release-time facts:

```text
componentId
componentType
artifactFileName
artifactMediaType
artifactDigest
sourceBundleDigest?
deploymentOrder
rollbackClass
dataCompatibilityWindow
```

It does not contain environment IDs, mutable URIs, secrets, provider build IDs,
provider output digests or deployed revision IDs.

### 5.3 `EnvironmentDeploymentPlan v1`

The plan binds one release to one target without rebuilding it:

```text
planVersion
releaseManifestDigest
environmentId / environmentClass
configurationDigest
secretReferenceSetDigest
featureFlagSnapshotDigest
compatibilityPlanRevision
expectedPreviousHealthyDeploymentId
componentTargets[]
changeRecordId
createdAt / expiresAt
```

Secret references are names/versions or opaque IDs, never secret values. A plan
change creates a new `deploymentPlanDigest` and invalidates approval even when
the release manifest is unchanged.

### 5.4 `ProviderDeploymentReceipt v1`

Only the deploy/reconcile job may create this post-provider record:

```text
receiptVersion
releaseManifestDigest / deploymentPlanDigest
environmentId / componentId
providerOperationId / providerBuildId?
providerOutputDigest? / deployedRevisionId
observedConfigurationDigest
startedAt / completedAt
result / typedFailure
rawEvidenceReferences[]
```

Missing provider fields remain explicitly `unsupported` or `unobserved`; they
are never fabricated from the caller-controlled source digest.

### 5.5 `PromotionRecord v1` and healthy pointer

The append-only promotion record binds manifest, plan, approvals, receipts,
validation and final state. `LastKnownHealthyDeployment` is a compare-and-set
pointer to a successful promotion record. It updates only after all required
components reconcile and post-deploy validation passes; partial/unknown results
cannot move it.

Mutable tags (`latest`, branch, semantic version) and human release names are
display/discovery aliases only. Deployment resolves and verifies the immutable
manifest and plan digests before approval and again immediately before use.

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
new healthy release pointer. The durable caller-controlled package is a
normalized source archive, manifest, SBOM and evidence index published together
as assets of one draft GitHub release and made immutable only on publication.
Its release tag is discovery metadata; asset digests and `manifestDigest` remain
authority.

Ordinary GitHub Actions artifacts may transport evidence inside a workflow but
are not canonical storage or rollback authority. Before any environment deploy,
the exact verified assets may be mirrored without modification to an
environment-local Artifact Registry generic repository in `europe-west1`.
`ALREADY_EXISTS` is accepted only when downloaded bytes match the expected
digest; otherwise it is `artifact_conflict`. Cross-project runtime pull grants
are not introduced by this design.

## 7. Functions and container enforcement boundary

The Accepted initial R1 component inventory is Firebase/Cloud Functions v2 plus
Rules/index/config artifacts. Direct OCI Cloud Run services/jobs are disabled
until an amended inventory and separately Approved slice exist.

For a future direct OCI deployment, the target state is:

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

The Functions exemption is documented as residual supply-chain risk. A source bundle
digest, GitHub attestation or provider build provenance is not mislabeled as a
Binary Authorization guarantee. If Functions later supports stronger
caller-enforced provenance, a reviewed revision may adopt it.

Provider Cloud Build provenance is captured when the concrete operation exposes
a supported verifiable statement. `unsupported` or unavailable provider
provenance blocks any claim of end-to-end SLSA/Binary Authorization, but does
not erase the independently verified caller-controlled source provenance. The
provider receipt and deployed revision reconciliation remain mandatory.

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

The candidate future release job is `.github/workflows/backend-release.yml`:
it runs from protected `main`, has no cloud deploy identity, produces the
normalized package, validates the four schemas, generates SBOM/scan evidence,
and creates GitHub keyless SLSA provenance with official `actions/attest`
resolved to reviewed full commit SHA
`1e69f48acb82d1966a394da916b4c1698aa569d6`. The SHA is a dated candidate and
must be rechecked when the executable slice starts. `id-token: write` and
`attestations: write` exist only on the smallest attestation job; all other job
permissions are explicit and read-only unless an output publication step
requires a narrower write permission.

The future `.github/workflows/backend-deploy.yml` accepts only
`manifestDigest`, `deploymentPlanDigest` and target environment. It verifies
the immutable release, GitHub attestation, policy and approvals before acquiring
the environment-specific WIF identity from accepted BCK05-OD-02. It never
rebuilds source and never inherits release-publisher authority.

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

`BCK05-REL-A1-DUAL-PROV-v1` selects two non-interchangeable evidence lanes:

1. the caller-controlled release bundle, manifest and SBOM use GitHub keyless
   artifact attestations (Sigstore/in-toto SLSA predicates) issued only by the
   reviewed release workflow in `RechargeN/Recharge`;
2. Firebase/Cloud Functions provider builds use provider operation, build,
   output and revision receipts plus Cloud Build provenance when the concrete
   build exposes a supported verifiable statement.

GitHub verification constrains repository numeric ID, repository owner,
workflow path/ref, source commit, event, environment when present, subject
digest and supported predicate type. Repository rename or transfer cannot be
accepted merely because a display name still matches. Promotion stores the
verification result and verifier version. Provider provenance is never used to
replace or retroactively manufacture caller provenance, and the two statements
must reconcile through the same source-bundle digest.

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

The canonical caller assets live in a GitHub **immutable release** only after
all assets and attestations are complete and the draft is published. If
immutable releases are unavailable or cannot be proven enabled, publication is
`capability_unavailable` and no stage/prod promotion occurs. Re-uploading bytes
under the same semantic version is prohibited; a correction is a new release.

## 11. Release state machine

```text
drafted
  -> built
  -> verified
  -> attested
  -> published_immutable
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

Release publication state is global, while approvals/deployments are separate
per-environment promotion records. A release can therefore be deployed to dev
without implying stage/prod approval. Transitions require expected current
state/revision. Approval expires and is invalidated by manifest digest, plan
digest, policy, workflow, source, compatibility plan, target environment or
expected-current-revision change.

## 12. Promotion contract

### 12.1 Build once, promote same digest

- environment-specific configuration belongs to a separately hashed
  `EnvironmentDeploymentPlan`, not the release manifest and not a code rebuild;
- stage and prod consume the same component/source-bundle digests;
- provider-generated revision IDs may differ by environment, but each must map
  to the same approved source bundle and compatibility plan;
- artifacts never flow backward from prod to stage/dev;
- local/emulator artifacts are not promotable.

### 12.2 Gates

| Transition | Minimum gate |
|---|---|
| source -> built | protected source, clean builder, pinned dependencies/toolchain |
| built -> verified | tests, contracts, SBOM, scans, canonical digest and manifest validation |
| verified -> attested | approved issuer/builder/workflow policy and exact subject digests |
| attested -> published_immutable | complete draft assets, immutable-release capability and post-publication digest verification |
| published_immutable -> dev | dev plan, IAM, config and drift checks |
| dev -> stage | same digest, stage approval, compatibility/emulator evidence |
| stage -> validated_stage | smoke/integration/load/rollback evidence against predeclared thresholds |
| validated_stage -> approved_prod | all non-deferrable BCK/OD gates, change record, two distinct approvals, budget/recovery readiness |
| approved_prod -> deployed_prod | reverify digest/provenance/policy/IAM/drift/expected revision immediately before deploy |

GitHub plan-dependent protections require capability evidence. For the current
public repository, the candidate uses GitHub environments with source branch
restriction, required reviewer, prevent-self-review and no admin bypass where
supported. Native environment approval may be a single approval; therefore
production additionally requires a signed release/change approval by another
authorized person, and the environment approver must be distinct from that
person and the initiating deploy actor. If these identities cannot be proven,
production remains blocked. Chat or a workflow input alone is insufficient.

### 12.3 Concurrency and idempotency

- one active deployment lease per environment;
- promotion key: environment + target manifest digest + change/release ID;
- the key also binds `deploymentPlanDigest`; a changed plan is a different
  operation and invalidates prior approval;
- same key/same digest returns the committed result;
- same key/different digest is `idempotency_conflict`;
- stale environment revision is `revision_conflict`;
- timeout after provider call is `unknown_outcome` until observed state is
  reconciled;
- no retry starts a second provider deployment while the first may be active.

## 13. Compatibility and component ordering

No universal hardcoded order is safe for every release. The release manifest
references a reviewed compatibility plan revision; each environment plan binds
the concrete target DAG, preconditions and rollback classes without changing
release bytes.

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

The canonical evidence graph is:

```text
BackendReleaseManifestDigest
  -> caller artifact/SBOM/provenance subject digests
  -> EnvironmentDeploymentPlanDigest
     -> approvals + expected previous healthy deployment
     -> ProviderDeploymentReceiptDigest[]
     -> validation evidence
     -> PromotionRecordDigest
        -> LastKnownHealthyDeployment (conditional pointer)
```

Every promotion/rollback record also includes operation ID, source commit,
workflow/build/attestation IDs, actor/federated/deploy identities, approvers,
timestamps, typed result/failure, observed-state digest and incident/change
references. The record is append-only; corrections supersede by digest and do
not rewrite prior evidence.

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
    backend-release-manifest.schema.json
    environment-deployment-plan.schema.json
    provider-deployment-receipt.schema.json
    promotion-record.schema.json
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
not permission to edit existing mobile CI, repository settings, releases,
environments, cloud resources or backend runtime now. A separate mobile Action
pin migration precedes repository-wide SHA enforcement.

## 19. Evidence and test matrix

| Evidence | Required proof | Gate |
|---|---|---|
| Manifest schema | unknown/missing critical field fails closed | R0 |
| Canonical digest | JCS record digest is external/non-self-referential; archive/config digests are stable | R0 |
| Record separation | pre-release manifest cannot contain post-deploy provider facts or environment secrets/config | R0 |
| Clean rebuild | caller-controlled output reproduces or bounded non-determinism is recorded | R0/R1 |
| Action/tool pinning | workflow has no unapproved mutable action/tool reference | R0 |
| SBOM/scan | complete shipped dependency inventory and accepted policy result | R0/R1 |
| Provenance positive | approved issuer/builder/workflow/source/digest verifies | R0 |
| Provenance negative | wrong repo/workflow/digest/issuer/revoked subject fails | R0 |
| Immutable release | incomplete/mutable/unverifiable release cannot become promotion authority | R0 |
| Durable retrieval | canonical assets survive workflow-artifact expiry and reverify byte-for-byte | R0 |
| Mirror conflict | existing generic artifact is accepted only when bytes match expected digest | R1 |
| Functions mapping | source digest maps to provider build and deployed revision | R1 |
| Binary Authorization | direct OCI non-attested digest is denied where selected | R1 |
| Same-artifact | dev/stage/prod use the same approved artifact/source-bundle digest | R1 |
| Approval binding | changed digest/environment/revision invalidates approval | R1 |
| Separation of persons | production release approval, environment approval and deploy initiator satisfy distinctness policy | G5/G6 |
| Concurrency | two promotions cannot mutate one environment concurrently | R1 |
| Unknown outcome | timeout reconciles provider/observed state before retry | R1 |
| Compatibility DAG | partial step enters recovery state; no false success | R1 |
| Rollback | each R0/R1 class rehearsed on stage with post-validation | G5/G6 |
| Data boundary | code rollback cannot pretend to reverse migration/data | every migration |
| Revocation | quarantined/revoked artifact cannot promote | G5 |
| Plan capability | required GitHub protections/attestations exist or equivalent gate | before prod |
| Healthy pointer | unknown/partial/failed deployment cannot replace last known healthy record | R1 |

Timed-out, skipped, manual-without-record or unsupported checks are
`Inconclusive`, never Pass.

## 20. Open evidence and decisions

| ID | State | Required answer | Blocks |
|---|---|---|---|
| REL-OD-01 | Selected, unproved | Accepted OD-01 toolchain; normalized archive/JCS/SHA-256 package; exact executable versions revalidated in R0 | R0 execution |
| REL-OD-02 | Selected, unproved | GitHub keyless SLSA/SBOM attestations constrained to exact repo/workflow/commit/subject plus separate provider receipts | R0/R1 evidence |
| REL-OD-03 | Selected, unproved | immutable GitHub release is canonical caller store; environment-local Artifact Registry generic mirror | R0/R1 evidence |
| REL-OD-04 | Open | exact vulnerability/license acceptance policy and exception process | production |
| REL-OD-05 | Partially observed | repository is public; environments/protection/immutable-release settings remain absent or unproved | stage/prod |
| REL-OD-06 | Selected | first R1 uses Functions v2/Rules/index/config; direct OCI and Binary Authorization are deferred to amendment | future direct OCI |
| REL-OD-07 | Open | per-component compatibility/rollback classes and first release DAG | first deploy |
| REL-OD-08 | Open | exact release/evidence retention aligned with BCK-04/Legal | production |

Fail-closed default: no unverified artifact, unavailable scan, mutable tag,
unapproved manifest, incompatible component, unknown outcome or quarantined
release may progress.

## 21. Acceptance sequence

```text
BCK05-OD07-REL-01 Accepted with controls
  -> separately Approved R0 non-production pipeline scaffold
  -> resolve REL-OD-01..03/05 executable evidence and REL-OD-04 policy
  -> manifest/provenance/negative/rollback evidence
  -> R1 dev/stage provider mapping and drift evidence
  -> resolve REL-OD-07/08 for the first component DAG/retention
  -> production remains blocked until G5/G6 and all D1 dependencies pass
```

Acceptance of the candidate selects the architecture and controls only. It does
not convert any `Selected, unproved` item into runtime evidence and does not
authorize GitHub settings, release publication, workflow creation, WIF/cloud
resources, deployment or production data processing.

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
51. **BCK05-REL-AC-51:** manifest digest is external to the canonical bytes it hashes.
52. **BCK05-REL-AC-52:** JSON records use one fail-closed canonicalization and digest contract.
53. **BCK05-REL-AC-53:** release manifest contains only environment-neutral release-time facts.
54. **BCK05-REL-AC-54:** environment plan changes create a new digest and invalidate approval.
55. **BCK05-REL-AC-55:** provider output identity is written only in a post-deploy receipt.
56. **BCK05-REL-AC-56:** manifest, plan, receipt and promotion records form a verifiable digest graph.
57. **BCK05-REL-AC-57:** immutable release assets, not workflow artifacts, are canonical caller storage.
58. **BCK05-REL-AC-58:** registry mirrors preserve exact verified bytes and fail on digest conflict.
59. **BCK05-REL-AC-59:** caller and provider provenance remain distinct and reconcile through source digest.
60. **BCK05-REL-AC-60:** repository numeric identity is constrained during attestation verification.
61. **BCK05-REL-AC-61:** initial R1 excludes direct OCI and makes no Binary Authorization claim for Functions.
62. **BCK05-REL-AC-62:** production approval evidence proves required separation of persons.
63. **BCK05-REL-AC-63:** partial, failed or unknown deployment cannot move the healthy pointer.
64. **BCK05-REL-AC-64:** repository-wide SHA enforcement waits for the reviewed mobile Action pin migration.
65. **BCK05-REL-AC-65:** candidate Acceptance selects policy only and leaves every executable/cloud action separately gated.
