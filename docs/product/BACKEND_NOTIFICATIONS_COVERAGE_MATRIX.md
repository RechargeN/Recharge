# BCK-13 — Notifications Backend Coverage Matrix

- ID: **BCK-13-PRE**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no Notifications backend/channel authority**
- Accountable owner: **Notifications owner**
- Target: [BCK-13 v0.2](NOTIFICATIONS_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.38](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_NOTIFICATIONS_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2 — 2026-08-25

- reconciled the repository audit with BCK-13 v0.2 Review;
- verified 22/22 mandatory design categories, 60 target AC and ten explicit
  BCK13 owner decisions;
- separated source-domain facts, inbox truth, channel attempts and read state;
- kept FCM, email, Firebase, mobile remote adapters and runtime absent.

### v0.1 — 2026-08-25

- inventoried canonical API, security, operations, identity, content, Booking,
  mobile and Proposed Firebase inputs;
- recorded current local inbox capabilities, gaps and 24 preparatory criteria.

## 1. Verdict

BCK-13 v0.2 is suitable for **Review as a documentation-only target**. It
defines one Notifications authority for inbox, preferences, push registrations,
delivery attempts, rendering and guarded navigation while preserving source
domain, Identity and mobile ownership boundaries.

Runtime remains **Absent**. The current Flutter local inbox is not backend
evidence. OD-09 is Proposed, OD-02 is Open, dependencies are not all Approved,
and no FCM/email provider, token store, Rules, worker, remote mobile adapter,
cloud resource or production data flow is authorized.

## 2. Sources and status

| Source | Status used here | BCK-13 treatment |
|---|---|---|
| BCK-01 v0.4.33 | Review | Parent target; notifications runtime still absent |
| BCK-02 v2.4.37 | Approved coordination | Owner, scope, dependencies, D3/R4 and open decisions |
| BCK-03 v0.3.3 | Draft; OD-09 Proposed | Typed API/split keys; event workers remain blocked |
| BCK-04 v0.4.16 | Draft | Security/privacy/retention/token overlay; exact policy unresolved |
| BCK-05 v0.2.23 | Draft | Environment/IAM/worker/SLO/recovery gates; only R0 scaffold exists |
| BCK-06 v0.2 | Review | Account/session/revocation/subject authority; production runtime absent |
| BCK-07 v0.2 | Review | Content lifecycle producer; runtime absent |
| BCK-09 v1.1 | Review | Booking intent/outbox semantics; notification worker absent |
| BCK-18 v0.2 | Review | Mobile adapter/cache/push-hint boundary; remote adapter absent |
| BCK-20 v0.2.2 / OD-10 | Draft / Proposed | Locale, fallback and market-revision input; not silently Accepted |
| OD-02 | Open | Email remains disabled |
| OD-09 | Proposed | Consumer semantics may be reviewed; effects remain disabled |
| Firebase Architecture v2.2 | Proposed input | FCM/layout not silently Accepted |
| Current mobile runtime | Local secure-storage inbox and local identity sink | Compatibility/debt evidence only |

## 3. Current implementation inventory

| Area | Present | Gap to target |
|---|---|---|
| Inbox model | `id/title/body/type/createdAt/isRead/targetRoute` local entity | No server revision, source/template/policy/expiry/archive/withdrawal |
| Persistence | Per-user JSON in Flutter secure storage | No server authority, pagination, cross-device sync or DSR worker |
| Commands | Fetch and mark-one/mark-all read through local controller | No typed remote receipt, revision, archive, preferences or reconciliation |
| Producers | Local `AppNotificationSink`; identity appends deterministic IDs | Inline local effect, rendered text and string route; no outbox consumer |
| Demo data | Five seed notifications when local list is empty | Must not become production authority or unread obligation |
| Navigation | Presentation parses `targetRoute` strings | No typed allowlist contract or backend/source access recheck evidence |
| Push/email | No `firebase_messaging` or delivery implementation found | No token lifecycle, FCM, email, consent or attempt state |
| API contracts | Booking-focused shared schemas | No Accepted Notifications schema/template workflow |
| Backend scaffold | R0 non-product toolchain only | No handlers, repositories, workers, emulator or cloud resources |
| Boundary gate | 380 Dart files, 71 exact suppressions, zero violations | Budget is full; documentation adds no suppression |

## 4. Mandatory BCK-02 coverage

| # | Requirement | BCK-13 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; Draft/Proposed inputs qualified |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope/channels | §4 | Full; optional channels default-off |
| 5 | Ownership/actors | §5–6 | Full; domain/inbox/mobile writers separated |
| 6 | Data/state model | §7 | Full design; schemas absent |
| 7 | Commands/queries/events/errors | §8–9 and §12 | Full semantic inventory; executable contracts absent |
| 8 | Templates/localization/navigation | §10 | Full target; BCK13-OD-05 open |
| 9 | Delivery pipeline | §11 | Full inbox-first model; workers blocked by OD-09 |
| 10 | Version/evolution/client | §13 | Full; workflow decision open |
| 11 | Persistence/index/atomicity | §14 | Full logical boundary; physical layout absent |
| 12 | IDs/time/reference | §15 | Full |
| 13 | Idempotency/order/replay | §16 | Full semantics; OD-09 exacts unresolved |
| 14 | Preferences/rate/quiet hours | §17 | Full target; numeric/default decisions open |
| 15 | Offline/cache/multi-device | §18 | Full; BCK-18 runtime absent |
| 16 | Migration/cutover | §19 | Full fail-closed plan; OD-04/08 and BCK13-OD-09 open |
| 17 | Privacy/consent/retention/DSR | §20 | Full design; qualified decisions absent |
| 18 | Security/abuse | §21 | Full design; executable IAM/Rules absent |
| 19 | Observability/SLO/cost | §22 | Full dimensions; numeric decisions absent |
| 20 | Flags/rollout/rollback | §23 | Full staged contract; runtime not authorized |
| 21 | Dependencies/files/tests/DoR/DoD | §24–28 | Full conditional plan/evidence model |
| 22 | AC/unimplemented/decisions | §29–31 | 60 sequential AC; ten decisions; absence explicit |

**Coverage verdict:** 22/22 addressed at Review design level. This is not an
Approval, implementation, emulator, deployment or channel-readiness verdict.

## 5. Single-writer reconciliation

| Concern | Writer | Consumer/handoff | Forbidden ambiguity removed |
|---|---|---|---|
| Booking/Content/Identity lifecycle | Owning domain | Accepted minimized intent/outbox | Notification cannot change lifecycle |
| Recipient/account/session | BCK-06 + producer policy | BCK-13 access input | No email/name/device identity inference |
| Inbox/read/archive | BCK-13 | Mobile query/command adapter | No producer/direct Firestore write |
| Preferences/quiet hours | BCK-13 under Accepted policy | Channel router | No per-feature preference store |
| Push token/attempt | BCK-13 | Channel-scoped dispatcher | No token in feature/mobile domain model |
| Navigation execution | Mobile/BCK-18 | Typed BCK-13 intent | No arbitrary trusted route string |
| Source action from CTA | Owning domain command | Explicit user action after revalidation | Click/read never equals domain action |
| Operational monitoring | BCK-05 | Minimized BCK-13 telemetry | Not product analytics authority |
| Product analytics | BCK-21 | Approved catalog/consent only | No payload-based shadow event catalog |
| Moderation/Admin work queue | BCK-22/BCK-19 | Accepted case/task fact only | Local moderator inbox is not authority |

BCK-09's logical Booking delivery-record names are reconciled as design input,
not a second writer: Booking retains the atomic source outbox; BCK-13 owns the
post-handoff inbox and delivery attempt. Direct client `isRead`/preference/token
writes remain forbidden by default under BCK-03/BCK-04.

## 6. Gap register

| Gap | Why material | Resolution/blocker |
|---|---|---|
| OD-09 not Accepted | No executable cross-domain delivery/replay contract | BCK13-OD-03 + OD-09 verdict |
| OD-02 Open | Email purpose/provider/consent/suppression unknown | Email disabled until BCK13-OD-02 |
| Notifications contracts absent | Client/producer/worker shapes could drift | BCK13-OD-01 + fixtures |
| Category policy absent | Mandatory/optional and preference defaults ambiguous | BCK13-OD-04 |
| Template/locale policy incomplete | Unsafe fallback or variable leakage risk | BCK13-OD-05 + OD-10 coordination |
| Token policy absent | Cross-account/env leak and DSR risk | BCK13-OD-06 |
| FCM delivery policy absent | TTL/retry/provider feedback could duplicate/spam | BCK13-OD-07 |
| Rate/coalescing policy absent | Spam, cost and lost-source risk | BCK13-OD-08 |
| Local migration undecided | Demo seeds/routes could be promoted as truth | BCK13-OD-09 + OD-04/08 |
| Numeric evidence absent | No honest scale, latency or cost claim | BCK13-OD-10 |
| Dependencies not Approved/runtime absent | Identity/security/ops/mobile seams unavailable | §24 gates |
| No executable runtime | No inbox, Rules, tokens, FCM/email or worker evidence | Separate Approved R4 slice |

## 7. Open owner decisions

| ID | Decision/evidence | Owners | Blocks | Fail-closed result |
|---|---|---|---|---|
| BCK13-OD-01 | API/schema/template/codegen workflow and compatibility fixtures | Notifications + API + Mobile | Any adapter | No remote adapter |
| BCK13-OD-02 | OD-02 email scope/provider/purpose/consent/suppression/retention | Notifications + Legal/Privacy + Operations | Email | Email disabled |
| BCK13-OD-03 | OD-09 envelope/order/retry/replay/poison/retention | API + Operations + Notifications | Consumers/workers | Effects disabled |
| BCK13-OD-04 | Categories, mandatory rules, preferences/defaults/consent | Product + Notifications + Legal/Privacy | Channel routing | Optional channels off |
| BCK13-OD-05 | Templates, variables, localization/fallback/revision | Notifications + Product + BCK-20 + Legal | Rendering | Unsupported unavailable |
| BCK13-OD-06 | Token encryption/binding/rotation/DSR/retention | Security/Privacy + Identity + Notifications | Registration/push | Push disabled |
| BCK13-OD-07 | Provider, priority, TTL, retry/backoff/invalid feedback | Operations + Notifications + Security | Dispatch | Push disabled |
| BCK13-OD-08 | Quiet hours, rate, fan-out, aggregation/coalescing | Product + Notifications + Operations | Scale/automation | Conservative/no fan-out |
| BCK13-OD-09 | Local import, typed route mapping, cutover/rollback | Mobile + Identity + Notifications + Product | Migration | Empty server inbox |
| BCK13-OD-10 | Numeric SLO, queue, quota and EUR cost/degradation | Operations + Notifications + Product | Scale/production | No scale claim |

## 8. Fail-closed defaults

- email, marketing, mass fan-out and arbitrary campaigns are disabled;
- cross-domain effects/workers are disabled before Accepted OD-09;
- push registration/dispatch is disabled before token/provider policy;
- inbox target starts empty; demo seeds are not imported;
- unknown/newer contract, template, locale or navigation authority is rejected;
- missing category policy cannot create “mandatory” delivery;
- sensitive channel text is generic/minimal or channel is suppressed;
- missing push/permission/provider never removes an inbox item;
- stale worker cannot override withdrawal, revocation, preference or expiry;
- documentation and emulator evidence never imply production enablement.

## 9. Preparatory acceptance criteria

1. **BCK-13-PRE-AC-01:** Target, Review status and runtime absence are explicit.
2. **BCK-13-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-13-PRE-AC-03:** Source domains remain business-lifecycle writers.
4. **BCK-13-PRE-AC-04:** BCK-13 alone owns inbox/preferences/tokens/attempts.
5. **BCK-13-PRE-AC-05:** Inbox/delivery/read/source states remain distinct.
6. **BCK-13-PRE-AC-06:** Inbox is created before an eligible channel attempt.
7. **BCK-13-PRE-AC-07:** Push is a hint and never authority.
8. **BCK-13-PRE-AC-08:** Provider acceptance is not delivery or read proof.
9. **BCK-13-PRE-AC-09:** Recipient authority never derives from email/name/device.
10. **BCK-13-PRE-AC-10:** Intent, template variables and push payload are minimized.
11. **BCK-13-PRE-AC-11:** Arbitrary URLs/text/recipient lists are rejected.
12. **BCK-13-PRE-AC-12:** Navigation revalidates current access/source state.
13. **BCK-13-PRE-AC-13:** Raw push tokens never enter normal logs/queries.
14. **BCK-13-PRE-AC-14:** Token account/environment binding is explicit.
15. **BCK-13-PRE-AC-15:** OD-09 blocks executable consumers/workers.
16. **BCK-13-PRE-AC-16:** OD-02 leaves email disabled.
17. **BCK-13-PRE-AC-17:** Local demo seed is not migration authority.
18. **BCK-13-PRE-AC-18:** String routes need a typed allowlisted mapper.
19. **BCK-13-PRE-AC-19:** Retention/DSR is per record family and purpose.
20. **BCK-13-PRE-AC-20:** No new boundary suppression is added.
21. **BCK-13-PRE-AC-21:** Proposed Firebase/FCM is qualified as input.
22. **BCK-13-PRE-AC-22:** Documentation checks are not runtime evidence.
23. **BCK-13-PRE-AC-23:** Future files/resources remain conditional.
24. **BCK-13-PRE-AC-24:** Runtime, Firebase, push, email and `main` remain untouched.

## 10. Evidence summary

- target coverage: **22/22**;
- target acceptance criteria: **60/60 sequential**;
- preparatory criteria: **24/24 sequential**;
- explicit owner decisions: **10**;
- current runtime classification: **local/mobile foundation only**;
- backend Notifications/FCM/email runtime: **Absent**;
- executable authority from this package: **none**.

## 11. Recommendation

Move BCK-13 v0.2 and BCK-13-PRE v0.2 to cross-owner Review together. Do not
promote BCK-13 to Approved until OD-09, OD-02 disposition, all ten decisions,
dependency compatibility and qualified owner evidence are recorded. Do not
start R4 runtime merely because documentation coverage is complete.
