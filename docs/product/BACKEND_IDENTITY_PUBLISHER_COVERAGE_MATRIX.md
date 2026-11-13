# BCK-06 — Identity & Publisher Coverage Matrix

- ID: **BCK-06-PRE**
- Version: **0.3**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Identity owner**
- Target: [BCK-06 v0.2](IDENTITY_PUBLISHER_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.33](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_IDENTITY_PUBLISHER_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.3 — 2026-08-25

- reconciled the matrix to BCK-06 v0.2 Review;
- recorded 22/22 Draft-design coverage, 60 sequential target AC and nine
  aligned BCK06 open decisions;
- closed the local/mock quota/Admin-preview overreach before Review;
- recorded boundary evidence: 380 Dart files, 71 existing suppressions,
  zero violations, zero stale/expired exceptions;
- retained Approval, runtime, Firebase, Legal/Privacy and owner decisions as
  independent pending gates.

### v0.2 — 2026-08-25

- reconciled the preparatory matrix to the Present BCK-06 v0.1 Draft;
- replaced the planned 0/22 state with verified 22/22 design-level coverage;
- added the ninth identity retention decision and preserved runtime Absent.

### v0.1 — 2026-08-25

- created the documentation-first source, runtime and gap audit;
- mapped all mandatory BCK-02 sections and fail-closed review prerequisites.

## 1. Verdict

`BCK-06 v0.2` is Present in Review and structurally addresses all 22 mandatory
categories. It cannot become Approved because its production dependencies,
retention/Legal evidence and owner decisions are not settled.

This matrix verifies the required 22/22 coverage, single-writer boundaries,
reconciliation rules, open decisions and fail-closed defaults for `BCK-06`.
It does not create Firebase projects, authentication providers,
claims, collections, Cloud Functions, mobile adapters, credentials or
production data processing.

## 2. Scope of the preparatory audit

Included:

1. account, provider identity and session authority;
2. server-resolved access snapshot and revocation;
3. Creator verification lifecycle;
4. Professional Page, membership and page-scoped capabilities;
5. canonical `PublisherRef` eligibility;
6. Find People consent and privacy-safe profile projections;
7. migration boundaries from historical/mock identity;
8. the exact structure and evidence required for `BCK-06 v0.2`.

Excluded:

- executable backend or mobile changes;
- provider setup, secrets, IAM or deployment;
- a numerical minors/age rule before `OD-11` is Accepted;
- vendor selection for identity verification;
- content publication, media, notification, moderation or Booking ownership;
- promotion of any parent Draft document to Approved/Accepted.

## 3. Source reconciliation

| Source | Tracked status | Binding treatment in BCK-06 |
|---|---|---|
| Accepted ADR 0013 | Accepted | Capability baseline where not superseded |
| Accepted ADR 0015 | Accepted | Mandatory authentication; Google/Apple production providers; verified Creator separated from login; canonical workspace and publisher model |
| Accepted ADR 0016 | Accepted | Bounded local/mock stabilization scope only |
| Accepted ADR 0017 | Accepted | Default fixture has zero pages; user-created local pages, quota 3 and presentation-only Admin preview in bounded scope |
| BCK-01 v0.4.28 | Review; product/cloud runtime Absent | Parent architecture, not runtime evidence |
| BCK-02 v2.4.33 | Approved semantic baseline | Registry, ownership, gates and mandatory 22-section template |
| BCK-03 v0.3.3 | Draft; runtime Absent | API envelope, typed failures and trusted-context boundary; not Approved |
| BCK-04 v0.4.16 | Draft; runtime Absent | Security/privacy baseline; exact session policy and several Legal controls unresolved |
| BCK-05 v0.2.23 | Draft; bounded R0 Pass | Platform/release input only; no product IAM authority |
| BCK-20 v0.2.2 | Draft; runtime Absent | Market, locale, timezone and reference-revision input |
| Identity/Publisher Slice v1.3 | Approved for bounded local/mock slices | Product semantics and migration input; not a production backend contract |
| S1 Auth | Historical Done evidence | Guest and email/password behavior is superseded by ADR 0015 and cannot define target runtime |
| Find People Create spec | Product/Create contract | Consent and profile-projection input; backend authority remains BCK-06 |
| OD-08 | Open | Account linking, recovery, deletion, duplicate resolution and local/mock identity mapping remain blocked |
| OD-11 | Open | No numerical age or minors eligibility may be invented; production account creation and Find People remain disabled |

Priority for conflicts is: Accepted ADR, active BCK-06 slice, BCK-02 and parent
platform standards, product specifications, then current runtime. A lower
source may provide evidence but cannot weaken a higher source.

## 4. Current implementation inventory

| Area | Present today | Target implication |
|---|---|---|
| Mobile Auth | Layered domain/data/application/presentation implementation backed by a mock remote datasource and local secure session cache | Compatibility evidence only; not production Auth |
| Sign-in methods | Demo email/password | Historical runtime debt; production target remains Google/Apple only |
| Guest state/routing | `AuthStatus.guest` and guest-flow controller behavior remain in code | Must be migrated safely; it is not target product policy |
| Identity access | Local/mock access snapshot with explicit Creator/Admin capabilities | Must never be accepted as server authority |
| Professional Pages | Local persistence, zero-page default, self-create quota 3 and idempotent pending increase request | Useful domain evidence; production command authority absent |
| Workspace switcher | Personal/page UI and presentation-only Admin experience preview | UI evidence only; client selection cannot grant access |
| PublisherRef | Shared `{user|page, id}` value is consumed by Event, Place and the common Create controller; Route still has a separate publication ref and other aggregate coverage is incomplete | Remaining Create/content reconciliation belongs to coordinated BCK-06/BCK-07/BCK-18 work |
| Find People | Typed local Create data and tests exist | Authoritative consent, eligibility and privacy-safe projection absent |
| API contracts | Booking DTO package exists; no identity API contract package surface exists | BCK-06 must define contracts before adapters |
| Backend | R0 toolchain/emulator feasibility and default-deny probes only | No product identity collections, functions, session registry or access authority |

**Runtime verdict:** local/mock capability is Present; production identity and
publisher authority is Absent.

## 5. Mandatory BCK-02 §14 coverage plan

| # | Required BCK section | BCK-06 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | BCK-06 header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; source conflicts reconciled |
| 3 | Outcome/non-goals | §3 | Full; feature-domain ownership excluded |
| 4 | Scope | §4–5 | Full at design level |
| 5 | Ownership | §6 | Full; one writer per authority family |
| 6 | Data classes/projections | §7–9 | Full at design level; numeric retention/Legal evidence open |
| 7 | Commands/queries/events/errors | §10–13 | Full semantic catalog; executable schemas absent |
| 8 | Versions/evolution/client | §14 | Full target policy; fixtures absent |
| 9 | AuthZ/revocation | §9 and §15 | Full target policy; BCK04-OD-03/runtime absent |
| 10 | Persistence/transactions | §16 | Full logical map and atomic boundaries; physical evidence absent |
| 11 | IDs/time/reference | §17 | Full |
| 12 | Idempotency/concurrency/failure | §18 | Full semantic contract; executable evidence absent |
| 13 | Offline/cache/degraded | §19 | Full; exact snapshot freshness remains BCK06-OD-05 |
| 14 | Migration/compatibility | §20 | Full fail-closed contract; OD-08/BCK-18 block execution |
| 15 | Outbox/replay/dedupe | §12 and §21 | Full semantic boundary; event transport decision/runtime absent |
| 16 | Privacy/retention/Legal | §7 and §22 | Full boundary; exact durations, OD-11 and qualified verdict absent |
| 17 | Abuse/rate/App Check/fraud | §23 | Full target controls; numeric limits/evidence absent |
| 18 | Logs/SLO/analytics/cost | §24 | Full structure; numeric SLO/cost evidence absent |
| 19 | Flags/rollout/rollback | §25 | Full; all server flags default false |
| 20 | Exact file map | §27 | Full conditional map; runtime creation not authorized |
| 21 | Test matrix | §28 | Full planned coverage; executable evidence absent |
| 22 | AC/DoR/DoD/unimplemented | §29–32 | Full; 60 unique sequential AC and explicit absent list |

**Coverage verdict:** 22/22 requirements are addressed at Draft design level;
Approval and runtime readiness are not claimed.

## 6. Reconciliation and single-writer contract

| Authority family | Single writer | Allowed consumers | Forbidden overlap |
|---|---|---|---|
| Account/provider links/session registry | BCK-06 Identity | All authenticated domains through trusted context | Flutter claims, content domains and Firebase client writes cannot grant or link identity |
| Access snapshot revision | BCK-06 Identity | API authorization and bounded mobile display | Cached client state cannot authorize a mutation |
| Creator verification decision | BCK-06 Identity | BCK-07 publication and other capability checks | Google/Apple sign-in, email or phone verification cannot imply Creator |
| ManagedPage lifecycle/membership | BCK-06 Identity | BCK-07, BCK-09, BCK-13, BCK-14, BCK-19 | Content/Booking/Admin cannot write membership directly |
| Capability vocabulary and grants | BCK-06 Identity, constrained by Accepted ADR | Backend policy evaluators | Tokens and client models cannot be the grant source |
| Active workspace selection | User preference; validated by BCK-06 on use | Mobile shell/Create defaults | Workspace selection cannot create membership or rewrite saved publisher |
| PublisherRef eligibility | BCK-06 Identity | BCK-07/content domains | Content domains store the ref but cannot establish page authority |
| Content lifecycle | BCK-07 | Discover/moderation/identity read references | BCK-06 does not publish or moderate content |
| Find People consent/profile authority | BCK-06 Identity | BCK-07/BCK-08 privacy-filtered projections | Discover cannot expose private identity fields or infer consent |
| Age/minors policy | One Accepted OD-11 policy under Security/Privacy | BCK-06/07/09/22 enforcement | No domain invents its own age threshold |
| Media objects | BCK-14 | Identity/page/profile references | BCK-06 stores verified references, not media blobs |
| Notifications | BCK-13 | BCK-06 emits transactional facts through outbox | BCK-06 does not call push/email providers inline |
| Audit/security policy | BCK-04 plus owning-domain audit records | Security/Privacy and Admin | Analytics is not audit evidence |

Rules that the full BCK-06 must preserve:

1. Server resolution, not request payload, determines actor, account state,
   Creator verification, capabilities and exact-page membership.
2. Firebase custom claims may contain only bounded coarse routing hints; page IDs,
   full capability sets and mutable membership do not belong in claims.
3. Every authoritative mutation rechecks current session, account, verification,
   capability, membership, ownership and lifecycle state.
4. A stale or unavailable access snapshot fails closed for mutations and is a
   typed stale/unavailable state, never silent permission.
5. Switching workspace changes a default for new work only; it does not mutate
   saved `PublisherRef` values.
6. Revocation is monotonic for authorization: rollback cannot resurrect a
   revoked session, grant, membership or verification.
7. Cross-document field ownership must be explicit. A consumer may cache a
   projection with source revision but may not create a second authority.

## 7. Detected reconciliation defects

| ID | Defect | Required resolution |
|---|---|---|
| BCK06-GAP-01 | Closed: `IDENTITY_PUBLISHER_BACKEND_SPEC.md v0.2` is Present in Review | Preserve runtime Absent and complete owner/qualified decisions before Approval |
| BCK06-GAP-02 | Identity slice v1.3 duplicates `IDP-AC-21…23` after `IDP-AC-25` | Accepted for BCK-06 Review as non-semantic upstream erratum: do not copy the numbering; issue a future v1.3.1 correction before cross-spec traceability is frozen |
| BCK06-GAP-03 | Identity prose previously implied preseeded pages, while ADR 0017 and later AC require zero-page default | ADR 0017 wins; default production/mock fixture is zero pages, and tests inject pages explicitly |
| BCK06-GAP-04 | S1 Auth guest/email-password behavior conflicts with ADR 0015 | Treat S1 as historical evidence only; target is mandatory Google/Apple auth |
| BCK06-GAP-05 | Mobile mock grants include privileged Creator/Admin capabilities | Mark demo-only and prohibit import or trust in R2 |
| BCK06-GAP-06 | Auth/session models are not aligned with target provider identity, access revision or revocation | Resolve through OD-08, BCK04-OD-03 and future typed contracts |
| BCK06-GAP-07 | `PublisherRef` rollout is incomplete: Event/Place share the canonical value, Route has a separate ref and other aggregate coverage is not proven | Coordinate BCK-06 eligibility with BCK-07 ownership and BCK-18 adapters; no bulk runtime change in this doc slice |
| BCK06-GAP-08 | Find People has local product data but no authoritative consent/profile projection | Define explicit consent evidence, visibility projection and server eligibility before enablement |
| BCK06-GAP-09 | Session/provider/verification/page/membership/consent retention tables are absent | Qualified Privacy/Legal review required before Approval |
| BCK06-GAP-10 | Identity outbox and event compatibility contract is absent | Reconcile BCK-03 and BCK05-OD-08 before effects |

## 8. Open decisions

| ID | Decision | Accountable owner | Blocking gate | Default while unresolved |
|---|---|---|---|---|
| BCK06-OD-01 / OD-08 | Provider linking, collision resolution, recovery, deletion and local/mock mapping | Identity owner | D2/R2 | No automatic merge/import; production account creation disabled |
| BCK06-OD-02 / BCK04-OD-03 | Session registry, maximum active sessions, TTL, refresh, device semantics and provider revocation | Identity + Security | Executable Auth slice | No production session issuance |
| BCK06-OD-03 | Creator verification evidence, provider/vendor boundary, expiry, recheck and retention | Identity + Security/Privacy + Legal | Creator production grants | Creator capabilities denied |
| BCK06-OD-04 | Page lifecycle, slug uniqueness, membership invitations, role changes and quota escalation | Identity owner | Page production mutations | Read-only disabled production surface |
| BCK06-OD-05 | Capability vocabulary, policy version and access snapshot freshness contract | Identity + API/Security | Any authoritative domain mutation | Deny when revision/freshness cannot be established |
| BCK06-OD-06 | Publisher eligibility and migration order for all ten Create types | Identity + Content + Mobile | BCK-07/BCK-18/R3 | Existing mock/local behavior only; no cloud publish |
| BCK06-OD-07 / OD-11 | Find People consent, public/protected/private profile projections and minors eligibility | Security/Privacy + Identity + Legal | Account creation, Find People and age-sensitive paths | Disabled, with no invented numerical age |
| BCK06-OD-08 / BCK04-OD-08 | Export/deletion verification, propagation, tombstone and revocation evidence | Privacy + Identity + affected domains | Production DSR | No production personal-data processing |
| BCK06-OD-09 | Identity-family retention durations, backup propagation and exceptional holds | Security/Privacy + Legal + Identity | Production personal-data processing | No production personal-data processing |

An open decision may be promoted only by a versioned owner decision record with
alternatives, exact selected value, evidence, controls, rollout, rollback and
affected-document reconciliation. Mentioning a candidate in BCK-06 does not
promote it.

## 9. Required aggregate and projection inventory

The full specification must define at least these conceptual records without
assuming Firestore shape in the domain contract:

| Family | Private authority | Allowed projection |
|---|---|---|
| Account | Provider links, lifecycle, policy acceptance, deletion state | Minimal authenticated self projection |
| Session | Registry entry, device/session metadata, auth/revocation instants | Self session list with redacted device data |
| Access | Verification, global capabilities, exact memberships, source revisions | Bounded access snapshot for current actor |
| Creator verification | Evidence references, review decision, expiry/revocation | Status/reason code without raw evidence |
| ManagedPage | Owner, lifecycle, verification, market defaults and revision | Public publisher profile only when eligible |
| Membership | Page/user relation, capabilities, lifecycle and revision | Current-user page access projection |
| Quota request | Idempotency key, requested scope, decision and audit | Self request status |
| Consent | Purpose, subject, policy version, locale/market, evidence and withdrawal | Purpose-scoped eligibility boolean/reason |
| Find People profile | Private matching inputs and safety controls | Explicit public/protected projection only |

The exact storage schema, indexes, TTLs, encryption, erasure and event payloads
remain work for the target BCK-06 and its qualified reviews.

## 10. Fail-closed baseline

Until the applicable decision is Accepted and runtime evidence passes:

- no production account creation or provider linking;
- no guest access as target behavior;
- no Creator verification grant;
- no authoritative page/membership/capability mutation;
- no production publisher eligibility decision;
- no Find People publication, matching or profile disclosure;
- no age-sensitive publication, discovery or Booking path;
- no import of mock users, demo grants, `loc_*` IDs or local page authority;
- no client-provided role, capability, membership or actor field is trusted;
- no rollback restores a revoked authority.

## 11. Conditional file plan for full BCK-06

Documentation phase:

1. `docs/product/IDENTITY_PUBLISHER_BACKEND_SPEC.md` — canonical BCK-06.
2. `docs/product/BACKEND_IDENTITY_PUBLISHER_COVERAGE_MATRIX.md` — this audit,
   updated as coverage evidence.
3. Owner decision records for §8 only when owners provide actual decisions.
4. BCK-02/BCK-01/LAUNCH_STATUS reconciliation after BCK-06 reaches a real
   lifecycle transition.

Future executable phase, conditional on Approved architecture and explicit
runtime authorization:

1. `packages/api_contracts` identity request/response/event schemas and fixtures.
2. `apps/backend` identity domain, application commands/queries, adapters and
   Firebase datasources.
3. Firestore/Storage rules and indexes owned by the applicable platform slice.
4. Mobile typed ports/adapters and migration under BCK-18.
5. Contract, emulator, security, migration and two-device evidence.

Paths in the executable phase are planning targets, not permission to create
them now.

## 12. Required test and evidence matrix

| Level | Minimum evidence before runtime Done |
|---|---|
| Domain | Account/page/membership/verification/consent lifecycle and invariant tests |
| Contract | Immutable fixtures, backward/forward compatibility and typed error tests |
| Authorization | Actor spoofing, stale grant, exact-page membership, suspended/revoked and cross-tenant denial |
| Emulator | Default-deny Rules, callable auth context, transaction and index evidence |
| Idempotency | Provider callback, page create, invite, quota, consent and deletion replay tests |
| Migration | Guest removal, duplicate provider, local/mock mapping, publisher rollout and rollback |
| Privacy | Consent withdrawal, export, deletion, retention, log-redaction and anti-enumeration tests |
| Failure | Provider outage, stale policy, outbox retry, partial failure and clock skew |
| Device | Logout/revocation and membership change observed across two devices |
| Operations | Alerts, SLO, cost, incident and rollback evidence without grant resurrection |

Passing documentation checks does not satisfy any executable evidence row.

## 13. Definition of Ready for BCK-06 Approval review

The full target document is Present in Review. It may advance to an Approval
review only when:

1. all 22 mandatory sections are present;
2. every source version/status is reverified;
3. every conflict in §7 has an explicit treatment;
4. all authority families have one writer;
5. every command/query/event/error has semantic ownership;
6. OD-08, OD-11 and BCK04-OD-03 remain visibly open or have exact owner records;
7. unresolved functions are explicitly disabled rather than silently assumed;
8. retention and Legal questions have named accountable owners;
9. the future file map remains conditional;
10. structural checks and cross-document links pass.

Review does not require executable runtime. Approval of architecture does not
itself authorize R2 implementation, cloud provisioning or personal-data
processing.

## 14. Preparatory acceptance criteria

1. **BCK-06-PRE-AC-01:** The target Draft is Present and the product backend runtime remains explicitly Absent.
2. **BCK-06-PRE-AC-02:** Accepted ADR 0015 overrides guest and email/password target behavior.
3. **BCK-06-PRE-AC-03:** Google/Apple authentication never implies Creator verification.
4. **BCK-06-PRE-AC-04:** Default fixtures contain zero Professional Pages.
5. **BCK-06-PRE-AC-05:** Local/mock grants are never importable production authority.
6. **BCK-06-PRE-AC-06:** Account/session/access has exactly one Identity writer.
7. **BCK-06-PRE-AC-07:** Page membership and capabilities have exactly one Identity writer.
8. **BCK-06-PRE-AC-08:** Client claims and request payloads cannot grant authority.
9. **BCK-06-PRE-AC-09:** Exact-page membership is resolved server-side.
10. **BCK-06-PRE-AC-10:** Stale or unavailable access state fails closed for mutations.
11. **BCK-06-PRE-AC-11:** Workspace selection cannot rewrite existing publisher identity.
12. **BCK-06-PRE-AC-12:** Revocation cannot be reversed by retry or rollback.
13. **BCK-06-PRE-AC-13:** `PublisherRef` eligibility and content lifecycle have separate writers.
14. **BCK-06-PRE-AC-14:** Find People receives only explicit privacy-safe projections.
15. **BCK-06-PRE-AC-15:** OD-11 remains Open and no numerical age is invented.
16. **BCK-06-PRE-AC-16:** Production account creation and Find People remain disabled while OD-11 is unresolved.
17. **BCK-06-PRE-AC-17:** OD-08 blocks automatic provider merge and mock-to-production mapping.
18. **BCK-06-PRE-AC-18:** BCK04-OD-03 blocks executable production session issuance.
19. **BCK-06-PRE-AC-19:** The duplicate Identity slice AC identifiers are recorded as a traceability defect.
20. **BCK-06-PRE-AC-20:** All 22 BCK-02 mandatory sections are mapped without claiming completion.
21. **BCK-06-PRE-AC-21:** The aggregate inventory separates private authority from projections.
22. **BCK-06-PRE-AC-22:** Retention, deletion and consent require qualified owner evidence.
23. **BCK-06-PRE-AC-23:** Outbox consumers cannot become identity writers.
24. **BCK-06-PRE-AC-24:** The future file map is conditional and docs-first.
25. **BCK-06-PRE-AC-25:** Documentation checks cannot be reported as runtime evidence.
26. **BCK-06-PRE-AC-26:** No Firebase, credentials, deployment, mobile runtime or `main` mutation is authorized.

## 15. Next controlled step

Prepare exact owner-decision packages for the Approval blockers without
promoting any Open decision by implication. BCK-18 preparation may begin from
the stable Review contract, but BCK-18 Approval and all executable work remain
blocked by their own dependencies. Parent status documents must report BCK-06
as Review/Present and runtime Absent.
