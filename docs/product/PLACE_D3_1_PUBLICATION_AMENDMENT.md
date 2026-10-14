# D3.1 — Place через Create, Content, Media и модерацию (только Emulator)

Статус: **Review (2026-10-10), Windows-local Emulator evidence (§11).**
Ветка `claude/d3-1-place` от `8a6c2de` (D2), отдельный worktree.

Документ разделён на три независимые части, и итог каждой оценивается
отдельно:

- **A. Emulator publication lifecycle** — что сервер делает с Place;
- **B. Совместимость с формой Create** — **проверенное подмножество**:
  какие черновики формы Create доходят до сервера и какие нет; полная
  совместимость существующей формы Create **не объявляется**;
- **C. Готовность Catalog/Discover** — оценка без изменений; D3.1 её не
  повышает.

Зелёный результат части A не означает совместимости B, и ни A, ни B не
означают готовности C.

## 0. Основание и граница

Заход D3.1 — «только Place»: подключить принятый Place validator,
включение только в Emulator, полный lifecycle C3 и существующий mobile Create
flow. Тип без валидатора остаётся выключенным. Activity, Rental и Collection
не затрагиваются.

Опора в коде (на `8a6c2de`):

- валидатор `place_rules.ts` (PLACE_CREATE_BLOCK_SPEC v1.0 §9.2/§10.2)
  зарегистрирован в `content_type_registry.ts` как `available`
  (`sourceAuthority`: PLC-ADP-01 v1.0);
- Content, Media и модерация C2 не зависят от типа; порт справочных данных
  получает `typeId`;
- барьеры «только Event» сейчас в трёх местах: композиция Content
  (`enabledTypes: {event}`, `content_entry.ts`), Catalog/Discover
  (`catalogEnabledTypes`) и mobile (тестовый путь C3 только для Event).

Не входит: изменения валидатора и реестра типов, контракта ответа Content,
Catalog/Discover для Place (BCK08-OD-04), форма Create и её локальная
публикация, облако и deploy, Activity/Rental/Collection, типы без валидатора.

## 1. Решения владельца (2026-10-10)

1. Mobile: **отдельный Place-путь** по образцу C3. Event-контроллер, панель и
   их доказательства C3/E2/F2 не меняются; общий шлюз Content получает только
   параметр `typeId` и чтение `createdByUserId`.
2. Медиа: **обложка и галерея** через путь Media C1.
3. Catalog/Discover: **не включать**; только доказать, что Place туда не
   попадает (OD-04 открыт).
4. Основа: коммиты D1-L, исправления стенда и D2, затем отдельный worktree.
5. Ревью поправки:
   - **Q1** — автор из `createdByUserId` серверного черновика; восстановление
     после сбоя между `createDraft` и `updateDraft` без второго черновика;
     журнал привязан к владельцу Session и publisher, чужая запись после смены
     аккаунта не используется (§5.4, §5.6).
   - **Q2** — отправляются активные поля по существующей `PlaceCreationPolicy`;
     неактивные значения остаются в локальном черновике; их исключение из
     отправки проверяется тестами (§5.3).
   - **Q3** — допустимо только как ограничение тестового пути: общий
     `validation_failed` остаётся; часть B — проверенное подмножество; полная
     совместимость формы Create не объявляется (§5.7).
   - **Q4** — mobile без Activate и правки после публикации; полный lifecycle
     подтверждается отдельно на бэкенде (§3).
   - Уточнения до кода: точные UUIDv5 и ключи медиа со стабильным id вложения
     (§5.5); минимальная реалистичная фикстура справочников с проверками
     неприменимой подкатегории и отсутствующего обязательного критерия (§2.3);
     явная матрица операций после выключения Place (§2.2); тесты по их уровню,
     интеграционные — с регистрацией в layout guard (§8).

---

## Часть A. Emulator publication lifecycle

### 2.1 Включение

- Новый флаг `content.place.authoring` (`contentFlagIds.placeAuthoring`),
  выключен по умолчанию, только `local`/`LV` в Emulator.
- `content_entry.ts`: список допустимых для Emulator типов
  `emulatorAuthoringTypes = ['event', 'place']` и функция
  `authoringTypesFor(флаги)`: `event` ← `content.event.authoring`, `place` ←
  `content.place.authoring`. Композиция принимает `enabledTypes` (по умолчанию
  `{event}` — все текущие вызовы и тесты не меняются) и **отказывается
  собираться**, если в наборе есть тип вне списка или тип без валидатора
  (`!isContentTypeAvailable`). «Тип без валидатора выключен» обеспечено
  структурно, а не только проверкой в сервисе.
- `contentCommandV1` / `contentQueryV1` после Session строят набор из флагов и
  передают его в композицию этого вызова.

### 2.2 Матрица операций

Два уровня, оба осознанные:

- **вход Content** открыт, если включён хотя бы один флаг authoring; иначе
  любой вызов — `type_disabled` (как сейчас для Event);
- **флаг типа** закрывает операции, которые создают или меняют публикуемое
  содержимое: `createDraft`, `updateDraft`, `submitForPublication`,
  `publishApprovedRevision`, `activatePublishedRevision` — `type_disabled`
  (существующий `usableType`). Скрытие владельцем (`withdrawPublication`) и
  чтение владельцем (`getDraft`, `getPublicationStatus`,
  `getPublishedRevision`) флагом типа не закрываются: владелец всегда может
  увидеть и снять своё.

| Флаги Event / Place | Place: save, submit, publish, activate | Place: hide | Place: чтение владельцем | Event |
|---|---|---|---|---|
| выкл / выкл | `type_disabled` (вход закрыт) | `type_disabled` | `type_disabled` | `type_disabled` (как сейчас) |
| вкл / выкл | `type_disabled` | разрешено | разрешено | как сейчас |
| выкл / вкл | разрешено | разрешено | разрешено | save…activate — `type_disabled`; hide и чтение разрешены |
| вкл / вкл | разрешено | разрешено | разрешено | разрешено |

Флаги authoring не управляют staff-модерацией (C2) и реакцией D2 на
ограничение Media: подавление и снятие с публикации действуют и при
выключенном флаге Place.

### 2.3 Справочные данные Place в Emulator

Синтетические константы (`EmulatorSyntheticReferenceData`) для Place заменяются
минимальной реалистичной фикстурой; для остальных типов ответы не меняются
(Event-тесты используют произвольные подкатегории).

- Фикстура — подмножество существующей таксономии mobile
  (`recharge_taxonomy_seed.dart`, `recharge_category_criteria.dart`):

  | Группа | Подкатегория | Применима к Place | Обязательные критерии |
  |---|---|---|---|
  | `art_culture_museums` | `museum`, `gallery` | да | — |
  | `art_culture_museums` | `artist_talk` | **нет** (только event) | — |
  | `outdoor_nature_walking` | `park`, `lake` | да | `difficulty` |

  Ревизия таксономии для Place — `test-only-tx-place-1`. Неизвестная пара
  группа/подкатегория — неприменима. Это не принятая таксономия BCK-20:
  фикстура доказывает только, что Content применяет применимость и
  обязательные критерии, а не правильность категорий.
- Канонический файл фикстуры —
  `packages/api_contracts/schema/content/v1/fixtures/place_reference_taxonomy.json`;
  константа бэкенда сверяется с ним (unit), а Dart-тест сверяет файл с
  таксономией mobile (применимость к `place` и `requiredFieldIds` профиля).
- Проверки: неприменимая подкатегория → `place.subcategory.not_applicable`;
  отсутствующий обязательный критерий → `place.criteria.required_missing:difficulty`
  (unit по валидатору с фикстурой); те же тела через Emulator →
  `validation_failed`; корректный Place с `difficulty` проходит.

### 3. Шаги lifecycle

| Шаг | Команда / путь | Кто решает | Отказы (примеры) |
|---|---|---|---|
| 1. Черновик | `createDraft` (`typeId: place`), `updateDraft` | Identity: Session, verified Creator, точная Page | `type_disabled`, `publisher_not_eligible`, `capability_denied`, `revision_conflict` |
| 2. Медиа | Media C1: Session → bytes → confirm → finalize, привязка к точному черновику (обложка и каждое фото) | Media | отказ или недоступность Media |
| 3. Submit | `submitForPublication` | Content: валидатор Place со справочниками §2.3, readiness всего набора медиа (`placeMediaIds`) | `validation_failed` (без кодов `place.*`), `media_not_ready` |
| 4. Review | staff C2 (approve / reject / restrict) | модерация C2, тестовый реестр staff | `moderation_decision_stale` |
| 5. Публикация | `publishApprovedRevision` | Content: повторная валидация и readiness | `validation_failed`, `moderation_required`, `revision_conflict` |
| 6. Скрытие | `withdrawPublication` (владелец) | Content | `revision_conflict` |
| 7. Возврат | `activatePublishedRevision` | Content: тип, справочные данные и медиа ревизии | `content_type_unsupported`, `media_not_ready` |
| 8. Правка | `updateDraft` → submit → review → publish переключает указатель | как 1–5 | как 1–5 |

Шаги 7 и 8 подтверждаются только бэкендом (Q4). Повторы с тем же ключом
идемпотентны: те же результаты, без лишних ревизий и эффектов. Устаревшая
ревизия черновика или указателя отклоняется.

### 4. Эффекты и соседние модули

- Эффекты публикации и видимости Place создаются тем же путём, что у Event.
- **Catalog**: факт Place доходит через триггер E2 и фиксируется как
  `excluded: type_disabled`; rebuild и rollback это сохраняют. Discover
  отклоняет `typeIds: [place]` как неподдерживаемый (`type_disabled:place`).
- **Booking**: handoff пропускает эффект не-Event (0 фактов).
- **D2**: медиа Place подпадают под D2. Ограничение фото галереи сразу
  закрывает его выдачу (`mediaDeliveryV1`), Content подавляет его по состоянию
  Media (`suppressedMediaIds`), снятие ограничения требует активации издателем.
  Подавление живёт только в указателе Content: Catalog Place не проецирует.
  Окна W1–W6 из D2 действуют и для Place.

### 4.1 Что не меняется в части A

`place_rules.ts`, `content_type_registry.ts`, сервис Content, контракт ответа
Content, Catalog (`catalogEnabledTypes`), Discover, Booking, `firestore.rules`,
`emulator-stand.mjs`, общий набор флагов стенда. Стражи `verify-*` не
ослабляются; `verify-r1-layout.mjs` получает только регистрацию нового
интеграционного теста (§8).

---

## Часть B. Совместимость с формой Create (проверенное подмножество)

### 5.1 Источник и путь

- Источник — текущий черновик Create пользователя
  (`CreateRepository.loadDraft(accountId)`), только `objectType == place` с
  `placeData`. Форма Create, её автосохранение и локальная публикация
  `pending_review` **не меняются**: локальная публикация и серверный тестовый
  путь независимы, их состояния не синхронизируются.
- Тестовый вход: define `RECHARGE_TEST_PLACE_PUBLICATION=true`, не release,
  binding `testBackend`, endpoint — loopback `demo-recharge/europe-west1`. Все
  четыре условия одновременно; тот же guard защищает маршрут, каждую команду
  Content и каждую загрузку Media.
- Панель «Place publication (test)»: Save, Upload media, Submit, Refresh,
  Publish, Hide и список «мои места» (до 20, статус с сервера). Activate и
  правки после публикации на mobile нет (Q4).

### 5.2 Таблица полей: черновик Create → тело Content Place

| Тело Content | Источник в Create | Правило |
|---|---|---|
| `title` | `draft.title` | trim |
| `placeKind`, `relationshipToPlace` | `placeData` | имена enum совпадают |
| `shortDescription` | `draft.shortDescription` | trim; пусто → поле не отправляется |
| `fullDescription` | `draft.fullDescription` | trim; пусто → не отправляется |
| `contentLocale`, `languages` | `placeData` | список отсортирован; пусто → не отправляется |
| `categoryId`, `subcategoryId` | `draft.mainCategory`, `draft.subcategory` | как есть (id группы и подкатегории таксономии mobile) |
| `tags` | `draft.tags` | пусто → не отправляется |
| `criteria` | `draft.sectionData['criteria']` | только активные критерии; `inactive_place_criteria` остаётся локально |
| `location.*` | `placeData.location` | имена совпадают; `latitude`/`longitude` → `point`; `geocodedAtUtc` → ISO; `addressComponents` в Create нет |
| `hours.mode`, `weeklyPeriods`, `exceptions` | `placeData.hours` | `id` → UUIDv5 (§5.5); `seasons` в Create нет |
| `operationalStatus` | `placeData.operationalStatus` | `closedFromLocalDate` → `startLocalDate`, `closedUntilLocalDate` → `endLocalDate` |
| `visitPlanning` | `placeData.visitPlanning` | имена совпадают; `bestTimeWindows` в Create нет |
| `amenityIds`, `amenityUnknownIds` | `placeData` | отсортированные списки |
| `pricing` | `placeData.pricing` | `Money` → целые minor units; `currencyCode` как есть |
| `contacts` | `placeData.contacts` | `websiteUrl` → `website`; остальное как есть |
| `media.coverImage.mediaId`, `media.gallery[].mediaId` | `draft.media` | asset id Media после загрузки; до неё `loc_` + id вложения (§5.5) |
| `provenance.sourceType`, `createdAtUtc`, `lastConfirmedAtUtc`, `*ConfirmedAtUtc` | `placeData.provenance` | ISO |
| `provenance.relationshipClaim` | `placeData.relationshipToPlace` | то же значение, выбранное пользователем |
| `provenance.submittedByUserId` | — | автор из записи черновика на сервере (§5.4) |

Не отправляются (только локальные): `schemaVersion`, `revision` черновика
Create, `categoryConfirmed`, `acceptedWarningCodes`, кандидаты дублей,
предложения Creator Assist, общие поля `CreateDraftEntity`, не относящиеся к
Place (расписание, `venueName`, `basePrice` и т. п.). `publisherRef` идёт в
команду `createDraft`, а не в тело.

### 5.3 Правила маппера

- Ничего не придумывается и ничего не теряется молча. Поле, которое Content
  Place не может принять, означает отказ без отправки:
  `unsupported_capability:<поле>`. Так обрабатываются `hours.mode == seasonal`
  (Phase 2; локальный валидатор Create тоже его не пропускает) и непустой
  `placeData.unknownFields` (черновик более новой схемы).
- **Активные поля (Q2).** Отправляется только то, что форма Create сама
  считает активным при текущей `PlaceCreationPolicy` (та же политика и тот же
  выбор профиля, что у локального валидатора). Неактивные значения
  остаются в локальном черновике, маппер их не удаляет и не отправляет:

  | Неактивное значение | Когда |
  |---|---|
  | `sectionData['inactive_place_criteria']` | всегда (критерии прежней категории) |
  | `operationalStatus.closedFrom/UntilLocalDate` | статус не `temporarilyClosed` |
  | `pricing.entryPriceFrom/To` | `entryType` не `paid`/`mixed` или `admission == hidden` |
  | `pricing.typicalSpendFrom/To` | `typicalSpend == hidden` |
  | `pricing.pricingNote`, `officialPricingUrl` | `admission` и `typicalSpend` оба `hidden` |
  | `visitPlanning` | `visitPlanning == hidden` |
  | `contacts` (кроме `bookingUrl`) | `contacts == hidden` |
  | `contacts.bookingUrl` | `booking == hidden` |
  | `hours` | `hours == hidden` |
  | `location.entranceHint` | `accessNote == hidden` |
  | `amenityIds`, `amenityUnknownIds` | `amenities == hidden` |

  Каждая строка — отдельный тест: значение есть в локальном черновике после
  отображения, его нет в отправленном теле.
- `relationshipClaim` — выбранный пользователем `relationshipToPlace`.
  `sourceType` отправляется как в черновике; несоответствие сервер отклоняет.

### 5.4 Автор (`submittedByUserId`) и восстановление (Q1)

Валидатор требует `provenance.submittedByUserId ==` userId аутентифицированного
актора. Mobile не хранит серверный userId
(`BookingIdentitySessionContext.fromServerResponse` отбрасывает User), поэтому
автор берётся из `createdByUserId` в `ContentDraftV1` — собственной записи
сервера об авторе черновика. Сервер сам сверяет автора при submit и publish;
правила Place проверяются только там, поэтому черновик без автора допустим.

Первое Save — два шага:

1. `createDraft` с **пустым телом `{}`** и стабильным ключом (§5.5). Тело
   всегда одинаковое, поэтому повтор того же ключа возвращает тот же черновик
   и не встречает `idempotency_conflict`, даже если пользователь изменил
   черновик между попытками.
2. Запись в журнал: `contentId`, `draftId`, ревизия, `serverOwnerUserId =
   createdByUserId`, `authorApplied = false`.
3. `updateDraft` с полным телом и автором; журнал: `authorApplied = true`.

Восстановление:

- сбой после ответа сервера на шаг 1, до записи в журнал: следующее Save
  повторяет `createDraft` с тем же ключом и получает тот же черновик;
- сбой после шага 2, до шага 3: следующее Save видит `authorApplied = false`
  и выполняет только `updateDraft`;
- сбой `updateDraft`: повтор с той же ожидаемой ревизией.

Во всех случаях на сервере ровно один черновик (проверка — unit контроллера с
отказами шлюза и Emulator-тест с повтором `createDraft`).

### 5.5 Идентификаторы и ключи

Namespace UUIDv5 пути Place: **`7dd283c2-0e3c-41e1-b60f-7ed6bb9e0735`**
(фиксирован в коде и в тестах).

Область (scope) — владелец, publisher и черновик:

```text
scope = recharge:place-publication:v1:<accountId>:<publisherType>:<publisherId>:<localDraftId>
```

`accountId` — id вошедшего аккаунта, которым панель открывает черновик Create.

| Идентификатор | Имя UUIDv5 |
|---|---|
| период недели | `<scope>:period:<localPeriodId>` |
| исключение | `<scope>:exception:<localExceptionId>` |
| период исключения | `<scope>:exception:<localExceptionId>:period:<localPeriodId>` |
| вложение-обложка | `<scope>:attachment:cover` |
| вложение галереи | `<scope>:attachment:gallery:<localMediaRef>` |
| загрузка (Media intent) | `<scope>:upload:<attachmentId>:<sha256 байтов>` |

- Id вложения галереи стабилен для ссылки на фото в черновике Create
  (`draft.media.gallery[i]`), а не для позиции: перестановка фото не меняет
  ключи и не вызывает повторных загрузок; порядок в теле следует черновику.
- Замена байтов того же вложения → новый id загрузки → новый asset; старый
  перестаёт упоминаться в теле и уходит в сверку R2 (D2).
- Ключи идемпотентности Content: `pp1-<первые 24 hex SHA-256(scope)>` и суффикс
  `:create`, `:update:<ревизия>:<16 hex SHA-256 тела>`, `:submit:<ревизия>`;
  публикация `<submissionId>:publish`, скрытие `<contentId>:withdraw:<ревизия
  указателя>` (как у Event).
- Заглушка медиа до загрузки — `loc_<attachmentId>`; сервер не пропустит её
  при submit (`place.local_id_unreplaced`).

### 5.6 Журнал

Файл `content/place-publications-v1.json`. Запись: `accountId`,
`publisherRef`, `localDraftId`, `contentId`, `draftId`, ревизия,
`serverOwnerUserId`, `authorApplied`, вложения (`attachmentId`, asset id,
SHA-256), `submissionId`.

- Используется только запись с тем же `accountId` и `publisherRef`, что у
  открытого черновика; список «мои места» показывает только записи текущего
  аккаунта. Чужие записи не удаляются, но не используются.
- Если сервер вернул черновик с другим `createdByUserId`, чем
  `serverOwnerUserId` записи, или отказал владельцу, запись считается чужой и
  не используется.

### 5.7 Расхождения правил: форма Create допускает → сервер отклоняет (Q3)

Локальный валидатор Create адаптивен (PLC-ADP-01): требования зависят от
профиля. Серверный валидатор следует строгим правилам v1.0 §10.2. Даже
базовый профиль (`safeFallback`) делает обложку «recommended», часы и цены —
«optional». Ответ сервера при нарушении — только `validation_failed`: коды
`place.*` клиенту не передаются (`toContentWireResult` отдаёт один `code`), и
панель показывает общий отказ.

| Случай в Create | Внутренний код валидатора |
|---|---|
| нет обложки (профиль не требует) | `place.media.cover_missing` |
| короткое описание пустое или 10–19 символов | `place.shortDescription` |
| режим часов не выбран (профиль не требует) | `place.hours` |
| тип входа не выбран (секция цен optional) | `place.pricing.entryType` |
| валюта черновика ≠ валюте рынка | `place.pricing.currencyCode` |
| телефон с буквами или > 15 цифр (Create проверяет только ≥ 7 цифр) | `place.contacts.phone` |
| `sourceType` не соответствует `relationshipToPlace` | `place.provenance.sourceType` |
| точка вне зоны рынка по bounding box (Create считает радиус от центра) | `place.location.outside_service_area` |
| подкатегория неприменима к Place (фикстура §2.3) | `place.subcategory.not_applicable` |
| нет обязательного критерия (фикстура §2.3) | `place.criteria.required_missing:<id>` |

Это ограничение тестового пути. Часть B подтверждает **проверенное
подмножество**: черновики по строгим правилам v1.0 со справочниками §2.3
проходят, перечисленные случаи отклоняются. Полная совместимость формы Create
не объявляется; согласование адаптивных правил PLC-ADP-01 с BCK-07 и передача
кодов нарушений клиенту — отдельные решения (§9).

Каждая строка таблицы проверяется цепочкой без раскрытия кодов на проводе:
файл `packages/api_contracts/schema/content/v1/fixtures/place_create_compat.json`
хранит для каждого случая точное тело, которое выдаёт маппер, и ожидаемые
коды; Dart-тест маппера сверяет свой вывод с телом; TS-тест сверяет
`validatePlaceBody(тело)` с кодами; Emulator-тест отправляет тело и получает
`validation_failed`. Тот же файл содержит корректный случай.

**Обновление 2026-10-14 (заход 3 пересмотра M1).** Фактическая матрица, решения
3-А и 3-Б и проверки — [M1_STAGE3_CREATE_COMPAT.md](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md).
Семь разрывов этой таблицы закрыты клиентскими портами серверных правил. Сервер теперь передаёт публичные код и поле (`expectedViolations` в
`place_create_compat.json`); форма Create при включённом серверном пути заранее
показывает требования, контроллер не отправляет заведомо отклоняемый submit.
Серверные правила не ослаблены; локальные правила формы не менялись.

### 5.8 Медиа

- Обложка и до 12 фото — каждое через `mediaUploadGatewayFor` (Media C1) с
  привязкой к `contentId` черновика и ключами §5.5: те же байты того же
  вложения повторяют ту же загрузку и не создают новый asset.
- Байты читаются тем же файловым источником, что у обложки Event
  (`FileEventCoverSource`, без изменений).

### 5.9 Что остаётся как было в части B

Форма Create, её валидатор и политика профилей, локальная публикация, поиск
дублей (только локальный: на сервере его нет), Creator Assist, Discover на
локальных данных Place.

---

## Часть C. Готовность Catalog/Discover

### 6.1 Сейчас (без изменений в D3.1)

- Catalog: `catalogEnabledTypes = {event}`; факт другого типа получает
  `excluded: type_disabled`. Модели элемента и запроса Catalog имеют форму
  Event (`typeId: 'event'` в `catalog_item.ts` и `catalog_query_service.ts`).
- Discover (`discoverQueryV1`): тип вне включённых — неподдерживаемый.
- Mobile Discover показывает Place из локального источника
  (PLACE_CREATE_BLOCK_SPEC §14).
- BCK08-OD-04 (типизированные семейства Feed/Map/Search/Details для десяти
  типов) — открыт, тип выключен.

### 6.2 Что докажет D3.1

Опубликованный Place не попадает в Catalog и Discover: факт исключается с
причиной, rebuild/rollback исключение сохраняют, запрос Discover с Place
отклоняется, Booking не получает фактов.

### 6.3 Чего не хватает для готовности (вне D3.1)

1. Решение BCK08-OD-04 для Place.
2. Проекция Place в Catalog: схема элемента (часы и «открыто сейчас»,
   удобства, цены, локация), фильтры, ключи сортировки, tombstones.
3. Перенос подавления D2 в факты Place (обложка и галерея).
4. Details Place из Catalog и mobile Discover вместо локального источника.
5. Ранжирование, свежесть и лимиты (OD-05/08/10), серверная проверка дублей,
   принятая таксономия BCK-20.

**Вывод:** Catalog/Discover для Place **не готовы**; D3.1 это не меняет.

---

## 7. Стенд и гейт D3.1

- Флаг `content.place.authoring` на стенде включает только команда
  `stand-seed.mjs place seed`, а не общая загрузка флагов: состояние и digest
  остальных гейтов не меняются.
- `place seed` проводит фиксированный Place (`outdoor_nature_walking/park`,
  критерий `difficulty`) через Content: черновик `{}` → обложка и два фото →
  полное тело с автором → submit → одобрение staff → публикация. Ключи
  фиксированы; повтор и возобновление переиспользуют результаты. Точка
  прерывания для гейта — после первого фото галереи
  (`STAND_SEED_INTERRUPT_AFTER=gallery-1`). Ids пишутся в манифест стенда
  (`contentPlace`).
- `place verify`: указатель видим, readiness набора медиа равна ids тела,
  факт Catalog `excluded: type_disabled`, фактов Booking нет.
- `scripts/stand-d3-1-gate.mjs --yes`: свежий стенд → базовый seed → `place
  seed` → `place verify` → digest; свежий стенд → базовый seed → прерванный
  `place seed` → возобновление (`reused`) → digest = чистому → повтор → digest
  тот же; затем на этом ПК против стенда `place_publication_stand_test.dart` и
  `place_publication_ui_stand_test.dart` (с define); остановка проверяется.

## 8. Проверки

Тест лежит на своём уровне: чистые функции — `test/unit`; сервис Content с
in-memory портами — `test/integration` с регистрацией в
`verify-r1-layout.mjs`; Firestore, Storage и Functions Emulator —
`test/emulator`; стенд — гейт.

| № | Часть | Что | Уровень и файл |
|---|---|---|---|
| P1 | A | матрица §2.2 через `contentCommandV1`/`contentQueryV1`: каждая строка, каждая операция, конкретный код; флаги и Session восстанавливаются | Emulator (Functions): `content_place_callable.test.ts` |
| P2 | A | `authoringTypesFor`; композиция не собирается с типом вне списка или без валидатора | unit: `content_authoring_types.test.ts` |
| P3 | A | сервис: route, session, scenario, find_people, class_workshop → `content_type_unsupported` даже при попытке включить; activity, rental, collection → `type_disabled`; place с включённым набором — разрешён; hide и чтение без флага типа | integration: `content_place_enablement.test.ts` |
| P4 | A | справочники §2.3: константа = файл фикстуры; неприменимая подкатегория и отсутствующий критерий — коды валидатора | unit: `emulator_place_taxonomy.test.ts`, `type_rules_place_create_compat.test.ts` |
| P5 | A | lifecycle §3 полностью: черновик, медиа, submit, approve/reject/restrict, publish, hide, activate, правка после публикации, stale, повторы; справочники §2.3 через Emulator | Emulator: `content_place_emulator_flow.test.ts` |
| P6 | A | эффекты: Catalog `excluded: type_disabled` (и после rebuild/rollback), Discover отклоняет Place, Booking 0 фактов, D2 для фото галереи | Emulator: `content_place_emulator_flow.test.ts` |
| P7 | B | маппер: §5.2 построчно; §5.3 каждое неактивное значение (есть в черновике, нет в теле); `seasonal`, `unknownFields`; §5.5 UUIDv5 по namespace, стабильность при перестановке галереи, разные scope для другого аккаунта или publisher; вывод = тела общей фикстуры | unit (Dart): `place_content_body_mapper_test.dart` |
| P8 | B | цепочка §5.7: тело фикстуры → код валидатора (TS) → `validation_failed` (Emulator) | unit (TS) + Emulator |
| P9 | B | контроллер: закрытый вход ничего не отправляет; Save/Media/Submit/Publish/Hide; восстановление §5.4 (три сбоя, один черновик); журнал §5.6 (смена аккаунта, чужой publisher, чужой `createdByUserId`); идемпотентная загрузка | unit (Dart): `place_publication_controller_test.dart` |
| P10 | B | guard (четыре условия); шлюз: `typeId` (Event по-прежнему `event`), `createdByUserId` | unit (Dart): `place_publication_test_entry_guard_test.dart`, `content_publication_gateway_type_test.dart` |
| P11 | A+B | фикстура справочников = таксономия mobile | unit (Dart): `place_reference_taxonomy_fixture_test.dart` |
| P12 | A+B | стенд: чистый = прерванный и возобновлённый = повторный (digest) | гейт `stand-d3-1-gate.mjs` |
| P13 | B | mobile против стенда: контроллер и UI с define | гейт + `flutter test` |
| P14 | C | `catalogEnabledTypes` и модели Catalog не изменены (дифф пуст); P6 подтверждает исключение | ревью диффа + P6 |
| P15 | A | положительная выдача фото Place через шлюз D2 с реальными вариантами инструментов D1 (L1): реальные байты WebP (SHA-256 = манифест, без EXIF/GPS) до ограничения; отказ сразу после ограничения при ещё не отреагировавшем Content, другое фото по-прежнему выдаётся; отказ после снятия ограничения без активации — до и после реакции Content; снова реальные байты после активации издателем | Emulator + инструменты D1: `content_place_media_delivery.test.ts` в гейте D3.1 |
| P16 | A+B | digest стенда: устойчив к случайным id, порядку ассетов и счётчику вариантов поддельного обработчика; чувствителен к составу и порядку галереи, привязкам, ревизиям, подавлению и подтверждениям | unit (стенд): `stand_digest.test.ts` |
| R | — | регресс: все гейты (C1–C3, E1, E2, E2a, F1, F2, B2, mobile, acceptance, D1, D2), `test:emulator`, тесты без Emulator, `verify-*`, `api_contracts`, `flutter analyze`, `flutter test` | финальный прогон |

Финальные результаты — на одном зафиксированном отпечатке, одной таблицей:
гейт, результат, лог, ревизия.

## 9. Остаточные риски и открытые пункты

- Часть B — проверенное подмножество: правила PLC-ADP-01 (адаптивные) и
  BCK-07 (строгие v1.0) расходятся (§5.7). Решение владельца.
- Коды нарушений валидатора клиенту не передаются: при `validation_failed`
  пользователь не видит, какое поле отклонено (изменение контракта BCK-07).
- Справочники Place — тестовая фикстура (§2.3), не принятая таксономия
  BCK-20.
- Catalog/Discover для Place не готовы (часть C, BCK08-OD-04).
- Дубли мест проверяются только локально.
- Окна W1–W6 (D2) действуют для медиа Place; F2a (подписанные URL, CDN, кеш
  клиента) и OD-07 открыты.
- Activate и правка после публикации на mobile не выведены (Q4).
- Физические устройства, Linux, облако и production не покрыты.

## 10. Окончательная карта файлов (58)

Пути от корня репозитория. «М» — изменяемый, «Н» — новый. В колонке «Карта»:
«✓» — файл был в карте, принятой на ревью (52 файла); «+» — добавлен при
реализации, причина в той же строке. Код Activity, Rental, Collection,
валидатор Place, реестр типов, сервис Content, Catalog, Discover, Booking,
`firestore.rules` и `emulator-stand.mjs` не меняются.

### 10.1 Бэкенд: код (6)

| Файл | | Карта | Назначение |
|---|---|---|---|
| `apps/backend/functions/src/shared/feature_flags.ts` | М | ✓ | `contentFlagIds.placeAuthoring` |
| `apps/backend/functions/src/content_entry.ts` | М | ✓ | `emulatorAuthoringTypes`, `authoringTypesFor`, `enabledTypes` в композиции и `ContentCaller`, инвариант (§2.1) |
| `apps/backend/functions/src/index.ts` | М | ✓ | `prepareContentCaller`: набор типов из двух флагов (§2.2) |
| `apps/backend/functions/src/modules/content/infrastructure/emulator_reference_data.ts` | М | ✓ | для `place` — фикстура §2.3; остальные типы без изменений |
| `apps/backend/functions/src/modules/content/infrastructure/emulator_place_taxonomy.ts` | Н | ✓ | TEST-ONLY таксономия Place (§2.3) |
| `apps/backend/README.md` | М | ✓ | раздел D3.1 и флаг `content.place.authoring` |

### 10.2 Бэкенд: тесты, стенд, гейт (14)

| Файл | | Карта | Назначение |
|---|---|---|---|
| `apps/backend/functions/test/unit/content/content_authoring_types.test.ts` | Н | ✓ | P2 |
| `apps/backend/functions/test/unit/content/emulator_place_taxonomy.test.ts` | Н | ✓ | P4: константа = файл фикстуры |
| `apps/backend/functions/test/unit/content/type_rules_place_create_compat.test.ts` | Н | ✓ | P4, P8: тела фикстуры → коды |
| `apps/backend/functions/test/integration/content_place_enablement.test.ts` | Н | ✓ | P3 (зарегистрирован в layout guard) |
| `apps/backend/functions/test/emulator/content_place_callable.test.ts` | Н | ✓ | P1 и wire-часть P8 |
| `apps/backend/functions/test/emulator/content_place_emulator_flow.test.ts` | Н | ✓ | P5, P6 |
| `apps/backend/functions/test/emulator/content_place_media_delivery.test.ts` | Н | + | P15: реальные байты фото Place до ограничения, отказ после, отказ после снятия без активации, снова байты после активации (инструменты D1, L1); добавлен по ревью перед коммитом |
| `apps/backend/functions/test/support/content_place_world.ts` | Н | + | общий мир Emulator-тестов Place (акторы с Session, Media, Content); иначе три файла дублировали бы его |
| `apps/backend/functions/test/stand/stand_content_place.ts` | Н | ✓ | стендовый Place, seed с точками прерывания, verify, флаг |
| `apps/backend/functions/test/stand/stand_digest.test.ts` | Н | + | устойчивость и чувствительность digest (§10.4); добавлен по ревью перед коммитом |
| `apps/backend/functions/test/stand/stand_main.ts` | М | ✓ | команда `place` |
| `apps/backend/scripts/stand-seed.mjs` | М | ✓ | команда `place` в списке |
| `apps/backend/scripts/stand-d3-1-gate.mjs` | Н | ✓ | P12, P13, P15 |
| `apps/backend/functions/package.json` | М | ✓ | `test:emulator:inside` + два файла |

### 10.3 Контракты (2)

| Файл | | Карта | Назначение |
|---|---|---|---|
| `packages/api_contracts/schema/content/v1/fixtures/place_reference_taxonomy.json` | Н | ✓ | фикстура справочников §2.3 |
| `packages/api_contracts/schema/content/v1/fixtures/place_create_compat.json` | Н | ✓ | случаи §5.7 и корректный |

### 10.4 Общая инфраструктура: изменения вне файлов Place (7)

| Файл | | Карта | Что меняется и почему это безопасно |
|---|---|---|---|
| `apps/backend/functions/test/support/content_event_world.ts` | М | ✓ | вынесены `createPublishingActors` и `uploadReadyImage`; API мира Event прежний (все Event-тесты Emulator и гейт D2 проходят) |
| `apps/backend/functions/test/stand/stand_flags.ts` | М | ✓ | вынесен `enableStandFlag`; общий набор флагов стенда прежний |
| `apps/backend/functions/test/stand/stand_content_event.ts` | М | ✓ | необязательное поле манифеста `contentPlace` (тип) |
| `apps/backend/scripts/verify-r1-layout.mjs` | М | ✓ | регистрация одного интеграционного теста; страж не ослаблен |
| `apps/backend/functions/test/integration/content_publication_security.test.ts` | М | + | регистрация двух символов реестра типов для `content_entry.ts`; страж не ослаблен (`resolveContentType` уже разрешён источнику Catalog) |
| `apps/backend/scripts/run-emulator-tests.mjs` | М | + | предел набора `test:emulator` 600 → 900 с: набор шёл ~600 с уже до D3.1, первый финальный прогон оборван пределом |
| `apps/backend/functions/test/stand/stand_digest.ts` | М | + | метки id стендового Place; изменчивы только поля вариантов, которые поддельный обработчик берёт из счётчика процесса (`variantId`, `byteLength` внутри `variantRefs`); канонический порядок — только у списков, которые домен сам хранит отсортированными по assetId (`mediaAttachments`, `mediaConfirmations`, `mediaSuppression`; `mediaAssetIds` — только у опубликованных ревизий). Порядок галереи в теле и `mediaAssetIds` черновика не трогаются. Найдено гейтом (digest чистого и возобновлённого seed различался); чувствительность проверяет `stand_digest.test.ts` |

`stand_digest.test.ts`: другая серия случайных id, обратный порядок ассетов и
другие номера вариантов дают тот же digest; каждое из изменений — удаление фото
из ревизии, перестановка галереи в теле, иной порядок медиа черновика, привязка
фото к другому Content, другая ревизия в указателе, другое тело ревизии,
подавление фото, иная эпоха подтверждения, ограниченное фото, иная длина
исходника, иной профиль варианта — меняет digest (и с id другого прогона).
Иной порядок медиа черновика прежняя, более широкая нормализация скрывала бы.

### 10.5 Mobile (24)

| Файл | | Карта | Назначение |
|---|---|---|---|
| `apps/mobile/lib/features/create/domain/usecases/build_place_content_body.dart` | Н | ✓ | `PlaceContentBodyMapper`, `PlacePublicationScope` (§5.2, §5.3, §5.5) |
| `apps/mobile/lib/features/create/domain/entities/place_publication.dart` | Н | ✓ | запись журнала, вложения |
| `apps/mobile/lib/features/create/domain/repositories/place_publication_gateway.dart` | Н | ✓ | источник черновика, журнал, чтение черновика, гейт команд |
| `apps/mobile/lib/features/create/application/place_publication_controller.dart` | Н | ✓ | Save с восстановлением, Media, Submit, Refresh, Publish, Hide, «мои места» |
| `apps/mobile/lib/features/create/data/file_place_publication_journal.dart` | Н | ✓ | журнал, привязанный к аккаунту и publisher |
| `apps/mobile/lib/features/create/presentation/widgets/place_publication_section.dart` | Н | ✓ | секция панели |
| `apps/mobile/lib/app/presentation/place_publication_panel.dart` | Н | ✓ | страница и панель (test) |
| `apps/mobile/lib/app/di/place_publication_composition.dart` | Н | ✓ | guard (define), адаптер Media, источник черновика, фабрика |
| `apps/mobile/lib/features/create/data/functions_event_publication_gateway.dart` | М | ✓ | общий шлюз Content: `typeId` (по умолчанию `event`), чтение `createdByUserId`, `draft()`; для Event поведение прежнее (тест типа шлюза, гейты C3, E2, F2) |
| `apps/mobile/lib/features/create/domain/entities/event_publication.dart` | М | ✓ | необязательное `EventServerDraftRef.createdByUserId` |
| `apps/mobile/lib/app/router/route_names.dart` | М | ✓ | `testPlacePublication` |
| `apps/mobile/lib/app/router/app_router.dart` | М | ✓ | маршрут с redirect по guard |
| `apps/mobile/lib/app/di/service_locator.dart` | М | ✓ | регистрация `PlacePublicationTestEntryGuard` |
| `apps/mobile/test/backend_local/support/stand_backend.dart` | М | ✓ | `placeSeed()`, `placeManifest()` |
| `apps/mobile/test/unit/place_content_body_mapper_test.dart` | Н | ✓ | P7 |
| `apps/mobile/test/unit/place_publication_controller_test.dart` | Н | ✓ | P9 |
| `apps/mobile/test/unit/place_publication_test_entry_guard_test.dart` | Н | ✓ | P10 |
| `apps/mobile/test/unit/content_publication_gateway_type_test.dart` | Н | ✓ | P10 |
| `apps/mobile/test/unit/place_reference_taxonomy_fixture_test.dart` | Н | ✓ | P11 |
| `apps/mobile/test/fixtures/create/user_place_draft.dart` | Н | ✓ | черновик и случаи совместимости |
| `apps/mobile/test/fixtures/media/stand_gallery_1.png` | Н | ✓ | фото галереи стенда |
| `apps/mobile/test/fixtures/media/stand_gallery_2.png` | Н | ✓ | фото галереи стенда |
| `apps/mobile/test/backend_local/place_publication_stand_test.dart` | Н | ✓ | P13: контроллер против стенда |
| `apps/mobile/test/backend_local/place_publication_ui_stand_test.dart` | Н | ✓ | P13: UI с define |

### 10.6 Документы (5)

| Файл | | Карта | Назначение |
|---|---|---|---|
| `docs/product/PLACE_D3_1_PUBLICATION_AMENDMENT.md` | Н | ✓ | этот документ |
| `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md` | М | ✓ | §40 D3.1 |
| `docs/product/BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md` | М | ✓ | строка `place` |
| `docs/product/create/PLACE_CREATE_BLOCK_SPEC.md` | М | ✓ | §9: ссылка на тестовый серверный путь |
| `docs/architecture/LAUNCH_STATUS.md` | М | ✓ | строка D3.1 |

Итого: 6 + 14 + 2 + 7 + 24 + 5 = 58 файлов; 52 из принятой карты и 6
добавленных при реализации (отмечены «+»).

### 10.7 Отпечаток и карта

Отпечаток хэширует все изменённые и новые файлы, кроме двух статусных
документов — этой поправки и `LAUNCH_STATUS.md`: гейты их не читают, а пишутся
они после прогона. Поэтому в отпечатке всегда на два файла меньше, чем в
карте: при итоговом прогоне 56-файловой карты — 54 файла; для окончательной
карты из 58 файлов — 56.

### 10.8 Прочие уточнения при реализации

- Проверка поддерживаемости черновика (`seasonal`, `unknownFields`)
  выполняется до любого вызова: неподдерживаемый черновик не создаёт даже
  пустой серверный черновик (тест контроллера).
- Удобства (`amenities == hidden`) — строка таблицы неактивных значений §5.3.
- Wire-проверка §5.7: реальные медиа загружаются только для корректного
  случая; остальные идут с заглушками медиа фикстуры, а контроль «корректное
  тело с заглушками → `media_not_ready`» показывает, что Content проверяет
  медиа только после валидации, то есть их `validation_failed` — от валидации.
- Emulator-тест D2 для фото Place в `content_place_emulator_flow.test.ts`
  работает с поддельным обработчиком (байтов вариантов нет) и проверяет pin
  публикации и запись Media; положительную выдачу байтов доказывает P15.

## 11. Статус

**Review (2026-10-10).** Windows-local Emulator evidence; не Done.

Проверенная ревизия: **`8a6c2de+wt:94c9d3f2a370`** — worktree
`claude/d3-1-place` от `8a6c2de`. Отпечаток: пути, отличающиеся от HEAD, и
неотслеживаемые файлы, по строке «путь TAB SHA-256», отсортировано; первые 12
hex SHA-256 списка; исключены только этот документ и `LAUNCH_STATUS.md`
(§10.7). Отпечаток до и после прогона совпал (56 файлов).

| Проверка | Результат |
|---|---|
| `git diff --check` (с новыми файлами) | без замечаний |
| boundary (`check_boundaries.dart`) | 0 нарушений, 71/71 подавлений — поимённо как на `8a6c2de` |
| сборка, lint, формат | без ошибок |
| тесты без Emulator | 946/946 |
| тесты скриптов / тесты стенда | 43/43 / 41/41 (включая P16 — 12) |
| стражи `verify-*` | пройдены |
| `test:emulator` | 197/197 (включая P1, wire §5.7, P5–P6) |
| гейт D3.1 | пройден: P15 4/4 (реальная выдача фото Place), чистый = прерванный и возобновлённый = повторный seed (digest), mobile против стенда — контроллер 4/4, UI 1/1 |
| гейты D2, D1, F2, F1, E2, E2a, E1, C3, C2, C1, B2, mobile, acceptance | пройдены |
| start → stop → start → stop без `reset` | пройден |
| `api_contracts` | 25/25 |
| `flutter analyze` / `flutter test` | 0 замечаний / 1357 пройдено, 25 пропущено |

Пропуски Flutter (JSON-отчёты базы `8a6c2de` и этого прогона, поимённо): все
20 пропусков базы на месте; 5 новых — стендовые тесты Place
(`place_publication_stand_test.dart` — 4, `place_publication_ui_stand_test.dart`
— 1), которые без стенда пропускаются так же, как 20 прежних из
`backend_local`, а в гейте D3.1 выполняются и проходят. Других новых пропусков
нет; пройденных на 54 больше — новые unit-тесты Place.

Промежуточные прогоны не считаются итоговыми: первый гейт D3.1 нашёл
расхождение digest (исправлено в `stand_digest.ts`), второй был сорван моей
пересборкой `lib` во время работы эмулятора, первый финальный прогон оборвал
предел `test:emulator`, прогон `8a6c2de+wt:61ffe324d8c5` был до ревью перед
коммитом (без P15, P16, boundary и `git diff --check`).

Открыто (D3.1 их не закрывает): часть B — проверенное подмножество, полная
совместимость формы Create не объявляется; коды нарушений клиенту не
передаются; справочники Place — тестовая фикстура; Catalog/Discover для Place не
готовы (BCK08-OD-04); дубли мест только локально; W1–W6, F2a и OD-07 из D2;
Activate и правка после публикации на mobile не выведены; физические
устройства, Linux, облако и production.
