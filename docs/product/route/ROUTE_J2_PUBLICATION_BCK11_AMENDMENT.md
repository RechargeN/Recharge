# RTE-PUB-01 — Route publication: амендмент BCK-11

- Revision: **0.3**, 2026-10-21.
- Status: **Accepted — решения RP-01…RP-16 утверждены владельцем 2026-10-21**:
  RP-02, RP-04, RP-06 и RP-12 (вариант B) — в редакции §3.1, остальные — по
  рекомендациям («Остальные RP … принимаю по рекомендациям. Контракт RTE-PUB-01
  утверждён, запускай J2 … без push и deploy»). Документ не разрешает
  Firebase, cloud, deploy, providers или production и не утверждает BCK-11
  целиком.
- Runtime: **J2 Review в local/LV Emulator объёме (default-off)**; owner
  acceptance открыт; evidence:
  [ROUTE_J2_VERIFICATION.md](../../verification/ROUTE_J2_VERIFICATION.md).
- Базовая ревизия: `codex/recharge-integration` `b4368e0` (32/J1). Ветка
  предложения: `claude/j2-route-publication`.
- Родители: [BCK-11 v0.3.1](../ROUTE_GPX_BACKEND_SPEC.md) §5–10, §14, §32, §35.3;
  [Route Builder v3.2](../ROUTE_BUILDER_SPEC.md) §11 и «Публикация и версии»;
  [J1](ROUTE_J1_STORAGE_SYNC_GPX_SLICE_SPEC.md);
  [BCK-07](../CONTENT_PUBLICATION_BACKEND_SPEC.md) §4, §7, §33.1;
  [BCK-08](../DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md) §7–8, §13, OD-04;
  образцы [SCN-PUB-01](../SCENARIO_PUBLICATION_BCK10_AMENDMENT.md) (I3) и D3.1–D3.7.

## 0. Проверка входа J2

| Условие | Состояние на `b4368e0` | Итог |
|---|---|---|
| J1 | Route storage/sync/GPX/trim реализован, Review, owner acceptance открыт | есть |
| C3 | Content + Media + moderation lifecycle (Event, затем D3.x, I3), Review | есть |
| E1 | Local Catalog, OD-04-A/S для Activity и Scenario, Review | есть |
| Owner-решение | для публикации Route нет | **нет** |
| Принятый backend-контракт | BCK-11 v0.3.1 Draft; §32 «privacy trim policy and public precision → publication disabled»; в реестре BCK-07 `route` = `unavailable`, `dependency_pending: BCK-11` | **нет** |

Вывод: вход не пройден. По образцу I3 этот документ — недостающий контракт;
код J2 начинается только после утверждения RP-01…RP-16.

## 1. Что не меняется

- Route — непрерывный трек. Нет `RouteMode`, Scenario-полей, остановок,
  Scenario handoff и связи с Quick Plan. Route-items в Scenario остаются
  заблокированными (SP-08).
- BCK-11 владеет источником и immutable ревизией; BCK-07 — review, публикацией,
  withdraw и visibility; BCK-08 — только проекцией. Route не пишет Catalog.
- Клиент и console не пишут напрямую; все изменения — owner-service commands.
- Публичная геометрия никогда не строится из полной owner-геометрии.
- J1-контракт (`wgs84-e7-dm-v1`, `endpoint-radius-v1`, лимиты, CAS, журнал) не
  ослабляется.

## 2. Факты кода на `b4368e0`

| # | Факт | Следствие |
|---|---|---|
| F1 | J1 хранит один изменяемый документ `routes/{owner}:{routeId}` (current revision + tombstone); immutable `RouteRevision` нет | Нужен immutable snapshot при submit |
| F2 | Реестр BCK-07: `route` — resolver `pinned_immutable_revision`, `unavailable` | Нужны resolver, validator и порт ревизий, как у Scenario |
| F3 | `trimmedView` уже есть: pinned `expectedRevision`, `variantHash`, пересчитанная сводка, без bounds; пустой trim → `privacy_trim_empty` | Это единственный источник публичной геометрии |
| F4 | Canonical Route J1 содержит только title, shape, turningAnchor, profile, anchors, segments, waypoints. Нет description, cover, category, conditions; заметки waypoint — owner-only | Общие публичные поля приходят из Content draft (C3), не из Route |
| F5 | `catalogEnabledTypes` = event; Activity, Scenario, Find People включаются флагом composition | Нужна отдельная проекция BCK08-OD-04-R |
| F6 | Mobile RTE-07: локальная in-memory публикация со своей очередью модерации, fast-track `publish.route.direct`, `RouteSearchProjection` с bounds и overview polyline; RTE-08 Discover читает её локально | В Emulator-пути не использовать; иначе вторая система публикации |
| F7 | J1 `delete` побеждает всегда и стирает геометрию | Нужен guard при активной публикации |
| F8 | `routed`/`generated` не сохраняются (`license_blocked`); `demoOnly`-версии есть только в mobile | Публиковать можно только сохранённые J1 source kinds |

## 3. Решения на утверждение

Спорность: **Высокая** — есть разумная альтернатива с другими последствиями;
**Низкая** — следует из принятых документов.

| ID | Вопрос | Рекомендация | Альтернатива | Спорность |
|---|---|---|---|---|
| RP-01 | Что публикуется | Submit создаёт immutable `RouteRevision` из J1-записи по `expectedRevision` (CAS) с `contentHash`; BCK-07 пинит `{routeId, routeRevisionId, contentHash}`. Правки после submit на неё не влияют; изменения — только новым submit | Публиковать live-запись, блокируя правки на время review | Низкая (BCK-11 §8–10) |
| RP-02 | Публичная геометрия | Только `trimmedView` закреплённой ревизии (`endpoint-radius-v1`). Если в Route есть `recordedGps`-сегмент, trim обоих концов ≥ 200 м обязателен (`privacy_trim_required`); для остальных trim по выбору автора | Trim всегда по выбору автора; или обязательный trim для всех Route | Высокая (BCK-11 §32) |
| RP-03 | Точность | Публичные координаты — те же e7 после trim, без округления; bounds не публикуются (как J1) | Округлять публичную геометрию до 1e-5° | Средняя |
| RP-04 | PublisherRef v1 | Только personal `{user, ownerUserId}`; verified Creator с `publish`. Page-publisher — после IDP-03B/04B | Page из active workspace | Высокая |
| RP-05 | Visibility v1 | Только public. Unlisted/share-ссылки нет; private = не опубликован | Unlisted по token, как SP-03 | Средняя |
| RP-06 | Модерация | Каждый submit → `pendingReview`, без auto-approve. Fast-track `publish.route.direct` из RTE-07 на сервер не переносится. Классы отказа: `route.unsafe_or_private_location`, `route.misleading_difficulty_or_conditions`, `route.prohibited_content`, `route.mass_duplicate`, `route.provenance_or_license`. После публикации — report/hide по ADR 0013/K1, restriction K2/K3 | Fast-track для доверенных Creator | Средняя |
| RP-07 | Source kinds | Публикуются `importedGpx`, `recordedGps`, `freehand`, `intentionalDirect`, `fallbackDirect`; direct-сегменты помечены в публичной ревизии. Provenance-токены, parent/source ids и `verification` не публикуются; ничего не выдаётся за verified | Блокировать `fallbackDirect` | Низкая |
| RP-08 | Общие поля | Content draft (Create/C3) несёт title, description, locale, cover и `route {ref}`; title Content = title закреплённой ревизии. Геометрия только по ref | Перенести description/cover в J1 Route | Низкая |
| RP-09 | Waypoints | Публикуются typeId, title, safetyNote, distance from start и позиция — только если waypoint пережил trim. `note` (личная заметка) не публикуется | Публиковать и `note` | Средняя |
| RP-10 | Категория | `categoryId` в Content body из категории `route` Category System v1.4.3, проверка через существующий порт BCK-20 | Route без категории, как Scenario | Низкая |
| RP-11 | Новая ревизия, withdraw, delete | Новая public ревизия заменяет текущую атомарным switch BCK-07; старая видна до switch. J1 `save` при активной публикации разрешён. J1 `delete` при активной публикации или pending submit → `publication_active`, без каскада; после withdraw delete разрешён и стирает геометрию неопубликованных ревизий (hash остаётся) | Delete каскадно отзывает публикацию | Средняя |
| RP-12 | Catalog-проекция (BCK08-OD-04-R) | Семейство `Route`: Feed/Search/Details; Map — одна точка: первая точка trimmed-геометрии. В item — сводка (distance, ascent/descent, profile, shape, category, direct-маркер), без polyline. Полная trimmed-геометрия — только в Details по свежему чтению опубликованной ревизии | Overview polyline с новой versioned политикой упрощения | Высокая |
| RP-13 | Фильтры v1 | Text, category, market, Map leaf. Числовые фильтры distance/ascent/profile отложены | Сразу distance/profile facets | Средняя |
| RP-14 | Media и export | Cover через C1/D1/D2. Фото waypoint и публичный GPX export — вне J2 | Включить публичный GPX export | Низкая |
| RP-15 | Mobile | Существующий Route Create block + Q4 test-panel по образцу I3; RTE-07 in-memory публикация остаётся только mock-путём и не участвует в Emulator composition. Discover/Details для Route из Catalog — в J2, только если существующая Route Details сущность RTE-08 подходит без параллельной модели; иначе отдельный DTL-slice | Всегда отдельный DTL-slice | Средняя |
| RP-16 | Включение | Флаги default-off: `content.route.authoring`, Catalog family `route`; требуется `route.owner_sync`. Только local/LV Emulator | — | Низкая |

### 3.1 Ответы владельца 2026-10-21 и уточнения

- **RP-02 — принято.** Обязательный trim ≥ 200 м для Route с `recordedGps`, по
  образцу Strava и аналогов. О трудностях сообщать с вариантами решения. Уже
  видна одна: GPS-Route короче ≈ 400 м после trim пуст (`privacy_trim_empty`) и
  не публикуется. Вариант — понятное сообщение в readiness до submit.
- **RP-04 — заменено.** Публикуют и личный профиль, и Professional Page: Route —
  естественный тип для Page (тропы, дороги, маршруты). PublisherRef
  `{user | page}` из active workspace, как у шести типов (Event, Place,
  Activity, Find People, Rental, Collection); publish заново проверяет доступ
  к Page через fresh Identity read (существующий `PublisherEligibilityPort`).
  Требование ADR 0015 сохраняется: личная публикация — verified Creator, Page —
  active membership с page-scoped capability. Для Route это закрывает часть
  IDP-03B/04B (typed PublisherRef).
- **RP-06 — заменено.** Первая публикация проходит ручную модерацию. Если она
  одобрена без замечаний, следующие публикации одобряются автоматически.
  Правила (утверждены владельцем 2026-10-21):
  - доверие хранится на publisherRef (личный профиль или Page отдельно), а не
    на одном Route;
  - автоодобрение не пропускает автоматические проверки (validator, RP-02,
    RP-07, Media) — оно заменяет только ручной review;
  - **принято владельцем:** доверие теряется только при нарушении, которое
    подтвердил модератор (reject или `changesRequested` при ручной модерации;
    hide или restriction по решению staff после report). Снятие Route самим
    автором (withdraw/archive) и автоматическое скрытие по порогу жалоб
    (ADR 0013/K1) на доверие не влияют, пока модератор не вынес решение.
    Вернуть доверие — следующей чистой ручной модерацией;
  - автоодобренная ревизия отмечается в audit и доступна report/hide как обычная;
  - это новый механизм модерации: в коде Content/moderation автоодобрения нет.
- **RP-12 — принят вариант B.** Catalog item несёт точку старта trimmed-трека,
  сводку и упрощённую линию-превью до 256 точек для карточки и карты (как у
  Strava/Komoot). Превью строится сервером только из trimmed-геометрии
  опубликованной ревизии по versioned политике упрощения (детерминированной,
  с сохранением первой и последней точки и gaps); полная trimmed-геометрия —
  в Details. Вариант A (только точка) отклонён.

## 4. Матрица visibility × actor

R — read, E — edit J1 live record, S — submit, P — publish approved (staff по
review), A — activate/restore, W — withdraw.

| Состояние | Owner | Посторонний | Staff |
|---|---|---|---|
| personal (не опубликован) | R E | `not_found` | только BCK-19 audited |
| public pending | R E W | `not_found` | review: approve/reject |
| public published | R E S A W | R опубликованной trimmed-ревизии | P, restrict/restore |
| hidden/restricted | R статуса, E | `not_found` | restore |

Посторонний никогда не видит полную геометрию, anchors, trim-решение,
provenance, receipts, J1-журнал и неактивные ревизии.

## 5. Immutable published revision

Allowlist (всё прочее отбрасывает mapper):

- routeId, routeRevisionId, contentHash, schemaVersion, coordinatePolicy,
  privacyTrimPolicy, publisherRef, market;
- title, shape, profile;
- trimmed segments: order, sourceKind, encoded polyline e7, elevation stream;
  явные gaps сохраняются;
- сводка из trimmed-геометрии: points, segments, gaps, distance, ascent,
  descent, min/max elevation;
- waypoints по RP-09.

Никогда не публикуются: полная геометрия, anchors, `turningAnchorId`,
trim-радиусы и флаги `reenteredStart/End`, provenance (origin, import source
token, transformations, parser version, `sourceId`, `parentSegmentId`),
`note`, J1 receipts и журнал, owner id сверх publisherRef, история ревизий,
GPX bytes, имена файлов, timestamps.

## 6. Конкуренция, повторы и восстановление

- Submit: `expectedRevision` J1 + семантический idempotency key; устаревшая
  ревизия → `revision_conflict`. Повтор → тот же receipt.
- Publish approved и activate сверяют `contentHash` и пересчитывают trimmed view
  с тем же `variantHash`; иное → `revision_conflict`.
- Submit, publish и activate вызывают один validator (allowlist, RP-02, RP-07,
  readiness).
- Потерянный ответ/рестарт: durable receipt; нет дубликатов и частично
  объявленного успеха.
- Hide/withdraw/restriction убирают Route из новых ответов, включая старые
  snapshot/cursor и exact-ID reads.

## 7. План файлов J2 (после утверждения)

**Backend** (`apps/backend/functions/src`):

- `modules/route/route_publication.ts` — submit-snapshot, порт ревизий для
  BCK-07, guard удаления (RP-11);
- `modules/route/route_distribution.ts` — allowlist mapper из trimmed view;
- `modules/route/route_contract.ts`, `firestore_route_service.ts` — команда
  submit, коллекция `routeRevisions`, `publication_active`;
- `modules/content/domain/type_rules/route_rules.ts`; `content_type_registry.ts`
  (`route` available, `content-type-registry-v10`);
  `application/ports/route_revision_port.ts`; `content_publication_service.ts`;
  `validation_context.ts`; `firestore_content_repository.ts`;
- `modules/catalog/domain/route_projection.ts`; `catalog_item.ts`,
  `evaluation.ts`, `discover_query.ts`, `catalog_projector.ts`,
  `catalog_query_service.ts`, `emulator_catalog_composition.ts`;
- moderation profile `route.default` (RP-06): `moderation.ts`,
  `moderation_service.ts`, composition;
- `shared/feature_flags.ts`, `content_entry.ts`, `index.ts`, `firestore.rules`,
  execution manifest, `verify-content-persistence-layout.mjs`.

**Тесты и стенд:** unit `type_rules_route.test.ts`, mapper, projection;
security и `rules_default_deny`; Emulator `route_j2.test.ts`, world
`route_j2_world.ts`; stand `stand_content_route.ts`, digest/main,
`stand-j2-gate.mjs` (+ self-test), группа `route-j2` в runner.

**Mobile** (`apps/mobile/lib`): entities/gateway (domain port)/controller
публикации Route, секция в существующем review-шаге Route Create block,
`route_publication_composition.dart` с guard `RECHARGE_TEST_ROUTE_PUBLICATION`,
journal; Discover/Details по RP-15. Unit/widget, test-entry guard и
`route_publication_ui_stand_test.dart`.

**Docs:** этот амендмент → Accepted, BCK-11 v0.4 §36, строка J2 в LAUNCH_STATUS,
ячейка Route в AGENTS.md, `docs/verification/ROUTE_J2_VERIFICATION.md`.

**Rollback:** выключить `content.route.authoring` и family `route`; J1 записи и
mobile-черновики не трогаются; опубликованные ревизии уходят из Catalog.

## 8. Остаётся закрытым

Production auth/Page authority, cloud, deploy, providers (routing/elevation),
unlisted share, публичный GPX export, фото waypoint, числовые фильтры, revision history сверх публикаций, retention/DSR и
cross-market policy. Local Emulator evidence не является production-готовностью.

## 9. J2: реализация и уточнения (2026-10-21)

Ветка `claude/j2-route-publication` от `b4368e0`, отдельный worktree. Уточнения
ниже строже контракта и ничего не ослабляют.

- **Флаги.** Кроме `content.route.authoring` и Catalog family `route`
  (`RECHARGE_TEST_ROUTE_CATALOG`), команда `distribute` закрыта своим
  default-off флагом `route.publication` (как `planning.scenarioPublication`
  у I3). При выключенном флаге отказ ничего не записывает.
- **Снимок.** `distribute` создаёт `routeRevisions/{routeRevisionId}` — один
  снимок на J1-ревизию; повтор той же ревизии возвращает тот же снимок, не
  меняя J1 revision. Квитанция компактна (ids и hash, без геометрии), повтор
  перечитывает снимок. Лимит — 100 снимков на Route (`distribution_limit`).
- **Проверка в Content.** Валидатор заново выводит сводку, число direct-
  сегментов, старт, расстояния waypoints и превью из опубликованных сегментов,
  поэтому тело нельзя подделать даже с верным hash. Порт ревизий сверяет
  автора черновика (не publisher: Page не владеет Route), Route, hash и активный
  Route на create, submit, publish и activate. `contentId = routeId`
  резервирует только автор — чужой черновик не может «занять» Route.
- **Удаление (RP-11).** Отказ `publication_active` при активной публикации и
  при submission в `submitted`/`under_review`/`approved_for_publication`.
  После withdraw delete стирает геометрию всех снимков (hash остаётся), и
  activate прежней опубликованной ревизии отклоняется.
- **Доверие (RP-06).** Запись `moderationPublisherTrust/route:{type}:{id}`
  пишет только модуль модерации, в той же транзакции, что и квитанцию
  применённого решения; побеждает более новое решение. Автоодобрение — это
  профиль `route.trusted-publisher` с `policyDecisionId` одобрения,
  записанный в submission; отдельной записи в журнале модерации нет.
  Классы причин обязательны для staff `reject` Route; для `restrict` и
  `withdraw` — по желанию, чтобы K1 re-moderation не ломалась.
  Автоматического скрытия по жалобам в коде нет — правило о нём
  выполняется тривиально.
- **Превью (RP-12 B).** `route-preview-dp-v1`: детерминированный
  Douglas–Peucker по trimmed-треку, первая и последняя точка каждого
  сегмента всегда остаются, высоты отбрасываются, ≤ 256 точек. Превью есть в
  карточке и на Map leaf, полный trimmed-трек — только в Details.
- **Mobile.** Тестовая страница `/test/route-publication` за guard
  `RECHARGE_TEST_ROUTE_PUBLICATION` (четыре условия). Контроллер сохраняет
  Create Route через J1 sync, скрывает 200 м с концов, вызывает `distribute`,
  создаёт и обновляет один Content draft, загружает обложку, отправляет и
  публикует. Publisher берётся из active workspace при первой подготовке и
  хранится в журнале публикации; Content draft сохраняет его дальше.

**Сужения против плана файлов (честно).**

- Typed `publisherRef` в `RouteDraftData` (IDP-04B для Route) не добавлен:
  publisher фиксируется при первой подготовке публикации, а не при создании
  черновика.
- Mobile Discover/Details для семейства Route из Catalog не сделаны (RP-15):
  локальная Route Details RTE-08 читает in-memory проекцию RTE-07 другой формы.
  Подделывать её под Catalog было бы параллельной моделью. Это отдельный
  DTL-slice. Backend Feed/Search/Map/Details готов.
- Stand seed, `stand-j2-gate.mjs` и UI stand test не сделаны. Реальный
  контроллер с реальными Flutter-адаптерами проверяется против Emulator в
  группе `route-j2` (GPX import → J1 sync → trim → distribute → Content →
  publish).
- RTE-07 in-memory публикация и её fast-track остаются только mock-путём и не
  участвуют в Emulator composition.
