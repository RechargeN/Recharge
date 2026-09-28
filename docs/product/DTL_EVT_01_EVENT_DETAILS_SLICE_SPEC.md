# RECHARGE — DTL-EVT-01: Event Details Visual Slice Spec

Версия: v0.3.1 (2026-08-29) — точечная правка (§4.1: `_toFavorite`
`startsAtUtc` явно привязан к резолвленной occurrence) по итогам
финального review перед Approval; содержательно не отличается от v0.3.
Статус: **Approved** (утверждён владельцем продукта 2026-08-29, после
двух раундов review v0.1→v0.2→v0.3 и финального прохода перед этой
пометкой). Runtime effect (этого документа): **none** — само утверждение
не меняет код; реализация авторизована и начинается отдельным
implementation-заходом под собственные analyzer/test/boundary/diff gates,
по file map §3.

## Execution Log

Стадии зафиксированы честно, включая то, что ещё не закрыто — не «Done»,
пока не закрыто на самом деле.

1. **Draft (v0.1)**, 2026-08-29 — первый черновик по мастер-спеке
   Recharge_Details_Event_Master_Spec.docx.
2. **Review round 1 → v0.2**, 2026-08-29 — 6 замечаний (About/ProgramItem
   словарь, typed read-модель вместо `DiscoverItemEntity`, chrome в hero,
   verified badge, пиксельный эталон вне репозитория, токены не в
   `design_system`) — все проверены по коду, все приняты.
3. **Review round 2 → v0.3**, 2026-08-29 — 7 новых блокеров
   (`PublisherVerificationDisplayState`, occurrence-модель,
   `ProgramItem.kind` не Candidate, нормативный список полей, честная
   Primary CTA, честные визуальные состояния, dp вместо px) + явное
   продуктовое решение по §4 (side-effects). Финальный review-проход
   нашёл и закрыл ещё один пробел (`_toFavorite.startsAtUtc`) → v0.3.1.
4. **Approved**, 2026-08-29 — владелец продукта утвердил v0.3.1.
5. **Doing — реализация**, 2026-08-29/30:
   - Domain-слой: `PublishedEventProgramItem`/`EventProgramItemKind`,
     `EventOccurrence`/`EventScheduleMode`/`EventOccurrenceStatus`,
     `PublisherVerificationDisplayState`, `PublishedEventDiscoveryEntity`
     — 7 unit-тестов, `flutter analyze` чист.
   - Data-слой: `PublishedEventDiscoveryPort`,
     `PublishedEventDiscoveryLocalDataSource` (mock-first),
     `EventDetailsLookup`, регистрация в `service_locator.dart`/
     `details_resolution_providers.dart` — 5 unit-тестов.
   - Presentation: `ObjectOfferDetailsRenderer.event` + все карточки в
     одном файле (по образцу `.rental`), `EventDetailsPage`-координатор,
     `app_router.dart` — 17 виджет-тестов, включая 360dp/150%
     (EVT-D-AC-11), нашедших и закрывших 3 реальных overflow.
   - Typed Scenario-intake: `DiscoverScenarioIntakeAdapter.toEventIntent`
     + `launchScenarioObjectIntakeForEvent` — меньшим объёмом, чем
     планировал file map (см. «Реализация — отклонения» ниже).
   - Design tokens — новая группа в `RechargeTheme`.
   - Boundary gate: найдено 8 нарушений при исходном размещении
     `EventDetailsPage` в `features/discover/`; исправлено переносом в
     `app/presentation/` — 0 violations, бюджет 71/71 не тронут.
6. **Concurrent drift — не reconciled**, обнаружено при подготовке этого
   Execution Log (не в рамках этой implementation-сессии): три файла
   (`event_details_page.dart`, `published_event_discovery_local_
   datasource.dart`, `event_occurrence.dart`) и рендерер изменены —
   добавлены реальный `.ics`-экспорт в календарь (`_onAddToCalendar`) и
   переход в профиль организатора (`_onOrganizerTap`). Оба напрямую
   расходятся с Approved-текстом этого документа: §0.4 «Calendar
   полностью отсутствует в v1» и §4.1 (ровно пять действий, без
   organizer-профиля). Решение владельца продукта: **оставить код как
   есть**, расхождение со спекой зафиксировать отдельно, не откатывать.
   Найдена и не исправлена сопутствующая регрессия: тест «a long title/
   venue/organizer name renders without overflow» (EVT-D-AC-11) заново
   падает (~115px overflow), вероятно из-за добавленной кнопки календаря
   в Program-карточке.

### Текущая стадия: **Doing**, не Review и не Done

Открыто до Review:

- Реконсилировать код с текстом спеки (Calendar/Organizer) — либо новая
  ревизия документа (v0.4) с этими двумя действиями в scope, либо откат
  кода до Approved-текста. Не решено.
- Починить регрессию overflow, найденную выше.
- `discover_details_parity_test.dart` не грузится из-за pre-existing
  поломки в `features/create/` (`create_repository_impl.dart` и др.),
  предшествующей этой сессии и не связанной с DTL-EVT-01 — блокирует
  EVT-D-AC-01 (Place-фикстура).
- Golden-тест на точной геометрии §7 не написан (нужен реальный
  screenshot-раннер, не только `takeException`).

## Реализация — фактические отклонения от плана

Зафиксировано по ходу implementation-захода (по прецеденту
`DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md`), не молча:

1. **`EventDetailsPage` живёт в `app/presentation/`, не в
   `features/discover/presentation/pages/`**, как предполагал file map
   §3. `tools/scripts/check_boundaries.dart` дал 8 нарушений
   (`cross_feature_import` на `features/auth`/`features/favorites`,
   `feature_to_app_di_or_app_presentation` на `app/di`/`app/presentation`)
   при исходном расположении — Rental/Collection никогда не задевали это
   правило именно потому, что не имеют favorites/auth/scenario-intake
   wiring. Exception budget уже полный (71/71,
   `tools/scripts/boundary-exceptions.json`) — по прецеденту `CLG-CRT-01`
   (перенос провайдеров в `app/application/` по той же причине) файл
   перенесён, не добавлено новое исключение. `check_boundaries.dart`
   зелёный, 0 violations, бюджет не тронут.
2. **Typed Scenario-intake mapping меньше по объёму, чем планировалось.**
   `scenario_intake_selection_controller.dart`/`_state.dart` не
   изменены вообще — они обслуживают только multi-select tray
   (Search/Map), не single-item add из Details. Обязательство
   («не конвертировать Event в `DiscoverItemEntity`») закрыто двумя
   точечными добавлениями: `DiscoverScenarioIntakeAdapter.toEventIntent`
   (новый метод) и `launchScenarioObjectIntakeForEvent` (новая функция
   рядом с существующим `launchScenarioObjectIntake`, с общим
   вынесенным хвостом `_presentScenarioObjectIntakeSheet`). Планировавшийся
   новый тип `ScenarioIntakeCandidate` не создан — это имя уже занято
   существующим внутренним типом intake-потока
   (`scenario_item_draft.dart`); переиспользован тот же существующий
   тип, не переопределён.
3. **Metrics-контейнер и два `Row` (Location/Organizer) используют
   `IntrinsicHeight`/`Flexible`, не фиксированную `SizedBox`/
   `mainAxisSize.min`**, как в первом черновике реализации — 360dp/150%
   accessibility-тест (EVT-D-AC-11) нашёл три реальных overflow до того,
   как они попали в review, тем же способом, что уже документирован для
   Activity Create.

## Что изменилось относительно v0.2

1. **§4 side-effects разрешён.** Владелец продукта отклонил вариант 1
   («принять тот же scope-пробел, что Rental/Collection») — «нельзя
   сознательно лишать Event уже работающих действий только потому, что
   Rental пока неполон». Вместо этого — bounded **Event interaction
   coordinator**, сохраняющий Save/Unsave, Share, Add to Scenario, Open
   map, analytics; явное осознанное удаление legacy-блока `Plan this
   recharge`/`Find similar`/`Create similar` (не входит в канонический
   §5.1 `DISCOVER_DETAILS_SYSTEM_SPEC.md`); Visit History не переносится,
   т.к. и сегодня показывается только Place. См. §4.
2. **Verified badge перемоделирован.** `publisherVerifiedAtUtc:
   DateTime?` заменён на `PublisherVerificationDisplayState { none,
   verifiedCreator, verifiedPage }` — timestamp не различает
   revoked/expired и смешивает Creator/Page. См. §2.3.
3. **`ProgramItem` → `PublishedEventProgramItem`**, `kind` — больше не
   Candidate: используется Accepted-словарь `EVENT_CLASSIFICATION_SPEC.md`
   §16 (`act | session | screening | activity | break`). Явно
   зафиксировано, что это read projection, не второй канонический
   aggregate type. См. §2.1.
4. **Occurrence-модель вместо голой пары дат.** `startsAtUtc`/`endsAtUtc`
   заменены на `scheduleMode` (`oneTime`/`multiDate`/`recurring`) +
   `occurrences: List<EventOccurrence>` + `displayOccurrenceId`, по
   `EVENT_CLASSIFICATION_SPEC.md` §8/§17.4. См. §2.2.
5. **Список полей стал нормативным**, не «представительным» — добавлены
   `subtitle`/`city`/`category`/`subcategory`/`marketCityId`/`distanceKm`,
   требуемые существующим `_toFavorite` (`discover_details_page.dart:
   472-486`). См. §2.4.
6. **Primary CTA специфицирована по §10 `DISCOVER_DETAILS_SYSTEM_SPEC.md`**,
   не единым фиктивным «заявка отправлена»: `isFree` → Join-семантика
   (внутреннее honest-acknowledgement, как сегодня); иначе — Book/External
   booking семантика, обязательный `externalBookingUrl`, реальный переход
   через уже существующий `url_launcher` (`rental_details_page.dart:
   27-49`), скрытие CTA при отсутствии URL — «нет `externalBookingUrl` →
   скрыть, не заглушка» (`DISCOVER_DETAILS_SYSTEM_SPEC.md:412`, дословно).
   См. §1.1.
7. **Визуальные честные состояния закрыты**: Calendar полностью убран из
   v1 (не полумера); participants unknown — «—» + accessibility label;
   hero — реальный `PageView` по cover+gallery с де-дупликацией cover,
   счётчик только при `total > 1`.
8. **Единицы измерения — dp, не px**; время конвертируется через
   существующий `TimezoneRepository.toLocal()`, не `DateTime.toLocal()`
   (устройство ≠ таймзона события); русский текст даты — маленький
   RU-only форматтер, тем же способом, что весь остальной копирайт этого
   экрана уже хардкодит русский текст — явно назван, не выдаётся за
   locale-aware систему.

## Связанные документы (дополнено)

- `EVENT_CLASSIFICATION_SPEC.md` §8 (Расписание/scheduleMode), §16
  (Program Items), §17.4 (Occurrence) — Accepted, 2026-08-04.
- `IDENTITY_PUBLISHER_SLICE_SPEC.md:278` (`verificationStatus`),
  `:642` («separate Creator/page verification badges»).
- `features/discover/domain/repositories/timezone_repository.dart` —
  существующий `TimezoneRepository.toLocal(DateTime, String) →
  LocalDateTimeValue`.
- `features/discover/presentation/pages/rental_details_page.dart:27-49` —
  существующий `url_launcher`-паттерн для external CTA.
- `app/presentation/scenario_object_intake_sheet.dart`,
  `features/discover/application/controllers/
  scenario_intake_selection_controller.dart` — сегодня типизированы на
  `List<DiscoverItemEntity>` напрямую (не generic/interface).
- `features/create/domain/entities/event_draft_data.dart:263-479` —
  существующий `externalBookingUrl: String?` на стороне authoring.

*(Остальные связанные документы из v0.2 не изменились — см. предыдущую
версию в истории git.)*

## 0. Явные адаптации и границы честности

Пункты 0.1–0.3, 0.5–0.6 из v0.2 не изменились. Обновлены:

**0.4 — «Добавить в календарь».** Не полумера — полностью отсутствует в
v1: ни активной CTA, ни неинтерактивного лейбла. Реальная calendar-
интеграция — отдельный будущий slice с явным решением о новой
зависимости.

**0.7 — Primary CTA честность (новое).** Мок-first не означает
«разрешено имитировать успех». `isFree`-событие получает internal
Join-подтверждение (аналог сегодняшнего «заявка отправлена» — оно не
заявляет об оплате или подтверждённом месте, только что запрос отправлен,
что соответствует статусу `internal` execution для `Join` в
`DISCOVER_DETAILS_SYSTEM_SPEC.md:408`). Платное событие без
`externalBookingUrl` не получает никакого подтверждающего UI вообще —
CTA скрывается.

## 1. Scope

### 1.1 В scope (обновлено)

Пункты 1–3, 5, 9–15 из v0.2 актуальны с учётом переопределений ниже.
Изменённые/новые пункты:

4. **Metrics honesty** — без изменений по сути, но `participantsCount ==
   null` теперь явно специфицирует accessibility: `Semantics(label:
   'Количество участников неизвестно')` поверх визуального «—», не
   просто визуальный дефис без описания для screen reader.
6. **Verified badge** — рендерится по `PublisherVerificationDisplayState
   != none` (см. §2.3), не по nullable timestamp.
7. **Program card** — источник теперь `PublishedEventProgramItem` (§2.1);
   Program Item никогда не рендерит собственный CTA/booking-состояние —
   он read-only отображение программы, не второй aggregate с
   собственным lifecycle (см. §2.1 инвариант). «Добавить в календарь» —
   удалён из v1 целиком (§0.4).
11. **Photo counter / hero** — hero строится как `PageView` над
    `[coverImageUrl, ...galleryImageUrls]`; если `coverImageUrl` уже
    присутствует в `galleryImageUrls` (по значению URL), не дублируется
    как отдельная первая страница. Счётчик `current/total` рендерится
    только при итоговом `total > 1` — при одной странице не показывается
    вовсе (не «1/1»).
14. **Primary CTA (переопределяет п.14 v0.2)** — см. §0.7 и «Что
    изменилось» п.6: `isFree` → internal Join-acknowledgement; иначе →
    `externalBookingUrl` через `url_launcher` по образцу
    `rental_details_page.dart:27-49`, CTA скрыт при отсутствии/
    невалидности URL.
16. **Event interaction coordinator (новое)** — небольшой bounded
    координатор в `EventDetailsPage`/сопутствующем файле, реализующий
    ровно пять действий §4, ничего сверх них.
17. **Typed Scenario-intake mapping (новое)** — см. §4.3.

### 1.2 Вне scope

Как в v0.2, плюс: расширение `ScenarioIntakeSupportIssue`/intake UI
сверх минимального типизированного адаптера; любая новая capability или
CTA, не перечисленная в §5.1 `DISCOVER_DETAILS_SYSTEM_SPEC.md` для
Event; реальный `admissionWindows`/`recurrenceRule` UI (только
хранение полей в read-модели, без построителя расписания).

## 2. Domain-дизайн (переписан)

### 2.1 — `PublishedEventProgramItem`

Переименован из `ProgramItem` (v0.2) — имя подчёркивает, что это
Discover read projection одного элемента программы, не второй
канонический aggregate рядом с Event. Новый файл `features/discover/
domain/entities/published_event_program_item.dart`:

```
class PublishedEventProgramItem {
  final String id;              // stable, ULID
  final String title;
  final EventProgramItemKind kind;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? description;
}

enum EventProgramItemKind { act, session, screening, activity, break_ }
```

Значения `kind` — прямая транскрипция Accepted-словаря
`EVENT_CLASSIFICATION_SPEC.md:943` (`act | session | screening |
activity | break`; `break_` — обход зарезервированного слова Dart,
`toWireValue()`/`fromWireValue()` мапят на строку `break` на границе).

**Инвариант (нормативный, не предложение):** `PublishedEventProgramItem`
никогда не содержит независимую visibility/access/inventory/pricing или
booking lifecycle — источник (`EVENT_CLASSIFICATION_SPEC.md:958-960,
1071`) явно требует, что элемент с такими независимыми свойствами
становится отдельным child Event с собственным `PublisherRef` и
`parentEventRef`, не более богатым Program Item. Read-модель этого slice
физически не имеет полей, которые позволили бы это нарушить (нет цены,
нет capacity, нет CTA-поля на самом `PublishedEventProgramItem`).

Timezone — на родительской `PublishedEventDiscoveryEntity.timezoneId`,
не здесь.

### 2.2 — Occurrence-модель

По `EVENT_CLASSIFICATION_SPEC.md` §8 (канонический `scheduleMode`) и
§17.4 (Occurrence lifecycle):

```
enum EventScheduleMode { oneTime, multiDate, recurring }
enum EventOccurrenceStatus { scheduled, cancelled }

class EventOccurrence {
  final String id;               // stable — Booking/CTA ссылаются на него
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final EventOccurrenceStatus status;
}
```

Новый файл `features/discover/domain/entities/event_occurrence.dart`.
`PublishedEventDiscoveryEntity` хранит `scheduleMode`, `occurrences:
List<EventOccurrence>` (минимум одна — Event без подтверждённой
occurrence не публикуется, `EVENT_CLASSIFICATION_SPEC.md:70,442`) и
`displayOccurrenceId: String` — какую occurrence показывает Header/
Metrics/CTA прямо сейчас (обычно ближайшую будущую `scheduled`; точное
правило выбора — деталь реализации `EventDetailsPage`, не домена).
Header/CTA **обязаны** резолвить occurrence по `displayOccurrenceId` из
`occurrences`, не читать голую пару полей — так multi-date/recurring
Event не может тихо потерять свою identity occurrence
(`EVENT_CLASSIFICATION_SPEC.md:1066`: «Multi-date/recurring Booking
всегда ссылается на occurrence ID»).

### 2.3 — `PublisherVerificationDisplayState`

Новый enum (полноценный Dart enum, по прецеденту `DurationConfidence`/
`AvailabilityKind`, объявленных прямо в domain-слое Discover — не
wire-safe строка, т.к. это собственный тип Discover, не транскрипция
чужого enum через границу):

```
enum PublisherVerificationDisplayState { none, verifiedCreator, verifiedPage }
```

`IDENTITY_PUBLISHER_SLICE_SPEC.md:278` определяет
`verificationStatus: unverified | pending | verified | rejected |
revoked` — пятизначный, с явным `revoked`, который `DateTime?` не мог
различить с «никогда не был verified». Адаптер на этапе публикации
схлопывает: `verified` + Creator-публикатор → `verifiedCreator`;
`verified` + Page-публикатор → `verifiedPage`; всё остальное
(`unverified`/`pending`/`rejected`/`revoked`) → `none`. Discover
по-прежнему не импортирует Identity-domain тип напрямую — только
результат схлопывания, тем же приёмом, что уже применяется к
`PublisherType` (Rental: строка `'user'/'page'`, не импорт enum). Badge
рендерится только при значении `!= none` (`IDENTITY_PUBLISHER_SLICE_
SPEC.md:642` — «separate Creator/page verification badges», две разные
визуальные пометки, не одна общая галочка).

### 2.4 — `PublishedEventDiscoveryEntity` (нормативный список полей)

Список ниже — нормативный для Approval этого документа (не
«представительный», как в v0.2); точные Dart-типы (nullable/required)
финализируются в review кода на этапе реализации, тем же принципом, что
`DTL_RTE_01` применяет к `PublishedRouteDiscoveryEntity`.

| Поле | Тип | Зачем обязательно |
|---|---|---|
| `eventId` | `String` | id |
| `publisherId`, `publisherType` | `String` | `'user' \| 'page'`, wire-safe |
| `publisherName`, `publisherHandle` | `String` | Organizer card |
| `publisherVerification` | `PublisherVerificationDisplayState` | §2.3 |
| `title`, `subtitle` | `String` | Header; `subtitle` обязателен — того требует `_toFavorite` (`discover_details_page.dart:474`) |
| `fullDescription` | `String` | About |
| `category`, `subcategory` | `String` | `_toFavorite` (`:477`); taxonomy label |
| `city`, `marketCityId` | `String` | `_toFavorite` (`:476`); market scoping |
| `coverImageUrl`, `galleryImageUrls` | `String`, `List<String>` | Hero `PageView` (§1.1 п.11) |
| `galleryAltText` | `Map<String,String>` | Accessibility, ключ — URL |
| `venueName`, `addressLine`, `latitude`, `longitude` | — | Location card |
| `distanceKm` | `double` | `_toFavorite` (`:479`) — без него Save для Event падает на runtime |
| `priceAmount`, `isFree`, `currencyCode` | — | Metrics + CTA-ветвление (§0.7) |
| `externalBookingUrl` | `String?` | Primary CTA (§0.7) |
| `participantsCount`, `capacity` | `int?` | nullable = unknown |
| `durationMinutes`, `durationConfidence` | `int?`, `DurationConfidence` | переиспользуется существующий enum |
| `scheduleMode`, `occurrences`, `displayOccurrenceId` | §2.2 | occurrence-модель |
| `timezoneId` | `String` | §2.2 + форматирование даты через `TimezoneRepository` |
| `programItems` | `List<PublishedEventProgramItem>` | §2.1, default `const []` |
| `publishedAtUtc` | `DateTime` | — |

### 2.5 — Почему не расширяется `DiscoverItemEntity`

Без изменений от v0.2 — см. `DISCOVER_DETAILS_SYSTEM_SPEC.md` §9.

## 3. Предлагаемый file map (обновлён)

Не изменившиеся строки из v0.2 (domain/data/router/design_system/
большинство presentation-виджетов) не повторяются — см. предыдущую
версию в истории git. Новые/переопределённые строки:

| Файл | Тип | Назначение |
|---|---|---|
| `domain/entities/published_event_program_item.dart` | новый (заменяет `program_item.dart`) | §2.1 |
| `domain/entities/event_occurrence.dart` | новый | §2.2 |
| `domain/entities/publisher_verification_display_state.dart` | новый | §2.3 (или инлайн в entity-файле, по прецеденту `DurationConfidence`) |
| `domain/entities/published_event_discovery_entity.dart` | новый | §2.4 — нормативный список полей |
| `presentation/pages/event_details_page.dart` | новый | Hosts Event interaction coordinator (§4); PageView hero; occurrence resolution |
| `presentation/widgets/event_program_card.dart` | новый | Рендерит `PublishedEventProgramItem`; без «Добавить в календарь» |
| `presentation/widgets/event_hero.dart` | новый | `PageView`, де-дупликация cover, условный counter |
| `features/discover/domain/entities/scenario_intake_candidate.dart` | новый | §4.3 — минимальная типизированная форма для intake, независимая от `DiscoverItemEntity` |
| `app/presentation/scenario_object_intake_sheet.dart` | изменён | Принимает `List<ScenarioIntakeCandidate>` вместо `List<DiscoverItemEntity>` напрямую |
| `features/discover/application/controllers/scenario_intake_selection_controller.dart` | изменён | Типизация состояния на `ScenarioIntakeCandidate` |
| `features/discover/application/state/scenario_intake_selection_state.dart` | изменён | То же |
| `features/discover/presentation/pages/discover_details_page.dart` | изменён | `_toFavorite`/`_onAddToScenario` продолжают строить `ScenarioIntakeCandidate`/`FavoriteItemEntity` из `DiscoverItemEntity` для Activity/Place — не трогается по поведению, только тип параметра на границе с intake sheet |
| test-файлы на `object_offer_details_renderer_test.dart`, `event_details_page_test.dart` | новые (из v0.2) | + кейсы: occurrence resolution, CTA hide без `externalBookingUrl`, badge `none` при отсутствующей verification, hero-дедупликация |

## 4. Event Interaction Coordinator (было открытым вопросом в v0.2 — разрешено)

Решение владельца продукта: вариант 1 v0.2 («принять тот же
scope-пробел, что Rental/Collection») отклонён. Event сохраняет ровно
то, что работает сегодня — не больше и не меньше.

### 4.1 — Сохраняется

1. **Save/Unsave** — тот же auth-gate, что сегодня
   (`discover_details_page.dart` `_onFavoriteTap` →
   `showAuthGateSheet(...)` при отсутствии аутентификации). Требует
   `FavoriteItemEntity`-совместимых полей на `PublishedEventDiscoveryEntity`
   — см. §2.4. `FavoriteItemEntity.startsAtUtc`
   (`discover_details_page.dart:478`) — единственное поле `_toFavorite`,
   для которого на `PublishedEventDiscoveryEntity` нет прямого
   эквивалента (occurrence-модель заменила голую пару дат, §2.2):
   координатор передаёт `startAtUtc` уже **резолвленной**
   `EventOccurrence` (по `displayOccurrenceId`), не читает
   несуществующее плоское поле.
2. **Share** — canonical Event URL тем же механизмом, что сегодня:
   `RouteNames.discoverDetailsCanonicalFor(CatalogObjectRef(...))` +
   `Clipboard.setData`.
3. **Add to Scenario** — через новый typed mapping, см. §4.3.
4. **Open map** — не имеет собственной data-зависимости сверх
   latitude/longitude, переносится без изменений по сути.
5. **Analytics** — просмотра (`discover_details_viewed`-эквивалент) и
   primary action (`discover_details_cta_clicked`-эквивалент,
   параметризован веткой §0.7).

### 4.2 — Явно и осознанно удаляется

Блок `DetailsActionHub` («Plan this recharge» + grid `Map` / `Add to
Scenario` / `Find similar` / `Create similar` / `Mark as visited`,
`compatibility_object_renderer.dart:568-717`) **не переносится в
Event** целиком:

- `Find similar`, `Create similar` — отсутствуют в каноническом §5.1
  `DISCOVER_DETAILS_SYSTEM_SPEC.md` (Secondary actions для Event:
  «Save, Share, Add to Scenario» — ровно три, не пять) — это legacy-
  композиция, которую §5.1 не требует ни для одного из семи
  `ObjectOfferDetailsRenderer`-типов явно, кроме как в форме generic
  `DetailsActionHub`, который сам не является нормативным контрактом
  (нормативна таблица §5.1, не сегодняшний виджет).
- `Mark as visited` — Visit History и сегодня в коде условен на
  `item.objectKind == DiscoverObjectKind.place`
  (`compatibility_object_renderer.dart:703`): «if (item.objectKind ==
  DiscoverObjectKind.place) DetailsActionTile(...'Mark as visited'...)».
  Event никогда не показывал этот tile — не регрессия, а точное
  сохранение уже верного поведения.
- `Map` (как отдельный action-tile внутри hub) — заменяется на п.4.1.4
  (`Open map` как самостоятельное действие §10-таблицы), не теряется,
  просто не внутри удаляемого hub-виджета.

Это удаление — осознанное решение этого документа, не побочный эффект
рефакторинга; если оно окажется неверным, откат — вернуть Event на
`.discoverItem` (§6, п.1 rollback v0.2), а не тихо восстановить
`DetailsActionHub` внутри нового `.event`-пути.

### 4.3 — Typed Scenario-intake mapping

`launchScenarioObjectIntake`/`ScenarioIntakeSelectionController`/
`ScenarioIntakeSelectionState` сегодня типизированы конкретно на
`List<DiscoverItemEntity>` (`scenario_object_intake_sheet.dart:80,124`,
`scenario_intake_selection_controller.dart:6,33,45,51,71`) — не через
интерфейс. Новый `ScenarioIntakeCandidate` (§3) — минимальная форма,
которую оба типа (`DiscoverItemEntity`, `PublishedEventDiscoveryEntity`)
маппят в себя каждый своей маленькой функцией; вызывающий код (обе
страницы Details) строит `List<ScenarioIntakeCandidate>` перед вызовом
`launchScenarioObjectIntake`. Точная минимальная форма (какие поля
реально читает `ScenarioIntakeSupportIssue`/сама шторка) фиксируется на
этапе реализации после прямого чтения этих файлов — этот документ
называет обязательство («не конвертировать Event в `DiscoverItemEntity`
ради Scenario intake»), не проектирует внутренний интерфейс заранее.

## 5. Acceptance criteria (обновлены/добавлены)

AC-01–03, 05–06, 08 из v0.2 актуальны без изменений. Обновлены/добавлены:

- **EVT-D-AC-04 (обновлён).** Verified badge рендерится тогда и только
  тогда, когда `publisherVerification != PublisherVerificationDisplayState.none`.
- **EVT-D-AC-07 (обновлён).** Metrics: `isFree` → «Бесплатно»;
  `participantsCount == null` → визуальный «—» **и**
  `Semantics(label: 'Количество участников неизвестно')`.
- **EVT-D-AC-09 (обновлён).** «Добавить в календарь» отсутствует в v1
  целиком — ни активной, ни неактивной кнопки. «Читать далее» реально
  раскрывает/сворачивает.
- **EVT-D-AC-14 (новый).** Primary CTA: `isFree` → internal
  Join-acknowledgement (без имитации оплаты/подтверждения); иначе —
  видима только при валидном `externalBookingUrl`, тап открывает его
  через `url_launcher`; невалидный/пустой URL → CTA скрыта целиком, не
  задизейблена с текстом.
- **EVT-D-AC-15 (новый).** Hero — `PageView` над
  `[coverImageUrl, ...galleryImageUrls]` без дублирования cover; счётчик
  показан только при итоговых `total > 1` страницах.
- **EVT-D-AC-16 (новый).** Header/Metrics/CTA читают occurrence по
  `displayOccurrenceId` из `occurrences`, никогда — литеральную пару
  `start/end` в обход occurrence-модели.
- **EVT-D-AC-17 (новый).** `PublishedEventProgramItem` не рендерит
  собственный CTA/booking-индикатор ни при каких данных — read-only.
- **EVT-D-AC-18 (новый).** Save/Unsave, Share, Add to Scenario, Open
  map продолжают работать для Event после перехода на
  `PublishedEventDiscoveryEntity` — regression-тест на каждое из
  четырёх, не только «страница открывается».
- **EVT-D-AC-19 (новый).** `Find similar`/`Create similar`/`Mark as
  visited` не появляются в Event Details — negative-тест, не только
  отсутствие в файле.
- **EVT-D-AC-20 (новый).** Дата/время идут через
  `TimezoneRepository.toLocal(...)` с `timezoneId` события, не через
  `DateTime.toLocal()` устройства.
- **EVT-D-AC-21 (новый).** Геометрия в тестах/коде выражена в dp
  (logical pixels), не `px`-литералах, скопированных из докса без
  перевода единиц.
- **EVT-D-AC-12 (без изменений).** `flutter analyze`, `flutter test`,
  boundary gate, `git diff --check` — зелёные.

## 6. Rollback

Как в v0.2, плюс:

7. Вернуть `scenario_object_intake_sheet.dart`/
   `scenario_intake_selection_controller.dart`/`_state.dart` на прямой
   `List<DiscoverItemEntity>` — `ScenarioIntakeCandidate` аддитивен до
   тех пор, пока сигнатуры не переключены; после переключения откат
   требует вернуть обе сигнатуры одновременно (не частично).
8. Удалить `event_occurrence.dart`, `published_event_program_item.dart`,
   `publisher_verification_display_state.dart` вместе с остальными
   `published_event_*`/`event_*` файлами (уже в списке v0.2).

## 7. Нормативный визуальный референс (обновлён)

### 7.1 — Геометрия (px → dp)

| Зона | Размер/правило |
|---|---|
| Device canvas | 430×932 dp база; для 375×812 dp — layout через clamp/constraints и safe-area, не масштабирование картинки целиком |
| Horizontal content margin | 16 dp |
| Card gap | 10–12 dp |
| Hero height | ~220–230 dp, edge-to-edge, не более ~25% viewport height |
| Content sheet overlap | 12–18 dp внахлёст на hero |
| Sheet top radius | 28–32 dp |
| Primary card radius | 22–24 dp |
| Metrics radius | 20 dp |
| CTA radius | 20–22 dp |

### 7.2–7.3 — без изменений от v0.2 (design tokens, порядок секций).

### 7.4 — Форматирование даты/времени (новое)

Дата/время читаются из выбранной `EventOccurrence`
(`displayOccurrenceId`), конвертируются в местное время через
`TimezoneRepository.toLocal(occurrence.startAtUtc, event.timezoneId)` —
не через `DateTime.toLocal()` устройства (иначе событие в Дубае покажет
время зрителя в Риге, а не время площадки). Русский текст дня
недели/месяца («вс», «июня») — маленький RU-only форматтер, тем же
способом, каким уже хардкожен весь остальной копирайт этого экрана
(«Организатор», «Показать на карте» и т.д.) — явное, названное решение
этого slice, не заявка на locale-aware систему, которая целиком вне
scope (§1.2).

### 7.5 — Точный копирайт демо-фикстуры

Без изменений от v0.2 §7.4 — те же строки, тот же статус («для
mock-датасорса и golden-теста, не литералы в production-коде
рендерера»).

## 8. Открытые вопросы (сокращены)

Пункты 2–4 из v0.2 закрыты этой ревизией. Остаются:

1. Точная минимальная форма `ScenarioIntakeCandidate` (§4.3) —
   фиксируется при реализации после прямого чтения
   `scenario_object_intake_sheet.dart`/контроллера, не проектируется
   заранее в этом документе.
2. Правило выбора `displayOccurrenceId` (ближайшая будущая `scheduled`
   по умолчанию?) — деталь `EventDetailsPage`, не блокирует Approval
   этого документа, т.к. не меняет ни один AC (какая бы occurrence ни
   была выбрана, она обязана прийти из `occurrences`, не быть
   литералом).
3. Стоит ли `PublishedEventProgramItem` ссылаться на stage/room/venue
   (`EVENT_CLASSIFICATION_SPEC.md:957`: «использует stable IDs для
   stage/room/venue») в этом slice, или это остаётся будущим
   расширением поля `description` — не блокирует Approval, т.к. демо-
   фикстура (§7.5) не использует multi-stage сценарий.
