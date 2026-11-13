# RECHARGE — DTL-CLS-01: Class / Workshop Details Runtime Slice

Версия: **0.2**, 2026-09-08.

Статус: **Approved** — владелец продукта подтвердил решения §9 и file map
2026-09-08. Разрешена ограниченная local/mock реализация DTL-CLS-01.

Родитель: [Object / Offer Runtime Completion Plan](OBJECT_OFFER_DETAILS_RUNTIME_COMPLETION_PLAN.md)
v0.2 Approved. Визуал: [Object / Offer Visual System Plan](OBJECT_OFFER_DETAILS_VISUAL_SYSTEM_PLAN.md).
Связанный продуктовый источник: [Class / Workshop / Experience Create](../create/CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md)
v1.1, **Ready for approval**, не Approved.
Accepted ADR 0013/0015/0019 выше этого документа по приоритету.

## 0. Цель и текущая точка

Перевести последний preview-only тип Object / Offer в typed local/mock
Details, сохранив утверждённый визуал. Сейчас visual 6/6, runtime 5/6;
после реализации этого vertical — 6/6 подключений, но не автоматический Done.
Общие regression/gates родительского плана остаются обязательными.

Проверено по коду 2026-09-08:

- `ClassWorkshopVisualPreviewProps` и `.classWorkshopPreview` существуют;
- `ClassWorkshopDetailsSection` уже задаёт отдельную typed matrix;
- Discover Class projection/port/loader отсутствуют;
- canonical `CatalogObjectType.classWorkshop` возвращает unavailable;
- wire/deep-link type — **`class_workshop`**, не `classWorkshop`;
- Create содержит общий тип, но не завершённый typed Class publication
  adapter. Большая Create-спека не является разрешением реализации её
  production Booking/Cohort/Learning подсистем внутри Details.

## 1. Границы предлагаемого slice

В scope: Discover-owned immutable public projection, read port, mock
datasource, lookup, registry/DI/router, page coordination, typed renderer,
Share, условный Map, typed external/informational enrollment state и тесты.

Вне scope: Create/draft/publication adapter, Firebase, реальные provider
данные, Booking/holds/payments/waitlist/approval, enrollment, attendance,
learning progress/certificates, Calendar, Scenario intake и typed Favorites.
Rental вне product scope, но обязателен в regression. Route/Scenario/
Collection проверяются на неизменность, не расширяются.

Не переносим Session slots/freshness/evaluator в Class: объявленное
расписание занятий не является каталогом свободных слотов.

### 1.1 Поддерживаемый read slice

- Пять display kinds из продуктовой спеки: class, workshop, masterclass,
  course, experience. Они не заменяют category/subcategory.
- Live delivery: offline, online-live, hybrid.
- Один согласованный публичный контекст показа: единичное занятие либо
  фиксированная серия; допускается явно ещё не объявленное расписание.
- Один primary instructor и одна общая public location variant на этот
  контекст. Никакой выборки «первого cohort» из произвольного списка.
- On-demand/blended, rolling cohorts, разные площадки/ведущие по occurrence,
  несколько ценовых вариантов и выбор cohort не моделируются как будто это
  одно занятие. Не поддерживаемый payload отклоняется до renderer.

Это bounded local/mock read slice, а не объявление полной реализации
всех возможностей большой Class Create-спеки. При расширении нужен отдельный
read-contract revision; нельзя молча сплющивать сложные варианты.

## 2. Архитектура

`CatalogObjectRef(class_workshop, offeringId)` → public port → typed lookup
→ существующий `ResolveDetailsUseCase` → `ClassWorkshopDetailsPage`
→ `ObjectOfferDetailsRenderer.classWorkshop`.

Discover не импортирует Create. Page живёт в `app/presentation/`, где
разрешена координация navigation/analytics. Renderer получает подготовленные
данные и callbacks, не читает DI/clock и не решает eligibility.

Никакой универсальной nullable projection для шести типов. Class имеет
собственный тип; существующий section registry остаётся одним файлом с
отдельными матрицами. Новые boundary exceptions не планируются.

## 3. Минимальный public contract

### 3.1 PublishedClassWorkshopDiscoveryEntity

| Группа | Typed поля и смысл |
|---|---|
| Identity | offeringId, positive revision, publishedAtUtc; постоянные IDs, без `loc_*` |
| Publisher | publisherId, user/page type, name, handle, verification display state |
| Instructor | отдельный primary instructor display object; см. §3.2 |
| Learning | title, kind enum, category/subcategory IDs, disciplineLabel, optional levelLabel, languageLabels |
| Content | short/fullDescription, public learningOutcomes, includedMaterials, requirements |
| Media | coverImageUrl и immutable galleryImageUrls; empty/failure fallback |
| Context | единый displayContextId, singleClass/fixedSeries enum; future cohort adapter должен сохранить scope |
| Schedule | ClassWorkshopSchedule: notAnnounced либо announced occurrences |
| Facts | nullable declaredGroupLimit, nullable durationMinutes + explicit perClass/wholeSeries scope |
| Price | ClassWorkshopPrice: notProvided, free либо fixed; fixed — integer minor units + currency + source-provided minorUnitDigits (0–4) + perPersonPerClass/perPersonFullSeries scope |
| Location | point / online / hidden, отдельные sealed варианты |
| Enrollment | sealed external либо informationOnly, см. §4 |

Цена, group limit, расписание, instructor и location относятся к одному
displayContextId, переданному source. Это read-reference, не новый Create
Cohort aggregate. Нельзя смешивать цену одного запуска с датами другого.
Указанный лимит — объявленный размер группы, не число участников и не
`spotsLeft`. Если limit неизвестен/unlimited, numeric metric отсутствует.

### 3.2 Publisher не равен instructor

Instructor — либо явный `sameAsPublisher`, либо отдельный public display
profile с именем, optional handle/bio и optional stable public profile ref.
Guest instructor может не иметь аккаунта; связи по имени запрещены.
Verification Publisher никогда не переносится на другого преподавателя.
Нет придуманного profile CTA без поддерживаемого typed navigation target.

В существующей teacher-карточке показывается instructor; если Publisher
другой, внутри той же карточки добавляется компактная подпись организатора.
Это не новая секция матрицы. Длинные имена проверяются при 150%.

### 3.3 Расписание — не availability

Announced содержит непустой immutable список public occurrences:
occurrenceId, startAtUtc, endAtUtc, IANA timezoneId, optional public title.
Все даты — UTC, end > start, IDs уникальны, строки отсортированы. Для
singleClass ровно одна occurrence; fixedSeries — минимум две без пересечений.
В этом slice timezone общий для контекста. Recurrence rules не передаются.

NotAnnounced не содержит фиктивную дату. UI пишет «Даты уточняются».
Объявленные прошедшие даты не сдвигаются в будущее и не становятся новыми
слотами. Из расписания не вычисляется возможность записаться; live capacity
неизвестна. Отмена/закрытие записи приходит как явное source state (§4).

Программа/outcomes не маскируются под timestamp occurrences: outcomes идут
в «О занятии». Временные этапы без даты не конвертируются в текущую дату.
В этой ревизии отдельный timeline agenda не добавляется.

### 3.4 Location и privacy

- Point: offline/hybrid, public venue/address/area, валидные finite geo и
  positive precision; Map только при callback.
- Online: provider display label, без координат и meeting URL/secret.
- Hidden: offline/hybrid и safe area label, без exact address/geo.

Public DTO физически не содержит attendee/actor data, private notes,
moderation payload, roster, booking/payment state, meeting tokens или
private learning resources. Enrollment URL и meeting-access URL — разные
смыслы; последний не входит в эту projection.

### 3.5 Общие invariants

Обязательные IDs/имена/title/discipline непусты; численные факты положительны
при наличии. Free не содержит amount; fixed требует positive minor amount,
currency code в ISO-формате и price scope. Точность minor units обязательна:
renderer не предполагает две десятичные позиции для любой валюты. Будущий
source adapter отвечает за согласованность currency/precision с источником;
нынешняя Dart-модель проверяет формат, а не полный внешний ISO registry.
NotProvided не превращается в free/zero.
Все коллекции immutable; пустые optional строки/пункты не дают пустых блоков.
Unknown enum/unsupported combination/malformed data fail closed, не silently
fallback к generic DiscoverItemEntity. Будущий wire decoder — отдельный
adapter, не объявляется реализованным тестом builder exception.

## 4. Действия и честные состояния

| Action/state | Отображение и поведение |
|---|---|
| Share | Копирует canonical `recharge://discover/details/class_workshop/<id>` через существующий route builder |
| Map point | Открывает Discover Map на разрешённой public point |
| Map online/hidden | Нет кнопки и tap-target |
| External enrollment | Required valid HTTPS URI без user-info; CTA «Проверить запись на сайте» |
| Information only: closed | Текст «Запись закрыта», без кликабельного primary CTA |
| Information only: onSite | Текст «Условия участия уточняются на месте», без обещания допуска |
| Information only: notProvided | Текст «Способ записи пока не указан», без кнопки |
| Information only: unsupportedInternal | Текст «Запись через приложение пока не подключена», без фальшивого internal flow |
| Save | Отсутствует до общего typed Favorites contract, как в DTL-FP-01/DTL-SES-01 |

External передаёт исходный URI без добавления occurrence/cohort/party/PII.
Рядом с действием: «Наличие мест, итоговая стоимость и условия — на сайте
организатора». Price metric — объявленная цена с unit, не checkout quote.
Нельзя выводить «от» без реальных вариантов или заявлять free при unknown.
Переход наружу не означает создание Booking/Enrollment в Recharge.
False launch/PlatformException → видимая ошибка, повторный тап возможен.

Information-only footer сохраняет визуальный shell, но не рисует disabled
«Записаться» с несуществующим обработчиком. Наличие даты, цена и group limit
сами по себе не разрешают и не закрывают external CTA.

Analytics allowlist: offeringId, object_type, category, enrollment state,
action. Без URL, geo, address, occurrenceId, teacher name/handle или PII.
View один раз на открытый объект; rebuild не дублирует событие.

## 5. Визуальная сборка

Порядок не меняется:

hero → header → metrics → teacher → about → schedule → materials
→ requirements → location → sticky footer.

- Hero: cover/gallery, без дубликатов/пустых URL; fallback для отсутствия
  или ошибки media. Геометрия и существующий Class accent сохраняются.
- Header: название, направление, level/kind/delivery, языки при наличии,
  дата/место только из своего контекста, без fixture strings в renderer.
- Metrics: объявленная цена с unit, размер группы, duration с unit.
  Как в preview: <2 известных значений → strip скрыт; ≥2 → только известные
  значения. Не добавляем выдуманную третью колонку.
- Teacher: identity по §3.2. About: full → short + публичные outcomes.
- Schedule: объявленные даты в timezone контекста, корректный конец через
  полночь; notAnnounced — честный текст, не fake timeline.
- Materials/requirements скрыты при пустом содержимом. Остальные optional
  подписи также presence-based.
- Footer зависит только от typed enrollment state/callback, не от догадок
  renderer о цене, времени или capacity.

Golden обновляется с typed fixture, а не простым принятием нового baseline:
визуально проверить header, price units, teacher/publisher и info-only footer.

## 6. План файлов — только после approval

Новые production-файлы:

1. `apps/mobile/lib/features/discover/domain/entities/published_class_workshop_discovery_entity.dart`
   — listing и небольшие собственные typed value objects §3/4.
2. `apps/mobile/lib/features/discover/domain/repositories/published_class_workshop_discovery_port.dart`
   — getActiveClassWorkshop(offeringId).
3. `apps/mobile/lib/features/discover/data/datasources/published_class_workshop_discovery_local_datasource.dart`
   — read-only fixtures, hidden/not-found/malformed, стабильные даты.
4. `apps/mobile/lib/features/discover/data/repositories/class_workshop_details_lookup.dart`
   — classification и проверка requested id = returned offeringId.
5. `apps/mobile/lib/app/presentation/class_workshop_details_page.dart`
   — injected launcher/analytics/timezone, Share/Map/external coordination.

Изменяемые production-файлы:

- `apps/mobile/lib/app/application/details_lookup_registry.dart` — comment/status;
- `apps/mobile/lib/app/application/details_resolution_providers.dart` — Class port;
- `apps/mobile/lib/app/di/service_locator.dart` — registration, без ремонта Create;
- `apps/mobile/lib/app/router/app_router.dart` — typed Class branch, safe fallback;
- `apps/mobile/lib/features/discover/presentation/renderers/object_offer_details_renderer.dart`
  — заменить только Class preview constructor/storage/dispatch/widgets;
- `apps/mobile/lib/features/discover/presentation/renderers/object_offer_section_matrix.dart`
  — Class runtime comment, не порядок;
- `apps/mobile/lib/features/discover/presentation/renderers/object_offer_visual_preview_props.dart`
  — удалить лишь после `rg`-подтверждения нулевых consumers; используемый
  `ClassWorkshopScheduleItem` заменить собственным runtime/presentation row
  без raw-time бизнеса в widget. Не удалять нужный shared primitive по имени Preview.

Тесты:

- `apps/mobile/test/unit/published_class_workshop_discovery_entity_test.dart`;
- `apps/mobile/test/unit/published_class_workshop_discovery_local_datasource_test.dart`;
- `apps/mobile/test/unit/class_workshop_details_resolution_test.dart`;
- `apps/mobile/test/widget/class_workshop_details_page_test.dart`;
- `apps/mobile/test/fixtures/class_workshop_details_fixture.dart` — общий typed
  fixture для unit/page/renderer/golden; production его не импортирует;
- существующие `apps/mobile/test/features/discover/presentation/renderers/`
  `object_offer_details_renderer_class_workshop_test.dart`,
  `object_offer_class_workshop_visual_golden_test.dart` и его Class golden;
  второй `goldens/object_offer_class_workshop_info_reference.png` фиксирует
  утверждённое состояние без primary action.

Docs: execution log в этом файле, родительский runtime plan и
`docs/architecture/LAUNCH_STATUS.md`. Визуальный план исторически самостоятелен.
Shared primitive/shell изменения не планируются; необходимость такого
изменения требует сначала уточнения file map и regression impact.

## 7. Этапы реализации и acceptance criteria

1. **Read model.** Constructor/privacy/location/price/instructor/schedule
   invariants; positive/free/unknown, single/series/notAnnounced, immutable lists.
2. **Read path.** Port/datasource/lookup: found/unknown/hidden/malformed;
   wrong id и wrong type fail closed без fallback scan. Demo явно обозначено,
   info-only по умолчанию; не создавать выдуманный действующий booking URL.
3. **Runtime wiring.** DI/registry/router → typed page; no Create imports,
   no Class preview fallback. Canonical path и injected dependencies проверены.
4. **Visual + actions.** Матрица/optional sections, честные units,
   separate teacher/publisher, Share, public-point Map, exact external URI,
   launch failure и все info-only states. Нет no-op или ложного обещания места.
5. **Adaptive/golden.** 360/375dp/150%, длинный контент, no/one/many media,
   длинная серия без потери строк, online/hidden/unknown price, RTL не заявлять
   готовым без тестов; проверить полную прокрутку и sticky safe-area.
6. **Object + neighbors.** Все шесть композиций/golden; Rental page/CTA/
   availability/pricing/projection; Route renderer/canonical, Scenario
   fail-closed, Collection page/mini-map, DetailsShell default/immersive/a11y.
7. **Gates.** Scoped и full analyze/test, boundary 0 с прежним budget,
   diff check, `rg` на preview consumers/запрещённые imports. Ошибки другого
   WIP не исправлять молча и не называть зелёными.
8. **Checkpoint.** Обновить статус runtime 6/6 только после доказанного
   подключения; `Done` — только после всех gates и итогового visual review.

На дату подготовки предыдущий общий прогон: analyzer 40 issues, tests
897 passed / 58 load failures в Create/Identity. Это историческая точка,
не результат будущего Class slice. Перед реализацией перепроверить checkout.

## 8. Rollback

Вернуть Class registry/router к unavailable, удалить только Class
registration/page/port/lookup/projection, восстановить Class preview fixture
и constructor из снимка перед slice. Не трогать persisted Create drafts,
соседние verticals и чужой WIP. Не применять whole-file rollback renderer/DI.

## 9. Решения, требующие подтверждения

1. Первый Class runtime — узкий live single/fixed-series read slice с одним
   согласованным display context; расширенные cohort/on-demand варианты позже.
2. External enrollment либо явный information-only footer; никакого internal
   Booking. Цена всегда с единицей, размер группы не равен оставшимся местам.
3. Publisher и instructor различаются; уточнение их показа остаётся внутри
   teacher-карточки. Остальной visual language и section order сохраняются.
4. Save пока отсутствует; Map только public point; Share canonical.
5. Discover-owned local/mock, без Create publication adapter; demo по умолчанию
   без мёртвой ссылки «записи». Успешный handoff проверяется injected launcher.

Approval получен 2026-09-08; реализация не расширяет пять решений выше.

## 10. Execution log — 2026-09-12

Статус реализации: **Review**, не Done. Class / Workshop подключён как
шестой local/mock Object / Offer тип; большой Create/Booking контракт
остаётся за пределами этой реализации.

### Реализовано и проверено

- Discover-owned immutable projection, отдельные price/enrollment/schedule/
  instructor/location варианты, стабильный display context, UTC/order/unique/
  overlap invariants. Precision цены передаётся source и форматируется без
  floating-point вычислений; есть проверки 0/2/3 десятичных позиций.
- Port/local datasource/lookup, requested-id guard и проверка IANA timezone
  через существующий TimezoneRepository; wrong id/type/unknown/hidden/error
  и Scenario ref fail closed.
- Registry/DI/canonical Class router branch, boundary-safe page и typed
  `.classWorkshop`. Private `_ClassWorkshopDisplay` форматирует typed entity;
  это не публичный preview API и не альтернативный путь загрузки данных.
- Share canonical, public-point Map, external URI без модификации, видимый
  false/PlatformException failure с retry, четыре info-only состояния,
  allowlisted analytics и отсутствие Save/internal Booking.
- Существующие section order/accent/карточки сохранены; Publisher и teacher
  различаются, дата/цена/duration имеют правильный scope, нет false availability.
- Cover/gallery и image failure fallback; два typed golden (external и
  info-only), 360/375dp/150%, длинная серия, unknown optional facts, overnight.

При проверках найдены и исправлены: переполнение disclosure+CTA внутри
фиксированной высоты общего sticky primitive и сужение кнопки после выноса
disclosure. Исправление находится только в Class footer. `DetailsShell` и
общий visual primitive не менялись; ширина CTA теперь проверяется тестом.
Оба итоговых golden просмотрены: external CTA занимает полную ширину,
информационное состояние не содержит фиктивную кнопку.

### Gates

| Gate | Результат |
|---|---|
| Model/datasource/resolver | 13/13 passed |
| Первичный page + renderer после overflow fix | 18/18 passed |
| Финальный общий Object/Offer + Rental + Route renderer + shell + typed resolvers | 171/171 passed; повторно подтверждено 2026-09-15 на текущих файлах, включая финальные Class precision/width tests и оба golden |
| Scoped analyzer (16 production/wiring/test targets) | 0 issues |
| Full mobile analyzer | 40 issues в существующем Create/Identity WIP и его DI wiring; повторно подтверждено 2026-09-15, Class/renderer/wiring ошибок нет |
| Full mobile test, запуск 2026-09-12 | 928 passed / 58 failed; все 58 — load/compile failures существующего Create/Identity baseline |
| Boundary | 0 violations, 71/71, без новых исключений; повторно подтверждено 2026-09-15 |
| Diff check | clean |

Runtime registration/page/lookup проверены по отдельности и статически в
router. Полный app smoke/Collection/parity не объявляются пройденными:
общий DI по-прежнему не компилируется из-за `moderationRepository` и
сопутствующих Create несоответствий. Чужой WIP не исправлялся.

Полный suite завершился, его результат перечитан 2026-09-15. Он запускался
параллельно с последними Class width/price-format уточнениями; финальный
код и golden покрыты последующим focused suite. Результат 928/58 не является
успешным repo-wide gate, а отсутствие ошибок в scoped analyzer не заменяет
сборку всего приложения.

### Удаление preview и восстановление

`object_offer_visual_preview_props.dart` удалён только после перевода всех
consumers; `rg` по lib/test не находит прежний файл, Class preview constructor
или `ClassWorkshopVisualPreviewProps`. Private shared `_Preview*` widgets
остались, поскольку используются реальными runtime-композициями.
Старый файл был untracked, поэтому для rollback исходник сохранён отдельно:
`C:/Users/User/AppData/Local/Temp/recharge-class-preview-props-before-removal-20260912.dart`.
Не полагаться на `git restore` для восстановления untracked файла.

### Осталось до общего Done

Владелец продукта подтвердил показанный Class visual 2026-09-15
(«да. дальше»). Visual-review больше не является открытым условием этого
Class slice; это не отменяет непрошедшие integration gates.

Устранить отдельно существующий Create/Identity baseline, повторить full
analyze/test и Collection/parity/app-route smoke. Никакой Firebase/provider
integration, Save, cohort selection или
on-demand runtime не заявляется готовым.
