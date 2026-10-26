# L1 — DSR, retention и legal hold для writers B–J

- ID: **PRIVACY-L1**
- Версия: **0.2 (реализация в local/Emulator объёме)**
- Дата: **2026-10-24**
- Статус: **Review — локальная реализация §13; production DSR не реализован**
- База: `codex/recharge-integration` @ `bcebd60`, ветка `claude/l1-dsr-retention`
- Расширяет: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md) §19–20 и
  [BCK04-SEC-DEC-01](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md); не заменяет
  domain-спеки владельцев.
- Runtime-эффект: только local/Emulator; cloud, deployment и реальные данные
  не затронуты.

Документ фиксирует фактическое состояние кода, а не названия slices. Всё,
что ниже названо «есть», проверено чтением исходников на `bcebd60`; всё, что
требует проверки при реализации, помечено **проверить**. Локальная
техническая проверка не является юридическим подтверждением и не означает
выполнения реального DSR.

## 1. Принятая база и её пределы

| Источник | Что принято | Чего нет |
|---|---|---|
| BCK-04 v0.4.35 (Draft) + BCK04-SEC-DEC-01 | 14 обязательных поправок: idempotency key + нормализованный payload, scope только на сервере, монотонный revisioned статус, запрет воскрешения через late work/import/rebuild/restore, hold с authority/scope/review/expiry/release | BCK-04 не Approved; BCK04-OD-07/08/09 открыты; Legal qualification нет |
| BCK-04 §19.1 / ECL03-D04 | Продуктовая таблица Booking (90/30/180 дней по классам) | Неактивна до Privacy/Legal gate |
| BCK09-RETENTION-DEC-01 | Технический owner baseline Booking: idempotency 7 дней, outbox +30 дней после delivered+reconciled, audit 365 дней, core 90 дней после позднего из occurrence end / terminal; erasure сразу закрывает доступ, отменяет будущие активные брони, затем псевдонимизирует | Не qualified Legal; production запрещён |
| BCK-04 §19.2 | Для non-Booking классов **нет** числового default; молчание ≠ 30/180 дней | — |
| ADR 0013 п.3 | 30 дней — только для soft-deleted recoverable entity lifecycle | Не распространяется на все записи |
| D3.7 FP-OD-03 | Точная локация Find People стирается через 30 дней после конца публичной жизни | Только Emulator; production Legal открыт |
| BCK-14 §34.5 | Media retention только из принятой policy; без неё `policy_unavailable` | Числовых значений нет, в тестах синтетика |
| BCK09-ABUSE-DEC-01 v1.1 | Rate-limit counter 1 час, attempt 7 дней | Abuse audit — unresolved |

## 2. Существующий DSR runner — факты

`modules/privacy_orchestration`: `PrivacyRequest` (типы `access`, `erasure`,
`restriction`, `rectification`, `objection`), `PrivacyDomainTask` на каждый
`requiredDomainId`, детерминированный `taskId`
(`privacyDomainTaskId(requestId, domainId, market, targetRevision)`),
атомарный dispatch, не более 5 попыток, outcome `completed` /
`retained_legal_hold` с `retainedCount`, reconcile в `completed`,
`completedWithRetention` или `failed` только когда все задачи терминальны, и
linked follow-up после снятия hold (`submitLegalHoldReleaseFollowUp`).
Idempotency: тот же `(subject, type, key)` с другим `semanticHash` даёт
`idempotency_conflict`.

`PrivacyDomainTaskRunner` знает только три домена: `booking`,
`notifications`, `library`. Перед erasure он ставит Identity-аккаунт в
`restricted`, и `AccountSecurityService.setStatus` отзывает активные Sessions.
Все пользовательские команды, которые идут через
`FirestoreBookingAccessAuthority`, после этого отказывают
(`account.status !== 'active'`).

Внешнего входа (callable) для DSR нет: runner вызывается только из тестов.

### 2.1 Gaps runner

| ID | Gap | Последствие |
|---|---|---|
| R-G1 | В задаче нет cursor/checkpoint и policy revision. Cursor есть только у Booking (`bookingPrivacyProgress`, ключ — `taskId`) | Остальные домены после сбоя повторяют проход с нуля; это безопасно только пока они идемпотентны по природе |
| R-G2 | Нет lease: два runner могут одновременно выполнить одну задачу; проигравший получает `revision_conflict` и возвращает `failed`, хотя задача не помечена failed | Ложный ярлык исхода; эффект мог выполниться дважды |
| R-G3 | `retryableFailure` после 5 попыток переводит задачу в терминальный `failed`, включая ожидаемые состояния вроде `active_future_booking_cancellation_required` | Нет видимого состояния blocked/incomplete, отличного от сбоя |
| R-G4 | `restriction` не ставит Identity в `restricted`; это делает только erasure | Restriction держится только на доменных fence (Library, Notifications) |
| R-G5 | `verify()` не связывает запрос с Session или authority; subject берётся из входа | Привязка к подтверждённому субъекту отсутствует (BCK04-SEC-DEC-01 п.5) |
| R-G6 | Hold — только boolean `legalHold` на записях Booking; `applyBookingLegalHold()` — чистая функция без вызывающего кода; нет authority, scope, revision, audit, review/expiry | Требование «hold ставит только server-side authority» не выполнено |
| R-G7 | Receipt/progress/evidence не проверялись на утечку чужих данных | Требует теста (п.10 проверки) |
| R-G8 | Retention: `RetentionRegistry` и `planRetentionDeletionDispatch` — чистые функции; worker есть только у Booking (`booking/retention.ts`) и Find People | Остальные семьи без исполнителя |

## 3. Registry writers B–J (по коду)

Буквы — этапы локального контура из LAUNCH_STATUS: B — Identity/Session
и Booking UI, C — Content, Media, модерация, D — Create-типы и импорт,
E — Catalog/Discover, F — Notifications и Booking actions, G — Library,
H — Reviews, I — Planning, J — Route. Связанные writers K1–K3
(T&S, Admin) включены, потому что пишут данные о тех же субъектах.

«DSR handler» — только то, что реально вызывается `PrivacyDomainTaskRunner`.
Отсутствующий handler нигде не считается покрытым по аналогии.

| # | Writer (owner-service) | Коллекции / объекты | Субъект и поиск | Производные / вспомогательные | DSR handler | Policy |
|---|---|---|---|---|---|---|
| W1 | Identity (BCK-06), B | `identityAccounts`, `identityProviderLinks`, `identitySessions`, `identityAccessSnapshots`, `identityCreatorVerifications` | doc id / `userId` | — | **нет** (runner только restrict + revoke Sessions) | `identity.*` unresolved; BCK06-OD-09 open |
| W2 | Identity — Pages | `identityManagedPages` (`ownerUserId`), `identityPageMemberships` (`userId`) | `ownerUserId`, `userId` | Page-owned Content, Catalog publisherRef | **нет** | unresolved |
| W3 | Identity — Find People consent | `identityFindPeopleConsents`, `identityFindPeopleConsentReceipts`, `identityAgeAttestations` | `consentDocumentId(user, …)` — **проверить** точный ключ | Content FP drafts | **нет** | FP-OD-03 только для точной локации |
| W4 | Security/abuse (platform) | `securityRateLimitCounters`, `securityRateLimitAttempts`, `securityAudit` | `accountId` | — | **нет** | counter/attempt accepted; audit unresolved |
| W5 | Booking (BCK-09), B2/E2/F2 | `bookings` (`userId`), `bookingActiveKeys`, `bookingUserUsage`, `bookingIdempotency`, `bookingAudit`, `bookingOutbox` (`actorId`) | поле субъекта + `orderBy(documentId)` | `bookingPoolLedgers` (inventory), `bookingEventProjections`, deadline jobs/checkpoints/operator audit, `bookingProjectionDeliveries`, `bookingPrivacyProgress`; `bookingHolds` объявлена, writer в коде нет | **есть**: paged pseudonymization, отмена будущих активных броней через `cancelBookingForPrivacyErasure`, пропуск `legalHold` | BCK09-RETENTION-DEC-01 (технический) |
| W6 | Content (BCK-07), C/D3.x | `contentDrafts` (`createdByUserId`, `publisherRef`, body), `contentSubmissions`, `contentPublishedRevisions` (immutable body + `publisherRef`), `contentPublicationPointers`, `contentIdempotency` (`actorUserId`, `outcome`), `contentAudit` (`actorUserId`, `subjectId`) | `createdByUserId`, `publisherRef.id`, `actorUserId` | `contentEffects` (feed), `contentMediaAvailability*`, `eventBookingHandoff*`, `eventBookingOutbox`; Catalog | **нет** | FP точная локация 30 дн. (D3.7); остальное — нет |
| W7 | Content — импорт D4 | `contentExternalBindings` (`local-import:v1:{user}:{key}`, `createdByUserId`) | ключ по user | Content drafts | **нет** | recovery 30 дней — клиентская политика оригинала, не серверного binding |
| W8 | Media (BCK-14), C1/D1/D2 | `mediaAssets` (`ownerSubjectId`), `mediaUploadSessions`, `mediaProcessingReceipts`, `mediaDeletionStatuses`, `mediaIdempotency`, `mediaAudit`, Storage-объекты source и variants | `ownerSubjectId`, `actorUserId` | `mediaEffects`, delivery gate, Content suppression | **нет** (есть owner `deleteAsset`/`detachAsset`, cleanup, `completeDeletion`) | только синтетическая тестовая; иначе `policy_unavailable` |
| W9 | Moderation (C2/K1) | `moderationDecisions`, `moderationEnforcementReceipts`, `moderationIdempotency`, `moderationAudit`, `moderationPublisherTrust`, `moderationRemoderationQueue`, `moderationWorkflowReceipts`, `moderationStaffAuthority` | staff `userId`; publisher id | Content/Media restriction | **нет** | нет (K1: retention явно вне scope) |
| W10 | T&S reports (K1) | `trustSafetyReports` (`reporterUserId`, `narrative`), `trustSafetyReportReceipts`, `trustSafetyInbox` | `reporterUserId` | — | **нет** | нет |
| W11 | Catalog (BCK-08), E1/E2 | `catalogItemVersions`, `catalogSourceStates`, `catalogFactReceipts`, `catalogProjectionSets`, `catalogActivePointer`, `catalogReports` | `publisherRef.id`; FP — `hostUserId` | целиком производные от Content | **нет** | производные: срок по rebuild/propagation, не задан |
| W12 | Notifications (F1) | `notificationInboxItems`, `notificationEffectReceipts`, `notificationDeliveryAttempts`, `notificationPreferences`, `notificationCommandReceipts` | `recipientId` (inbox, receipts), `userId` (command receipts), ID документа (preferences) | `notificationReconcileCheckpoints` | **есть**: restrict через preferences; erasure удаляет inbox/attempts/command receipts/preferences, receipts → tombstone | тестовые сроки F1 §8 |
| W13 | Library (G) | `libraryEntries` (favorites, visits), `libraryCommandReceipts`, `libraryOwners` (fence) | `ownerId` | snapshot title/city/category | **есть**: fence, удаление entries + receipts, `erased: true` | нет принятого срока tombstones |
| W14 | Reviews (H) | `reviews` (`authorId`, `text`, `rating`, `evidence`), `reviewAuthorTargets`, `reviewReceipts` (результат содержит строку отзыва с `authorId` и текстом), `reviewAudit` (`actorId`) | `authorId`; receipts/audit — по digest(actor, key), прямого запроса по субъекту **нет** | `ratingProjections` (агрегат) | **нет** | BCK12-OD-05 open |
| W15 | T&S K2 | `safetyRelations` (`ownerId` + `targetUserId` — два субъекта), `safetyReceipts`, `safetySanctions`, `safetyAppeals`, `safetyAudit`, `safetyNotices`, `safetyAttemptLimits`, `safetyOwnerAuthority` | `ownerId`, `targetUserId`, subject санкции | visibility (`relationEffects`) | **нет** | нет |
| W16 | Admin/Support K3 | `adminSupportCases`, `adminRepairProposals`, `adminRepairApprovals`, `adminRepairExecutions`, `adminReadAudit` | case subject — **проверить** поле | — | **нет** | BCK19-OD-08 open |
| W17 | Quick Plan (I1) | `quickPlans` (`ownerId`, map `invitations` с `inviteeId`), `quickPlanCommandReceipts` (`ownerId`) | `ownerId`; приглашённый — `invitations.{id}.inviteeId` | — | **нет** | нет |
| W18 | Scenario (I2/I3) | `scenarios` (`ownerId`, soft `deleted`), `scenarioMembers` (`{id}:{user}`), `scenarioInvites` (`ownerId`, `recipientId`), `scenarioCommandReceipts` (`actorId`), `scenarioRevisions`, `scenarioShares` (токен) | `ownerId`, `recipientId`, member key | Content publication, Catalog Scenario | **нет** | BCK-10 retention schedule open |
| W19 | Route (J1/J2) | `routes` (`{owner}:{routeId}`, геометрия), `routeCommandReceipts` (`ownerId`), `routeRevisions` (обрезанный snapshot) | `ownerId` | Content publication, Catalog Route | **нет** | BCK-11 raw GPS/GPX retention open |
| W20 | Privacy orchestration | `privacyRequests`, `privacyDomainTasks`, `bookingPrivacyProgress` | `subjectId` | — | — | unresolved |

Покрытие сейчас: **3 из 20 writers** имеют DSR handler (W5, W12, W13).

### 3.1 Данные вне сервера (описываются отдельно, не «удалено»)

| Место | Что остаётся | Почему не покрывается DSR |
|---|---|---|
| Клиентский offline-кэш и журналы (Library v3, Quick Plan, Scenario, Route GPS журнал RTE-11, журнал импорта D4, operation journal Booking) | Локальные копии на устройстве | Сервер не управляет устройством; restriction лишь не даёт им снова попасть на сервер |
| Локальный оригинал D4 | До подтверждения и 30 дней recovery | Клиентская политика D4 |
| Ранее скачанные файлы (GPX export, Media через delivery gate) | Копии у получателя | Отзыв доставки (D2) закрывает только новые выдачи |
| Backup | В локальном контуре backup нет; в production — до 14 недель Firestore | BCK04-OD-07 open |

## 4. Матрица writer → data class → policy → action → evidence

Действия различаются: **delete** — физическое удаление; **anonymize** —
замена прямого идентификатора scope-bound псевдонимом с сохранением
необходимого факта; **restrict** — запрет новой обработки, данные остаются;
**retention expiry** — удаление по сроку, не по запросу; **blocked** —
действие зависит от непринятой policy, задача остаётся видимо incomplete.

| Writer | Data class | Policy | Erasure action | Restriction | Retention expiry | Evidence (будущий тест) |
|---|---|---|---|---|---|---|
| W1 Identity | account, session, snapshot, provider link, verification | unresolved | **blocked** PB-01: только restrict + revoke Sessions; teardown после всех доменов | есть (status) | нет | L1-T-W1 |
| W2 Pages | page, membership | unresolved | **blocked** PB-03: удалить membership субъекта безопасно, если он не единственный owner; страница и её данные остаются | membership fence | нет | L1-T-W2 |
| W3 FP consent | consent, attestation | FP-OD-03 частично | отзыв согласия (существующая команда) → projection выключается; удаление записей **blocked** PB-01 | да | точная локация — 30 дн. (есть) | L1-T-W3 |
| W4 Abuse | counters, attempts, audit | 1 ч / 7 дн / unresolved | counters/attempts — retention expiry; audit **blocked** | — | counters/attempts | L1-T-W4 |
| W5 Booking | core, key, usage, idempotency, audit, outbox | BCK09-RETENTION-DEC-01 | anonymize (есть); будущие активные — отмена через Booking command; hold — retain | Session | есть (`retention.ts`) | L1-T-W5, L1-T-BK |
| W6 Content | drafts, submissions, published revisions, idempotency, audit | нет | **blocked** PB-18: в Content нет команды удаления черновика (rollback D4.1 оставляет tombstone с полным телом), поэтому PB-00 здесь неприменим; опубликованное **blocked** PB-02; idempotency/audit **blocked** PB-05 | Session | FP точная локация | L1-T-W6/W7 |
| W7 Import bindings | binding | нет | **blocked** PB-18 (как W6) | Session | нет | L1-T-W6/W7 |
| W8 Media | source, variants, findings, audit, receipts | `policy_unavailable` | собственные неприкреплённые ассеты → owner `deleteAsset` + проверка Storage source/variants и delivery; прикреплённые к опубликованному — **blocked** PB-02/PB-14 | Session + delivery gate | только синтетическая (тест) | L1-T-W8, L1-T-MD |
| W9 Moderation | decisions, receipts, audit, trust | нет | **blocked** PB-11 (staff и publisher-факты) | — | нет | L1-T-W9 (только инвентарь + неизменность) |
| W10 Reports | report, receipt, inbox | нет | **blocked** PB-09; reporter identity никогда не выдаётся в DSR другим | — | нет | L1-T-W10 |
| W11 Catalog | производные | производный | не удаляется напрямую; следует за Content tombstone; rebuild не возвращает | — | — | L1-T-W11 |
| W12 Notifications | inbox, receipts, attempts, prefs | тестовые F1 | delete/tombstone (есть) | есть | есть | существующие + L1-T-W12 |
| W13 Library | favorites, visits, receipts, fence | нет срока для fence | delete (есть); fence остаётся (PB-16) | есть | нет | существующие + L1-T-W13 |
| W14 Reviews | review, uniqueness, receipt, audit, projection | BCK12-OD-05 | опубликованный отзыв **blocked** PB-04; удалённый (`deleted`) не влияет на рейтинг — сохранить в rebuild | Session | нет | L1-T-W14 |
| W15 T&S K2 | relations, sanctions, appeals, notices, audit | нет | собственные relations субъекта → owner-equivalent deactivate/delete; где субъект — target чужой relation, запись **не трогается** (чужие данные); sanctions/appeals **blocked** PB-09 | Session | нет | L1-T-W15 |
| W16 Admin | cases, repair, read audit | BCK19-OD-08 | **blocked** PB-10 | — | нет | L1-T-W16 |
| W17 Quick Plan | plan, invitations, receipts | нет | собственные планы → owner-equivalent `delete` (существующий tombstone); приглашения, где субъект — invitee → existing `leave`/`decline`; receipts **blocked** PB-05 | Session | нет | L1-T-W17 |
| W18 Scenario | plan, members, invites, revisions, shares | нет | собственный неопубликованный → existing delete; при активной публикации/share — `publication_active` → **blocked** PB-02; membership субъекта в чужом Scenario → existing leave | Session | нет | L1-T-W18 |
| W19 Route | source geometry, revisions, receipts | нет | собственный неопубликованный → existing delete; опубликованный — guard RP-11 → **blocked** PB-02/PB-13 | Session | нет | L1-T-W19 |

«Owner-equivalent» — действие, которое субъект и так может выполнить
существующей командой владельца-сервиса. Его применение при erasure принято
владельцем 2026-10-24 (PB-00, §9) только для приватных неопубликованных
данных субъекта: черновики, свободные Media, свои relations, Quick Plan,
неопубликованные Scenario и Route. Опубликованное и shared остаётся blocked.
Решение не задаёт сроков хранения receipts, audit и fence (PB-05, PB-16).
Для черновиков Content существующей команды удаления нет, поэтому они
остаются blocked (PB-18), а не удаляются в обход Content.

## 5. Shared data и данные других субъектов

- Запись, где субъект — один из нескольких участников (`safetyRelations` с
  `targetUserId`, приглашения Quick Plan/Scenario, membership Page),
  изменяется только в части субъекта и только командой владельца-сервиса.
  Чужие права, блок-листы и планы сохраняются.
- Данные Professional Page принадлежат странице, а не аккаунту: удаление
  аккаунта снимает его membership (PB-03), но не удаляет контент страницы.
- Receipt, progress и evidence DSR содержат только счётчики и коды. Они не
  содержат идентификаторы других пользователей, `reporterUserId`, текст
  отзывов или основание hold (будет проверено тестом L1-T-10).
- Агрегаты (`ratingProjections`, `bookingPoolLedgers`) не содержат прямых
  идентификаторов и пересчитываются, а не удаляются.

## 6. Booking: будущие и действующие брони

Принятое правило (BCK-09, BCK09-RETENTION-DEC-01): erasure сразу закрывает
доступ, отменяет будущие активные брони через Booking command
(`cancelBookingForPrivacyErasure`, причина `privacyErasure`: освобождение
active key и usage, уведомление подавляется `recipient_erasure`), затем
псевдонимизирует. Refunds и финансовых операций нет: Booking только
бесплатный, Payments отсутствуют.

Открыто:
- **PB-07**: код считает активной любую `confirmed` бронь с
  `occurrenceEndSnapshot > now`, то есть отменяет и уже идущее занятие.
  Принятое правило говорит о «будущих»; для начавшегося, но не закончившегося
  занятия нужно отдельное решение (отменить или держать до конца).
- **PB-08**: субъект — организатор Event с чужими бронями. Отмена Event
  затрагивает других людей; без решения Event и брони участников не трогаются.
- Терминальная отмена через 5 попыток (R-G3) должна стать видимым
  `blocked`, а не `failed`.

## 7. Legal hold

Требования BCK-04 и BCK04-SEC-DEC-01 п.10: authority, scope, revision,
audit, review/expiry, release. Сейчас есть только флаг на записях Booking
без вызывающего кода (R-G6).

Безопасный механизм для реализации (не зависит от policy, кроме PB-06):
- запись hold с `holdId`, `scope` {subject, domain, record family или
  record id}, `revision`, `basisRef` (непрозрачная ссылка, в DSR не
  раскрывается), `placedBy`, `reviewAt`, `status`, и append-only audit;
- ставит, меняет и снимает hold только server-side authority port; локально
  — тестовый реестр, как `moderationStaffAuthority`;
- каждый handler перечитывает актуальный hold в той же транзакции, что и
  эффект; устаревший checkpoint не разрешает удаление;
- hold-записи пропускаются без остановки пагинации и учитываются в
  `retainedCount`, результат запроса — `completedWithRetention`;
- снятие hold порождает существующий linked follow-up request.

**PB-06**: кто является authority в production, чем подтверждается основание,
допустимый срок review/expiry — не принято.

## 8. Защита от повторного появления данных

| Канал | Защита |
|---|---|
| Новые пользовательские команды | Identity `restricted` + revoke Sessions до первого доменного эффекта (есть для erasure; для restriction — R-G4) |
| Retry той же задачи | Идемпотентные эффекты; checkpoint только после подтверждённого эффекта |
| Outbox replay / consumers | Consumer проверяет статус получателя в транзакции (как F1); для Content/Media/Catalog effect consumers — **проверить** и добавить |
| Import D4 | Идёт через Session, отказывает при `restricted`; binding удаляется вместе с черновиком |
| Rebuild projections | Rebuild читает только источники; удалённые/tombstone-источники не попадают (Reviews `ratingProjection`, Catalog из Content) |
| Staff/system writers (модерация, T&S, retention jobs) | Не создают новых персональных записей о субъекте после fence; **проверить** каждый |
| Restore из backup | Вне локального контура (PB-15) |

Завершающая сверка после всех задач повторно проверяет каждую
коллекцию из registry: остаток по субъекту без hold → задача не `completed`.

## 9. Policy blockers

| ID | Blocker | Чья policy | Что блокирует | Что делается без неё |
|---|---|---|---|---|
| PB-00 | **Принято владельцем 2026-10-24:** при erasure удалять приватные неопубликованные данные субъекта существующими командами владельца-сервиса | Product owner (RechargeN) | — | Применено к W8 свободным ассетам, W15 своим relations (деактивация, как в owner-команде), W17, W18 и W19 неопубликованным и не shared; к W6/W7 неприменимо — такой команды нет (PB-18); опубликованное и shared — blocked (PB-02, PB-12) |
| PB-01 | Identity teardown: удалить аккаунт или оставить tombstone, судьба consent/attestation | BCK06-OD-09, BCK04-OD-08 | W1, W3 | restrict + revoke Sessions |
| PB-02 | Опубликованный контент personal publisher при erasure: снять с публикации, удалить или анонимизировать автора | BCK-07 §20 + Privacy/Legal | W6, W8, W18, W19 опубликованные; Catalog | Ничего не трогается, задача blocked |
| PB-03 | Page с единственным owner; membership при erasure | BCK-06 + Product | W2 | Membership не трогается |
| PB-04 | Опубликованный отзыв: удалить или анонимизировать | BCK12-OD-05 | W14 | blocked |
| PB-05 | Сроки receipts/idempotency/audit для non-Booking семей | BCK-04 §19.2, owners | receipts и audit W6–W19 | Не удаляются, не считаются удалёнными |
| PB-06 | Authority, основание и review/expiry legal hold | BCK-04 + Legal | production hold | Локальный тестовый реестр authority |
| PB-07 | Начавшееся, но не закончившееся занятие | BCK-09 owner | W5 часть | Текущее поведение кода фиксируется, не расширяется |
| PB-08 | Организатор Event с чужими бронями | BCK-09 + BCK-07 | W5/W6 организатор | Event и чужие брони не трогаются |
| PB-09 | Reports, sanctions, appeals о субъекте или от субъекта; Art. 17(3) | BCK-22 + Legal | W10, W15 | blocked; reporter identity не раскрывается |
| PB-10 | Admin cases, repair, read audit | BCK19-OD-08 | W16 | blocked |
| PB-11 | Moderation decisions/audit/publisher trust | BCK-22 | W9 | blocked |
| PB-12 | Shared Scenario/Quick Plan при erasure владельца (участники, share-токены, revisions) | BCK-10 §29 | W17/W18 общая часть | blocked |
| PB-13 | Raw GPS/GPX и Route revisions | BCK-11 | W19 | blocked |
| PB-14 | Числовые сроки Media (orphan, quarantine, receipts) | BCK14-OD | W8 retention | `policy_unavailable` |
| PB-15 | Backup propagation | BCK04-OD-07 | все | Описывается, не заявляется |
| PB-16 | Срок хранения erasure fence (libraryOwners, псевдоним Booking, будущие fence) | BCK-04 | fence | Fence хранится, не удаляется |
| PB-17 | Проверка subject/authority и step-up при подаче DSR | BCK04-OD-08 | вход DSR | Технически: subject = пользователь Session; ручной канал поддержки вне scope |
| PB-18 | Команда удаления черновика Content и привязки импорта (сейчас её нет: rollback D4.1 сохраняет тело) | BCK-07 owner | W6 drafts, W7 | Черновики и привязки не трогаются; задача Content остаётся blocked |

## 10. План реализации (после окончания захода Codex)

Без второго runner и без записи в чужие коллекции из общего worker.

1. **Registry** `privacy_writer_registry.ts` в `privacy_orchestration`:
   коллекция → writer, domainId, subject locator, data class, policyId,
   статус handler (`implemented` / `blocked:PB-xx` / `none`). Coverage-тест
   сверяет registry со всеми collection-константами и литералами
   `.collection('…')` в `src`; положительный контроль — тест на фикстуре с
   лишней коллекцией, который обязан упасть.
2. **Runner**: в задаче — `policyRevision`, `checkpoint` (cursor, collection
   index), lease с fencing token; исправить R-G2; ожидаемые условия (PB,
   активная бронь) — видимое `blocked`/incomplete вместо `failed` после
   5 попыток; restriction тоже ставит Identity `restricted` (R-G4); вход с
   привязкой subject к Session (R-G5). Изменение схемы
   `privacy_domain_task.schema.json` — с фикстурами и проверкой паритета.
3. **Hold**: запись hold, authority port, повторная проверка в транзакции
   эффекта, audit (§7).
4. **Handlers** в каждом owner-service для всех 20 writers: `access`
   (инвентарь без чужих данных) и `restriction` — для всех; `erasure` —
   там, где policy принята (W5, W12, W13, retention W3/W4, приватные
   неопубликованные семьи по PB-00); остальные возвращают `blocked` с
   кодом PB, а не `succeeded`.
5. **Финальная сверка** по registry и проверка производных (Catalog,
   `ratingProjections`, Media delivery).

## 11. Обязательные проверки → тесты

| № | Проверка | Тест |
|---|---|---|
| 1 | Именованный сценарий на каждого writer W1–W19 с проверкой storage и производных | `L1-T-W1` … `L1-T-W19` (Emulator) |
| 2 | Нет authority, чужой субъект, повтор, изменённый payload под тем же key | `L1-T-AUTH` (integration + Emulator) |
| 3 | Несколько страниц, вставка/удаление между страницами, повтор и перезапуск с checkpoint | `L1-T-PAGE` |
| 4 | Сбой до эффекта, после эффекта до checkpoint, во время финальной сверки | `L1-T-CRASH` |
| 5 | Hold до начала, во время, перед удалением; release и повторная обработка | `L1-T-HOLD` |
| 6 | Booking с будущей/идущей бронью: inventory, usage, без refunds | `L1-T-BK` |
| 7 | Shared/Page данные, несколько субъектов | `L1-T-SHARED` |
| 8 | Outbox/queue/import/rebuild не воскрешают | `L1-T-RESURRECT` |
| 9 | Retention expiry с hold и без; ошибки физического удаления Media | `L1-T-RET`, `L1-T-MD` |
| 10 | Состав ответов, progress, audit без лишних данных | `L1-T-LEAK` |
| 11 | Один аккаунт через все доступные writers в одной Emulator-сессии | `L1-T-E2E` |
| 12 | Coverage registry + положительный контроль | `L1-T-REG` (unit) |

Для writers со статусом blocked тест проверяет честное `blocked` с кодом PB
и неизменность данных, а не удаление.

## 12. Что не входит

Production DSR, реальные данные, Legal-квалификация, backup, cloud,
deployment, push, export delivery (BCK04-OD-08), rectification, objection
и portability.

## 13. Реализация (v0.2, local/Emulator)

Второго runner нет: `PrivacyDomainTaskRunner` остаётся единственным и
находит handler по `domainId`. Общий worker не пишет в чужие коллекции:
каждый эффект — код модуля-владельца.

| Механизм | Где | Что делает |
|---|---|---|
| Registry | `privacy_orchestration/domain/privacy_writer_registry.ts` | Строка на пару «коллекция + поле субъекта»: writer, домен, правило (`delete`, `anonymize`, `fence`, `blocked:PB`, `derived`, `not_subject_data`). Coverage-тест сверяет её со всеми коллекциями в исходниках |
| Task | `privacy_domain_task.ts`, схема `privacy_domain_task.schema.json` | Статус `blocked` с `blockedCodes`, `policyRevision`, lease (`leaseOwner`, `leaseExpiresAtUtc`); запрос с blocked-задачей — `partially_completed`, не `completed` |
| Lease | `leaseTask` / `releaseTaskLease` | Живой lease исключителен, истёкший перехватывается; ревизия ограждает запись прежнего владельца (`lease_lost`) |
| Обход | `firestore_privacy_subject_sweep.ts` | Порядок по ID документа, страница — одна транзакция: lease и hold перечитываются, эффект и checkpoint коммитятся вместе; затем проход сверки с начала, пока он что-то меняет; лимит страниц на запуск; смена `policyRevision` начинает обход заново |
| Hold | `privacy_legal_hold.ts`, `firestore_privacy_legal_hold_service.ts` | Scope (домен, коллекция, запись), revision, review date, release; ставит только authority из серверного реестра; audit без основания |
| Вход DSR | `privacy_request_intake.ts` | Субъект — пользователь Session; чужой subject → `subject_mismatch`; повтор → тот же запрос; другой payload под тем же ключом → `idempotency_conflict`; ответ без чужих данных |
| Barrier | runner | Erasure и restriction сначала ставят аккаунт в `restricted` и отзывают Sessions |
| Owner appliers | Quick Plan, Scenario, Route, T&S, Media, Library | Тот же код, что у owner-команды delete (общие методы), с теми же guard'ами публикации |
| Booking | `firestore_booking_privacy_record_store.ts` | Страница псевдонимизации — транзакция с перечитыванием записей и активных hold |
| Notifications | handler | Hold домена проверяется перед каждым шагом удаления |

Остаточные окна (не закрыты, названы):
- **Notifications:** удаление идёт batch-операциями хранилища; hold,
  поставленный между проверкой и batch, не останавливает эту страницу.
- **Media:** удаление — собственный многошаговый протокол Media; hold
  перечитывается непосредственно перед ним, но не в его транзакции.
- **Счётчики evidence:** эффект, закоммиченный без checkpoint (сбой между
  ними), при повторе засчитывается как `unchanged`; данные удалены,
  `erasedCount` занижен. Счётчик никогда не завышается.
- Задача Media и других доменов с receipts, которые нельзя найти по субъекту,
  всегда `blocked` (PB-05, PB-14): такие записи не объявляются удалёнными.

## 14. Итог: writer → действие → тест → результат

Проверено локально на Firestore/Storage Emulator с синтетическими данными
(`test/emulator/privacy_l1.test.ts`, группа `privacy-l1`). Это техническая
проверка, а не юридическое подтверждение и не выполнение реального DSR.

| Writer | Действие при erasure | Тест | Результат |
|---|---|---|---|
| W1 Identity | restrict + отзыв Sessions; записи остаются | L1-T-W1 | blocked PB-01, PB-03 |
| W2 Pages | membership и страница остаются | L1-T-W1, L1-T-SHARED | blocked PB-03; данные Page не тронуты |
| W3 FP consent | остаются | L1-T-W1 | blocked PB-01 |
| W4 Security | остаются | L1-T-W4 | blocked PB-05 |
| W5 Booking | псевдонимизация; будущая бронь отменяется через Booking | L1-T-W5, L1-T-BK | succeeded; inventory, key и usage согласованы, refund нет |
| W6/W7 Content | остаются | L1-T-W6/W7 | blocked PB-02, PB-05, PB-18 |
| W8 Media | свободные ассеты удаляются протоколом Media (source и variant в Storage); прикреплённые и без policy остаются | L1-T-W8, L1-T-MD | удалено; задача blocked PB-02/PB-14; сбой удаления байтов → повтор, не «удалено» |
| W9/W10 Moderation, reports | остаются; reporter не раскрывается | L1-T-W9/W10, L1-T-LEAK | blocked PB-09, PB-11 |
| W11 Catalog | производный; следует за источниками | — (нет записей субъекта вне Content) | не обрабатывается отдельно |
| W12 Notifications | удаление/tombstone; hold удерживает домен | L1-T-W12 | succeeded; с hold — completedWithRetention, после release и follow-up удалено |
| W13 Library | удаление entries и receipts; fence остаётся | L1-T-W13 | succeeded |
| W14 Reviews | остаются; удалённый отзыв не возвращается в рейтинг | L1-T-W14 | blocked PB-04, PB-05; rebuild без удалённого |
| W15 T&S | свои relations деактивируются; чужие и санкции остаются | L1-T-W15 | blocked PB-09 |
| W16 Admin | остаются | L1-T-W16 | blocked PB-10 |
| W17 Quick Plan | свои не shared → tombstone; shared и приглашения остаются | L1-T-W17 | blocked PB-12 (shared) |
| W18 Scenario | свои неопубликованные не shared → deleted; shared/published остаются | L1-T-W18 | blocked PB-02, PB-12 |
| W19 Route | свои неопубликованные → deleted, снимки стёрты; опубликованный остаётся | L1-T-W19 | blocked PB-02 |
| Все сразу | один аккаунт через 14 доменов | L1-T-E2E | `partially_completed`; succeeded: booking, library, notifications, quick_plan, route, scenario |

Сквозные проверки: L1-T-AUTH (authority, чужой субъект, повтор, изменённый
payload), L1-T-PAGE (страницы, вставка за cursor, удаление впереди, рестарт),
L1-T-CRASH (сбой до эффекта, после эффекта до checkpoint, во время сверки;
lease), L1-T-HOLD (authority, hold до и во время обработки, release,
follow-up), L1-T-RESURRECT (поздняя запись, повтор задачи, rebuild),
L1-T-RET (expiry с hold и без), L1-T-REG (coverage registry с положительным
контролем, unit).

**Удерживается hold:** записи под активным hold (в тестах — Quick Plan и
Notifications) до release и follow-up.
**Deferred / blocked:** всё с кодами PB-01…PB-18 выше; receipts и audit
всех доменов, кроме Booking, Notifications и Library.
**Incomplete по устройству:** Identity teardown, Catalog-проекции
опубликованного, backup, клиентские кэши и скачанные файлы (§3.1).

### 14.1 Проверки (2026-10-24, Windows-local, точный toolchain)

Node 22.23.2, Temurin 21.0.12+8, Flutter 3.44.9. Полный Emulator-набор
одной сессией — 22 группы, включая новую `privacy-l1`, все зелёные; typecheck,
lint, format, unit, contract, security/privacy, layout-гейты, самотесты
runner, boundary и `git diff --check` зелёные. В integration пять падений,
идентичных чистой базе `bcebd60` (три теста Create без валидатора, неучтённые
J2-файлы в инвентаре Content): к L1 не относятся, исправляются отдельно.
Новая группа добавила около минуты; лимит CI-задачи `backend-r0` поднят
со 110 до 115 минут, workflow не запускался. Mobile не менялся.
