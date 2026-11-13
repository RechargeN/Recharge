# Recharge Backend — Backup, RPO/RTO and Recovery Model

- Evidence ID: **BCK05-OD05-REC-01**
- Version: **0.1**
- Date: **2026-08-21**
- Decision served: **BCK05-OD-05**
- Decision status: **Proposed — Platform/Privacy/domain verdict pending**
- Evidence status: **Draft — restore drill and topology evidence required**
- Runtime status: **Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Required reviewers: **Platform Operations, Security/Privacy, Legal/Privacy,
  Identity, Content, Booking, Reference Data, Media and Product/Finance**
- Parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Reliability boundary: [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md)
- Cost boundary: [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md)
- Infrastructure boundary: [OD-07 evidence](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md)
- Runtime effect: **none**

---

## 1. Purpose and verdict

This document defines the first numerical recovery proposal for Recharge:
record-family criticality, RPO/RTO, containment time, backup/PITR/soft-delete
candidate policy, isolated restore, privacy re-deletion, reconciliation,
evidence and drills.

It advances `BCK05-OD-05` from Open to **Proposed**, not Accepted. No backup,
PITR, Storage policy, export, project, database, IAM role or restore operation
is created or authorized.

## 2. Core recovery principles

1. Provider replication handles infrastructure failure; it does not undo a
   valid-but-wrong application write, compromised credential or operator error.
2. Backup existence is not recovery proof; only an isolated verified restore is.
3. Restore never blindly overwrites the current authoritative database.
4. Domain owners reconcile aggregates and invariants; Operations does not edit
   domain truth directly.
5. Restored data remains quarantined until schema, AuthZ, privacy, retention and
   domain reconciliation pass.
6. Backup retention never becomes an undocumented extension of product/legal
   retention or an analytics archive.
7. Deletion, restriction and legal-hold decisions are re-applied after restore.
8. Derived projections are rebuilt from authority rather than treated as truth.
9. Last-known-good read/safe-cancel paths take priority over reopening writes.
10. Recovery targets are business objectives, not a claim about provider tools.

## 3. Definitions and recovery clocks

| Term | Definition |
|---|---|
| Incident start | earliest reliable evidence of destructive event/failure |
| Detection time | incident start to owned detection |
| Containment time | detection to stopping unsafe new effects/writes |
| RPO | maximum accepted authoritative data loss measured before incident point |
| Safe-state RTO | time to bounded safe read/cancel/restriction capability |
| Full RTO | time to reconciled normal service for the named record family |
| Restore point | immutable provider timestamp/backup ID selected with evidence |
| Recovery completion | validation, reconciliation, privacy re-deletion and owner sign-off complete |

RPO is not the backup schedule alone. RTO is not the duration of a provider
restore command alone. Detection, decision, validation, reconciliation and
safe cutover are included.

## 4. Official provider constraints — checked 2026-08-21

| Provider fact | Recovery consequence |
|---|---|
| Firestore regional databases synchronously replicate across at least three zones; multi-region across five zones in three regions | replication/topology handles infrastructure resilience but not logical corruption |
| Firestore scheduled backup retention is at most 14 weeks; schedules may be daily or weekly | candidate schedule must remain within this limit |
| Firestore backup restore creates a new database in the same project and source backup location | isolated restore is supported; same-project compromise remains a risk requiring IAM/break-glass review |
| Firestore PITR can read at one-minute granularity up to seven days and documents a 1-minute RPO for PITR recovery | supports the RC0 proposal only after enablement and drill proof |
| Cloud Storage soft delete is enabled by default on supported new buckets for seven days and can be configured 7–90 days or disabled | every bucket must declare a policy; provider default is not Recharge acceptance |
| Cloud Storage recommends soft delete over Object Versioning for accidental/malicious deletion protection; versioning remains useful for explicit version workflows | use soft delete as candidate baseline; add versioning only with bounded lifecycle/cost purpose |

Sources:

- [Firestore disaster recovery](https://docs.cloud.google.com/firestore/native/docs/disaster-recovery)
- [Firestore backup restore API](https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases/restore)
- [Cloud Storage soft delete](https://docs.cloud.google.com/storage/docs/soft-delete)
- [Cloud Storage Object Versioning](https://docs.cloud.google.com/storage/docs/object-versioning)
- [Google Cloud recovery testing guidance](https://docs.cloud.google.com/architecture/framework/reliability/perform-testing-for-recovery-from-data-loss)

Vendor facts are rechecked at Acceptance and provisioning. This document does
not infer that any feature is enabled in Recharge.

## 5. Disaster and corruption scenarios

| Scenario | Primary protection | Recovery boundary |
|---|---|---|
| zone/region/provider infrastructure outage | Firestore/Storage replication; Cloud Run re-creation | OD-07 topology plus last-known-good/degraded mode |
| accidental document deletion/write | PITR or backup into isolated database | domain-scoped compare/replay, never bulk blind copy |
| buggy release writes valid corrupt state | feature containment, restore point, audit/outbox | rollback code; reconcile every affected aggregate/effect |
| stolen deploy/backup identity | IAM revoke, break-glass, immutable audit | Security incident first; recovered state remains untrusted until review |
| Firestore database deletion | scheduled backup where available plus config-as-code | restore new database; rebuild indexes/Rules/IAM/config |
| Storage object/bucket deletion | explicit soft-delete policy; optional bounded versioning | restore exact generation/object and metadata under review |
| projection loss/corruption | authoritative source/event/rebuild reader | rebuild new projection and atomically switch revision |
| privacy deletion resurrected by restore | deletion/restriction completion evidence | mandatory re-deletion/restriction before exposure |
| market/reference config corruption | immutable signed revision/last-known-good | roll back pointer, never invent translations/policy |
| total project/account compromise | separately approved cross-boundary export/escrow strategy | remains blocking evidence; same-project backup alone is insufficient |

The last scenario is intentionally not claimed solved by v0.1.

## 6. Record-family recovery classification

| Class | Record families | Loss tolerance | Restore approach |
|---|---|---|---|
| RC0 — authority/safety | identity/capability/publisher grants; Booking/hold/ledger/usage/idempotency/audit/outbox; privacy restrictions/deletion tasks; security incident evidence | near-zero | PITR/backup plus transactional/domain reconciliation; safe paths first |
| RC1 — primary product truth | Event/Place/Route/Scenario/publication source; profiles/pages; favorites/visits/reviews; reference/localization accepted revisions; media originals | bounded | isolated restore by family/revision, verify ownership/retention, controlled cutover |
| RC2 — rebuildable operational view | feed/map/search/details projections; counters; derived media; notification inbox projection | source loss forbidden; view loss accepted temporarily | rebuild from RC0/RC1 sources with new projection revision |
| RC3 — disposable/analytical | synthetic fixtures, caches, sampled ordinary telemetry and derived analytics where lawful | documented loss acceptable | re-create; restore only if purpose/retention requires |

An outbox obligation committed atomically with an authoritative transition has
the owning aggregate's class. It is not downgraded to RC2 because a worker
consumes it asynchronously.

## 7. Numerical RPO/RTO proposal

Targets apply after production activation and are measured by drills/incidents.
`Safe RTO` is the bounded user-safety surface; `Full RTO` is reconciled normal
operation.

| Family/journey | RPO | Containment | Safe RTO | Full RTO |
|---|---:|---:|---:|---:|
| Identity/capability/publisher authority | `<=1 min` | `<=15 min` | correct deny/last-known-good authority `<=1 h` | `<=4 h` |
| Booking/hold/ledger/usage/audit/outbox | `<=1 min` | `<=15 min` | own read/cancel/safe release `<=1 h` | reconciled mutations `<=4 h` |
| Privacy restriction/deletion orchestration | `<=1 min` | `<=15 min` | restriction enforced/status visible `<=1 h` | task reconciliation `<=4 h` |
| Security/repair audit required for response | `<=1 h` | `<=15 min` | incident access `<=2 h` | verified archive `<=8 h` |
| Published content/profile/page sources | `<=1 h` | `<=30 min` | last-known-good/read-only `<=4 h` | writes/publication `<=8 h` |
| Personal library, visits and reviews | `<=4 h` | `<=1 h` | read-only `<=8 h` | normal service `<=24 h` |
| Reference/localization accepted revision | zero accepted-revision loss | `<=15 min` | last-known-good pointer `<=1 h` | normal publication `<=4 h` |
| Media originals plus ownership metadata | `<=1 h` | `<=30 min` | existing safe media `<=4 h` | upload/processing `<=8 h` |
| Critical feed/map/search/details projection | source RPO applies | `<=30 min` | previous honest stale revision `<=1 h` | rebuilt current revision `<=4 h` |
| Full derived projections/variants | source RPO applies | `<=1 h` | optional | complete rebuild `<=24 h` |
| Ordinary operational logs/analytics | `<=24 h` where retained | `<=4 h` | not a service dependency | `<=72 h` or documented no-restore |

Any RC0 target unsupported by selected topology/tooling blocks OD-05/OD-07
Acceptance; the number is not weakened silently to fit a cheaper design.

## 8. Candidate environment protection policy

| Control | dev | stage | prod proposal |
|---|---|---|---|
| Firestore PITR | off | enabled only for bounded rehearsal window when authorized | enabled for authoritative database after Privacy/Cost approval |
| daily Firestore backup | none | 7-day retention during recovery validation | daily, 14-day retention |
| weekly Firestore backup | none | optional bounded rehearsal | weekly, 12-week retention |
| restore destination | disposable isolated database | isolated stage database | isolated quarantine database in same project/location; never live overwrite |
| Storage originals soft delete | explicit 0/7-day test policy | explicit 7-day synthetic policy | explicit **7-day candidate**, per-bucket Privacy/Cost approval |
| Storage derived/temp soft delete | normally disabled with evidence | explicit short policy | disabled or bounded by purpose; always rebuildable/no personal truth |
| Object Versioning | off | targeted test only | off by default; allowed only for named overwrite workflow with lifecycle cap |
| restore drill | fixture smoke | quarterly-equivalent before release and on topology change | quarterly plus trigger-based, executed safely in stage/isolation |

The prod schedule is a candidate, not a generic retention rule. Record-family
product/legal deletion limits remain authoritative. A shorter lawful retention
can require disabling/reducing protection or enforced re-deletion after restore.

## 9. Configuration and non-data recovery inventory

Recovery evidence must version and reconstruct:

- project/environment/resource map without secrets;
- Firestore database edition/location, indexes, TTL and backup schedules;
- Firestore/Storage Rules source, compiled/deployed digest and IAM bindings;
- Functions/services, runtime, concurrency, max instances and traffic revision;
- feature flags, market config and accepted reference/localization revision;
- Secret Manager resource names/versions and rotation procedure, never values;
- Scheduler/Tasks/Pub/Sub/Eventarc configuration and retry/dead-letter policy;
- dashboards, alerts, budget routes and runbook versions;
- API/schema/migration compatibility and release manifest.

Repository configuration is necessary but not proof that actual cloud state
matches. Drift evidence is captured before and after recovery.

## 10. Backup success and health evidence

Each backup/protection check records:

```text
evidenceId, environment, projectAlias, resourceId, location,
protectionType, scheduleRevision, sourceRevisionRange,
startedAtUtc, completedAtUtc, providerArtifactId,
size/count, encryption/IAMPolicyRevision, retentionExpiresAt,
status, failureReason, releaseManifestId, evidenceDigest
```

Mandatory alerts:

- no successful RC0 protection point within the declared RPO;
- backup/PITR/soft-delete policy drift;
- schedule disabled/deleted or retention shortened;
- backup identity/permission change;
- unexpected size/count delta `>25%` without known release/load reason;
- restore drill overdue or last result inconclusive/failed;
- evidence missing, unparsable or newer unsupported schema.

Metadata contains no user payload or secret. Provider console screenshots alone
are insufficient.

## 11. Restore workflow — always isolated

1. **Declare and classify:** incident ID, scope, suspected corruption start,
   affected record families/markets and Security/Privacy involvement.
2. **Contain:** disable unsafe mutations/effects; preserve read/cancel/restriction
   paths where verified safe; revoke compromised identities.
3. **Preserve evidence:** immutable manifest, audit/log/export references,
   current configuration and no destructive cleanup.
4. **Select restore point:** compare audit, release, migration and deletion
   evidence; record expected data-loss interval against RPO.
5. **Create isolation:** restore/clone into named quarantined database/bucket with
   no mobile/public route, worker trigger or production credentials.
6. **Reconstruct controls:** indexes, Rules, IAM, TTL, flags and schemas from
   verified manifests; default all risky mutations/effects off.
7. **Validate structure:** counts, hashes, schema versions, referential checks,
   encryption/location/retention and unsupported values.
8. **Reapply privacy state:** deletion/restriction/rectification/legal-hold
   completion evidence; create audited re-deletion tasks before exposure.
9. **Domain reconcile:** each owner runs deterministic dry-run and invariant
   checks; Booking has zero oversell/duplicate/drift tolerance.
10. **Rebuild projections/effects:** use accepted source revisions; dedupe
    outbox/notifications and quarantine poison.
11. **Approve cutover:** Operations + affected domains + Security/Privacy;
    two-person approval for RC0, no console-only decision.
12. **Canary and observe:** read-only/synthetic first, then bounded safe traffic;
    verify SLO, audit, cost and no resurrection.
13. **Reopen:** mutations/effects separately by flag after exit criteria.
14. **Close:** actual RPO/RTO, loss, exceptions, evidence, postmortem and expiry/
    deletion of quarantine resources.

If isolation cannot be guaranteed, restore stops. Availability pressure does not
authorize a blind live overwrite.

## 12. Domain reconciliation contracts

| Domain | Minimum proof before reopen |
|---|---|
| Identity/Publisher | grants derive from verified source; revoked/expired access remains denied; exact page scope |
| Content publication | one active accepted revision; moderation/visibility/publisher provenance consistent |
| Booking | ledger equals active allocations/holds; usage, audit, outbox and idempotency reconcile; affected pool blocked until zero drift |
| Privacy | restriction/deletion/rectification tasks re-applied; restored projections and media covered |
| Reference/Localization | accepted immutable revision/hash; market activation and Legal copy complete; last-known-good pointer |
| Discover | feed/map/search share query/source revision and freshness; rebuild cannot become authority |
| Media | object generation/hash/owner/rights/moderation and source metadata agree; orphan quarantine |
| Notifications | obligations deduped; no duplicate user effect; dead-letter ownership visible |

Repair commands are idempotent, scoped, dry-runnable and append audited outcomes.
Direct console edits are unsupported repair.

## 13. Privacy, deletion and legal hold

- backup/PITR data is inaccessible to ordinary product/admin queries;
- restore access requires incident/purpose/case, least privilege and audit;
- subject deletion immediately blocks live access even when physical backup
  expiry is later;
- a privacy-safe completion ledger records subject scope, domain task/revision
  and completion status without copying deleted payload;
- every restore replays restriction/deletion/rectification from evidence newer
  than the selected restore point before user/public access;
- exceptional legal/security hold is explicit, scoped, time-bound, reviewable
  and never inferred from backup existence;
- quarantine/restored copies receive an expiry and deletion confirmation;
- exports beyond 14 weeks require a distinct purpose, retention, location,
  encryption, access, cost and Legal/Privacy decision.

The exact lawfulness and retention values remain BCK-04/domain decisions. This
model provides the operational enforcement path, not legal advice.

## 14. Storage media recovery policy

- original and derived/quarantine objects use separate buckets/prefix policies;
- every stored reference includes bucket/object/generation/hash and purpose;
- a successful upload is not published until object and metadata commit contract
  is satisfied;
- soft delete is the candidate accidental/malicious deletion protection for
  originals, explicitly configured rather than inherited silently;
- Object Versioning is not enabled globally; if used, lifecycle bounds number/
  age of noncurrent versions and cost is reconciled;
- derived variants are reproducible and do not receive stronger retention than
  their original/source policy;
- quarantined unsafe/illegal content is not restored to public delivery merely
  because the blob exists;
- bucket-level deletion recovery is exercised before media production.

## 15. Restore drill programme

| Drill | Frequency/trigger | Required result |
|---|---|---|
| backup metadata/control audit | daily automated; monthly owner review | schedule/policy/IAM/location/retention match manifest |
| RC0 scoped PITR recovery | quarterly | selected Booking/authority fixtures recovered/reconciled within target |
| full Firestore backup restore | quarterly before source-of-truth production; after topology/major schema change | isolated new database, controls reconstructed, representative scale within RTO |
| projection rebuild | every projection/schema major and quarterly | new revision built, parity/freshness verified, atomic switch/rollback |
| Storage object/bucket recovery | quarterly while media enabled | exact generation/hash/metadata restored; privacy/moderation preserved |
| privacy resurrection test | every full restore drill | deleted/restricted fixtures never become accessible |
| compromised-identity recovery | at least annually and after IAM redesign | revoke, break-glass, restore and evidence without reused compromised principal |

First production activation requires one complete representative full restore;
quarterly timing starts only after that proof. Drill fixtures are synthetic or
lawfully minimized; production data is not copied to dev.

## 16. Drill pass/fail contract

Pass requires all of:

- authoritative start/end timestamps and selected restore point;
- measured RPO, containment, safe/full RTO within the family target;
- no public/mobile access to quarantine;
- configuration/IAM/Rules/index/schema parity verified;
- domain invariants and privacy re-deletion pass;
- projection/effect dedupe and safe cutover/rollback pass;
- cost and resource cleanup recorded;
- named Operations/domain/Security-Privacy verdicts.

Any missing evidence, timeout, skipped reconciliation, manual assertion,
provider backup-only screenshot or unresolved invariant is **Inconclusive/Fail**,
never Pass.

## 17. Capacity and cost reconciliation

- stage uses representative document/index/object counts, not necessarily real
  personal data;
- restore duration is measured at L1 and forecast/tested for L2/L3 envelopes;
- backup/PITR/soft-delete/versioning storage and restore operations are charged
  to the owning environment/module;
- a forecast above BCK05-OD04 guardrail blocks scale/retention expansion and
  triggers architecture review, not silent RPO/RTO weakening;
- quarantine resources have TTL/owner and are deleted only after evidence hold;
- cross-location/cross-project export is not introduced only to claim DR.

## 18. Ownership and two-person controls

| Action | Accountable | Mandatory review/approval |
|---|---|---|
| protection schedule/config | Platform Operations | Privacy + affected domains + Finance |
| restore-point selection | Incident commander/Operations | affected domain + Security/Privacy |
| RC0 quarantine validation | affected domain | Operations + Security/Privacy |
| RC0 cutover/reopen | Product/Operations | two-person approval including domain authority |
| privacy re-deletion completion | Privacy Orchestration | owning domains + Security/Privacy |
| exceptional hold/export | Legal/Privacy owner | Security + Operations + owning domain |
| quarantine deletion | Operations | incident/evidence owner |

The combined Product owner may coordinate Draft preparation but is not an
independent Operations, Security or Legal verdict.

## 19. Acceptance and provisioning gates

`BCK05-OD-05` may become Accepted only when:

1. OD-07 topology/location and same-project risk are explicitly reviewed;
2. every authoritative record family has an owner/class/RPO/RTO;
3. Privacy/Legal accepts backup deletion/restriction/hold enforcement boundaries;
4. Finance/Operations accepts protection/restore cost;
5. stage completes a representative full restore within targets;
6. RC0 scoped PITR, projection rebuild, media and privacy resurrection drills pass;
7. IAM/break-glass/two-person cutover and evidence retention are approved;
8. runbooks name exact resources/commands only after provisioning is authorized;
9. failure/rollback/quarantine cleanup are proven;
10. BCK-01/02/04/05, ledger, evidence package and LAUNCH_STATUS reconcile.

After Acceptance, a separate Approved provisioning slice must still name exact
resources, commands, credentials, rollback and verification. This document is
not that slice.

## 20. Explicitly absent and unresolved

- Firestore/Storage project, database, bucket, backup, PITR or soft-delete config;
- IAM, break-glass, restore identity or executable runbook;
- stage restore, performance, cost or representative-scale evidence;
- cross-project/account compromise recovery decision;
- accepted per-family non-Booking retention/Legal conclusions;
- owner/Operations/Security/Privacy/Legal/Finance verdicts;
- production data, credentials, deployment or runtime.

## 21. Acceptance criteria

1. **BCK05-REC-AC-01:** replication and logical-data recovery remain distinct.
2. **BCK05-REC-AC-02:** provider feature/SLA does not prove Recharge RPO/RTO.
3. **BCK05-REC-AC-03:** RPO includes maximum authoritative data loss.
4. **BCK05-REC-AC-04:** RTO includes detection, validation and reconciliation.
5. **BCK05-REC-AC-05:** safe-state and full RTO remain separately measured.
6. **BCK05-REC-AC-06:** backup existence never substitutes restore proof.
7. **BCK05-REC-AC-07:** restore never blindly overwrites live authority.
8. **BCK05-REC-AC-08:** restore first enters isolated quarantine.
9. **BCK05-REC-AC-09:** quarantine has no public/mobile/worker route.
10. **BCK05-REC-AC-10:** unsafe mutations/effects are contained before restore.
11. **BCK05-REC-AC-11:** RC0 has 1-minute proposed RPO and bounded RTO.
12. **BCK05-REC-AC-12:** unsupported RC0 targets block rather than weaken.
13. **BCK05-REC-AC-13:** outbox class follows its authoritative transition.
14. **BCK05-REC-AC-14:** derived projections rebuild from authority.
15. **BCK05-REC-AC-15:** projection rebuild creates a new revision/cutover.
16. **BCK05-REC-AC-16:** Booking reconciliation has zero drift tolerance.
17. **BCK05-REC-AC-17:** domain owners execute typed repairs, not Operations edits.
18. **BCK05-REC-AC-18:** direct console edit is unsupported repair.
19. **BCK05-REC-AC-19:** privacy deletion/restriction is re-applied before access.
20. **BCK05-REC-AC-20:** restored copies receive retention/expiry/deletion proof.
21. **BCK05-REC-AC-21:** legal hold is explicit, scoped and time-bound.
22. **BCK05-REC-AC-22:** backup is not an indefinite analytics archive.
23. **BCK05-REC-AC-23:** Firestore backup restore uses a new isolated database.
24. **BCK05-REC-AC-24:** same-project compromise risk remains explicit.
25. **BCK05-REC-AC-25:** PITR/backup schedules are candidates, not enabled facts.
26. **BCK05-REC-AC-26:** every Storage bucket declares soft-delete policy.
27. **BCK05-REC-AC-27:** Object Versioning requires bounded purpose/lifecycle.
28. **BCK05-REC-AC-28:** derived media never outlives source policy silently.
29. **BCK05-REC-AC-29:** configuration/IAM/Rules/index state is reconstructed.
30. **BCK05-REC-AC-30:** secret names/versions may be evidenced, never values.
31. **BCK05-REC-AC-31:** backup evidence contains no personal payload.
32. **BCK05-REC-AC-32:** policy drift and overdue drills alert explicitly.
33. **BCK05-REC-AC-33:** first production use requires full restore proof.
34. **BCK05-REC-AC-34:** topology/schema changes trigger a new drill.
35. **BCK05-REC-AC-35:** drill Pass requires RPO/RTO plus invariants/privacy.
36. **BCK05-REC-AC-36:** timeout/skipped/screenshot-only is inconclusive.
37. **BCK05-REC-AC-37:** recovery cost cannot silently weaken safety target.
38. **BCK05-REC-AC-38:** RC0 cutover uses two-person approval.
39. **BCK05-REC-AC-39:** Acceptance and provisioning remain separate gates.
40. **BCK05-REC-AC-40:** this document creates no backup/cloud/runtime resource.
