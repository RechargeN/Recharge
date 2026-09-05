# BCK-14 — Media Storage Backend Coverage Matrix

- ID: **BCK-14-PRE**
- Version: **0.2.1**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no Storage/runtime authority**
- Accountable owner: **Media Platform owner**
- Target: [BCK-14 v0.2.1](MEDIA_STORAGE_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.36](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_MEDIA_STORAGE_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2.1 — 2026-08-25

- reconciled BCK-07 v0.2 as Present in Review;
- preserved BCK-07 Approval/runtime/handoff as blockers and changed no Media
  contract semantics, AC numbering or runtime status.

### v0.2 — 2026-08-25

- reconciled the audit with BCK-14 v0.2 Review;
- verified 22/22 mandatory design categories, 60 target AC and ten explicit
  BCK14 owner decisions;
- separated blob/metadata authority from BCK-07 content lifecycle authority;
- kept Storage, upload, processing, provisioning and runtime absent.

### v0.1 — 2026-08-25

- inventoried canonical security, operations, identity, content and mobile
  inputs;
- recorded 14 gaps and 24 preparatory acceptance criteria.

## 1. Verdict

BCK-14 v0.2.1 is suitable for **Review as a documentation-only target**. It
defines one Media authority for upload sessions, blob generations, validation,
quarantine, transforms, protected delivery and cleanup without granting Media
ownership of Content, Identity, Route or moderation decisions.

Runtime remains **Absent**. BCK-07 is Review but not Approved or implemented;
BCK-03/04/05 are Draft, BCK-06 and BCK-18 are Review, exact media policy
decisions are open and no Firebase Storage resource, Rules, worker, callable
endpoint or mobile upload adapter is authorized by this matrix.

## 2. Sources and status

| Source | Status used here | BCK-14 treatment |
|---|---|---|
| ADR 0013 | Accepted | Media references decoupled from draft finalization; preprocessing/retry/orphan cleanup required |
| ADR 0015 | Accepted | Persistent `PublisherRef`; capability and exact-page membership authority remain BCK-06 |
| BCK-01 v0.4.32 | Review | Parent target architecture; runtime claims remain Absent |
| BCK-02 v2.4.36 | Approved coordination | Owner, scope, dependencies, D3/R4 placement and 22-category template |
| BCK-03 v0.3.3 | Draft with Accepted split-key decision | Envelope, typed errors, version, idempotency; ordinary envelope excludes media bytes |
| BCK-04 v0.4.16 | Draft | Mandatory media security overlay; exact path/variants/retention delegated here |
| BCK-05 v0.2.23 | Draft | Accepted regional Storage baseline plus deployment/recovery/cost gates; no provisioning authority |
| BCK-06 v0.2 | Review | Actor, session, capability, page membership and PublisherRef eligibility input |
| BCK-07 v0.2 | Review/runtime Absent | Content lifecycle and attachment authority; Approval/runtime/handoff remain blockers |
| BCK-18 v0.2 | Review | Typed mobile seam; upload adapters and production binding absent |
| Firebase Architecture v2.2 | Proposed input | Staging model is useful but not silently Accepted |
| Backup Recovery Model | Draft operational input | Generation/hash recovery and privacy-resurrection controls |
| Current mobile runtime | Local URL strings and local GPX only | Evidence/debt; not Media backend implementation |

## 3. Current implementation inventory

| Area | Present | Gap to target |
|---|---|---|
| Create media | Cover/gallery are mostly text URL values in local drafts | No asset ID, upload session, finalize receipt or authoritative attachment |
| Event media | Alt text and rights-confirmed fields exist locally | No server rights record, validation, moderation or lifecycle |
| Discover/library | Network image URL projections | No visibility token, generation pinning, revocation or stale-media state |
| Route/GPX | Local inspect/import/export and encrypted recording journal | No BCK-11/BCK-14 GPX storage classification or protected delivery |
| Identity media | Local/profile references | No authoritative avatar/page asset pipeline |
| API contracts | Booking-only shared cross-language schemas | No accepted Media schema/codegen family |
| Backend scaffold | R0 non-product toolchain only | No Storage emulator config, Rules, handlers, tasks or manifests |
| Firebase mobile SDK | No product Firebase Storage adapter | Addition requires separate Approved executable slice |
| Boundary gate | 380 Dart files, 71 exact suppressions, zero violations | Budget is full; documentation adds no suppression |

## 4. Mandatory BCK-02 coverage

| # | Requirement | BCK-14 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; Proposed sources qualified |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope | §4 | Full |
| 5 | Ownership | §5–6 | Full; Media/Content/Identity/Moderation writers separated |
| 6 | Data/projections | §7–8 | Full design model; schemas absent |
| 7 | Commands/queries/events/errors | §9–11 | Full semantic inventory; executable contracts absent |
| 8 | Versions/evolution/client | §12 | Full; Media contract workflow decision open |
| 9 | AuthZ/revocation | §13 | Full target boundary; BCK-06/runtime absent |
| 10 | Persistence/index/transactions | §14 | Full atomicity boundary; implementation absent |
| 11 | IDs/time/reference | §15 | Full |
| 12 | Idempotency/concurrency/retry/failure | §16 | Full |
| 13 | Offline/cache/freshness | §17 | Full semantic contract; mobile adapter absent |
| 14 | Migration/import/compat | §18 | Full fail-closed plan; mapping decisions open |
| 15 | Outbox/replay/dedupe | §19 | Full design; event envelope/runtime absent |
| 16 | Privacy/retention/Legal | §20 | Full boundary; exact terms and Legal verdict absent |
| 17 | Abuse/rate/App Check | §21 | Full; numeric quotas/enforcement absent |
| 18 | Logs/SLO/analytics/cost | §22 | Full structure; measurements absent |
| 19 | Flags/rollout/rollback | §23 | Full; runtime gates closed |
| 20 | Exact file map | §25 | Full conditional map; no executable authorization |
| 21 | Test matrix | §26 | Full planned evidence; no runtime evidence |
| 22 | AC/DoR/DoD/unimplemented | §27–30 | Full; 60 AC and explicit absent list |

**Coverage verdict:** 22/22 addressed at Review design level. This is not an
Approval, implementation or cloud-readiness claim.

## 5. Single-writer reconciliation

| Concern | Writer/source of truth | BCK-14 consumes/produces | Forbidden overlap |
|---|---|---|---|
| Actor/session/capabilities | BCK-06 | Verified access snapshot | Media grants role/membership |
| Content draft/publish state | BCK-07 | Attachment intent and readiness receipt | Media publishes/archives content |
| Blob bytes/generation/hash | BCK-14 | Canonical object record | Content stores raw bytes or mutable URL as truth |
| Media lifecycle | BCK-14 | Session, asset, variant, quarantine, deletion state | Client directly promotes staging blob |
| Moderation decision | BCK-22/BCK-07 handoff | Safety finding/status reference | Scanner outcome becomes final moderation verdict |
| Route/GPX semantics | BCK-11 | Opaque protected media handle and technical inspection | BCK-14 interprets route domain geometry |
| Privacy/retention | BCK-04 + BCK-14 family decision | Enforced expiry/deletion/hold task | Bucket default becomes lawful retention |
| Deployment/recovery | BCK-05 | Resource manifest, worker/recovery evidence | Domain spec provisions cloud resources |
| Mobile orchestration | BCK-18 | Typed upload/finalize/read state | UI or SDK owns authoritative policy |

## 6. Gaps

| ID | Finding | Required disposition |
|---|---|---|
| BCK14-GAP-01 | BCK-14 target file was absent | Closed by v0.2 Review; runtime still Absent |
| BCK14-GAP-02 | BCK-07 contract is Review but not Approved/implemented | No attach-to-published-content or content lifecycle effect before BCK-07 Approval and runtime handoff evidence |
| BCK14-GAP-03 | Proposed Firebase path model mixes technical paths and product families | Use opaque server-selected object keys; exact manifest remains owner decision |
| BCK14-GAP-04 | Exact accepted Media API schema family is absent | No hand-authored generated client; API/Mobile owners decide workflow |
| BCK14-GAP-05 | Variant profiles and formats are not settled | Public delivery disabled until bounded profile is Accepted and measured |
| BCK14-GAP-06 | MIME/size/dimension/duration limits are not settled | Upload sessions unavailable by default |
| BCK14-GAP-07 | Malware/unsafe-content service and response policy are absent | Quarantine, never auto-publish on inconclusive scan |
| BCK14-GAP-08 | Rights/attribution policy is not legally reviewed | Rights-sensitive publication remains blocked |
| BCK14-GAP-09 | Originals/variants/staging/quarantine retention is unresolved | No production storage |
| BCK14-GAP-10 | Protected URL/CDN policy is unresolved | No permanent public URL for protected/private bytes |
| BCK14-GAP-11 | Delete/replace races with content references are unspecified in runtime | Generation-pinned refs and atomic finalize/detach required |
| BCK14-GAP-12 | GPX can expose sensitive location and is not ordinary public media | BCK-11 privacy classification required before remote GPX |
| BCK14-GAP-13 | Existing URL strings lack asset IDs/generation/visibility | Explicit migration/quarantine; never infer ownership from URL |
| BCK14-GAP-14 | Boundary exception budget is 71/71 | Executable slice must add no suppression or separately reduce/approve debt |

## 7. Open owner decisions

| ID | Decision | Owners | Gate | Fail-closed default |
|---|---|---|---|---|
| BCK14-OD-01 | Accepted Media API/schema/codegen workflow | API + Media + Mobile | Any adapter | No remote Media client |
| BCK14-OD-02 | Object-key/bucket/prefix manifest and isolation | Media + Operations + Security | R4 provisioning | No bucket/path creation |
| BCK14-OD-03 | Allowed families, MIME signatures, size/dimension/duration/count limits | Media + Product + Security | Upload session | Upload unavailable |
| BCK14-OD-04 | Variant profiles, codecs, quality and accessibility metadata | Media + Product + Mobile | Public delivery | Original/private only; not public |
| BCK14-OD-05 | Scanner/moderation providers, timeout and inconclusive behavior | Security + Trust/Safety + Media | Finalize | Quarantine |
| BCK14-OD-06 | Rights, attribution, consent and child/sensitive-media evidence | Legal/Privacy + Product | Publication | Publication denied |
| BCK14-OD-07 | Per-state retention, DSR, legal hold and backup propagation | Privacy/Legal + Media + Operations | Production data | No production storage |
| BCK14-OD-08 | Protected delivery token/CDN/revocation/cache policy | Security + Media + Operations | Protected read | Access unavailable |
| BCK14-OD-09 | Legacy URL/GPX mapping, disclosure, conflict and rollback | Content + Route + Media + Mobile | Import | No import |
| BCK14-OD-10 | Numeric SLO, quotas, egress/cost guardrails and degradation | Operations + Media + Product | Scale/production | Feature disabled |

## 8. Fail-closed defaults

- no production Storage, bucket, Rules, worker, upload endpoint or CDN;
- no public promotion without a ready asset and BCK-07 command;
- no authorization from path, URL, client claims or guessed ownership;
- no MIME trust from filename or request header alone;
- no protected original through public variant URL;
- no cross-publisher checksum dedupe disclosure;
- no inconclusive/failed scan promotion;
- no remote GPX before BCK-11 privacy contract;
- no legacy URL ownership inference;
- no retention inherited from provider defaults.

## 9. Preparatory acceptance criteria

1. **BCK-14-PRE-AC-01:** Target, Review status and runtime absence are explicit.
2. **BCK-14-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-14-PRE-AC-03:** BCK-14 owns bytes and media metadata only.
4. **BCK-14-PRE-AC-04:** BCK-07 remains the content lifecycle writer.
5. **BCK-14-PRE-AC-05:** BCK-06 remains access and PublisherRef authority.
6. **BCK-14-PRE-AC-06:** Moderation findings do not become final verdicts implicitly.
7. **BCK-14-PRE-AC-07:** Upload and content finalization remain decoupled.
8. **BCK-14-PRE-AC-08:** Server selects opaque canonical object identity.
9. **BCK-14-PRE-AC-09:** Client-declared MIME is insufficient.
10. **BCK-14-PRE-AC-10:** Public output never exposes protected original.
11. **BCK-14-PRE-AC-11:** Failed/inconclusive processing stays quarantined.
12. **BCK-14-PRE-AC-12:** Immutable generation/hash participates in readiness.
13. **BCK-14-PRE-AC-13:** Checksum dedupe leaks no cross-owner existence.
14. **BCK-14-PRE-AC-14:** Retention is per record/object state and purpose.
15. **BCK-14-PRE-AC-15:** Backup cannot resurrect public/deleted access.
16. **BCK-14-PRE-AC-16:** GPX remains gated by BCK-11 privacy.
17. **BCK-14-PRE-AC-17:** Legacy URL ownership is never inferred.
18. **BCK-14-PRE-AC-18:** Non-Booking contract generation needs Accepted workflow.
19. **BCK-14-PRE-AC-19:** App Check supplements but never replaces AuthZ.
20. **BCK-14-PRE-AC-20:** No new boundary suppression is added.
21. **BCK-14-PRE-AC-21:** Documentation checks are not runtime evidence.
22. **BCK-14-PRE-AC-22:** Proposed Firebase detail is qualified as input.
23. **BCK-14-PRE-AC-23:** Future executable files remain conditional.
24. **BCK-14-PRE-AC-24:** Runtime, Firebase, push and `main` remain untouched.

## 10. Evidence summary

- repository/source audit: complete for this Review revision;
- target coverage: 22/22;
- target acceptance criteria: 60 sequential;
- owner decisions: ten Open;
- runtime/cloud evidence: absent;
- new boundary suppressions: zero;
- authorized side effects: documentation and a local commit only.
