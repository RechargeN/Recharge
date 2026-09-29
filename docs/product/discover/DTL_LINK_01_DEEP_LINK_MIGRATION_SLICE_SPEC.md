# RECHARGE — DTL-LINK-01: Canonical Deep Link Migration Slice Spec

Версия: v0.3 (2026-08-24) — major revision после третьего раунда review.
Статус: **Approved** (утверждён владельцем продукта 2026-08-24, вслед за
`DTL-FND-01`; реализация авторизована и выполнена в изолированном
worktree `dtl-fnd-01`).

Runtime effect (этого документа): **none**. Сам текст не меняет код —
изменения внесены отдельным implementation-коммитом поверх `DTL-FND-01`,
под собственными analyzer/test/boundary/diff gates.

## Реализация — фактические отклонения от плана

Зафиксировано явно, не молча (см. также §4 file map ниже):

1. **11 из 13 call site'ов реально изменены** (`route_names.dart`,
   `app_router.dart`, `discover_details_page.dart`,
   `collection_details_page.dart`, `discover_map_page.dart`,
   `discover_results_page.dart`, `notifications_page.dart`,
   `notifications_repository_impl.dart`, `profile_page.dart`,
   `visited_places_page.dart`, `discover_hub_page.dart`).
   `category_page.dart` и `favorites_page.dart` **намеренно оставлены
   нетронутыми**: в обоих случаях `objectType` физически не известен в
   момент построения ссылки без выхода за рамки этого slice —
   `category_page.dart` знает только `itemId`, полученный из
   `DiscoverFeedSection` (не входит в file map этого slice, отдельный
   файл); `favorites_page.dart`'s `FavoriteItemEntity` не содержит
   `objectKind`/`objectType` вовсе (тип никогда не сохранялся у
   Favorites-записи). Тип угадан не был — оба сайта продолжают работать
   через legacy нетипизированный путь без изменения поведения.
2. **Collection-фича (~29 файлов read-side + минимальная DI-регистрация)
   перенесена в этот worktree** из незакоммиченных изменений исходного
   checkout — по явному запросу продукт-оунера, отдельным блоком перед
   реализацией самого slice. Create-side авторинг Collection (координатор,
   catalog search, publication repository — упирается в отдельную
   незакоммиченную фичу Location Search и несовместимые правки
   `CreateController`/`CreateState`/`CreateDraftEntity`) не перенесён —
   вне scope этого slice.
3. **`discover_item_entity.dart` затронут** сверх исходного file map:
   добавлено расширение `DiscoverItemCatalogType.catalogObjectType` —
   единая точка классификации `DiscoverItemEntity → CatalogObjectType`,
   переиспользуемая `DiscoverItemDetailsLookup.classify` и presentation
   self-link сайтами, чтобы не дублировать логику 7 раз и не тянуть
   presentation-код в data-слой.
4. Каноничная типизированная ссылка на Details, построенная self-link
   сайтами внутри `DiscoverDetailsPage` (share, auth-gate `originRoute`),
   теперь имеет форму `recharge://discover/details/{objectType}/{id}` —
   было `recharge://discover/details/{id}`.

## Что изменилось относительно v0.2

1. **Реализационный vertical дописан целиком.** v0.2 останавливалась на
   одном порте (`DetailsResolutionPort`) без registry, use case, provider
   composition и конкретных loader'ов для уже существующих типов. Теперь
   расписан полный список компонентов (§2) и то, какой существующий
   репозиторий каждый loader оборачивает.
2. **Этот slice теперь идёт сразу после `DTL-FND-01`, до
   `DTL-OBJ-01`/`DTL-RTE-01`/`DTL-CLG-01`** (см. обновлённый порядок в
   `DISCOVER_DETAILS_SYSTEM_SPEC.md` §Этап 3). Это устраняет саму
   причину, по которой `DTL-OBJ-01` был вынужден городить временный
   Rental-маршрут: резолвер уже существует до появления первого нового
   typed renderer.
3. **File map исправлена**: `features/discover/application/discover_providers.dart`
   удалён из списка (он не строит ссылки на Details — только определяет
   `discoverDetailsProvider`, провайдер данных, не навигации). Добавлен
   пропущенный `features/notifications/data/repositories/notifications_repository_impl.dart`,
   где захардкожены `/discover/details/place-1` (две строки). Список
   по-прежнему из 13 файлов, но состав исправлен, не просто число.
4. **Scenario alias убран из runtime file map и тестов.** Пока
   `DTL-SCN-01` заблокирован (`ScenarioDetailsRenderer` не существует),
   этот slice не создаёт `/discover/details/scenario/:id` и не пишет
   alias-тест для `recharge://scenario/{id}`. Единственное, что
   фиксируется — Accepted URI-контракт Scenario не трогается; сам alias
   и его нормализация — предмет `DTL-SCN-01`, когда renderer появится.

## Approval gates

Заблокировано до:

1. `DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем продукта.
2. `DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` реализован и принят
   (presentation renderer registry — то, что использует этот slice для
   диспетчеризации уже резолвленной projection, но не для самой
   резолюции — см. §1.1.4).
3. Сам этот документ отдельно получает статус `Approved`.

Явно **не зависит** от `DTL-OBJ-01`/`DTL-RTE-01`/`DTL-CLG-01` — наоборот,
этот slice идёт раньше них (см. «Что изменилось», п. 2).

## Связанные документы

- `DISCOVER_DETAILS_SYSTEM_SPEC.md` §9 (три ответственности), §11.
- `SCENARIO_BUILDER_SPEC.md` line 2118 (`recharge://scenario/{id}`
  Accepted canonical), §5 lines 494-509 (видимость Favorites/Review
  `{objectType, objectId}`-прецедент).
- Текущие loader-кандидаты: `GetDiscoverDetailsUseCase`/`DiscoverRepository`
  (Event/Activity/Place/Route), `PublishedCollectionDiscoveryPort`/
  `collectionByIdProvider` (Collection).

## 1. Scope

### 1.1 В scope — полный резолюционный vertical

1. **`CatalogObjectRef`** (`lib/shared/models/catalog_object_ref.dart`) —
   shared app-level primitive: `{objectType, objectId}`, тот же список
   стабильных `objectType`, что в родительском документе. Не router-only
   тип — используется Favorites, Collection, Notifications и т.д.
2. **`DetailsLookupPort`** (application-layer интерфейс, один на
   renderer family): `Future<TypedProjection?> lookup(String objectId)`.
   Реализации в этом slice:
   - **`DiscoverItemDetailsLookup`** — оборачивает уже существующий
     `GetDiscoverDetailsUseCase`/`DiscoverRepository.getDetails`,
     обслуживает `event`, `activity`, `place`, `route` (различение
     `route` от остальных трёх — через уже существующий
     `item.isPublishedRoute`, без изменения `DiscoverItemEntity`).
   - **`CollectionDetailsLookup`** — оборачивает уже существующий
     `PublishedCollectionDiscoveryPort`/эквивалент
     `collectionByIdProvider`, обслуживает `collection`.
   - Loader'ы для `session`/`find_people`/`class_workshop`/`rental` **не
     создаются** этим slice — для них ещё нет read-модели/adapter'а
     (Rental получит свой в `DTL-OBJ-01`, который последует за этим
     slice и просто зарегистрирует новый loader в уже существующий
     registry, не создавая собственного временного пути).
   - Loader для `scenario` **не создаётся** — `DTL-SCN-01` заблокирован.
3. **`DetailsLookupRegistry`** — реестр `objectType → DetailsLookupPort`.
   Архитектурно отдельный от presentation renderer registry
   `DTL-FND-01`: тот отвечает «каким виджетом рисовать уже резолвленную
   typed projection», этот — «откуда взять данные и подтвердить тип».
   Два реестра не совмещаются в одном классе (исправление 3-й
   ответственности из §11 родительского документа).
4. **`ResolveDetailsUseCase`** (application-layer): принимает
   `CatalogObjectRef` **или** legacy `itemId`/`collectionId` без явного
   типа; для legacy input определяет `objectType` тем же способом, что
   и сегодняшний код (`objectKind`/`isPublishedRoute` для
   discover-маршрута, фиксированный `collection` для
   collection-маршрута — см. §1.1.6); достаёт `DetailsLookupPort` из
   registry; вызывает `lookup`; если результат `null` **или**
   `actualObjectType != objectType_hint` (для canonical input, где hint
   уже был явным) — возвращает `notFound` (§12 родительского
   документа), без перебора остальных portов.
5. **Provider/DI composition** (`app/application/details_resolution_providers.dart`,
   по месту размещения — как `collection_discover_providers.dart`, не в
   `features/discover/application/`): собирает `DetailsLookupRegistry` из
   уже существующих providers/repositories, предоставляет
   `resolveDetailsProvider`.
6. **Router-парсер** (`app/router/details_route_parser.dart`): парсит
   входящий путь (`/discover/details/:objectType/:objectId`, legacy
   `/discover/details/:itemId`, `/collection/details/:collectionId`) в
   `CatalogObjectRef` или legacy-id — **не резолвит**, только парсит
   строку URI. Обязан воспроизводить сегодняшнюю legacy-классификацию
   один-в-один — не переизобретать её.
7. Точечная миграция 13 реальных call site’ов (§3) на построение
   `CatalogObjectRef`, где тип уже известен в момент построения ссылки.

### 1.2 Вне scope

- Новые typed read-модели для Session/Find People/Class-Workshop/Rental
  — их loader'ы регистрируются последующими slice'ами
  (`DTL-OBJ-01`+) в уже существующий registry этого slice, не создаются
  здесь.
- `recharge://scenario/{id}` alias/normalization — предмет `DTL-SCN-01`.
- Удаление legacy-маршрутов.
- Миграция внешних push-уведомлений на новый формат.
- Изменение read-моделей.

## 2. Компоненты vertical (сводка)

```
CatalogObjectRef                         — shared primitive
DetailsLookupPort                        — application interface (per family)
  ├─ DiscoverItemDetailsLookup            (wraps GetDiscoverDetailsUseCase)
  └─ CollectionDetailsLookup              (wraps PublishedCollectionDiscoveryPort)
DetailsLookupRegistry                    — objectType → DetailsLookupPort
ResolveDetailsUseCase                    — hint/legacy → typed projection | notFound
details_resolution_providers.dart        — DI composition
details_route_parser.dart                — router: URI → ref | legacy id (no resolution)
```

## 3. Точный file map

### 3.1 Новые файлы

| Файл | Назначение |
|---|---|
| `apps/mobile/lib/shared/models/catalog_object_ref.dart` | `CatalogObjectRef` + стабильные `objectType` |
| `apps/mobile/lib/features/discover/domain/repositories/details_lookup_port.dart` | Интерфейс `DetailsLookupPort` |
| `apps/mobile/lib/features/discover/data/repositories/discover_item_details_lookup.dart` | Реализация, оборачивает `GetDiscoverDetailsUseCase` |
| `apps/mobile/lib/features/discover/data/repositories/collection_details_lookup.dart` | Реализация, оборачивает `PublishedCollectionDiscoveryPort` |
| `apps/mobile/lib/app/application/details_lookup_registry.dart` | `DetailsLookupRegistry` |
| `apps/mobile/lib/app/application/resolve_details_usecase.dart` | `ResolveDetailsUseCase` (§1.1.4) |
| `apps/mobile/lib/app/application/details_resolution_providers.dart` | DI composition, `resolveDetailsProvider` |
| `apps/mobile/lib/app/router/details_route_parser.dart` | Router-only парсинг URI (§1.1.6) |

### 3.2 Изменяемые файлы — 13 реальных call sites (проверено `grep`)

| Файл | Что меняется |
|---|---|
| `apps/mobile/lib/app/router/route_names.dart` | Новая canonical route-константа; legacy — `@Deprecated` с комментарием на compatibility |
| `apps/mobile/lib/app/router/app_router.dart` | Регистрация canonical route; builder вызывает `resolveDetailsProvider` перед выбором renderer'а; legacy-регистрации не удаляются |
| `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart` | Построение внутренних ссылок на себя через `CatalogObjectRef` |
| `apps/mobile/lib/features/discover/presentation/pages/collection_details_page.dart` | Переход во вложенный объект через `CatalogObjectRef` |
| `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart` | Ссылки на Details со страницы карты |
| `apps/mobile/lib/features/discover/presentation/pages/discover_results_page.dart` | Ссылки на Details из списка результатов |
| `apps/mobile/lib/features/discover/presentation/pages/category_page.dart` | Ссылки на Details из категорий |
| `apps/mobile/lib/features/favorites/presentation/pages/favorites_page.dart` | Ссылки на Details из Favorites |
| `apps/mobile/lib/features/notifications/presentation/pages/notifications_page.dart` | Ссылки на Details из уведомлений (presentation) |
| `apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart` | Два хардкода `/discover/details/place-1` заменяются на построение `CatalogObjectRef`, где тип известен на месте генерации уведомления |
| `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart` | Ссылки на Details из Profile |
| `apps/mobile/lib/features/visited/presentation/pages/visited_places_page.dart` | Ссылки на Details из Visit History |
| `apps/mobile/lib/features/auth/presentation/pages/discover_hub_page.dart` | Ссылки на Details из Discover Hub |

`features/discover/application/discover_providers.dart` **исключён** —
он определяет `discoverDetailsProvider` (данные для уже открытой
страницы), не строит ссылки на неё.

### 3.3 Существующие тесты, требующие обновления

`discover_details_page_test.dart`, `search_page_test.dart`,
`home_page_test.dart`, `visited_places_page_test.dart` — те же 4, что и
в v0.2, без изменений.

### 3.4 Новые тесты

- Резолвер: hint совпал / hint разошёлся / объект не найден.
- Legacy-совместимость: оба старых маршрута резолвят те же объекты, что
  сегодня, включая Route-классификацию через `isPublishedRoute`.
- `notifications_repository_impl.dart`: уведомление с типом `place`
  строит `CatalogObjectRef(place, ...)`, не строку.
- **Без** alias-теста для `recharge://scenario/{id}` — не создаётся в
  этом slice (см. «Что изменилось», п. 4).

## 4. Acceptance criteria

- **LINK-AC-01.** Полный vertical (§2) реализован: `CatalogObjectRef`,
  `DetailsLookupPort`+2 реализации, `DetailsLookupRegistry`,
  `ResolveDetailsUseCase`, provider composition, router-парсер — не
  только один порт.
- **LINK-AC-02.** Резолюция отделена от router (только парсинг) и от
  presentation renderer registry (только выбор виджета) — оба реестра
  физически разные классы.
- **LINK-AC-03.** `CatalogObjectRef` — shared primitive, используется
  минимум в Favorites, Collection, Notifications.
- **LINK-AC-04.** Ровно 13 файлов из §3.2 обновлены, включая
  `notifications_repository_impl.dart` и **исключая**
  `discover_providers.dart`.
- **LINK-AC-05.** Оба legacy-маршрута резолвят объекты идентично
  сегодняшнему поведению, включая Route-классификацию.
- **LINK-AC-06.** Ни один alias/код/тест для `recharge://scenario/{id}`
  не добавлен этим slice.
- **LINK-AC-07.** Ни один loader для Session/Find People/Class-Workshop/
  Rental/Scenario не зарегистрирован этим slice — только Event/Activity/
  Place/Route/Collection (через 2 loader-реализации).
- **LINK-AC-08.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **LINK-AC-09.** Rollback возвращает все 13 файлов и оба маршрута к
  сегодняшнему raw-поведению.

## 5. Rollback

1. Вернуть 13 изменённых файлов к построению raw `itemId`/`collectionId`/
   хардкод-строк.
2. Удалить canonical route из `app_router.dart`/`route_names.dart`.
3. Удалить все 8 новых файлов vertical (§3.1).
4. Legacy-маршруты не менялись по существу — откат безопасен даже для
   уже разосланных внешних ссылок.

## 6. Открытые вопросы

1. Формат push-уведомлений (ADR 0013, политика 16) — миграция вне
   scope (§1.2).
2. Момент, когда `DTL-SCN-01` добавит `scenario`-loader и
   `recharge://scenario/{id}` alias в уже существующий из этого slice
   registry — не решается здесь, фиксируется как явная будущая
   зависимость `DTL-SCN-01`.
