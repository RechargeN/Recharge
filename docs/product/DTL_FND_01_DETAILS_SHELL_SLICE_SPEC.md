# RECHARGE — DTL-FND-01: Details Shell And Renderer Foundation Slice Spec

Версия: v0.2 (2026-08-24) — синхронизация с `DTL-LINK-01` v0.3: §2
уточнён, чтобы не пересекаться с ответственностью
`DetailsLookupRegistry`/`ResolveDetailsUseCase`, введённых в `DTL-LINK-01`
позже. Это единственная содержательная правка; scope/file map/AC не
менялись.
Статус: **Approved** (утверждён владельцем продукта 2026-08-24, вместе с
родительским документом; реализация авторизована).

Runtime effect (этого документа): **none**. Сам текст не меняет код —
изменения вносятся отдельными коммитами implementation-ветки/worktree по
file map ниже, каждый под собственные analyzer/test/boundary/diff gates.

## Approval gates — выполнены

1. `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем
   продукта 2026-08-24 (Accepted).
2. Этот документ отдельно получил статус `Approved` от владельца
   продукта 2026-08-24.

Оба условия выполнены — реализация авторизована. Ниже — план, теперь
разрешение на код.

## Связанные документы

- `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` v0.2 (Accepted) — родительский
  каноничный контракт; §3 (каноническое решение), §4 (Details Shell),
  §5 (Object/Offer), §12 (состояния) — прямые источники этого slice.
- `docs/architecture/ARCHITECTURE_BASELINE.md` — правило 3 (layering
  `presentation -> application -> domain`), правило 5 (`features/*` не
  импортируют друг друга напрямую), правило 10 (архитектурные изменения
  baseline требуют новый Accepted ADR — этот slice его не создаёт и не
  требует, поскольку не меняет baseline, только состав файлов внутри
  `features/discover/presentation`).

---

## 1. Scope

### 1.1 В scope

1. `DetailsShell` — presentation-only оболочка (app bar, hero-слот,
   sticky action container, loading/error/not-found представление §12
   родительского документа), не требующая координаты, даты, цены,
   расписания или CTA как обязательных полей.
2. Расширяемый typed `DetailsRenderer` contract — точка расширения для
   будущих `ObjectOfferDetailsRenderer` / `RouteDetailsRenderer` /
   `ScenarioDetailsRenderer` / `CollectionDetailsRenderer`, ни один из
   которых не реализуется в этом slice.
3. **Compatibility renderer** — одна реализация `DetailsRenderer`,
   которая воспроизводит один в один сегодняшнее содержимое
   `DiscoverDetailsPage` для Event, Activity, Place и временно
   встроенного Route (то есть включая существующий
   `_PublishedRouteCard` как есть, без выделения полноценного Route
   renderer).
4. Перевод существующего `DiscoverDetailsPage` на `DetailsShell` +
   compatibility renderer **без визуального или функционального
   изменения**: тот же маршрут, тот же набор карточек, тот же порядок,
   те же CTA, та же аналитика.
5. Widget/contract-тесты, подтверждающие поведенческий паритет старой и
   новой композиции.

### 1.2 Вне scope

- Новые read-модели для Session, Find People, Class/Workshop, Rental.
- Publication adapters (`app/adapters/*_publication_discovery_adapter.dart`)
  для любого нового типа.
- Новый `CatalogObjectRef`-маршрут (`/discover/details/:objectType/:objectId`)
  — текущий маршрут `/discover/details/:itemId` не меняется.
- Полноценное выделение `RouteDetailsRenderer` (интерактивная карта вместо
  фото-hero, geometry/elevation/difficulty как first-class) — остаётся
  `DTL-RTE-01`.
- Миграция Collection на общий shell.
- Scenario Details.
- Любые изменения DI, domain или data слоёв — **за одним исключением**:
  если сохранение текущего Details-контракта физически невозможно без
  точечного изменения DI/domain/data (например, если провайдер жёстко
  завязан на конкретный виджет `DiscoverDetailsPage`, а не на абстракцию),
  такое изменение выносится отдельным пунктом file map (§4) и отдельно
  подтверждается до кода — оно не считается частью базового scope этого
  slice по умолчанию.

## 2. Архитектурная поправка: без преждевременного `sealed`

`DetailsRenderer` **не фиксируется** как Dart `sealed`-интерфейс.
`sealed` в Dart ограничивает реализации той же библиотекой — это
помешало бы физически разнести четыре будущих renderer'а
(`ObjectOfferDetailsRenderer`, `RouteDetailsRenderer`,
`ScenarioDetailsRenderer`, `CollectionDetailsRenderer`) по отдельным
файлам/библиотекам, как того требует §9 родительского документа
(«per-type или grouped family adapters», разные renderer'ы — разная
физическая структура).

Вместо этого фиксируется:

- **Presentation renderer registry** — закрытый на уровне known renderer
  families список (те же четыре семьи из §3 родительского документа),
  которым владеет `DetailsHost`. Этот registry отвечает **только** за
  «дать renderer family (`event`/`route`/`scenario`/`collection`-класс
  семьи) → получить виджет `DetailsRenderer`». Он **не решает**, к какому
  `objectType` принадлежит конкретный объект, и не подтверждает это —
  эта ответственность (парсинг URI, поиск и проверка фактического типа
  через typed lookup) закреплена отдельно за
  `DetailsLookupRegistry`/`ResolveDetailsUseCase`
  (`DTL-LINK-01`, application-layer). Presentation registry получает уже
  резолвленную и проверенную typed projection и просто выбирает виджет —
  он не является data authority ни в каком смысле (см. также
  `DISCOVER_DETAILS_SYSTEM_SPEC.md` §11: три разделённые ответственности
  router/application resolver/presentation registry). В этом slice
  (`DTL-FND-01`) резолвер ещё не существует — единственный потребитель
  registry — compatibility renderer, подключаемый напрямую для
  Event/Activity/Place/Route, без резолюции через будущий `DTL-LINK-01`.
- **Расширяемый typed Dart-контракт** для самого `DetailsRenderer` —
  конкретная конструкция (`abstract interface class`, mixin-based
  contract, или что-то ещё) не фиксируется этим документом.

`sealed` остаётся допустимым инструментом там, где он уместен —
например, для typed read-model union внутри одной renderer family
(§9 родительского документа), но не для самого renderer-интерфейса.

Точный выбор конструкции подтверждается **file map и analyzer spike до
реализации** — то есть до первой строки production-кода этого slice
должен существовать короткий technical spike (не подлежащий отдельному
approval-циклу, но подлежащий фиксации в PR-описании), показывающий,
что выбранная конструкция действительно позволяет:
(a) закрытый registry family↔renderer;
(b) физически раздельные файлы для будущих `DTL-RTE-01`/`DTL-CLG-01`/
`DTL-SCN-01`, не создающие циклических импортов внутри `features/discover`.

## 3. Compatibility renderer — что именно сохраняется

Compatibility renderer оборачивает существующее содержимое
`discover_details_page.dart` без переписывания его внутренней логики:

- `_DetailsHero`, `_SummaryCard`, `_PublishedRouteCard` (условно, как
  сейчас — по `item.isPublishedRoute`), `_DetailsActionHub`,
  `_OrganizerCard`, `_InfoGrid`, `_HighlightsCard`, `_LocationCard`,
  `_DetailsBottomBar` — весь этот набор перемещается **как есть** под
  `DetailsShell`, не переписывается по новой секционной модели §5
  родительского документа.
- Такое поведение осознанно: полная секционная модель Object/Offer —
  предмет `DTL-OBJ-01`, не этого slice. `DTL-FND-01` доказывает, что
  shell/renderer-абстракция физически работает на реальном, а не
  гипотетическом потребителе, и не более того.
- Route внутри compatibility renderer остаётся в сегодняшнем
  промежуточном виде (migration debt, зафиксированный §6 родительского
  документа) — этот slice не трогает его форму, только переносит в новую
  оболочку.

## 4. Предлагаемый file map

Ниже — план, не разрешение на код (см. Approval gates).

| Файл | Тип изменения | Назначение |
|---|---|---|
| `apps/mobile/lib/features/discover/presentation/shell/details_shell.dart` | новый | `DetailsShell` — app bar, hero-слот, sticky action container, loading/error/not-found по §12 родительского документа |
| `apps/mobile/lib/features/discover/presentation/shell/details_renderer.dart` | новый | typed `DetailsRenderer` contract + closed renderer-family registry (§2) |
| `apps/mobile/lib/features/discover/presentation/shell/compatibility_object_renderer.dart` | новый | Compatibility renderer (§3), потребляет существующие приватные виджеты `discover_details_page.dart` — при необходимости их публичный экспорт из того же файла, без выноса в отдельный слой |
| `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart` | изменён | тело `build()` делегирует в `DetailsShell` + `CompatibilityObjectRenderer`; публичный API страницы (конструктор, маршрут, параметры) не меняется |
| `apps/mobile/test/features/discover/presentation/details_shell_test.dart` | новый | контрактные тесты shell (loading/error/not-found рендерится независимо от наличия координаты/даты/цены) |
| `apps/mobile/test/features/discover/presentation/discover_details_parity_test.dart` | новый | тесты поведенческого паритета: то же содержимое, те же CTA, та же навигация, та же аналитика до/после |
| `apps/mobile/test/features/discover/presentation/details_shell_accessibility_test.dart` | новый | 360dp/150% text scale, sticky action container overflow |

Любое отклонение от этого списка при фактической реализации (например,
если compatibility renderer потребует точечного экспорта приватного
виджета, упомянутого в §1.2 как «исключение») фиксируется в PR-описании
явно, не молча.

## 5. Acceptance criteria

- **FND-AC-01.** `DetailsShell` реализован как presentation-only
  оболочка: не имеет обязательных полей координаты, даты, цены,
  расписания или CTA в своём публичном API — их наличие полностью
  определяется тем, что renderer передаёт в слоты.
- **FND-AC-02.** Определён typed `DetailsRenderer` contract,
  допускающий отдельные реализации в разных файлах/библиотеках (не
  `sealed` на уровне самого интерфейса; см. §2).
- **FND-AC-03.** Текущий Event/Activity/Place Details подключён к
  `DetailsShell` через compatibility renderer.
- **FND-AC-04.** Текущий Route продолжает работать в прежнем
  промежуточном виде внутри compatibility renderer; полноценное
  выделение остаётся `DTL-RTE-01` и не начинается здесь.
- **FND-AC-05.** Поведение, навигация, favorite/share/report, Add to
  Scenario, loading/error и CTA текущего Details не изменились —
  подтверждено тестами паритета (FND-AC-08), не только визуальным
  осмотром.
- **FND-AC-06.** Не добавлены новые read-модели, publication adapters,
  маршруты или DI registrations, кроме точечного исключения из §1.2,
  явно поднятого на отдельное подтверждение до кода.
- **FND-AC-07.** Нет невызванных production-заглушек и speculative dead
  code: если `DetailsRenderer` или `DetailsShell` предоставляют API,
  которым в этом slice некому воспользоваться (например, слот для
  renderer family, для которой ещё нет реализации), такой API либо не
  добавляется, либо явно помечается как заготовка под конкретный будущий
  `DTL-*` в комментарии, а не существует «на всякий случай».
- **FND-AC-08.** Добавлены widget/contract-тесты визуально значимых
  состояний, включая 360dp/150% text scale и sticky action container
  overflow (см. file map, §4).
- **FND-AC-09.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate и `git diff --check` — зелёные, без новых нарушений
  относительно текущего allowlist.
- **FND-AC-10.** Rollback (см. §6) описан и проверяем: удаление
  foundation-файлов и возврат `discover_details_page.dart` к прежней
  композиции восстанавливает исходное поведение без следов в persisted
  data или маршрутах.

## 6. Rollback

1. Вернуть `discover_details_page.dart` к композиции без `DetailsShell`/
   `CompatibilityObjectRenderer` (прямой revert коммита, затрагивающего
   этот файл).
2. Удалить три новых файла shell/renderer/compatibility из
   `features/discover/presentation/shell/`.
3. Удалить три новых тестовых файла.
4. Маршруты (`route_names.dart`, `app_router.dart`) не участвовали в
   изменении — откатывать нечего.
5. Persisted data (Create drafts, Favorites, Visit History и т.д.) не
   затронуты этим slice ни в одном сценарии — rollback не требует
   миграции данных.

## 7. Test plan (детализация FND-AC-08)

- **Контракт shell**: `DetailsShell` рендерит loading/error/not-found
  состояния (§12 родительского документа: `available |
  temporarilyUnavailable | unavailable | notFound`) независимо от того,
  какой renderer подключён — тест собирает shell с renderer-заглушкой,
  не с реальным compatibility renderer, чтобы доказать независимость
  shell от формы данных.
- **Паритет**: для одного и того же `DiscoverItemEntity` (event, activity,
  place, published route — 4 фикстуры) сравнивается дерево виджетов/
  список видимых CTA/список аналитических событий до и после перехода
  на shell. Тест обязан провалиться при любом расхождении, а не только
  при явном крэше.
- **Accessibility**: существующий паттерн 360×800 при масштабе текста
  1.5×, уже применяемый в репозитории (например, RTE-05/RTE-06,
  Route/Session accessibility-тесты) — воспроизводится для
  `DetailsShell`, отдельно проверяя, что sticky action container не
  обрезает и не перекрывает primary CTA при максимальном тексте.

## 8. Открытые вопросы (не блокируют approval этого документа, фиксируются для реализации)

1. Публичный экспорт приватных виджетов `discover_details_page.dart»
   (`_SummaryCard` и т.д.) для использования из
   `compatibility_object_renderer.dart` — остаться в том же файле одним
   large-file компромиссом или сделать точечный export — решается
   analyzer spike (§2), не этим документом.
2. Итог analyzer spike (§2) — выбранная Dart-конструкция для
   `DetailsRenderer` — фиксируется в PR-описании реализации, не
   требует отдельного review этого текста.
