# RECHARGE — DTL-OBJ-01: Object / Offer Engine Slice Spec (Phase 1)

Версия: v0.9 (2026-08-26) — Done: correction-pass закрыл все 6
находок review (5 контрактных проблем + 1 доп., `PublisherRef.type`),
полный gate suite перепрогнан и зелёный.
Статус: **Done** (второй раз, после Review). Первый gate-прогон
(`26b80dc`…`4eecc70`) был технически зелёным, но code review вскрыл:
(1) CTA не выполнял реальный launch внешнего URL — disclosed gap не
отменял canonical-контракт §12; (2) `object_offer_section_matrix.dart`
был мёртвым кодом — `offerProfileSections`/`objectOfferProfileFor`
нигде не вызывались, Rental-body был хардкодом (`OBJ-AC-01`/`06` не
выполнены); (3) «e2e»-тест вызывал `sink.activate()` вручную, минуя
`CreateController.publishDraft()`/router/widget (`OBJ-AC-03` не
доказан); (4) availability-подписи говорили «available» без
requested-interval/freshness — канонический §17.3/§8.3 требует «N
units listed» и «Confirm on provider site»; (5) сбой `sink.activate()`
проглатывался без retry/трассировки — Rental мог навсегда остаться
невидимым в Discover при видимом пользователю «Опубликовано»; (доп.)
`PublisherRef.type` терялся в `PublishedRentalDiscoveryEntity`,
оставался только `id`. Каждая находка закрыта отдельным, проверяемым
изменением — см. «Фактический результат реализации» ниже за точной
трассировкой пункт-за-пунктом на коммиты и файлы.

Runtime effect (этого документа): **none**.

## Rental Create prerequisite (git-история) — resolved

Historical record, kept for context (was blocking 2026-08-24 through
the same day's later prerequisite pass):

При попытке реализации (2026-08-24, worktree `dtl-fnd-01`) обнаружено:
Rental Create-сторона (~20 файлов: draft data, create block, sections,
publish repository, private authoring datasource и т.д.) отсутствует в
git-истории рабочей ветки целиком — существует только как
незакоммиченные изменения в исходном checkout, вперемешку с другими
незакоммиченными фичами (Session, Location Search, Team Invitations и
др.). В отличие от Collection (`DTL-LINK-01`, `DTL-CLG-01`), где
недостающие файлы были достаточно изолированы, чтобы перенести только
read-side (~14 файлов) отдельным коммитом, Rental требует правки
**`CreateController`** — единого файла, где разница между committed и
исходной версией составляет **~1368 строк** с **304 вхождениями
`Rental`**, разбросанными по всему файлу, не изолированным блоком.
Перенести весь файл целиком означало бы утащить и все остальные
незакоммиченные фичи вместе с ним; вырезать вручную только
Rental-фрагменты — высокий риск сломать что-то несвязанное в самом
большом контроллере Create.

Решение (согласовано с владельцем продукта 2026-08-24): **не
переносить грязный `CreateController` и не вырезать 304 Rental-фрагмента
вручную.** Вместо этого — отдельный prerequisite-заход **до**
возврата к этому slice:

1. Стабилизировать Rental Create в исходном checkout (закоммитить его
   как самостоятельную, работающую фичу — вне scope Details-волны).
2. Отделить Rental от Session/Location Search и прочих незакоммиченных
   правок, которые сейчас переплетены в том же дереве.
3. Прогнать полный набор гейтов (`flutter analyze`, `flutter test`,
   boundary gate, `git diff --check`) на стабилизированном Rental
   Create отдельно от Details-волны.
4. Разложить результат на самостоятельные, проверяемые коммиты.
5. Только затем — перенести эти проверенные prerequisite-коммиты в
   Details-worktree и вернуться к реализации `DTL-OBJ-01`.

Шаги 1–5 выполнены 2026-08-24 (см. `RENTAL_CREATE_STABILIZATION_PLAN.md`
§8 для полной трассировки, включая 3 disclosed-отклонения от
исходного 7-файлового плана, найденные только сквозным прогоном
тестов). Rental Create теперь доступен в этой ветке как committed,
gate-green prerequisite. Этот конкретный (git-hygiene) блокер закрыт.

## Rental publication lifecycle prerequisite — resolved (второй, отдельный блокер)

Historical record, kept for context (was blocking 2026-08-24 through
the same day's later `RNT-PUB-01` implementation). Обнаружено при
подготовке file plan для §3 этого документа (Rental publication-sink
vertical), до написания какого-либо кода.

**Проблема.** `sink.activate(...)` (§3.5) должен вызываться только для
листингов в состоянии `published` — канонический
`RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md` §16 (line 912): «`pending_review`
отсутствует в Discover». Но единственный сегодняшний publish-путь для
Rental — общий с Event/Place/Activity/FindPeople generic-путь
`CreateController.publishDraft()` (`create_controller.dart:3525`) →
`CreateRepositoryImpl.publishDraft()` (`create_repository_impl.dart:292,
299`) — **всегда** устанавливает `DraftStatus.pendingReview`/
`PublishStatus.pendingReview`, без исключений и без ветвления по
capability. Вызов `sink.activate(...)` сразу после этого преждевременно
показал бы в Discover неодобренный Rental.

**Почему это не просто «добавить if» в существующий hook.** Канонический
документ прямо относит выбор `pending_review | published` не к Create
UI, а к отдельной **application policy**:

- §13.8: «Author не выбирает moderation result. Application policy
  возвращает `pending_review` или trusted direct `published`.»
- §16.1 шаг 12: «policy-selected `pending_review | published` result».
- §15.2: «`RNT-CRT-01` may simulate submit locally, but ... it is not
  production publication ... unless trusted test policy authorizes
  direct publish» — то есть уже реализованный (и смёрженный) `RNT-CRT-01`
  **сознательно** ограничен только mock `pending_review`; trusted
  direct-publish policy — заявленно отдельная, ещё не реализованная
  часть контракта, не упущение этой стабилизации.
- §4.2 Operation matrix уже называет `Direct publish` отдельной
  operation, gated `publish.rental.direct` — capability-сигнал
  (`canPublishRentalDirect`) уже добавлен в `CreateController` во время
  Rental-стабилизации, но никак не влияет на фактический publish-путь
  сегодня.

**Решение.** Отдельный bounded slice `RNT-PUB-01` — trusted local/mock
policy, решающая `pending_review | published` для Rental, точно по
контракту §13.8/§16.1/§4.2. Только `published`-результат с валидной
публичной проекцией может вызывать `sink.activate`; `pending_review`
обязан продолжать давать `notFound` в Discover (как и сегодня — просто
потому что `sink.activate` не вызывается вообще).

**Резолвлено 2026-08-24.** `RNT-PUB-01` реализован и Done — 4 коммита
(`454b758`/`1bded1b`/`e6d795f`/`4a6b23f`), полный gate suite зелёный
(`flutter analyze` 0 issues, `flutter test` 854 passing, boundary
71/71, `git diff --check` чисто). См.
`RNT_PUB_01_RENTAL_PUBLICATION_LIFECYCLE_SLICE_SPEC.md` «Фактический
результат реализации» — включая один непредусмотренный review'ами
deadlock, найденный и исправленный при полном прогоне suite перед
коммитом. `published`-состояние для Rental (personal publisher,
`publish.rental.direct` + verified Creator + trusted policy) теперь
реально достижимо — §3 этого документа разблокирован.

**Что не блокируется.** §4 (Rental loader, read-сторона) и `RentalDetailsPage`/
`app_router.dart`-часть file plana (см. предыдущий раунд обсуждения)
не зависят от publication lifecycle и могут готовиться параллельно —
но без реального Rental-контента для показа (`sink.activate` не
вызван) для сквозного OBJ-AC-03 end-to-end теста всё равно нужен
`RNT-PUB-01`.

## Что изменилось относительно v0.2

**Временный Rental read vertical и временный маршрут — убраны целиком.**
Причина: `DISCOVER_DETAILS_SYSTEM_SPEC.md` §Этап 3 пересмотрен —
`DTL-LINK-01` (canonical resolver vertical) теперь идёт **до** этого
slice, не после. Это значит, что `DetailsLookupRegistry`/
`ResolveDetailsUseCase` уже существуют к моменту реализации `DTL-OBJ-01`;
Rental просто регистрирует новый loader в уже существующий registry —
никакого временного маршрута/провайдера/страницы не требуется.

Вместо этого добавлена недостающая **write-сторона** Rental-verticals,
которой не было даже в v0.1/v0.2: `RentalPublicationIndexSink` (Create
depends on this), конкретный existing hook point (`BuildRentalPublicProjectionUseCase`
consumer в `CreateController`, ниже §3), и explicit DI-wiring по образцу
`CollectionPublicationDiscoveryAdapter`/`RoutePublicationDiscoveryAdapter`.

## Approval gates

Заблокировано до:

1. `DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем продукта.
2. `DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` реализован и принят.
3. **`DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md` реализован и
   принят** — этот slice регистрирует Rental-loader в уже существующий
   `DetailsLookupRegistry`, не создаёт собственный резолюционный путь.
4. Сам этот документ отдельно получает статус `Approved`.

## Связанные документы

- `DISCOVER_DETAILS_SYSTEM_SPEC.md` §5, §9, §10 (DTL-D11), §12.
- `PLACE_CREATE_BLOCK_SPEC.md` v1.0, `EVENT_CLASSIFICATION_SPEC.md`
  rev 2.2.3, `RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.4,
  `RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md` v1.0.
- `apps/mobile/lib/app/adapters/collection_publication_discovery_adapter.dart`
  — точный образец push(publish)/pull(read) паттерна: один класс
  реализует и Create-side sink, и Discover-side port, поверх одного
  общего local datasource, инстанциируется один раз в
  `app/di/service_locator.dart`.
- `apps/mobile/lib/features/create/domain/usecases/build_rental_public_projection_usecase.dart`,
  `apps/mobile/lib/features/create/domain/entities/rental_listing.dart` —
  уже существующая public-projection логика Rental (вычисляет
  `RentalListing`, но **не публикует** его в Discover — сегодня это
  чисто preview/validation use case внутри `CreateController`, без
  publication sink на другом конце).

## 1. Scope

### 1.1 В scope — ровно 4 из 7 типов

Place (`venue`), Event и Recharge Activity (`participation`), Rental /
Equipment (`offer`) — единственные четыре create-спеки со статусом
Accepted/Approved. Session, Find People, Class/Workshop — Candidate,
не входят (см. родительский документ §5.1); последующий `DTL-OBJ-0x`.

1. Три визуальных профиля (`venue`, `participation`, `offer`) — реальные
   код-пути `ObjectOfferDetailsRenderer`.
2. Секционная матрица §5.1 родительского документа — data-driven
   конфигурация; Place/Event/Activity визуально идентичны сегодняшнему
   выводу; Rental — первый Details-рендеринг.
3. **Rental publication-sink vertical** (§3) — недостающая write-сторона,
   без которой `PublishedRentalDiscoveryEntity` нечем наполнять.
4. **Rental loader**, зарегистрированный в уже существующем
   `DetailsLookupRegistry` из `DTL-LINK-01` — Rental Details открывается
   через уже существующий canonical route
   `/discover/details/rental/:id`, без временного маршрута.
5. Place/Event/Activity продолжают читаться через `DiscoverItemEntity`
   (легаси, DTL-D02) — их loader в `DetailsLookupRegistry` уже добавлен
   `DTL-LINK-01` (`DiscoverItemDetailsLookup`), этот slice его не
   трогает, только регистрирует renderer поверх той же projection.
6. Viewer CTA policy Rental (`Rent`) отделена от creator-capability
   строк `create.rental`/`submit.rental`/`publish.rental.direct`
   (DTL-D11).

### 1.2 Вне scope

- Read-модели/adapters для Session, Find People, Class/Workshop.
- Изменение canonical resolver vertical (`DTL-LINK-01`) — этот slice
  только добавляет одну реализацию `DetailsLookupPort` и один loader,
  не трогает сам registry/use case/router-парсер.
- Route renderer (`DTL-RTE-01`), Collection (`DTL-CLG-01`), Scenario
  (`DTL-SCN-01`).
- Изменение `DiscoverItemEntity`.
- Booking/Payments сверх уже одобренного `externalBookingUrl`-redirect.

## 2. Три профиля как код

| Профиль | Тип(ы) в этом slice | Обязательные секции | Запрещённые секции |
|---|---|---|---|
| `venue` | Place | hero, название, часы работы, address/area | одна дата начала, capacity |
| `participation` | Event, Activity | hero, дата/время **или** гибкое время (Activity), место, publisher | opening hours таблица |
| `offer` | Rental | hero, инвентарь/доступность, цена, pickup, publisher | opening hours таблица |

## 3. Rental publication-sink vertical (write-сторона)

Ровно по образцу `CollectionPublicationDiscoveryAdapter`:

1. **`RentalPublicationIndexSink`** (`features/create/domain/repositories/rental_publication_index_sink.dart`)
   — интерфейс, который Create depends on: `activate(RentalPublishedVersion)`,
   `archive(rentalId)`. Сегодня у Rental **нет** ни одного эквивалента
   этого интерфейса (в отличие от Collection, где
   `CollectionPublicationIndexSink` уже существовал до adapter'а) — этот
   slice создаёт его впервые.
2. **`PublishedRentalDiscoveryPort`** (`features/discover/domain/repositories/`)
   — интерфейс, который Discover depends on: `getActiveRental(rentalId)`,
   `loadActiveRentals()`.
3. **`PublishedRentalDiscoveryLocalDataSource`** — local store, аналог
   `PublishedCollectionDiscoveryLocalDataSource`.
4. **`RentalPublicationDiscoveryAdapter`** (`app/adapters/`) —
   единственный класс, реализующий оба интерфейса и импортирующий обе
   стороны (Create + Discover), поверх одного `_localDataSource`.
5. **Hook point в Create**: `CreateController` уже вызывает
   `_buildRentalPublicProjection(id:, draft:)` (строка около 386,
   `build_rental_public_projection_usecase.dart`) сегодня как
   preview/validation-only вызов, без какой-либо записи наружу. Этот
   slice добавляет: после успешного commit публикации Rental (там же,
   где сейчас коммитится сама публикация черновика — точная строка
   уточняется первым шагом реализации, не дописывается здесь
   умозрительно) — вызов `sink.activate(...)` с построенным
   `RentalListing`. Это единственная точка, где `features/create`
   узнаёт про Discover-facing sink — оформляется как явное точечное
   исключение из «не менять Create domain» (см. `DTL-FND-01`/`DTL-OBJ-01`
   собственная оговорка про необходимые исключения, поднимаемые на
   отдельное подтверждение).
6. **DI-wiring** (`app/di/service_locator.dart`): один экземпляр
   `RentalPublicationDiscoveryAdapter`, зарегистрированный и как
   `RentalPublicationIndexSink` (инжектируется в Rental publish use
   case), и как `PublishedRentalDiscoveryPort` (инжектируется в Discover
   loader, §4).

## 4. Rental loader (read-сторона, поверх уже существующего резолвера)

- **`RentalDetailsLookup`** (`features/discover/data/repositories/`) —
  реализация `DetailsLookupPort` из `DTL-LINK-01`, оборачивает
  `PublishedRentalDiscoveryPort.getActiveRental`.
- Регистрируется в `DetailsLookupRegistry` под `objectType: rental` —
  расширение уже существующего реестра, не новый параллельный механизм.
- Rental Details открывается через уже существующий canonical route
  `/discover/details/rental/:id` (из `DTL-LINK-01`), без temporary route.

## 5. Предлагаемый file map

| Файл | Тип | Назначение |
|---|---|---|
| `apps/mobile/lib/features/discover/presentation/renderers/object_offer_details_renderer.dart` | новый | `DetailsRenderer` для трёх профилей |
| `apps/mobile/lib/features/discover/presentation/renderers/object_offer_section_matrix.dart` | новый | Data-driven секционная конфигурация |
| `apps/mobile/lib/features/discover/domain/entities/published_rental_discovery_entity.dart` | новый | Typed read-модель Rental, primitives-only |
| `apps/mobile/lib/features/create/domain/repositories/rental_publication_index_sink.dart` | новый | Create-side sink interface (§3.1) |
| `apps/mobile/lib/features/discover/domain/repositories/published_rental_discovery_port.dart` | новый | Discover-side port interface (§3.2) |
| `apps/mobile/lib/features/discover/data/datasources/published_rental_discovery_local_datasource.dart` | новый | Local store (§3.3) |
| `apps/mobile/lib/app/adapters/rental_publication_discovery_adapter.dart` | новый | Единственный composition boundary (§3.4) |
| `apps/mobile/lib/features/discover/data/repositories/rental_details_lookup.dart` | новый | `DetailsLookupPort` реализация (§4) |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | изменён (точечное исключение) | Вызов `sink.activate(...)` после commit публикации Rental (§3.5) |
| `apps/mobile/lib/app/di/service_locator.dart` | изменён | Регистрация `RentalPublicationDiscoveryAdapter` под обоими интерфейсами (§3.6) + регистрация `RentalDetailsLookup` в `DetailsLookupRegistry` |
| `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart` | изменён | Регистрация `place`/`event`/`activity` на `ObjectOfferDetailsRenderer` вместо compatibility renderer |
| тесты паритета (Place/Event/Activity) | новые | Визуальная идентичность старому выводу |
| тесты Rental end-to-end | новые | Publish → sink.activate → port.getActiveRental → loader → renderer → виджет |
| тесты viewer CTA vs capability (DTL-D11) | новые | `Rent` управляется viewer-state resolver'ом, не capability |

## 6. Acceptance criteria

- **OBJ-AC-01.** Три профиля — одна конфигурация section-matrix engine.
- **OBJ-AC-02.** Place/Event/Activity визуально и функционально
  идентичны выводу compatibility renderer (тесты паритета).
- **OBJ-AC-03.** Rental **реально открывается** пользователем через уже
  существующий canonical route (`DTL-LINK-01`), end-to-end от publish
  до рендера — не только существованием файлов entity/adapter.
- **OBJ-AC-04.** `RentalPublicationIndexSink`/`PublishedRentalDiscoveryPort`
  реализованы ровно одним классом (`RentalPublicationDiscoveryAdapter`),
  как у Collection/Route — не двумя независимыми хранилищами данных.
- **OBJ-AC-05.** `PublishedRentalDiscoveryEntity` — primitives-only, без
  импорта `RentalDraftData`/`RentalListing` Create-типов в Discover.
- **OBJ-AC-06.** Section-matrix engine не содержит хардкода на 4 типа.
- **OBJ-AC-07.** `Rent` управляется viewer-state resolver'ом независимо
  от creator-capability текущего пользователя.
- **OBJ-AC-08.** Session/Find People/Class-Workshop не получили ни
  read-модели, ни sink/port, ни loader'а, ни секции конфигурации.
- **OBJ-AC-09.** Единственное изменение в `features/create` —
  точечный вызов `sink.activate(...)` в уже существующем hook point
  (§3.5), не рефакторинг Rental publish flow.
- **OBJ-AC-10.** Этот slice не заявляется как завершение полного
  Object/Offer target contract для Place/Event/Activity — они остаются
  на legacy `DiscoverItemEntity` projection.
- **OBJ-AC-11.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **OBJ-AC-12.** Rollback восстанавливает compatibility renderer для
  Place/Event/Activity и полностью убирает Rental (entity, sink, port,
  datasource, adapter, loader, DI-регистрацию, точечный вызов в
  `CreateController`) — Rental возвращается к состоянию «Create работает,
  Discover о нём не знает», не к сломанному промежуточному виду.

## Фактический результат реализации (2026-08-24, первый заход)

Реализация прошла по file map §5 без структурных отклонений. Одно
архитектурное решение принято по ходу (не предусмотрено спекой заранее,
но не противоречит ей) и раскрывается явно:

**`ObjectOfferDetailsRenderer` для venue/participation делегирует в
`CompatibilityObjectRenderer` целиком, а не реконструирует эквивалентный
layout из section-matrix.** OBJ-AC-01 требует «одна конфигурация
section-matrix engine», OBJ-AC-02 — точный визуальный/функциональный
паритет с сегодняшним выводом. Реконструкция ~1000 строк проверенного
Place/Event/Activity-рендеринга как data-driven конфигурации несла бы
реальный риск тонких визуальных регрессий без соразмерной выгоды — сам
документ (§1.1 п.2) заранее допускает, что «Place/Event/Activity
визуально идентичны сегодняшнему выводу» в Phase 1. Решение: один
класс `ObjectOfferDetailsRenderer`, зарегистрированный под
`DetailsRendererFamily.objectOffer` (соответствует «engine» на уровне
registry/dispatch); venue/participation строят внутри себя
`CompatibilityObjectRenderer` и форвардят все 4 build-метода —
гарантирует OBJ-AC-02 *по построению*, не по аккуратности
реализации. Проверено: уже существующий
`discover_details_parity_test.dart` прошёл без единого изменения.
`offer` (Rental) — единственный профиль, реально построенный из
`offerProfileSections`/новых Rental-виджетов, поскольку это первый
Details-рендеринг этого типа вообще (§1.1.2).

Первый gate-прогон был технически зелёным (`flutter analyze` 0 issues,
`flutter test` 861 passing, boundary 71/71, `git diff --check` чисто,
5 коммитов `26b80dc`…`4eecc70`), и на этой основе slice был
преждевременно помечен Done — без полной сверки кода против контракта.
Владелец продукта затребовал такую сверку отдельно; она нашла 6 находок
(перечислены в статус-заголовке выше), после чего статус был откачен
на Review. Итоговое закрытие каждой находки — ниже.

## Correction-pass (2026-08-26) — закрытие 6 находок review

Один заход внутри того же slice, без новой спеки, 4 послойных коммита
(тесты — отдельным пятым):

**1. CTA не открывал URL (canonical §12).** Добавлена зависимость
`url_launcher: ^6.3.0` (её не было нигде в проекте). `RentalDetailsPage`
теперь реально вызывает `launchUrl(parsed, mode:
LaunchMode.externalApplication)` со snackbar-фоллбэком при неудаче.
Viewer-auth check сознательно не добавлен: соседний generic-Details CTA
(`discover_details_page.dart`'s `_onCtaTap`) тоже не auth-гейтится, а
§17.5 прямо говорит «Все product users уже authenticated; Guest-row в
матрице нет» — это раскрытое отклонение от буквальной формулировки
review, не тихое игнорирование. Коммит `aa73b23`.

**2. Section-matrix была мёртвым кодом.** `offerProfileSections`
теперь реально управляет `buildBody()` Rental-профиля через
`_bodySectionFor`-диспетчер (переставить/убрать секцию в списке меняет
фактический рендер). `objectOfferProfileFor` — который до этого не
вызывался вообще нигде — теперь реальный runtime-guard: `assert` в
`.discoverItem`-конструкторе ловит попытку прогнать non-venue/
participation тип через этот путь (и бросает `ArgumentError` для
любого типа вне scope этого slice) вместо тихого рендера чего-то
generic. `OBJ-AC-01`/`06` теперь выполнены буквально, не только по
намерению. Коммит `aa73b23`.

**3. «E2E»-тест вызывал `sink.activate()` вручную.**
`rental_details_end_to_end_test.dart` переписан: основной widget-тест
теперь идёт `CreateController.publishDraft()` → реальный
`RentalPublicationDiscoveryAdapter` → реальный `GoRouter`,
зарегистрированный точно как canonical route в `app_router.dart`, →
публичный (промотирован из `_ResolvedDetailsRoute`) `ResolvedDetailsRoute`
→ ассерты на фактический вывод `RentalDetailsPage`. Никто в тесте не
вызывает `sink.activate` или порт напрямую — `OBJ-AC-03` доказан
сквозным путём, не изолированной вызываемостью файлов. Коммит `9af552f`.

**4. Availability-подписи говорили «available» без freshness.**
`rentalInventoryGroupLabel` теперь пишет «`N units listed`» (канонический
§17.3), не «available». Поскольку `PublishedRentalDiscoveryEntity`
вообще не несёт поля `confirmedAt`/freshness (pre-existing пробел, не
внесённый этим slice) — CTA-матрица §17.5 «unknown/stale»-строка
применяется безусловно, не только «иногда»: кнопка теперь всегда
показывает `Confirm on provider site` (было `Check availability on
provider site`), это строже буквальной формулировки review, выведено
прямым чтением полной таблицы §17.5, а не только двух процитированных
пунктов. Коммит `aa73b23`.

**5. Сбой `sink.activate()` проглатывался без retry/трассировки.**
`CreateController` получил `_activateRentalSinkWithRetry`: одна
немедленная повторная попытка, затем — при повторном сбое —
`analyticsService.track('rental_sink_activation_failed', {rental_id})`
вместо тихого проглатывания. `create_publish_succeeded` получил
`sink_activated: bool`, чтобы «опубликовано, но не проиндексировано»
было отличимо от настоящего успеха в телеметрии. Коммит `1d40954`.

**(доп.) `PublisherRef.type` терялся в read-модели.**
`PublishedRentalDiscoveryEntity` получил обязательное поле
`publisherType` (`user`/`page`), прописанное сквозь entity, local
datasource (`_toMap`/`_fromMap`) и
`RentalPublicationDiscoveryAdapter.activate()`. Коммит `1aa03a5`.

Гейты после correction-pass: `flutter analyze` 0 issues, `flutter test`
861 passing (тот же 1 pre-existing tracked skip — golden-тест Route,
не относится к DTL-OBJ-01; 0 failures), boundary 71/71 (бюджет не
менялся), `git diff --check` чисто. 5 коммитов поверх исходных шести:
`1aa03a5` (PublisherRef.type), `1d40954` (sink retry/tracking),
`aa73b23` (section-matrix wiring + real CTA launch + availability
copy), `9af552f` (router promotion + переписанные e2e/widget тесты),
и коммит с этим документом.

## 7. Rollback

1. Вернуть регистрацию `place`/`event`/`activity` на compatibility
   renderer.
2. Удалить `object_offer_details_renderer.dart`,
   `object_offer_section_matrix.dart`.
3. Удалить весь Rental vertical: entity, sink interface, port interface,
   local datasource, adapter, loader.
4. Убрать регистрацию из `service_locator.dart` и вызов `sink.activate(...)`
   из `create_controller.dart` (revert точечного изменения).
5. Persisted data, Rental Create/публикация продолжают работать
   независимо — только Discover больше не видит Rental.

## 8. Открытые вопросы

1. Точная строка в `CreateController`, где коммитится сама публикация
   Rental (не preview-вызов `_buildRentalPublicProjection`) — уточняется
   первым шагом реализации, не блокирует принятие документа.
2. Порядок последующего `DTL-OBJ-0x` (Session/Find People/Class-Workshop)
   зависит от порядка апрува их апстрим-спек владельцем продукта.
