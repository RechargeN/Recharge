# Recharge Backend — IAM, Workload Identity and Break-glass Model

- ID: **BCK05-OD02-IAM-01**
- Version: **0.1**
- Date: **2026-08-21**
- Status: **Draft evidence — BCK05-OD-02 Proposed**
- Runtime status: **Absent**
- Accountable owners: **Platform Security and Platform Operations**
- Review coordinator: **RechargeN / Product owner**
- Parent: [BCK-05 v0.2.12](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Security boundary: [BCK-04 v0.4.10](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Infrastructure dependency: [OD-07 evidence v0.4](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md)
- Environment policy: [ENV_FLAVORS_SECRETS](../architecture/ENV_FLAVORS_SECRETS.md)
- Runtime effect: **none**

---

## 1. Verdict first

Recharge's proposed CI/cloud authority model is **keyless, environment-isolated
and task-specific**:

- GitHub Actions authenticates through OIDC and Google Cloud Workload Identity
  Federation (WIF), never through committed or stored service-account keys;
- `dev`, `stage` and `prod` use distinct trust bindings and distinct deployment
  identities;
- build, attest, deploy, runtime, backup, restore and emergency duties are
  separate identities with separate permission envelopes;
- production promotion requires a protected environment, immutable artifact,
  named approval and no self-approval;
- human emergency access is temporary, purpose-bound and audited; a static key
  is not the outage fallback;
- project-wide `Owner`, `Editor` and blanket service-account impersonation are
  forbidden for pipelines and runtimes.

This is the concrete candidate policy needed to move `BCK05-OD-02` from Open
to **Proposed**. It does not create a workload identity pool, service account,
IAM binding, GitHub environment, secret, credential or cloud project. Exact
resource names and permission lists remain evidence gates before Acceptance.

## 2. Normative inputs and dated vendor facts

Vendor facts were rechecked on 2026-08-21. A future executable slice must
revalidate them and pin action/tool versions.

| Source | Verified fact | Recharge consequence |
|---|---|---|
| [Google Cloud WIF for deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) | GitHub Actions can exchange an OIDC token for short-lived Google credentials; Google recommends a dedicated project for workload identity pools/providers. | Long-lived GCP credentials are not stored in GitHub; the control-project choice remains tied to OD-07. |
| [Google Cloud WIF overview](https://docs.cloud.google.com/iam/docs/workload-identity-federation) | Pools/providers map external identities; Google recommends separate pools for distinct environments and attribute-limited principals. | `dev`, `stage` and `prod` trust cannot share an unrestricted principal set. |
| [Service accounts in deployment pipelines](https://docs.cloud.google.com/iam/docs/best-practices-for-using-service-accounts-in-deployment-pipelines) | Dedicated service account per pipeline improves least privilege and audit attribution; WIF avoids service-account-key risk. | One deploy identity is not reused across environments or unrelated pipelines. |
| [Secure service-account practices](https://docs.cloud.google.com/iam/docs/best-practices-service-accounts) | Single-purpose accounts, no broad impersonation, key-creation restrictions and disabling unused accounts are recommended. | Basic roles, shared accounts and routine user-managed keys fail review. |
| [GitHub OIDC for Google Cloud](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform) | A cloud-side condition is required to prevent untrusted repositories from obtaining tokens; immutable repository identity is preferred. | Mutable repository names alone never authorize Recharge cloud access. |
| [GitHub deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) | Environments can restrict branches/tags, require reviewers and prevent self-review, but capabilities depend on repository visibility/plan. | Plan/visibility capability is an explicit gate; unavailable GitHub controls require an equivalent independently reviewed gate. |
| [Temporary elevated access](https://docs.cloud.google.com/iam/docs/temporary-elevated-access) | Privileged Access Manager or an equivalent JIT design can grant temporary elevated access with audit evidence. | Break-glass is time-limited elevation, not a permanent privileged account. |

## 3. Scope and non-goals

Included:

- CI OIDC trust and WIF attribute policy;
- pipeline, runtime and recovery identity taxonomy;
- permission ownership, impersonation and revocation rules;
- GitHub environment approval contract;
- bootstrap, break-glass and GitHub/cloud outage behavior;
- IAM intended-state, drift, evidence and test contracts;
- future file map and Acceptance gates.

Excluded:

- no actual IAM role grants or organization-policy mutation;
- no exact project/pool/provider/service-account names;
- no Firebase project, Auth tenant, database, bucket or function;
- no production user/Creator/Page authorization policy owned by BCK-04/06;
- no secrets, access tokens, private keys or identifiers in this document;
- no claim that GitHub plan-dependent controls are available;
- no selection of Terraform, Firebase CLI, `gcloud` or another deploy tool;
- no runtime authorization from Proposed status.

### 3.1 Current repository reality

The repository currently has mobile verification workflows only. They do not
request `id-token: write`, authenticate to Google Cloud, reference protected
backend deployment environments or contain backend deploy jobs. No WIF pool,
provider, service account, IAM intended-state file or `apps/backend` exists.
This is the correct safe state before an Approved executable slice.

Existing action references and GitHub repository plan/visibility still require
separate hardening/capability evidence; this document does not relabel current
mobile CI as a compliant backend release pipeline.

## 4. Trust-boundary model

```text
untrusted PR/fork
  -> verification workflow with no cloud token
  -> protected merge to accepted source revision
  -> release builder with no deploy authority
  -> immutable manifest/provenance
  -> protected environment approval
  -> environment-specific OIDC subject
  -> environment-specific WIF pool/provider
  -> one pipeline-specific deploy identity
  -> exact environment resources
```

Trust does not flow backward. A deployment identity cannot alter the source,
workflow, WIF provider, its own IAM policy, approval evidence or artifact
attestation. A runtime identity cannot deploy or impersonate a deployment
identity.

## 5. Proposed identity topology

### 5.1 Control plane

Candidate A is one dedicated identity/control project containing the GitHub
WIF pools/providers and non-secret trust configuration. It is recommended by
the current vendor guidance but remains conditional on OD-07 topology,
organization availability, cost and Security review.

Minimum logical separation is mandatory even if a dedicated project is not
selected:

| Boundary | Required separation |
|---|---|
| `github-dev` | dev-only subject conditions and dev deploy identity |
| `github-stage` | stage environment/branch conditions and stage deploy identity |
| `github-prod` | prod environment/release conditions and prod deploy identity |

No binding grants an entire pool, GitHub organization or repository all three
environments. Every grant binds the smallest principal/attribute set supported
by the chosen immutable claim format.

### 5.2 Identity catalogue

Names below are logical purpose IDs, not provisioned account names.

| Identity | Purpose | May access | Explicitly denied |
|---|---|---|---|
| `ci-verify` | PR lint/test/codegen/security checks | source and ephemeral CI artifacts | any cloud credential or deploy API |
| `release-build` | reproducible release bundle, SBOM and provenance inputs | source, package registries, artifact staging | environment deploy and production data |
| `release-attest` | attest a verified digest/manifest | verified build output and attestation store | source modification, build output mutation, deploy |
| `deploy-dev` | dev promotion/reconciliation | exact dev deployment resources | stage/prod and domain-data repair |
| `deploy-stage` | stage promotion/reconciliation | exact stage deployment resources | dev/prod and production data |
| `deploy-prod` | prod promotion/rollback of approved manifest | exact prod deployment resources | IAM administration, arbitrary data writes, build/attest |
| `runtime-<module>` | one deployed module/task | only its declared resources/actions | deploy, IAM mutation and other module authority |
| `backup-operator` | scheduled protection operation | declared protected resources and backup destination | restore cutover and domain repair |
| `restore-operator` | isolated restore/drill | declared restore target and evidence paths | direct production cutover without separate approval |
| `audit-exporter` | append/export required audit evidence | audit source and immutable destination | policy/deployment/domain mutation |
| human approver | approve a promotion/change | review metadata and evidence | obtaining deploy credentials merely by approval |
| emergency operator | JIT incident action | exact temporary incident permission set | permanent role, policy/log deletion, hidden impersonation |

One physical service account may not represent multiple catalogue rows unless
an evidence-backed exception proves identical purpose, environment and blast
radius. Production rows have no such bootstrap exception.

## 6. GitHub OIDC subject and claim policy

Cloud trust must validate all applicable immutable and contextual claims:

- immutable repository owner/account ID;
- immutable repository ID;
- exact workflow file or approved reusable-workflow identity;
- source revision/ref class;
- GitHub environment for stage/prod;
- expected issuer and audience;
- event class (`push`, protected tag, or explicitly allowed dispatch);
- no pull-request/fork subject for cloud-bearing jobs.

Repository name, owner name, branch text or actor name alone is insufficient.
If the repository uses an older mutable default `sub` format, the executable
slice must opt into an immutable format or map and condition on numeric claims
before any cloud access.

Required workflow posture:

```yaml
permissions:
  contents: read
  id-token: write
```

This permission block appears only on the exact job that exchanges the token.
All other workflow/job permissions are explicit and default to none. A token is
requested after source/manifest verification and environment approval, never
during untrusted PR execution.

Third-party actions are allowlisted and pinned to a full commit SHA. Dependabot
or equivalent monitoring tracks pinned action updates; tag-only references do
not satisfy the production gate.

## 7. Permission and role contract

### 7.1 Grant rules

- grant at the narrowest resource level supported by the API;
- prefer documented predefined roles only after their permissions are diffed;
- use a version-controlled custom role when predefined roles materially
  overgrant and the operational burden is accepted;
- forbid `roles/owner`, `roles/editor` and `roles/viewer` as pipeline/runtime
  shortcuts;
- forbid project/folder-wide `Service Account Token Creator` or equivalent
  blanket impersonation;
- a principal cannot edit the trust/provider or service-account policy that
  authorizes itself;
- deploy identities cannot create/upload service-account keys;
- provider-managed service agents are inventoried separately from user-managed
  service accounts and never confused with product runtime identities.

### 7.2 Permission manifest

Each identity has a machine-readable intended-state record:

```text
identityPurposeId
environment
principalBinding
claimConditionRevision
targetResources[]
roles[]
expandedPermissionsDigest
impersonationTargets[]
owner
reviewers[]
createdAt
reviewAt
expiresAt?
breakGlassEligible
```

The executable slice expands every role to permissions, flags wildcard or
privilege-escalation capabilities and runs a policy simulation where supported.
Any unreviewed expansion in a provider-managed/predefined role blocks the next
production promotion until reconciled.

## 8. Environment promotion authority

| Environment | Source gate | Human approval | Credential boundary |
|---|---|---|---|
| dev | protected repository source and green required checks | optional by approved policy | dev WIF only |
| stage | exact verified manifest; approved source ref | one named non-author approval | stage WIF only |
| prod | same manifest validated on stage; change/release record; all gates green | two distinct accountable approvals, no self-approval | prod WIF only after approval |

If the current GitHub plan/visibility cannot enforce the required stage/prod
controls, production remains blocked until an equivalent external approval gate
is selected, evidenced and fail-closed. A chat acknowledgement is not a deploy
approval.

Deployment concurrency is one active promotion per environment. Approval is
bound to manifest digest, environment, expected current revision and expiry;
changing any of them invalidates approval.

## 9. Runtime service identity

- every deployed service/job/function receives an explicit user-managed
  runtime identity where the platform permits it;
- default compute/App Engine identities are disabled or stripped of automatic
  broad grants after service-specific compatibility is proved;
- module identity has only its own data, queue, secret and telemetry actions;
- server SDK authority is constrained by IAM even where Firebase Security Rules
  are bypassed;
- public request authentication never implies cloud IAM permission;
- runtime-to-runtime calls use explicit service identity and audience, never a
  shared static secret;
- scheduled jobs and outbox workers use separate identities when their write
  authority differs from the synchronous command service;
- no runtime may alter IAM, organization policy, WIF configuration, deployment
  manifests or its own environment flags.

Exact service decomposition follows Approved domain slices. This document does
not pre-create one account per hypothetical microservice.

## 10. Key and secret policy

Target organization policy enforces:

- disable user-managed service-account key creation;
- disable service-account key upload;
- disable automatic broad grants to default service accounts;
- prevent basic roles for pipeline/runtime identities through review/policy;
- enable audit evidence for token exchange and impersonation.

No JSON service-account key, refresh token or deploy token is stored in GitHub
secrets, environment variables, local files, release artifacts, chat or docs.
WIF configuration values and service-account email addresses are identifiers,
not secrets, but are still environment-scoped configuration.

There is no routine key exception in this model. A provider limitation that
requires a long-lived key blocks Acceptance and requires a new bounded Security
decision with owner, expiry, storage, rotation, revocation and migration back
to keyless authentication.

## 11. Bootstrap and lifecycle

### 11.1 Initial bootstrap

The first control project, organization policies, WIF provider and service
accounts require a separately Approved bootstrap slice. A named human
organization administrator performs only the reviewed bootstrap plan with MFA:

1. apply organization and key-creation constraints;
2. create the intended trust/provider and single-purpose accounts;
3. apply reviewed resource bindings;
4. run negative and impersonation tests;
5. enable audit evidence;
6. remove temporary bootstrap privilege;
7. reconcile observed state to repository intent.

Bootstrap privilege never becomes the steady-state deployment path.

### 11.2 Joiner/mover/leaver and account lifecycle

- human access is group/role based, not directly scattered across projects;
- removal from the repository and cloud organization are separate revocations;
- unused service accounts are disabled before delayed deletion;
- account purpose, owner and last-use evidence are reviewed at least quarterly
  and before every production launch;
- a changed pipeline/workflow gets a new trust revision and re-review;
- repository transfer, rename, owner change or immutable-ID mismatch disables
  token exchange until explicitly reconciled.

## 12. Break-glass contract

Break-glass is allowed only for an active incident or imminent safety/data-loss
risk when the standard path cannot act quickly enough.

Required record:

```text
incidentId
requester
approver(s)
reason
exact resource and permissions
startAt / expiresAt
expected action
rollback/revocation owner
audit query/evidence link
post-incident review dueAt
```

Controls:

- JIT/PAM or equivalent temporary elevation, target maximum 60 minutes;
- two-person approval for production when two qualified people are available;
- if team capacity cannot meet separation of duty, production activation stays
  blocked rather than normalizing single-person permanent access;
- no service-account key fallback;
- no disabling/deleting immutable audit, security rules or evidence;
- every action carries incident/change reason and is reviewed within 48 hours;
- privilege is revoked immediately after use, not merely allowed to expire;
- emergency deployment still uses an identified artifact or records why a
  quarantine/containment action did not deploy software.

The repository's maximum 24-hour CI incident override remains an outer limit;
this narrower IAM elevation target does not weaken it.

## 13. Outage and compromise behavior

| Failure | Required behavior |
|---|---|
| GitHub unavailable | no new deployment; running service and safe user exits continue; break-glass may perform bounded non-code containment |
| OIDC/WIF unavailable | fail closed; do not fall back to a stored key |
| environment approval unavailable | prod promotion waits; incident containment follows §12 |
| repository transferred/renamed | WIF condition mismatch blocks; rebind only after immutable-ID review |
| deploy identity suspected compromised | disable trust binding/account, freeze promotion, audit token exchange and reconcile cloud state |
| runtime identity compromised | disable/replace exact runtime identity, activate safe flag/containment and preserve forensic evidence |
| approver account compromised | revoke human access/session, invalidate approvals and require fresh distinct approval |
| unauthorized IAM drift | freeze promotions; restore reviewed intended state only after impact analysis |

Recovery never broadens an identity to make an error disappear.

## 14. Audit, observability and privacy

Required evidence covers:

- OIDC token exchange and federated principal;
- service-account impersonation/delegation chain;
- IAM/policy/provider/service-account changes;
- deployment and rollback principal, manifest and environment;
- denied access and anomalous cross-environment attempts;
- break-glass request, approval, action and revocation;
- quarterly access review and unused-identity disablement.

Logs do not include tokens, credential configuration contents, secret values,
raw production payloads or private domain records. Retention follows BCK-04 and
BCK-05 accepted tables; this proposal does not invent a legal retention term.

Alerts are required for service-account key creation/upload attempts, broad
role grants, production trust-policy change, repeated token-exchange denial,
unexpected principal/claim and break-glass activation.

## 15. Intended state, drift and rollback

Version-controlled IAM intent is authoritative; cloud IAM is observed state.
Every planned change produces a before/after binding diff, expanded permission
diff, privilege-escalation analysis, owner approval and rollback plan.

Rollback rules:

- remove the new binding before deleting an identity;
- disable a compromised/unused identity before delayed deletion;
- never restore a known-vulnerable broad grant merely because it was previous;
- changing a WIF claim format is additive: add new binding, verify, remove old
  binding, then prove the old subject can no longer exchange a token;
- unknown outcome triggers observed-state reconciliation before retry;
- an IAM rollback cannot bypass a domain/data migration safety gate.

## 16. Conditional implementation map

Only a separately Approved executable slice may create these target paths:

```text
apps/backend/
  infra/
    iam/
      identities.*
      roles.*
      bindings.*
      workload-identity.*
      org-policies.*
      break-glass.*
    environments/
      dev.*
      stage.*
      prod.*
  config/
    iam-policy.schema.json
    workload-identity.schema.json
  scripts/
    verify-oidc-claims.*
    expand-role-permissions.*
    verify-iam-drift.*
    revoke-identity.*

.github/workflows/
  backend-verify.yml
  backend-release.yml
  backend-deploy.yml

docs/runbooks/
  backend-access-revocation.md
  backend-break-glass.md
```

`*` is not permission to mix shell implementations. R0 selects and pins one
cross-platform path, exact provider/action SHAs and generated/manual ownership.

## 17. Evidence and test matrix

| Evidence | Required proof | Gate |
|---|---|---|
| Claim fixtures | allowed exact claims pass; fork/PR/wrong repo/ref/environment fail | before BCK05-OD-02 Acceptance |
| Keyless proof | no user-managed SA key exists or is accepted by workflow | G1/R1 |
| Permission expansion | no basic role, wildcard escalation or unrelated resource | every IAM change |
| Cross-environment negative | dev/stage principal cannot reach prod; prod cannot use dev trust | R1 |
| Impersonation negative | no project-wide arbitrary SA impersonation | R1 |
| Approval binding | changed digest/environment/revision invalidates approval | R1 |
| Runtime negative | runtime cannot deploy, alter IAM or cross module boundary | R2/R4 |
| Drift | console grant freezes promotion and produces typed evidence | R1 |
| Revocation | repository/cloud access and active credential effect are removed | G5 |
| Break-glass | JIT grant, audit, action, immediate revoke and review rehearsed | G6 |
| GitHub capability | plan/visibility supports required protections or equivalent gate exists | before prod |
| Bootstrap | temporary admin removed and intended/observed state reconciled | G1 |

Skipped, manual-without-record, timed-out or provider-unavailable checks are
`Inconclusive`, never Pass.

## 18. Open evidence and decisions

| ID | State | Required answer | Blocks |
|---|---|---|---|
| IAM-OD-01 | Open | dedicated identity/control project versus isolated in-project providers, reconciled with OD-07 | BCK05-OD-02 Acceptance |
| IAM-OD-02 | Open | exact immutable GitHub OIDC claim/sub format for the current repository | any WIF binding |
| IAM-OD-03 | Open | exact per-identity resource roles/permissions reconciled to proposed [BCK05-OD01-TCH-01](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md) after R0 compatibility | BCK05-OD-02 Acceptance |
| IAM-OD-04 | Open | GitHub repository visibility/plan and enforceable environment controls | stage/prod deployment |
| IAM-OD-05 | Open | JIT/PAM tool and qualified two-person production roster | production/break-glass |
| IAM-OD-06 | Open | organization/folder availability and enforceable key/default-SA constraints | G1 |

Fail-closed default: no cloud-bearing workflow, service-account key, production
promotion or privileged emergency access until the applicable row is resolved.

## 19. Acceptance sequence

```text
BCK05-OD02-IAM-01 Proposed
  -> Platform Security + Operations exact-version review
  -> resolve IAM-OD-01..06
  -> BCK05-OD-02 Accepted
  -> separately Approved non-production bootstrap/executable slice
  -> negative WIF/IAM/drift/revocation evidence
  -> stage deployment identity validation
  -> production remains blocked until G5/G6 and independent approvals
```

Acceptance of this model does not provision resources. Evidence from dev/stage
does not automatically prove production readiness.

## 20. Acceptance criteria

1. **BCK05-IAM-AC-01:** CI/cloud authentication is keyless by default.
2. **BCK05-IAM-AC-02:** service-account keys are absent from GitHub and artifacts.
3. **BCK05-IAM-AC-03:** dev, stage and prod trust are isolated.
4. **BCK05-IAM-AC-04:** an entire pool/org/repository is not broadly authorized.
5. **BCK05-IAM-AC-05:** immutable repository identity is checked.
6. **BCK05-IAM-AC-06:** mutable names alone grant no authority.
7. **BCK05-IAM-AC-07:** exact workflow identity is checked.
8. **BCK05-IAM-AC-08:** fork and pull-request subjects receive no cloud token.
9. **BCK05-IAM-AC-09:** OIDC audience and issuer are constrained.
10. **BCK05-IAM-AC-10:** token permission exists only on the auth job.
11. **BCK05-IAM-AC-11:** third-party actions are pinned to full SHAs.
12. **BCK05-IAM-AC-12:** build and deploy authority are separated.
13. **BCK05-IAM-AC-13:** attest and deploy authority are separated.
14. **BCK05-IAM-AC-14:** each deployment environment has a distinct identity.
15. **BCK05-IAM-AC-15:** runtime identities are task/module scoped.
16. **BCK05-IAM-AC-16:** backup and restore duties are separated.
17. **BCK05-IAM-AC-17:** approvers do not receive deploy credentials by approval.
18. **BCK05-IAM-AC-18:** basic Owner/Editor/Viewer roles are forbidden shortcuts.
19. **BCK05-IAM-AC-19:** blanket service-account impersonation is forbidden.
20. **BCK05-IAM-AC-20:** identities cannot modify their own trust or policy.
21. **BCK05-IAM-AC-21:** deploy identities cannot create service-account keys.
22. **BCK05-IAM-AC-22:** role permissions are expanded and reviewed.
23. **BCK05-IAM-AC-23:** permission drift blocks promotion.
24. **BCK05-IAM-AC-24:** production approval is bound to exact manifest/revision.
25. **BCK05-IAM-AC-25:** production prevents self-approval.
26. **BCK05-IAM-AC-26:** unavailable plan controls require equivalent evidence.
27. **BCK05-IAM-AC-27:** deployment concurrency is bounded per environment.
28. **BCK05-IAM-AC-28:** default service accounts get no automatic broad grant.
29. **BCK05-IAM-AC-29:** server SDK authority remains IAM-constrained.
30. **BCK05-IAM-AC-30:** runtime cannot deploy or mutate IAM.
31. **BCK05-IAM-AC-31:** runtime-to-runtime trust uses identity/audience.
32. **BCK05-IAM-AC-32:** organization key restrictions are evidence-gated.
33. **BCK05-IAM-AC-33:** no routine long-lived-key exception exists.
34. **BCK05-IAM-AC-34:** bootstrap privilege is temporary and removed.
35. **BCK05-IAM-AC-35:** human and cloud revocation are separate checks.
36. **BCK05-IAM-AC-36:** unused identities are disabled before deletion.
37. **BCK05-IAM-AC-37:** repository identity change fails closed.
38. **BCK05-IAM-AC-38:** break-glass is incident/purpose/time scoped.
39. **BCK05-IAM-AC-39:** break-glass never disables immutable audit.
40. **BCK05-IAM-AC-40:** break-glass has no static-key fallback.
41. **BCK05-IAM-AC-41:** compromised identity freezes affected promotion.
42. **BCK05-IAM-AC-42:** cloud/GitHub outage does not broaden authority.
43. **BCK05-IAM-AC-43:** token/secret contents are never logged.
44. **BCK05-IAM-AC-44:** impersonation and policy changes are auditable.
45. **BCK05-IAM-AC-45:** IAM rollback never restores known-unsafe grants.
46. **BCK05-IAM-AC-46:** unknown IAM outcome requires reconciliation.
47. **BCK05-IAM-AC-47:** negative tests cover cross-environment access.
48. **BCK05-IAM-AC-48:** inconclusive evidence is never Pass.
49. **BCK05-IAM-AC-49:** Proposed status creates no resource or credential.
50. **BCK05-IAM-AC-50:** runtime requires a separate Approved executable slice.
