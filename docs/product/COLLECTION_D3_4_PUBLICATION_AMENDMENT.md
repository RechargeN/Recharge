# D3.4 — Collection / Guide через Create, Content, Media и модерацию (только Emulator)

Статус: **Review (2026-10-12), Windows-local Emulator evidence (§12).**
Ветка `claude/d3-4-collection` от `e87883f` (integration), отдельный worktree
`C:/Users/User/.claude/worktrees/recharge-d3-4`. От D3.3 (Rental) не зависит.

Документ устроен как поправки D3.1/D3.2 и разделён на три части; итог каждой
оценивается отдельно:

- **A. Emulator publication lifecycle** — что сервер делает с Collection;
- **B. Совместимость с формой Create** — **проверенное подмножество**; полная
  совместимость формы Create **не объявляется**;
- **C. Готовность Catalog/Discover** — оценка без изменений; D3.4 её не
  повышает и **не создаёт Catalog-модели Collection**.

## 0. Основание и граница

Заход D3.4 — «только Collection / Guide», зависимость E1: подключить принятый
Collection validator, включение только в Emulator, полный lifecycle C3 и
mobile Create. Ссылки Collection допускаются только на разрешённые
опубликованные объекты по ID. Отдельная Catalog-модель Collection не создаётся.

Опора в коде (на `e87883f`):

- валидатор `collection_rules.ts` (CLG-CRT-01 v1.0) зарегистрирован как
  `available` с `sourceResolver: published_object_membership`; членство он
  проверяет через синхронный `PublishedObjectLookup`, которого никто не
  передавал: любая подборка получала `collection.published_objects_unavailable`;
- E1/D3.9: Catalog-owned `PlaceLinkService` — exact-ID проверка опубликованного
  Place по указателю и immutable-ревизии владельца Content;
- механизм D3.1/D3.2: `emulatorAuthoringTypes`, `authoringTypesFor`, отказ
  композиции собираться с типом вне списка или без валидатора; общий шлюз
  Content mobile с параметром `typeId`; journal IO D11.

Не входит: изменения валидатора, реестра типов и контракта ответа Content;
Catalog-проекция, Discover и Details Collection; removal-only и archive
(CLG §3.11); форма Create и её локальная публикация; облако и deploy; другие
Create-типы.

## 1. Решения владельца (2026-10-12)

1. **Типы пунктов — все доступные.** Проверка в Catalog общая для пяти
   listing-типов, которые разрешает валидатор (`place`, `route`,
   `bookableSession`, `classWorkshop`, `rental`); ни один тип не объявлен
   запрещённым в коде — решает опубликованный объект нужного типа. Сейчас в
   Emulator публикуется Place; Rental станет членом без нового захода после
   D3.3; Route, Session, Class/Workshop дают `unknown`, пока их публикации нет.
2. **Скрытый или ограниченный пункт** (был опубликован, сейчас скрыт владельцем
   или ограничен модерацией) — `unavailable`, требует подтверждения в
   `compositionReview` (CLG §3.6, §11).
3. **Activate разрешён с перепроверкой**: на теле целевой ревизии
   перепроверяются жёсткие отказы и доступность Catalog; естественный decay
   (CLG §3.10) не блокирует.
4. **Mobile — панель + пикер в Create**: под test-guard `ItemsPickerSection`
   читает опубликованные объекты из Catalog; тестовая панель публикует черновик.
   Activate и правка после публикации — только бэкенд (как Q4 в D3.1).
5. Принято без возражений: основа `e87883f`; категории по каноническому
   артефакту BCK-20 (§2.4).

---

## Часть A. Emulator publication lifecycle

### 2.1 Включение

- Флаг `content.collection.authoring` (`contentFlagIds.collectionAuthoring`),
  выключен по умолчанию, только `local`/`LV` в Emulator.
- `content_entry.ts`: `emulatorAuthoringTypes = ['event', 'place', 'activity',
  'collection']`; `authoringTypesFor` получает необязательный четвёртый флаг
  (отсутствует — выключен). Инвариант D3.1 сохраняется. Rental остаётся вне
  списка.
- `contentCommandV1` / `contentQueryV1` строят набор из четырёх флагов.

### 2.2 Матрица операций

Правило D3.1 без изменений: вход Content открыт, если включён хотя бы один
флаг authoring; флаг Collection закрывает `createDraft`, `updateDraft`,
`submitForPublication`, `publishApprovedRevision`, `activatePublishedRevision`
(`type_disabled`, до любого вопроса о членстве); скрытие и чтение владельцем
флагом типа не закрываются. Флаги authoring не управляют модерацией C2 и D2.

### 2.3 Членство: только разрешённые опубликованные объекты по ID

Content сам статус чужих объектов не определяет. Он спрашивает Catalog через
consumer-порт `PublishedObjectMembershipPort`; политика и чтения источника —
в Catalog.

- **Catalog.** Единый evaluator `PublishedObjectLinkService`
  (`published_object_link_service.ts`) для listing-типов
  `place | route | session | class_workshop | rental`: текущий указатель,
  immutable-ревизия, тип, `contentId`, рынок, `public_catalog`, непустой title,
  тело не `unlisted/private`, указатель не сдвинулся между чтениями.
  `PlaceLinkService` (D3.9) делегирует ему и отвечает ровно как раньше
  (скрытый Place — `forbidden` до чтения ревизии). Проверка целостности тела
  (`bodyHash`) в источнике Catalog расширена с Place/Activity на все
  listing-типы. Новой проекции, модели элемента или хранилища Collection нет.
- **Content-адаптер** `CatalogCollectionMembership` переводит тип пункта
  Collection в тип Content (`bookableSession → session`, `classWorkshop →
  class_workshop`, остальные как есть); тип вне закрытого списка — `forbidden`
  без запроса.

| Ответ Catalog | Смысл | Для Collection |
|---|---|---|
| `eligible` | опубликован, виден, тот же тип и рынок | `ready` |
| `withheld` | опубликован этого типа и рынка, сейчас скрыт владельцем или ограничен модерацией (причина не раскрывается) | `unavailable` — требует подтверждения в `compositionReview` |
| `unknown` | публикации с этим id нет (черновик, несуществующий id) | жёсткий отказ `validation_failed` (внутр. `collection.item_ref_unknown`) |
| `forbidden` | другой тип (в т.ч. Event, Activity, Collection), рынок или политика видимости | жёсткий отказ `validation_failed` (внутр. `collection.item_ref_forbidden`) |
| `unavailable` / сбой | ответ не получен | `validation_failed` (`collection.published_objects_unavailable`, fail closed) |

- **Когда.** Сервис Content спрашивает Catalog заново для точного тела:
  на `submitForPublication` и на `publishApprovedRevision` (ответ submit не
  переиспользуется) — вместе с валидатором; на `activatePublishedRevision` —
  для тела целевой immutable-ревизии: блокируют `unknown`, `forbidden` и
  недоступность Catalog; `withheld` не блокирует (decay, CLG §3.10), review
  этой ревизии не перепроверяется (валидатор при activate не запускается ни
  для одного типа). Отказ не меняет указатель, ревизии, submissions и эффекты.
- **Границы.** Один вопрос на уникальную ссылку; при `items` больше
  `maxItems` вопросов нет (тело такого размера и так не проходит 64 КБ
  `assertBoundedBody`). Ответ — текущее чтение источника, не lease и не
  распределённая атомарность двух агрегатов.
- **Включение.** Env `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true` включает
  evaluator для проверок Content и запросы `publishedObject` /
  `publishedObjectCandidates` (Discover). Без него ответ Catalog —
  `unavailable`, и Collection отказывает (fail closed).
- **Discover-запросы (аддитивно).** `discoverQueryV1` получает
  `publishedObject {marketId, typeId, contentId}` и
  `publishedObjectCandidates {marketId, typeId, text?, after?, limit?}`
  (`typeId` — только listing-тип; рынок `LV`; страница ≤ 50). Контракт —
  `packages/api_contracts/schema/discover/v1/published_object_link_result.schema.json`:
  eligible-ответ несёт только `typeId, contentId, publishedRevisionId,
  pointerRevision, marketId, title`, остальные статусы — ничего. `placeLink` и
  `placeCandidates` (D3.9) не меняются.

### 2.4 Справочные данные Collection

Collection отвечает по каноническому артефакту BCK-20 (та же закреплённая
ревизия, что у Activity): пара категория/подкатегория должна существовать;
применима любая существующая пара — как `effectiveApplicableTypes` в mobile,
где Collection применим ко всем категориям. Неизвестная пара неприменима;
нет артефакта — `collection.taxonomy_unavailable`. Явный список
`applicableTypes` артефакта это неявное правило не кодирует (Collection там
только у `other/other_event`) — пробел контракта BCK-20, открыт (§10). Прежняя
синтетика «любая пара применима» для Collection закрыта.

### 3. Шаги lifecycle

| Шаг | Команда / путь | Кто решает | Отказы (примеры) |
|---|---|---|---|
| 1. Черновик | `createDraft` (`typeId: collection`, тело `{}`), `updateDraft` | Identity: Session, verified Creator, точная Page | `type_disabled`, `publisher_not_eligible`, `revision_conflict` |
| 2. Медиа | Media C1: обложка и фото галереи к точному черновику | Media | отказ или недоступность Media |
| 3. Submit | `submitForPublication` | Content: валидатор Collection со справочниками §2.4 и членством §2.3, readiness медиа | `validation_failed` (без кодов `collection.*`), `media_not_ready` |
| 4. Review | staff C2 (approve / reject / restrict) | модерация C2 | `moderation_decision_stale` |
| 5. Публикация | `publishApprovedRevision` | Content: повторная валидация и свежее членство | `validation_failed`, `moderation_required`, `revision_conflict` |
| 6. Скрытие | `withdrawPublication` (владелец) | Content | `revision_conflict` |
| 7. Возврат | `activatePublishedRevision` | Content: членство тела целевой ревизии | `validation_failed`, `media_not_ready` |
| 8. Правка | `updateDraft` → submit → review → publish переключает указатель | как 1–5 | как 1–5 |

Шаги 7 и 8 подтверждаются только бэкендом. Повторы с тем же ключом
идемпотентны; устаревшая ревизия черновика или указателя отклоняется.

### 4. Эффекты и соседние модули

- **Catalog**: факт Collection — `excluded: type_disabled`; rebuild, activate
  и rollback это сохраняют. Discover отклоняет `typeIds: [collection]`.
  Collection сама не является целью связи (`publishedObject` как Place —
  `forbidden`).
- **Booking**: handoff пропускает эффекты Collection (0 фактов).
- **D2**: обложка и галерея Collection подпадают под D2 (ограничение,
  подавление в указателе Content, снятие только активацией издателем).

### 4.1 Что не меняется в части A

`collection_rules.ts`, `content_type_registry.ts`, `validation_context.ts`,
контракт ответа Content (коды клиенту не идут, allowlist деталей не
расширяется), `catalogEnabledTypes`, модели элемента Catalog, Booking,
`firestore.rules`, `emulator-stand.mjs`, ответы `placeLink`/`placeCandidates`.
Сервис Content получает только необязательный порт
`publishedObjectMembership` (по умолчанию нет — поведение прежнее).

---

## Часть B. Совместимость с формой Create (проверенное подмножество)

### 5.1 Источник, путь и пикер

- Источник — текущий черновик Create (`CreateRepository.loadDraft`), только
  `objectType == collection` с `collectionData`. Форма Create и её локальная
  публикация не меняются.
- Тестовый вход: define `RECHARGE_TEST_COLLECTION_PUBLICATION=true`, не
  release, binding `testBackend`, loopback `demo-recharge/europe-west1` — все
  четыре условия сразу; тот же guard защищает маршрут
  `/test/collection-publication`, пикер Create, каждую команду Content и каждую
  загрузку Media.
- **Пикер Create (решение 4).** Под guard `CollectionCatalogSearchRepository`
  в Create — `TestEntryCollectionCatalogSearchRepository`: Catalog-адаптер
  `CatalogCollectionCatalogSearchRepository` (поиск —
  `publishedObjectCandidates` по каждому разрешённому типу, до 10 страниц по 50
  и до 20 результатов на тип; preview — `publishedObject`, ready только
  `eligible`); без guard — прежний mock. Решение принимается на каждом вызове.
  Тот же адаптер отдаёт панели точный статус каждого пункта.
- Панель «Collection publication (test)»: Save, Upload media, Submit, Refresh,
  Publish, Hide, «мои подборки» (до 20) и серверный статус каждого пункта
  (до 50 показано; сервер проверяет все).

### 5.2 Таблица полей: черновик Create → тело Content Collection

| Тело Content | Источник в Create | Правило |
|---|---|---|
| `title` | `title` | trim |
| `shortDescription`, `fullDescription` | те же поля | trim; пусто → не отправляется |
| `categoryId`, `subcategoryId` | `mainCategory`, `subcategory` | trim; пусто → не отправляется |
| `media.coverImage`, `media.gallery` | `media.coverImage`, `media.gallery` | id ассетов Media; до загрузки — `loc_<attachmentId>` |
| `areaLabel`, `areaId` | `collectionData` | trim; пусто → не отправляется |
| `anchor` | `anchorLatitude/Longitude` | только если заданы обе |
| `budgetTier` | `collectionData.budgetTier` | имя enum |
| `visibility` | `visibility` | `public`/`unlisted`; `private` — отказ §5.3 |
| `sections[]` | `collectionData.sections` | `id` → UUIDv5 (§5.5), title trim, `order` как есть |
| `items[].id` | `item.id` | UUIDv5 (§5.5) |
| `items[].ref` | `item.ref` | `{objectId, objectType}` как есть; членство решает сервер |
| `items[].snapshot` | `item.snapshot` | title, categoryLabel, publisherRef `{type, id}`, price/currency, checkedAtUtc; без geo и **без `coverMediaId`** (чужой Media id к ревизии не прикрепляется) |
| `items[].sourceStatus`, `order` | как в черновике | подсказка; сервер решает сам |
| `items[].sectionId` | `item.sectionId` | UUIDv5 той же секции |
| `items[].curatorNote`, `highlight` | как в черновике | note trim, пусто → не отправляется; `highlight` только `true` |
| `compositionReview` | `collectionData.compositionReview` | `draftRevision` = серверная ревизия, которую создаст это сохранение (`expected + 1`); подтверждённые ключи — как в Create, отсортированы |

`publisherRef` идёт в команду `createDraft`, а не в тело.

### 5.3 Не отправляется совсем (черновик целиком)

`unsupported_capability:<список>` без единого вызова, даже пустого черновика:
`unknown_fields` (схема новее), `visibility.private`, `composition_review`
(автор не прошёл preview), `composition_review_stale` (подтверждён пункт,
которого нет в черновике, или не подтверждён пункт, который сам Create видел
`unavailable`).

### 5.4 Сохранение и восстановление

Как в D3.1: пустой черновик под стабильным ключом (повтор возвращает тот же),
затем полное тело. Review принадлежит ревизии, которую создаёт сохранение,
поэтому при `revision_conflict` ревизия читается заново (только для черновика
этого автора) и тело **маппится заново** с новой ревизией. Автора в теле
Collection нет; `createdByUserId` сервера хранится в журнале и защищает от
чужой записи.

### 5.5 Идентификаторы и ключи

UUIDv5 в namespace `cc088011-4f89-400c-b2cd-ebbf22fbcdc8` от
`recharge:collection-publication:v1:<account>:<publisherType>:<publisherId>:<localDraftId>`:
`item:<localItemId>`, `section:<localSectionId>` (перестановка id не меняет),
`attachment:cover`, `attachment:gallery:<localRef>`,
`upload:<attachmentId>:<sha256>`. Значения сверены с Python `uuid5`. Префикс
ключей Content — `clp1-<24 hex SHA-256 scope>`.

### 5.6 Журнал

`content/collection-publications-v1.json` в каталоге поддержки, до 100
записей, общий IO D11. Запись привязана к аккаунту и publisher; чужие записи
хранятся, но не возвращаются; статус всегда с сервера.

### 5.7 Расхождения: форма Create допускает → сервер отклоняет

Общая фикстура `packages/api_contracts/schema/content/v1/fixtures/collection_create_compat.json`:
тело, которое делает маппер для каждого случая Create (Dart-тест сверяет
байт в байт), и коды валидатора под справочниками Emulator и статусами
членства случая (TS-тест). По проводу каждый непустой случай —
`validation_failed` без кода.

| Случай | Код валидатора |
|---|---|
| `valid` | — |
| `withheld_acknowledged` | — |
| `withheld_not_reviewed` | `collection.composition_review_mismatch` |
| `too_few_items` | `collection.min_items` |
| `area_missing` | `collection.area_required` |
| `short_description_missing` | `collection.short_description_required` |
| `cover_missing` | `collection.cover_image_required` |
| `subcategory_unknown` | `collection.subcategory_not_applicable` |
| `curator_note_too_long` | `collection.curator_note_length` |
| `local_object` | `collection.item_ref_invalid`, `collection.local_id_unreplaced` |

Жёсткие отказы членства (`unknown`, `forbidden`, outage) — не коды
валидатора; они доказаны интеграционным и Emulator-тестами (§8). Это
проверенное подмножество; полная совместимость формы Create не объявляется.

---

## Часть C. Готовность Catalog/Discover

- Сейчас: `catalogEnabledTypes = {event}` (+ Activity по флагу D3.8);
  Collection получает `excluded: type_disabled`; Discover Collection
  отклоняет; mobile Discover показывает Collection из локального источника
  (секция «Guides», `CollectionDetailsPage`).
- D3.4 доказывает только исключение (и после rebuild/rollback), отсутствие
  фактов Booking и то, что Collection не становится целью связи.
- Для готовности нужны: решение BCK08-OD-04 для Collection, read-проекция
  (live-резолв пунктов на Details, мини-карта из source projection), перенос
  подавления D2 в факты, Details из Catalog.

**Вывод:** Catalog/Discover для Collection **не готовы**; Catalog-модель
Collection в D3.4 не создавалась.

---

## 7. Стенд и гейт D3.4

- Стенд запускается с `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true` (гейт ставит
  его сам). Флаги `content.place.authoring` и `content.collection.authoring`
  включает только `stand-seed.mjs collection seed`.
- `collection seed`: три фиксированных Place (черновик `{}` → обложка → тело с
  автором сервера → submit → одобрение staff → publish), затем Collection на
  них (черновик `{}` → обложка → тело с review ревизии 2 → submit → одобрение →
  publish). Точка прерывания — `STAND_SEED_INTERRUPT_AFTER=member-2`. Ids всех
  объектов — в манифест (`contentCollection`); digest именует их метками
  `seed-collection` и `seed-collection-member-N`.
- `collection verify`: указатель видим, ссылки ревизии = три члена, члены
  видимы, обложка готова, Catalog `excluded: type_disabled`, фактов Booking нет.
- `scripts/stand-d3-4-gate.mjs --yes`: свежий стенд → `collection seed` →
  verify → digest; свежий стенд → прерванный seed → возобновление → digest =
  чистому → повтор (`reused`) → digest тот же; затем на этом ПК
  `collection_publication_stand_test.dart` и
  `collection_publication_ui_stand_test.dart` (с define); остановка проверяется.

## 8. Проверки

| № | Часть | Что | Уровень и файл |
|---|---|---|---|
| L1 | A | общий evaluator: пять типов, `withheld` только для своего типа и рынка, отказы, сдвиг указателя, outage, выключен; кандидаты; ответы D3.9 прежние | unit: `published_object_link.test.ts` (+ неизменный `place_link.test.ts`) |
| L2 | A | запросы `publishedObject`/`publishedObjectCandidates`: только listing-типы, рынок, id, границы страницы | unit: `published_object_query.test.ts` |
| L3 | A | контракт ответа: eligible — только allowlist, остальные статусы пусты | contract: `published_object_link_fixture.test.ts` |
| A1 | A | `authoringTypesFor` (16 сочетаний + отсутствующий флаг), список типов, отказ композиции | unit: `content_authoring_types.test.ts` |
| A2 | A | справочники §2.4: ревизия, все пары применимы, неизвестные нет, без артефакта — нет ответа | unit: `emulator_collection_reference_data.test.ts` |
| A3 | A | адаптер членства: перевод типов, ответы, сбой, тип вне списка (включая prototype-ключи) | unit: `catalog_collection_membership.test.ts` |
| A4 | A | сервис: матрица флагов; без порта — отказ; все типы спрашиваются своим типом; `withheld` + ровно подтверждение; `unknown`/`forbidden`/outage — отказ даже с подтверждением; publish перечитывает; activate терпит decay и отказывает жёстким; отказ ничего не меняет; только для Collection, один вопрос на ссылку | integration: `content_collection_enablement.test.ts` |
| A5 | A | матрица §2.2 по проводу; без env у Functions — `validation_failed` без кода | Emulator: `content_collection_callable.test.ts` |
| A6 | A | lifecycle §3 с реальными Place через Catalog: скрытые/ограниченные члены и подтверждение; unknown, черновик, чужой тип, Collection как член — отказ; без env — fail closed; publish перечитывает; hide, activate с decay, новая ревизия; эффекты §4; точный ответ пикера; D2 обложки | Emulator: `content_collection_emulator_flow.test.ts` |
| B1 | B | маппер §5.2–§5.5: тела = фикстура, UUIDv5 (Python `uuid5`), перестановка, snapshot без geo/coverMediaId, отказы §5.3 | unit (Dart): `collection_content_body_mapper_test.dart` |
| B2 | B | цепочка §5.7: тело → код валидатора; review чужой ревизии — stale | unit (TS): `type_rules_collection_create_compat.test.ts` |
| B3 | B | контроллер: закрытый вход, локальные отказы, создание и тело, восстановление (3 сбоя, один черновик), повторное связывание review с новой ревизией, медиа, submit/publish/hide, журнал (аккаунт, автор), статусы пунктов | unit (Dart): `collection_content_publication_controller_test.dart` |
| B4 | B | guard (четыре условия), маршрут, шлюз `typeId: collection`, Media и Catalog закрыты; пикер Create переключается по guard | unit (Dart): `collection_publication_test_entry_guard_test.dart` |
| B5 | B | Catalog-адаптер пикера: типы, исключения, пагинация с границей, нарушения контракта, точные статусы | unit (Dart): `catalog_collection_catalog_search_repository_test.dart` |
| S1 | A+B | стенд: чистый = прерванный и возобновлённый = повторный (digest) | гейт `stand-d3-4-gate.mjs` |
| S2 | B | mobile против стенда: пикер находит члены, точные статусы; контроллер и UI публикуют; неизвестная ссылка — отказ сервера | гейт + `flutter test` |
| R | — | регресс: `test:emulator`, тесты без Emulator, `verify-*`, гейты D3.1, D3.8 `--linked-place` (изменён `PlaceLinkService`), C3; `api_contracts`, `flutter analyze`, `flutter test`, boundary, `git diff --check` | финальный прогон |

## 9. Откат

Выключить `content.collection.authoring` (по умолчанию выключен) — создание и
изменение Collection закрываются, скрытие и чтение владельцем остаются; без
`RECHARGE_TEST_COLLECTION_MEMBERSHIP` Collection отказывает fail closed, а
запросы `publishedObject*` отвечают `unavailable`; без define mobile —
прежние mock-пикер и локальный путь. Полный откат — revert коммита D3.4:
Collection уходит из списка Emulator, порт и адаптер удаляются,
`PlaceLinkService` возвращается к собственной реализации с теми же ответами.
Данные Emulator не мигрируются; immutable-ревизии не переписываются.

## 10. Остаточные риски и открытые пункты

- Правило применимости Collection (§2.4) выведено из mobile; артефакт BCK-20
  его не кодирует — нужно решение контракта BCK-20.
- Коды нарушений Collection клиенту не передаются (allowlist деталей —
  только Activity); панель показывает точные статусы пунктов из Catalog.
- Проверка членства — до одного вопроса на ссылку, каждый — несколько чтений
  источника; для production нужен пакетный owner read (OD-05/08/10).
- Ответ `withheld` по точному id подтверждает, что такая публикация была;
  D3.9 уже раскрывал это как `forbidden`. Причины не раскрываются.
- Членство — текущее чтение, не lease: изменение члена после publish видно
  только следующему чтению; Collection это допускает (CLG §3.10).
- Removal-only и archive (CLG §3.11), Catalog/Discover/Details Collection
  (OD-04), live-резолв пунктов на сервере, Activate и правка после
  публикации на mobile, физические устройства, Linux, облако и production — не
  покрыты.
- Найденное при заходе: страж импортов Content
  (`content_publication_security.test.ts`) падал на `e87883f` — D9
  импортировал `canonicalJson`/`sha256Hex` в `content_catalog_source.ts` без
  регистрации. В D3.4 оба символа зарегистрированы (страж не ослаблен: это
  проверка целостности ревизии владельца, D3.9).

## 11. Карта файлов

Пути от корня репозитория. «М» — изменяемый, «Н» — новый.

### 11.1 Бэкенд: код (14)

| Файл | | Назначение |
|---|---|---|
| `apps/backend/functions/src/modules/catalog/domain/published_object_link.ts` | Н | listing-типы, статусы, публичные факты |
| `apps/backend/functions/src/modules/catalog/application/published_object_link_service.ts` | Н | единый exact-ID evaluator и кандидаты |
| `apps/backend/functions/src/modules/catalog/application/place_link_service.ts` | М | делегирует evaluator, ответы D3.9 прежние |
| `apps/backend/functions/src/modules/catalog/application/catalog_query_service.ts` | М | `publishedObject`, `publishedObjectCandidates` |
| `apps/backend/functions/src/modules/catalog/application/discover_query_handler.ts` | М | аддитивные запросы и их проверки |
| `apps/backend/functions/src/modules/catalog/infrastructure/emulator_catalog_composition.ts` | М | evaluator по env D3.4 |
| `apps/backend/functions/src/modules/catalog/infrastructure/content_catalog_source.ts` | М | целостность тела для всех listing-типов |
| `apps/backend/functions/src/modules/content/application/ports/published_object_membership_port.ts` | Н | consumer-порт |
| `apps/backend/functions/src/modules/content/infrastructure/catalog_collection_membership.ts` | Н | адаптер типов и ответов |
| `apps/backend/functions/src/modules/content/application/content_publication_service.ts` | М | необязательный порт; членство на submit/publish/activate |
| `apps/backend/functions/src/modules/content/infrastructure/emulator_reference_data.ts` | М | Collection по артефакту BCK-20 |
| `apps/backend/functions/src/shared/feature_flags.ts` | М | `content.collection.authoring` |
| `apps/backend/functions/src/content_entry.ts` | М | список типов, флаг, порт в композиции |
| `apps/backend/functions/src/index.ts` | М | четвёртый флаг |

### 11.2 Бэкенд: тесты, стенд, гейт, скрипты (27)

Новые: `test/unit/catalog/published_object_link.test.ts`,
`test/unit/catalog/published_object_query.test.ts`,
`test/contract/published_object_link_fixture.test.ts`,
`test/unit/content/emulator_collection_reference_data.test.ts`,
`test/unit/content/catalog_collection_membership.test.ts`,
`test/unit/content/type_rules_collection_create_compat.test.ts`,
`test/integration/content_collection_enablement.test.ts`,
`test/emulator/content_collection_callable.test.ts`,
`test/emulator/content_collection_emulator_flow.test.ts`,
`test/support/content_collection_world.ts`,
`test/stand/stand_content_collection.ts`,
`apps/backend/scripts/stand-d3-4-gate.mjs` (все в `apps/backend/functions/`,
кроме скрипта).

Изменяемые: `test/unit/content/content_authoring_types.test.ts` (D3.4),
`test/integration/content_publication_security.test.ts` (регистрация
`CatalogCollectionMembership` для `content_entry.ts` и `canonicalJson`/`sha256Hex`
для `content_catalog_source.ts`), `test/support/content_place_world.ts`
(необязательный `enabledTypes`), `test/stand/stand_main.ts` (команда
`collection`), `test/stand/stand_content_event.ts` (поле манифеста),
`test/stand/stand_digest.ts` (метки Collection и членов),
`apps/backend/functions/package.json` (`test:emulator:collection`),
`apps/backend/scripts/run-emulator-test-groups.mjs` (группа `collection`),
`apps/backend/scripts/run-emulator-test-groups.test.mjs` (43 задачи, 7 групп),
`apps/backend/scripts/stand-seed.mjs` (команда), `apps/backend/scripts/verify-r1-layout.mjs`
(регистрация интеграционного теста), `apps/backend/README.md`.

### 11.3 Контракты (3)

`packages/api_contracts/schema/discover/v1/published_object_link_result.schema.json` (Н),
`packages/api_contracts/schema/discover/v1/fixtures/published_object_link.json` (Н),
`packages/api_contracts/schema/content/v1/fixtures/collection_create_compat.json` (Н).

### 11.4 Mobile (23)

Новые: `lib/features/create/domain/usecases/build_collection_content_body.dart`,
`lib/features/create/domain/entities/collection_content_publication.dart`,
`lib/features/create/domain/repositories/collection_content_publication_gateway.dart`,
`lib/features/create/application/collection_content_publication_controller.dart`,
`lib/features/create/data/file_collection_publication_journal.dart`,
`lib/features/create/data/repositories/catalog_collection_catalog_search_repository.dart`,
`lib/features/create/presentation/widgets/collection_content_publication_section.dart`,
`lib/app/presentation/collection_content_publication_panel.dart`,
`lib/app/di/collection_content_publication_composition.dart`,
`test/unit/collection_content_body_mapper_test.dart`,
`test/unit/collection_content_publication_controller_test.dart`,
`test/unit/collection_publication_test_entry_guard_test.dart`,
`test/unit/catalog_collection_catalog_search_repository_test.dart`,
`test/fixtures/create/user_collection_draft.dart`,
`test/backend_local/collection_publication_stand_test.dart`,
`test/backend_local/collection_publication_ui_stand_test.dart` (все в `apps/mobile/`).

Изменяемые: `lib/app/di/service_locator.dart` (guard, Catalog-адаптер,
пикер Create по guard), `lib/app/router/route_names.dart`,
`lib/app/router/app_router.dart`, `test/backend_local/support/stand_backend.dart`.

### 11.5 Документы (7)

`docs/product/COLLECTION_D3_4_PUBLICATION_AMENDMENT.md` (Н, этот документ),
`docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md` (§43),
`docs/product/BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md` (строка
`collection`), `docs/product/create/COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md`
(ссылка на тестовый серверный путь), `docs/architecture/LAUNCH_STATUS.md`
(строка D3.4), `docs/evidence/backend/d3/D3_4_COLLECTION_2026-10-12.md` (Н),
`apps/backend/README.md` (раздел D3.4 и группа).

## 12. Статус

**Review (2026-10-12).** Windows-local Emulator evidence; не Done; без коммита.
Проверенная ревизия, отпечаток и таблица результатов — в
[evidence](../evidence/backend/d3/D3_4_COLLECTION_2026-10-12.md).
