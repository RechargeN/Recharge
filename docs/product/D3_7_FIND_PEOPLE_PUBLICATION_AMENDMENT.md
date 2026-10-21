# D3.7 — Find People publication amendment, T3

- Revision: **0.1**, 2026-10-19.
- Status: **Review — owner-authorized bounded local implementation**.
- Scope: **local/LV Emulator only, default-off, synthetic data only**.
- Base: `0b131ab` (`codex/d3-5-session`, contains `codex/recharge-integration`).
- Separate worktree: `C:/Users/User/.claude/worktrees/recharge-t3-find-people`,
  local branch `claude/t3-find-people`.
- No commit, push, merge or deployment authorized.
- Sources: [Find People Create v3.1](create/FIND_PEOPLE_CREATE_BLOCK_SPEC.md),
  [BCK-06 §8.9](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
  [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md),
  [BCK-08](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md),
  [H/K2 local owner policy](REVIEWS_TRUST_SAFETY_LOCAL_OWNER_POLICY.md),
  [OD-11 product review](BACKEND_OD_11_PRODUCT_POLICY_REVIEW.md),
  [D3.5 pattern](D3_5_SESSION_PUBLICATION_AMENDMENT.md).

## 1. Входной gate и решения владельца

### 1.1 Gate до решения (read-only, 2026-10-19)

Первая проверка T3 остановилась: отдельного owner-решения о возврате Find
People не было, BCK-06 v0.8 и BCK-04 v0.4.35 — Review, OD-11 не Accepted
(в разных документах записан как Open и как Proposed), числового возраста и
trusted age authority нет (`LocalUnavailableAgePolicyPort` всегда отвечает
`policy_unavailable`), реестр держал `find_people` как
`consent_gate_pending`. K2 local owner policy (2026-10-15) уже покрывает
«people discovery» и не является blocker.

### 1.2 Решения владельца в чате T3, 2026-10-19

Отдельный источник — явные ответы владельца на четыре вопроса в чате T3.
Это не вывод из запроса реализации, существующего mobile Create flow,
наличия валидатора или контракта другого типа.

| ID | Решение |
|---|---|
| FP-OD-01 | Возврат Find People принят как **local owner policy** по образцу H/K2: только Emulator, default-off флаги, синтетические данные, рынок **LV**. Publisher — personal user **и Professional Page** с серверной проверкой доступа к Page. Production остаётся закрытым до Accepted OD-11 и Legal/Privacy |
| FP-OD-02 | Публичная геопозиция — **центр ячейки сетки ~1 км**, вычисляет сервер. Точные координаты хранятся только в private source, читает их только сам автор; в Catalog, MapObject и логи они не попадают |
| FP-OD-03 | Согласие привязано к публикации и действует **до конца встречи, но не дольше 30 дней**. Точная локация удаляется сервером **через 30 дней** после revoke, hide, expiry или unpublish |
| FP-OD-04 | Возраст — **синтетическая серверная аттестация 18+**, только Emulator: аттестацию пишут серверные fixtures, никогда клиент. Порог 18+, unknown или minor — отказ. Production-порт остаётся unavailable |

После подтверждения prerequisites формальное согласование плана не требуется
(условие T3). Amendment остаётся Review; агент не повышает статус до Accepted.

### 1.3 Чего эти решения не делают

Они не принимают OD-11, не задают production-возраст, не дают qualified
Legal/Privacy evidence, не включают Find People на других рынках, в cloud или
production и не разрешают messaging, live tracking, заявки, waitlist,
приглашения, co-hosts, online secrets, Payments или production-инфраструктуру.

## 2. Ограниченный серверный subset T3

Spec v3.1 описывает полный продукт. Сервер T3 принимает только этот subset;
остальное — явный отказ `validation_failed` с кодом `find_people.*_unsupported`,
а не permissive default. Это граница slice, а не новое продуктовое правило.

| Область | Принимается | Явный отказ |
|---|---|---|
| Schedule | `single`: ровно один слот 30 мин…24 ч, `applicationDeadlineUtc` до начала | `time_poll`, `recurring` |
| Meeting | `in_person`, публичное место подтверждено | `online`, `hybrid` (нужен secret store) |
| Visibility / approval | `public`; approval `manual` или `automatic` как декларация | `unlisted`, `invite_only` |
| Hosts | `responsibleHostUserIds = [автор]` | co-hosts, чужой host, несколько hosts |
| Участие | декларации группы 2…20, host seats, party 1…4, waitlist enums | `applicationQuestions`, `itemized` расходы, share links, participant invites, scheduled publish |
| Media | отсутствует (cover по category visual) | любое поле `media` |
| Publisher | `user` = автор; `page` с доступом автора к Page | delegated import, Page без доступа |

Заявки, waitlist, participants, reveal точной точки участникам, conversations,
notifications и recurring materialization в T3 отсутствуют.

## 3. Контракты: private source и public projection

### 3.1 Private source — тело Content draft

`contentDrafts.body` типа `find_people` (camelCase wire, schema 1):

```text
title, shortDescription, fullDescription, contentLocale,
categoryId, subcategoryId, tags[]
findPeople {
  schemaVersion = 1, revision,
  skillLevel, pace?, languageCodes[1..3], participationGoal,
  experienceRequirements[], equipmentNotes?, accessibilityNotes?,
  houseRuleIds[], houseRulesNote?,
  schedule { mode = single, timezoneId,
             slot { id, startAtUtc, endAtUtc }, applicationDeadlineUtc },
  meeting { mode = in_person, publicAreaLabel, publicPlaceConfirmed = true,
            exact { latitude, longitude, placeName, addressLine, instructions? } },
  group { targetGroupSize, hostSeatCount, approvalMode, allowPartyApplications,
          maxSeatsPerApplication, verificationRequirement, waitlistEnabled,
          waitlistPolicy, waitlistSeatFitPolicy, attendanceConfirmationRequired,
          guestPolicy = authenticated_adults_only },
  cost { costType, expectedSpend? {amountMinor, currencyCode}, costNote?,
         expenseSplitMode, cancellationPolicyId },
  hosts { responsibleHostUserIds = [author], conversationPolicy,
          quietHoursStartMinute?, quietHoursEndMinute? },
  confirmations { safetyRulesAccepted, accuracyConfirmed, ageRequirementConfirmed }
}
```

- `meeting.exact` — **единственное** место точных данных. `placeName`
  считается приватным: название точки раскрывает место точнее ячейки 1 км.
- Клиентские `publicGeo`, `location`, `geo`, координаты в любом другом поле и
  пары координат в публичном тексте — отказ
  (`find_people.public_geo_forbidden`, `find_people.unknown_field`,
  `find_people.public_coordinates_forbidden`). Сервер никогда не берёт
  публичную точку с клиента.
- `ageRequirementConfirmed` — декларация автора, а не возрастная authority.
  Клиентские `age`, `birthDate` и подобные ключи отклоняются
  (`rejectClientDeclaredAge`).

### 3.2 Public projection — тело опубликованной ревизии

При `publishApprovedRevision` сервер строит **новое** тело из allowlist
private source (никогда не копирует объект целиком):

```text
title, shortDescription, fullDescription, contentLocale,
categoryId, subcategoryId, tags[]
findPeople {
  schemaVersion = 1, projection = public_v1,
  skillLevel, pace?, languageCodes, participationGoal, experienceRequirements,
  equipmentNotes?, accessibilityNotes?, houseRuleIds, houseRulesNote?,
  schedule { mode, timezoneId, slot, applicationDeadlineUtc },
  meeting { mode, publicAreaLabel,
            publicLocation { latitude, longitude, precisionMeters = 1000,
                             policyRevision } },
  group {...}, cost {...},
  hosts { responsibleHostUserIds, conversationPolicy }
}
```

`publicLocation` — центр ячейки сетки: шаг широты `1000 / 111320`°, шаг
долготы `1000 / (111320 · cos(φ_band))`, где `φ_band` — центр полосы широты;
результат округлён до 6 знаков. Преобразование детерминированное (без
случайного сдвига), выполняется только на сервере; `bodyHash` считается по
public body. Activate проверяет ровно immutable public body: точных полей нет,
точка лежит в центре своей ячейки, `precisionMeters` и `policyRevision`
совпадают с текущей reference policy.

## 4. Какие координаты хранятся, кто их читает, что получает клиент

| Данные | Где хранятся | Кто читает | Что получает клиент |
|---|---|---|---|
| `meeting.exact` (lat/lng как ввёл автор, placeName, addressLine, instructions) | `contentDrafts.body`; ответы `createDraft`/`updateDraft` в `contentIdempotency` | Только автор (`createdByUserId`) через `getDraft`; сервер — для валидации и вычисления ячейки | Автор — свои точные данные; никто другой, включая членов Page, moderation и Catalog |
| `publicLocation` (центр ячейки ~1 км) | `contentPublishedRevisions.body`, версии Catalog | Любой авторизованный viewer после всех gates §6 | Центр ячейки, `precisionMeters = 1000` |
| `publicAreaLabel` | public body, Catalog | То же | Текст района |
| `distanceMeters` | Вычисляется на чтении от центра ячейки | Viewer | Расстояние до центра ячейки, не до точки |
| Геопозиция устройства | Не отправляется в Find People | — | — |

Логи, telemetry, уведомления и ошибки: коды отказов и issue codes не содержат
значений; audit содержит только ID; producer уведомлений для Find People нет;
telemetry не добавляется. Moderation читает только опубликованную public
ревизию, тело draft ей не передаётся.

## 5. Согласие, отзыв, expiry, retention и удаление

### 5.1 Согласие (owner — Identity, BCK-06)

- Запись `identityFindPeopleConsents/{contentId}:{userId}`: purpose
  `find_people.public_listing`, `policyRevision`, `state active|revoked`,
  `revision`, `grantedAtUtc`, `expiresAtUtc = grantedAtUtc + 30 дней`,
  `revokedAtUtc`.
- Выдаёт только сам автор draft (`createdByUserId`) явной командой
  `grantFindPeopleConsent` под флагом `identity.findPeople.consent`; нужна
  действующая аттестация 18+. Геопозиция устройства, Create-форма, чекбокс
  или наличие draft согласием **не** являются.
- `revokeFindPeopleConsent` доступен всегда, в том числе при выключенном
  флаге: уменьшение раскрытия не блокируется.
- Повторная выдача после отзыва или истечения — новая ревизия с новым
  окном не более 30 дней. Это прочтение FP-OD-03; владелец может его ужесточить.

### 5.2 Expiry

Объект виден только пока одновременно: согласие active и
`now < expiresAtUtc`, и `now < slot.endAtUtc` (конец встречи). Так согласие
действует до конца встречи, но не дольше 30 дней.

### 5.3 Retention и удаление точной локации

`lifeEnd` — самое раннее из: `revokedAtUtc`, `expiresAtUtc` согласия,
`slot.endAtUtc`, момент owner hide/unpublish. Если ничего из этого нет (draft
без согласия и без валидного слота), `lifeEnd = createdAtUtc` draft + 30 дней —
консервативное применение максимума FP-OD-03, отмечено для владельца.

Когда `now ≥ lifeEnd + 30 дней`, Content-owned retention job удаляет
`meeting.exact` из draft и из сохранённых ответов `createDraft`/`updateDraft`
этого draft, даже если текущий draft уже не содержит `exact`. Ревизия draft
повышается только при изменении его body; запись audit не содержит значений.
Owner hide/unpublish определяется по неизменяемому Content audit, а не по
`pointer.updatedAtUtc`. Исторические consent receipts и command bodies также
учитываются. Решение и удаление выполняются одной Firestore transaction.
Для legacy hidden записей без terminal audit используется исходный createdAtUtc;
если ни одной достоверной даты нет, запись считается overdue. Миграция и
последующие pointer/moderation updates не предоставляют новый срок хранения. После этого
повторная публикация требует заново ввести точку. Job не управляется
feature-флагом: приватное удаление не выключается. Санкция и moderation hold
сами по себе таймер не запускают (возможен restore), но slot end запускает.

### 5.4 Ограничение offline-клиента

Уже выданные данные невозможно гарантированно удалить с чужого устройства.
Сервер выдаёт только public projection (ячейка ~1 км, текст района). Mobile
adapter не сохраняет выдачу Find People на диск: она живёт в памяти текущего
listing snapshot. Следующий Feed, Map, Details или exact-ID read после revoke,
hide, expiry, block или санкции получает исключение, и адаптер показывает
«недоступно», а не старую копию. Скриншоты и память чужого процесса до этого
чтения вне контроля сервера. Собственный local Create draft автора хранит его
точные данные на его устройстве — это данные автора.

## 6. Видимость, block/mute и T&S

Каждый новый серверный ответ (Feed, Search, Map, Details, cursor старого
snapshot, Content `getPublishedRevision`) проверяет **свежо**, в момент
запроса:

1. Флаг `catalog.findPeople` (Catalog) или `content.findPeople.authoring`
   (Content) включён.
2. Content pointer видим и указывает ровно на эту ревизию (hide, unpublish,
   moderation hold → исключение до доставки в Catalog).
3. Согласие host active, не истекло; `now < slot.endAtUtc`.
4. Аттестация 18+ у host и у viewer; viewer без аттестации ничего не видит.
5. K2 по принятой матрице 2026-10-15: block в любую сторону между viewer и
   host или владельцем Page — исключение везде, включая exact-ID; mute
   viewer → host — исключение из Feed/Search/Map и exact-ID (для Event
   исключение только для direct link, для Find People его нет).
6. T&S: `safetyRestricted` для publisher и owner, существующие Catalog holds.

Snapshot и cursor не дают обхода: исключённый объект пропадает и из
следующей страницы старого snapshot. Автор всегда видит свой draft через
`getDraft`, но public выдачу — по тем же правилам.

## 7. Матрица зависимостей и отказов

| Зависимость / owner | Явный отказ |
|---|---|
| Emulator/local/LV + флаги `content.findPeople.authoring`, `identity.findPeople.consent`, `catalog.findPeople` | Флаг off, не Emulator, не local, не LV → `type_disabled` / `feature_disabled` |
| Identity: session, capability, Page access | Нет session, отозвана, чужая Page, нет capability → отказ до записи |
| Автор draft | Не автор (в т.ч. член Page) читает, меняет, сабмитит, публикует, активирует → `capability_denied`; delegated import → `capability_denied` |
| Age authority (синтетическая аттестация) | Нет, minor, revoked, другой рынок, порт недоступен → `age_eligibility_required` |
| Consent (BCK-06) | Нет, revoked, expired, порт недоступен → `privacy_consent_required` |
| Validator и subset | Нарушение или unsupported → `validation_failed` с публичными кодами |
| Reference Data: taxonomy, locale, geo policy | Нет или stale → `validation_failed` / `source_revision_stale` |
| C2 moderation | Без approval → `moderation_required` |
| Content CAS и idempotency | Stale revision или pointer, другой payload с тем же ключом → отказ |
| K2 relations, T&S holds | Объект исключён из ответа; команды автора под санкцией → отказ |
| Catalog delivery | Флаг off → `type_disabled`; невалидная projection → `invalid_projection` |

## 8. Lifecycle C3

`createDraft → updateDraft → grantFindPeopleConsent → submitForPublication →
(C2 review) → publishApprovedRevision → withdraw (owner hide) →
activatePublishedRevision → новая ревизия`. Submit, approved publish и
immutable activate выполняют те же проверки: автор, возраст, согласие,
expiry, validator (на activate — public validator immutable body), reference,
eligibility, moderation, CAS. Один и тот же запрещённый вход отказывает на
всех трёх путях. Withdraw (уменьшение раскрытия) не требует согласия и
возраста.

## 9. План файлов

Пути от корня; Н — новый, М — изменение.

Документы: Н этот amendment; М `create/FIND_PEOPLE_CREATE_BLOCK_SPEC.md`
(§29 ссылка на T3), М `CONTENT_PUBLICATION_BACKEND_SPEC.md` (§48),
М `BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md` (строка `find_people`),
М `IDENTITY_PUBLISHER_BACKEND_SPEC.md` (§8.9 local), М
`DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md` (local Find People projection),
Н evidence `docs/evidence/backend/d3/D3_7_FIND_PEOPLE_2026_10_19.md`,
М `docs/architecture/LAUNCH_STATUS.md`, М `AGENTS.md` (статус).

Backend (`apps/backend/functions/src`): Н `shared/find_people_policy.ts`,
Н `modules/content/domain/type_rules/find_people_rules.ts`,
Н `modules/content/application/ports/find_people_privacy_port.ts`,
Н `modules/identity_publisher/infrastructure/firestore_find_people_consent_service.ts`,
Н `modules/identity_publisher/infrastructure/synthetic_age_attestation_policy.ts`,
Н `shared/find_people_visibility.ts`,
Н `modules/content/infrastructure/find_people_private_location_retention.ts`,
Н `modules/catalog/domain/find_people_projection.ts`;
М реестр, publication service, validation details/context, reference data,
feature flags, content/catalog entries, `index.ts`, age policy port,
Catalog item/evaluation/query/projector/composition, content contract и
`firestore.rules`. Тесты unit/integration/emulator и общий fixture
`packages/api_contracts/schema/content/v1/fixtures/find_people_create_compat.json`.

Mobile (`apps/mobile/lib`): Н wire mapper, publication record/gateway,
controller, journal, consent adapter, composition, Create section и test
panel; Н Catalog Find People Details adapter; М Catalog Discover repository и
wire models, Discover object kind, DI, router, Find People Create block.

Стенд: Н `stand_content_find_people.ts`, `stand-d3-7-gate.mjs` с self-test;
М общие runners только для регистрации группы.

## 10. Обязательная приёмка

| Проверка | Доказательство |
|---|---|
| Default closed | Флаги off, не автор, чужой publisher/Page/market, истёкшая session, нет consent, нет аттестации |
| Private/public matrix | create, query, details, Catalog, MapObject, logs, telemetry |
| Negative fixtures | Точные координаты в альтернативных полях и тексте не проходят в public ответ |
| Lifecycle C3 | Все переходы, запрет обхода на publish и activate |
| Revoke/hide/expiry/block | Против текущей выдачи, старого snapshot/cursor и exact-ID |
| Public map | Только ячейка из public projection |
| Recovery | Потерянный ответ, повтор команды, interrupted/resumed |
| Real mobile | Controller/UI Create и Catalog/Map adapter против Emulator |
| Regression | Остальные Create-типы и пользовательские данные не меняются |
| Final gates | Самопроверки runners, очистка fixtures, полный Emulator одной сессией, flutter analyze/test, backend gates, boundary, diff-check |

Неполный, упавший или прерванный прогон не считается green. Emulator evidence
не является device, staging или production evidence.

## 11. Открытые gates и прочтения, ждущие владельца

Production и выход за Emulator:

1. OD-11 Accepted для рынка, квалифицированные Legal/Privacy evidence, DPIA.
2. Production age authority: синтетическая аттестация — только Emulator;
   production-порт остаётся `LocalUnavailableAgePolicyPort`.
3. Production consent UX, тексты согласия, legal retention и scheduler удаления.
4. Device, staging и production evidence отсутствуют.

Не реализовано в T3 (явные отказы, а не скрытые пробелы): заявки, waitlist,
участники и раскрытие точной точки принятым участникам, co-hosts, `time_poll`,
`recurring`, `online`/`hybrid`, unlisted и приглашения, медиа, уведомления,
production UI-вход (есть только default-off тестовая панель), l10n.

Интеграции владельцев:

- K2 `contentHide` сейчас принимает только event/place/activity/rental/
  collection. Санкции уровня пользователя действуют на Find People. Снятие
  конкретного объекта идёт через C2 moderation restrict/withdraw. Расширение
  K2 на `find_people` требует решения T&S owner.
- Переключение `catalog.findPeople` после доставки требует reconcile/rebuild
  Catalog: уже доставленный effect не проецируется повторно.

Прочтения, ждущие подтверждения владельца:

- `placeName` приватен (точнее ячейки 1 км), хотя spec v3.1 его не называет.
- Повторная выдача согласия после отзыва или истечения открывает новое окно
  до 30 дней.
- Draft без согласия и без валидного слота: точные данные стираются через
  30 + 30 дней от создания; исторические terminal events не сбрасываются последующими изменениями.
## 12. Итог локальной реализации — 2026-10-19

Статус: **Review**. Bounded local/LV Emulator implementation и обязательные
локальные gates завершены; owner acceptance и gates §11 остаются открыты.
[Подробное evidence](../evidence/backend/d3/D3_7_FIND_PEOPLE_2026_10_19.md).

Полный Emulator одной сессией: 16/16 групп, 315 passed, 0 failed/skipped;
Find People 8/8, собственные fixtures удалены. Backend unit/integration/
contract 1075/1075; Flutter analyze clean, full test 1683 passed / 73 explicit
environment skips. Отдельный D3.7 stand прошёл clean/resumed/repeated parity,
реальные mobile controller/Catalog/Map и UI; stop/cleanup проверены.
Boundary, lint, typecheck, format, layout/config/exports/manifest/generated и
diff-check зелёные. Прерванные попытки сохранены в evidence отдельно.

Фактическая раскладка §9: consent и synthetic age adapter объединены в
`modules/identity_publisher/infrastructure/find_people_privacy_authority.ts`;
общий visibility gate реализован Content-owned адаптером
`modules/content/infrastructure/find_people_privacy_adapter.ts`, Catalog
использует его read-only. Retention scheduler входит через `content_entry.ts`.
Это сохраняет единственного Content writer и точные архитектурные allowlists.
Публичный exact-ID read автора проходит тот же свежий gate, что и остальных;
его private draft остаётся доступен через `getDraft`.

Изменения не закоммичены. Push, merge, cloud/deploy и активация рынков не
выполнялись. Результат не является device/staging/production evidence.
