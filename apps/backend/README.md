# Recharge backend — local platform and bounded domain foundations

Status: **local R1 platform, Reference Data, Security/Privacy,
Identity/Publisher and disabled Booking foundations; all cloud and market
activation disabled**.

R1 adds a provider-neutral local platform skeleton on top of the retained R0
and disabled RAW-C compatibility evidence. It contains typed logical
environments, immutable release/config revisions, optimistic activation
pointers, default-deny security ports, bounded telemetry and in-memory
adapters. Product domains remain separately gated.

The BCK-20 foundation adds immutable, schema-validated LV/EE/LT market
configuration, explicit locale fallback outcomes, currency and IANA-timezone
contracts, mandatory-copy and source-eligibility gates, and compatible
activation-pointer rollback. Its data is synthetic, each market is isolated,
and every capability remains disabled. No external dataset is imported.

The BCK-04 local foundation adds server-resolved actor/session/market/workspace
checks, default-deny authentication and capability decisions, App Check and
rate-limit ports, privacy-safe audit/redaction controls, data-class/access/
retention registries, unavailable-by-default age policy, emergency-disable
flags and both in-memory and Emulator-only Firestore DSR repositories. Booking
DSR tasks run through the domain handler with bounded attempts and atomic
pseudonymization. It stores no secret values, chooses no numeric age and
exposes no client or cloud handler.

The BCK-06 local slice adds provider-neutral Google/Apple assertion ports,
hashed provider-subject linking, Account and Session authority with revocation
fences, Creator and ManagedPage verification lifecycles, exact-page membership,
fresh AccessSnapshot evaluation and ID-based PublisherRef eligibility. It has
in-memory and disposable-Emulator Firestore adapters, including opaque Session
handles and revision-fenced AccessSnapshots. One disabled Emulator-only
Session callable maps Firebase transport UID to a distinct domain User ID. It
remains local/test-only: no OAuth credential, production Firebase Auth adapter
or production grant exists.

The BCK-09 local slice contains five disabled Emulator-only Booking callables
plus the bounded Identity Session callable,
typed command/query results, finite and unlimited inventory transactions,
idempotency, cancellation, access-revocation, retention and reconciliation
evidence. Booking mutations resolve Account, Session, AccessSnapshot and the
common R1 feature flag inside the same Firestore transaction; query authority
is separately revision-aware. A provider-neutral mobile adapter is present but
bound only to an explicitly loopback dev Emulator; production binding remains
disabled. Immutable Event outbox records feed the sole Booking projection
consumer; delivery checkpoints, cancellation/reschedule effects and all
Booking/support collections remain direct-client default-deny. It is not
deployed. `BCK09-ABUSE-DEC-01 v1.0` adds separate transaction-atomic finite
`5` and unlimited `50` active caps per User+market, layered rolling
actor/account/installation limits, request dedupe, typed retry-after, a
three-active-Session ceiling, atomic opaque-handle rotation and exact-local
App Check bypass. Network identity is a day-rotated secondary hash and never
the sole authenticated-cancel authority. Scoped incident switches and
minimized audit are server-owned; no global security bypass exists. A local
single-ledger load probe preserved the zero-oversell invariant but failed the
accepted popular and mass latency/success targets. A fixed-capacity escrow
model is therefore selected for the later scalability migration: 16 shards
for popular pools and 64 for mass pools. The model, migration planner and
reconciliation tests are pure/default-off code; no Firestore schema, runtime
switch or activation was added.

## Readiness matrix

| Level | Current verdict |
|---|---|
| Local implementation | Ready for physical dev backend, with controls. The verdict covers the implemented R1, Identity, Event projection, disabled Booking, mobile transport seam and Privacy/retention scope; it does not authorize project creation or deployment |
| Emulator evidence | Present on Node 22.23.2, npm 10.9.8 and Temurin 21.0.12+8: 92 unit, 28 contract, 13 integration and 66 Emulator/Rules tests pass. The disposable full-flow covers Auth UID → distinct User ULID → opaque Session/AccessSnapshot → Event projection → callable create/read/list/availability/cancel → notification obligations → Privacy/DSR → retention/legal hold, including deterministic projection retry |
| Dev cloud | Not Ready; no project, billing, credentials, deployment or measured cloud load evidence |
| Staging | Not Ready; no independent Security/Privacy review, restore/incident drill or staged rollout evidence |
| Production | Not Ready; no qualified Legal/Privacy, SLO/cost/DR or escrow runtime evidence |
| Enabled markets | None; LV, EE and LT remain independently disabled |

## Safety boundary

- project identity is always `demo-recharge`;
- no `.firebaserc`, cloud credential, OIDC, service-account key or secret;
- no Firebase/Google project creation, API enablement, billing or deployment;
- no Terraform backend, stateful resource, plan or apply;
- Firestore and Storage client access deny all;
- the exact export allowlist is R0 plus five disabled Booking callables and one
  disabled Identity Session callable; all refuse non-emulator use;
- all `local/dev/stage/prod` identities are logical and `unbound`;
- every market, capability, feature flag and release is `disabled`;
- Terraform has no resources, backend, real project or credential input;
- `apps/mobile` does not depend on this package.

Any command requesting login, a real project, credentials, billing or deploy
is a boundary failure and must stop.

## Exact toolchain

The authoritative pins live in `toolchain.lock.json`. Required hosts:

- Node.js 22.23.2 / npm 10.9.8;
- Eclipse Temurin 21.0.12+8;
- Terraform 1.15.9;
- Windows x64 or Linux x64.

Do not substitute a global Firebase CLI or floating tool version.

## Local verification

From `apps/backend/functions`:

```text
npm ci --ignore-scripts
npm run verify:cloud-context
npm run verify:toolchain
npm run format:check
npm run lint
npm run typecheck
npm run test:unit
npm run test:contract
npm run test:emulator
npm run verify:generated
npm run verify:reproducibility
npm run verify:r1:layout
npm run verify:r1:config
npm run verify:r1:exports
npm run test:r1
npm run test:r1:emulator
npm run test:reference-data
npm run test:security-privacy
npm run test:identity-publisher
npm run test:booking:load:local
```

`test:booking:load:local` is a deliberately long disposable-Emulator probe. It
checks the agreed normal/popular/mass profiles and records latency, outcomes
and oversell. It is evidence for architecture selection, not a release gate or
production benchmark.

From `apps/backend/infra/terraform`, after the verified R0 Terraform installer:

```text
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate -no-color
```

The exact R1 collection families are `platformReleaseManifests`,
`platformActiveReleasePointers`, `platformFeatureFlagRevisions`,
`platformActiveFeatureFlagPointers`, `referenceMarketConfigRevisions` and
`referenceActivationPointers`. Identity uses the explicitly deny-all
`identityAccounts`, `identityProviderLinks`, `identitySessions`,
`identityAccessSnapshots`, `identityCreatorVerifications`,
`identityManagedPages` and `identityPageMemberships` families. Direct client
access is denied. Only the local Emulator/Admin test context may write
synthetic records, and every test removes them.

A missing exact tool, network outage or command that did not execute is
`Inconclusive`, never Pass. Current hosted parity and Moderate transitive
advisory disposition remain open. See
`docs/evidence/backend/r0/BCK-R0-TCH-01_RESULT.md`.
