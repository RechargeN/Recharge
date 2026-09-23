# Recharge Backend — Payments Specification

- ID: **BCK-17**
- Version: **0.3.1**
- Date: **2026-09-21**
- Spec status: **Draft — blocked pending new Accepted Payments ADR**
- Runtime status: **Absent — no PSP, financial ledger, credentials or payment processing**
- Accountable owner: **RechargeN / Product owner (interim)**
- Permanent owner assignment: **Payments owner assigned by the new Accepted Payments ADR**
- Coordination baseline: [BCK-02 v2.4.82](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D5 / R10 — separately gated**

## 0. Changelog

### v0.3.1 — 2026-09-21

- normalized internal payment/refund/dispute lifecycle enum values to the
  BCK-03 lowerCamelCase rule while retaining snake_case error codes;
- assigned an explicit interim accountable owner until the new Payments ADR;
- preserved Draft/blocked status and every financial/runtime gate.

### v0.3 — 2026-09-21

- completed the Stage 5 financial lifecycle, webhook, balanced-ledger,
  reconciliation, dispute and Booking-result contract;
- fixed merchant/payout, refund/capture and market/legal/accounting boundaries;
- retained the hard new Accepted Payments ADR blocker and authorized no PSP,
  financial persistence, credentials, Firebase or deployment.

### v0.2 — 2026-09-20

- added the Stage 2 normalized future Payments entity inventory;
- separated financial authority from Booking, provider handoff and notification
  delivery while retaining the hard Accepted-ADR blocker;
- normalized money, ledger, webhook, reconciliation and evidence semantics.

### v0.1 — 2026-09-20

- created the first canonical BCK-17 design contract without selecting a PSP,
  merchant model, operating entity, payout model or tax/accounting treatment;
- defined Payment Intent/Attempt, immutable balanced subledger, verified
  webhook, refund, dispute, reconciliation and Booking-result boundaries;
- added strict card-data minimization, market gates, financial audit, rollback
  and Legal/Tax/Accounting/Security review requirements;
- kept all payment runtime blocked until a new Accepted Payments ADR.

## 1. Verdict and hard blocker

This document is intentionally **not Approved**. It cannot authorize a PSP,
merchant/acquirer agreement, payment method, card-data handling, financial
account, Firebase collection, secret, network call, deployment, paid Booking,
payout or production cohort.

The mandatory entry condition is a new Accepted Payments ADR that selects at
least the operating/merchant model, system authority, PSP boundary, funds flow,
Booking/payment orchestration, accounting ownership, dispute/refund ownership,
market order and rollback principle. Until then:

- all payment flags remain off;
- `apps/backend/.../payments` must not be created for product runtime;
- Event/Booking continues free/internal or honest external handoff only;
- no document status, test or emulator can remove the blocker.

## 2. Parents, priority and reconciliation

BCK-17 inherits without silently overriding:

1. the future Accepted Payments ADR and existing Accepted ADRs;
2. the frozen [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md),
   [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md);
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-09](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md),
   [BCK-13](NOTIFICATIONS_BACKEND_SPEC.md),
   [BCK-16](PROVIDER_INTEGRATION_BACKEND_SPEC.md),
   [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md),
   [BCK-19](ADMIN_SUPPORT_BACKEND_SPEC.md) and
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md);
4. the canonical [Event Classification](EVENT_CLASSIFICATION_SPEC.md);
5. provider documentation, implementation notes and local/mock behavior.

Once Approved after the ADR, BCK-17 owns Recharge payment intent, attempts,
operational payment subledger, refunds, disputes and reconciliation records. It
does not own Booking inventory, Event pricing configuration, PSP truth or the
company's statutory general ledger.

## 3. Dated regulatory and industry review inputs

These links are **review inputs, not a legal conclusion**. Qualified Legal,
Tax, Accounting, Security and PCI assessors must verify applicability and the
current consolidated text for the selected operating entity, market, role,
PSP, payment methods and funds flow immediately before ADR acceptance/runtime:

- [Directive (EU) 2015/2366 (PSD2), current EUR-Lex record](https://eur-lex.europa.eu/legal-content/en/TXT/?uri=CELEX%3A32015L2366);
- [Commission Delegated Regulation (EU) 2018/389 on SCA and secure communication](https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX%3A32018R0389);
- [European Commission payment-services page, including PSD3/PSR work](https://finance.ec.europa.eu/consumer-finance-and-payments/payment-services/payment-services_en);
- [Latvia Law on Payment Services and Electronic Money](https://likumi.lv/ta/en/en/id/206634);
- [Latvijas Banka payment-institution licensing guidance](https://www.bank.lv/en/licensing/payment-institutions/);
- [Regulation (EU) 2022/2554 (DORA)](https://eur-lex.europa.eu/eli/reg/2022/2554/oj), where applicable to the selected entity/service chain;
- [PCI SSC document library](https://www.pcisecuritystandards.org/document_library/), including the current applicable PCI DSS material.

The review must distinguish current binding law, national implementation,
directly applicable regulation, regulator guidance, scheme/contract rules and
future/proposed legislation. A proposal or political agreement is not silently
treated as an in-force requirement; transition planning is recorded separately.

## 4. Outcome and non-goals

### 4.1 Outcome

BCK-17 defines a provider-neutral, auditable payment boundary that can create a
priced obligation, orchestrate an external PSP attempt, verify asynchronous
results, append balanced immutable financial facts, issue cancellation/refund,
handle disputes, reconcile PSP/Booking/subledger/payout state and deliver only a
typed payment result to BCK-09.

### 4.2 Non-goals

BCK-17 does not:

- select PSP, acquirer, merchant of record or marketplace/connect model;
- determine whether Recharge provides a regulated payment service;
- hold customer funds, issue e-money or create stored-value/wallet functionality;
- own Booking inventory/confirmation or Event price/product definition;
- own statutory accounting, tax returns, invoices or organizer payouts by default;
- store/process raw PAN, CVC/CVV, PIN or authentication secrets;
- infer SCA, PCI, VAT, AML/KYC, consumer or DORA applicability;
- authorize crypto, cash, tips, donations, subscriptions or multi-party split;
- authorize Firebase, PSP credentials, deployment or paid production flows.

## 5. Scope

### 5.1 In scope

- Payment Intent, Attempt and immutable payment subledger;
- provider-neutral PSP adapter and hosted/tokenized payment boundary;
- amount/currency/tax/fee snapshots and versioned commercial reference;
- signed webhooks, replay protection and provider-event deduplication;
- authorize/capture/cancel/void/refund lifecycle;
- dispute/chargeback and evidence/response lifecycle;
- Booking integration via typed verified payment result;
- settlement/payout boundary without selecting a model;
- reconciliation, correction, audit, DSR and incident behavior;
- per-market/method/currency/entity flags and rollback.

### 5.2 Disabled until later gates

- every PSP/account/payment method/credential/network call;
- payment collection, capture, refund, dispute response and payout;
- saved payment methods, one-click, subscriptions, deposits, instalments;
- organizer onboarding/KYC/KYB, split settlement or marketplace payouts;
- chargeback automation, negative-balance recovery or collections;
- paid internal Booking and any production financial record;
- cross-border market activation beyond exact qualified approval.

## 6. Operating, merchant and funds-flow boundary

The Payments ADR must select exactly one bounded model for the first slice:

| Candidate model | Required decision boundary | Fail-closed status |
|---|---|---|
| External provider handoff only | Provider is merchant/payment authority; Recharge records no internal payment | Existing BCK-16 path only |
| Recharge/operating entity as merchant | Merchant, PSP/acquirer, tax/invoice/refund/dispute obligations and settlement account | Blocked |
| Organizer/Creator as merchant through platform model | Connected accounts, onboarding/KYB, split/payout/negative balance and platform liability | Blocked |
| Other regulated/intermediated model | Exact legal role, licensing/registration and funds flow | Blocked |

No generic “platform payment” state is permitted. The accepted model names the
contracting customer, seller/merchant, payee, funds recipient, invoice/receipt
issuer, refund/dispute owner, fees, payout owner, operating entity and regulator/
scheme/contract obligations for each market.

## 7. Ownership and single writers

| Record/fact | Authoritative writer | Consumers |
|---|---|---|
| `PaymentIntent` / current status | Payments command service | Payer/Booking/support |
| `PaymentAttempt` | Payments orchestration service | Payments/reconciliation |
| `PaymentLedgerTransaction` and entries | Payments ledger service | Reconciliation/accounting export |
| `Refund` | Payments refund service | Payer/Booking/support/accounting |
| `PaymentDispute` / chargeback | Payments dispute service | Support/accounting/risk |
| `PaymentReconciliationRun/Break` | Payments reconciliation service | Operations/accounting/support |
| `Settlement/PayoutReference` | Payments settlement adapter after ADR | Accounting/authorized merchant |
| PSP transaction/balance/payout truth | Selected PSP | BCK-17 verified mirror only |
| Event price/refund policy config | BCK-07/Event authority | BCK-17 immutable snapshot consumer |
| Booking/hold/inventory/confirmation | BCK-09 | Consumes typed payment result |
| Notification delivery | BCK-13 | Minimized accepted payment intent |
| Support/repair access | BCK-19 | Registered payment commands only |
| Statutory general ledger/tax records | Named Finance/Accounting system | BCK-17 export/reconciliation only |

Clients, consoles, PSP webhooks and staff tools never write payment state or
ledger entries directly. Payment status is derived from verified immutable
facts, not from a mobile return URL or UI success screen.

## 8. Actors, capabilities and separation of duties

| Actor/service | Allowed | Denied |
|---|---|---|
| Authenticated payer | Create/pay/read own eligible intent; request eligible refund | Foreign payment/dispute/payout access |
| Booking service | Create requirement/consume typed result | Write payment ledger or trust PSP redirect |
| Payments service | Orchestrate PSP and ledger | Confirm Booking inventory |
| PSP webhook ingress | Submit verified external fact | Direct domain/ledger write before validation |
| Refund operator | Propose/refund within scoped policy | Self-approve high-risk exception where dual control applies |
| Dispute operator | Manage assigned dispute/evidence | Reveal unrelated payment/customer data |
| Reconciliation worker | Compare sources/create breaks | Invent corrections or mutate history |
| Finance/Accounting | Review/export/approve defined journals | Product/Admin superuser authority |
| Support/Admin | BCK-19 scoped command/read | Impersonation/direct ledger edit |

High-value refunds, manual corrections, payout changes, secret operations and
write-offs use accepted maker-checker/dual-control thresholds. Revocation and
staff/session state are checked at every command.

## 9. Data classification and PCI minimization

| Data | Class | Rule |
|---|---|---|
| PAN, CVC/CVV, PIN, SCA/authentication secrets | Prohibited in Recharge systems | Use accepted hosted/tokenized PSP boundary |
| PSP payment-method token/reference | Restricted | Server-side scoped reference only |
| Billing/contact/address | Personal/protected | Collect only if exact purpose requires |
| Intent/attempt/refund/dispute | Financial/protected | Owner/scoped staff/service only |
| Ledger/reconciliation/payout | Financial/restricted | Finance/audit/service access only |
| Dispute evidence | Sensitive/restricted | Exact case scope and retention |
| Public payment state | None by default | No public payment projection |
| Logs/analytics | Operational minimized | IDs/codes/buckets; no payment-sensitive material |

Hosted checkout/components, tokenization and redirect/native-sheet choices do
not automatically remove PCI or legal obligations. The selected architecture is
reviewed against the current applicable PCI program and PSP contract. Recharge
must not receive/store raw card data merely for debugging, support or retries.

## 10. Money, price and currency contract

```text
Money { minorUnits: integer, currency: ISO-4217 uppercase }
```

Currency is explicit and never inferred from market. Integer range, zero/negative
rules and exponent/display formatting use accepted versioned reference data.
Transport and PSP adapters do not perform hidden floating-point rounding.

`PaymentAmountSnapshot` pins:

- gross amount/currency;
- item/base price and quantity where applicable;
- tax/fee/discount components only under accepted commercial/accounting policy;
- Event/offer/pricing/refund policy IDs and revisions;
- market, merchant/operating entity and payee model;
- created/expiry time and canonical hash.

Changing price/currency/merchant/policy creates a new intent; it never mutates
the financial meaning of an existing attempt or ledger transaction.

## 11. Canonical domain model

```text
PaymentIntent {
  paymentIntentId, actorUserId, merchantModelRef, merchantEntityRef,
  purposeRef, bookingRequirementRef?, amountSnapshot,
  status, captureMode, providerRef?, providerIntentRef?,
  currentAttemptId?, expiresAtUtc, revision, createdAtUtc, updatedAtUtc
}

PaymentAttempt {
  paymentAttemptId, paymentIntentId, attemptNumber, providerRef,
  providerAttemptRef?, status, requestedAmount, authenticatedOutcome?,
  failureCode?, startedAtUtc, completedAtUtc?, idempotencyRef
}

PaymentLedgerTransaction {
  ledgerTransactionId, paymentIntentId, type, currency,
  entries[], providerFactRef?, sourceOperationId,
  effectiveAtUtc, recordedAtUtc, correctionOfId?
}

PaymentLedgerEntry {
  ledgerEntryId, ledgerAccountRef, direction, minorUnits, currency
}

Refund {
  refundId, paymentIntentId, captureLedgerTransactionId,
  amount, reasonCode, status, providerRefundRef?,
  requestedByActorId, approvedByActorId?, revision, createdAtUtc
}

PaymentDispute {
  disputeId, paymentIntentId, providerDisputeRef, type, amount,
  status, reasonCode, responseDeadlineUtc?, evidenceRefs[],
  revision, openedAtUtc, closedAtUtc?
}
```

The ledger is a Payments operational subledger, not the statutory general
ledger. Each transaction is immutable and balanced per currency under the
accepted chart/sign convention. Corrections use compensating transactions;
entries and amounts are never edited or deleted.

## 12. Lifecycle and state derivation

Intent lifecycle:

```text
created -> requiresPaymentMethod -> requiresAction -> processing
processing -> authorized -> captured
created|requiresPaymentMethod|requiresAction|authorized -> cancelled|expired
any pre-capture state -> failed
```

Attempt lifecycle:

```text
created -> submitted -> requiresAction | processing
submitted|processing -> authorized | captured | failed | cancelled
requiresAction -> processing | failed | cancelled | expired
```

Refund lifecycle is `requested -> reviewRequired? -> submitted -> processing ->
succeeded | failed | cancelled`. Dispute lifecycle is `opened -> responseDue ->
submitted -> won | lost | withdrawn | expired`, using PSP-specific normalized
facts without pretending universal semantics.

Intent summary may derive `partiallyRefunded | refunded | disputed` from
immutable ledger/refund/dispute facts; those derived views never rewrite capture.

## 13. Booking integration and paid-flow saga

BCK-09 owns inventory/hold/Booking. BCK-17 owns payment. The future Payments ADR
and paid-Booking slice must choose exact authorization/capture ordering. The
safe generic orchestration boundary is:

1. BCK-09 creates an eligible Booking-owned hold/payment requirement with expiry;
2. BCK-17 creates an Intent from an immutable amount/policy snapshot;
3. PSP action/redirect occurs under BCK-17;
4. only verified PSP fact changes BCK-17 ledger/status;
5. BCK-17 issues a signed/internal typed `PaymentDecisionRef`;
6. BCK-09 validates requirement/amount/currency/status/expiry/idempotency and
   decides Booking confirmation in its own transaction;
7. failure to confirm after captured funds creates an explicit compensation
   obligation (void/refund/reconciliation), never silent success.

`PaymentDecisionRef` contains payment intent/result/ledger transaction IDs,
amount/currency, verified status, provider fact revision, occurred time and
integrity/version metadata. It contains no card/payment-method secret.

Provider return URL, client screenshot, cached state or unverified webhook is
never a payment decision. Payment result never reserves inventory by itself.

## 14. PSP adapter and client boundary

The Payments domain depends on a provider-neutral `PaymentProviderGateway`.
Adapter owns vendor SDK/types, credential/token serialization, payment-method
session, SCA/next-action mapping, authorize/capture/cancel/refund calls, provider
query and webhook normalization. Vendor types never escape the adapter.

Mobile receives only bounded checkout/session material explicitly designed for
the accepted PSP integration; it never receives secret keys, raw financial
credentials or ledger authority. Client “completed” means only that a PSP/user
interaction ended; authoritative status comes from verified server retrieval or
webhook/reconciliation.

## 15. Webhook authenticity and replay protection

Each PSP ingress has exact endpoint/provider/account/environment binding and
enforces raw-body requirements, content type/size, signature/key version,
timestamp/freshness, replay window, provider event ID, payload schema and tenant/
object scope before domain processing. Failed verification produces no domain
or ledger mutation.

Webhook receipts are immutable and deduplicated by verified provider/account/
event identity plus semantic object/fact protection where needed. Delivery order
and exactly-once are never assumed. Stale/out-of-order events cannot regress a
newer accepted fact; gaps trigger provider retrieval/reconciliation. Secret/key
rotation supports bounded overlap and audit.

## 16. Commands, queries and typed outcomes

Commands:

- `CreatePaymentIntent`, `CreatePaymentMethodSession`;
- `SubmitPaymentAttempt`, `ConfirmNextActionResult`;
- `AuthorizePayment`, `CapturePayment`, `CancelOrVoidPayment`;
- `RequestRefund`, `ApproveRefund`, `SubmitRefund`;
- `RecordVerifiedProviderFact`, `OpenOrUpdateDispute`;
- `SubmitDisputeEvidence`, `CloseDispute`;
- `RunPaymentReconciliation`, `ResolveReconciliationBreak`;
- registered emergency/credential/flag commands through BCK-05/BCK-19.

Queries:

- payer's bounded intent/status/receipt/refund/dispute view;
- internal typed payment decision for exact Booking requirement;
- capability-scoped support/finance intent/ledger/reconciliation/dispute views;
- provider/settlement/payout aggregate without secrets or raw card data.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, payments_disabled,
market_disabled, method_unsupported, currency_unsupported,
amount_invalid, amount_mismatch, price_expired, requirement_expired,
merchant_model_unavailable, provider_disabled, provider_unavailable,
provider_timeout, provider_rate_limited, authentication_required,
authentication_failed, payment_declined, insufficient_funds,
payment_failed, intent_expired, already_processed, invalid_transition,
idempotency_conflict, signature_invalid, replay_detected,
refund_not_allowed, refund_amount_exceeded, dispute_state_conflict,
reconciliation_required, accounting_hold, legal_review_required,
temporarily_unavailable, cancelled
```

Provider decline codes are normalized to privacy-safe/user-safe categories;
restricted fraud/risk details are not returned to clients.

## 17. Contract versions and compatibility

Contract/API/schema/provider-adapter/webhook/event/ledger/policy/price/payment-
method/accounting-export versions are independent and pinned. Unknown critical
enum affecting money, authority, SCA, refund, dispute, merchant or Booking fails
closed; no generic property bag bypasses validation.

Breaking meaning/requiredness/status/ledger/account mapping requires a new
version, migration, fixtures, minimum-client/consumer evidence and rollback.
Historical intents/ledger entries remain interpretable under their original
versions. Retired adapters can reconcile history but cannot receive new traffic.

## 18. Idempotency, concurrency and transaction boundaries

Create/attempt/capture/cancel/refund/dispute/reconciliation commands use scoped
idempotency keys and canonical semantic hashes. Same key plus different request
returns conflict. PSP idempotency keys are deterministically scoped but never
assumed to replace Recharge idempotency/ledger controls.

Optimistic revision applies to mutable workflow records. Money/lifecycle changes
never use silent last-write-wins. Atomic local boundaries include intent state,
attempt/provider fact, balanced ledger transaction, audit and outbox. External
PSP plus BCK-09 cannot form one database transaction; durable saga obligations,
reconciliation and compensating actions make partial state explicit.

## 19. Capture, cancel, refund and correction rules

Capture mode (`automatic | manual`) is an accepted method/PSP/purpose policy,
not a client choice. Capture validates authorized amount/currency/expiry and
cannot exceed permitted authorization/adjustment rules. Cancel/void targets
uncaptured authorization where supported; it never fabricates refund success.

Refund validates captured/refunded/disputed amounts in the same currency and
accepted refund policy. Partial/multiple refunds cannot exceed refundable amount.
Provider submission and provider success are separate states. Failed/unknown
refund remains reconcilable and does not notify success.

Ledger corrections are compensating journal transactions linked to the original
and approved reason/actor; immutable history is preserved. Manual PSP dashboard
actions create reconciliation breaks until verified/imported and cannot be
silently copied as trusted internal commands.

## 20. Disputes, chargebacks and evidence

Provider dispute/chargeback is recorded only from verified provider retrieval or
webhook. It pins payment/ledger/provider fact, amount/currency, reason/status,
deadline and evidence requirements. Dispute state never deletes or rewrites
capture/refund history.

Evidence uses BCK-14 protected references and scoped access, not arbitrary URLs
or general support notes. Submission requires exact capability, deadline,
provider schema and audit. Customer/reporter/payment data is minimized. Win/loss
posts accepted immutable ledger facts and reconciliation/accounting obligations;
it does not directly change Booking/content.

## 21. Settlement, payouts, fees and accounting boundary

Settlement/payout remains blocked until the ADR selects merchant/payee model.
If Recharge is merchant, BCK-17 may mirror PSP balance/settlement/payout facts and
export reconciled journal data. If organizers are merchants/payees, onboarding,
KYB, connected accounts, splits, reserves, negative balance and payout liability
require a separate Approved scope.

Fees, commissions, taxes, reserves, FX and payouts are distinct typed components
with currency/source/policy, not inferred from net provider amount. PSP payout/
balance truth, BCK-17 subledger and statutory general ledger remain separate and
reconciled. Accounting owns chart mapping, period close, correction/write-off
approval and statutory retention/export.

## 22. Reconciliation

Reconciliation compares at minimum:

1. verified PSP intents/charges/captures/refunds/disputes/balance transactions;
2. BCK-17 attempts and immutable balanced ledger;
3. BCK-09 payment requirements/holds/Bookings/compensation obligations;
4. settlement/payout records where applicable;
5. Finance/accounting export acknowledgements where applicable.

Runs are checkpointed, repeatable and idempotent. Break types are closed/versioned
(missing, duplicate, amount/currency/status mismatch, orphan, late, payout gap,
Booking compensation, accounting export gap). Break resolution is proposal ->
approval where required -> registered command -> verification receipt; no direct
record edit. Period close does not hide unresolved breaks.

## 23. Events, outbox and notification boundary

After Accepted OD-09, Payments ADR and runtime authorization, minimized events
may include:

- `payment.intentCreated`, `payment.authorizationChanged`;
- `payment.captured`, `payment.cancelled`, `payment.failed`;
- `payment.refundChanged`, `payment.disputeChanged`;
- `payment.reconciliationBreakOpened`, `payment.compensationRequired`.

Events contain stable IDs, versions, amount/currency where the consumer is
authorized, and bounded status/reason; never card/payment-method data, billing
details, secret, raw PSP payload or unrestricted fraud signal. Outbox is atomic
with ledger/source state. BCK-13 owns delivery; notification success is not
payment success.

## 24. Privacy, retention, DSR and consumer transparency

The accepted model documents purpose/legal basis where applicable, payer/
merchant/participant disclosures, PSP/subprocessors, residency, fraud/risk data,
retention, deletion/restriction/export and rights limitations for financial/
security/legal records. Qualified review decides applicable exceptions; neither
“financial” nor “fraud” creates indefinite blanket retention.

DSR/export distinguishes user-facing payment history from restricted fraud,
dispute, staff, ledger and legal records. Erasure/restriction is executed through
domain handlers with explicit retained/pseudonymized outcomes. Client UI clearly
shows merchant/payee, amount/currency, recurring status if any, external PSP,
refund/dispute path and authoritative status/freshness.

## 25. Security, fraud and abuse controls

Controls include dedicated workload identity, Secret Manager/KMS, environment/
PSP-account isolation, encrypted transport/storage, webhook/replay/SSRF/redirect
defenses, scoped hosted checkout, rate/value/velocity limits, session/capability
revocation, anomaly/fraud signals and least-privilege staff access. App Check is
supplementary and never authorizes money movement.

Fraud/risk rules/models are versioned, explainable at a safe reason-category
level, monitored for false positives and separated from public/product analytics.
They cannot silently change amount, merchant, payee, Booking or refund policy.
High-impact holds/rejections/manual overrides use accepted review/appeal/support
process. Secrets/payment data never enter logs, crash reports or fixtures.

## 26. Legal, Tax, Accounting and Security gates

Before any runtime slice, named qualified reviewers must record applicability,
obligations, owners and retained evidence for:

- entity/merchant/payee/payment-service role and licensing/registration;
- PSP/acquirer/scheme contracts, payment methods, SCA and consumer disclosures;
- AML/KYC/KYB/sanctions obligations where applicable to the selected model;
- VAT/tax/fees/invoice/receipt and cross-border treatment;
- refunds, complaints, disputes/chargebacks and support/contact obligations;
- safeguarding/settlement/payout/negative-balance treatment where applicable;
- GDPR/privacy, retention/DSR and cross-border transfers;
- PCI DSS/card-data scope and attestation path where applicable;
- DORA/ICT/outsourcing/incident/resilience requirements where applicable;
- statutory accounting, financial audit and record-retention mapping.

An `N/A` disposition names reviewer, rationale, scope and revalidation trigger.
Product/technical-owner agreement cannot substitute for qualified evidence.

## 27. Observability, SLO, audit and cost

Operational metrics include stage latency/outcome, provider/webhook delay,
authorize/capture/refund/dispute/reconciliation rates, ledger imbalance (must be
zero), compensation age, unresolved breaks, payout/accounting-export lag,
fraud/rate controls and provider/processing cost. Logs use bounded IDs/codes and
exclude payment method, billing, raw provider/evidence and secret data.

Financial audit preserves actor/service identity, command/operation/provider
fact, before/after workflow revision, immutable ledger transaction, policy/
adapter version and timestamps. Numeric SLOs, alerts, fraud/value limits, budget,
close/reconciliation deadlines and retention are accepted before runtime. Product
analytics remains BCK-21-owned and cannot use financial records opportunistically.

## 28. Flags, rollout, rollback and emergency disable

Independent server flags cover Payments globally and by environment, entity,
market, currency, PSP, method, capture mode, paid product/Booking cohort,
refund, dispute, payout and staff operation. All default off.

Rollout sequence is contract/fixture -> PSP sandbox -> emulator/local ledger ->
staging synthetic -> internal controlled real-money only after approval -> bounded
cohort -> wider cohort. Test mode and live mode use separate accounts/secrets/
webhooks and cannot be promoted by config accident.

Rollback stops new intents/captures while preserving safe status/refund/dispute/
reconciliation/support paths. It drains/quarantines webhooks, revokes credentials
where needed, preserves ledger/audit and fulfills already-created obligations.
Emergency disable never deletes money facts or strands users without an owner.

## 29. Migration and provider replacement

No current local/mock/external-link state is imported as successful payment.
Paid legacy/external records, if later eligible, require verified provider
identity, dry-run, user/merchant/Booking mapping, amount/currency reconciliation,
duplicate protection, disclosure and rollback. Unknown remains external/unknown.

PSP replacement creates a new adapter/account/policy and preserves old PSP refs
for refunds/disputes/reconciliation. Existing intents are not silently moved.
Payment-method tokens are provider-scoped and not assumed portable. Dual-run or
cutover requires bounded cohort, exact routing, reconciliation and rollback.

## 30. Backup, restore and disaster recovery

Backups preserve encrypted immutable ledger/audit/workflow state under accepted
retention but do not restore expired/revoked secrets, live sessions or stale PSP
authority. Restore into isolated environment verifies counts, hashes, balanced
ledger, cursor/checkpoint, provider/account mapping and post-backup external facts.

After restore, outbound money mutation remains disabled until reconciliation
with PSP/Booking/accounting completes. RPO/RTO and emergency/refund/dispute
continuity are accepted/tested with BCK-05. Replay cannot duplicate capture,
refund, payout or notification.

## 31. Conditional implementation file map

No file below is authorized before the Payments ADR and an exact Approved slice:

```text
packages/api_contracts/schemas/payments/
packages/api_contracts/fixtures/payments/
apps/backend/functions/src/modules/payments/domain/
apps/backend/functions/src/modules/payments/application/
apps/backend/functions/src/modules/payments/data/
apps/backend/functions/src/modules/payments/transport/
apps/backend/functions/src/modules/payments/providers/<psp>/
apps/backend/functions/src/modules/payments/webhooks/
apps/backend/functions/src/modules/payments/workers/
apps/backend/functions/src/modules/payments/reconciliation/
apps/backend/functions/test/contract/payments/
apps/backend/functions/test/emulator/payments/
```

Secrets/IAM/IaC remain BCK-05-owned; Booking adapter stays BCK-09-owned; Finance/
accounting export has a separately accepted boundary. Generated files are
generator-only. Absence of this directory is the correct current state.

## 32. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Money | integer minor units, currency/exponent/range/rounding and overflow |
| Domain | all intent/attempt/refund/dispute transitions and forbidden paths |
| Ledger | balance per currency, immutability, compensation and derived status |
| Contract | schemas/fixtures/version/unknown-critical-value fail-closed |
| Idempotency | create/capture/refund/webhook/retry/timeouts and hash mismatch |
| Webhook | raw body, signatures, rotation, replay, order, duplicates and gaps |
| Booking | hold/payment/capture/confirm/compensation race/failure matrix |
| Security/PCI | no raw card data, secrets/IAM/SSRF/redirect/log/fixture checks |
| Authorization | payer/merchant/staff/finance/service/revocation/dual control |
| Reconciliation | PSP/subledger/Booking/payout/accounting every break type |
| Refund/dispute | partial/max/deadline/evidence/win/loss/unknown provider state |
| Emulator | transactions, Rules/IAM, outbox, leases, restore and flags |
| Resilience | PSP outage, retry storm, delayed webhook, worker crash/poison |
| Market | entity/method/currency/LV then EE/LT independent activation |
| Load/cost | peak attempts/webhooks/reconciliation, limits and hard budget stop |
| Operations | incident, secret compromise, emergency disable, refund continuity |

Real-money tests require separate exact authority, bounded amounts/accounts and
reconciliation/cleanup. Unrun, sandbox-only where live proof is required,
timed-out, unsigned or environment-blocked checks are `Inconclusive`.

## 33. Dependency and delivery gates

BCK-17 cannot become `Review-ready for runtime` or `Approved` before the new
Accepted Payments ADR. After the ADR, Approval additionally requires applicable
BCK-03/04/05/06/09/13/16/18/19/20 boundaries; exact PSP/method/entity/merchant/
market model; Legal/Tax/Accounting/Security/Privacy/PCI verdicts; accepted paid-
Booking saga; contracts/fixtures; operations/cost/DR ownership.

R10 requires an exact Approved implementation slice, green sandbox/emulator/
security/concurrency/reconciliation tests, staging evidence, trained support/
finance owners, exercised rollback/incident/refund/dispute procedures and
default-off market flags. Document completion authorizes none of those steps.

## 34. Definition of Ready

BCK-17 is ready for ADR drafting when:

- business owner states why internal payment is needed versus external handoff;
- candidate entity/merchant/payee/funds-flow and PSP models are documented;
- Booking/hold/capture/refund/compensation choices are explicit;
- Legal/Tax/Accounting/Security/Privacy/Finance owners are assigned;
- supported first market/product/currency/method is bounded;
- every open decision has fail-closed default and evidence owner.

It is ready for implementation review only after the Payments ADR is Accepted
and BCK-17 is amended/reviewed against that exact decision.

## 35. Definition of Done

Documentation Done requires Accepted Payments ADR, attributable qualified and
technical reviews, resolved blockers, exact contract/slice map, traceable AC and
atomic BCK-01/BCK-02/LAUNCH_STATUS reconciliation. This v0.1 is intentionally
not Done and cannot claim Approval.

Runtime Done is separately defined by R10: deployed code is insufficient without
financial correctness, reconciliation, support/accounting operations, rollback,
incident evidence and explicit market activation.

## 36. Acceptance criteria

1. **BCK-17-AC-01:** New Accepted Payments ADR is a hard prerequisite.
2. **BCK-17-AC-02:** All payment runtime/PSP/Firebase/deployment remains blocked.
3. **BCK-17-AC-03:** Operating entity and merchant/payee model are explicit.
4. **BCK-17-AC-04:** Funds flow and each obligation have a named owner.
5. **BCK-17-AC-05:** BCK-17 owns payment records, not Booking inventory.
6. **BCK-17-AC-06:** PSP truth, subledger and statutory ledger stay distinct.
7. **BCK-17-AC-07:** Mobile/redirect/UI success never proves payment success.
8. **BCK-17-AC-08:** Only verified server facts change payment state.
9. **BCK-17-AC-09:** Raw PAN/CVC/PIN/SCA secrets never enter Recharge systems.
10. **BCK-17-AC-10:** PSP tokens/refs are restricted and server scoped.
11. **BCK-17-AC-11:** PCI scope is assessed, not assumed away by tokenization.
12. **BCK-17-AC-12:** Money uses integer minor units and explicit ISO currency.
13. **BCK-17-AC-13:** Currency is never inferred from market.
14. **BCK-17-AC-14:** Existing attempt/ledger financial meaning is immutable.
15. **BCK-17-AC-15:** Price snapshot pins policy/entity/market/hash/expiry.
16. **BCK-17-AC-16:** Ledger transactions are immutable and balanced per currency.
17. **BCK-17-AC-17:** Corrections use linked compensating transactions.
18. **BCK-17-AC-18:** Statutory general ledger remains Finance-owned.
19. **BCK-17-AC-19:** Intent/attempt/refund/dispute lifecycles are typed.
20. **BCK-17-AC-20:** Derived refund/dispute status never rewrites capture facts.
21. **BCK-17-AC-21:** Booking creates/owns hold and confirmation decision.
22. **BCK-17-AC-22:** Payment result alone never reserves/confirms inventory.
23. **BCK-17-AC-23:** Booking validates amount/currency/status/expiry/idempotency.
24. **BCK-17-AC-24:** Captured-but-unconfirmed state creates compensation obligation.
25. **BCK-17-AC-25:** PSP adapter types remain behind provider-neutral gateway.
26. **BCK-17-AC-26:** Client next-action material grants no ledger authority.
27. **BCK-17-AC-27:** Webhooks verify signature/key/time/replay/schema/scope.
28. **BCK-17-AC-28:** Invalid webhooks cause no payment/ledger mutation.
29. **BCK-17-AC-29:** Provider event delivery order/exactly-once is not assumed.
30. **BCK-17-AC-30:** Stale events cannot regress accepted financial state.
31. **BCK-17-AC-31:** Every money mutation has scoped semantic idempotency.
32. **BCK-17-AC-32:** Same key with changed request returns conflict.
33. **BCK-17-AC-33:** Local financial transaction includes ledger/audit/outbox.
34. **BCK-17-AC-34:** PSP/Booking partial states use durable saga/reconciliation.
35. **BCK-17-AC-35:** Capture cannot exceed accepted authorization rules.
36. **BCK-17-AC-36:** Refund totals cannot exceed refundable captured amount.
37. **BCK-17-AC-37:** Refund submission and success are separate states.
38. **BCK-17-AC-38:** Unknown refund/provider state remains reconcilable.
39. **BCK-17-AC-39:** Disputes preserve capture/refund history.
40. **BCK-17-AC-40:** Dispute evidence uses protected scoped references.
41. **BCK-17-AC-41:** Payout/split/KYB stays blocked until selected model.
42. **BCK-17-AC-42:** Fees/tax/reserve/FX/payout components are typed.
43. **BCK-17-AC-43:** Reconciliation covers PSP/subledger/Booking/payout/accounting.
44. **BCK-17-AC-44:** Every reconciliation break has typed resolution/audit.
45. **BCK-17-AC-45:** Period close cannot hide unresolved breaks.
46. **BCK-17-AC-46:** Events/logs exclude payment method/secret/raw payload.
47. **BCK-17-AC-47:** Notification success never means payment success.
48. **BCK-17-AC-48:** Retention/DSR exceptions require qualified review.
49. **BCK-17-AC-49:** Fraud rules cannot silently change money/domain policy.
50. **BCK-17-AC-50:** App Check never authorizes money movement.
51. **BCK-17-AC-51:** Legal/Tax/Accounting/Security/Privacy/PCI gates are explicit.
52. **BCK-17-AC-52:** Future/proposed rules are not treated as current law.
53. **BCK-17-AC-53:** Product owner cannot substitute qualified verdicts.
54. **BCK-17-AC-54:** Ledger imbalance alert threshold is zero.
55. **BCK-17-AC-55:** Financial and product analytics remain separated.
56. **BCK-17-AC-56:** Every market/entity/method/currency flag defaults off.
57. **BCK-17-AC-57:** Test/live PSP accounts/secrets/webhooks are isolated.
58. **BCK-17-AC-58:** Rollback preserves ledger and existing obligations.
59. **BCK-17-AC-59:** Restore disables money mutation until reconciliation.
60. **BCK-17-AC-60:** Documentation acceptance authorizes no financial runtime.

## 37. Explicit unimplemented list

- Payments ADR, owner, operating/merchant/payee/funds-flow decision;
- PSP/account/method/contracts/credentials/network/webhook endpoints;
- API schemas, fixtures, generated clients and payment domain runtime;
- ledger, persistence, Rules/IAM, outbox, workers and reconciliation;
- paid BCK-09 saga and mobile checkout adapter;
- refund/dispute/payout/accounting/support operations;
- qualified Legal/Tax/Accounting/Security/Privacy/PCI evidence;
- sandbox/staging/real-money tests, SLOs, DR and market activation.

## 38. Decisions required for the Payments ADR

| Decision | Owner/evidence | Fail-closed default |
|---|---|---|
| Business need and first paid product | Product/Business | external handoff/free only |
| Operating entity and merchant/payee/funds flow | Legal/Finance | no internal payments |
| PSP/acquirer, methods, account and regions | Payments/Security/Legal | none selected |
| Booking authorize/capture/hold/compensation order | Booking + Payments | paid Booking disabled |
| Tax/VAT/invoice/receipt/accounting mapping | Tax/Accounting | no capture |
| Refund/cancellation/dispute/chargeback ownership | Legal/Support/Finance | no paid cohort |
| Payout/split/KYB/negative-balance model | Legal/Finance/Risk | payouts disabled |
| PCI/SCA/fraud/security/IAM/webhook scope | Security/qualified assessor | no provider traffic |
| Retention/DSR/residency/incident/outsourcing | Privacy/Legal/Operations | no persistence |
| First market/entity/currency/method/limits | Market/Finance/Product | all markets disabled |

## 39. Final statement

BCK-17 provides a complete technical review baseline for future Payments while
making the most important fact explicit: Recharge currently has no accepted
payment authority. Until a new Payments ADR and all retained professional gates
are complete, the correct product state is free internal Booking or honest
external provider handoff — never hidden or partially implemented Payments.

## 40. Stage 2 normalized future Payments entity contract

This section is design-only and does not weaken the hard new-ADR blocker.
All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| PaymentIntent | Payments / intent handler | Booking typed-result consumer and authorized user/Admin | paymentIntentId + purpose/booking reference + integer minor units/currency |
| PaymentAttempt | Payments / PSP adapter orchestrator | intent status/reconciliation | attemptId + intentId + provider reference; provider reference is not authority |
| FinancialLedgerEntry | Payments / append-only ledger | reconciliation, Finance and audit | ledgerEntryId + balanced account refs + minor units/currency + UTC instant |
| WebhookReceipt | Payments / verified webhook handler | attempt/reconciliation workflow | receiptId + provider event ID/signature timestamp/hash |
| Refund | Payments / refund handler | user/Booking/Finance projections | refundId + intent/ledger refs + minor units/currency |
| DisputeChargeback | Payments / dispute handler | Finance, Support and Booking consequence adapter | disputeId + provider/intent/ledger refs + revision |
| MerchantPayoutRecord | Payments / future payout handler defined only by Accepted ADR | Finance/merchant projection | payoutId + merchant/ledger refs; absent until ADR scope permits |

The lifecycle for Intent/Attempt/Refund/Dispute uses monotonic transitions; PSP callbacks
cannot skip internal verification/reconciliation. Float money, mutable/deleted
ledger entries, duplicate capture/refund, client success and provider result as
Booking authority are forbidden. Commands/webhooks use semantic idempotency and
expected revision; each ledger mutation is one balanced atomic transaction,
while Booking receives a typed result afterward. Financial classification,
authorization, retention/legal holds and audit require BCK-04 plus qualified
Legal/Tax/Accounting/Security decisions. Telemetry excludes payment instruments.
Migration/reconciliation and rollback are ledger adjustments, never history
rewrite. PSP/market/payment flags default off. Evidence must cover signatures,
replay, double-spend/refund, currency/minor units, reconciliation, disputes,
financial audit and market isolation—only after the Accepted ADR.

## 41. Stage 5 complete-but-blocked Payments contract

This section closes design coverage only. Every command, schema, PSP call,
credential, collection, ledger write, webhook endpoint, payout and market flag
below remains unauthorized until a new Accepted Payments ADR and the named
Legal/Tax/Accounting/Security/Operations/domain gates are recorded.

### 41.1 Intent, attempt and money lifecycle

| Boundary | Payments authority after ADR | Required invariants |
|---|---|---|
| PaymentIntent | requested business amount/purpose/Booking reference | integer minor units, ISO currency, immutable commercial terms revision |
| PaymentAttempt | one PSP/payment-method interaction | idempotency, PSP reference uniqueness, monotonic verified state |
| Authorization/capture/cancel | internal orchestration after verified PSP result | amount/currency limits, no double capture, partial operations explicitly policy-gated |
| Refund | separate command and balanced ledger adjustment | cumulative refund ≤ captured amount, independent idempotency and reason |
| Dispute/chargeback | immutable external case plus internal adjustments | evidence/deadlines/fees/status revisions; never silent ledger rewrite |
| Merchant/payout | separate future ledger/workflow | operating/merchant model, beneficiary, tax/accounting and segregation fixed by ADR |

Client success, provider redirect, handoff or unverified callback never changes
internal financial state. Booking consumes only a typed internal payment result
after Payments verifies and records the authoritative transition; Payments
does not mutate Booking storage, capacity or Event state.

### 41.2 Webhook, ledger and reconciliation

Webhook ingress verifies provider/endpoint identity, signature over raw body,
timestamp/skew, event/nonce replay, payload hash/schema, environment/merchant
and intent/attempt mapping before an immutable receipt is accepted. Duplicate
same-hash events return prior disposition; same event ID with changed content
is a security conflict. Processing is idempotent and every financial change
creates a balanced atomic ledger transaction. Ledger entries are append-only;
correction uses linked reversal/adjustment entries.

Reconciliation compares internal intent/attempt/ledger totals with PSP
settlement, refunds, disputes, fees and payouts by currency and merchant. Gaps,
unknown outcomes and rounding/currency mismatches stop affected operations and
create audited Finance/Admin work; they never auto-confirm Booking or invent a
balancing transaction without approved policy.

### 41.3 Security, privacy and market enablement

Recharge stores no raw PAN/CVC and minimizes payment-instrument data according
to the future ADR/PSP scope. Secrets are BCK-05 references; staff access and
repair use BCK-19 propose/approve and a Payments-owned command. Financial
audit, provider receipt, ledger, user-facing projection, dispute evidence,
support evidence and analytics use distinct access/retention classes.

Each payment method, currency, merchant, PSP and LV/EE/LT market remains an
independent default-off capability. Enabling Latvia does not enable Estonia or
Lithuania. Tax, invoicing, consumer, refund, dispute, payout, residency and
accounting evidence is market/entity-specific.

### 41.4 Rollback and blocked state

Deployment rollback never reverses financial history. Operational rollback
disables new intents/captures, preserves verified refunds/cancels and reconciles
in-flight/unknown attempts. Business reversal uses explicit cancel/refund/
ledger-adjustment commands. No local/mock, provider or Booking state may
simulate paid/settled success.

### 41.5 Additional acceptance criteria

61. **BCK-17-AC-61:** BCK-17 remains hard-blocked until a new Accepted Payments ADR.
62. **BCK-17-AC-62:** Intent, Attempt, ledger, refund, dispute and payout remain separate records/lifecycles.
63. **BCK-17-AC-63:** Every amount is integer minor units plus explicit ISO currency.
64. **BCK-17-AC-64:** Client redirect/provider handoff/unverified callback never changes financial authority.
65. **BCK-17-AC-65:** Capture/cancel/refund are idempotent and bounded by verified prior amounts/states.
66. **BCK-17-AC-66:** Webhook verifies identity, raw-body signature, time, replay, hash, schema and mapping.
67. **BCK-17-AC-67:** Same provider event ID with changed payload is a security conflict.
68. **BCK-17-AC-68:** Every financial mutation creates a balanced atomic append-only ledger transaction.
69. **BCK-17-AC-69:** Corrections use linked reversals/adjustments, never ledger rewrite/delete.
70. **BCK-17-AC-70:** Reconciliation covers settlement, refund, dispute, fee and payout per currency/merchant.
71. **BCK-17-AC-71:** Unknown/mismatched reconciliation stops affected operations without Booking confirmation.
72. **BCK-17-AC-72:** Booking consumes typed internal payment result and Payments never writes Booking storage.
73. **BCK-17-AC-73:** Staff repair uses BCK-19 approval and a Payments-owned command.
74. **BCK-17-AC-74:** PSP/method/currency/merchant and LV/EE/LT enable independently default-off.
75. **BCK-17-AC-75:** v0.3.1 authorizes no PSP, credential, ledger runtime, Firebase, deployment or paid flow.
