# SCN-PUB-01 — Scenario publication: амендмент BCK-10 (предложение)

- Revision: **0.2**, 2026-10-20.
- Status: **Accepted — решения SP-01…SP-14 утверждены владельцем 2026-10-20**
  («Утверждаю SP-01…SP-14 по рекомендациям из amendment SCN-PUB-01»).
  Утверждены рекомендованные варианты; альтернативы в §3 отклонены. Документ не
  разрешает Firebase, cloud, Payments, providers или production и не утверждает
  BCK-10 целиком; runtime I3 — bounded local/LV Emulator slice по этому контракту.
- Базовая ревизия: `codex/recharge-integration` `eb5fb0f` (I2 Done, runtime `51d3f29`).
- Runtime: **I3 Done в local/Emulator объёме (default-off)** — owner accepted 2026-10-20;
  evidence: [SCENARIO_I3_VERIFICATION.md](../verification/SCENARIO_I3_VERIFICATION.md).
- Родители: [BCK-10 v0.3.2](PLANNING_SCENARIO_QUICK_PLAN_BACKEND_SPEC.md) §5–9, §29, §32;
  [Scenario Builder v1.7](SCENARIO_BUILDER_SPEC.md) §5, §6, §15, §21, §27;
  [BCK-07 v0.15](CONTENT_PUBLICATION_BACKEND_SPEC.md) §4, §7, §33.1;
  [BCK-08](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md) §7–8, §13, OD-04;
  [I2](SCENARIO_I2_SLICE_SPEC.md); образцы D3.1–D3.5 и
  [BCK08-OD-04-A](ACTIVITY_CATALOG_DISCOVER_OD04_PROPOSAL.md).

Решения перенесены в BCK-10 v0.4 (§33). Строка `scenario` реестра BCK-07 и
проекция BCK08-OD-04-S меняются кодом I3 по §3 и §7; I3 выполняется как bounded
local/LV Emulator slice по образцу D3.x.

## 1. Что не меняется

- Scenario, Quick Plan и Route — разные aggregates и writers. Нет Route-полей,
  второго creation path и live-связи с Quick Plan после Expand.
- Planning (BCK-10) владеет источником; BCK-07 — review, immutable публикацией,
  withdraw и visibility; BCK-08 — только проекцией. Planning не пишет Catalog.
- Все изменения — owner-service commands; клиент и console не пишут напрямую.
- Право редактировать не даёт права публиковать. Publish Scenario не публикует
  вложенные объекты и не расширяет права на них.
- Revoke collaboration (гарантии I2) не отменяет публикацию.

## 2. Факты кода на `51d3f29`, которые определяют объём

| # | Факт | Следствие |
|---|---|---|
| F1 | I2 хранит один изменяемый документ плана (`scenarioPlans`) с revision/generation; неизменяемых `ScenarioRevision` нет | Нужен immutable snapshot при submit (BCK-10 §8) |
| F2 | I2-сервер отвергает draft, если `capabilities.publicPublish` или `unlistedShare` ≠ false | Это правило заменяется проверкой флага/readiness, а не снимается |
| F3 | Реестр BCK-07: `scenario` = `unavailable`, `dependency_pending: BCK-10`, resolver `pinned_immutable_revision` | Нужен resolver/validator, а не inline body |
| F4 | `getPublishedRevision` отдаёт любому авторизованному пользователю опубликованную ревизию по `contentId`, проверяя pointer, но не `body.visibility` (так сейчас читается unlisted Collection) | Для Scenario знание ID не должно давать доступ к unlisted (см. SP-03) |
| F5 | Catalog исключает `unlisted`/`private`; `catalogEnabledTypes` = event, activity | Нужна отдельная проекция Scenario (BCK08-OD-04-S) |
| F6 | Mobile: нет publish/share readiness Scenario, нет PublisherRef у Scenario; `ScenarioLocationDisclosure {private, approximate, public}` уже есть | Нужны readiness, publisher capture и Q4-панель |
| F7 | У Scenario нет `categoryId`; Catalog-фильтры опираются на категорию | Решение SP-12 |
| F8 | `DTL-SCN-01` Blocked до Approved publication/read-projection contract | Этот амендмент и есть такой contract |

## 3. Решения на утверждение

Спорность: **Высокая** — есть разумная альтернатива с другими последствиями;
**Низкая** — следует из принятых документов, нужно только подтверждение.

| ID | Вопрос | Рекомендация | Альтернатива | Спорность |
|---|---|---|---|---|
| SP-01 | Роли collaboration при публикации | Только owner: submit, withdraw, activate, create/revoke share. Editor правит только live draft; viewer читает. Роли I2 без нового `publisher`-role | Делегируемая роль `publisher` для editor | Низкая (BCK-10 §6, I2) |
| SP-02 | PublisherRef v1 | Только personal: `{type: user, id: ownerUserId}`; owner — verified Creator с `publish`; Page-publisher — после IDP-03B/04B | Page из active workspace, как у шести типов | Высокая |
| SP-03 | Модель доступа unlisted | Unlisted — **BCK-10 share token** к immutable share-snapshot: CSPRNG ≥128 бит, хранится hash, constant-time, scope `read_copy`, отдельный non-indexed путь. Не BCK-07 публикация, без Creator и human review, но те же privacy-проверки, report и restriction. ID без token → `not_found` | (б) unlisted через BCK-07 с review и Creator; (в) доступ по знанию ID (как Collection) — **не рекомендую**, противоречит §21 | Высокая |
| SP-04 | Срок жизни unlisted-ссылки | По умолчанию 30 дней, максимум 90; owner может отозвать или ротировать — старая ссылка сразу недействительна; истёк → `token_expired`, продление = новый token. Одна активная ссылка на Scenario. Лимиты в Emulator — test-only конфиг | Бессрочно до revoke; или 7 дней | Высокая (BCK-10 §29 Security/Privacy) |
| SP-05 | Правила модерации public | Каждый public submit → `pendingReview`, без auto-approve; staff review через K1. Классы отказа: `scenario.misleading_schedule_or_budget`, `scenario.unsafe_or_private_location`, `scenario.prohibited_public_note`, `scenario.mass_duplicate`, `scenario.unavailable_dependency`. После публикации — report/auto-hide по ADR 0013/K1, restriction через K2/K3 | Auto-approve без нарушений автоматических проверок | Средняя (§29 Planning + T&S) |
| SP-06 | Что публикуется: ревизия | Submit создаёт immutable `ScenarioRevision` из live плана по `expectedRevision` (CAS) с `contentHash`; BCK-07 пинит `{scenarioId, scenarioRevisionId, contentHash}`. Publish approved и activate сверяют hash; правки live draft после submit на неё не влияют; новые изменения — только новый submit | Публикация текущего live плана с блокировкой правок на время review | Низкая (BCK-10 §8–9) |
| SP-07 | Даты public v1 | Public — только `template`; `dated` → `validation_failed: dated_public_unsupported`. Unlisted допускает оба режима | Разрешить dated public с проверками Event/расписания | Высокая |
| SP-08 | Зависимые остановки при submit/activate | Каждый catalog ref должен быть сейчас опубликован и public (через существующий evaluator Collection по BCK-07 pointer, не через членство в Catalog). Hidden/withdrawn/unlisted/private/чужой draft → отказ `reference_unavailable` с id item, без данных объекта. Route-items блокируют public/unlisted v1 (BCK-11 не готов) | Блокировать только mandatory items | Средняя |
| SP-09 | Зависимость стала недоступной после публикации | Публикация не отзывается. Публичный ответ на свежем чтении заменяет stop на `unavailableStop {itemId, kind}` без title/координат/media источника. Если доступных public items < 2 — Scenario исключается из Catalog до новой ревизии | Автоматический withdraw | Средняя |
| SP-10 | Снимки вложенных объектов | Public revision хранит только `{objectType, objectId}` и свои публичные поля; presentation snapshot чужих объектов не публикуется — чтение берёт текущую public проекцию зависимости | Публиковать snapshot для стабильности/офлайна | Высокая |
| SP-11 | Visibility, ревизии, отзыв | Visibility опубликованной ревизии неизменна. public → unlisted/private = withdraw (+ при желании новая share). Новая public ревизия заменяет текущую атомарным BCK-07 switch; старая остаётся видимой до switch. Удаление Scenario запрещено, пока есть активная публикация или share (`publication_active`) — без неявных каскадов | Удаление каскадно отзывает публикацию | Средняя |
| SP-12 | Catalog-проекция (BCK08-OD-04-S) | Семейство `Scenario`: Feed/Search/Details; Map — одна точка: первая public/approximate location первого дня (approximate — округлённая). Без категории: не участвует в категорийных фильтрах, участвует в text search и в фильтрах format/days | Не показывать на Map в v1 | Высокая |
| SP-13 | Copy («Save a copy») | Вне I3: отдельный slice через единственный creation path I2 | Включить в I3 | Низкая |
| SP-14 | Mobile и включение | Существующий Create flow + Q4 test-panel по образцу D3.1–D3.5; флаги default-off: `content.scenario.authoring`, `planning.scenarioShare`, Catalog family `scenario`; только local/LV Emulator | — | Низкая |

## 4. Матрица visibility × actor (после SP-01…SP-04)

R — read, E — edit live draft, S — submit/create share, P — publish approved
(только staff по решению review), A — activate/restore, W — withdraw/revoke share.

| Visibility | Owner | Editor | Viewer | Посторонний | Отозванный участник | Staff |
|---|---|---|---|---|---|---|
| personal (private) | R E | R E | R | — | — | только BCK-19 audited |
| unlisted (share) | R E S A W | R E | R | R по действующему token, иначе `not_found` | как посторонний | restrict/restore |
| public pending | R E W | R E (live draft) | R | — | — | review: approve/reject |
| public published | R E S(новая ревизия) A W | R E | R | R опубликованной ревизии | R опубликованной ревизии | P, restrict/restore |
| hidden/restricted | R статуса | R live draft | R live draft | `not_found` | `not_found` | restore |

Посторонний никогда не видит live draft, участников, invites, receipts и historical revisions.
Отзыв участника закрывает live draft сразу (I2), но не отзывает публикацию.

## 5. Immutable published revision

Allowlist (всё прочее отбрасывается mapper'ом, а не вычёркивается):

- title, public description, cover (ready Media generation, прикреплённая к ревизии);
- format, dateMode (`template`), количество дней, day title/index, рекомендуемое
  local time и длительности;
- items: kind, role, выбранная alternative и группы вариантов, `publicNote`,
  duration, catalog ref `{objectType, objectId}` или custom location id;
- locations только `public` (точка/адрес) и `approximate` (округлённая точка,
  без адреса); market/region/timezone;
- legs: mode, distance, duration, `notLive`-маркер planned transport,
  polyline — только если оба конца public;
- totals и агрегированный budget `from` с unknown count; party kind/peopleCount
  как общие требования к группе;
- publisherRef, market, scenarioId, scenarioRevisionId, contentHash, schemaVersion.

Никогда не публикуются (ни через вложенность, ни через media, ни через snapshot):
участники, memberships, invites, роли, grants, share token и его hash;
`ScenarioPersonalState`, private notes, booking refs, билеты, confirmation codes,
фактические расходы, completion; locations с `private` и любые polyline/leg,
касающиеся их; `origin` (Quick Plan source ids, provenance), `capabilities`,
`unknownFields`, I2 receipts/журнал, owner id сверх publisherRef, история ревизий,
snapshot чужих объектов (SP-10).

## 6. Конкуренция, повторы и восстановление

- Submit: `expectedRevision` + семантический idempotency key; устаревшая ревизия →
  `revision_conflict` с текущей авторизованной ревизией. Повтор с тем же ключом →
  тот же receipt.
- Publish approved: публикуется ровно approved `scenarioRevisionId`/hash; иное →
  явный `revision_conflict`. Правки live draft во время review не меняют body.
- Activate/restore: повторяет все проверки §3 SP-08 на immutable ревизии.
- Submit, publish и activate вызывают один общий validator (privacy, allowlist,
  dependencies, readiness `publishTemplate`).
- Потерянный ответ/рестарт: durable receipt; нет дубликатов, повторных эффектов
  и частично объявленного успеха.
- Hide/withdraw/restriction убирают Scenario из новых ответов, включая старые
  snapshot/cursor (как tombstone E1) и exact-ID reads; unlisted token reads тоже
  закрываются; Media delivery следует D2 late restriction.

## 7. Чего не хватает в C3 и E1 для Scenario

### C3 (Content + Media + moderation lifecycle)

C3 доказан для Event, затем повторён для Place, Activity, Rental, Collection,
Session (D3.1–D3.5) по одной схеме. Для Scenario нет ни одной части:

1. **BCK-10 ScenarioRevision**: команда submit-snapshot в существующем
   `firestore_scenario_service.ts` (immutable, hash, CAS по I2 revision), owner-only.
2. **BCK-07 resolver** `pinned_immutable_revision` для `scenario`: чтение
   immutable ревизии по ref, сверка hash; запись в реестр (`content-type-registry-v8`).
3. **Validator** `scenario_rules.ts`: allowlist §5, `publishTemplate` readiness
   (§15 Builder), SP-07, SP-08 через существующий published-object evaluator.
4. **Public mapper** с allowlist и privacy-тестами на всех путях ответа (успех,
   ошибки, replay).
5. **Media**: cover через существующий C1/D1/D2 pipeline; новых Media-механизмов нет.
6. **Moderation profile** `scenario` (SP-05) в K1 и restriction через K2/K3.
7. **Unlisted share** (если SP-03 = BCK-10 token): `CreateScenarioShare`/
   `RevokeScenarioShare`, token resolution path, TTL/rotation, rate limit,
   restriction. Это новый механизм — его нет ни в одном D3.x.
8. **Mobile**: personal PublisherRef capture, publish/share readiness, Q4-панель в
   существующем Create flow, реальный adapter против Emulator.
9. **Тесты/стенд**: Emulator-группа, stand gate (clean/interrupted/resumed/repeated),
   cleanup fixtures, регистрация в runner — по образцу D3.5.

### E1 (Catalog)

E1 и OD-04-A покрывают Event и Activity. Для Scenario нужно:

1. **BCK08-OD-04-S** (SP-12): `CatalogScenarioItem`, schema
   `catalog-scenario-projection-v1`, поля Feed/Search/Details, правило Map-точки.
2. Projector/evaluator: включить `scenario` в `catalogEnabledTypes`; исключение
   unlisted/private; tombstone при hide/withdraw/restriction; SP-09 eligibility
   (< 2 доступных items → excluded).
3. Fresh-read omission недоступных stops (как D3.9 для Place).
4. Query: Feed/Search/Details и Map leaf без категорийных фильтров; старые
   snapshot/cursor не возвращают отозванный Scenario.
5. Mobile Discover/Details: минимальная Scenario Details family (разблокирует
   `DTL-SCN-01` в объёме read-only).
6. Rebuild/activation/rollback и цифровые лимиты остаются test-only (OD-05/08/10 открыты).

Оценка: C3-часть — один D3.x-подобный slice плюс unlisted share (новый механизм);
E1-часть — одна OD-04-подобная проекция. Обе укладываются в I3, если SP-03 и SP-12
утверждены; иначе unlisted или Catalog выносятся в отдельные slices.

## 8. Ограничения и что остаётся открытым

Production auth/Page authority (IDP-03B/04B), cloud, deployment, Payments,
external AI/live planning, providers, Route-items, Copy, dated public Scenario,
retention schedule (BCK-10 §29 Privacy/Legal), числовые бюджеты (OD-05/08/10) и
cross-market policy остаются закрытыми. Local Emulator evidence не является
production-готовностью.

## 9. I3: план файлов и уточнения реализации (2026-10-20)

Владелец запустил I3 по этому контракту (bounded local/LV Emulator, без commit,
push и deploy). Рабочая копия: `.claude/worktrees/recharge-i2-integration`
(detached `eb5fb0f`). Уточнения ниже строже контракта и ничего не ослабляют.

**Уточнения реализации.**

- Content Scenario имеет `contentId = scenarioId`: одна публикация на Scenario,
  повторный `createDraft` того же Scenario → `revision_conflict`, а guard удаления
  читает pointer без отдельного индекса.
- Тело Content: общие публичные поля (title = `distribution.title`, описания,
  locale, cover) и `scenario {ref, distribution}`. `distribution` — immutable
  BCK-10 snapshot; `contentHash = sha256(canonicalJson(distribution))`. Валидатор
  BCK-07 проверяет hash и через порт BCK-10 — что ревизия существует, принадлежит
  publisher, имеет purpose `public`, а план активен.
- Каталожные stops хранят только `{objectType, objectId}`; их locations не
  публикуются (SP-10). Точка карты (SP-12) — только собственная public/approximate
  location; polyline — только между двумя собственными public locations.
  `approximate` — координаты округлены до 0.01°, без адреса.
- Unlisted token выдаётся один раз: receipt хранит результат без token, повтор
  потерянного ответа возвращает `tokenUnavailable` и требует ротации; дубликата нет,
  так как у Scenario одна активная ссылка.
- Ограничение unlisted-ссылки персоналом — действия `restrict_share` /
  `restore_share` модерационного модуля по образцу D2, проверяемые Planning.
  Отдельный report flow для ссылок остаётся открытым.

**Файлы.** Backend: `content/domain/type_rules/scenario_rules.ts` (общий
валидатор distribution и тела), `quick_plan/scenario_distribution.ts` (allowlist
mapper), `quick_plan/scenario_publication.ts` (distribute/share/revoke/resolve,
port ревизий, guard удаления, restriction), `content/infrastructure/catalog_scenario_stops.ts`,
`catalog/domain/scenario_projection.ts`; изменения в registry, Content service,
Planning service, PublishedObjectLinkService, Catalog projector/query/handler,
moderation, compositions, флагах, manifest, Rules, verifiers и runner. Тесты:
unit (rules, mapper, projection), Emulator `scenario_i3.test.ts`, stand seed и
`stand-i3-gate.mjs`. Mobile: entities/controller/gateway публикации, секция в
существующем Scenario Create block, composition с guard
`RECHARGE_TEST_SCENARIO_PUBLICATION`, Scenario family в Discover/Details (read-only),
unit/widget и stand тесты.

**Сужения против плана файлов (зафиксированы честно).**

- Mobile Discover/Details для семейства Scenario в I3 не реализованы: backend Catalog
  (Feed/Search/Map/Details, fresh-проверка stops, исключение при < 2 доступных) готов,
  а мобильный renderer — отдельный slice `DTL-SCN-01`, который этот контракт
  разблокирует. У `DiscoverItemEntity` нет формы Scenario, и подделывать её под Event
  было бы параллельной моделью.
- Unlisted share не несёт Media: cover доступен только через публичную публикацию,
  где действует D2 delivery gate. Отдельный report flow для ссылок не сделан;
  ограничение ссылки делается действием персонала `restrict_share`.
- Mobile-читатель unlisted-ссылки — только gateway (`resolveShare`), без экрана.
