# RTE-PUB-01 — Route publication: амендмент BCK-11 (предложение)

- Revision: **0.1**, 2026-10-21.
- Status: **Proposed — ждёт решений владельца RP-01…RP-16.** Документ не
  разрешает Firebase, cloud, deploy, providers или production и не утверждает
  BCK-11 целиком. Код J2 не начат.
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
unlisted share, публичный GPX export, фото waypoint, overview polyline,
числовые фильтры, revision history сверх публикаций, retention/DSR и
cross-market policy. Local Emulator evidence не является production-готовностью.
