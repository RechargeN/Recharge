# BCK09-API-CORR-01 — Booking v1 Contract Correction Slice

- Version: **0.1**
- Date: **2026-08-27**
- Status: **Review — exact correction plan; implementation not authorized**
- Parent finding:
  [BCK09-API-REV-01 v0.1](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Product baseline:
  [BCK09-API-DEC-01 v0.1](BACKEND_EVENT_BOOKING_API_OWNER_DECISION.md)
- Target package: **`packages/api_contracts` / Booking wire v1**
- Runtime effect of this revision: **none**

## 0. Outcome

This slice will make the normative Booking v1 command schema and executable
consumers describe the same closed command variants. It corrects a
pre-runtime specification defect; it does not add a backend, endpoint, mobile
adapter, Firebase resource or new Booking capability.

The current schema accepts command/payload combinations that the Dart DTO
rejects. Because no remote Booking runtime or supported external producer
exists, the proposed correction may remain wire major `v1` only if the
compatibility audit in §5 confirms that every supported producer already
follows the stricter intended matrix. Otherwise the work stops and proposes a
new compatible major/minor contract decision; it must not silently narrow a
deployed contract.

## 1. Scope

### 1.1. Included after explicit approval

1. Replace the shared command payload property bag with a closed discriminated
   union for every existing Booking v1 command.
2. Make each variant fix `commandType`, require its exact fields and forbid
   fields owned by another variant.
3. Keep the existing Booking v1 command names, result union and error values.
4. Upgrade or replace the bounded schema-test helper so the repository tests
   the actual Draft 2020-12 keywords used by the normative schema.
5. Add negative fixtures for every command variant and boundary family.
6. Verify Dart behavior against the corrected schema.
7. Add a future TypeScript parity entry point and golden-vector contract, but
   do not create backend runtime in this slice unless a later explicit
   authorization expands the file plan.
8. Record compatibility evidence and exact hashes of the accepted fixtures.

### 1.2. Excluded

- changing Event Classification behavior or adding a Booking flow;
- changing the Booking v1 result union;
- query/page/availability API creation;
- ECL-03 request-ID parent amendment;
- canonical semantic-hash implementation;
- `apps/backend`, Firebase, Functions, Firestore, Rules or deployment;
- mobile repository/datasource/application/presentation/DI changes;
- production data, credentials, flags, migrations or provider integration.

## 2. Normative command matrix

The correction must derive the exact variants from the checked-in Dart DTO and
Accepted ECL-03B semantics, then freeze one table in the schema tests. At
minimum it covers these existing names:

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

Each variant uses a closed envelope and closed payload. Required/optional
fields are command-local. Unknown fields, authority fields, mixed variants and
missing required fields are invalid. This plan does not guess the detailed
field matrix: the implementation review must extract and reconcile it against
the current DTO and fixtures before editing the normative schema.

## 3. Exact future file plan

Only after explicit slice approval may the correction touch:

| Path | Intended change |
|---|---|
| `packages/api_contracts/schema/booking/v1/booking_command.schema.json` | Closed discriminated command union |
| `packages/api_contracts/test/booking_contract_test.dart` | DTO command-matrix assertions |
| `packages/api_contracts/test/booking_fixture_test.dart` | Schema/fixture parity assertions |
| `packages/api_contracts/test/support/booking_schema_fixture_validator.dart` | Draft 2020-12 keyword support or strict adapter |
| `packages/api_contracts/schema/booking/v1/fixtures/valid.json` | Only missing valid boundary vectors |
| `packages/api_contracts/schema/booking/v1/fixtures/invalid.json` | Variant, cross-field and boundary failures |
| `packages/api_contracts/schema/booking/v1/fixtures/forward.json` | Unknown future command/schema fail-closed vectors if required |
| `packages/api_contracts/lib/src/dto/request/booking_command_dto.dart` | DTO correction only if reconciliation proves a DTO defect |
| `packages/api_contracts/lib/src/contracts/booking/booking_contract.dart` | Enum/contract correction only if evidence proves a defect |
| `packages/api_contracts/CHANGELOG.md` | Pre-runtime corrective release note and compatibility evidence |
| `packages/api_contracts/pubspec.yaml` | Patch version only if package policy requires it |

Mechanically generated workspace lockfiles may change only if dependency
resolution genuinely changes. No `apps/backend` or `apps/mobile` file is in
scope. The implementation diff must fail if any unlisted product/runtime path
appears.

## 4. Schema strategy gate

Before editing, the implementer must select and record one test strategy:

1. use a standards-compliant Draft 2020-12 validator in tests; or
2. extend the bounded helper with the exact `oneOf`/`const`/closure semantics
   and prove it against an independent standards validator.

Hand-coded tests that validate only the Dart DTO while declaring JSON Schema
the sole wire source are insufficient. A validator that ignores an unknown
keyword is also insufficient and must fail the test setup.

## 5. Compatibility gate

The correction remains Booking wire v1 only when all checks below pass:

- repository search finds no supported producer that emits a
  schema-accepted/DTO-rejected command;
- every existing valid fixture stays valid;
- every current DTO-valid command is schema-valid;
- the three evidenced malformed commands become invalid;
- no committed external API, deployed endpoint or stored command log relies on
  the permissive shape;
- package changelog identifies this as a pre-runtime defect correction.

Any contrary evidence stops the slice. The implementer records the affected
producer and proposes a versioned migration instead of weakening validation or
silently breaking compatibility.

## 6. Required invalid fixture families

1. empty payload for every command;
2. required field missing;
3. field belonging to another command;
4. unknown payload and envelope field;
5. mixed pool/channel or mutually exclusive fields;
6. `expectedBookingRevision` present or absent against the exact matrix;
7. actor, role, capability, server time or authority injection at any depth;
8. unknown command type and unsupported schema version;
9. string/list/integer/participant-unit boundaries;
10. null versus absent where semantics differ;
11. duplicate JSON key and unsafe/non-finite numeric input at the raw parser
    boundary when supported by the chosen validator harness;
12. forward-compatible unknown value that must become an opaque unsupported
    contract rather than a mutation-ready command.

## 7. Verification gates

The implementation slice is not Done until:

1. an independent Draft 2020-12 validator rejects every invalid fixture;
2. the repository validator fails on unsupported normative keywords;
3. Dart accepts all valid and rejects all invalid/unsupported inputs;
4. schema and Dart command matrices are mechanically compared;
5. fixture hashes are stable and reviewable;
6. `dart format --output=none --set-exit-if-changed .` passes for changed Dart;
7. `dart analyze` and `dart test` pass in `packages/api_contracts`;
8. the repository boundary gate passes with no new suppression;
9. the exact diff contains no backend/mobile/runtime file;
10. TypeScript parity remains a clearly assigned ECL-03C prerequisite if no
    TypeScript consumer is authorized in this slice.

## 8. Migration and rollback

There is no production data migration in the planned slice. Rollback is the
single correction commit while runtime is still absent. If a supported
producer dependency is discovered after implementation, do not revert only
the tests or relax one consumer: disable release of the corrected package,
restore the last internally consistent schema/consumer pair, document the
producer and open a versioned compatibility slice.

## 9. Acceptance criteria

1. **BCK09-API-CORR-AC-01:** this file is a plan and grants no implementation authority.
2. **BCK09-API-CORR-AC-02:** the evidenced schema/DTO divergence is the only defect scope.
3. **BCK09-API-CORR-AC-03:** all current command names remain unchanged.
4. **BCK09-API-CORR-AC-04:** the Booking v1 result union remains unchanged.
5. **BCK09-API-CORR-AC-05:** every command has one closed schema variant.
6. **BCK09-API-CORR-AC-06:** required and optional fields are command-local.
7. **BCK09-API-CORR-AC-07:** mixed and unknown fields fail closed.
8. **BCK09-API-CORR-AC-08:** authority injection fails at every nesting depth.
9. **BCK09-API-CORR-AC-09:** a real Draft 2020-12 validation path is mandatory.
10. **BCK09-API-CORR-AC-10:** unsupported schema keywords cannot be ignored silently.
11. **BCK09-API-CORR-AC-11:** existing valid fixtures remain valid.
12. **BCK09-API-CORR-AC-12:** all DTO-valid commands are schema-valid.
13. **BCK09-API-CORR-AC-13:** the three evidenced malformed commands become invalid.
14. **BCK09-API-CORR-AC-14:** a repository producer compatibility audit is required.
15. **BCK09-API-CORR-AC-15:** contrary compatibility evidence forces a versioned migration.
16. **BCK09-API-CORR-AC-16:** no Event/Booking capability is added.
17. **BCK09-API-CORR-AC-17:** request-ID policy is outside this slice.
18. **BCK09-API-CORR-AC-18:** hashing and transport implementation are outside this slice.
19. **BCK09-API-CORR-AC-19:** query and availability schemas remain separately gated.
20. **BCK09-API-CORR-AC-20:** TypeScript parity remains an explicit later prerequisite.
21. **BCK09-API-CORR-AC-21:** no backend, mobile, Firebase or deployment file may change.
22. **BCK09-API-CORR-AC-22:** package analyze/test and boundary gates must pass.
23. **BCK09-API-CORR-AC-23:** the correction has a pre-runtime changelog and rollback path.
24. **BCK09-API-CORR-AC-24:** implementation requires a separate explicit approval.
25. **BCK09-API-CORR-AC-25:** push and `main` merge remain separately authorized.

## 10. Final state

The correction is now bounded enough to approve independently. Until that
happens, the checked-in schema and DTO remain divergent, the API specialist
row remains Pending and no endpoint may be implemented.
