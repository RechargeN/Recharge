# Recharge Backend — Identity & Publisher Specification

- ID: **BCK-06**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — documentation only; approval and owner decisions pending**
- Runtime status: **Absent — local/mock mobile behavior is not backend authority**
- Accountable owner: **Identity owner**
- Required reviewers: **API Platform, Security/Privacy, Mobile Platform,
  Content Platform, Trust & Safety, Legal/Privacy for applicable decisions**
- Coordination baseline: [BCK-02 v2.4.33](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Preparatory audit:
  [BCK-06-PRE v0.2](BACKEND_IDENTITY_PUBLISHER_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/IDENTITY_PUBLISHER_BACKEND_SPEC.md`

## 0. Changelog

### v0.2 — 2026-08-25

- advanced the complete contract to Review after 22/22 coverage,
  contradiction, link, numbering and boundary validation;
- corrected the bounded ADR 0017 treatment so local quota `3` and Admin
  experience preview are not silently promoted into production policy;
- retained all nine BCK06 open decisions, BCK-03/BCK-04 dependencies,
  qualified Legal/Privacy evidence and every executable gate;
- kept runtime Absent and authorized no Firebase, credentials, deployment,
  mobile adapter, product backend or `main` mutation.

### v0.1 — 2026-08-25

- created the complete documentation-first BCK-06 contract;
- assigned one writer for account, session, access, Creator verification,
  ManagedPage, membership, capability and consent authority;
- separated workspace preference, publisher eligibility and content ownership;
- defined commands, queries, events, errors, revisions and transactions;
- preserved `OD-08`, `OD-11`, `BCK04-OD-03`, retention and provider/vendor
  decisions as explicit fail-closed blockers;
- recorded current mock/guest/email-password code as migration evidence, not
  production behavior;
- added conditional file, test, rollout and rollback plans without authorizing
  Firebase or runtime implementation.

## 1. Verdict and status meaning

This document defines the target backend authority for Recharge identity and
publisher access. It is ready for contradiction and owner review, but it is
not Approved and it creates no executable authority.

Current product facts remain:

- mobile Auth and Identity are local/mock;
- current demo sign-in and guest state are historical implementation debt;
- `apps/backend` contains R0 toolchain/emulator feasibility only;
- production account, session, Creator, Professional Page, membership,
  capability, consent and publisher decisions do not exist;
- Find People production publication/matching remains disabled.

`Draft`, `Review`, `Approved`, deployed runtime and production processing are
separate evidence states. Advancing this document does not advance another
state automatically.

## 2. Parents, priority and conflict resolution

### 2.1 Normative source order

1. Accepted ADR 0013, as superseded where explicitly stated.
2. Accepted ADR 0015 — mandatory authenticated Viewer and verified Creator.
3. Accepted ADR 0016 and ADR 0017 — bounded stabilization exceptions.
4. This active BCK-06 specification after owner Approval.
5. BCK-02 coordination, BCK-03 API, BCK-04 Security/Privacy and BCK-05
   Operations standards at their exact recorded statuses.
6. Approved product specifications, including Identity/Publisher and Find
   People.
7. Current mock/runtime evidence.

No Draft or runtime behavior may silently weaken an Accepted ADR.

### 2.2 Known reconciliations

| Conflict | Resolution |
|---|---|
| S1 Auth permits guest and email/password | Historical evidence only; ADR 0015 requires authenticated Google/Apple target behavior |
| Identity v1.3 §11.2 asks for preseeded pages | ADR 0017 and later Identity AC win: default fixture contains zero pages; tests inject pages explicitly |
| Identity v1.3 reuses `IDP-AC-21…23` | Source traceability defect; BCK-06 uses its own stable sequential AC IDs |
| Mobile mock contains Creator/Admin grants | Demo fixture only; grants are never imported or trusted in production |
| Active workspace appears to select authority | It is a validated UX preference only; server authorization is recalculated per operation |
| Page display data resembles Place/business data | ManagedPage, Place and business relationship remain different aggregates and IDs |

### 2.3 Independent document ladders

Mobile and backend document status ladders are independent. An Approved mobile
slice is product/runtime evidence for mobile only; it does not make this backend
spec Approved or authorize production processing.

## 3. Outcome and non-goals

### 3.1 Intended outcome

BCK-06 provides one auditable source for:

- linking an authenticated provider subject to one Recharge account;
- active-session and revocation decisions;
- server-resolved access snapshots;
- Creator verification lifecycle;
- Professional Page and exact-page membership authority;
- versioned capability evaluation;
- eligibility to act through a personal or page `PublisherRef`;
- purpose-specific consent and privacy-safe Find People identity projections;
- identity changes consumed safely by other backend domains.

### 3.2 Non-goals

BCK-06 does not own:

- content draft, moderation or publication lifecycle — BCK-07;
- catalog/discovery ranking and queries — BCK-08;
- Booking ledger or participation eligibility beyond identity facts — BCK-09;
- push/email delivery — BCK-13;
- media bytes/transforms — BCK-14;
- external provider integration in general — BCK-16;
- payment identity/KYC — BCK-17 and a separate Accepted ADR;
- DSR orchestration and cross-domain deletion policy — BCK-04;
- admin cases or repair approval workflow — BCK-19;
- market/reference values — BCK-20;
- moderation sanctions/appeals — BCK-22;
- a numerical age policy or Legal conclusion — `OD-11`;
- Firebase/GCP provisioning, credentials, deployment or production activation.

## 4. Scope and system boundary

### 4.1 Included authority families

| Family | BCK-06 responsibility |
|---|---|
| Account | Stable user ID, provider links, lifecycle and policy eligibility |
| Session | Registry, active/revoked/expired state and device-bounded self view |
| Access | Roles, verification, global capabilities, exact memberships and policy revisions |
| Creator verification | Submission reference, review outcome, expiry and revocation |
| ManagedPage | Owner, lifecycle, verification, defaults and public projection eligibility |
| Membership | Exact user-page relation and page-scoped capabilities |
| Page quota | Owned-page count, effective quota and increase request |
| Workspace preference | Last personal/page choice, validated on every use and never authoritative |
| Publisher eligibility | Server decision for actor, publisher, action, type, market and revision |
| Consent | Purpose, policy version, evidence and withdrawal |
| Find People identity profile | Private source and bounded public/protected projections |

### 4.2 Principals

```text
no valid session
authenticated User
verified Creator in personal context
active ManagedPage member
Admin/support principal through dedicated tool context
service identity/worker
```

`Pro` is not a role. Admin preview is not a principal, workspace, publisher or
grant.

### 4.3 Trust boundary

Provider token validation establishes a provider subject and session identity.
It does not establish Recharge roles, Creator verification, capabilities,
membership, ownership, age eligibility or publisher authority.

The backend derives trusted execution context. Payload fields such as
`actorUserId`, `role`, `isAdmin`, `creatorVerified`, `pageIds`, `capabilities`,
`membership` and `publisherEligible` are ignored or rejected as grants.

## 5. Terminology and invariants

| Term | Meaning |
|---|---|
| User | Authenticated Recharge account; Viewer is its UI/product term |
| Creator | User with Accepted additional identity verification and required grants |
| ManagedPage | Professional Page aggregate; not a Place or role |
| Membership | Exact relation between one user and one page |
| Capability | Stable versioned operation permission; role alone is insufficient |
| WorkspaceRef | Personal/page UX context selected by the user |
| PublisherRef | Persistent `{type: user|page, id}` ownership reference |
| AccessSnapshot | Bounded server-derived read projection, not a transferable grant |
| Policy revision | Immutable version of capability/consent/market policy input |

Core invariants:

1. Every production Viewer is authenticated.
2. Google and Apple are the only Accepted production sign-in providers.
3. Authentication, Creator verification and page verification are separate.
4. A personal Creator grant never implies page authority.
5. A verified page never implies membership.
6. A membership for Page A never applies to Page B.
7. Publisher identity is ID-based; names/emails/profile text never establish it.
8. Saved publisher identity is not rewritten by workspace switching.
9. Every authoritative mutation evaluates current server state.
10. Revocation is monotonic; retries and rollback cannot restore authority.
11. Temporary `loc_*` IDs never cross an authoritative backend boundary.
12. Unknown policy, stale authority or ambiguous identity fails closed.

## 6. Ownership and single-writer matrix

| Record/decision | Single writer | Readers | Forbidden writers |
|---|---|---|---|
| Account/provider link | BCK-06 Identity | Auth gateway, Privacy, Support | Mobile, content, Booking |
| Session registry | BCK-06 Identity | Auth middleware, self query, Security | Client token claims, domains |
| Access policy/snapshot revision | BCK-06 Identity | All protected backend entrypoints | Mobile cache, Remote Config |
| Creator verification | BCK-06 Identity | Content and capability evaluators | Provider sign-in, client, page |
| ManagedPage/membership | BCK-06 Identity | Content, Booking, Media, Admin | Domain feature writers |
| Workspace preference | BCK-06 user-preference command | Mobile shell/Create default | Authorization middleware |
| Publisher eligibility | BCK-06 evaluator | BCK-07 and other owning domains | Content payload assertions |
| Content ownership/lifecycle | BCK-07 | Identity reads opaque refs where needed | BCK-06 |
| Consent evidence/profile source | BCK-06 Identity | Privacy and approved projection builders | Discover/search clients |
| Age policy | Accepted OD-11 policy | BCK-06/07/09/22 evaluators | Individual domains |
| DSR case | BCK-04 Privacy Orchestration | BCK-06 deletion worker | BCK-06 public API |
| Media object | BCK-14 | Identity stores opaque media reference | BCK-06 byte storage |
| Notifications | BCK-13 | BCK-06 outbox facts | Inline provider calls |

## 7. Data classification and projection contract

BCK-04 classification vocabulary applies per record content. Labels such as
`private` or `audit` below describe purpose, not a new classification enum.

| Record family | Minimum class | Authority fields | Allowed client projection |
|---|---|---|---|
| Account | Protected; Sensitive when eligibility/evidence is present | provider links, lifecycle, policy states | own account ID, safe lifecycle/reason, display settings |
| Session | Protected | opaque session ID/hash, times, revocation, device/risk metadata | self device label, created/last-active time, current flag, status |
| AccessSnapshot | Protected | role/capability/membership/policy source revisions | bounded current-user snapshot with expiry/freshness |
| CreatorVerification | Sensitive | evidence refs, reviewer/provider, decision, reason, expiry | status, safe reason code, next allowed action |
| ManagedPage | Protected plus Public projection | owner, lifecycle, verification, revision | eligible public publisher card; owner/member management view |
| Membership | Protected | user ID, page ID, lifecycle, capability IDs, revision | current user's exact-page access only |
| Quota request | Protected | requested quota, decision, audit refs | own request status and safe reason |
| Consent | Sensitive or Protected by purpose | purpose, policy version, market, locale, evidence, withdrawal | own status and policy reference |
| Find People profile source | Sensitive | matching/safety inputs and restricted contact data | explicit public/protected projection only |
| Audit/idempotency/outbox | Operational, possibly Protected/Sensitive by payload | opaque IDs, reason codes, revisions | never general client data |

Projection rules:

- public page/profile fields are allowlisted; absence is the default;
- raw verification evidence, provider subject, DOB/age evidence, risk signals,
  session secrets, private contact and membership graph never enter public
  projections;
- every projection includes schema version, source revision and freshness where
  material;
- consent withdrawal or authority revocation invalidates dependent projections;
- a consumer may cache a projection, but it never becomes a second writer.

## 8. Domain records and lifecycle

### 8.1 Account

```text
eligibilityPending | active | restricted | suspended | deletionPending | deleted
```

- one permanent ULID/UUID `userId` identifies the Recharge account;
- provider subjects are stored as protected links and never used as public IDs;
- production creation remains disabled until `OD-11` supplies an Accepted
  applicable market policy;
- `deleted` is terminal for access; any exceptional retained audit uses a
  pseudonymous reference under approved policy.

### 8.2 Provider link

```text
pending | active | disabled | unlinked
```

A unique provider+subject may map to at most one non-deleted account. Automatic
merge is forbidden while `OD-08` is Open. Email equality is never proof that
two provider identities belong to one person.

### 8.3 Session

```text
active | revoked | expired
```

The baseline permits at most three active account sessions. Exact TTL, refresh,
device semantics and provider-revocation behavior remain `BCK04-OD-03`.
Session tokens are not stored in plaintext application records.

### 8.4 Creator verification

```text
notStarted | pending | verified | rejected | expired | revoked
```

`verified` requires an authoritative, auditable decision under an Accepted
verification policy. Page verification is a different state machine. Safe
reason codes are bounded; raw evidence is never returned to ordinary clients.

### 8.5 ManagedPage

Lifecycle:

```text
pendingReview | active | suspended | archived
```

Verification:

```text
unverified | pending | verified | rejected | revoked
```

The two dimensions do not imply each other. Creation assigns a permanent page
ID, explicit owner and owner membership atomically. The accepted bounded
local/mock self-service quota is three; it is not silently promoted into a
production quota. Production quota values and escalation require
`BCK06-OD-04`, an active versioned policy and an authoritative approved
request. Delegated memberships never count as owned pages.

### 8.6 Membership

```text
invited | active | suspended | revoked
```

Membership contains exact `userId`, `pageId`, lifecycle, capability IDs and
revision. Owner membership cannot be silently removed if it would leave an
active page without a valid owner; transfer rules require an explicit future
decision and audited command.

### 8.7 Capability policy

Minimum publish semantics inherited from the Identity product spec:

```text
create.<type>
submit.<type>
publish.<type>.direct
manage_page
view_insights
manage_bookings
```

The full versioned registry, implications and page-scoped create/submit/publish
codes are `BCK06-OD-05`. Current local/mock code also contains `page.create`
and `admin.experience.preview`; this is implementation evidence, not an
Accepted production registry. If retained, `admin.experience.preview` permits
only the bounded presentation preview defined by ADR 0017 and grants no domain
operation. Unknown capability IDs never grant access.

### 8.8 Workspace preference

```text
personal | page:<pageId>
```

The server validates the selected page against current access. Missing or
revoked access returns a typed fallback to personal while preserving saved
draft publisher data for explicit reconciliation.

### 8.9 Consent and Find People profile

Consent is purpose-specific and versioned. Granting one purpose cannot imply
another. Withdrawal is effective for new processing immediately at the
authority and propagates through auditable deletion/invalidation work.

Find People keeps a private source separate from:

- public discovery profile;
- authenticated/protected matching profile;
- accepted-relationship contact projection.

Exact purpose IDs, fields and age eligibility require the BCK-06/Find People
contract and Accepted `OD-11`; all production paths remain disabled until then.

## 9. AccessSnapshot and authorization evaluation

Logical snapshot:

```text
schemaVersion
userId
accountLifecycle
roles[]
creatorVerificationStatus
globalCapabilityIds[]
pageAccess[] {
  pageId
  membershipLifecycle
  membershipRevision
  pageLifecycle
  capabilityIds[]
}
policyRevision
sourceRevision
generatedAtUtc
freshUntilUtc
```

Rules:

1. Snapshot is generated server-side from current authoritative records.
2. Firebase custom claims do not contain page IDs or the full mutable
   capability/membership graph.
3. A client snapshot is for UI planning only.
4. Each mutation resolves or revalidates current access; `sourceRevision` and
   `policyRevision` are checked where supplied.
5. Suspension/revocation increments the affected access revision and invalidates
   caches.
6. Unknown, expired or unavailable snapshot is typed `access_snapshot_stale` or
   `access_authority_unavailable` and fails closed.
7. Query denial uses anti-enumerating behavior; foreign resource existence is
   not disclosed.

Authorization formula:

```text
valid session
+ active account
+ current verification where required
+ exact global capability
+ exact active page membership/capability where required
+ resource ownership/lifecycle
+ market/policy eligibility
= allow
```

Any missing operand is deny.

## 10. Command catalog

All commands use the BCK-03 envelope, client/request correlation,
`idempotencyKey`, versioned payload and `expectedRevision` where applicable.

| Command | Caller | Transaction result | Notes |
|---|---|---|---|
| `identity.ensureAccount` | Trusted auth adapter | Existing account or one new eligible account | Disabled until OD-08/OD-11 and Auth gates; provider subject server-derived |
| `identity.linkProvider` | Active user with recent re-auth | New provider link | No email-based auto merge; OD-08 |
| `identity.unlinkProvider` | Active user with recent re-auth | Provider link disabled/unlinked | Cannot remove last usable provider without approved recovery path |
| `identity.revokeSession` | Account owner or privileged audited security action | Exact session revoked | Current-session handling explicit |
| `identity.revokeOtherSessions` | Account owner with recent re-auth | Other active sessions revoked | Idempotent set operation |
| `identity.submitCreatorVerification` | Active eligible user | Verification becomes pending | Evidence is protected reference, not client grant |
| `identity.cancelCreatorVerification` | Applicant where policy permits | Terminal/cancelled product outcome or reset | Does not erase required audit |
| `identity.decideCreatorVerification` | Dedicated privileged reviewer/service | Verified/rejected with audit | Never ordinary mobile/Admin preview |
| `identity.createManagedPage` | Verified Creator with the Accepted page-create capability | Page + owner membership + revisions | Active production quota checked atomically; page begins pending review |
| `identity.updateManagedPage` | Exact-page member with `manage_page` | Page revision incremented | Public projection updated asynchronously |
| `identity.archiveManagedPage` | Authorized owner/member | Page archived and access recalculated | Does not delete content authority records silently |
| `identity.decidePageVerification` | Dedicated privileged reviewer | Verification state and audit | Separate from Creator verification |
| `identity.invitePageMember` | Exact-page `manage_page` | One invitation/membership record | Anti-abuse and recipient privacy rules apply |
| `identity.acceptPageInvite` | Exact invited user | Membership active | Invite secret/reference is single-use and bounded |
| `identity.declinePageInvite` | Exact invited user | Invite terminal | No page data beyond safe preview |
| `identity.changePageMemberCapabilities` | Exact-page authorized manager | Membership revision incremented | Cannot self-escalate or grant unknown codes |
| `identity.revokePageMembership` | Authorized manager or self where allowed | Membership revoked | Owner safety invariant enforced |
| `identity.requestPageLimitIncrease` | Verified Creator at quota | One pending request | Same active request replays original result |
| `identity.decidePageLimitIncrease` | Dedicated privileged reviewer | Approved/rejected request and quota revision | Production decision not part of local mock preview |
| `identity.setWorkspacePreference` | Active user | Validated preference or personal fallback | Never changes authorization or existing publisher refs |
| `identity.grantConsent` | Eligible subject | Versioned consent evidence | Purpose/market/policy exact; OD-11 where applicable |
| `identity.withdrawConsent` | Subject | Consent withdrawn + invalidation event | New dependent processing fails immediately |
| `identity.upsertFindPeopleProfile` | Eligible consented user | Private source revision | Production disabled until OD-11 and projection contract |
| `identity.deleteFindPeopleProfile` | Profile owner/Privacy directive | Source unavailable + deletion work | Does not erase required restricted audit |
| `identity.applyDeletionDirective` | BCK-04 trusted service | Identity records restricted/deleted per plan | Internal only; DSR case remains BCK-04-owned |

Privileged decisions require a dedicated tool/service context, reason code,
case/reference, current policy revision and append-only audit. Admin role alone
is insufficient.

### 10.1 Required semantic payload boundaries

The registered schema owns exact field names and bounds. At minimum:

| Command family | Required semantic input | Explicitly not accepted as authority |
|---|---|---|
| Account ensure/link | permanent proposed ID where allowed, market/policy revisions, provider flow reference | provider subject copied from client, email-match decision, role/capability |
| Session revoke | opaque session ID or explicit `others` scope, current account revision where applicable | raw token, foreign user ID |
| Verification submit/decide | policy revision, protected evidence reference or review case, expected revision, bounded reason code | raw document in command/log, client `verified=true` |
| Page create/update | permanent page ID, display fields, market/country/locale/timezone/currency, expected revision/policy | owner/membership/grant assertion |
| Membership/invite | permanent page/invite ID, intended subject reference through approved private channel, capability IDs, expected revision | arbitrary capability, email as membership proof |
| Quota request/decision | permanent request ID, requested scope, policy/expected revision, review reason | effective quota written by client |
| Workspace preference | `personal` or exact page ID | role, membership or publisher rewrite instruction |
| Consent | purpose ID, policy revision, market, notice locale and explicit user action evidence | bundled/all-purpose consent or inferred acceptance |
| Find People profile | schema version, expected revision, purpose/consent revision and bounded profile fields | raw authority, hidden consent or unrestricted contact projection |
| Deletion directive | BCK-04 case/directive ID, exact scope and policy revision from trusted service | ordinary mobile request presented as approved directive |

All protected transport fields are schema-bounded and redacted from logs.
Server-generated lifecycle, audit, actor and commit-time fields are rejected if
the client attempts to set them.

## 11. Query catalog

| Query | Caller | Result/freshness |
|---|---|---|
| `identity.getMyAccount` | Active/current user | Safe self projection + resource revision |
| `identity.listMySessions` | Account owner with step-up where required | Redacted session list + snapshot time |
| `identity.getAccessSnapshot` | Active user/backend adapter | Bounded snapshot + source/policy revision + freshness |
| `identity.getCreatorVerificationStatus` | Applicant | Status, safe reason and allowed next action |
| `identity.listMyManagedPages` | Active user | Exact accessible page summaries and membership revisions |
| `identity.getManagedPageManagementView` | Exact member | Management projection permitted by capability |
| `identity.getPublicPublisherProfile` | Authenticated eligible viewer | Allowlisted active public projection or anti-enumerating absence |
| `identity.listPageMembers` | Exact-page authorized member | Paginated bounded membership projections |
| `identity.getPublisherEligibility` | Active Creator/domain service | Eligible personal/pages for content type/action/market with policy revision |
| `identity.getConsentStatus` | Subject | Purpose/policy/version/status; no raw evidence |
| `identity.getMyFindPeopleProfile` | Owner | Private self view plus projection status |
| `identity.getFindPeopleProjection` | Approved BCK-08/service consumer | Purpose-limited projection with consent/source revision |

Queries are side-effect-free. Pagination uses stable ordering and cursor tied to
the same query/projection revision. A newer source during pagination returns a
typed stale/inconsistent state rather than silently mixing snapshots.

## 12. Events and consumers

Event names are past tense, immutable and versioned. They use BCK-03 OD-09
semantics only after the event/outbox decision is Accepted.

| Event | Producer | Primary consumers |
|---|---|---|
| `identity.accountCreated` | BCK-06 | Privacy inventory, BCK-13 notification |
| `identity.accountLifecycleChanged` | BCK-06 | All protected domains/cache invalidation |
| `identity.sessionRevoked` | BCK-06 | Auth gateway, Security |
| `identity.accessRevisionChanged` | BCK-06 | API cache invalidation, Mobile sync hint |
| `identity.creatorVerificationChanged` | BCK-06 | BCK-07 eligibility, BCK-13 |
| `identity.managedPageCreated` | BCK-06 | BCK-13, BCK-19 review case |
| `identity.managedPageChanged` | BCK-06 | Content/media publisher projection rebuild |
| `identity.pageMembershipChanged` | BCK-06 | Access invalidation, BCK-13 |
| `identity.pageQuotaRequestChanged` | BCK-06 | BCK-13, BCK-19 |
| `identity.consentChanged` | BCK-06 | Projection invalidation and Privacy evidence |
| `identity.findPeopleProfileChanged` | BCK-06 | BCK-08 projection builder |
| `identity.deletionApplied` | BCK-06 | BCK-04 DSR reconciliation |

Producer transaction writes authority change, audit, idempotency result and
outbox record atomically. Delivery is at least once; consumers deduplicate by
`eventId + consumerName + consumerVersion`, reject unknown major versions and
never become identity writers.

No email, push, moderation or search call occurs inline with an identity
transaction.

## 13. Result and error vocabulary

BCK-03 outcomes apply:

```text
success | cancelled | failure
```

`cancelled` is a terminal non-success user/product outcome, not an error.

| Domain code | Common code | Safe meaning |
|---|---|---|
| `account_not_active` | `failed_precondition` | Current account cannot perform operation |
| `account_creation_disabled` | `failed_precondition` | Production creation gate is closed |
| `provider_not_supported` | `invalid_argument` | Provider is outside supported registry |
| `provider_already_linked` | `conflict` | Current operation conflicts with an existing protected link |
| `provider_collision_requires_review` | `failed_precondition` | No automatic merge is allowed |
| `recent_auth_required` | `failed_precondition` | Step-up/re-auth is required |
| `session_revoked` | `unauthenticated` | Current session is no longer active |
| `session_limit_reached` | `failed_precondition` | Session policy blocks issuance |
| `creator_verification_required` | `failed_precondition` | Creator-only operation is unavailable |
| `creator_verification_pending` | `failed_precondition` | Decision is pending |
| `creator_verification_expired` | `failed_precondition` | Reverification is required |
| `page_limit_reached` | `failed_precondition` | No page is created; request path may be offered |
| `page_membership_required` | `not_found` or `permission_denied` | Anti-enumerating exact-page denial |
| `page_membership_inactive` | `failed_precondition` | Known own membership cannot authorize |
| `capability_required` | `permission_denied` | Required stable capability is absent |
| `page_not_eligible` | `failed_precondition` | Page lifecycle/policy blocks action |
| `publisher_selection_required` | `failed_precondition` | Multiple/no implicit publisher choice |
| `publisher_not_eligible` | `failed_precondition` | Selected publisher cannot perform action |
| `access_snapshot_stale` | `stale_revision` | Client/access revision must refresh |
| `access_authority_unavailable` | `unavailable` | Current authority cannot be established |
| `consent_required` | `failed_precondition` | Purpose-specific consent is absent |
| `consent_withdrawn` | `failed_precondition` | Dependent processing is disabled |
| `age_policy_unavailable` | `failed_precondition` | Applicable OD-11 policy is not Accepted/available |
| `eligibility_not_satisfied` | `failed_precondition` | Safe policy outcome denies action |
| `invite_not_actionable` | `not_found` | Invalid/expired/foreign invite without enumeration |
| `quota_request_pending` | `conflict` | Existing pending request is returned safely |

Common `invalid_argument`, `idempotency_conflict`, `rate_limited`,
`unsupported_client`, `unsupported_contract`, `unsupported_schema`,
`deadline_exceeded`, `internal` and `stale_revision` retain BCK-03 meaning.
Errors contain no provider subject, raw evidence, DOB, email existence,
membership graph, collection path or reviewer notes.

## 14. Versioning and client compatibility

Distinct versions must not be conflated:

| Version | Purpose |
|---|---|
| `contractVersion` | Common BCK-03 envelope major |
| `commandVersion` / `queryVersion` | Operation payload semantics |
| `schemaVersion` | Persisted record/projection shape |
| `resourceRevision` | Optimistic concurrency for one aggregate |
| `accessSnapshotRevision` | Actor authority projection source revision |
| `capabilityPolicyRevision` | Capability registry and implication semantics |
| `consentPolicyRevision` | Exact purpose/notice/market policy |
| `agePolicyRevision` | Accepted OD-11 market policy |
| `referenceRevision` | BCK-20 market/locale/timezone inputs |

Compatibility rules:

- additive optional fields require safe defaults and fixture evidence;
- new required field, enum removal or semantic change requires a new major;
- unknown enum is preserved/typed unsupported, never coerced into privilege;
- unknown capability, policy or major version fails closed;
- minimum supported client comes from server platform policy and returns
  `unsupported_client` with approved update metadata;
- old clients may retain safe read/export/logout paths but cannot bypass new
  eligibility or revocation policy;
- every cross-domain event declares event type/version and aggregate revision.

## 15. Authentication, authorization and revocation

### 15.1 Authentication

- Google/Apple only for production;
- no anonymous/guest product session;
- provider verification occurs at trusted Auth adapter;
- provider token and App Check are transport/security signals, not grants;
- account creation/link/unlink requires OD-08 and applicable OD-11 policy;
- sensitive commands require risk-based recent re-auth/step-up;
- service identities are separate least-privilege principals.

### 15.2 Authorization

Every mutation checks current session, account, verification, global
capability, exact membership, resource ownership/lifecycle and policy.
Privileged review additionally requires dedicated tool context, capability,
case/reason and audit.

### 15.3 Revocation

Revocable authorities:

- session;
- provider link/account;
- Creator verification;
- global capability;
- page lifecycle/verification;
- membership/page capability;
- consent and Find People projection;
- market/policy eligibility.

Revocation increments a source revision, invalidates dependent caches and emits
an outbox fact when available. Until propagation is confirmed, authoritative
mutations still deny from source state. A mobile cached snapshot can become
stale but cannot extend authority.

## 16. Persistence, indexes and transaction boundaries

### 16.1 Logical record families

Future physical mapping must preserve these independently addressable records:

```text
accounts/{userId}
providerLinks/{providerSubjectKey}
sessions/{sessionId}
accessSnapshots/{userId}
creatorVerifications/{userId}
managedPages/{pageId}
pageMemberships/{pageId_userId}
pageQuotaRequests/{requestId}
workspacePreferences/{userId}
consents/{userId_purposeId}
findPeopleProfiles/{userId}
identityIdempotency/{scopeKey}
identityOutbox/{eventId}
identityAudit/{auditId}
```

Names are target logical paths. Final physical collections, partitions and
indexes require the executable slice and security/rules review.

`providerSubjectKey` is an opaque lookup key derived through an approved
secret-keyed construction; it is never the raw provider subject or email. Key
rotation, encryption and secret ownership follow BCK-04/BCK-05 and require
executable security review.

### 16.2 Required uniqueness/index semantics

| Need | Required enforcement |
|---|---|
| Provider subject uniqueness | Unique provider+subject key to one account |
| Session listing | `userId + state + lastActiveAtUtc` bounded index |
| Exact membership | Direct `pageId + userId` lookup; never name/email query |
| My pages | `userId + membership lifecycle + pageId` projection/index |
| Owned-page quota | Authoritative counter or transactionally checked ownership set |
| Pending quota request | At most one actionable request per user/policy scope |
| Consent | Exact `userId + purposeId + policyRevision/active` lookup |
| Find People projection | Only approved privacy-filtered query fields; no raw profile scan |
| Outbox | status/availableAt/lease with bounded retry indexes |

### 16.3 Atomic transactions

The following changes are atomic within their authority boundary:

1. ensure account + provider link + audit + idempotency + outbox;
2. create page + owner membership + owned quota usage + access revision +
   audit + idempotency + outbox;
3. verification decision + role/capability effect + access revision + audit +
   idempotency + outbox;
4. membership/capability mutation + access revision + audit + idempotency +
   outbox;
5. quota decision + effective quota revision + audit + idempotency + outbox;
6. consent change + source revision + projection invalidation marker + audit +
   idempotency + outbox;
7. session revocation + access/session revision + audit + idempotency.

Cross-domain side effects are eventual through outbox and never make an
identity authority transaction partially successful.

## 17. IDs, time and reference data

- all domain IDs are ULID/UUID and opaque;
- clients may generate permanent IDs only for explicitly allowed create
  commands; provider subjects, session IDs and audit IDs remain server-owned;
- `loc_*` identifiers are rejected at backend boundaries;
- relationships use IDs only, never names or email;
- instants are UTC RFC 3339 with millisecond precision where supported;
- calendar interpretation uses explicit IANA timezone from BCK-20 inputs;
- market, country, locale, currency and timezone use stable IDs/codes plus
  reference revision;
- provider time never overrides authoritative backend commit time;
- clock skew affects telemetry, not lifecycle authorization;
- unknown market/reference/policy revision fails closed for mutation.

## 18. Idempotency, concurrency, retry and partial failure

### 18.1 Idempotency

BCK-03 scope applies:

```text
actor/service identity + command type/version + idempotency key
```

Canonical semantic hash excludes token, transport headers, retry count,
correlation ID and request ID. Same key/same hash returns the original semantic
result; same key/different hash returns `idempotency_conflict` without mutation.

Provider callbacks additionally bind verified provider and provider event ID.

### 18.2 Concurrency

- lifecycle, ownership, membership, capabilities, consent and verification use
  optimistic revision checks;
- stale expected revision returns typed `stale_revision`;
- last-write-wins is forbidden for authority;
- page quota is checked in the page-create transaction;
- concurrent invite/accept/revoke resolves to one legal state transition;
- access snapshot revision is not used as aggregate revision.

### 18.3 Retry and unknown outcome

- bounded retry reuses exact idempotency key and semantic payload;
- timeout after send is unknown outcome, not local failure;
- client queries by key/result or safely retries;
- no offline mutation is shown as server-confirmed;
- partial cross-domain effects remain pending/retryable outbox work;
- poison effects are quarantined and alerted, never converted into authority
  success or silently dropped.

## 19. Offline, cache, freshness and degraded behavior

| Data | Offline/cache policy |
|---|---|
| Account self projection | May be displayed with explicit stale state; no mutation authority |
| AccessSnapshot | Short-lived UI hint only; exact TTL is BCK06-OD-05/BCK04-OD-03 |
| ManagedPage summaries | Cache with source revision; missing current authority disables actions |
| Workspace preference | Local-first preference allowed; server validates page on use |
| Creator verification | Cached display allowed with freshness; submit/publish checks server |
| Consent | Cached display is non-authoritative; withdrawal requires confirmed command or explicit pending state |
| Find People profile | Private local draft allowed; never publicly visible until confirmed eligible server projection |

If Identity authority is unavailable:

- existing safe cached UI may remain readable and labelled stale;
- protected mutations, publishing, page switching with authority implications,
  consent-dependent processing and Find People enablement fail closed;
- logout may clear local material even when server revocation is pending, while
  showing the server outcome honestly;
- recovery never invents a successful grant.

## 20. Migration, import and compatibility

### 20.1 Sources requiring migration

- S1 guest routing and `AuthStatus.guest`;
- demo email/password Auth datasource;
- local secure session model;
- local mock Creator/Admin grants;
- locally created pages, memberships and quota requests;
- aggregate-specific or missing publisher fields;
- separate Route publisher representation;
- Find People local profile/draft data.

### 20.2 Migration contract

1. Inventory local records without uploading them.
2. Establish an eligible production account through Accepted provider/policy
   flow; never map by email alone.
3. Produce an explicit preview of importable, non-importable and conflicting
   records.
4. Replace `loc_*` with permanent IDs before any accepted import.
5. Import only user-owned safe drafts/data through versioned idempotent
   commands; never import roles, verification, capabilities, memberships,
   page approval, quota approval, consent or audit authority.
6. Resolve missing publisher as `publisherSelectionRequired`; never infer page
   from organizer/business text.
7. Preserve original local record and provenance until confirmed reconciliation
   and user-visible rollback window under an Accepted policy.
8. Record mapping, source version, result and reason without sensitive payload.

Exact provider linking, duplicate handling, recovery, deletion and mapping are
blocked by `OD-08`. Exact mobile orchestration belongs to BCK-18.

### 20.3 No dual authority

Shadow reads/comparison may observe local and server states, but only one source
authorizes a mutation. Rollout cannot alternate between mock grant and backend
grant based on availability.

## 21. Outbox, replay and deduplication

Until BCK03/BCK05 event transport decisions are Accepted, events in §12 are
semantic contracts only.

When executable:

- authority record, audit, idempotency and outbox are committed atomically;
- event carries opaque IDs, event/schema version, aggregate revision,
  occurred-at backend time, correlation and causation IDs;
- raw evidence, contact, DOB, token or unrestricted profile is excluded;
- consumers dedupe and checkpoint;
- revision gap/out-of-order event triggers replay/reconciliation, not blind
  application;
- replay is bounded, privileged and audited;
- dead-letter diagnostic payload follows BCK-04 minimization/retention;
- notification/search/content effects can fail without rolling back committed
  identity authority.

## 22. Privacy, retention, Legal and DSR

### 22.1 Purpose limitation

Each protected/sensitive field requires a documented purpose, legal basis,
visibility, retention trigger, deletion/anonymization action and responsible
owner. Creator verification evidence cannot be reused for Find People, payment
or marketing eligibility without a separately approved basis.

### 22.2 Retention proposal status

There is no generic numeric retention inherited from the data class. Before
production processing, qualified owners must approve exact values for:

| Record | Lifecycle trigger | Required terminal action |
|---|---|---|
| Provider link/account | unlink/deletion/legal state | delete or pseudonymize subject link per recovery/legal policy |
| Session | revoke/expire | delete secret material; retain only approved minimal security evidence |
| Creator evidence | decision/expiry/revocation | delete provider/raw evidence under exact policy; retain safe decision audit if lawful |
| ManagedPage/membership | archive/revoke/delete | remove private access data and public projection; reconcile owned content |
| Invite/quota request | terminal/expired | delete contact/token payload; retain bounded decision evidence if approved |
| Consent | withdrawal/policy supersession | retain only lawful proof/withdrawal evidence; stop dependent processing |
| Find People source/projection | withdrawal/delete/ineligible | disable projection immediately and delete/pseudonymize source per policy |
| Idempotency/outbox/log/audit | safe retry/effect/security window | delete, aggregate or restrict according to exact record family |

This table defines triggers/actions, not approved durations. Numeric retention,
backup propagation and exceptional holds are `BCK06-OD-09` with
Security/Privacy/Legal and BCK-04.

### 22.3 OD-11

While OD-11 is Open:

- no numerical minimum age is stated here;
- production account creation is disabled;
- Find People publication, matching and contact disclosure are disabled;
- age-sensitive content/Booking paths are disabled;
- unknown market or policy revision denies processing;
- local/demo labels cannot be presented as Legal eligibility.

An Accepted OD-11 must be versioned per market and define applicable account,
consent, guardian, age-restricted classification, verification and disclosure
rules with qualified evidence.

### 22.4 DSR

BCK-04 owns the rights-request case and orchestration. BCK-06 must:

- verify only the domain directive/service context, not invent a second case;
- export identity data in versioned machine-readable form with protected access;
- restrict access promptly at approved deletion start;
- propagate delete/pseudonymize instructions to owned identity records and
  projections;
- reconcile page/content ownership before deletion, never orphan or silently
  transfer it;
- return per-family completion/failure evidence to BCK-04;
- preserve only approved legal/security holds with owner, reason and expiry.

## 23. Abuse, rate limiting, App Check and fraud controls

| Surface | Required controls |
|---|---|
| Account/link/recovery | Provider verification, anti-enumeration, risk/step-up, collision review, bounded attempts |
| Sessions | Token validation, device/risk signals, active-session limit, revoke-all, anomaly alerts |
| Creator verification | Submission/retry bounds, evidence integrity, reviewer separation, vendor callback verification |
| Page create/quota | Quota transaction, idempotency, rate limits, abuse/moderation handoff |
| Membership invite | Exact-page authority, recipient privacy, single-use bounded invite, spam limits |
| Capabilities | Allowlisted policy revision, no arbitrary strings, privileged audit |
| Consent/profile | Purpose exactness, withdrawal, scraping resistance, projection minimization |
| Find People | OD-11, consent, block/sanction integration, discovery/query limits and anti-enumeration |

App Check is required for applicable mobile endpoints after approved rollout but
never replaces AuthN/AuthZ. Missing/invalid App Check fails according to
BCK-04 rollout policy; there is no client bypass header. Exact numeric rate
limits and risk thresholds require evidence and owner decision before runtime.

## 24. Logs, audit, SLO, analytics and cost

### 24.1 Audit

Audit events include opaque actor/service ID, operation, target opaque ID,
before/after state codes or revisions, policy revision, reason/case where
required, time, correlation and outcome. They exclude raw tokens, provider
payload, verification evidence, DOB, contact text and unrestricted profile.

Privileged reads of sensitive verification/profile data are themselves audited.
Audit is append-only and not a product analytics stream.

### 24.2 Operational indicators

Required indicators:

- provider sign-in/link success/failure by safe reason;
- account ensure latency and collision-review rate;
- session validation/revocation latency and stale-session denial;
- access snapshot build/cache hit/stale/denial rate;
- verification and page-review queue age;
- membership/capability mutation latency and denial reasons;
- consent withdrawal-to-projection-disable lag;
- outbox age/retry/dead-letter count;
- DSR identity-family completion/failure;
- unauthorized/cross-page/anti-enumeration negative-test alerts.

Exact SLO/error budgets and paging thresholds belong to BCK-05 owner review.

### 24.3 Analytics

Product analytics receives bounded event names, coarse state and pseudonymous
IDs only. It never receives provider subject, membership graph, evidence,
private profile, consent proof or capability list. Analytics failure never
changes domain outcome.

### 24.4 Cost

Before production, measure reads/writes and fan-out for session validation,
access snapshots, exact membership lookup, projection rebuild, audit,
idempotency and outbox. No optimization may replace exact authorization with a
stale permissive cache.

## 25. Flags, rollout, rollback and emergency disable

Server-owned target flags, all `false` until their gates pass:

```text
identity.productionAuthEnabled
identity.accountCreationEnabled
identity.providerLinkingEnabled
identity.creatorVerificationEnabled
identity.managedPageMutationsEnabled
identity.publisherAuthorityEnabled
identity.findPeopleProfileEnabled
identity.findPeopleDiscoveryEnabled
```

Flags are typed, environment/market scoped, revisioned and audited. Mobile
Remote Config or local state cannot enable server authority.

Rollout order:

```text
contracts and fixtures
-> emulator/default-deny evidence
-> provider sandbox and session authority
-> account mapping dry run
-> staff/internal cohort
-> Creator verification and page authority
-> PublisherRef adapters/content integration
-> consent/profile projection
-> Find People only after OD-11 and safety gates
-> Latvia cohort
```

Rollback:

1. disable affected mutation flag;
2. preserve committed authority, idempotency and audit;
3. drain/quarantine compatible outbox work;
4. keep revoke/deny decisions effective;
5. revert client routing/adapters only through compatible contract;
6. never restore guest mode, mock grant, revoked session or revoked membership;
7. reconcile before re-enable.

Emergency disable must support provider, account creation, verification, page
mutation, publisher and Find People surfaces independently.

## 26. Open decisions and blockers

| ID | Status | Decision/owner | Blocks | Fail-closed default |
|---|---|---|---|---|
| OD-08 / BCK06-OD-01 | Open | Provider linking, collision, recovery, deletion and local mapping — Identity | D2/R2 | No merge/import/account creation |
| BCK04-OD-03 / BCK06-OD-02 | Open | Session/token TTL, refresh, device/provider revocation — Identity + Security | Executable Auth | No production session issuance |
| BCK06-OD-03 | Open | Creator verification policy, vendor/evidence, expiry/retry — Identity + Security/Privacy + Legal | Creator grants | Deny Creator-only operation |
| BCK06-OD-04 | Open | Page transfer, slug, invitation, lifecycle, quota escalation — Identity | Production Page mutations | Disabled |
| BCK06-OD-05 | Open | Exact capability registry and access snapshot freshness — Identity + API/Security | Authoritative mutations | Unknown/stale deny |
| BCK06-OD-06 | Open | Ten-type PublisherRef migration/reconciliation — Identity + Content + Mobile | BCK-07/BCK-18/R3 | No cloud publish |
| OD-11 / BCK06-OD-07 | Open | Market minors/age and Find People consent eligibility — Security/Privacy + Legal + Identity | Account creation/Find People/age-sensitive paths | Disabled |
| BCK04-OD-08 / BCK06-OD-08 | Open | DSR verification, SLA, propagation and tombstone evidence — Privacy + Identity | Production DSR | No production data |
| BCK06-OD-09 | Open | Identity record retention, backup propagation and holds — Security/Privacy + Legal + Identity | Production personal data | No production data |
| BCK04-OD-09 / BCK05-OD-08 | Proposed | Event transport/effects topology — API + Operations | Async effects | Semantic events only |

Each resolution requires a versioned owner decision record with alternatives,
selected exact value, evidence, controls, affected documents, rollout and
rollback. Candidate prose does not change status.

## 27. Exact conditional artifact map

### 27.1 Documentation in this slice

```text
docs/product/IDENTITY_PUBLISHER_BACKEND_SPEC.md
docs/product/BACKEND_IDENTITY_PUBLISHER_COVERAGE_MATRIX.md
```

Owner-decision records are created only when accountable owners provide actual
decisions. BCK-02/BCK-01/LAUNCH_STATUS change only after a verified lifecycle
transition.

### 27.2 Future API contracts — not authorized by v0.1

```text
packages/api_contracts/schema/identity/v1/*.schema.json
packages/api_contracts/schema/identity/v1/fixtures/{valid,invalid,forward}.json
packages/api_contracts/lib/src/contracts/identity/*
packages/api_contracts/lib/src/dto/identity/*
packages/api_contracts/test/identity_*_test.dart
```

### 27.3 Future backend — not authorized by v0.1

```text
apps/backend/functions/src/identity/domain/*
apps/backend/functions/src/identity/application/commands/*
apps/backend/functions/src/identity/application/queries/*
apps/backend/functions/src/identity/data/*
apps/backend/functions/src/identity/presentation/callables/*
apps/backend/functions/src/identity/presentation/workers/*
apps/backend/functions/test/unit/identity/*
apps/backend/functions/test/contract/identity/*
apps/backend/functions/test/emulator/identity/*
apps/backend/firestore.rules
apps/backend/firestore.indexes.json
```

### 27.4 Future mobile integration — BCK-18-owned and not authorized

```text
apps/mobile/lib/features/auth/{domain,data,application,presentation}/*
apps/mobile/lib/features/identity/{domain,data,application,presentation}/*
apps/mobile/test/{unit,widget,integration}/identity_*
```

No runtime file is created or changed by BCK-06 v0.2.

## 28. Test and evidence matrix

| Level | Mandatory cases/evidence |
|---|---|
| Source/coverage | 22/22 sections, unique AC, links, statuses and conflicts |
| Schema | valid/invalid/forward fixtures; null/absent/enum/ID/time/revision bounds |
| Domain | every lifecycle transition and invariant, including terminal/revoked states |
| AuthN | Google/Apple validation, unsupported provider, collision, logout/revoke/expiry |
| AuthZ | spoofed actor/role/capability ignored; exact-page isolation; stale access denial |
| Idempotency | same key/same hash, different hash, in-progress, timeout-after-commit |
| Concurrency | page quota race, membership grant/revoke race, verification stale decision |
| Contract | common outcome/error mapping and old/new client compatibility |
| Emulator | default-deny Rules, callable trusted context, indexes and atomic transaction evidence |
| Privacy | projection allowlist, consent withdrawal, log redaction, export/deletion and retention |
| Abuse | enumeration, invite/quota spam, App Check/rate/step-up negative cases |
| Events | atomic outbox, duplicate, gap, replay, poison and consumer non-authority |
| Migration | no email auto-link, no mock-grant import, `loc_*` rejection, publisher conflict |
| Offline | stale UI label, no offline confirmed grant, unavailable authority fail-closed |
| Two-device | session revoke, membership/capability/consent change observed cross-device |
| Operations | SLO/alerts/cost, incident exercise and rollback without grant resurrection |

Documentation checks are not executable evidence. Emulator evidence is not
shared-cloud or production evidence.

## 29. Review entry evidence and Approval-review prerequisites

BCK-06 entered Review after:

1. BCK-06-PRE reconciliation defects are resolved or explicitly accepted as
   tracked upstream errata;
2. BCK-03/BCK-04 Draft dependencies have Review-safe exact treatment;
3. all commands, queries, events, errors and owners are reviewed;
4. every record family has classification, projection and retention owner;
5. all Open decisions have owner, gate and fail-closed default;
6. OD-08 and OD-11 are not presented as decided;
7. exact file/test plans remain conditional;
8. links, numbering, fences, whitespace and coverage checks pass.

BCK-06 may advance beyond Review only after the accountable and required
reviewers record an exact verdict on the authority boundaries and each
applicable open decision is either resolved or explicitly retained behind a
disabled surface without weakening D2/R2 gates.

Executable R2 readiness additionally requires Approved BCK-03/04/05/06/20,
BCK-18 migration contract, Accepted applicable OD records, production
Identity/Platform/Privacy prerequisites and separate explicit authorization.

## 30. Definition of Done

Documentation Done requires:

- Approved BCK-06 exact version and owner record;
- BCK-02/BCK-01/LAUNCH_STATUS reconciled without overstating runtime;
- 22/22 coverage evidence and zero unresolved contradictions that permit
  divergent authority;
- every unresolved production function disabled explicitly.

Runtime Done requires, separately:

- immutable contracts/fixtures and typed mobile/backend adapters;
- default-deny Rules/IAM and no client grant path;
- complete unit/contract/emulator/security/migration/two-device evidence;
- approved retention, Legal/Privacy, SLO/cost and incident evidence;
- staged rollout/rollback proof;
- no demo email/password, guest target path or mock privileged grant in
  production dependency graph;
- LAUNCH_STATUS updated to measured reality.

## 31. Acceptance criteria

1. **BCK-06-AC-01:** BCK-06 is the single writer for account/provider identity.
2. **BCK-06-AC-02:** BCK-06 is the single writer for session state and revocation.
3. **BCK-06-AC-03:** BCK-06 is the single writer for Creator verification.
4. **BCK-06-AC-04:** BCK-06 is the single writer for ManagedPage membership and capabilities.
5. **BCK-06-AC-05:** Content publication remains BCK-07-owned.
6. **BCK-06-AC-06:** DSR orchestration remains BCK-04-owned.
7. **BCK-06-AC-07:** Every production Viewer has a valid authenticated session.
8. **BCK-06-AC-08:** Google and Apple are the only Accepted production sign-in providers.
9. **BCK-06-AC-09:** Guest/email-password runtime is migration evidence, not target authority.
10. **BCK-06-AC-10:** Provider authentication never grants Creator.
11. **BCK-06-AC-11:** Creator and page verification remain separate facts.
12. **BCK-06-AC-12:** Role alone never authorizes a privileged operation.
13. **BCK-06-AC-13:** Exact-page membership and capability are checked server-side.
14. **BCK-06-AC-14:** Page IDs and full mutable grants are absent from custom claims.
15. **BCK-06-AC-15:** Client actor/role/capability assertions are ignored or rejected.
16. **BCK-06-AC-16:** Access snapshot carries source/policy revision and freshness.
17. **BCK-06-AC-17:** Stale/unavailable authority fails closed for mutation.
18. **BCK-06-AC-18:** Revocation cannot be undone by retry, cache or rollback.
19. **BCK-06-AC-19:** Default accounts and fixtures contain zero user-owned pages.
20. **BCK-06-AC-20:** Page creation atomically creates exact owner membership.
21. **BCK-06-AC-21:** Three is the bounded local/mock quota only; production quota requires an Accepted versioned policy.
22. **BCK-06-AC-22:** Delegated memberships do not consume owned-page quota.
23. **BCK-06-AC-23:** A page beyond the active policy quota is not created without approved quota authority.
24. **BCK-06-AC-24:** Page quota requests are idempotent and auditable.
25. **BCK-06-AC-25:** Admin experience preview changes presentation only.
26. **BCK-06-AC-26:** Active workspace is preference, not authority.
27. **BCK-06-AC-27:** Workspace switching never rewrites saved PublisherRef.
28. **BCK-06-AC-28:** Publisher identity is `{user|page, permanent id}` only.
29. **BCK-06-AC-29:** Names, email, Place or business text never establish publisher ownership.
30. **BCK-06-AC-30:** Publisher eligibility evaluates actor/action/type/market/current policy.
31. **BCK-06-AC-31:** Personal and page publisher eligibility are evaluated separately.
32. **BCK-06-AC-32:** Public publisher/profile data is an allowlisted projection.
33. **BCK-06-AC-33:** Raw verification, provider and private contact data never enters public projections.
34. **BCK-06-AC-34:** Find People consent is purpose-specific and versioned.
35. **BCK-06-AC-35:** Consent withdrawal disables new dependent processing immediately at authority.
36. **BCK-06-AC-36:** Find People private source and public/protected projections are distinct.
37. **BCK-06-AC-37:** OD-11 remains Open and no numerical age is invented.
38. **BCK-06-AC-38:** Account creation and Find People remain disabled until applicable OD-11 Acceptance.
39. **BCK-06-AC-39:** OD-08 forbids automatic provider merge and email-based identity mapping.
40. **BCK-06-AC-40:** Mock roles, verification, grants, pages, quota approvals and consent are never imported as authority.
41. **BCK-06-AC-41:** Temporary `loc_*` IDs are rejected by authoritative boundaries.
42. **BCK-06-AC-42:** Missing legacy publisher becomes explicit selection-required state.
43. **BCK-06-AC-43:** Commands use separate request correlation and logical idempotency identities.
44. **BCK-06-AC-44:** Same idempotency key and different semantic hash creates no mutation.
45. **BCK-06-AC-45:** Authority state never uses silent last-write-wins.
46. **BCK-06-AC-46:** Timeout-after-send is unknown outcome and is safely reconciled.
47. **BCK-06-AC-47:** Authority, audit, idempotency and outbox are atomic where an event is produced.
48. **BCK-06-AC-48:** Event consumers deduplicate and never become identity writers.
49. **BCK-06-AC-49:** Queries are side-effect-free and paginated against one logical revision.
50. **BCK-06-AC-50:** Error mapping prevents account/page/membership enumeration.
51. **BCK-06-AC-51:** Errors and logs exclude secrets, evidence, DOB, contact and provider payload.
52. **BCK-06-AC-52:** Numeric retention is not inferred from data class or another domain.
53. **BCK-06-AC-53:** Production personal data waits for exact approved retention and Legal/Privacy evidence.
54. **BCK-06-AC-54:** App Check and provider token never replace authorization.
55. **BCK-06-AC-55:** Server flags are false until their exact gates pass.
56. **BCK-06-AC-56:** Rollback never restores guest mode or revoked/mock authority.
57. **BCK-06-AC-57:** Documentation, emulator, shared-cloud and production evidence remain distinct.
58. **BCK-06-AC-58:** All runtime paths in the artifact map remain conditional on separate authorization.
59. **BCK-06-AC-59:** The specification covers every mandatory BCK-02 §14 category.
60. **BCK-06-AC-60:** Runtime status remains Absent until measured executable evidence exists.

## 32. Explicit unimplemented list

As of this version, the following are not implemented:

- production Google/Apple Auth integration;
- production account creation/linking/recovery/deletion;
- session registry, refresh and revocation authority;
- access snapshot backend and policy registry;
- Creator verification provider/review workflow;
- ManagedPage/membership/quota backend;
- production workspace/publisher eligibility;
- full ten-type PublisherRef migration;
- identity API schemas, fixtures and DTOs;
- identity Cloud Functions, collections, indexes and Rules;
- outbox workers and consumers;
- consent evidence and Find People profile projections;
- Accepted OD-08, OD-11 and exact identity retention;
- production DSR integration;
- emulator, two-device, load, security and production evidence;
- Firebase projects, credentials, deployment and production data processing.

The only present implementation evidence is bounded local/mock mobile behavior
and non-product backend R0 feasibility. Neither is production authority.

## 33. Final statement

BCK-06 v0.2 is a complete Review contract pending owner/qualified decisions. It prevents identity,
publisher and consent authority from being duplicated across Flutter,
Firestore Rules and feature backends. It intentionally keeps all unresolved
Legal, session, provider-linking, verification, retention and rollout choices
fail-closed. No runtime implementation may begin from this document alone.
