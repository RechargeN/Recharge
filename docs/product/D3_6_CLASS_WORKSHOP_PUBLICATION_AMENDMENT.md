# D3.6 — Class / Workshop publication amendment, T2

- Revision: **0.3**, 2026-10-19.
- Status: **Review — решения CLS-OD-01…10 записаны (§1); план §6 и Event
  Classification 2.2.4 приняты владельцем 2026-10-19 («все принимаю, реалищзовывай»);
  bounded реализация в пределах §6 разрешена**.
- Runtime effect: реализовано в пределах §6 — default-off, только local/LV
  Emulator; результаты и gates — §9.
- Base: `0b131ab` (на момент начала совпадал с `codex/recharge-integration`).
- Local branch: `claude/t2-class-workshop`; commit checkpoint `bed7b05`.
  Последующее закрытие контрактного расхождения выполняется без нового commit.
- Separate worktree: `C:/Users/User/.claude/worktrees/recharge-t2-class-docs`.
- Локальные коммиты выполнены по последующему отдельному разрешению владельца (§9).
  Новые commit, push, merge и deploy этим закрытием не разрешены.
- Sources: [Class/Workshop v1.2, CW-V1 Approved](create/CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md),
  [BCK-07 v0.16 §47](CONTENT_PUBLICATION_BACKEND_SPEC.md),
  [Event Classification v2.2.4 Accepted](EVENT_CLASSIFICATION_SPEC.md),
  [DTL-CLS-01 v0.2 Approved](discover/DTL_CLS_01_CLASS_WORKSHOP_DETAILS_RUNTIME_SLICE_SPEC.md),
  [D3.5 Session](D3_5_SESSION_PUBLICATION_AMENDMENT.md) — образец формы.

## 0. Почему документ существует

Входной gate T2 (2026-10-19) остановлен после проверки только для чтения:
не найдены (1) отдельное owner-решение о возврате Class / Workshop,
(2) принятый backend-контракт типа, (3) принятый typed Create contract.
Владелец попросил подготовить проекты этих оснований. Это исторический
входной checkpoint v0.1; последующие явные решения владельца записаны в §1
и §1.1. Они разрешили bounded реализацию; агент не назначал product rules
и не повышал Review до Accepted.

Отличие от T1: у Session был typed local runtime (SES-CRT-01) и bounded
spec v1.1, который владелец утвердил без изменения содержания. У Class
/ Workshop typed Create block отсутствует, а spec v1.1 описывает полный
продукт (Offering/Cohort, inventory, commerce, learning). Поэтому для T2
нужно сначала утвердить bounded v1-подмножество — CW-V1 (Class spec §34).

v0.1 был проектом. В v0.2 записаны решения владельца (§1); документы
переведены по CLS-OD-10. В v0.3 план §6 отдельно принят (§1.1).

## 1. Решения владельца

Отдельный источник — явное решение владельца в чате T2 от 2026-10-19:

> «Как владелец принимаю рекомендации D3.6 §1 по CLS-OD-01…10 (вариант A и предложенные значения OD). Запиши решения, переведи документы по CLS-OD-10 и остановись до принятия плана.»

Это не вывод из запроса реализации, legacy UI, наличия Event-архетипов или
validator другого типа. Каждая рекомендация ниже принята как есть, включая
вариант A (CLS-OD-01) и все значения колонки «Предложение» (CLS-OD-03).
Само решение CLS-OD-01…10 не принимало план §6 и ревизию Event Classification;
их последующее отдельное принятие записано в §1.1.

### CLS-OD-01 — канонический typeId и связь с Event Classification

Факты:

- `class_workshop` — один из десяти принятых Create-типов (AGENTS.md,
  разрешённый конфликт №4), зарегистрирован в BCK-07 §33.1 как
  отдельный Content type с Discover family `Class/Workshop`; Category System
  v1.4.3 даёт ему applicability `C`; DTL-CLS-01 Approved читает его
  отдельной projection. Второй aggregate не создаётся: тип уже существует.
- Event Classification v2.2.3 (Accepted) содержит Event-архетипы
  `class_session` и `workshop` на той же тематике («мастер-класс, кулинария,
  керамика») и в §1/§1.2 не упоминает Class / Workshop. Пример §20:
  «платный workshop внутри фестиваля» → child Event/Bookable Session.
- Class spec §2.4 п.2: «объявленные occurrence + обязательная практическая
  программа → classWorkshop». Для одноразового мастер-класса с датой два
  документа дают разные ответы.

Варианты:

- **A (рекомендуется).** `class_workshop` остаётся отдельным типом. Тип
  выбирает Creator в Create Hub; автоматической конвертации нет. Граница:
  Class / Workshop — самостоятельное учебное предложение Publisher'а с
  обязательными outcomes и instructor; Event `workshop`/`class_session` —
  занятие как организованное событие или часть Event-программы (Program
  Item/child Event). Class не несёт Event archetype, admission, ECL-03
  inventory; Event не несёт learning-полей Class. Требует ревизии Event
  Classification 2.2.4 со строками в §1/§1.2 и §6.2 (текст — Class spec
  §2.6). Ревизию принимает владелец отдельно; агент Accepted-документ не
  правит.
- **B.** Class / Workshop становится preset Event с archetype
  `workshop`/`class_session`, без отдельного Content type. Противоречит
  разрешённому конфликту №4, BCK-07 §33.1 и DTL-CLS-01; требует нового ADR и
  миграции Details/Collection. Для T2 не рекомендуется.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-02 — bounded v1-подмножество (CW-V1)

Рекомендация: CW-V1 = зеркало Approved read-контракта DTL-CLS-01: одно
Offering и один контекст показа без Cohort aggregate; `singleClass` (ровно
одна occurrence) или `fixedSeries` (≥ 2 явные occurrence); без recurrence
rule; один IANA timezone; delivery `offline | online_live | hybrid`; один
primary instructor; одна public location variant; цена
`notProvided | free | fixed` со scope; запись только внешняя HTTPS-ссылка
или information-only. Вне CW-V1: multi-cohort, recurrence, rolling,
on-demand/blended, inventory/holds/Booking/waitlist/approval, Payments,
material add-ons, waiver, guardian flows, learning resources/progress/
certificates, collaborators, page publisher. Полный контракт — Class spec §34.

Соответствия, предложенные агентом и тоже требующие подтверждения:
expertise masterclass (§9.2) выражается обязательным `short_bio`
instructor; «observable result» experience — обязательным
`take_home_result`; curriculum (§14 п.7) — списком заголовков modules без
agenda-минут. Modules и take_home_result хранятся в revision, но в DTL-CLS-01
v0.2 не выводятся; их показ в Details — отдельная ревизия read-контракта.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-03 — числовые лимиты, которых нет в spec

Spec v1.1 отсылает к versioned `PolicyLimits` и запрещает UI-константы, но
значений не задаёт. Агент их не придумывает. Нужны значения:

| Лимит | Что известно из spec | Предложение для решения |
|---|---|---|
| Длительность одной occurrence | «положительна, по PolicyLimits» | 15…720 минут, без multi-day в CW-V1 |
| Число occurrences в fixedSeries | нет скрытого ceiling; batch limit отдельно | защитный payload limit 60 |
| Outcomes | 1+ | 1…10, каждый 3…160 символов |
| Curriculum modules | 1+ со stable ID | 1…20 заголовков, 3…120 символов, без agenda-минут |
| includedMaterials / requirements | нет | 0…20 пунктов, 2…120 символов |
| declaredGroupLimit | положителен, PolicyLimits | 1…500, optional; не inventory |
| online_provider_label | нет | 2…60 символов, без URL/secret |
| Gallery | `PolicyLimits.galleryMax` | 0…10, как у других D3 типов при совпадении |
| Tags | `PolicyLimits.tagsMax` | как в общем Content contract, без нового лимита |

Решение владельца: **приняты значения колонки «Предложение»** (2026-10-19).

### CLS-OD-04 — время, DST и прошедшие даты

Рекомендация:

1. Каждая occurrence хранит local date, local start/end minute, общий IANA
   timezone, вычисленные UTC start/end и resolved offset; сервер сам
   пересчитывает UTC из local + timezone и отказывает при расхождении.
2. DST gap — отказ; DST overlap — обязателен явный выбор offset
   (`fold`), иначе отказ. Device timezone не authority. Политика
   `dst_policy_version = 1`, как у Session.
3. Occurrences отсортированы, ID уникальны, без пересечений; end > start.
4. Submit и publish требуют, чтобы каждая occurrence начиналась позже
   серверного now. Activate immutable revision требует хотя бы одну будущую
   occurrence; прошедшие не сдвигаются и не становятся новыми.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-05 — Publisher

Рекомендация: только personal publisher, разрешённый Identity owner, как у
Session. Typed PublisherRef для Class (IDP-04B) не входит в T2.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-06 — taxonomy и dynamic criteria

Рекомендация: категория — canonical `C` applicability из текущей reference
revision. Required-поля активного criteria profile блокируют publish
(Class spec §3.2/§14 п.5; отличие от advisory-only Session SES-D14
осознанное). Teaching language и skill level читаются только из criteria,
без второго поля. Конфликт `includedMaterials` и `equipment_provided` в
CW-V1 не проверяется, потому что enum `materialsPolicy` не входит в
подмножество.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-07 — возраст и безопасность

Рекомендация: структурированный возраст и guardian/waiver flows в CW-V1 не
входят: в Approved read-контракте DTL-CLS-01 таких полей нет, а детские
форматы требуют guardian/consent policy (Class spec §31 п.6). Ограничения
указываются текстом в `requirements` и проходят обычную moderation.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-08 — Catalog/Discover и Collection

Рекомендация: Catalog/Discover исключены (BCK08-OD-04), как в D3.1–D3.5.
Существующий exact-ID evaluator Collection может вернуть eligible для
опубликованного Class без включения projection.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-09 — mobile

Рекомендация: T2 включает новый typed local Create block Class в
существующем form engine (секции config-driven, без отдельного flow) и
Q4-контроллер публикации по образцу D3.1/D3.5. Это завершение принятого
Create scope (AGENTS.md №4), а не новый тип. Без mobile Activate и
редактирования после публикации.

Решение владельца: **принята рекомендация** (2026-10-19).

### CLS-OD-10 — scope T2 после решений

Рекомендация (как T1): первый шаг после ответов — только документы:
Class spec v1.2 Approved (CW-V1), BCK-07 §47 Review, строка coverage matrix,
этот D3.6 → Review с записанными решениями. Затем остановка до явного
принятия плана §6. Runtime, флаги, реестр, Emulator gates — только после
него. Ревизия Event Classification 2.2.4 (если выбран A) — отдельный
owner-шаг до runtime.

Решение владельца: **принята рекомендация** (2026-10-19).

### 1.1 Принятие плана и Event Classification 2.2.4

После docs-only checkpoint владелец ответил: «все принимаю, реалищзовывай». Это явное принятие
обоих оставшихся оснований: плана файлов §6 и ревизии
[Event Classification 2.2.4](EVENT_CLASSIFICATION_SPEC.md) (§1.1, §1.2, §6.2).
Разрешена bounded реализация §6 с local Emulator gates. D3.6 и BCK-07
остаются Review; повышать их до Accepted самостоятельно нельзя. На этом
историческом checkpoint commit, push и deploy не разрешались; последующие
локальные коммиты записаны в §9, push и deploy не выполнялись.

## 2. Границы реализации

Один существующий Content aggregate и C3 команды; C2 moderation и C1/D2
Media через owner-service commands. Прямые записи в чужие домены запрещены.
Client claims не устанавливают publisher authority, eligibility, group limit,
attendance, Booking authority или readiness Media.

Сервер не материализует recurrence, не хранит availability, не создаёт
второй schedule или Booking engine, не копирует Event archetype/admission
и Session weekly-rules. `declaredGroupLimit` — декларация, не inventory и
не `spotsLeft`. Не включаются другие Create-типы, Payments, providers или
production.

## 3. Read-only сверка mobile → backend на 0b131ab

| Область | Факт | Следствие для T2 |
|---|---|---|
| Mobile Create | `CreateObjectType.classWorkshop` — общий config (`create_taxonomy.dart`), `eventSlots`, только `startDateTimeUtc` обязателен (`create_controller.dart`) | Typed draft отсутствует; generic поля не являются CW-V1 и не подаются на сервер |
| Mobile Details | DTL-CLS-01: `ClassWorkshopKind`, `ContextKind {singleClass, fixedSeries}`, `Delivery {offline, onlineLive, hybrid}`, price/enrollment sealed | CW-V1 обязан проецироваться в этот контракт без потерь и расширений |
| Wire type | `class_workshop` (mobile `create_draft_entity.dart`, backend registry, `content_common.schema.json`) | Канонический typeId не меняется |
| Backend | Registry: `unavailable: spec_not_approved`; `validation_context.ts` уже знает `classWorkshop` как тип пункта Collection | Validator отсутствует; fallback на generic/Event запрещён |
| Envelope | Session: общие camelCase поля + типовой payload под ключом type ID, snake_case внутри | CW-V1 — тот же конверт с payload `class_workshop` (Class spec §34.3) |
| Legacy | Generic draft хранит `eventSlots`, `bookingLink`, organizer-поля | Непустой legacy — явный local отказ и server negative fixture, без молчаливого удаления |

## 4. Матрица обязательных зависимостей и отказов

| Зависимость / owner | Явный отказ |
|---|---|
| Решения владельца §1 и принятие плана §6 | Получены 2026-10-19 («все принимаю, реалищзовывай») |
| Ревизия Event Classification 2.2.4 (вариант A) | Принята 2026-10-19 |
| Emulator/local/LV + независимый default-off флаг | absent/off, не Emulator, не local/LV — closed |
| Identity: actor, capability, personal publisher | missing/revoked/foreign/page — отказ до изменения |
| Class validator + composition rules | unknown/unavailable type, unsupported body, unknown field — отказ без generic fallback |
| Reference Data: market/taxonomy C/criteria profile/locale | missing/stale/unavailable — отказ |
| IANA helper + DST policy | unknown zone, gap, неуказанный fold, UTC mismatch — отказ |
| Content CAS/idempotency/immutable target | stale revision/pointer, approval-body mismatch, тот же ключ с другим payload — отказ |
| Media generation-pinned readiness | missing/not ready/stale/restricted — отказ на новом переходе |
| Moderation disposition | нет действующего approval — отказ |
| Collection exact-ID evaluator | текущие D3.4 отказы, без foreign writes |
| Internal Booking/provider/payment | отсутствует намеренно; claims hold/capacity/confirmed/paid — отказ |

## 5. Submit / publish / activate

Путь: `apps/backend/functions/src/modules/content/application/content_publication_service.ts`.
D3.5 закрыл пропуск source-validation на activate для Session; для Class
тот же pipeline обязан вызывать Class validator на immutable target без
нового слоя.

| Путь | Обязательные проверки до сохранения |
|---|---|
| submitForPublication | текущий draft revision, Class source/composition, время/DST, capability/eligibility, Media |
| publishApprovedRevision | именно approved body; повторные source/composition/time/authority/Media проверки |
| activatePublishedRevision | именно immutable target; current references, source/composition/eligibility/Media, expected-current-pointer CAS |

Один и тот же запрещённый body обязан отказать на всех трёх путях, в том
числе после прежнего approval/publish; сохранённые snapshots, receipts и
effects не меняются.

## 6. План файлов (принят владельцем 2026-10-19)

Пути от корня; Н — новый, М — изменение.

### 6.1 Docs-only checkpoint после решений §1 — выполнен 2026-10-19

- М `docs/product/create/CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md` — v1.2 Approved (CW-V1).
- М `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md` — §47 Review.
- М `docs/product/BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md` — строка `class_workshop`.
- М этот документ — v0.2 Review с решениями.
- М `docs/product/EVENT_CLASSIFICATION_SPEC.md` — rev. 2.2.4, принята
  владельцем 2026-10-19 (§1.1); `AGENTS.md` — ссылки на версию.

### 6.2 Backend runtime

- Н `apps/backend/functions/src/modules/content/domain/type_rules/class_workshop_rules.ts`.
- М `.../content/domain/content_type_registry.ts` — validator + personal-only; остальные типы неизменны.
- М `.../content/domain/type_rules/validation_context.ts` — criteria profile/time lookups при необходимости.
- М `.../content/infrastructure/emulator_reference_data.ts` — pinned `C` applicability и profiles.
- М `.../content/application/content_publication_service.ts` — Class validator на immutable activate.
- М `apps/backend/functions/src/shared/feature_flags.ts` — `content.class_workshop.authoring`, default-off.
- М `apps/backend/functions/src/content_entry.ts`, `apps/backend/functions/src/index.ts` — allowlist/flag через существующую entry.

### 6.3 Backend tests и fixtures

Новые: `test/unit/content/type_rules_class_workshop.test.ts`,
`test/unit/content/type_rules_class_workshop_create_compat.test.ts`,
`test/integration/content_class_workshop_enablement.test.ts`,
`test/emulator/content_class_workshop_callable.test.ts`,
`test/emulator/content_class_workshop_emulator_flow.test.ts`,
`test/support/content_class_workshop_world.ts`,
`packages/api_contracts/schema/content/v1/fixtures/class_workshop_create_compat.json`.
Изменяемые regression assertions без ослабления: `type_rules_unavailable`,
`content_authoring_types`, `content_domain`, enablement-тесты Place/Activity/
Session, `content_publication_service`. Fixture недоступного типа переносится
на оставшийся unavailable type.

### 6.4 Mobile

Новые: `features/create/domain/entities/class_workshop_draft_data.dart`,
`.../domain/entities/class_workshop_validation_issue.dart`,
`.../domain/usecases/validate_class_workshop_draft_usecase.dart`,
`.../domain/usecases/build_class_workshop_content_body.dart`,
`.../data/models/class_workshop_draft_mapper.dart`,
`.../application/class_workshop_create_config.dart`,
`.../application/class_workshop_create_coordinator.dart`,
`.../presentation/widgets/class_workshop_create_block.dart`,
publication: `class_workshop_publication.dart`, `..._publication_gateway.dart`,
`..._publication_controller.dart`, `file_class_workshop_publication_journal.dart`,
`app/di/class_workshop_publication_composition.dart`,
`app/presentation/class_workshop_publication_panel.dart`.
Изменяемые: `create_draft_entity.dart`, `create_draft_model.dart`,
`create_controller.dart`, `create_providers.dart`, `create_page.dart`,
`service_locator.dart`, `app_router.dart`, `route_names.dart`.
Тесты: fixtures, mapper, validator, controller, entry guard, widget block,
`test/backend_local/class_workshop_publication_{stand,ui_stand}_test.dart`,
`test/backend_local/support/stand_backend.dart`.

### 6.5 Стенд и evidence

Новые: `test/stand/stand_content_class_workshop.ts`,
`scripts/stand-d3-6-gate.mjs` + self-test,
`docs/evidence/backend/d3/D3_6_CLASS_WORKSHOP_<дата>.md`.
Изменяемые: `stand_main.ts`, `stand_digest.ts`, `stand-seed.mjs`,
`run-emulator-test-groups.mjs` + test, `verify-r1-layout.mjs`,
`functions/package.json`, `apps/backend/README.md`,
`docs/architecture/LAUNCH_STATUS.md`. Собственный isolated stand root вне
Git; verified stop и cleanup также при failure.

## 7. Обязательная матрица будущей приёмки

| Проверка | Требуемое доказательство |
|---|---|
| Default closed | absent/off flag, не Emulator/local/LV, unknown type, нет capability/personal scope, page publisher — отказ до записи |
| Compatibility | valid/invalid shared Dart/TS fixtures; unknown/future/legacy поля не теряются молча; parser defaults не делают raw input валидным |
| Time boundary | single/fixedSeries counts, end > start, overlap, duration bounds, gap/overlap DST (последнее воскресенье марта/октября Europe/Riga), UTC mismatch, past dates |
| Full C3 | draft → update → media → submit → review → publish → owner hide / moderation restrict-restore → activate → новая revision; state, immutable bodies, receipts, отсутствие посторонних изменений |
| Three-path refusal | один запрещённый body на submit, approved publish, immutable activate |
| Retry/recovery | lost response, interrupted/resumed, repeated seed — без duplicates и повторных effects |
| Privacy | private поля и enrollment-only данные не в public/evaluator ответах |
| Real mobile | настоящий controller и config-driven UI против Emulator |
| Regression | остальные Create-типы и их enablement неизменны; полный Emulator набор одной сессией |
| Final gates | self-tests runners, cleanup fixtures, flutter analyze, полный flutter test, backend gates, boundary, diff-check, актуальные spec/LAUNCH_STATUS |

## 8. Статус и ограничения

Docs-only checkpoint CLS-OD-10 выполнен: CW-V1 и §2.6 Class spec — v1.2
Approved slice spec; полный продукт §1–§33 остаётся Ready for approval;
BCK-07 §47 и этот документ — Review; строка coverage matrix обновлена.
На docs-only checkpoint Event Classification не менялась; последующая
принятая ревизия 2.2.4 описана в §1.1.

План §6 и Event Classification 2.2.4 приняты (§1.1); реализация выполнена в
пределах §6, результаты — §9 и evidence. Не повышать Review до Accepted самостоятельно.
Последующее разрешение владельца на локальные коммиты выполнено (§9); push и deploy не разрешены. Неопределённое контрактом поведение при
будущей реализации — blocker до зависимого кода.

## 9. Реализация после принятия плана

В пределах §6 реализовано (base `0b131ab`, локальная ветка `claude/t2-class-workshop`):

- **Backend.** `class_workshop_rules.ts` — validator CW-V1 (§34): exact
  allowlists на каждом уровне, single/fixed series 2…60, 15…720 минут без
  multi-day, сервер пересчитывает UTC через существующий `resolveLocalTime`
  (gap — отказ, overlap — обязателен `fold`, лишний `fold` — отказ),
  отсортированность и непересечение, required criteria профиля, personal
  publisher, LV, валюта market, scope цены, HTTPS enrollment без user-info,
  `unsupported_internal` не создаётся. Registry v8: `class_workshop`
  available, personal-only; остальные типы без изменений. Независимый
  default-off `content.class_workshop.authoring` (local/LV, существующая
  entry). Pipeline: submit/approved publish требуют все occurrences в будущем,
  activate валидирует именно immutable target (хотя бы одна будущая occurrence,
  current references, composition, Media, CAS); outage reference — `policy_unavailable`.
  Emulator reference data: applicability `C` и required criteria по профилю.
- **Shared fixture.** `class_workshop_create_compat.json`: 45 кейсов (5 valid,
  40 отказов, по одному нарушению на кейс); ожидания заданы вручную. Id —
  UUIDv5 тестового scope, поэтому реальный mobile mapper даёт valid-кейсы
  байт в байт.
- **Mobile.** Typed `ClassWorkshopDraftData` в общем envelope, lossless
  persistence mapper (`class_workshop_details`; испорченное значение остаётся в
  `unknownFields`, новая schema — guarded read-only), wire mapper со scope
  UUIDv5 и UTC через существующий `EventTimezoneRepository`, coordinator,
  локальная readiness только по наличию обязательного, config-driven
  `ClassWorkshopCreateBlock` в общей Create page (общие taxonomy/criteria
  секции), Q4 controller, durable journal, default-off guard и тестовый маршрут
  `/test/class-workshop-publication`. Legacy `eventSlots`, Booking-флаги,
  посторонние секции, неизвестные поля и неразрешённое DST-время — явный
  локальный отказ; ничего не отбрасывается. Нет mobile Activate и
  редактирования после публикации.
- **Стенд.** `stand_content_class_workshop.ts` (seed/verify/status/manifest,
  фиксированные даты 2027-05-15/22 для повторяемого seed), группа Emulator
  `class-workshop`, `stand-d3-6-gate.mjs` с собственным изолированным root.

Уточнения реализации, не меняющие правил контракта:

1. `schema_version` ≠ 1 отклоняется на submit, approved publish и immutable
   activate кодом `content_type_unsupported` по §34.5, без fallback. Общий
   source-validator сохраняет внутренний issue `class_workshop.schema_unsupported`;
   C3 одинаково преобразует его в контрактный код. Regression-тест проверяет
   каждый путь и неизменность сохранённого состояния. Первоначальное отклонение
   закрыто исправлением кода, без изменения принятого контракта.
2. Длина полей без лимита в §34.4 (адрес, area label, take-home result,
   заголовок occurrence) проверяется только на непустоту, как у Session:
   агент не назначал новых product limits.
3. Section-виджет публикации помещён в файл panel
   (`class_workshop_publication_panel.dart`), чтобы не выходить за список
   файлов §6.4. Test world Class переиспользует D3.5 world (actors, Media, C2,
   cleanup), без копии cleanup-логики.
4. `stand-d3-5-gate` и прочие запускатели T1 не менялись, кроме регистрации
   новой группы в `run-emulator-test-groups`.
5. Два существующих теста `create_page_test` использовали Class как generic-форму.
   После появления typed block они проверяют то же поведение на пути Class:
   publish без cover блокируется с прежним текстом ошибки (block показывает её
   у поля cover), taxonomy picker меняет категорию и подкатегорию draft. Суть
   ассертов не ослаблена; generic-формы у выбираемых типов больше нет.

Фактические gates, lifecycle/state/receipts matrix и ограничения —
[evidence](../evidence/backend/d3/D3_6_CLASS_WORKSHOP_2026_10_19.md). Статус остаётся Review; самостоятельного перевода
в Accepted нет. Локальные коммиты: `f083d7c` (docs), `ef1356c` (backend),
`0f80e12` (mobile), `32cc0d3` (stand/evidence); 72 файла без пересечений.
Push, merge и deploy не выполнялись.


## 10. Общая версия 28–29 — 2026-10-20

Исторические base/worktree и числа §9 описывают исходный отдельный slice.
Текущая проверка выполняется в изолированной общей копии поверх `9881c48`
с итогом I1/I2 (26–27), CW-V1, Session, Scenario publication и существующим
Find People WIP; исходные рабочие деревья сохранены. Основания владельца
§1 не переутверждаются и scope не расширяется. Общий ledger и границы:
[28–29 common verification](../verification/T1_T2_COMMON_VERIFICATION.md).
Статус остаётся Review; окончательная приёмка bounded результата владельцем
не подменяется прохождением технических gates. Commit/push/merge/deploy нет.


Общие обязательные backend/Emulator и dedicated controller/UI gates повторены
после Session source-read privacy repair и завершены. Clean/resumed/repeated,
инварианты и verified cleanup прошли; готово к bounded-приёмке владельцем,
статус Review сохранён. Подробности — общий ledger28–29 по ссылке выше.
