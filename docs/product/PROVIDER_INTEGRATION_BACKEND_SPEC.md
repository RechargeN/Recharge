# Recharge Backend — External Provider Integration Specification

- ID: **BCK-16**
- Version: **0.3.1**
- Date: **2026-09-21**
- Spec status: **Draft — Present; provider, domain, Security/Privacy, Legal and Operations review pending**
- Runtime status: **Absent — external links/local snapshots are compatibility input only**
- Accountable owner: **Integrations owner**
- Coordination baseline: [BCK-02 v2.4.82](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D5 / R9 — gated and not required for Latvia GA**

## 0. Changelog

### v0.3.1 — 2026-09-21

- normalized Provider connection lifecycle enum values to the BCK-03
  lowerCamelCase rule;
- preserved provider-neutrality, Draft status and all network/runtime gates.

### v0.3 — 2026-09-21

- completed the Stage 5 provider registry, provenance, freshness,
  cache/live-check and external-handoff contract;
- fixed retry, circuit-breaker, rate-limit, callback and credential-rotation
  boundaries with independent market activation;
- preserved the rule that provider observations never confirm internal Booking
  or Payment and granted no network/runtime authority.

### v0.2 — 2026-09-20

- added the Stage 2 normalized provider entity inventory;
- separated external observation/handoff from Discover projection, internal
  Booking and Payments authority;
- normalized provenance, credentials, lifecycle, rollback, flags and evidence.

### v0.1 — 2026-09-20

- created the first canonical backend contract for external provider adapters;
- defined market registry, connections, bindings, provenance, freshness,
  polling/webhooks, cache/live-check and external handoff;
- kept provider data separate from Recharge overlays and internal Booking;
- added credential, licensing, resilience, cost, Baltic activation and rollback
  gates without choosing or enabling any provider.

## 1. Verdict and status semantics

BCK-16 is a provider-neutral design contract. It does not select a vendor,
accept terms, create an account, store credentials, authorize network access,
import data, deploy an adapter or activate a market. `Draft` remains fail-closed
until each exact adapter/provider/market/data purpose and operational boundary
has current attributable approval and runtime evidence.

Current external URLs, local/mock availability and manually entered source
references are compatibility evidence only. They do not prove provider identity,
freshness, inventory, booking, license, connectivity or production authority.

## 2. Parents, priority and reconciliation

BCK-16 inherits without silently overriding:

1. Accepted ADRs and the frozen
   [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md);
2. [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) architecture and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md) coordination;
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md),
   [BCK-08](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md),
   [BCK-09](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md),
   [BCK-13](NOTIFICATIONS_BACKEND_SPEC.md),
   [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md) and
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md);
4. the canonical [Event Classification](EVENT_CLASSIFICATION_SPEC.md) and
   applicable domain specifications;
5. implementation notes, external links and local/mock behavior.

Once Approved, BCK-16 owns Recharge's provider connection/mirror/provenance and
handoff records. The external provider remains authority for its own system;
owning Recharge domains retain their aggregates and overlays.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-16 defines one replaceable integration platform for versioned providers and
market policies, authenticated connections, resource bindings, polling/webhook
sync, provider snapshots, availability/live-check and honest external handoff.
Every value carries source identity, observation time, freshness and authority.

### 3.2 Non-goals

BCK-16 does not:

- own Event/Place/Route/Scenario or other Recharge content;
- own Recharge editorial/category/localization overlays;
- create internal Booking/hold/inventory/payment/attendance authority;
- call an external confirmation an internal Booking;
- permit scraping or unlicensed acquisition;
- choose a vendor, contract, commercial model or operating entity;
- expose credentials to mobile, UI, logs or product documents;
- authorize Firebase, network access, deployment or production activation.

## 4. Scope

### 4.1 In scope

- provider/adapter capability registry and per-market enablement;
- organization/tenant connection and resource binding;
- external identity keys and idempotent source upsert;
- field-authority/provenance and Recharge overlay preservation;
- polling, webhook, sync cursor, retry and reconciliation;
- availability snapshot, cache/freshness and optional live-check;
- safe external handoff and bounded external-booking mirror;
- secrets/credential rotation, rate/cost/circuit/kill controls;
- licensing/terms/retention/deletion and market rollout evidence.

### 4.2 Disabled until later gates

- every concrete provider, connector, credential and network call;
- scraping, browser automation and guessed/unpublished endpoints;
- provider-owned booking mirror without accepted identity/linkage policy;
- internal write based solely on unverified provider payload;
- automatic fuzzy merge or PublisherRef/capability assignment;
- external paid Booking/Payment reconciliation without BCK-17 and separate gate;
- production import/sync/handoff in LV, EE or LT.

## 5. Ownership and single writers

| Record/projection | Authoritative writer | Consumers |
|---|---|---|
| `ProviderDefinition` / market policy | Integrations config workflow | Adapters/domains/operations |
| `ProviderConnection` | Integrations connection service | Exact adapter/authorized owner |
| `ProviderResourceBinding` | Integrations binding service | Sync/handoff/domain import |
| `ProviderSourceRecord` | Integrations sync service | Owning domain/import review |
| `ProviderAvailabilitySnapshot` | Integrations availability service | BCK-08/mobile/handoff |
| `ProviderSyncRun` / cursor / webhook receipt | Integrations sync service | Operations/audit |
| `ExternalHandoffReceipt` | Integrations handoff service | User/support/audit |
| External provider source truth | External provider | BCK-16 mirror only |
| Recharge content/overlay | BCK-07/owning domain | BCK-16 cannot overwrite overlay |
| Public composed projection | BCK-08 | Reads BCK-16 source/freshness |
| Internal Booking/inventory ledger | BCK-09 | Rechecks its own authority only |
| Credentials/secrets/IAM | BCK-05 security workflow | Exact adapter identity |

Provider sync never writes domain collections directly. It produces a typed
source/import candidate or snapshot; the owning domain accepts/reconciles it
through its registered command.

## 6. Actors, capabilities and trust boundaries

| Actor/service | Allowed | Denied |
|---|---|---|
| Authenticated User | Follow enabled external handoff | Secret/source-admin access |
| Verified Creator/Page member | Connect authorized provider tenant/resource | Claim unrelated provider organization |
| Integrations service | Sync exact accepted connection/capabilities | Product-domain direct write |
| Adapter identity | Call exact allowlisted provider endpoints | Broad project/network/secret access |
| Owning domain | Validate/apply accepted source candidate | Modify provider truth |
| BCK-08 | Compose display availability with provenance | Confirm Booking/inventory |
| Support/Admin | BCK-19 audited workflow | Impersonate provider/user/direct write |

Connection/binding actions re-evaluate Page membership and scoped capabilities.
Provider/OAuth identity cannot grant Recharge Creator, Page or Admin authority.

### 6.1 Data classification and projection boundary

| Data | Class | Storage/projection rule |
|---|---|---|
| OAuth/client/webhook secret material | Secret | Secret Manager/KMS only; never a product record |
| Connection/tenant/resource identity | Protected | Authorized publisher/integration staff only |
| Raw provider payload | Restricted or protected by field inventory | Optional bounded source evidence; never public directly |
| Normalized provider source record | Protected | Owning domain/import review only until accepted |
| Public provider-derived fields | Public derived | Exact accepted allowlist with provenance/freshness |
| Availability snapshot | Public/protected derived by source | BCK-08 composition only; no Booking authority |
| External user/booking linkage | Sensitive restricted | Explicit linkage gate; never public |
| Sync/webhook/handoff receipt | Operational protected | Bounded IDs/status; no secret/raw personal payload |
| Credentials, tokens and signing keys | Secret | Opaque reference outside Secret Manager/KMS only |

A field does not become public because the provider returned it. Publication
requires the owning domain's accepted field-authority and projection allowlist.
Raw payload, provider attendee/customer identity, access tokens, external
booking details and private organization metadata never enter public catalog,
general logs or product analytics.

## 7. Provider registry and lifecycle

```text
ProviderDefinition {
  providerId, adapterType, adapterVersion, capabilityRefs[],
  supportedMarkets[], supportedLocales[], dataClassRefs[],
  endpointPolicyRef, authPolicyRef, ratePolicyRef, costPolicyRef,
  termsEvidenceRef, status, createdAtUtc, activatedAtUtc?
}

ProviderMarketPolicy {
  providerId, marketId, capabilityRefs[], serviceAreaRefs[],
  freshnessPolicyRef, liveCheckPolicyRef, handoffPolicyRef,
  enabled, revision, effectiveAtUtc
}
```

Definition lifecycle is `draft -> review -> active -> suspended -> retired`.
Only an exact active definition plus enabled market capability may receive
traffic. Suspension immediately blocks new sync/live-check/handoff as configured
without deleting source/provenance history.

## 8. Connection, binding and external identity model

```text
ProviderConnection {
  connectionId, providerId, owningPublisherRef, externalTenantId,
  credentialRef, grantedScopes[], status, verifiedAtUtc?,
  expiresAtUtc?, revision, createdByUserId
}

ProviderResourceBinding {
  bindingId, connectionId, providerResourceType, externalResourceId,
  owningDomain, owningResourceId?, status, fieldAuthorityPolicyRef,
  createdAtUtc, verifiedAtUtc?, revision
}

ProviderExternalKey {
  providerId, externalTenantId, externalEntityType,
  externalEntityId, externalOccurrenceId?
}
```

Connection states are `pendingAuthorization | active | needsReauth | suspended
| revoked | expired`. Resource binding is explicit and reviewable. External key
uniqueness is provider/tenant/type/entity/occurrence scoped; display values,
URLs, title, venue/date or coordinates never replace it.

## 9. Source records, snapshots and provenance

```text
ProviderSourceRecord {
  sourceRecordId, externalKey, connectionId?, bindingId?,
  payloadSchemaVersion, providerRevision?, sourceHash,
  observedAtUtc, fetchedAtUtc, expiresAtUtc?, verificationStatus,
  rawBlobRef?, normalizedCandidateRef?, status, provenance
}

ProviderAvailabilitySnapshot {
  availabilitySnapshotId, externalKey, marketId,
  sourceStatus, availabilityStatus, observedAtUtc,
  freshUntilUtc, providerRevision?, confidence,
  liveCheckRequired, handoffRequired, sourceHash
}
```

Raw payload storage is optional, protected and separately justified. Normalized
records retain exact provider/tenant/entity/revision/hash/observation provenance.
Unknown/missing values stay unknown; they are never coerced to free, available,
unlimited, closed or sold out.

## 10. Field authority and overlay preservation

Every binding has a versioned field-authority matrix. For Event providers,
provider-owned candidates may include schedule, price/ticket types, inventory,
seat status, booking URL and cancellation/refund status only where the contract
permits. Recharge-owned overlay includes category mapping, localized editorial
copy, recommendation facets, Scenario suitability and Publisher policy.

Provider sync cannot overwrite Recharge overlay or silently rewrite publisher,
moderation, capability or accepted domain fields. A changed authority matrix is
a reviewed migration, not an adapter implementation detail.

## 11. Adapter contract and isolation

Each adapter implements provider-neutral ports for declared capabilities only:

- authenticate/refresh/revoke connection;
- discover/list authorized resources;
- fetch delta/page/snapshot;
- normalize/verify webhook;
- fetch availability and optional live-check;
- produce safe external handoff;
- optionally query permitted external booking reference state.

Vendor SDK/types, endpoint quirks and credentials stay inside the adapter. The
domain sees normalized typed outcomes. Egress is exact-domain/endpoint/method
allowlisted; adapters cannot browse, scrape or follow unapproved redirects.

## 12. Sync, cursor and reconciliation

```text
ProviderSyncRun {
  syncRunId, providerId, connectionId, bindingId?, capabilityId,
  cursorBefore?, cursorAfter?, startedAtUtc, completedAtUtc?,
  status, counts, failureCode?, adapterVersion, policyVersions[]
}

ProviderWebhookReceipt {
  webhookReceiptId, providerId, externalEventId, signatureKeyVersion,
  receivedAtUtc, sourceHash, status, processedAtUtc?, dedupeKey
}
```

Polling is cursor/checkpoint based and idempotent. Webhooks require signature,
timestamp/replay window, exact endpoint, size/schema limits and dedupe. Neither
path trusts ordering or completeness. Scheduled reconciliation compares accepted
provider identity/revision/hash and repairs missing/duplicate/out-of-order facts
through the owning-domain command boundary.

## 13. Availability, cache and freshness

Availability statuses align with BCK-08: `available | limited | soldOut |
closed | unavailable | unknown | stale | unsupported`. Snapshot includes source,
revision, observed/generated time, `freshUntil`, confidence and required
live-check/handoff.

`cache read` and `live-check` are different operations. Cache may support honest
display/filtering under policy; it never confirms a booking. Live-check is a
bounded provider read immediately before handoff or another allowed decision,
not a write reservation. When stale/unknown, UI shows that state and follows
fail-closed availability/filter policy.

## 14. External handoff and booking boundary

```text
ExternalHandoffReceipt {
  handoffId, actorUserId, providerId, externalKey,
  sourceSnapshotId, destinationClass, sanitizedDestination,
  liveCheckReceiptId?, disclosedExternalBoundary,
  createdAtUtc, expiresAtUtc?
}
```

The destination is generated/validated by the server from accepted provider
data and an allowlisted scheme/domain policy; clients do not submit arbitrary
redirect URLs. UI clearly states the user is leaving Recharge and that provider
terms/privacy/availability apply.

Opening a link, receiving a provider success page, webhook or mirror record does
not create/confirm/cancel an internal BCK-09 Booking. Optional external-booking
mirror is labelled external, requires verified user/provider identity linkage
and remains separate from Recharge inventory/Booking lifecycle.

## 15. Commands, queries and typed outcomes

Commands:

- `CreateProviderConnection`, `CompleteProviderAuthorization`;
- `RefreshProviderConnection`, `RevokeProviderConnection`;
- `CreateProviderResourceBinding`, `VerifyProviderResourceBinding`,
  `RevokeProviderResourceBinding`;
- `RunProviderSync`, `ProcessProviderWebhook`, `ReconcileProviderSource`;
- `RequestProviderLiveCheck`, `CreateExternalHandoff`;
- `SubmitProviderCandidateToDomain`;
- registered suspend/rotate/emergency actions through BCK-05.

Queries:

- enabled provider capabilities for market/domain;
- authorized publisher connections/bindings/sync health;
- provider snapshot/availability with freshness/provenance;
- actor's bounded external handoff/mirror receipts;
- operator sync/circuit/cost status without credentials/raw personal data.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, provider_disabled,
market_disabled, capability_unsupported, connection_required,
connection_expired, reauthorization_required, scope_insufficient,
binding_invalid, external_identity_conflict, source_unverified,
signature_invalid, replay_detected, payload_too_large,
schema_unsupported, rate_limited, circuit_open, quota_exhausted,
provider_timeout, provider_unavailable, stale_snapshot,
live_check_required, availability_unknown, handoff_blocked,
license_blocked, idempotency_conflict, cancelled,
temporarily_unavailable
```

## 16. Contract versions and compatibility

Provider definition, adapter, capability, payload schema, normalized schema,
authority, freshness, rate/cost, handoff and market policies are independently
versioned and pinned in records/receipts. Unknown/newer versions fail closed;
no generic property bag bypasses schema review.

Additive compatible fields may be preserved, but changed meaning/requiredness,
identity, lifecycle, authority or provider state requires migration, fixtures,
minimum-client/consumer evidence and rollback. Retired adapters remain readable
for history but cannot receive traffic.

## 17. Persistence, indexes and transaction boundaries

Definitions/policies, connections/bindings, source records/raw blobs,
availability, sync/webhook/handoff receipts, idempotency/audit/outbox are
separate. Credentials are only opaque secret references. Required indexes are
scoped by provider/market/connection/binding/status/external key/updated time.

Atomic boundaries include:

- connection authorization result plus audit/credential reference;
- resource binding plus uniqueness reservation/audit;
- source upsert plus cursor/checkpoint/outbox where applicable;
- webhook dedupe plus processing receipt;
- handoff receipt plus exact snapshot/live-check reference.

Owning-domain application is a separate idempotent command with source receipt;
cross-domain distributed transactions are not implied.

## 18. IDs, time, Money and reference data

- Recharge records use immutable server-issued ULID/UUID-style IDs;
- external identity is a typed provider/tenant/type/entity/occurrence key;
- UTC instants carry explicit observed/fetched/generated/fresh-until meaning;
- local occurrence semantics retain IANA timezone and source revision;
- Money uses integer minor units, ISO currency and price status/provenance;
- markets/locales/taxonomy/service areas use BCK-20 IDs/revisions;
- URLs are validated delivery values, never entity identity;
- raw provider enums map through versioned adapters and preserve unknown values.

## 19. Idempotency, concurrency and partial failure

Connection/binding/sync/webhook/live-check/handoff commands use scoped operation
identity. Same key with changed canonical input fails. External-key uniqueness
prevents duplicate source identity; fuzzy overlap creates a candidate, never an
automatic merge.

Sync lease/fencing prevents concurrent cursor writers. A page/run failure does
not advance checkpoint beyond committed facts. Stale worker/webhook cannot
replace a newer provider revision or revoked binding. Partial domain application
is recorded per source candidate and reconciled without re-importing accepted
effects blindly.

## 20. Retry, circuit breaker and degraded behavior

Retries are bounded/jittered and restricted to classified transient failures;
429/Retry-After and provider quotas are respected. Auth, signature, schema,
license, permission and invalid-binding failures are not blind-retried. Circuit
state is provider/capability/market scoped and has half-open probes plus global
emergency disable.

Retry storms are prevented by leases, budgets and shared backoff. Cached stale
snapshots may render only under accepted policy with honest labels. Unknown,
unsupported or circuit-open never becomes available. Core Recharge manual and
internal paths continue without provider integration.

## 21. Credentials, secrets and rotation

OAuth/client secrets, refresh/access tokens, webhook secrets and signing keys
exist only in accepted Secret Manager/KMS bindings. Records store opaque
credential/key-version refs. Mobile, Firestore product documents, logs,
analytics, fixtures and support UI never receive secret material.

Scopes are least privilege per capability/environment/market. Refresh/rotation
is auditable and overlap-bounded; revocation stops new work and marks connection
`needsReauth` or `revoked`. Compromise invokes provider-specific revoke,
credential rotation, circuit/flag disable and BCK-04/BCK-05 incident response.

## 22. Events, outbox and notifications

After Accepted OD-09 and authorization, minimized events may include:

- `provider.connectionChanged`, `provider.bindingChanged`;
- `provider.syncCompleted`, `provider.syncFailed`;
- `provider.sourceChanged`, `provider.availabilityChanged`;
- `provider.reauthorizationRequired`, `provider.handoffCreated`;
- `provider.reconciliationRequired`.

Payloads contain IDs/revisions/status codes/freshness, never credentials, raw
payloads, personal booking data or arbitrary URLs. Outbox is atomic with source
state. Consumers dedupe and reconcile by source/provider revision. User/staff
delivery flows through BCK-13; push/email are not provider source truth.

## 23. Privacy, retention, DSR and external-booking identity

Each adapter inventories personal/protected/public/operational fields, purpose,
legal basis where applicable, provider/subprocessors, residency, disclosure,
retention, deletion/correction/export and DSR handoff. Absence of current binding
evidence blocks the affected provider/data class/market.

External user/booking identity linkage requires explicit accepted policy,
verified account binding, minimized scopes and unlink/revoke behavior. It never
merges accounts by email/name or exposes organizer attendee data without exact
authority. Numeric retention for source/raw payloads/connections/receipts/mirror
records is accepted under BCK-04 before production processing.

## 24. Licensing, terms, attribution and source withdrawal

Every provider/capability/market has pinned terms/license/commercial evidence,
permitted fields/purpose/storage/cache/display/export, attribution, rate limits,
termination and deletion/correction obligations. A public endpoint or successful
response is not permission to ingest or republish.

Terms/version change triggers revalidation and may suspend affected capability.
Source withdrawal stops new acquisition, marks freshness/status honestly,
executes required deletion/correction and preserves only permitted audit
evidence. Scraping remains prohibited unless separately accepted with exact
authority and technical controls.

## 25. Security and abuse controls

Controls include server-only adapter identities, egress allowlists, TLS and
certificate policy, SSRF/DNS rebinding defenses, response/content/redirect
limits, webhook signatures/replay windows, OAuth state/PKCE where applicable,
least scopes, tenant isolation, rate/abuse limits and raw-payload sanitization.

App Check is only a client risk signal and never protects provider credentials
or replaces server authorization. Provider payload is hostile input and cannot
create HTML/script execution, tool permission, internal URL fetch, secret read
or direct domain mutation.

## 26. Observability, SLO, cost and sync health

Operational metrics cover connection/reauth state, sync latency/lag/cursor,
provider/adapter errors, webhook verification/dedupe, freshness, live-check,
handoff, circuit/retry/quota/rate/cost and reconciliation. Logs use bounded IDs
and codes; credentials, raw payloads, external user/booking details and handoff
destinations are prohibited.

`sync health` is a derived status, not proof of field correctness. BCK-05 accepts
numeric SLO/alerts/budgets before runtime. Cost includes provider fees, egress,
polling/webhook/compute/storage and amplification. Hard budget/rate limits can
disable one capability/provider/market without blocking core product.

## 27. Flags, rollout, rollback and emergency disable

Flags are independent by provider, adapter version, capability, connection
class, market, domain and cohort. Polling, webhook, live-check, handoff, external
mirror and domain application can be disabled separately; all default off.

Rollout proceeds fixtures -> sandbox -> emulator/local adapter -> staging
synthetic -> bounded internal connection -> approved cohort. Rollback stops new
traffic, revokes/rotates credentials where needed, preserves provenance/cursors,
marks snapshots stale/unknown and keeps Recharge overlays/internal Booking
unchanged. It never deletes obligations or claims a provider result was applied.

## 28. Migration and provider replacement

Existing external URLs become reviewed handoff candidates, not automatic
connections or source records. Migration dry-run inventories provider identity,
bindings, field ownership, duplicates, references and unsupported values.
Names/date/venue overlap creates `DuplicateCandidate`; only shared authoritative
provider identity or approved review can merge.

Provider replacement creates new definitions/connections/bindings and explicit
mapping/reconciliation. Historical provenance is retained according to policy;
old external keys are not silently reinterpreted. A changed provider does not
rewrite Recharge overlay, PublisherRef, internal Booking or user capability.

## 29. Conditional implementation file map

No physical adapter is authorized by this document alone. An Approved slice may
create:

```text
packages/api_contracts/schemas/provider_integration/
packages/api_contracts/fixtures/provider_integration/
apps/backend/functions/src/modules/provider_integration/domain/
apps/backend/functions/src/modules/provider_integration/application/
apps/backend/functions/src/modules/provider_integration/data/
apps/backend/functions/src/modules/provider_integration/transport/
apps/backend/functions/src/modules/provider_integration/adapters/<provider>/
apps/backend/functions/src/modules/provider_integration/workers/
apps/backend/functions/test/contract/provider_integration/
apps/backend/functions/test/emulator/provider_integration/
```

Secrets/IAM/IaC remain BCK-05-owned. Owning-domain adapters stay in that domain
and consume typed BCK-16 candidates/snapshots. Generated files are generator-only.

## 30. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Contract | registry/connection/binding/source/availability/handoff schemas |
| Adapter | sandbox fixtures, pagination/delta, errors and unknown fields |
| Authority | field matrix and overlay/PublisherRef/capability preservation |
| Identity | external key uniqueness, tenant isolation and account linkage |
| Security | OAuth/webhook/SSRF/redirect/egress/secrets/rotation/hostile payload |
| Freshness | cache/live-check/stale/unknown/circuit and BCK-08 composition |
| Booking | handoff/mirror never creates internal Booking/inventory effects |
| Concurrency | lease/fencing/cursor/page retry/webhook replay/idempotency |
| Privacy/Legal | terms/license/retention/DSR/withdrawal per market/provider |
| Emulator | transactions, Rules/IAM, indexes, outbox and domain receipts |
| Resilience | outage, retry storm, quota, poison payload, provider suspension |
| Baltic | independent LV/EE/LT support/service areas/locales/currencies |
| Load/cost | polling/webhook bursts, fanout, cache/storage and budget stop |
| End-to-end | connect -> bind -> sync -> display/live-check -> handoff/revoke |

Unrun, timed-out, sandbox-only-without-required-provider, unsigned or
environment-blocked checks are `Inconclusive`, never Pass.

## 31. Dependency and delivery gates

Approval requires applicable BCK-03/04/05/06/07/08/09/13/18/20 boundaries,
exact provider/capability/market and commercial/legal/license decision, domain
field-authority approval, independent Security/Privacy review, operations/cost
ownership and representative sandbox/fixture evidence.

Runtime requires R9 entry and one exact Approved adapter slice. External booking
mirror needs separate identity/privacy/provider terms approval; paid flows also
need new Accepted Payments ADR and BCK-17. BCK-16 is not required for Latvia GA
and cannot block internal/manual product paths.

## 32. Definition of Ready

BCK-16 is ready for formal review when:

- provider versus Recharge ownership and field-authority model are accepted;
- registry/connection/binding/source/freshness/handoff models are reconciled;
- provider/domain/Security/Privacy/Legal/Operations/Mobile reviewers are named;
- each provider/data class/market has explicit disabled default;
- every open decision has owner, fail-closed default and target gate.

## 33. Definition of Done

BCK-16 becomes `Approved` only after current attributable verdicts, resolved
blocking decisions, exact contracts/slices, traceable AC/evidence and atomic
BCK-01/BCK-02/LAUNCH_STATUS reconciliation. Runtime Done remains separate and
requires code, sandbox/staging evidence, rollback and activation approval.

## 34. Acceptance criteria

1. **BCK-16-AC-01:** BCK-16 owns internal provider mirror/provenance/handoff.
2. **BCK-16-AC-02:** External provider remains authority for its system.
3. **BCK-16-AC-03:** Recharge domains retain aggregates and overlays.
4. **BCK-16-AC-04:** Provider sync never directly writes domain collections.
5. **BCK-16-AC-05:** Internal Booking/inventory stays exclusively BCK-09-owned.
6. **BCK-16-AC-06:** Provider result never confirms internal Booking.
7. **BCK-16-AC-07:** Provider registry is versioned per capability/market.
8. **BCK-16-AC-08:** Only exact active/enabled definitions receive traffic.
9. **BCK-16-AC-09:** LV/EE/LT adapters activate independently.
10. **BCK-16-AC-10:** Unsupported market/capability fails closed.
11. **BCK-16-AC-11:** Connection owner/capability is server verified.
12. **BCK-16-AC-12:** Provider identity grants no Recharge role/capability.
13. **BCK-16-AC-13:** Resource binding is explicit, scoped and revocable.
14. **BCK-16-AC-14:** External identity uses provider/tenant/type/entity keys.
15. **BCK-16-AC-15:** Display fields/URLs/coordinates never replace identity.
16. **BCK-16-AC-16:** Fuzzy overlap creates candidate, never automatic merge.
17. **BCK-16-AC-17:** Every normalized value retains source provenance.
18. **BCK-16-AC-18:** Unknown/missing values remain unknown.
19. **BCK-16-AC-19:** Provider-owned fields cannot overwrite Recharge overlay.
20. **BCK-16-AC-20:** Sync cannot change PublisherRef/capabilities silently.
21. **BCK-16-AC-21:** Vendor SDK/types stay behind adapter.
22. **BCK-16-AC-22:** Egress endpoints/methods/redirects are allowlisted.
23. **BCK-16-AC-23:** Scraping/guessed endpoints remain prohibited.
24. **BCK-16-AC-24:** Polling cursor advances only after committed facts.
25. **BCK-16-AC-25:** Webhooks verify signature/time/replay/schema/size.
26. **BCK-16-AC-26:** Polling/webhook ordering/completeness is not assumed.
27. **BCK-16-AC-27:** Reconciliation is idempotent and domain-command bounded.
28. **BCK-16-AC-28:** Availability carries source/revision/time/freshness.
29. **BCK-16-AC-29:** Cache read and live-check are distinct operations.
30. **BCK-16-AC-30:** Cached/live data never reserves/confirms inventory.
31. **BCK-16-AC-31:** Stale/unknown never coerces to available/free/unlimited.
32. **BCK-16-AC-32:** Handoff destination is server-generated/validated.
33. **BCK-16-AC-33:** Handoff clearly discloses external boundary.
34. **BCK-16-AC-34:** Handoff receipt pins source/live-check snapshot.
35. **BCK-16-AC-35:** External booking mirror is labelled and isolated.
36. **BCK-16-AC-36:** External identity linkage never merges by email/name.
37. **BCK-16-AC-37:** Unknown/newer adapter/policy/schema fails closed.
38. **BCK-16-AC-38:** Breaking changes require migration/consumer evidence.
39. **BCK-16-AC-39:** Credentials are opaque Secret Manager/KMS references.
40. **BCK-16-AC-40:** Mobile/logs/fixtures/UI never receive credentials.
41. **BCK-16-AC-41:** Scopes/identities are least privilege and environment-local.
42. **BCK-16-AC-42:** Rotation/revocation/compromise paths are exercised.
43. **BCK-16-AC-43:** Idempotency detects changed canonical input.
44. **BCK-16-AC-44:** Sync leases/fencing reject stale workers.
45. **BCK-16-AC-45:** Retries respect classification/quota/Retry-After.
46. **BCK-16-AC-46:** Auth/schema/license failures are not blind-retried.
47. **BCK-16-AC-47:** Circuit breakers/kill switches prevent retry storms.
48. **BCK-16-AC-48:** Provider outage preserves internal/manual safe paths.
49. **BCK-16-AC-49:** Outbox/events exclude secrets/raw/personal booking data.
50. **BCK-16-AC-50:** Consumers dedupe/reconcile by source/provider revision.
51. **BCK-16-AC-51:** Data transfer requires purpose/terms/residency evidence.
52. **BCK-16-AC-52:** Retention/DSR/withdrawal policy precedes production sync.
53. **BCK-16-AC-53:** Public endpoint/success response is not ingestion permission.
54. **BCK-16-AC-54:** App Check never protects secrets/replaces authorization.
55. **BCK-16-AC-55:** Logs exclude credentials/raw payloads/personal details.
56. **BCK-16-AC-56:** Sync health is not proof of field correctness.
57. **BCK-16-AC-57:** Cost/SLO/rate thresholds require BCK-05 acceptance.
58. **BCK-16-AC-58:** Provider/capability/market flags default off.
59. **BCK-16-AC-59:** Rollback preserves provenance/overlays/internal Booking.
60. **BCK-16-AC-60:** Documentation acceptance authorizes no provider/runtime.

## 35. Explicit unimplemented list and owner decisions

Unimplemented:

- API schemas, fixtures, registry, connections/bindings and source records;
- every concrete adapter, provider account, secret, IAM and network path;
- polling/webhooks/live-check/handoff/workers;
- domain/mobile integration, Rules/indexes/outbox/observability;
- terms/license/privacy/cost evidence, SLOs and market activation.

Required decisions:

| Decision | Owner | Fail-closed default | Gate |
|---|---|---|---|
| Exact provider/adapter/capability/market | Integrations + Product | adapter disabled | Runtime slice |
| Contract/terms/license/storage/attribution | Legal/Commercial | no acquisition/display | Approval |
| Field authority and domain application | Provider + domain owner | candidate only/no apply | Approval |
| Credentials/scopes/egress/webhook policy | Security/Operations | no connection | Runtime |
| Freshness/live-check/cache thresholds | Provider + Discover | stale/unknown | R9 |
| Rate/cost/SLO/circuit thresholds | Operations/Finance | conservative hard stop | R9 |
| External user/booking identity linkage | Identity/Privacy/Legal | mirror disabled | Mirror slice |
| LV/EE/LT service areas/locales/currencies | Market/Product | market disabled | Activation |

## 36. Final statement

BCK-16 defines an honest provider-neutral boundary: Recharge can mirror and
display externally sourced facts with exact identity, provenance and freshness,
then hand the user to the provider without pretending that an internal Booking
occurred. It authorizes no provider, credential, network call, import, Firebase,
deployment or market activation.

## 37. Stage 2 normalized Provider Integration entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| ProviderRegistryEntry | Integrations / provider registry | adapter resolver, Operations and market policy | providerId + adapter/contract/credential-ref revision; no secret value |
| ProviderObjectMapping | Integrations / mapping handler | Discover/owning domain reconciliation | mappingId + providerId/externalObjectId/internal objectId + provenance |
| ProviderObservation | Integrations / adapter ingestion | Discover availability/content composition | observationId + provider/object/source revision + observedAt/expiresAt |
| ProviderAvailabilitySnapshot | Integrations / availability snapshot handler | Discover and handoff UI only | snapshotId + observation refs/freshness; not inventory authority |
| ExternalHandoffSession | Integrations / handoff handler | requesting user and audit | handoffId + provider/object/actor/purpose/expiry; no internal Booking ID claim |
| ProviderCallbackReceipt | Integrations / verified callback handler | reconciliation and owning domain command adapter | receiptId + provider event ID/signature timestamp/hash |

Registry/mappings are draft → verified → enabled/suspended; observations are
fresh/stale/expired/invalid; handoff is prepared → opened/completed/unknown and
never internal confirmation. Provider result cannot create Booking or Payment
without the owning typed command and separate authority. Ingestion/callback
idempotency uses provider/event/object/hash; mapping concurrency uses expected
revision. Receipt persistence and outbox are atomic, external calls are not.
Credentials live in BCK-05 secrets, while data classification, authorization,
retention/deletion and audit follow BCK-04. Telemetry records provider/code/
latency/freshness, not secrets/raw payload. Migration preserves provenance and
supports remap reconciliation; rollback suspends adapter or restores prior
mapping without fabricating freshness. Provider/market/capability flags and
circuit breakers default off. Evidence covers signature/replay/SSRF, mapping,
freshness, cache/live distinction, rate/retry, outage, handoff honesty and
market isolation.

## 38. Stage 5 provider lifecycle, freshness and resilience contract

### 38.1 Registry and market activation

One provider registry revision describes provider, adapter/schema version,
allowed capabilities/data purposes, service areas, markets, legal/terms/source
evidence, credential reference, quotas and kill switches. Provider registration
does not enable it. Each `(provider, capability, market)` requires an
independent default-off activation decision and may be suspended without
affecting other markets or internal Recharge functionality.

### 38.2 Observation, cache and live-check semantics

Every provider observation pins provider/object/mapping IDs, source and adapter
revisions, observed/received/expires timestamps, request/callback provenance,
market/service area and integrity/status evidence. Cached observation exposes
fresh/stale/expired/invalid honestly. A live check is an explicit bounded
provider request with its own attempt/result/expiry and never retroactively
labels older cache as live.

Provider availability is a read signal consumed by BCK-08. It never mutates
BCK-09 inventory or confirms internal Booking/Payment. External handoff returns
a typed prepared/opened/returned/unknown result and is labelled external; a
provider confirmation may update BCK-16 observation/handoff only unless an
owning domain separately accepts a typed command.

### 38.3 Resilience, callbacks and credentials

Retries honor idempotency, provider rate limit, deadline, attempt budget and
Retry-After. Circuit breaker states are closed/open/half-open with audited
threshold/policy revision; half-open probes are bounded and do not serve as
user confirmation. Bulk polling is paginated, leased, checkpointed and bounded
per provider/market. Callback handling verifies endpoint/provider identity,
signature, timestamp/skew, nonce/event replay, body hash/schema and mapping
before atomic receipt persistence.

Credentials are BCK-05 secret references scoped by environment/provider/
capability/market, never registry values, logs or mobile configuration.
Rotation supports overlapping versions, forced revocation, audit and rollback
without fabricating source freshness. Terms/license/data-purpose expiry
suspends affected ingestion/handoff fail-closed.

### 38.4 Reconciliation and replacement

Mapping conflict, missed callback, polling gap, stale cache and provider
correction create typed reconciliation work. Replacement/migration preserves
old provider provenance, uses explicit mapping/review and never merges external
IDs by display name. Rollback suspends calls, preserves honest cached state and
selects a prior compatible adapter/registry revision; it cannot convert stale
or unknown data into fresh/confirmed state.

### 38.5 Additional acceptance criteria

61. **BCK-16-AC-61:** Registry pins provider/adapter/capability/purpose/market/evidence revisions.
62. **BCK-16-AC-62:** Registration never enables a provider or market automatically.
63. **BCK-16-AC-63:** Each provider capability activates independently for LV/EE/LT.
64. **BCK-16-AC-64:** Every observation carries source, mapping, provenance and freshness timestamps.
65. **BCK-16-AC-65:** Cached and live-check states are distinct and honestly labelled.
66. **BCK-16-AC-66:** Provider availability never allocates internal inventory or confirms Booking/Payment.
67. **BCK-16-AC-67:** External handoff remains external with prepared/opened/returned/unknown outcomes.
68. **BCK-16-AC-68:** Retry obeys idempotency, rate, Retry-After, deadline and attempt budget.
69. **BCK-16-AC-69:** Circuit breaker/probe states are bounded, audited and not confirmation.
70. **BCK-16-AC-70:** Polling is paginated, leased, checkpointed and provider/market bounded.
71. **BCK-16-AC-71:** Callbacks verify identity, signature, time, replay, hash, schema and mapping.
72. **BCK-16-AC-72:** Credentials remain environment/provider/capability/market-scoped BCK-05 refs.
73. **BCK-16-AC-73:** Terms/license/purpose expiry suspends affected integration fail-closed.
74. **BCK-16-AC-74:** Replacement/rollback preserves provenance and cannot fabricate freshness.
75. **BCK-16-AC-75:** v0.3.1 authorizes no provider, network, credential, ingestion or activation.
