# RECHARGE — DTL-CLG-01: Collection Details Shell Migration Slice Spec

Версия: v0.3 (2026-08-24) — уточнение после третьего раунда review.
Статус: **Draft for review — Proposed implementation slice.
Implementation not authorized.**

Runtime effect (этого документа): **none**.

## Что изменилось относительно v0.2

«Чистая shell-миграция» означает буквально текущий порядок
(title/description → chips area/budget/itemCount/publisher →
**мини-карта → сгруппированные секции**, как сегодня в
`_CollectionDetailsBody`, проверено прямым чтением кода), а не
идеализированный порядок §8 родительского документа (editorial hero →
description → publisher → area/budget → sections → item cards → curator
notes → highlights → mini-map), который описывает целевую композицию, не
обязательную для этого узкого slice. Реордер под §8 и добавление
editorial hero — предмет отдельного будущего visual-slice, не этого.
Добавлены AC против фиктивного CTA и пустого sticky-контейнера (§3).

## Что изменилось относительно v0.1

1. **Unavailable-item policy исправлена на Approved-поведение.** Ранее
   этот документ (и родительский `DISCOVER_DETAILS_SYSTEM_SPEC.md`)
   ошибочно требовали показывать недоступный пункт с явным статусом.
   Approved `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md` (line 919) требует
   обратного: пункт, ставший `unavailable`, **публично скрывается** из
   списка и мини-карты без ошибки; предупреждение и агрегированный
   сигнал видит только автор в своём редакторе. Родительский документ
   исправлен отдельно; здесь — согласованная формулировка.
2. **Visual polish исключён из scope.** Вместо открытого «уточняется при
   реализации» — этот slice **сужен до чистой shell-миграции**:
   структура/секции/DetailsShell, без задачи довести визуал до уровня
   Place/Route/Find People. Визуальная полировка — предмет отдельного
   будущего slice с собственным file map по конкретным design-system
   компонентам, не додумывается здесь.

## Approval gates

Заблокировано до:

1. `DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем продукта
   (включая исправленную unavailable-item policy).
2. `DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` реализован и принят.
3. Сам этот документ отдельно получает статус `Approved`.

## Связанные документы

- `DISCOVER_DETAILS_SYSTEM_SPEC.md` §8 (Collection Details, исправлено).
- `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md` v1.0 (Approved), line 919
  (unavailable-item policy — нормативный источник, не этот документ).
- Текущий код: `collection_details_page.dart`,
  `collection_details_mini_map.dart`, `published_collection_discovery_entity.dart`,
  `collection_discover_providers.dart`, `collection_discover_section.dart`.

## 1. Scope

### 1.1 В scope — чистая shell-миграция, без визуальной полировки

1. `CollectionDetailsPage` подключается к `DetailsShell` из
   `DTL-FND-01`: тот же app bar/loading/error/not-found/sticky action
   паттерн.
2. `CollectionDetailsRenderer` реализует `DetailsRenderer` contract,
   регистрируется под `objectType: collection`.
3. **Порядок секций — сегодняшний, без изменений**: title/description →
   chips (area/budget/itemCount/publisher) → мини-карта → сгруппированные
   секции с item-карточками. Это НЕ порядок §8 родительского документа
   (editorial hero → description → publisher → area/budget → sections →
   item cards → curator notes → highlights → mini-map) — тот порядок
   целевой, не обязательный для этого slice. Визуальное исполнение
   (`ListView`+`Chip`) тоже не меняется — меняется только то, что весь
   этот вывод оборачивается в `DetailsShell` вместо bare `Scaffold`.
4. **Unavailable-item policy** — воспроизводит Approved-поведение:
   недоступный пункт **не отображается** публично ни в списке, ни на
   мини-карте; никакого public-facing статуса/бейджа не добавляется.
   Автор видит предупреждение только в своём Collection-редакторе
   (`features/create/`), это поведение не меняется этим slice.
5. Маршрут `/collection/details/:collectionId` **не меняется**.
6. Переход во вложенный объект продолжает работать через сегодняшний
   способ адресации.

### 1.2 Вне scope

- Визуальная полировка (карточки/радиусы/типографика под design_system
  токены) — отдельный будущий slice, не начинается здесь.
- Изменение `PublishedCollectionDiscoveryEntity`,
  `PublishedCollectionSectionRef`, `PublishedCollectionItemRef`,
  `CollectionPublicationDiscoveryAdapter`.
- Изменение параллельной секции «Guides»
  (`CollectionDiscoverSection`/`collection_discover_section.dart`).
- Унифицированная лента/ranking Collection наравне с point-object.
- Известное ограничение "instant-remove не исчезает из списка визуально
  до перезагрузки draft" — не Details-баг, не в scope.
- Новый `CatalogObjectRef`-маршрут (`DTL-LINK-01`).

## 2. Предлагаемый file map

| Файл | Тип | Назначение |
|---|---|---|
| `apps/mobile/lib/features/discover/presentation/renderers/collection_details_renderer.dart` | новый | Реализация `DetailsRenderer`, потребляет существующие `PublishedCollectionDiscoveryEntity`/`collectionResolvedItemsProvider` без изменений их формы |
| `apps/mobile/lib/features/discover/presentation/pages/collection_details_page.dart` | изменён | Тело `build()` делегирует в `DetailsShell` + `CollectionDetailsRenderer`; публичный конструктор/маршрут не меняются |
| `apps/mobile/lib/features/discover/presentation/widgets/collection_details_mini_map.dart` | не меняется | Переиспользуется как есть |
| тесты паритета | новые | Тот же набор секций/контента до и после |
| тест unavailable-item hide | новый | Недоступный пункт не появляется в public-рендере ни в списке, ни на мини-карте |

## 3. Acceptance criteria

- **CLG-D-AC-01.** `CollectionDetailsPage` использует `DetailsShell`
  вместо собственного bare `Scaffold`+`ListView`.
- **CLG-D-AC-02.** Порядок секций и их визуальное исполнение идентичны
  сегодняшнему `_CollectionDetailsBody` (title/description → chips →
  мини-карта → сгруппированные секции) — **не** переставлены под
  идеализированный порядок §8 родительского документа.
- **CLG-D-AC-03.** `PublishedCollectionDiscoveryEntity` и её adapter не
  изменены.
- **CLG-D-AC-04.** `CollectionDetailsMiniMap` переиспользован без
  изменений поведения.
- **CLG-D-AC-05.** Unavailable-item policy соответствует Approved
  `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md:919` — пункт **скрывается**
  публично без ошибки, не показывается со статусом. Тест явно проверяет
  отсутствие пункта в public-рендере, не наличие бейджа.
- **CLG-D-AC-06.** Визуальный вывод секций (карточки/типографика)
  не изменён относительно сегодняшнего `_CollectionDetailsBody` —
  изменилась только оболочка (`DetailsShell`), не визуальный стиль
  контента.
- **CLG-D-AC-07.** Маршрут `/collection/details/:collectionId` не
  изменён.
- **CLG-D-AC-08.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **CLG-D-AC-09.** Rollback возвращает `CollectionDetailsPage` к
  прежней bare-реализации без потери функциональности.
- **CLG-D-AC-10.** Collection не получает выдуманный primary CTA —
  `DetailsShell`'s sticky action container не рендерится вообще, если
  Collection не предоставляет ни одного action (у Collection сегодня
  нет единого «booking»-подобного primary action, в отличие от
  Object/Offer/Route); пустой sticky-контейнер с нулевой высотой не
  занимает место в layout.

## 4. Rollback

1. Вернуть `collection_details_page.dart` к прежней прямой композиции
   без `DetailsShell`/`CollectionDetailsRenderer`.
2. Удалить `collection_details_renderer.dart`.
3. `collection_details_mini_map.dart`, read-model и adapter не
   затрагивались — откатывать нечего.
4. Маршрут, persisted data не затронуты.

## 5. Открытые вопросы

Нет открытых вопросов, блокирующих реализацию — visual polish явно
вынесен из scope (§1.2), unavailable-item policy зафиксирована точно по
Approved-источнику (§1.1.4).
