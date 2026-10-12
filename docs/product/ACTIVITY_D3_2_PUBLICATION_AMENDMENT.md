# D3.2 — Recharge Activity через Create, Content, Media и модерацию (только Emulator)

Статус: **Review (2026-10-11), Windows-local Emulator evidence (§11).**
Ветка `claude/d3-2-activity` от `fd56758` (D3.1, Review), отдельный worktree.

Документ устроен как поправка D3.1
([PLACE_D3_1_PUBLICATION_AMENDMENT.md](PLACE_D3_1_PUBLICATION_AMENDMENT.md)) и
разделён на три независимые части; итог каждой оценивается отдельно:

- **A. Emulator publication lifecycle** — что сервер делает с Activity;
- **B. Совместимость с формой Create** — **проверенное подмножество**;
  полная совместимость формы Create **не объявляется**;
- **C. Готовность Catalog/Discover** — оценка без изменений; D3.2 её не
  повышает.

## 0. Основание и граница

Заход D3.2 — «только Recharge Activity»: подключить принятый Activity
validator, включение только в Emulator, полный lifecycle C3 и существующий
mobile Create flow; fail closed при отсутствующей зависимости. Другие
Create-типы не затрагиваются.

Опора в коде (на `fd56758`):

- валидатор `activity_rules.ts` (RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC v1.4
  §9.1/§12) зарегистрирован в `content_type_registry.ts` как `available`
  (`sourceAuthority`: ACT-CRT-01 v1.4);
- механизм D3.1: `emulatorAuthoringTypes`, `authoringTypesFor`, отказ
  композиции собираться с типом вне списка или без валидатора; общий шлюз
  Content mobile с параметром `typeId`;
- справочные данные Emulator для всех типов, кроме Place, отвечали «любая
  подкатегория применима, обязательных критериев нет» — для Activity это был
  бы пропуск без проверки (fail open);
- `location.linkedPlaceId` валидатор проверяет только как постоянный id;
  существование Place — дело владельца Catalog (ACT-CRT-01 §13 шаг 5), а Place
  в Catalog исключён (BCK08-OD-04): зависимости нет.

Не входит: изменения валидатора и реестра типов, контракта ответа Content,
Catalog/Discover для Activity, формы Create и её локальной публикации,
мягкого порога неформального доступа (§13 шаг 7), облака и deploy; Event,
Place, Rental, Collection и типы без валидатора.

## 1. Решения владельца (2026-10-11)

1. **Основа** — поверх D3.1 (`fd56758`), отдельный worktree
   `claude/d3-2-activity`; используется механизм включения типов D3.1.
2. **`linkedPlaceId` — fail closed**: mobile поле не отправляет, черновик с
   привязанным Place до сервера не доходит; сервер в композиции Emulator
   отклоняет тело с `linkedPlaceId` (`validation_failed`). Включение — отдельным
   slice вместе с проверкой существования Place.
3. **Mobile — как Q4 в D3.1**: черновик, медиа, submit, publish, hide; Activate
   и правка после публикации подтверждаются только бэкендом.

---

## Часть A. Emulator publication lifecycle

### 2.1 Включение

- Новый флаг `content.activity.authoring` (`contentFlagIds.activityAuthoring`),
  выключен по умолчанию, только `local`/`LV` в Emulator.
- `content_entry.ts`: `emulatorAuthoringTypes = ['event', 'place', 'activity']`;
  `authoringTypesFor` получает третий флаг. Инвариант D3.1 сохраняется:
  композиция не собирается с типом вне списка или без валидатора. Rental и
  Collection (валидаторы есть) остаются вне списка.
- `contentCommandV1` / `contentQueryV1` строят набор из трёх флагов.

### 2.2 Матрица операций

Правило D3.1 без изменений: вход Content открыт, если включён хотя бы один
флаг authoring; флаг Activity закрывает `createDraft`, `updateDraft`,
`submitForPublication`, `publishApprovedRevision`,
`activatePublishedRevision` (`type_disabled`); скрытие и чтение владельцем
флагом типа не закрываются.

| Флаги Event / Place / Activity | Activity: save…activate | Activity: hide, чтение | Event, Place |
|---|---|---|---|
| все выкл | `type_disabled` (вход закрыт) | `type_disabled` | `type_disabled` |
| вкл / вкл / выкл | `type_disabled` | разрешено | как в D3.1 |
| выкл / выкл / вкл | разрешено | разрешено | save…activate — `type_disabled` |
| все вкл | разрешено | разрешено | разрешено |

Флаги authoring не управляют staff-модерацией (C2) и реакцией D2.

### 2.3 Справочные данные Activity в Emulator

Для Activity синтетические константы заменяются минимальной фикстурой —
подмножеством таксономии mobile; неизвестная пара группа/подкатегория
**неприменима** (fail closed). Ответы для остальных типов не меняются.

| Группа | Подкатегория | Применима к Activity | Обязательные критерии |
|---|---|---|---|
| `outdoor_nature_walking` | `forest_walk`, `sunset_walk` | да | `difficulty` |
| `wellness_recharge` | `meditation` | да | — |
| `wellness_recharge` | `sauna` | **нет** | — |
| `water_activities` | `kayak` | да | `equipment_provided`, `swimming_required` |

Ревизия — `test-only-tx-activity-1`. Канонический файл —
`packages/api_contracts/schema/content/v1/fixtures/activity_reference_taxonomy.json`;
константа бэкенда сверяется с ним (unit), Dart-тест сверяет файл с таксономией
mobile. Это не принятая таксономия BCK-20.

### 2.4 Fail closed: зависимости, которых нет

- **Связанный Place.** Сервис Content получает необязательный порт
  `compositionRules` — правила композиции поверх принятого валидатора; они
  могут только добавить нарушения. Композиция Emulator передаёт правило
  Activity: тело с `location.linkedPlaceId` (любое значение) →
  `activity.linked_place_unresolved` → `validation_failed`. Правило проверяет
  именно то тело, которое станет публичным: на submit и publish — отправленную
  ревизию черновика (publish отклоняет черновик, ушедший дальше), на
  `activatePublishedRevision` — тело целевой immutable revision, а не текущего
  черновика. Поэтому ревизия с `linkedPlaceId`, опубликованная до правила
  (без него), при включённой Activity и подключённом правиле не активируется —
  ни после замены новой ревизией, ни после скрытия владельцем; одобренная до
  правила submission не публикуется. Указатель, ревизии и эффекты при отказе не
  меняются. Валидатор и реестр не меняются; без правила те же команды проходят
  (доказано тестами).
- **Таксономия.** Неизвестная пара неприменима (§2.3); недоступный ответ
  справочников — коды валидатора `activity.taxonomy_unavailable` /
  `criteria_registry_unavailable`, как и раньше.
- **Тип и валидатор.** Как в D3.1: тип без валидатора не включается;
  композиция не собирается.

### 3. Шаги lifecycle

| Шаг | Команда / путь | Кто решает | Отказы (примеры) |
|---|---|---|---|
| 1. Черновик | `createDraft` (`typeId: activity`, тело `{}`), `updateDraft` | Identity: Session, verified Creator, точная Page | `type_disabled`, `publisher_not_eligible`, `revision_conflict` |
| 2. Медиа | Media C1: обложка и каждое фото галереи к точному черновику | Media | отказ или недоступность Media |
| 3. Submit | `submitForPublication` | Content: валидатор Activity со справочниками §2.3, правило §2.4, readiness набора медиа (`activityMediaIds`) | `validation_failed` (без кодов `activity.*`), `media_not_ready` |
| 4. Review | staff C2 (approve / reject / restrict) | модерация C2 | `moderation_decision_stale` |
| 5. Публикация | `publishApprovedRevision` | Content: повторная валидация и readiness | `validation_failed`, `moderation_required`, `revision_conflict` |
| 6. Скрытие | `withdrawPublication` (владелец) | Content | `revision_conflict` |
| 7. Возврат | `activatePublishedRevision` | Content | `media_not_ready` |
| 8. Правка | `updateDraft` → submit → review → publish переключает указатель | как 1–5 | как 1–5 |

Шаги 7 и 8 подтверждаются только бэкендом. Повторы с тем же ключом
идемпотентны; устаревшая ревизия черновика или указателя отклоняется.

### 4. Эффекты и соседние модули

- **Catalog**: факт Activity фиксируется как `excluded: type_disabled`;
  rebuild, activate и rollback это сохраняют. Discover отклоняет
  `typeIds: [activity]` (`type_disabled:activity`).
- **Booking**: handoff пропускает эффекты Activity (0 фактов, состояния нет).
- **D2**: медиа Activity подпадают под D2 (ограничение фото, подавление в
  указателе Content, снятие только активацией издателем). Реальная выдача байтов
  с инструментами D1 для Activity не повторяется: Media и D2 от типа не
  зависят, для Place это доказано гейтом D3.1 (P15).

### 4.1 Что не меняется в части A

`activity_rules.ts`, `content_type_registry.ts`, контракт ответа Content,
Catalog (`catalogEnabledTypes`), Discover, Booking, `firestore.rules`,
`emulator-stand.mjs`, общий набор флагов стенда. Сервис Content получает только
необязательный порт `compositionRules` (по умолчанию пусто — поведение прежнее);
при активации он применяется к телу целевой ревизии (§2.4).

---

## Часть B. Совместимость с формой Create (проверенное подмножество)

### 5.1 Источник и путь

- Источник — текущий черновик Create (`CreateRepository.loadDraft`), только
  `objectType == activity` с `activityData`. Форма Create и её локальная
  публикация не меняются.
- Тестовый вход: define `RECHARGE_TEST_ACTIVITY_PUBLICATION=true`, не release,
  binding `testBackend`, loopback `demo-recharge/europe-west1` — все четыре
  условия сразу; тот же guard защищает маршрут `/test/activity-publication`,
  каждую команду Content и каждую загрузку Media.
- Панель «Activity publication (test)»: Save, Upload media, Submit, Refresh,
  Publish, Hide и «мои активности» (до 20, статус с сервера).

### 5.2 Таблица полей: черновик Create → тело Content Activity

| Тело Content | Источник в Create | Правило |
|---|---|---|
| `title` | `title` | trim |
| `categoryId`, `subcategoryId` | `mainCategory`, `subcategory` | как есть |
| `shortDescription`, `fullDescription` | те же поля | trim; пустое не отправляется |
| `criteria` | `sectionData['criteria']` | если не пусто |
| `media.coverImage`, `media.gallery` | `media.coverImage`, `media.gallery` | id ассетов Media; до загрузки — `loc_<attachmentId>` |
| `location.latitude/longitude/pinConfirmed` | `activityData.location` | как есть |
| `location.addressLine`, `location.accessNotes` | то же | trim; пустое не отправляется |
| `location.accessCaution` | то же | не отправляется, если не неформальный и без заметки (§8 шаг 2); заметка — trim |
| `typicalDurationMinutes`, `suggestedGroupSize` | то же | `{min, max}` |
| `optionalContribution` | то же | только если есть вид, заметка или сумма; сумма — `{amountMinor, currencyCode}` |
| `bestTime` | то же | только заданные поля; пустое не отправляется |

Не отправляются никогда: `publisherRef` (он в команде), `schedule`, `booking`,
`pricing`, `capacity` (их нет в Activity).

### 5.3 Не отправляется совсем (черновик целиком)

Черновик, в котором есть что-то из этого, не уходит на сервер, даже пустым
черновиком (`unsupported_capability:<список>`):

- `location.linked_place` — привязанный Place (§2.4);
- `tags` — контракт Activity их не несёт;
- `unknown_fields` — поля более новой схемы черновика.

### 5.4 Сохранение и восстановление

Как в D3.1: пустой черновик под стабильным ключом (повтор возвращает тот же),
затем полное тело; при `revision_conflict` ревизия читается заново и
сохранение повторяется только для черновика этого автора. В теле Activity
автора нет; `createdByUserId` сервера хранится в журнале и защищает от чужой
записи.

### 5.5 Идентификаторы и ключи

UUIDv5 в namespace `82167158-6d3c-4536-aec4-b7f4f12b012b` от
`recharge:activity-publication:v1:<account>:<publisherType>:<publisherId>:<localDraftId>`:
`attachment:cover`, `attachment:gallery:<localRef>` (перестановка галереи id не
меняет), `upload:<attachmentId>:<sha256>`. Префикс ключей Content —
`ap1-<24 hex SHA-256 scope>`.

### 5.6 Журнал

`activity-publications-v1.json` в каталоге поддержки, до 100 записей, запись
«записать во временный файл → переименовать». Запись привязана к аккаунту и
publisher; чужие записи хранятся, но не возвращаются; статус всегда с сервера.

### 5.7 Расхождения правил: форма Create допускает → сервер отклоняет

Общая фикстура `activity_create_compat.json`: тело, которое делает маппер для
каждого случая Create, и коды валидатора под справочниками Emulator. По проводу
каждый непустой случай — `validation_failed` без кода.

| Случай | Код валидатора |
|---|---|
| `valid` | — |
| `cover_missing` | `activity.cover_image_required` |
| `short_description_short` | `activity.short_description_length` |
| `pin_unconfirmed` | `activity.pin_confirmation_required` |
| `access_notes_missing` | `activity.access_notes_required` |
| `informal_access_without_note` | `activity.access_caution_note_required` |
| `contribution_note_missing` | `activity.contribution_note_required` |
| `contribution_currency_mismatch` | `activity.contribution_currency_unsupported` |
| `duration_range_invalid` | `activity.duration_range_invalid` |
| `subcategory_not_applicable` | `activity.subcategory_not_applicable` |
| `criterion_missing` | `activity.criterion_required:difficulty` |

Это проверенное подмножество; полная совместимость формы Create не
объявляется. Коды клиенту не передаются (контракт BCK-07).

---

## Часть C. Готовность Catalog/Discover

- Сейчас: `catalogEnabledTypes = {event}`; Activity получает
  `excluded: type_disabled`; Discover Activity отклоняет; mobile Discover
  показывает Activity из локального источника (ACT-CRT-01 §14).
- D3.2 доказывает только исключение (и после rebuild/rollback) и отсутствие
  фактов Booking.
- Для готовности нужны: решение BCK08-OD-04 для Activity, проекция Activity в
  Catalog (локация, длительность, время, вклад), перенос подавления D2 в факты,
  Details из Catalog, проверка `linkedPlaceId` владельцем Catalog, принятая
  таксономия BCK-20, серверный мягкий порог неформального доступа.

**Вывод:** Catalog/Discover для Activity **не готовы**; D3.2 это не меняет.

---

## 7. Стенд и гейт D3.2

- Флаг `content.activity.authoring` на стенде включает только
  `stand-seed.mjs activity seed`.
- `activity seed` проводит фиксированную Activity
  (`outdoor_nature_walking/forest_walk`, `difficulty`) через Content: черновик
  `{}` → обложка и два фото → полное тело → submit → одобрение staff →
  публикация. Ключи фиксированы; точка прерывания —
  `STAND_SEED_INTERRUPT_AFTER=gallery-1`. Ids — в манифест (`contentActivity`);
  digest стенда именует их метками `seed-activity`.
- `activity verify`: указатель видим, медиа ревизии = готовые ассеты, Catalog
  `excluded: type_disabled`, фактов Booking нет.
- `scripts/stand-d3-2-gate.mjs --yes`: свежий стенд → `activity seed` →
  verify → digest; свежий стенд → прерванный seed → возобновление → digest =
  чистому → повтор (`reused`) → digest тот же; затем на этом ПК
  `activity_publication_stand_test.dart` и
  `activity_publication_ui_stand_test.dart` (с define); остановка проверяется.

## 8. Проверки

| № | Часть | Что | Уровень и файл |
|---|---|---|---|
| A1 | A | матрица §2.2 по проводу, каждая строка, конкретный код; флаги восстанавливаются | Emulator: `content_activity_callable.test.ts` |
| A2 | A | `authoringTypesFor` (8 сочетаний), список типов, отказ композиции | unit: `content_authoring_types.test.ts` |
| A3 | A | сервис: Activity только со своим флагом; Rental/Collection `type_disabled` при любом наборе; типы без валидатора `content_type_unsupported`; Activity выкл → hide и чтение разрешены | integration: `content_activity_enablement.test.ts` |
| A4 | A | справочники §2.3: константа = файл; применимость, критерии; неизвестная пара неприменима | unit: `emulator_activity_taxonomy.test.ts` |
| A5 | A | §2.4: `linkedPlaceId` отклоняется композицией, а не валидатором; без правила тот же черновик проходит; после снятия связи — проходит; activate целевой ревизии со связью (заменённой и скрытой) и publish одобренной до правила submission отклоняются без изменения указателя, ревизий и эффектов, без правила — проходят | unit + integration (`content_activity_enablement.test.ts`) + Emulator |
| A6 | A | lifecycle §3 полностью, справочники через Emulator | Emulator: `content_activity_emulator_flow.test.ts` |
| A7 | A | эффекты §4: Catalog, Discover, Booking, D2 | Emulator: `content_activity_emulator_flow.test.ts` |
| B1 | B | маппер §5.2–§5.3, UUIDv5 §5.5 (сверены с Python `uuid5`), вывод = фикстура | unit (Dart): `activity_content_body_mapper_test.dart` |
| B2 | B | цепочка §5.7: тело → код валидатора → `validation_failed` по проводу | unit (TS) `type_rules_activity_create_compat.test.ts` + Emulator |
| B3 | B | контроллер: закрытый вход, восстановление, журнал, идемпотентная загрузка, связанный Place не отправляется | unit (Dart): `activity_publication_controller_test.dart` |
| B4 | B | guard (четыре условия), шлюз `typeId: activity` | unit (Dart): `activity_publication_test_entry_guard_test.dart`, `content_publication_gateway_type_test.dart` |
| B5 | A+B | фикстура справочников = таксономия mobile | unit (Dart): `activity_reference_taxonomy_fixture_test.dart` |
| S1 | A+B | стенд: чистый = прерванный и возобновлённый = повторный (digest); метки Activity в digest | гейт `stand-d3-2-gate.mjs`; unit `stand_digest.test.ts` |
| S2 | B | mobile против стенда: контроллер и UI с define | гейт + `flutter test` |
| R | — | регресс: `test:emulator`, тесты без Emulator, `verify-*`, `flutter analyze`, `flutter test`, boundary | финальный прогон |

## 9. Откат

Выключить `content.activity.authoring` (по умолчанию выключен): создание и
изменение Activity закрываются, скрытие и чтение владельцем остаются. Полный
откат — revert коммита D3.2: Activity исчезает из списка Emulator, порт
`compositionRules` и фикстуры удаляются; данные Emulator не мигрируются.

## 10. Остаточные риски и открытые пункты

- Часть B — проверенное подмножество; коды нарушений клиенту не передаются.
- `linkedPlaceId` закрыт до проверки существования Place владельцем Catalog.
- Справочники Activity — тестовая фикстура, не BCK-20.
- Мягкий порог неформального доступа (§13 шаг 7) на сервере не реализован.
- Catalog/Discover для Activity не готовы (BCK08-OD-04).
- Реальная выдача байтов медиа Activity с инструментами D1 не повторялась (§4).
- Activate и правка после публикации на mobile не выведены.
- Физические устройства, Linux, облако и production не покрыты.

## 11. Статус

**Review (2026-10-11).** Windows-local Emulator evidence; не Done; без коммита.

Проверенная ревизия: **`fd56758+wt:4f3b908ac8c9`** — worktree
`claude/d3-2-activity` от `fd56758`. Отпечаток: пути, отличающиеся от `fd56758`,
и неотслеживаемые файлы, по строке «путь TAB SHA-256 (содержимое без CR)»,
отсортировано; первые 12 hex SHA-256 списка; исключены только этот документ и
`LAUNCH_STATUS.md`. Отпечаток до и после прогона совпал (51 файл).

| Проверка | Результат |
|---|---|
| `git diff --check` (с новыми файлами) | без замечаний |
| boundary (`check_boundaries.dart`) | 0 нарушений, 71/71 подавлений |
| сборка, typecheck, lint, формат | без ошибок |
| `test:unit` / `test:r1:integration` / `test:contract` | 692/692 / 219/219 / 50/50 |
| тесты стенда (`test:stand`) | 42/42 |
| стражи `verify-*` (r1, content-persistence, reference-data, security-privacy, identity-publisher, generated) | пройдены |
| `test:emulator` | 210/210 за 708 с (предел 900 с) |
| гейт D3.2 | пройден: чистый = прерванный и возобновлённый = повторный seed (digest), mobile против стенда — контроллер 4/4, UI 1/1 |
| гейт D3.1 | пройден: P15 4/4 (реальная выдача фото Place), digest, mobile — контроллер 4/4, UI 1/1 |
| гейт C3 | пройден: mobile — контроллер 3/3, UI 1/1 |
| `flutter analyze` / `flutter test` | 0 замечаний / 1400 пройдено, 30 пропущено |

Новые пропуски Flutter (+5 к D3.1) — стендовые тесты Activity
(`activity_publication_stand_test.dart` — 4, `activity_publication_ui_stand_test.dart`
— 1): без стенда пропускаются, в гейте D3.2 выполняются и проходят. Остальные
гейты (D2, D1, F2, F1, E2, E2a, E1, C2, C1, B2, mobile, acceptance) в этом
заходе не повторялись.

Исправление перед прогоном: `activatePublishedRevision` не проверял тело
целевой ревизии правилами композиции — ревизию с `linkedPlaceId`, опубликованную
без правила, можно было снова сделать публичной. Теперь правило применяется к
телу целевой immutable revision (§2.4); тесты A5 без исправления падают (2 из 9),
с ним проходят.

## D3.7 — explicit mobile Activate and publication editing (2026-10-11)

The owner's direct instruction for pass 7 extends the former §5.1 exclusion
only in the existing default-off loopback Emulator Activity publication entry.
It does not enable production or accept the publication slice on behalf of its
owner. Existing backend Activate composition validation is reused unchanged.

Activate targets the current immutable published revision with the server's
pointer revision. Its exact target/fence/idempotency key is journaled before
sending; a transport failure retains it for explicit retry after restart.
A definitive refusal retains the server code and never automatically retries
with another pointer fence. Every call uses existing client and server guards.

Edit opens the existing Create Activity form in draft-only editing mode. It
preserves the Content/local draft IDs and media bindings and records which
published revision is being edited. Save creates a new revision of the existing
mutable server draft; submit snapshots it for fresh review, and publish only
switches the pointer after approval. Immutable published history is not written.
The journal's optional editing/recovery fields read legacy records unchanged.
The UI labels published version and draft revision separately and requires a
new Save after local form edits before Submit. Draft-only mode saves back to
Create instead of invoking its separate local/mock publication action.

Acceptance: real stand controller and UI perform hide → explicit Activate and
Edit in Create → new draft save → submit → staff review → publish; old immutable
revision data remains byte-equivalent. Unit regressions cover lost Activate
response/restart, optimistic conflict, closed gate and stale unsaved Create body.
Device, real D1 Activity bytes, Linux/cloud/production and previous dependencies
are not closed. Rollback: hide Activate/Edit actions and restore normal Create
entry; stored immutable history and lifecycle contracts remain compatible.

Activity Catalog/Discover is still excluded. Pass 8's proposed OD-04 decision is
[ACTIVITY_CATALOG_DISCOVER_OD04_PROPOSAL.md](ACTIVITY_CATALOG_DISCOVER_OD04_PROPOSAL.md),
awaiting owner acceptance before dependent implementation.

## D3.8 — Activity Catalog/Discover bounded extension (2026-10-11)

BCK08-OD-04-A Activity-only design принят владельцем; отдельно подтверждено отсутствие dynamic criteria в первой версии. Runtime использует immutable artifact Category System v1.4.3 через existing ReferenceDataPort exact-revision reader. CatalogActivityItem публикует confirmed standalone location, duration range, suggested group, best time, informal warning и optional contribution, без Event occurrence/price/Booking или private authoring fields. D2 suppressedMediaIds уже передаются Content feed; projection и reads соблюдают их при duplicate/stale replay, rebuild, activation и rollback. Media restore не снимает suppression без explicit Content owner Activate.

Backend env RECHARGE_TEST_ACTIVITY_CATALOG=true и mobile dart-define того же имени включают только разрешённый local Emulator path совместно с existing Discover/testBackend guards. Оба default-off; release composition не активируется. Existing controller/gateway/form lifecycle не меняется. Старые drafts/revisions не переписываются; linked Place по-прежнему fail closed.

Evidence: ../evidence/backend/d3/D3_ACTIVITY_CATALOG_2026-10-11.md. Status Review, владельческая приёмка не объявлена. Dynamic public criteria, dedicated bestTime/duration filters, linked Place authority, BCK-22 threshold, другие Catalog types и production/device/Linux gates остаются отдельным долгом. Rollback: выключить Activity backend/mobile flags; при последующем включении reconcile/rebuild и atomic activation обязательны для записей, ранее исключённых type_disabled.

## D3.9 — Catalog-owned linked Place bounded extension (2026-10-11)

Owner approved OD-01 A and the file plan in ACTIVITY_LINKED_PLACE_D3_9_PROPOSAL.md: Activity remains visible when Place is hidden/restricted/unavailable; only its public relation disappears. Submit, publish of an earlier approved submission and activation of the exact immutable target body require fresh Catalog-owned eligibility. Unknown, wrong type/market, nonpublic, missing publication, changed source pointer or dependency outage refuse with allowlisted validation details at /body/location/linkedPlaceId. Content retains only the relation ID, never Place visibility authority. Old drafts/revisions are not rewritten.

Backend RECHARGE_TEST_ACTIVITY_LINKED_PLACE=true and mobile dart-define of that name enable only the existing guarded local path; defaults remain off with the previous deny. The existing location step provides bounded Catalog lookup/pagination/select/explicit clear. Public Activity Feed/Search/Map/Details filter the relation again against the current owner source, including old snapshots and rebuilt/rolled-back projection sets. Source body integrity is verified; public DTO contains only current ID/revision/pointer/market/title. No full Place Catalog/Discover/Details is enabled.

Eligibility is a current source read, not a cross-aggregate atomic lease: a later Place change is reflected by the next public read. No stronger guarantee is claimed. Rollback: disable linked Place on backend/mobile, retaining published Activity without a public Place relation and restoring command deny; do not rewrite immutable history. Evidence: ../evidence/backend/d3/D3_ACTIVITY_LINKED_PLACE_2026-10-11.md. Implementation status Review, finished slice acceptance remains with the owner.
