# RECHARGE — DTL-SES-01: Bookable Session Details Runtime Slice Spec

Версия: **0.2**

Дата: **2026-09-06**

Статус: **Approved** (утверждён владельцем продукта 2026-09-07)

Родительский план:
`OBJECT_OFFER_DETAILS_RUNTIME_COMPLETION_PLAN.md` v0.2 Approved

Визуальный контракт:
`OBJECT_OFFER_DETAILS_VISUAL_SYSTEM_PLAN.md`

Связанный upstream contract:
`BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md` v1.1 Draft for review

## 0. Назначение и граница

DTL-SES-01 переводит уже утверждённую визуальную композицию Bookable
Session из preview-only в typed Discover runtime:

```text
CatalogObjectRef(session, id)
  -> PublishedBookableSessionDiscoveryPort
  -> BookableSessionDetailsLookup
  -> ResolveDetailsUseCase
  -> BookableSessionDetailsPage
  -> ObjectOfferDetailsRenderer.bookableSession
```

Slice не меняет визуальный язык и не создаёт Booking внутри Recharge.
Он подключает реальные typed данные, честную freshness-семантику,
canonical Share, условный Map и внешний booking handoff.

Вне scope:

- hold, booking confirmation, waitlist, capacity decrement и Payments;
- provider calendar sync, webhooks и проверка фактической availability;
- выбор/резервирование slot внутри Recharge;
- передача `slotKey`, party size или PII во внешний URL;
- Favorites redesign, Calendar и Scenario intake;
- Create mapper/form/publication lifecycle и Firebase;
- Route, Scenario, Collection и Rental product changes.

Rental остаётся вне Object / Offer scope, но проходит обязательную
регрессию, пока физически находится в общем renderer-файле.

## 1. Исходное состояние перед реализацией

1. Визуальная композиция уже существует как
   `ObjectOfferDetailsRenderer.bookableSessionPreview`.
2. `BookableSessionVisualPreviewProps` содержит только готовые строки и
   не является runtime read model.
3. Canonical `CatalogObjectType.session` сейчас fail closed, потому что
   loader не зарегистрирован.
4. Create содержит typed Session schedule и allowlist-based
   `PublicSessionScheduleProjection`, но не имеет согласованного active
   published listing/read adapter. Discover не должен импортировать Create
   ради Details.
5. Внешний HTTPS booking URL — единственный принятый booking path v1;
   Recharge не знает фактическую provider availability.

## 2. Архитектурное решение

### 2.1 Read boundary

Добавляется собственная Discover-owned immutable projection. Она не
наследуется от `DiscoverItemEntity` и не импортирует `SessionDraftData`,
`PublicSessionScheduleProjection` или другие Create-типы.

В DTL-SES-01 datasource остаётся read-only local/mock. Будущий
Create-to-Discover publication adapter сможет материализовать тот же port
после появления цельной active publication model, но это не причина
соединять текущий грязный Create WIP с Details.

### 2.2 Freshness принадлежит domain evaluation

Renderer не сравнивает timestamps и не объявляет availability. Чистый
`EvaluateBookableSessionScheduleUseCase` получает projection и injected
`nowUtc`, затем возвращает одно из трёх состояний:

```dart
enum BookableSessionScheduleState {
  freshWithOffers,
  freshEmpty,
  stale,
}
```

- fresh: `generatedAtUtc <= nowUtc < validUntilUtc`;
- offers для Viewer — только отсортированные future starts;
- stale не показывает отдельные slot labels;
- `providerAvailabilityUnknown` всегда true и отображается явно;
- empty/stale не меняют lifecycle опубликованного listing.

Это freshness cache snapshot, а не подтверждение свободного места.

## 3. Typed public contract

### 3.1 Enums и offers

```dart
enum PublishedBookableSessionPriceType { free, fixed }

enum PublishedBookableSessionMeetingMode {
  inPerson,
  online,
  hybrid,
}

final class PublishedBookableSessionOffer {
  final String slotKey;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
}

final class PublishedBookableSessionScheduleSnapshot {
  final int scheduleRevision;
  final DateTime generatedAtUtc;
  final DateTime validUntilUtc;
  final List<PublishedBookableSessionOffer> offers;

  bool get providerAvailabilityUnknown => true;
}
```

`slotKey` публичен только как opaque identity. Он не является Booking id,
availability proof или параметром внешнего handoff.

### 3.2 Public location variants

```dart
sealed class PublishedBookableSessionPublicLocation {}

final class PublishedBookableSessionPointLocation
    extends PublishedBookableSessionPublicLocation {
  final PublishedBookableSessionMeetingMode meetingMode; // inPerson|hybrid
  final String venueName;
  final String areaLabel;
  final String publicAddress;
  final double latitude;
  final double longitude;
  final int publicGeoPrecisionMeters;
}

final class PublishedBookableSessionOnlineLocation
    extends PublishedBookableSessionPublicLocation {
  final String providerLabel; // label only, never meeting URL/secret
}

final class PublishedBookableSessionHiddenLocation
    extends PublishedBookableSessionPublicLocation {
  final PublishedBookableSessionMeetingMode meetingMode; // inPerson|hybrid
  final String safeAreaLabel;
}
```

Point содержит только разрешённую public точность. Online не содержит
coordinates или meeting credentials. Hidden не означает, что exact point
лежит в public projection: публичных координат в этом варианте нет.

Online/hybrid варианты нужны read-контракту и regression matrix. Этот slice
не расширяет текущую Session Create-форму и не заявляет, что она уже умеет
создавать каждый вариант.

### 3.3 Listing projection

```dart
final class PublishedBookableSessionDiscoveryEntity {
  final String sessionId;

  final String publisherId;
  final String publisherType; // user | page
  final String publisherName;
  final String publisherHandle;
  final PublisherVerificationDisplayState publisherVerification;

  final String title;
  final String resourceName;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final String subcategory;
  final String serviceCategoryLabel;
  final String coverImageUrl;
  final List<String> galleryImageUrls;

  final int durationMinutes;
  final int maxPartySize;

  final PublishedBookableSessionPriceType priceType;
  final int? priceAmountMinor;
  final String currencyCode;

  final String timezoneId;
  final PublishedBookableSessionScheduleSnapshot schedule;
  final PublishedBookableSessionPublicLocation publicLocation;

  final Uri externalBookingUri;
  final Uri? externalTermsUri;
  final DateTime publishedAtUtc;
}
```

### 3.4 Инварианты

- обязательные ids/title/resource/publisher/category/service label/timezone
  не пусты;
- `publisherType` только `user | page`;
- duration 30–180 минут, max party size 1–20;
- `free` не имеет amount; `fixed` требует positive minor amount и ISO
  currency;
- schedule revision положителен для active published snapshot;
- generated/valid/published и offer timestamps — UTC;
- `validUntilUtc > generatedAtUtc`, `offer.end > offer.start`;
- offer keys уникальны, offers отсортированы, timezone каждого offer равна
  listing timezone;
- внешний booking URI обязателен, absolute HTTPS, без user-info; terms URI
  при наличии следует тем же правилам;
- point допускает только in-person/hybrid, валидные coordinates и positive
  precision;
- online не имеет public/exact coordinates и meeting secret;
- hidden не имеет coordinates/address;
- malformed/future payload fail closed до renderer.

## 4. Privacy allowlist

Public projection физически не содержит:

- weekly rules и closing exceptions;
- `privateNote`, actor/creator audit IDs и moderation payload;
- blocked/past/notice-window/DST intervals и internal reason codes;
- provider calendar, confirmed bookings, holds и capacity ledger;
- exact hidden address/coordinates;
- online meeting URL, passcode, token или credentials;
- customer identity, party size selection или application data.

Analytics может получать `sessionId`, object type, category, schedule state
и action name. Запрещены URL, slotKey, address, coordinates, search query,
private notes и PII.

## 5. Action matrix

| Действие | Условие | Реальное поведение |
|---|---|---|
| Share | projection разрешена | Копирует canonical deep link |
| Map | public point + callback | Открывает Discover Map на public point |
| Map | online/hidden/no callback | Кнопки и tap-target нет |
| External CTA | valid required booking URI | Открывает URI внешним приложением |
| Save | любой Session в DTL-SES-01 | Кнопки нет |
| Slot selection | любой schedule state | В Recharge отсутствует |

Save временно отсутствует по той же причине, что в DTL-FP-01: legacy
`FavoriteItemEntity` требует event/point-only значения (`startsAtUtc`,
`distanceKm`, `city`, flat price). Online/hidden/stale Session нельзя
сохранить без фиктивных данных. Это закрывается общим typed Favorites
contract, а не адаптером внутри Details.

External CTA не зависит от freshness как от eligibility: provider site —
единственный authority и остаётся доступен при stale/empty snapshot.
Никакой выбранный slot и никакие query parameters к сохранённому URI не
добавляются.

При launch failure показывается честная ошибка. Disabled/no-op CTA не
рендерится.

## 6. Визуальное отображение typed данных

Порядок существующей `BookableSessionDetailsSection` сохраняется:

```text
hero
-> header
-> metrics
-> provider
-> about
-> availability
-> location
-> sticky CTA
```

| Секция | Источник |
|---|---|
| Hero | cover/gallery, fallback при отсутствии media |
| Header | title, category/subcategory, meeting mode |
| Metrics | free/fixed price и duration; существующая двухколоночная геометрия сохраняется |
| Provider | publisher identity/verification |
| About | fullDescription, fallback shortDescription |
| Availability | result `EvaluateBookableSessionScheduleUseCase` |
| Location | один из трёх public location variants |
| CTA | реальный external callback + schedule-aware honest label |

`maxPartySize` остаётся typed public fact для последующего общего
capability/booking контракта, но DTL-SES-01 не добавляет третью metric-колонку
и не меняет уже принятую двухколоночную геометрию без visual approval.

Availability отображается так:

- `freshWithOffers`: ближайшие declared schedule times + постоянный текст
  «Доступность подтверждается на сайте партнёра»;
- `freshEmpty`: «В текущем окне время не указано» + тот же authority note;
- `stale`: «Расписание требует обновления — проверьте время на сайте»;
  старые slot labels скрыты;
- нигде не используются «свободно», «доступно», «осталось N мест» или
  другой язык provider-confirmed availability.

CTA label:

- fresh with offers: `Проверить и забронировать`;
- fresh empty/stale: `Проверить время на сайте`.

Renderer только отображает переданные projection/evaluation/callbacks. Он
не вызывает clock, не проверяет URI, не выбирает slot и не решает
availability/eligibility.

## 7. Exact file map

### 7.1 Новые production-файлы

- `apps/mobile/lib/features/discover/domain/entities/`
  `published_bookable_session_discovery_entity.dart`;
- `apps/mobile/lib/features/discover/domain/entities/`
  `bookable_session_schedule_evaluation.dart`;
- `apps/mobile/lib/features/discover/domain/usecases/`
  `evaluate_bookable_session_schedule_usecase.dart`;
- `apps/mobile/lib/features/discover/domain/repositories/`
  `published_bookable_session_discovery_port.dart`;
- `apps/mobile/lib/features/discover/data/datasources/`
  `published_bookable_session_discovery_local_datasource.dart`;
- `apps/mobile/lib/features/discover/data/repositories/`
  `bookable_session_details_lookup.dart`;
- `apps/mobile/lib/app/presentation/bookable_session_details_page.dart`.

### 7.2 Изменяемые production-файлы

- `apps/mobile/lib/features/discover/presentation/renderers/`
  `object_offer_details_renderer.dart`;
- `apps/mobile/lib/features/discover/presentation/renderers/`
  `object_offer_section_matrix.dart` — только comment/status, порядок
  Bookable Session matrix не меняется без отдельного visual approval;
- `apps/mobile/lib/features/discover/presentation/renderers/`
  `object_offer_visual_preview_props.dart` — удалить только Session props;
- `apps/mobile/lib/app/application/details_lookup_registry.dart`;
- `apps/mobile/lib/app/application/details_resolution_providers.dart`;
- `apps/mobile/lib/app/di/service_locator.dart`;
- `apps/mobile/lib/app/router/app_router.dart`.

### 7.3 Тесты

- entity/location/URI/privacy invariants;
- schedule evaluator: fresh offers, fresh empty, stale, future-generated,
  past offers, ordering и injected clock;
- datasource found/not-found/hidden/malformed;
- lookup/registry/resolver classification и mismatch fail closed;
- page Share/Map/external launch/failure; URI передаётся без модификации;
- renderer order, presence, all schedule/location/price variants;
- отсутствие Save, slot selection и false availability semantics;
- 360/375dp, 150% text scale, long title/provider/address;
- typed golden вместо `BookableSessionVisualPreviewProps`;
- все Object/Offer tests, Rental regression, Route/Scenario/Collection и
  DetailsShell invariance.

## 8. Acceptance criteria

- **SES-DTL-AC-01.** Canonical Session ref открывает typed page.
- **SES-DTL-AC-02.** Unknown/hidden/malformed/type mismatch fail closed.
- **SES-DTL-AC-03.** Discover production не импортирует Create.
- **SES-DTL-AC-04.** Public projection не может содержать private schedule,
  exact hidden location, meeting secrets, Booking state или PII.
- **SES-DTL-AC-05.** Freshness вычисляется pure usecase из injected UTC
  clock; renderer не читает `DateTime.now()`.
- **SES-DTL-AC-06.** Stale slots не показываются как актуальные; fresh empty
  не превращается в unavailable listing.
- **SES-DTL-AC-07.** UI всегда сообщает, что provider availability unknown.
- **SES-DTL-AC-08.** External CTA открывает exact approved HTTPS URI без
  slot/PII/query injection и остаётся доступен при stale/empty snapshot.
- **SES-DTL-AC-09.** Map существует только для public point.
- **SES-DTL-AC-10.** Share canonical; Save и in-app booking controls
  отсутствуют.
- **SES-DTL-AC-11.** Free/fixed price и nullable content не фабрикуются.
- **SES-DTL-AC-12.** Typed section order совпадает с утверждённым visual.
- **SES-DTL-AC-13.** Golden строится из typed projection/evaluation.
- **SES-DTL-AC-14.** 360/375dp и 150% не дают overflow/ложных semantics.
- **SES-DTL-AC-15.** Place/Event/Activity/Find People, Rental и соседние
  Details families не регрессируют.
- **SES-DTL-AC-16.** Targeted/full analyzer/tests, boundary и diff gates
  зелёны; красный pre-existing baseline не объявляется Done.

## 9. Порядок реализации

1. Entity/location/schedule snapshot + invariant tests.
2. Pure freshness evaluator + clock matrix tests.
3. Public port/local datasource/lookup + malformed/not-found tests.
4. DI/registry/resolver registration.
5. `.bookableSessionPreview` -> typed `.bookableSession`.
6. Boundary-safe page coordinator и canonical router branch.
7. Typed golden и adaptive/action tests.
8. Object/Offer + Rental + cross-family + full gates.
9. Execution log и runtime-plan checkpoint **5/6**.

Production code DTL-SES-01 меняется только после утверждения v0.1;
approval получен 2026-09-07, реализация ведётся по v0.2 без расширения
решений §11.

## 10. Rollback

1. Удалить Session router/registry/DI registration.
2. Вернуть canonical Session route к общему fail-closed unavailable state.
3. Удалить Session page, lookup, port, datasource, evaluator и projection.
4. Вернуть Session golden/widget fixture на
   `BookableSessionVisualPreviewProps` и `.bookableSessionPreview`.
5. Не менять Create Session payload, уже принятые Object/Offer verticals,
   Rental и соседние Details families.

## 11. Решения для Approval

1. DTL-SES-01 идёт без Save до общего typed Favorites contract.
2. External CTA доступен при fresh/stale/empty snapshot, всегда ведёт на
   исходный provider URI и никогда не переносит выбранный slot.
3. Stale snapshot скрывает individual slot labels; показывает честный
   handoff message.
4. Read projection поддерживает point/online/hidden variants, не расширяя
   текущую Create-форму.
5. Первый runtime datasource остаётся Discover-owned local/mock без
   временного импорта незавершённой Create publication model.

## 12. Execution log — 2026-09-08

Статус реализации: **Review**, не Done. Approved scope реализован на
Discover-owned local/mock boundary; backend/Create publication adapter и
реальный booking provider не подключались.

### Реализовано

- Immutable listing, schedule/offers и три разных public location-типа;
  строгие constructor invariants, required HTTPS URL без user-info.
- Pure injected-clock evaluator: future offers, fresh empty, stale.
  Page обновляет состояние на временных границах и при resume; stale
  slot labels исчезают без повторного входа. Таймер отменяется при dispose.
- Port, local datasource, typed lookup, registry/DI и canonical Session
  router branch. Wrong id/type и unknown/hidden/malformed fail closed.
- Typed `.bookableSession`, удаление Session preview props, прежняя typed
  section matrix и геометрия. Cover/gallery с дедупликацией, fallback,
  двухколоночные metrics, provider, about, schedule, typed location, CTA.
- Share canonical; Map только public point; внешний URI передаётся без
  добавления параметров. False launch и PlatformException дают видимую
  ошибку. Save и in-app booking не добавлялись.
- Typed golden, 360/375dp/150%, overnight time label, галерея,
  lifecycle freshness и точный external handoff покрыты тестами.

### Проверки

| Gate | Фактический результат |
|---|---|
| Focused Object/Offer + Rental + Route renderer + shell + resolver | 143/143 passed |
| Session resolver после добавления Scenario invariance | 4/4 passed |
| Session gallery/adaptive/overnight + typed golden | 11/11 passed |
| Scoped analyzer: Session production/tests и renderer directory | 0 issues |
| Full mobile analyzer | 40 issues, существующий Create/Identity WIP и его DI wiring |
| Full mobile test | 897 passed / 58 failed; все 58 — load/compile failures в Create/Identity baseline |
| Boundary | 0 violations, 71/71, без новых исключений |
| Diff whitespace | clean |

Collection page и Discover parity не загружаются из-за отсутствующего
`moderationRepository` в DI и рассинхронизации Create `sessionData`.
Это не пройденная invariance-проверка: AC-15/16 целиком остаются открыты.
Route renderer и общий shell зелёные; Scenario registration по-прежнему
отсутствует, что отдельно проверено fail-closed тестом.

Полный suite запускался параллельно с заключительным gallery/resolver
проходом; окончательный код дополнительно подтверждён focused 143/143 и
resolver 4/4. Красный repo-wide baseline не выдаётся за успешный финальный gate.

### Ограничения и следующий этап

Встроенный `session_personal_training_riga` — явно помеченный demo fixture.
`booking.recharge.local` не является действующим сервисом бронирования;
успешный provider handoff подтверждён только injected-launcher тестами.
Mock snapshot создаётся один раз на жизнь datasource: повторное чтение не
обновляет freshness и не перемещает слоты. Нет автоматического provider refresh.

Статус public schedule не означает наличие места у provider. Privacy/type
invariants проверяют нынешнюю Dart read model; полноценного wire decoder
здесь нет, future-schema regression проверяет fail-closed builder error,
а не поддержку внешнего протокола.

Следующий vertical — Class / Workshop: сначала отдельная slice-spec и
approval, затем runtime. Rental и соседние семейства не расширяются.
