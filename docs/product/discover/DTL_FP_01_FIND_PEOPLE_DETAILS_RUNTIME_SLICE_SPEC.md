# RECHARGE — DTL-FP-01: Find People Details Runtime Slice Spec

Версия: v0.2 (2026-09-06).

Статус: **Approved** (утверждён владельцем продукта
2026-09-06; приняты bounded reader-only scope без Save/Join и
два conditional блока `schedule`/`cost`). Runtime effect самого
документа: **none**; implementation разрешена по файловой карте §6.

Эта подспека разрешает только первый vertical из
`OBJECT_OFFER_DETAILS_RUNTIME_COMPLETION_PLAN.md`: публичное
reader-facing Details для `find_people`. Она не разрешает
application, waitlist, invitation, chat, attendance, production backend или
раскрытие закрытых meeting data.

## 0. Исходная точка и решения

1. Find People visual composition уже существует в
   `ObjectOfferDetailsRenderer.findPeoplePreview`, но она получает
   заранее форматированные presentation-only строки.
2. Canonical route для `CatalogObjectType.findPeople` сейчас корректно
   fail closed, потому что loader не зарегистрирован.
3. `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` задаёт продуктовую
   семантику, но не является Discover runtime contract.
4. Source of truth для time, capacity, recruitment и public location —
   выбранная occurrence, а не mutable request aggregate и не renderer.
5. Online request не получает fake coordinates. Hidden-location
   вариант не получает Map action.
6. В текущем slice нет фальшивых Save/Join действий. Причины
   зафиксированы в §4.

## 1. Цель

Довести Find People от visual preview до типизированного
mock-first runtime vertical:

```text
CatalogObjectRef(find_people, requestId)
  -> PublishedFindPeopleDiscoveryPort
  -> FindPeopleDetailsLookup
  -> DetailsLookupRegistry
  -> ResolvedDetailsRoute
  -> FindPeopleDetailsPage
  -> ObjectOfferDetailsRenderer.findPeople
```

После slice canonical Find People URL открывает реальную typed
projection; unknown, hidden, malformed и type-mismatched data по-прежнему
дают общий unavailable surface.

## 2. Scope

### 2.1 В scope

- Discover-owned immutable public projection для одного request и одной
  выбранной occurrence;
- read port, local datasource, lookup и registry/DI registration;
- typed `.findPeople` constructor в существующем shared renderer;
- boundary-safe page coordinator для Share, условного Map и analytics;
- typed route branch;
- перевод Find People widget/golden fixtures на typed projection;
- conditional schedule, cost и public-location display без изменения
  общего Object / Offer shell;
- focused, Object/Offer, Rental и cross-family regression.

### 2.2 Вне scope

- Create-domain imports в Discover;
- Create -> Discover publish adapter и production persistence;
- application questions/answers, JoinRequest, waitlist, invitation, offers;
- Auth -> Join handoff, participant chat, co-host/manage flows;
- exact meeting location, instructions, online URL/passcode;
- Favorite storage migration;
- report/block implementation;
- Search/Map/Feed ranking и online rail;
- Scenario intake;
- Route, Scenario, Collection и Rental redesign.

## 3. Точный public read contract

### 3.1 Типы

```dart
enum PublishedFindPeopleScheduleMode { single, timePoll, recurring }

enum PublishedFindPeopleMeetingMode { inPerson, online, hybrid }

enum PublishedFindPeopleRecruitmentStatus {
  collectingAvailability,
  open,
  waitlistOnly,
  full,
  completed,
  cancelled,
  expired,
}

enum PublishedFindPeopleCostType { free, estimated, unknown }

enum PublishedFindPeopleTimeOptionKind { confirmed, candidate }

final class PublishedFindPeopleTimeOption {
  final String id;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final PublishedFindPeopleTimeOptionKind kind;
}

sealed class PublishedFindPeoplePublicLocation {}

final class PublishedFindPeoplePointLocation
    extends PublishedFindPeoplePublicLocation {
  final PublishedFindPeopleMeetingMode meetingMode; // inPerson | hybrid
  final String areaLabel;
  final double latitude;
  final double longitude;
}

final class PublishedFindPeopleOnlineLocation
    extends PublishedFindPeoplePublicLocation {
  final String providerLabel; // public provider name only; never URL/secret
}

final class PublishedFindPeopleHiddenLocation
    extends PublishedFindPeoplePublicLocation {
  final PublishedFindPeopleMeetingMode meetingMode; // inPerson | hybrid
  final String safeAreaLabel; // may be empty
}
```

`PublishedFindPeopleHiddenLocation` не означает, что exact point
хранится в public projection. Он означает только: публичной
координаты нет, поэтому Map недоступен.

### 3.2 `PublishedFindPeopleDiscoveryEntity`

```dart
final class PublishedFindPeopleDiscoveryEntity {
  final String requestId;
  final String occurrenceId;

  final String publisherId;
  final String publisherType; // user | page
  final String publisherName;
  final String publisherHandle;
  final PublisherVerificationDisplayState publisherVerification;

  final String title;
  final String purposeLabel;
  final String fullDescription;
  final String category;
  final String subcategory;
  final String coverImageUrl;

  final PublishedFindPeopleScheduleMode scheduleMode;
  final List<PublishedFindPeopleTimeOption> timeOptions;
  final String timezoneId;
  final int? durationMinutes;

  final int? currentGroupSize;
  final int targetGroupSize;
  final int? remainingSeats;
  final PublishedFindPeopleRecruitmentStatus recruitmentStatus;

  final String skillLevelLabel;
  final String paceLabel;
  final List<String> languageLabels;
  final List<String> publicRequirements;
  final String equipmentNote;
  final String accessibilityNote;

  final PublishedFindPeopleCostType costType;
  final double? expectedSpendAmount;
  final String currencyCode;
  final String costNote;

  final PublishedFindPeoplePublicLocation publicLocation;
  final DateTime publishedAtUtc;
}
```

`timeOptions` и все group/recruitment значения уже принадлежат
выбранной occurrence. Renderer может только форматировать
типизированные UTC/money/count values для UI. Он не выбирает
occurrence, не считает seats и не выводит recruitment status.

### 3.3 Инварианты

- `requestId`, `occurrenceId`, `title`, `publisherId` и `timezoneId` не пусты;
- `timeOptions` не пуст; ids уникальны, `endAtUtc > startAtUtc`;
- `single` имеет ровно один `confirmed`; `timePoll` — минимум два
  `candidate`; `recurring` не смешивает candidate/confirmed в одной
  Details projection;
- `targetGroupSize` в диапазоне 2–20;
- nullable counts означают unknown, а не zero;
- из `remainingSeats`/`currentGroupSize` не пересчитывается status;
- `free` не имеет положительного amount; `estimated` требует
  положительные amount и currency; `unknown` не превращается в
  «бесплатно»;
- point location разрешает только `inPerson | hybrid` и валидные
  coordinates;
- online location не имеет coordinates;
- hidden location не имеет exact/public coordinates;
- malformed projection не попадает в renderer.

## 4. Action/privacy matrix

### 4.1 Действия текущего slice

| Действие | Условие | Поведение |
|---|---|---|
| Share | projection успешно резолвлена | Копирует canonical deep link |
| Map | `PublishedFindPeoplePointLocation` и передан callback | Открывает Discover Map на public approximate point |
| Map | online/hidden или callback отсутствует | Кнопки/тапа нет |
| Save | любой Find People в DTL-FP-01 | Кнопки нет; см. §4.2 |
| Primary CTA | любой Find People в DTL-FP-01 | Sticky action нет; см. §4.3 |

Информационные `full`, `waitlist only`, `cancelled`, `expired` и
прочие recruitment states могут отображаться как текст/бейдж,
но не как disabled button, имитирующая недоступный flow.

### 4.2 Почему Save не подключается в этом slice

Текущий `FavoriteItemEntity` обязательно требует `startsAtUtc`,
`distanceKm`, `priceAmount`, `city` и event-like summary. Online request не
имеет distance/coordinates, time-poll не имеет одного выбранного
`startsAtUtc`, а expected spend не является ценой. Подставить
`0`, первый slot или expected spend означало бы исказить данные.

Поэтому Save скрыт до отдельного slice типизированного
catalog-favorite contract. DTL-FP-01 не расширяет cross-feature storage
ради одной Details-ветки.

### 4.3 Почему Join/Apply не подключается в этом slice

Product CTA matrix зависит от auth, viewer relation, selected
occurrence, application deadline, capacity, waitlist, invitations, block/safety
и capabilities. Ни один из этих runtime contracts не входит в
Details visual/runtime completion plan. Поэтому renderer не выводит
eligibility из одного `recruitmentStatus`, а page не показывает
кнопку, которая ничего не делает.

### 4.4 Public allowlist

Разрешены только поля §3: publisher display, public content,
public time options, occurrence counters/status, safe requirements, expected
spend disclosure и public location variant.

Запрещены:

- `exactGeo`, `exactAddressLine`, meeting instructions;
- online URL, passcode, secret ref;
- applicant/participant identities и contact data;
- application questions/answers, waitlist/order и decision reasons;
- live/device location;
- moderation, report, block, audit и internal capability data.

Запрещённые поля не должны просто «не рендериться» — их
не должно быть в public entity и local public fixture.

## 5. Visual mapping

Общие `DetailsShell`, immersive hero, spacing, cards, radius, typography
и sticky-action geometry не форкаются.

| Typed данные | Блок |
|---|---|
| cover/title | hero + header |
| purpose | header, только если не пусто |
| time options/timezone | header summary + conditional schedule card |
| current/target group + duration | metrics; вся strip скрыта при <2 честных values |
| publisher display | organizer card |
| description | about card |
| meeting mode, level, pace, languages | meeting-format card |
| public requirements/equipment/accessibility | requirements card |
| cost type/amount/note | conditional cost card |
| point/online/hidden location | location/online block; Map affordance только для point |
| recruitment status | informational label; не CTA eligibility |

Для двух новых optional blocks в том же registry-файле
добавляются `FindPeopleDetailsSection.schedule` и `.cost`. Это не
универсальная nullable matrix: остаётся отдельный typed-порядок
только Find People. Пустой optional block не рендерится.

## 6. File map

### 6.1 Новые production-файлы

- `apps/mobile/lib/features/discover/domain/entities/published_find_people_discovery_entity.dart`;
- `apps/mobile/lib/features/discover/domain/repositories/published_find_people_discovery_port.dart`;
- `apps/mobile/lib/features/discover/data/datasources/published_find_people_discovery_local_datasource.dart`;
- `apps/mobile/lib/features/discover/data/repositories/find_people_details_lookup.dart`;
- `apps/mobile/lib/app/presentation/find_people_details_page.dart`.

### 6.2 Изменяемые production-файлы

- `apps/mobile/lib/features/discover/presentation/renderers/object_offer_details_renderer.dart`;
- `apps/mobile/lib/features/discover/presentation/renderers/object_offer_section_matrix.dart`;
- `apps/mobile/lib/app/application/details_resolution_providers.dart`;
- `apps/mobile/lib/app/di/service_locator.dart`;
- `apps/mobile/lib/app/router/app_router.dart`.

`object_offer_visual_preview_props.dart` на этом этапе не удаляется:
Class/Workshop и Bookable Session ещё используют его. Из production
renderer удаляются только `FindPeopleVisualPreviewProps` и
`.findPeoplePreview`, если их больше не требуют тесты.

### 6.3 Тесты

- entity invariants и privacy allowlist;
- local datasource found/not-found/hidden/malformed;
- port/lookup classification;
- registry/resolve/router typed dispatch;
- page actions (Share, conditional Map, absent Save/Join);
- renderer order, presence, schedule/cost/location variants;
- 360/375dp, 150% text scale, long content;
- Find People golden на typed fixture;
- существующие 66 Object/Offer visual tests, 3 Rental tests,
  Route, Scenario fail-closed, Collection и DetailsShell tests.

Точные имена test-файлов следуют существующему Event/
Details convention и не требуют новой test infrastructure.

## 7. Acceptance criteria

- **FP-DTL-AC-01.** Canonical `find_people` ref с известным public id
  открывает `FindPeopleDetailsPage` с typed projection.
- **FP-DTL-AC-02.** Unknown, hidden, malformed и type mismatch fail closed в
  общий unavailable/not-found surface.
- **FP-DTL-AC-03.** Discover production не импортирует Create.
- **FP-DTL-AC-04.** Public entity физически не может содержать
  exact location, secrets, identities заявителей и application data.
- **FP-DTL-AC-05.** Renderer получает typed values, не вычисляет
  seats, recruitment и viewer eligibility.
- **FP-DTL-AC-06.** Single/time-poll/recurring и UTC/timezone semantics
  покрыты тестами; candidate не показывается как confirmed.
- **FP-DTL-AC-07.** Unknown counts/cost не превращаются в `0`/
  «Бесплатно».
- **FP-DTL-AC-08.** Point location с callback показывает Map;
  online/hidden/no-callback не показывают Map.
- **FP-DTL-AC-09.** Share использует canonical deep link.
- **FP-DTL-AC-10.** Save и Primary CTA отсутствуют, а не
  рендерятся disabled/no-op controls.
- **FP-DTL-AC-11.** Find People typed matrix сохраняет порядок
  блоков; пустые optional blocks не создают карточку/отступ.
- **FP-DTL-AC-12.** 360/375dp, 150% text, long title/publisher/area не
  дают overflow; semantics не обещают недоступных действий.
- **FP-DTL-AC-13.** Find People golden строится из typed projection,
  а не preview props.
- **FP-DTL-AC-14.** Place/Event/Activity visual tests, Rental legacy tests,
  Route, Scenario, Collection и DetailsShell invariance не регрессируют.
- **FP-DTL-AC-15.** Targeted analyzer/tests, full analyzer/tests, boundary gate
  и `git diff --check` зелёны. Предсуществующий красный baseline не
  объявляется зелёным и блокирует Done до reconciliation.

## 8. Порядок реализации

1. Entity/enums/location variants + unit tests.
2. Local public datasource + port + lookup tests.
3. DI/registry registration + resolver tests.
4. Typed renderer constructor + visual mapping + widget/adaptive tests.
5. Boundary-safe page coordinator + router branch + action/privacy tests.
6. Golden migration.
7. Object/Offer, Rental, cross-family и full gates.
8. Execution log и фактический status в runtime completion plan.

Перед пунктом 1 эта v0.1 должна получить **Approved**.

## 9. Rollback

1. Удалить Find People router/registry/DI registration.
2. Вернуть canonical route к общему fail-closed unavailable state.
3. Удалить Find People page, lookup, port, datasource и public entity.
4. Вернуть Find People golden/widget fixture на preview props и
   `.findPeoplePreview`.
5. Не менять Create drafts, Favorite storage, Place/Event/Activity,
   Class/Workshop, Bookable Session, Rental и соседние Details families.

## 10. Решения Approval

1. Bounded DTL-FP-01 идёт без Save до общего typed Favorites
   contract.
2. DTL-FP-01 остаётся reader-only без Join/Application CTA до
   отдельного approved participation slice.
3. Find People typed matrix получает conditional `schedule` и `cost`.

## 11. Execution log — 2026-09-06

Статус реализации: **Review**. Функциональный vertical собран полностью, но
`Done` не объявляется до восстановления зелёных repo-wide gates.

Реализовано:

1. Typed public entity, schedule/cost/location variants и fail-fast invariants.
2. Discover-owned public port, local mock datasource и typed lookup.
3. Registry/DI registration и canonical typed router branch.
4. `FindPeopleDetailsPage` с canonical Share и условным Map только для
   публичной point-location; Save и Join/Application CTA отсутствуют.
5. `.findPeople` renderer, отдельная typed section matrix с conditional
   `schedule`/`cost`, typed golden; preview-only Find People API удалён.

Проверки:

- focused Object/Offer, DetailsShell, Find People runtime и обязательная
  Rental regression: **101/101 passed**;
- scoped analyzer по восьми Find People/renderer-файлам: **0 issues**;
- отдельный analyzer `app_router.dart`: **0 issues**;
- Find People projection/datasource/lookup/page tests: green;
- `resolve_details_usecase_test.dart`: **10/10 passed**;
- boundary gate: **0 violations**, существующий budget 71/71 не расширен;
- полный analyzer: **40 issues**, все в предсуществующем параллельном
  Create/Identity WIP, не в DTL-FP-01;
- repo-wide tests: **872 passed, 58 failed**; все failures — load/compile
  failures по тем же blockers: отсутствующие
  `sessionData`, `actorUserId`, `moderationRepository` и Place
  location-search members;
- Collection invariance test не загружается из-за тех же внешних blockers.

До `Done`: восстановить согласованный Create/Identity baseline и повторить
full analyzer, full test, Collection invariance и final diff gate. Scope
DTL-FP-01 для этого не расширяется.
