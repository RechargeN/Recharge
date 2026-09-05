# Recharge Backend — Notifications Specification

- ID: **BCK-13**
- Version: **0.2**
- Date: **2026-08-25**
- Spec status: **Review — documentation only; approval pending**
- Runtime status: **Absent**
- Accountable owner: **Notifications owner**
- Review owners: **API Platform, Security/Privacy, Platform Operations,
  Identity, Mobile, Product domain owners, Legal/Privacy and Support**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.38](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-13-PRE v0.2](BACKEND_NOTIFICATIONS_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/NOTIFICATIONS_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

### v0.2 — 2026-08-25

- completed all 22 mandatory BCK-02 design categories and promoted the document
  to Review;
- established a single-writer split between source-domain facts and the
  Notifications-owned inbox, preferences, device registrations and delivery
  attempts;
- defined inbox-first, idempotent and privacy-minimized delivery semantics,
  typed navigation intents, token lifecycle, replay, migration and rollback;
- recorded 60 acceptance criteria and ten owner decisions without authorizing
  FCM, email, Firebase, mobile adapters, deployment or production processing.

### v0.1 — 2026-08-25

- created a documentation-only draft from the canonical backend and current
  local mobile Notifications audit;
- reconciled BCK-03/04/05/06/07/09/18, OD-02, Proposed OD-09 and the Proposed
  Firebase architecture without promoting any dependency status.

## 1. Verdict and status semantics

BCK-13 defines the target Notifications authority for Recharge. It is complete
enough for cross-owner Review, not Approval or implementation. Runtime is
**Absent**.

The current Flutter app has a local secure-storage inbox, demo seed items,
idempotent append-by-ID for local identity events, `mark read` and string route
targets. That is useful compatibility evidence only. It is not a server inbox,
FCM delivery, token registry, cross-device synchronization or production
authority and must not be imported as trusted domain truth.

Document Review, contract fixtures, emulator evidence, staged deployment,
channel enablement and production readiness are independent. Nothing in this
revision provisions Firebase/GCP, registers a token, sends a message, changes
mobile code, deploys a worker, processes production data, pushes a branch or
merges `main`.

## 2. Parents, priority and reconciliation

Priority is:

1. Accepted ADR;
2. Approved owning-domain specification;
3. BCK-02 coordination and BCK-01 architecture;
4. this BCK-13 contract;
5. Proposed architecture and implementation notes.

Normative inputs:

- [BCK-03](BACKEND_API_CONTRACT_STANDARD.md): typed envelopes, errors,
  versioning, pagination, split request/idempotency keys and Proposed OD-09;
- [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md): data classes, AuthN/Z, consent,
  retention, DSR, logging and token protection;
- [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md): environments, service
  identities, workers, observability, recovery, cost and rollout;
- [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md): account/session/revocation,
  subject identity and producer facts;
- [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md): content lifecycle facts and
  current visibility authority;
- [BCK-09](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md): Booking-owned facts,
  transactional outbox obligations and privacy-minimized notification needs;
- [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md): typed adapter, cache,
  offline and push-as-hint behavior;
- [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md): locale/market revisions,
  LocalizedText/fallback policy and independently gated Baltic rollout.

[Firebase Architecture](../architecture/FIREBASE_ARCHITECTURE.md) v2.2 is a
**Proposed input**. FCM and the suggested collection layout are not silently
Accepted. Exact transport, paths, Rules, indexes and regional resources require
the decisions and executable gates below.

OD-09 is Proposed, not Accepted. Therefore this Review may define compatible
consumer semantics, but cross-domain workers remain disabled. OD-02 is Open;
email is disabled by default.

BCK-09 §15 supplies compatible Booking producer obligations and privacy rules.
Its logical `bookingNotificationDeliveries` naming is not a second delivery
authority: Booking owns the atomic Booking outbox fact; BCK-13 owns the inbox,
registration and channel-attempt records after handoff. Any physical BCK-09
implementation must reconcile those records to this single writer before an
effect is enabled.

## 3. Outcome and non-goals

### 3.1 Outcome

Provide one provider-neutral Notifications contract that:

- consumes accepted, minimized source-domain intents after source commit;
- creates an authoritative, queryable per-recipient inbox idempotently;
- routes eligible effects through user preferences and policy;
- manages environment-bound device push registrations safely;
- records channel attempts without overstating delivery or reading;
- supports typed guarded navigation, replay, correction and revocation;
- operates across offline, multi-device, retry and account-switch conditions;
- exposes privacy, DSR, observability, cost and rollback controls.

### 3.2 Non-goals

BCK-13 does not own:

- Booking, Content, Identity, moderation, payment or other source lifecycle;
- source-domain authorization or creation of a business fact;
- arbitrary marketing campaigns, recommendations or analytics profiling;
- mobile navigation implementation or UI grouping;
- provider account linking, email recovery or contact verification;
- Firebase/FCM/email vendor selection or infrastructure provisioning;
- a claim that provider acceptance equals device delivery or user reading;
- legal advice or an Accepted mandatory-message/retention policy.

## 4. Scope and channel posture

### 4.1 In scope

- notification intent consumption and normalization;
- durable per-recipient inbox projection;
- read, unread, archive and bounded dismissal state;
- notification category/channel preferences and quiet-hours evaluation;
- device installation/push registration lifecycle;
- in-app, push and future explicitly enabled email delivery attempts;
- template/version/locale rendering and minimized variables;
- typed navigation intent and current-access revalidation;
- retry, replay, dedupe, correction, cancellation and dead-letter handling;
- migration from local demo/runtime state without authority promotion;
- privacy, retention, DSR, recovery, SLO, rate and cost controls.

### 4.2 Initial channel posture

| Channel | Review target | Enablement default |
|---|---|---|
| Authoritative in-app inbox | Required system of record for user-visible notifications | Disabled until Approved runtime slice |
| FCM push | Best-effort wake-up/hint after inbox creation | Disabled until token, privacy and R4 gates |
| Transactional email | Optional channel governed by OD-02 | **Disabled** while OD-02 is not Accepted |
| Marketing/promotional | Outside initial scope; requires purpose/consent policy | **Disabled** |
| SMS/voice/web push | Outside this contract revision | **Disabled** |

Push permission denial, unavailable devices or provider failure never prevents
creation of an eligible authoritative inbox item.

## 5. Ownership and single writers

| Aggregate/decision | Single writer | BCK-13 boundary |
|---|---|---|
| Source business lifecycle | Owning domain | Emits accepted fact/intent only |
| Source recipient eligibility | Owning domain + BCK-06 access input | BCK-13 cannot invent audience from names/email |
| `NotificationInboxItem` | BCK-13 | Canonical recipient-visible projection and status |
| `NotificationPreferenceSet` | BCK-13 | Category/channel/quiet-hours user choices under policy |
| `DevicePushRegistration` | BCK-13 | Token binding, rotation, revocation and provider feedback |
| `NotificationDeliveryAttempt` | BCK-13 | Attempt/retry/provider outcome, not source state |
| Templates and variable allowlist | BCK-13 with Product/Locale review | Producer supplies typed variables, not rendered free text |
| Auth/session/account revocation | BCK-06 | Revalidated; Notifications cannot grant access |
| Deep-link route handling | Mobile/BCK-18 | Backend emits typed navigation intent only |
| Moderation/Admin work queue | BCK-22/BCK-19 | BCK-13 may notify from an accepted fact; never owns the case/task |
| Consent/retention/legal basis | BCK-04 + Accepted category policy | BCK-13 enforces, does not invent |
| Operational queue/recovery | BCK-05 | BCK-13 declares effect semantics and evidence |

Source domains never write inbox read state, preferences, tokens or delivery
attempts. Notifications never confirms/cancels a Booking, publishes/hides
Content, changes membership or treats a click as a source-domain command.

## 6. Actors, trust and data classification

Actors and service identities:

- authenticated recipient;
- accepted source-domain producer;
- Notifications intent consumer/inbox writer;
- channel dispatcher with channel-scoped credentials;
- preference/read-state command handler;
- replay/reconciliation/retention worker;
- narrowly authorized Support/Security responder.

The producer identity, event type and schema are allowlisted. Recipient IDs,
token values, rendered private text, source references and delivery correlation
may be Personal or Protected. Raw push tokens are protected secrets-like
personal device identifiers: encrypted at rest, never logged, never returned by
normal queries and visible only to the channel dispatcher through least
privilege.

App Check is an abuse signal. It does not replace authentication, recipient
ownership, session/revocation, source authority or server policy.

## 7. Domain model

### 7.1 NotificationIntent

An accepted intent contains at minimum:

- permanent `intentId` and `schemaVersion`;
- authoritative `producerDomain` and `eventType`;
- opaque recipient subject ID or approved bounded recipient set reference;
- `sourceRef {type, id, revision}` without display-name authority;
- `category`, `priority`, `occurredAtUtc` and optional `expiresAtUtc`;
- versioned `templateKey`, `templateRevision` and minimized typed variables;
- stable `dedupeKey` and optional `supersedesIntentId`;
- eligible channel set constrained by server policy;
- optional typed `NavigationIntent`;
- data-class/purpose/policy revision and trace-safe correlation IDs.

An intent is an obligation/request for user communication, not proof of
delivery. It excludes arbitrary HTML, arbitrary URL, raw email/token, access
code, exact private location, application free text and entire source records.

`NotificationIntent` is the BCK-13 normalized consumer model. It does not
replace or fork the OD-09 event envelope: the producer emits the Accepted
version of that envelope and BCK-13 deterministically derives the intent while
preserving event ID, aggregate revision, market, correlation and causation.

### 7.2 NotificationInboxItem

The inbox item contains:

- permanent `notificationId`, recipient ID and immutable `createdAtUtc`;
- source/intent/dedupe/template references and effective locale;
- server-rendered title/body or approved localization payload;
- category, priority and typed navigation intent;
- `status`, `readAtUtc`, `archivedAtUtc`, `removedAtUtc`, expiry and revision;
- correction/supersession state and policy provenance;
- content hash sufficient for idempotent reconciliation.

Inbox item states are:

```text
activeUnread -> activeRead -> archived
      |             |
      +-------> expired
      +-------> withdrawn
      +-------> removed
```

`readAtUtc` is server-authoritative recipient state. Read does not mean the
source action was completed. Archive is reversible presentation state. Recipient
removal hides the item and retains only a policy-bounded tombstone; it is not
physical privacy erasure. Withdrawal/correction is a typed producer effect and
never inferred from a missing push.

### 7.3 NotificationPreferenceSet

Preferences are versioned per account and contain category/channel choices,
quiet-hours schedule with IANA timezone, locale preference, policy revision and
updated-at metadata. Defaults are server-owned and market-versioned. A missing
or newer unsupported policy fails closed to the least intrusive allowed
delivery; it never silently opts a user into marketing.

Required security/service communications, if any, need an Accepted category
policy and Legal/Privacy disposition. A product team cannot label its message
“mandatory” to bypass preference or consent.

### 7.4 DevicePushRegistration

The registration binds:

- permanent registration/install ID;
- authenticated user ID;
- environment and market;
- platform, app identifier and bounded client/build capability;
- provider and encrypted token value plus keyed token fingerprint;
- permission/registration state, issued/rotated/last-seen timestamps;
- revoke reason, provider invalidation and revision.

One provider token cannot be simultaneously active for two users or
environments. Account switch, logout, account revocation, token rotation,
provider invalid-token feedback and DSR cause explicit rebind/revoke behavior.

### 7.5 NotificationDeliveryAttempt

Each attempt contains delivery ID, notification/channel, attempt number,
provider-safe message correlation, requested/accepted/failed timestamps,
failure class, next-attempt time and terminal/dead-letter state. It never stores
raw credentials or treats provider acceptance as recipient delivery/read.

Inbox state, channel delivery state and source lifecycle state are separate
state machines and separate facts.

## 8. Commands and authorization

| Command | Actor | Authoritative checks/result |
|---|---|---|
| `notifications.markRead` | Recipient | Own active item; idempotent server `readAtUtc` |
| `notifications.markAllRead` | Recipient | Bounded query snapshot/cursor and cutoff; no unbounded scan |
| `notifications.archive` | Recipient | Own item and expected revision; source unchanged |
| `notifications.removeFromInbox` | Recipient | Own item; bounded tombstone; source and audit unchanged |
| `notifications.updatePreferences` | Recipient | Accepted policy/version and eligible choices |
| `notifications.registerPush` | Authenticated install | Session, environment/app binding, token validation and rotation |
| `notifications.revokePush` | Recipient/install/system | Exact registration or current token fingerprint; idempotent revoke |
| `notifications.consumeIntent` | Trusted producer/worker | Producer/event/schema allowlist, recipient, dedupe and policy |
| `notifications.correctOrWithdraw` | Owning producer | Source/revision ownership and monotonic effect |
| `notifications.replayDelivery` | Privileged worker/admin workflow | Bounded scope, reason, audit, dedupe and poison controls |

Client-provided user ID, category, mandatory flag, source state, template text,
provider result or deep-link URL is never authoritative. Privileged replay uses
propose/approve/execute where the BCK-05/BCK-19 policy requires it.

Every recipient mutation is a registered versioned BCK-03 command. This Review
does **not** authorize direct client writes to Firestore `isRead`, preferences
or token records; any future bounded direct-write exception requires its own
Accepted security/Rules/contract decision and negative evidence.

## 9. Queries and pagination

Queries include:

- `notifications.listInbox` with opaque cursor, bounded page and stable sort;
- `notifications.getUnreadSummary` as a revisioned projection;
- `notifications.getPreferences`;
- `notifications.listRegistrations` returning safe device labels/status only;
- narrowly scoped operational delivery/reconciliation queries.

Inbox sorts by server `createdAtUtc`, then permanent ID. Cursor binds recipient,
filters, snapshot/revision and page direction. A cursor from another account,
environment or filter is invalid. Read-your-write uses command receipt/revision;
eventual unread-count projection exposes honest freshness and cannot overwrite
a newer local command receipt.

Normal clients never query another recipient, raw device tokens, attempts,
outbox payloads, provider IDs or dead letters.

## 10. Templates, localization and navigation

Templates are versioned, reviewed and allowlist their variable names, types,
lengths and data classes. Producers send typed variables; the Notifications
renderer selects an Accepted template revision and locale profile. Arbitrary
producer-rendered content, HTML and interpolation keys are rejected.

Locale handling coordinates with BCK-20/OD-10. Until a compatible localization
policy is Accepted, only explicitly supported template/locale combinations may
send; missing sensitive translations fail closed. A generic safe fallback may
be used only when approved per category and must not change meaning.

`NavigationIntent` is an allowlisted typed structure such as:

```text
{ routeKind, objectRef {type, id}, action?, routeContractVersion }
```

It is not an arbitrary URL. On open, mobile re-authenticates as necessary,
revalidates current resource visibility/capability and fetches authoritative
state. A withdrawn, deleted, unauthorized or unsupported target opens a typed
safe state, never cached protected content.

## 11. Inbox-first delivery pipeline

The required flow is:

1. owning-domain transaction commits its fact and outbox record atomically;
2. an allowlisted consumer validates schema, producer, recipient and policy;
3. BCK-13 idempotently creates or reconciles the inbox item;
4. eligible channel obligations are derived from preferences/policy;
5. push/email attempts run after inbox commit and record separate outcomes;
6. retry/replay never creates a second inbox item or source transition;
7. poison work is quarantined, observable and repairable without silent drop.

If a push is received before the query projection catches up, the client shows
a bounded syncing state and refetches. If push is lost, the inbox remains
discoverable. Push payload contains only a safe hint and opaque identifiers;
the notification body shown on a locked device follows the approved privacy
profile and defaults to generic for sensitive categories.

## 12. Events and typed failures

### 12.1 Events

BCK-13 may emit minimized facts such as:

- `notifications.inboxItemCreated`;
- `notifications.inboxItemCorrected`;
- `notifications.inboxItemWithdrawn`;
- `notifications.readStateChanged`;
- `notifications.preferencesChanged`;
- `notifications.pushRegistrationChanged`;
- `notifications.deliveryTerminal`;
- `notifications.deadLettered`.

Analytics consumes the canonical catalog separately; delivery telemetry is not
permission to profile notification content or reconstruct protected payloads.

### 12.2 Failure vocabulary

Typed failures include:

```text
unauthenticated
permission_denied
recipient_not_found
notification_not_found
unsupported_contract
unsupported_template
unsupported_locale
invalid_navigation_intent
invalid_preference
policy_unavailable
stale_revision
idempotency_conflict
cancelled
token_invalid
token_already_bound
channel_disabled
delivery_expired
rate_limited
provider_unavailable
temporarily_unavailable
reconciliation_required
```

Provider-specific codes, email existence, raw token, protected source data and
internal policy detail are not returned to ordinary clients. User cancellation
or permission denial is a typed neutral outcome, not success or server failure.

## 13. Contract versioning and compatibility

Contracts follow BCK-03 and the Accepted API contracts workflow. Each command,
query, event, template and navigation contract is versioned independently.
Unknown required fields, enum values or newer authority semantics fail closed;
unknown optional presentation data may be preserved opaquely only when safe.

The local Flutter `NotificationItemEntity` and `AppNotificationEvent` are
compatibility inputs, not wire schemas. String `targetRoute` is converted only
through an explicit allowlisted mapper. No backend schema may be inferred from
the current seeded JSON shape.

## 14. Persistence, indexes and atomicity

Logical records:

- inbox item by recipient and permanent notification ID;
- intent-consumption/dedupe receipt;
- preference set and policy revision;
- device push registration and token fingerprint index;
- delivery obligation/attempt/dead-letter;
- audit/reconciliation/retention state.

Required indexes support recipient + status/category + stable time/ID,
registration fingerprint/environment/status, due attempt time/status and
bounded operational reconciliation. Exact Firestore collections/indexes are a
future owner decision; the Proposed layout is not normative.

Inbox creation, dedupe receipt and channel obligations are atomic where the
chosen store permits. If a provider call cannot be transactional, it occurs
after commit and is reconciled by a stable delivery key. Partial state is never
reported as a successful complete delivery.

## 15. IDs, time and reference semantics

- persistent entities use ULID/UUID; `loc_*` remains unsaved-local only;
- all relationships use IDs, never title, email, phone or display name;
- server acceptance/read/attempt times are UTC instants;
- quiet hours use an explicit IANA timezone and local-wall schedule;
- DST gaps/overlaps use a versioned deterministic policy;
- expiry uses backend time, never untrusted client clock;
- request ID is attempt correlation; stable idempotency key identifies the
  logical mutation, per BCK-03 split-key semantics.

## 16. Idempotency, ordering, concurrency and replay

An intent dedupe key, inbox item ID, delivery key and provider message ID are
different identifiers. They are never conflated.

At-least-once consumption is expected. Exactly-once user-visible effect is
achieved with idempotent state transitions and deterministic keys, not a claim
of exactly-once transport. Same idempotency key with a different canonical
payload hash yields `idempotency_conflict` and no mutation.

There is no global event order. Monotonic source revision applies per source
reference where correction/withdrawal needs ordering. A stale worker cannot
restore a withdrawn item, rebind a revoked token, revert a preference revision
or send an expired obligation. Replay pins consumer/template/policy revision or
uses an explicit reviewed migration; it cannot silently render new wording for
an old fact.

Exact cross-domain envelope, lease, ordering, retry, poison, replay and
retention details require Accepted OD-09 before effects/workers run.

## 17. Preferences, quiet hours, rate and coalescing

Preference evaluation order is explicit and versioned:

1. channel globally/environment disabled;
2. legal/security/category policy eligibility;
3. recipient consent/preference;
4. token/channel availability;
5. expiry, quiet hours, frequency and coalescing policy;
6. delivery attempt.

Quiet hours defer eligible non-urgent push; they do not hide the inbox item.
Category priority cannot be raised by the producer to bypass user settings.
Rate limits apply per producer, recipient, category and environment. Aggregation
or coalescing preserves source references and never merges incompatible users,
publishers, privacy classes or actions. Exact defaults are BCK13-OD-08.

## 18. Offline, multi-device and cache

- inbox cache is account/environment scoped and stores provenance/revision;
- push is only an invalidation/query hint;
- pending read/archive commands use stable idempotency keys and reconcile
  unknown outcomes before creating a new logical command;
- multiple devices converge through server read/preference state;
- logout/account switch clears or cryptographically isolates protected cache
  and revokes/rebinds the installation according to policy;
- stale cached CTA always revalidates current auth/visibility/source state;
- no offline source-domain mutation is inferred from notification interaction.

## 19. Migration and cutover

Current local seed items and local moderator inbox are demo/runtime evidence.
They are not imported as production business facts, unread obligations,
moderation cases or user consent.

A future migration must define:

- identity mapping through BCK-06/OD-08, never email or device ID;
- allowlisted local item types and typed target-route mapping;
- deterministic import ID, dry-run, conflict and duplicate report;
- whether user-created read/archive state is eligible to preserve;
- disclosure, checkpoint, retry, rollback and deletion behavior;
- server-source verification before any actionable imported item exists.

Default cutover starts the authoritative inbox empty unless an Approved import
profile proves a trusted source. Legacy local storage stays isolated during a
bounded compatibility window and is removed only after measured rollback-safe
evidence. Moderator seed inbox is never production Admin authority.

## 20. Privacy, consent, retention and DSR

Data minimization occurs twice: producer-to-intent and notification-to-channel.
Lock-screen push defaults to generic wording for Booking, identity, Find People,
private location, moderation and other sensitive classes. Access codes,
application text, participant identity, exact private location, token, email
and unrestricted free text are forbidden in push payloads and logs.

Each record family has purpose, data class, retention trigger, deletion or
restriction behavior, backup propagation and legal/security hold rules. The
BCK-04 draft 30-day payload/outbox value is input, not silently Accepted exact
policy. Exact values require BCK13-OD-06 and qualified review.

DSR/account deletion revokes active registrations, deletes or irreversibly
detaches eligible personal inbox/preference/delivery data, preserves only
lawfully required minimized records and prevents backup restore from
resurrecting access. Recipient correction/withdrawal obligations and incident
communications follow the applicable Accepted policy; this spec does not
invent statutory deadlines.

Email stays disabled until OD-02 resolves inclusion, provider/controller/
processor roles, lawful purpose, consent/preference, template, unsubscribe where
applicable, bounce/suppression, retention and DSR behavior.

## 21. Security and abuse controls

- least-privilege producer and channel service identities;
- environment-separated credentials and registrations;
- encryption in transit/at rest and restricted raw-token access;
- keyed token fingerprints for lookup/dedupe, with key rotation plan;
- no token, rendered protected content or recipient enumeration in logs;
- producer/event/template/variable/navigation allowlists;
- per-source/recipient/category quotas and bounded fan-out;
- authorization recheck on every protected query/navigation;
- revocation propagation and invalid-token feedback handling;
- App Check, rate limit and anomaly detection as layered abuse controls;
- audited replay/support access and poison-message quarantine.

Mass fan-out, arbitrary recipient lists, user-authored push text and arbitrary
URLs remain disabled. Security alerts cannot be suppressed or enabled by
pretending an unresolved category policy is Accepted.

## 22. Observability, SLO, analytics and cost

Metrics:

- accepted/rejected intents by producer/category/reason;
- inbox creation/reconciliation latency and unread projection lag;
- preference suppression and quiet-hour deferral counts;
- active/rotated/revoked/invalid registrations by safe dimension;
- attempts, provider acceptance, terminal failure, retry and dead-letter;
- duplicate/replay/poison/correction/withdrawal outcomes;
- deep-link safe-state and authorization-denial counts;
- DSR/deletion/retention/recovery completion lag;
- queue age, operations, egress and provider cost.

“Provider accepted”, “device delivered”, “notification displayed”, “opened” and
“source action completed” are distinct metrics; unavailable provider receipts
must remain unknown rather than guessed. Product analytics requires BCK-21 and
applicable consent; operational telemetry is minimized under BCK-05.

Numeric SLO, retry, quota, fan-out, latency, retention and EUR cost guardrails
are BCK13-OD-10. Until Accepted and measured, no production-scale claim exists.
Degradation may pause nonessential channels while retaining inbox truth; it
cannot bypass privacy, preferences or source authorization.

## 23. Flags, rollout and rollback

Server-owned flags are scoped by environment, market, producer, category,
template, command, channel and cohort:

- intent consumption;
- inbox creation/query/read commands;
- push registration and dispatch;
- each email/optional channel;
- each source-domain consumer;
- each template/localization revision;
- replay/correction/migration workers.

Rollout proceeds documentation → contracts/fixtures → unit → emulator → stage
synthetic → bounded non-production → production owner decision. Each stage has
separate evidence. Push/email remain off until inbox correctness is proven.

Rollback disables scoped consumers/channels, stops new attempts, drains or
quarantines accepted work, preserves inbox/read/preference truth and completes
privacy duties. It never rolls back a source-domain fact, reactivates a revoked
token, converts a failed push into success or republishes protected content.

## 24. Dependency and delivery gates

Before Approval:

- BCK-03/04/05/06, BCK-18/20 and OD-10 Approval/Acceptance or explicit
  accepted compatibility disposition;
- Accepted OD-09 for cross-domain effect workers;
- OD-02 Accepted or explicitly Deferred with email disabled;
- all ten BCK13 decisions Accepted or Deferred with bounded controls;
- producer handoff profiles for each enabled domain;
- qualified Security/Privacy, Operations, Mobile and Legal/Privacy verdicts.

Before executable work:

- separately Approved bounded R4 slice with exact files/resources;
- accepted Notifications contract/schema/template workflow and fixtures;
- G1/R1 environment and workload-identity prerequisites;
- server flags, kill switch, rollback, quotas and cost limit predeclared;
- no new boundary suppression or unapproved mobile dependency.

Before production:

- production Identity/session/revocation authority;
- Rules/IAM/secret/token lifecycle and cross-account negative tests;
- load, retry, replay, poison, cost and SLO evidence;
- DSR/deletion/backup-resurrection and incident/rollback drills;
- channel consent/store/Legal/Privacy and signed owner evidence.

## 25. Conditional exact file map

No file below is authorized by this Review. A future Approved slice may create:

```text
packages/api_contracts/notifications/          # only after BCK13-OD-01
  schemas/
  fixtures/

apps/backend/src/notifications/
  domain/
    notification_intent.*
    inbox_item.*
    notification_preference.*
    push_registration.*
    delivery_attempt.*
  application/
    consume_intent.*
    mark_read.*
    update_preferences.*
    register_push.*
    revoke_push.*
    correct_notification.*
  infrastructure/
    notifications_repository.*
    template_repository.*
    push_gateway.*
    email_gateway.*                  # absent while OD-02 unresolved
  presentation/
    notifications_handlers.*
  workers/
    dispatch_notification.*
    retry_delivery.*
    reconcile_notifications.*
    retain_delete_notifications.*

apps/backend/test/notifications/
  unit/
  contract/
  integration/
  security/
  recovery/

infra/firebase/                      # exact layout subject to Approved slice
  firestore.rules
  firestore.indexes.json
  notifications-resource-manifest.*

apps/mobile/lib/features/notifications/data/remote/  # BCK-18-approved seam
apps/mobile/test/**/notifications_remote_*_test.dart
```

Source-domain state and outbox creation stay in their owning modules. Shared
mobile transport stays outside presentation/domain. Generated files follow the
accepted workflow and are never hand-edited.

## 26. Test and evidence matrix

| Layer | Required evidence |
|---|---|
| Domain/unit | inbox/preference/token/attempt state machines, expiry, quiet hours, policy |
| Contract | commands/queries/events/errors/templates/navigation fixtures and compatibility |
| Consumer | producer allowlist, duplicate, gap, correction, withdrawal, poison and replay |
| Security | cross-user/environment, guessed ID, token exposure, arbitrary route/text denial |
| Delivery | inbox-first, provider failure, invalid token, retry, TTL and no false read claim |
| Identity | logout/account switch/revocation, exact subject, no email/device authority |
| Mobile | offline read reconciliation, push hint, deep-link recheck, newer version failure |
| Privacy | minimized payload/log, sensitive lock-screen profile, DSR/retention/backup |
| Recovery | restored inbox/dedupe/preferences do not resend or reactivate revoked tokens |
| Load/cost | fan-out, queue age, provider quota/cost and degradation guardrails |
| Rollout | flags, disable/drain/quarantine, compatible client and rollback evidence |

Documentation checks prove links, structure and numbering only. Emulator cannot
prove production IAM, provider deliverability, consent, latency or recovery.

## 27. Definition of Ready

For Approval review:

1. 22/22 coverage remains reconciled;
2. ten owner decisions have dated verdicts;
3. OD-09 is Accepted and OD-02 has a bounded disposition;
4. dependency status and source-domain handoffs are explicit;
5. contract, privacy, security, operations, mobile and Legal owners sign;
6. all runtime/channel files remain absent unless separately authorized.

For an executable slice:

1. BCK-13 is Approved;
2. exact bounded scope/file/resource list is approved;
3. contracts, templates, variables and failures are frozen in fixtures;
4. G1/R1 and production-identity prerequisites for the chosen environment pass;
5. rollback/kill-switch/rate/cost limits are predeclared;
6. no unresolved provider or policy choice is implemented by assumption.

## 28. Definition of Done

BCK-13 runtime is Done only when:

- approved contracts, inbox, preferences, registrations and delivery attempts
  are implemented in owned layers;
- source consumers preserve domain authority and pass replay/poison tests;
- security, contract, integration, privacy, recovery and load gates pass in
  required environments;
- mobile integration treats push as a hint and revalidates navigation;
- migration is measured, reversible and excludes demo/mock authority;
- observability, runbooks, on-call and cost controls are active;
- LAUNCH_STATUS links measured evidence without conflating deployment,
  enablement, provider acceptance, delivery or reading.

Production Enabled additionally requires market/channel activation,
Legal/Privacy, recovery and owner sign-off. `Review`, `Approved`, `Done`,
`Deployed` and `Enabled` are not synonyms.

## 29. Acceptance criteria

1. **BCK-13-AC-01:** Source domains own business lifecycle and recipient facts.
2. **BCK-13-AC-02:** Notifications alone writes inbox, preferences, registrations and attempts.
3. **BCK-13-AC-03:** Inbox, channel delivery and source lifecycle are separate states.
4. **BCK-13-AC-04:** A notification interaction never silently mutates source state.
5. **BCK-13-AC-05:** Names, email, phone and device IDs never establish recipient authority.
6. **BCK-13-AC-06:** App Check supplements but never replaces AuthN/Z.
7. **BCK-13-AC-07:** Intent payload is minimized and producer/schema allowlisted.
8. **BCK-13-AC-08:** Arbitrary HTML, text, URL and recipient lists are rejected.
9. **BCK-13-AC-09:** Source fact/outbox commits before any notification effect.
10. **BCK-13-AC-10:** Eligible inbox creation precedes channel dispatch.
11. **BCK-13-AC-11:** Push failure cannot remove or roll back the inbox item.
12. **BCK-13-AC-12:** Provider acceptance is not device delivery or user reading.
13. **BCK-13-AC-13:** Push is a query hint, never authority.
14. **BCK-13-AC-14:** Deep links use typed allowlisted navigation intents.
15. **BCK-13-AC-15:** Navigation revalidates current auth, visibility and source state.
16. **BCK-13-AC-16:** Read state is per recipient and server-authoritative.
17. **BCK-13-AC-17:** Read does not mean source action complete.
18. **BCK-13-AC-18:** Archive, removal, expiry, withdrawal and privacy erasure remain distinct.
19. **BCK-13-AC-19:** Mark-all-read is bounded by snapshot/cursor and cutoff.
20. **BCK-13-AC-20:** Preferences are versioned by market and policy.
21. **BCK-13-AC-21:** Missing policy never silently opts a user into marketing.
22. **BCK-13-AC-22:** Mandatory category cannot be invented by a producer.
23. **BCK-13-AC-23:** Quiet hours defer channels but do not hide inbox truth.
24. **BCK-13-AC-24:** Priority cannot bypass preference, consent or privacy.
25. **BCK-13-AC-25:** Templates and variable schemas are immutable/versioned.
26. **BCK-13-AC-26:** Unsupported sensitive locale/template fails closed.
27. **BCK-13-AC-27:** Registration binds exact user, install, app and environment.
28. **BCK-13-AC-28:** One token cannot be active for two users/environments.
29. **BCK-13-AC-29:** Token rotation/logout/revocation/provider invalidation are explicit.
30. **BCK-13-AC-30:** Raw tokens never appear in normal query, log or analytics.
31. **BCK-13-AC-31:** Intent, inbox, delivery and provider IDs are not conflated.
32. **BCK-13-AC-32:** At-least-once transport uses idempotent user-visible effects.
33. **BCK-13-AC-33:** Same key/different payload hash yields no mutation.
34. **BCK-13-AC-34:** Request-attempt ID is separate from logical idempotency key.
35. **BCK-13-AC-35:** Stale workers cannot undo withdrawal, revoke or preferences.
36. **BCK-13-AC-36:** Replay cannot duplicate inbox items or source transitions.
37. **BCK-13-AC-37:** Poison work is quarantined and observable.
38. **BCK-13-AC-38:** Cross-domain workers stay disabled until OD-09 Accepted.
39. **BCK-13-AC-39:** Email stays disabled until OD-02 disposition is Accepted.
40. **BCK-13-AC-40:** Sensitive push payload defaults to generic minimal content.
41. **BCK-13-AC-41:** Access codes, private locations and application text never enter push/logs.
42. **BCK-13-AC-42:** Retention is per record family/purpose, not provider default.
43. **BCK-13-AC-43:** DSR revokes tokens and prevents backup access resurrection.
44. **BCK-13-AC-44:** Environment, market, account and cache data never mix.
45. **BCK-13-AC-45:** Offline unknown outcomes reconcile before a new logical command.
46. **BCK-13-AC-46:** Multi-device state converges through server revisions.
47. **BCK-13-AC-47:** Local demo seed never becomes production authority.
48. **BCK-13-AC-48:** Legacy target routes require explicit allowlisted mapping.
49. **BCK-13-AC-49:** Import never maps identity by email or device token.
50. **BCK-13-AC-50:** Unsupported newer authority contract fails closed.
51. **BCK-13-AC-51:** Metrics distinguish accepted, delivered, displayed, opened and acted.
52. **BCK-13-AC-52:** Logs exclude tokens and protected/rendered payloads.
53. **BCK-13-AC-53:** Numeric SLO/quota/cost claims require owner evidence.
54. **BCK-13-AC-54:** Degradation preserves inbox truth and privacy controls.
55. **BCK-13-AC-55:** Every consumer/channel/replay surface has a kill switch.
56. **BCK-13-AC-56:** Rollback never reactivates tokens or rolls back source facts.
57. **BCK-13-AC-57:** Proposed Firebase/FCM layout is not silently Accepted.
58. **BCK-13-AC-58:** No new boundary suppression is introduced by this revision.
59. **BCK-13-AC-59:** Executable files require a separate Approved slice.
60. **BCK-13-AC-60:** Runtime remains Absent until measured implementation evidence exists.

## 30. Explicit unimplemented list

- Notifications API schemas, fixtures, clients and generated DTOs;
- source-domain event consumers and Accepted OD-09 runtime;
- authoritative inbox, preference, read/archive and correction storage;
- FCM project/configuration, push credentials, token registry and dispatcher;
- transactional email provider, templates, consent and suppression processing;
- Rules, IAM, indexes, queues/tasks and retention workers;
- BCK-06 production identity/session/revocation integration;
- BCK-18 mobile remote adapter, push SDK, permission and deep-link bridge;
- local-to-server migration or demo-seed cleanup;
- DSR, deletion, recovery, replay and incident runbooks;
- accepted numeric limits, retention, SLO, quotas and cost guardrails;
- production Security/Privacy/Legal/Operations or owner approval;
- cloud provisioning, deployment, production traffic or data processing.

## 31. Owner decisions required

| ID | Required decision | Owners | Fail-closed default |
|---|---|---|---|
| BCK13-OD-01 | API/schema/template/codegen source and compatibility workflow | Notifications + API + Mobile | No remote adapter |
| BCK13-OD-02 | OD-02 email inclusion/provider/purpose/consent/template/suppression | Notifications + Legal/Privacy + Operations | Email disabled |
| BCK13-OD-03 | OD-09 envelope, ordering, retry, replay, poison and retention | API + Operations + Notifications | Consumers disabled |
| BCK13-OD-04 | Category taxonomy, mandatory rules, preference defaults and consent | Product + Notifications + Legal/Privacy | Inbox only where clearly eligible; optional channels off |
| BCK13-OD-05 | Template variables, localization, fallback and revision policy | Notifications + Product + BCK-20 + Legal | Unsupported combination unavailable |
| BCK13-OD-06 | Device/token encryption, binding, rotation, DSR and record retention | Security/Privacy + Identity + Notifications | Push registration/dispatch disabled |
| BCK13-OD-07 | Provider, priority, TTL, retry/backoff and invalid-token feedback | Operations + Notifications + Security | Push dispatch disabled |
| BCK13-OD-08 | Quiet hours, rate, fan-out, aggregation and coalescing | Product + Notifications + Operations | Conservative limits; mass fan-out off |
| BCK13-OD-09 | Local migration, typed route mapping, cutover and rollback | Mobile + Identity + Notifications + Product | Empty server inbox; no import |
| BCK13-OD-10 | Numeric SLO, queue/latency/quota/cost and degradation budgets | Operations + Notifications + Product | No scale/production claim |

## 32. Final statement

BCK-13 v0.2 is a complete Review contract for a production-grade Notifications
subsystem design. It is deliberately inbox-first, provider-neutral and
fail-closed where event, channel, privacy, localization or runtime evidence is
absent. It neither claims nor authorizes implementation.
