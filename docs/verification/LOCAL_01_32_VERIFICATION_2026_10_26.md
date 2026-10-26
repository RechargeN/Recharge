# 01–32: consolidated local verification, 2026-10-26

Status: technical verification and independent read-only review completed; ready for separate owner acceptance. Existing Review/Accepted decisions are not promoted by this report.

Tested runtime: `7d6ec42b11264005a0f747c6c193d76ce7bc2e18`. Node 22.23.2, Temurin 21.0.12+8, installed Firebase CLI 15.34.0, Flutter 3.44.9 / Dart 3.12.2.
The isolated common version contains the accepted I1/I2/J2 base and the integrated T1/T2/T3/I3/J1 changes. Original WIP and the six final T2 edits were preserved. Subsequent documentation changes do not alter tested runtime inputs.

## Completed verification

- 25 post-security stand gates retain `363d69dbfc64a8bb8b4f4ab0e21a52efef8f2678`. D3.7 Create/UI and backend/general/full21 completed on `7d6ec42b11264005a0f747c6c193d76ce7bc2e18` after the independent-review T3 fix. Native Android B1 and Flutter retain `86edaad3651830f9f32d305be0b0cf52d2747388`. The final delta is limited to the T3 retention helper and its Emulator regression; relevant unaffected runtime, mobile, native, lock, workflow and configuration inputs remain identical. Full runtime identity is not claimed.
- Full Firestore Emulator: 21 groups, 376 passed, 0 failed/skipped, complete=true, exit=0.
- Backend: {'tests': 1160, 'pass': 1160, 'fail': 0, 'cancelled': 0, 'skipped': 0}; script self-tests: {'tests': 72, 'pass': 72, 'fail': 0, 'cancelled': 0, 'skipped': 0}.
- Flutter analyze/test on `86edaad3651830f9f32d305be0b0cf52d2747388`: analyze exit=0; 1780 passed, 81 explicit environment skips, all mapped to completed stand/Emulator evidence; D3.7/full21 references refreshed after the fix.
- Toolchain, static/general checks, boundaries, API contracts and actual HTTP raw-body probe passed.
- Security audit at 2026-10-26T00:10:27.0395286Z: production/full 0 high/critical; moderate 6/10. Policy passes with exceptionUsed=false and reviewOnly=false.
- The independent reviewer found no unresolved P1/P2 in the reviewed bounded scope. The review scope and limitations are recorded in the accompanying INDEPENDENT_REVIEW.md.

## 01–32 matrix

| # | Slice | Evidence entry points | Scope |
|---|---|---|---|
| 01 | Рабочая копия и WIP | common-candidate-equivalence.json; final-runtime-composition.json; security-lock-delta.json; preservation snapshots | Изолированная общая версия; исходный WIP сохранён; локальные commits/patch. |
| 02 | A1 stand | a1-a2 | Защита процесса и project identity; verified stop/reset. |
| 03 | A2 seed/bootstrap | a1-a2 | Чистый, повторный и export/import seed; одинаковый digest. |
| 04 | B1 Auth/Session | b1; b1-native; platform | Host и Android Emulator; физические устройства вне этого evidence. |
| 05 | B2 Event/Booking UI | b2; booking | Три повтора; journals/replay; ранее принятый bounded UI scope. |
| 06 | C1 Media | c1; content-media | Реальные adapters/upload; scanner в обычном stand — fake; real-tools отдельно D1/D2. |
| 07 | C2 moderation | c2; content-media | Общие owner commands, review/hold/restore и immutable decisions. |
| 08 | C3 Event/Create | c3; content-media | Настоящий CreatePage с сохранённым draft, controller/UI и повтор/восстановление; принятый M1 scope. |
| 09 | E1 Catalog | e1; content-media; rules-reference | Derived projection, snapshots, withdraw/activate, rebuild и atomicity. |
| 10 | E2 Discover/Map | e2a; e2 | Реальные adapters и два одновременных клиента; принятый controller scope. |
| 11 | F1 Notifications | f1; handoff-notifications | Реальный inbox UI и reconcile/retention; production delivery отдельно. |
| 12 | F2 Booking lifecycle | f2; booking; BOOKING_ACTIONS_F2_AMENDMENT.md | Два клиента и принятый сокращённый F2 scope. D05/D07 (delivery/deadline policy) не закрыты; BOOKING-HIDE-FENCE-01 остаётся перед реальным Booking use. |
| 13 | D1 real tools | D1_evidence_inheritance.json; d1; t3-review-delta.json | Windows real-tools на 363d69d; D1 runtime и входы стенда неизменны. Последующая правка T3 отдельно отражена в scoped delta. Linux CI — историческое evidence, не новый запуск. |
| 14 | D2 Media restrictions | d2; content-media | Real-tools, Storage и propagation ограничений через общий lifecycle. |
| 15 | D3.1 Place | d3-1; place-activity | Controller/UI, реальные фото, S5/S6 и два installation S7. |
| 16 | D3.2 Activity | d3-2; d3-8; d3-8-linked; d10-activity-delivery; place-activity | Create/publication, Catalog и linked Place; реальная Media доставка. |
| 17 | D3.3 Rental | d3-3; rental | Config-driven fields/readiness, controller/UI; принятый ограниченный локальный scope, test-only policy, activation закрыта. |
| 18 | D3.4 Collection | d3-4; collection | Общий Create/picker; unknown reference refusal и lifecycle. |
| 19 | D4 import | d4; import | Реальные clients, replay, lost response, original deletion и fenced rollback. |
| 20 | M1 final local contour | all gates; independent review | Историческая приёмка M1 сохранена; расширенный итог 01–32 подготовлен для отдельной приёмки владельцем. |
| 21 | G Favorites/Visits | library | Реальные Flutter repositories; CAS/idempotency/privacy и explicit visit. |
| 22 | K1 moderation/reports | moderation-k1 | Scoped decisions/reports и owning-service commands. |
| 23 | H reviews/rating | reviews-safety | Принятая local policy; lifecycle/projection/rebuild; eligibility не означает attendance. |
| 24 | K2 Trust/Safety | reviews-safety | Reconcile, owner effects, sanctions/appeals; production authority отдельно. |
| 25 | K3 Admin/Support | admin-support-k3 | Scoped reads/audit/proposals/approval и запрет direct writes. |
| 26 | I1 Quick Plan | quick-plan | Owner/invited viewer, visibility/generation fences и local sync; Quick Plan не публикуется. |
| 27 | I2 collaboration/Expand | scenario-i2 | Canonical creation writer, revoke/replay fences, новый независимый Scenario. |
| 28 | T1 Bookable Session | session; d3-5 | Schedule/exceptions/timezone/reference revisions/immutable activation; настоящий Create block + draft reload + publication UI. Только externalBookingUrl. |
| 29 | T2 Class/Workshop | class-workshop; d3-6 | CW-V1, шесть WIP сохранены, существующий form engine/Create block; schema refusal на submit/publish/activate. |
| 30 | T3 Find People | find-people; d3-7; t3-review-delta.json | Stored receipts/replay, устойчивый terminal anchor и fallback только по собственному draft; legacy без продления, deadline/purge/concurrency; private source/coarse publicGeo; свежий Create reload/UI после P2 fix. |
| 31 | I3 Scenario publication | scenario-i3; i3 | SP-01…14 сохранены; personal/unlisted/public, tokens, immutable Planning hash и Quick Plan→Expand→publication; Create reload/UI. |
| 32 | J1 Route persistence/GPX | route-j1; j2 | Безопасный SYSTEM/PUBLIC text, запрет DTD/entities/XInclude и лимиты; отдельный canonical codec; endpoint-radius-v1 без постоянных предупреждений. J2/Discover добавлен как compatibility gate. |

## Evidence and boundaries

The delivery includes LOCAL_01_32_EVIDENCE.zip, LOCAL_01_32_MANIFEST.json and the minimal final patch. The archive contains completed logs, exact-SHA ledgers, input hashes, the full Emulator summary, skip mapping, audits and independent review. No managed stand credentials, process dumps, caches or dependency binaries are packaged.
Earlier failed/incomplete attempts are not counted as successes. The earlier native attempts failed from resource/startup errors; the earlier J2 timeout was traced to the local runner PATH accumulation; the first extended Find People UI test had an incorrect finder. All evidence used in the final result was obtained after the security dependency update. After the subsequent T3 correction, the affected D3.7, backend/general and full Emulator checks were repeated; unaffected inherited runs retain their original SHAs.
The first consolidated backend run exposed four obsolete tests that treated the now-supported Route type as unsupported. A subsequent workflow self-test incorrectly required unused actions and assumed LF line endings. Only those five test files were corrected; their focused checks and the complete final suites passed. Both failed runs remain in the evidence history.
Independent review identified one P2: a new partial Find People draft could inherit a prematurely early retention origin from unrelated Content receipts of the author. The correction limits fallback timestamps to matching create/update outcomes. A real Firestore regression covers own-creation and legacy-receipt anchors, exact deadlines, replay and repeated purge; existing history/concurrency tests remain included. The same reviewer checked the fix and its refreshed evidence. The initial review is retained separately.
The body-parser/Zod security correction changes exactly four transitive lock nodes while preserving direct pins. The historical DEF-05 local risk decision remains recorded separately; the current audit does not use that exception. No global/CI exception was activated.
Windows D1 real tools ran on `363d69dbfc64a8bb8b4f4ab0e21a52efef8f2678` with unchanged inputs on the final test candidate. Linux/EICAR/official-database evidence remains the explicitly historical CI run 38567123384 on 83e05cd; no new Linux CI run is claimed. Terraform validation is mock-only, with cached verified providers and no cloud plan/apply.
This is bounded local/Emulator verification. Physical Android/iOS devices, remote CI, production identity/legal authority, cloud/staging/production and market activation remain outside this result. Default-off flags and accepted M1 limitations remain in place. No push, Git merge, deployment, provisioning or CI activation was performed.
Session remains externalBookingUrl-only. Class/Workshop uses the existing form engine. Find People retains author-only private source and server-built coarse publicGeo. Scenario publication preserves SP-01…SP-14 and immutable independent Planning snapshots. Route retains its own canonical codec and endpoint-radius-v1 policy, without repeated warning popups or external routing providers.
