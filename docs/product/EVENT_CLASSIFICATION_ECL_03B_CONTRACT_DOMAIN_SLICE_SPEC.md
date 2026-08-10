# ECL-03B — Shared Booking contracts and pure domain foundation

- Версия: 1.1
- Дата: 2026-08-09
- Статус: **Done — contracts/pure domain only; no Booking runtime**
- Parent:
  [EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md](EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md),
  Approved v1.1
- Architecture:
  [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md), Accepted
- Decisions:
  [EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md),
  Accepted D01-D10
- API governance:
  [API_CONTRACTS_WORKFLOW.md](../api/API_CONTRACTS_WORKFLOW.md)
- Runtime effect: **none**

## 1. Goal

ECL-03B establishes one versioned, cross-language Booking wire contract and a
pure Flutter-domain projection that later ECL-03 stages can implement without
inventing new lifecycle semantics.

The slice produces:

- JSON Schema Draft 2020-12 Booking v1 source contracts;
- valid, invalid and forward-compatibility fixtures;
- fixture-verified Dart transport DTOs without generated output;
- pure Booking, Hold, policy, failure and action-readiness domain types;
- deterministic validation/transition-readiness use cases;
- package and mobile unit tests.

It does not create a Booking, reserve capacity, call a server, persist data,
change Event Create, expose UI or claim production readiness.

## 2. Fixed boundaries

### 2.1 Included

1. Independent Booking v1 transport vocabulary.
2. Booking and BookingHold read projections.
3. Command envelopes and typed results/errors for the parent-spec command set.
4. Versioned uniform concurrency policy projection from Accepted D06.
5. Closed v1 enums and fail-closed handling of unsupported enum/schema values.
6. Pure local validation of already-received data.
7. Pure evaluation of whether an action is structurally eligible to be
   offered; this never asserts server authorization or capacity.
8. Shared fixtures usable later by the TypeScript backend.

### 2.2 Excluded

- `apps/backend`, Firebase configuration, Functions, Rules or deployment;
- HTTP/callable client, repository, datasource, mapper or DI registration;
- controller/application orchestration;
- persistence, cache, local confirmed Booking or offline mutation queue;
- inventory calculation, ledger mutation, cap counters or waitlist ordering;
- notification delivery, scheduler, reconciliation or support repair;
- Auth/Creator/Page authority implementation;
- Event draft schema v4, attendance configuration or auxiliary-track editor;
- Details/Profile/Creator/Notifications/Create presentation;
- provider Booking, Payments, deposits, assigned seating or paid tickets;
- edits to `EventCreateBlock`.

Any excluded work requires its own later ECL-03 stage.

## 3. Contract source and compatibility decision

### ECL03B-D01 — Accepted

Use JSON Schema Draft 2020-12 under
`packages/api_contracts/schema/booking/v1/` as the normative wire source.

For ECL-03B:

- Dart DTOs are hand-authored consumer implementations, not generated files;
- every DTO is verified against the same checked-in fixtures;
- a bounded test validator supports only the schema keywords used by Booking
  v1 and fails if an unapproved keyword appears;
- no file is written under `generated/`;
- the future TypeScript backend must consume the same fixtures before it can
  implement mutations;
- choosing a production generator remains a separate reviewed tooling change;
- package version moves from `0.1.0` to `0.2.0` because the addition is
  backward compatible.

This satisfies the Accepted `generated/fixture-verified` contract without
introducing an unreviewed generator or runtime dependency.

## 4. Wire contract

### 4.1 Common envelope rules

- JSON field names use `lowerCamelCase`.
- IDs are non-empty opaque strings; ULID format enforcement belongs to the
  authoritative producer, while consumers reject blank IDs.
- timestamps are required UTC RFC 3339 strings ending in `Z`.
- revisions and schema versions are non-negative integers.
- absent optional field and explicit `null` have the same v1 meaning only when
  the schema marks the field nullable.
- unknown object fields are rejected for mutation commands.
- read projections may preserve a raw unsupported payload only in the typed
  `unsupportedContract` result; they never coerce it into a known state.
- enum values are exact, case-sensitive wire values.
- transport parsing never defaults an unknown state to `confirmed`,
  `available`, `cancelled` or `free`.

### 4.2 Booking projection

Required fields:

```text
id, schemaVersion, revision, userId, eventId, occurrenceId,
admissionMode, confirmationMode, state, participantUnits,
reconfirmationState, createdAt, updatedAt
```

Optional fields follow parent §6.1 exactly:

```text
inventoryPoolId, channel, auxiliaryTrackId, namedGuests,
eligibilitySnapshotRef, activeHoldId, terminalReason,
confirmedAt, cancelledAt, expiredAt
```

`participantUnits >= 1`. Named guest payload is bounded by schema but remains
private transport data; mobile domain exposes no analytics-friendly free-text
projection.

### 4.3 Hold projection

BookingHold follows parent §6.2. Only `waitlistOffer` exists in v1. Its states
are `active`, `accepted`, `declined`, `expired`, `released`. An active hold has
a future `expiresAt`; all terminal holds require `resolvedAt`.

### 4.4 Policy projection

BookingPolicy v1 fixes Accepted D06:

```text
policyVersion: 1
maxConcurrentFiniteAllocations: 5
countingRule: onePerBookingOrActiveHold
unlimitedBookingCounts: false
```

The client may display the policy but cannot calculate authoritative usage or
override it.

### 4.5 Commands

The shared command envelope includes:

```text
schemaVersion, commandType, requestId, idempotencyKey,
expectedBookingRevision?, occurredAgainstEventRevision?, payload
```

Supported v1 command types:

```text
createBooking
cancelBooking
approveApplication
rejectApplication
joinWaitlist
leaveWaitlist
acceptWaitlistHold
declineWaitlistHold
reconfirmBooking
```

Actor/user/publisher authority is never accepted from command payload. The
backend derives actor identity and capabilities from the verified token.

ECL-03B only represents commands as immutable data. It adds no method that can
send or execute them.

### 4.6 Result and error

Result kinds:

```text
succeeded
rejected
retryableFailure
unsupportedContract
```

The error vocabulary includes all parent §19 codes, including
`sold_out`, `window_closed`, `eligibility_failed`, `concurrency_cap_reached`,
`revision_conflict`, `idempotency_conflict`, `hold_expired`, `forbidden`,
`unsupported_schema` and `temporarily_unavailable`.

Errors contain stable code, retryability, correlation ID and optional
allowlisted details. They contain no access secret, guest identity,
eligibility evidence or application free text.

## 5. Mobile domain contract

The mobile Booking domain is intentionally independent of transport DTOs.
It contains immutable domain projections and pure decisions only.

### 5.1 Entities/value objects

- `Booking`: authoritative read projection with explicit state/revision.
- `BookingHold`: authoritative hold projection.
- `BookingPolicy`: received policy snapshot, never a local authority.
- `BookingFailure`: typed failure safe for application/presentation.
- `BookingAction`: user/creator action vocabulary.
- `BookingActionReadiness`: `allowed`, `blocked`, or `requiresServerCheck`,
  with stable reason codes.

### 5.2 Pure use cases

`ValidateBookingProjectionUseCase` checks structural and cross-field
invariants after mapping. It never repairs invalid data.

`EvaluateBookingActionReadinessUseCase` determines only whether an action is
locally impossible from authoritative state, for example:

- cancel is blocked for terminal Booking;
- reconfirm is offered only when reconfirmation is required and open;
- accepting a hold requires an active non-expired hold reference;
- creator approval is structurally relevant only to pending application;
- every capacity-changing action otherwise returns `requiresServerCheck`.

`ValidateBookingStateTransitionUseCase` validates a received before/after pair
against the parent state machine. It is diagnostic and testable; it does not
perform the transition.

No use case returns `confirmed` from local input and none accepts remaining
inventory as a trusted parameter.

## 6. Exact implementation file plan

The user confirmed this plan on 2026-08-09 by instructing the work to continue.

### 6.1 Shared contract package

| Action | Path | Purpose |
|---|---|---|
| Add | `packages/api_contracts/analysis_options.yaml` | Mechanical pure-Dart lint baseline required by the confirmed package analyze gate |
| Modify | `packages/api_contracts/pubspec.yaml` | Version `0.2.0`; no runtime dependency added |
| Modify | `packages/api_contracts/pubspec.lock` | Mechanical resolution of the test-only dependency |
| Modify | `packages/api_contracts/lib/api_contracts.dart` | Export Booking v1 public transport surface |
| Add | `packages/api_contracts/schema/booking/v1/common.schema.json` | IDs, timestamp, revision and shared enum definitions |
| Add | `packages/api_contracts/schema/booking/v1/booking.schema.json` | Booking read projection |
| Add | `packages/api_contracts/schema/booking/v1/booking_hold.schema.json` | Hold read projection |
| Add | `packages/api_contracts/schema/booking/v1/booking_policy.schema.json` | Accepted D06 policy projection |
| Add | `packages/api_contracts/schema/booking/v1/booking_command.schema.json` | Closed v1 command envelope/variants |
| Add | `packages/api_contracts/schema/booking/v1/booking_result.schema.json` | Success/rejection/retry/unsupported union |
| Add | `packages/api_contracts/schema/booking/v1/booking_error.schema.json` | Safe typed error vocabulary |
| Add | `packages/api_contracts/schema/booking/v1/fixtures/valid.json` | Representative valid projections/commands/results |
| Add | `packages/api_contracts/schema/booking/v1/fixtures/invalid.json` | Expected schema/semantic failures |
| Add | `packages/api_contracts/schema/booking/v1/fixtures/forward.json` | Unknown enum/schema fail-closed cases |
| Add | `packages/api_contracts/lib/src/contracts/booking/booking_contract.dart` | Wire enums, schema constants and contract marker |
| Add | `packages/api_contracts/lib/src/dto/request/booking_command_dto.dart` | Immutable command variants and JSON codec |
| Add | `packages/api_contracts/lib/src/dto/response/booking_dto.dart` | Booking read DTO and JSON codec |
| Add | `packages/api_contracts/lib/src/dto/response/booking_hold_dto.dart` | Hold read DTO and JSON codec |
| Add | `packages/api_contracts/lib/src/dto/response/booking_policy_dto.dart` | Policy DTO and JSON codec |
| Add | `packages/api_contracts/lib/src/dto/response/booking_result_dto.dart` | Result union and JSON codec |
| Add | `packages/api_contracts/lib/src/dto/response/booking_error_dto.dart` | Safe error DTO and JSON codec |
| Add | `packages/api_contracts/test/support/booking_schema_fixture_validator.dart` | Bounded schema-keyword and fixture validator, test-only |
| Add | `packages/api_contracts/test/booking_contract_test.dart` | Enum/schema/version invariants |
| Add | `packages/api_contracts/test/booking_fixture_test.dart` | Valid/invalid/forward fixture and round-trip tests |

### 6.2 Mobile pure domain

| Action | Path | Purpose |
|---|---|---|
| Add | `apps/mobile/lib/features/booking/domain/entities/booking.dart` | Immutable authoritative Booking projection |
| Add | `apps/mobile/lib/features/booking/domain/entities/booking_hold.dart` | Immutable hold projection |
| Add | `apps/mobile/lib/features/booking/domain/entities/booking_policy.dart` | Versioned received policy snapshot |
| Add | `apps/mobile/lib/features/booking/domain/entities/booking_failure.dart` | Privacy-safe typed failure |
| Add | `apps/mobile/lib/features/booking/domain/entities/booking_action.dart` | Action/readiness vocabulary |
| Add | `apps/mobile/lib/features/booking/domain/usecases/validate_booking_projection_usecase.dart` | Structural/cross-field validation |
| Add | `apps/mobile/lib/features/booking/domain/usecases/evaluate_booking_action_readiness_usecase.dart` | Fail-closed local action eligibility |
| Add | `apps/mobile/lib/features/booking/domain/usecases/validate_booking_state_transition_usecase.dart` | Diagnostic state-machine validation |
| Add | `apps/mobile/test/unit/booking_domain_test.dart` | Entity/policy/invariant tests |
| Add | `apps/mobile/test/unit/booking_action_readiness_test.dart` | State/action/time-boundary matrix |
| Add | `apps/mobile/test/unit/booking_state_transition_test.dart` | Allowed/forbidden transition matrix |

### 6.3 Documentation/status after implementation

| Action | Path | Purpose |
|---|---|---|
| Modify | `docs/product/EVENT_CLASSIFICATION_COVERAGE_MATRIX.md` | Mark only contract/domain coverage actually proven |
| Modify | `docs/architecture/LAUNCH_STATUS.md` | ECL-03B factual status/evidence |
| Modify | `AGENTS.md` | Current Event status; runtime still absent |

Explicitly unchanged:

```text
apps/backend/**
apps/mobile/lib/features/create/**
apps/mobile/lib/features/booking/application/**
apps/mobile/lib/features/booking/data/**
apps/mobile/lib/features/booking/presentation/**
apps/mobile/lib/app/di/**
packages/api_contracts/lib/src/clients/**
packages/api_contracts/lib/src/generated/**
```

## 7. Acceptance criteria

1. JSON Schema Draft 2020-12 is the sole Booking v1 wire source.
2. All six root schemas use stable `$id`, explicit version and closed v1 enums.
3. Mutation commands reject unknown fields and never accept actor authority.
4. Booking requires stable user/Event/occurrence IDs and revision.
5. Finite confirmed Booking requires pool/channel consistency.
6. Waitlisted Booking without active hold consumes no modeled allocation.
7. Active hold is bounded, monotonic and references its Booking/pool.
8. `participantUnits` is positive and separate from concurrency counting.
9. Policy v1 exactly encodes Accepted D06 values.
10. Same wire input round-trips without semantic loss.
11. Unsupported schema/enum fails closed and never becomes a known success.
12. Invalid fixtures fail for the expected stable reason.
13. Forward fixtures produce typed unsupported results, not crashes/defaults.
14. Error details cannot serialize prohibited PII/secret keys.
15. Dart DTOs do not import Flutter, Firebase, HTTP or mobile features.
16. Mobile domain does not import DTOs, data, application or presentation.
17. Domain models are immutable and expose no inventory calculation.
18. Projection validation never repairs or normalizes invalid authority data.
19. Action readiness distinguishes local impossibility from server check.
20. No pure use case can execute a command or create confirmation.
21. State-transition validation matches the Approved parent state machine.
22. No repository, datasource, client, mapper, DI or UI is introduced.
23. No Event draft/schema/template/Create file changes.
24. No `apps/backend` directory or production configuration is introduced.
25. `api_contracts` version is `0.2.0`; generated directories remain untouched.
26. Contract package analyze/test gates pass.
27. Mobile `flutter analyze --no-pub` and full `flutter test --no-pub` pass.
28. Boundary and `git diff --check` gates pass with no new suppressions.
29. Coverage/status docs make no Booking runtime claim.
30. Every functional implementation file matches the confirmed plan; the
    mechanical package lint/lock files required by the confirmed analyze/test
    gates are recorded explicitly in §6.1.

## 8. Verification commands

From `packages/api_contracts`:

```text
dart analyze
dart test
```

From `apps/mobile`:

```text
flutter analyze --no-pub
flutter test --no-pub
```

From repository root:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\scripts\check-boundaries.ps1
git diff --check
```

Additional assertions:

- no file exists below `apps/backend`;
- no ECL-03B diff below Create/application/data/presentation/DI;
- no generated file was manually added or changed;
- all relative Markdown links resolve;
- all acceptance criteria remain sequential 1-30.

## 9. Rollback

ECL-03B has no runtime state and no user data. Rollback is:

1. remove the new Booking schema/fixture/DTO/domain/test files;
2. restore `api_contracts` package version and export surface;
3. restore coverage/status documentation;
4. rerun package/mobile/boundary/diff gates.

No migration, data repair or user communication is required because the slice
cannot create, persist or display Booking.

## 10. Acceptance and completion record

The user authorized implementation on 2026-08-09 after reviewing:

- ECL03B-D01 fixture-verified JSON Schema strategy;
- the exact file plan in §6;
- the exclusions in §2.2 and unchanged paths in §6.3;
- acceptance criteria 1-30.

Implementation evidence:

- all six Booking v1 root schemas plus `common.schema.json` parse as JSON;
- valid/invalid/forward fixtures are shared and fixture-verified;
- package `dart analyze`: **0 issues**;
- package `dart test`: **9 passed**;
- targeted Booking domain suite: **12 passed**;
- full `flutter analyze --no-pub`: **0 issues**;
- full `flutter test --no-pub`: **659 passed**;
- boundary check: passed with 59 existing allowlist suppressions and no new
  violation;
- `git diff --check`: passed; only existing LF/CRLF conversion warnings;
- `apps/backend` remains absent;
- generated, Create, Booking application/data/presentation, DI and client paths
  remain unchanged by ECL-03B.

ECL-03B is therefore Done within its bounded contracts/pure-domain scope. It
does not make Booking usable in the application and does not authorize ECL-03C
or production activation.
