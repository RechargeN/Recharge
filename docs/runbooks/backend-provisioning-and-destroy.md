# Backend provisioning and destroy (Draft, not executed)

Status: **Draft.** Writing this procedure and the IaC grants no authority to
create or destroy anything. Provider project IDs follow
`recharge-<env>-<uniqueSuffix>` and are chosen only in the approved provisioning
slice after availability checks; none is invented here.

## Provisioning (separately authorized slice)

1. Create the environment project and link billing (outside this repository).
2. Bootstrap the state bucket: local state first, then migrate to the bucket of
   that environment (`<project>-tfstate`, versioned, never public,
   destroy-protected). One bucket per environment; never shared.
3. Supply the reviewed project/commit/manifest and owner-record digests. The
   record alone cannot open the checked-in Draft manifest: plan/apply fail with
   a blocking precondition. Permission never changes resource cardinality.
4. Review the plan of that environment root; apply only in the approved slice.
5. Deploy Rules, indexes, TTL and Functions with the Firebase CLI (they are not
   managed by Terraform); run the smoke list.

## Destroy (data protection first)

| Environment | Rule |
|---|---|
| dev | separate explicit destroy authorization, verified export and protection check |
| stage | only with a dated record and the same checks |
| prod | forbidden except through a superseding decision |

Before any destroy: verified export of data and audit, list of protected
resources (databases, buckets and secrets carry `deletion_protection` /
`prevent_destroy` and are unprotected only by a reviewed change, never forced),
and confirmation that nothing another environment depends on is removed.
`force_destroy` stays false everywhere.

## Dev preflight (2026-10-01; none of this authorizes execution)

Only synthetic dev data. Stage/prod, market activation, push and merge remain
unauthorized. Do not remove all cloud restrictions globally. Close the following
items for the exact dev slice; the preparer writes the record, the owner approves
it. Do not ask the owner to re-accept already Accepted architecture decisions.

| Item | Existing decision / exact missing input | Required before |
|---|---|---|
| Scope and location | OD-07 Accepted with controls; exact available project ID/number, artifact and resource/API allowlist still missing | project creation and any provisioning |
| IAM/WIF | BCK05-OD-02 Accepted; expanded per-identity permissions/bindings, immutable subject opt-in, exact audience, protected main and environments, sanitized negative claim evidence pending | WIF binding or cloud-bearing workflow |
| Budget | Roadmap §3.5 already accepts the dev EUR25/month verification baseline and RechargeN as temporary Finance owner. OD-04 remains Proposed; this is neither spending authorization nor a hard cap. Notification destination, quotas and exact spend/provisioning approval remain missing | billable provisioning |
| Reliability | OD-03 Proposed; select bounded dev thresholds, observation duration and stop criteria; full stage load evidence is not claimed | dev service deployment/traffic; BCK-05/G1/R1 approvals remain independent |
| Recovery | Roadmap §3.5 accepts the OD-05 §7 verification targets; OD-05 remains Proposed and restore evidence is absent. State backup custody and an executable dev export/restore procedure remain missing; do not silently relax RPO/RTO for synthetic data | data-bearing provisioning under the approved slice |
| Incident | Roadmap §3.5 names RechargeN as Incident owner. OD-08 remains Proposed, formal G5/G6 gate; dev contact channel, containment and escalation remain missing. Independent review/tabletop evidence is not fabricated | dev traffic; full OD-08 evidence before G5/G6 |
| App Check | mode/provider/registration and exact callable enforcement policy missing; Emulator bypass must be impossible in cloud | deploy/expose dev endpoints |
| Approval | exact reviewed SHA, manifest bytes/hash, owner evidence, operations and expiry missing | every cloud operation |

Project creation, billing linkage, state bootstrap, IAM changes, data deployment
and active smoke are separate operation scopes, not implied by an IaC approval.
The owner performs login/MFA/payment entry; delegated automation uses separately
authorized short-lived access, never keys pasted into chat or the repository.

### Authorization record template — DRAFT, not a signature

Keep the completed record in the separately approved evidence location. The
following empty template does not permit anything and must fail validation:

```json
{
  "schemaVersion": 1,
  "status": "draft",
  "recordRef": null,
  "owner": null,
  "ownerApprovalEvidenceRef": null,
  "environment": "dev",
  "projectId": null,
  "commitSha": null,
  "manifestSha256": null,
  "issuedAtUtc": null,
  "expiresAtUtc": null,
  "operations": [],
  "dataScope": "synthetic",
  "push": false,
  "merge": false,
  "marketActivation": false
}
```

For a future approved execution, the record and variables must agree on project,
environment, commit and manifest SHA-256; the exact record bytes are pinned by
`authorization_record_sha256`. The operator verifies the actual owner approval
and its provenance; strings and hashes are not cryptographic proof of consent.
The current manifest is Draft/denied and cannot pass, even with a fabricated
complete record. Promoting it requires a separately approved provisioning/schema
amendment, not this local task. No automatic transition to approved is provided.

Before any future apply, re-check expiry, revocation, record provenance, approved
operations and the **saved plan digest** in the protected runner. A saved plan is
not a permanent grant; `plantimestamp()` checks alone cannot enforce expiry at
later apply time. No deployment runner or approval-signature verifier exists yet.

Copyable owner wording (fill all brackets first; not effective as a template):

> Разрешаю только [операции] в dev-проекте [ID/number], для commit [SHA],
> execution manifest [SHA-256], перечня ресурсов/API [digest] и reviewed plan
> [digest, если apply]. Бюджет [значение/решение], владелец [имя], канал [ref],
> квоты [решение], срок до [UTC]. Только синтетические данные. Stage/prod,
> activation, неуказанные операции, push и merge не разрешаю.

### Expected dev inventory (generated, not observed cloud state)

From the repository root, using the pinned local Node (no network):

```text
node apps/backend/scripts/verify-execution-manifest.mjs --dev-inventory
```

The output carries the exact manifest hash, database/location, buckets, account
names, WIF, budget/App Check decisions, collections/indexes/TTL, flags and explicit
absences. It is a candidate inventory, **not** permission to create all entries.
Null decisions, exact API allowlist, IAM roles and approved Functions exports
must be resolved before the future plan-to-inventory comparison. The manifest's
legacy account `deployed` field currently selects planned runtime identities;
it is not evidence of any deployed cloud account.

State bootstrap must be separate: create and protect the environment state bucket
under its own bounded approval, retain an encrypted/restricted backup outside the
target project, then migrate/import its state ownership. Never let an ordinary
environment destroy remove its own only recovery state. Versioning, no public
access, no force_destroy and verified state recovery are mandatory. `destroy`
is not allowed by the plan/apply record above.

### Read-only smoke vs active checks

| Read-only, separately authorized cloud reads | Active, separately authorized mutations |
|---|---|
| Compare resource names, regions, IAM and WIF settings with reviewed inventory | Synthetic Auth/Session/Booking commands and cleanup |
| Inspect deployed Rules/index/TTL configuration and index readiness | Negative Rules requests / real authorization probes |
| Inspect flags off, public-access prevention and bucket IAM | Emit a test notification and confirm delivery/acknowledgment |
| Inspect budget/channel configuration and monitoring coverage | Exercise kill switch, rollback or restore drill |

Read-only configuration checks do not prove delivery, denial enforcement, restore
or end-to-end correctness. A missing active check is Pending, not a passed smoke.

### Minimum dev monitoring and cost controls

Before dev traffic, choose a named primary contact and escalation destination;
approve numerical thresholds and observation window (do not infer acceptance
from Proposed OD values). Required signals: Function errors/timeouts/latency,
permission/App Check/Rules denials where available, retry/dead-letter backlog,
unexpected resource/region/IAM drift, spend and quota pressure. Redact payloads,
tokens and PII; monitoring must not become a second personal-data store.

Budget notifications at proposed 50/75/90/100% need explicit owner adoption and
a tested channel. Alerts are not a hard spending cap. Configure service quotas
and scoped creation/ingestion kill switches; preserve existing Booking cancel,
session recovery and mandatory privacy exits. Never detach billing automatically.
Alert delivery test, budget creation and monitoring creation remain unauthorized.

### Next owner checkpoint — one bounded decision, not a new document

Do not request re-approval of the R1 scope, locations, IAM architecture, EUR25
baseline or RechargeN's existing roles. Do not fill missing contact data from a
Git email address. Resolve these inputs before preparing an executable cloud
authorization:

1. **Destination:** the owner supplies the dev budget/incident notification
   address or channel, and confirms who acknowledges an alert. Thresholds
   50/75/90/100% remain a proposal until explicitly adopted; delivery must be
   tested before ordinary billable resources, not merely configured.
2. **Next scope:** recommended next authorization is credentialed, read-only
   discovery of a candidate dev project ID/number, billing currency/availability
   and available quotas. Project creation, billing linkage, API activation,
   role grants, plan/apply, deployment and active smoke are excluded. Login/MFA
   stays with the owner; no credentials are pasted into chat or Git.
3. **Source gate:** the Accepted WIF contract trusts only the protected `main`
   deployment workflow. The current `codex/recharge-integration` branch is not
   eligible, even if its tests pass. While push/merge are forbidden, CI cloud
   execution stays blocked. Do not broaden the subject/ref condition to bypass
   this. A later owner-authorized merge/protection setup or a separately
   accepted bounded bootstrap route is required; neither is authorized here.

Before implementation of IAM bindings, complete the existing IAM model §7.2
permission manifests. The intended separation is:

| Identity / phase | Intended scope to expand and review | Must not gain |
|---|---|---|
| Bootstrap operator | Exact dev project, APIs, protected state, approved accounts/trust/budget; short-lived and separately authorized | Standing runtime/deploy authority or stage/prod access |
| WIF principal | Only the exact environment deploy identity and accepted claims | Arbitrary service-account impersonation or modification of its own trust |
| Deploy identity | Reviewed artifact, exact target services, act-as only approved runtime identities | Billing administration, WIF/self-IAM administration, key creation, product-data mutation |
| Runtime Booking / Identity | Approved data operations and telemetry for their responsibilities | Flags/IAM/deployment administration, unrelated modules or environments |
| Recovery operator | Separately approved backup/restore targets and protected state evidence | Routine deploy powers or unapproved data deletion |

This table is not a role-binding permission manifest. Do not grant a broad role
as a temporary substitute; do not assume collection-level isolation from a
database-level IAM grant. Verify the actual supported scope before choosing
roles and digesting expanded permissions. No binding is created by this pass.

Bootstrap order for the later authorized slice: owner decision and source gate
→ exact IDs/permission manifests → protected state and recovery copy → budget
channel plus active delivery evidence and quotas → reviewed ordinary-resource
plan → separately approved apply → read-only inventory reconciliation →
separately approved deployment/active smoke. Bootstrap resource costs and the
alert test need explicit bounded authorization; there is no implied free or
zero-risk bootstrap. Dev synthetic traffic does not prove R1/stage capacity.

Copyable next-step wording (replace the channel and expiry first):

> Подтверждаю канал dev budget/incident [канал] и получение уведомлений мной,
> RechargeN. Принимаю пороги 50/75/90/100% поверх ранее принятого baseline
> €25/месяц; это не hard cap и не разрешение расходов. Разрешаю только
> read-only проверку доступности candidate dev project ID, billing currency
> и доступных квот до [UTC]. Вход/MFA выполняю сам. Создание проекта,
> привязку billing, IAM/API changes, plan/apply, deployment, активные проверки,
> push, merge и activation не разрешаю. WIF/main gate не обходить.
