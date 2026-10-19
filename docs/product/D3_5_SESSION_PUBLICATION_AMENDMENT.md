# D3.5 — Bookable Session publication amendment, T1

- Revision: **0.2**, 2026-10-18.
- Status: **Review — bounded local implementation and required gates passed**.
- Current scope: **owner-authorized local/LV Emulator implementation, default-off**.
- Base/HEAD: `638f75284c710314517adb51260785600bbef1e8` (detached).
- Separate worktree: `C:/Users/User/.codex/worktrees/t1-session-docs/Recharge`.
- No commit, push, merge or deployment authorized.
- Sources: [Session v1.2](create/BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md),
  [BCK-07 v0.15 §46](CONTENT_PUBLICATION_BACKEND_SPEC.md),
  [D3.1 Q4](PLACE_D3_1_PUBLICATION_AMENDMENT.md),
  [D3.4 evaluator](COLLECTION_D3_4_PUBLICATION_AMENDMENT.md).

## 1. Решения владельца

Отдельный источник — явное решение владельца в чате T1 от 2026-10-18,
записанное также в Session §22.1. Это не вывод из запроса реализации,
существующего mobile Create flow, наличия валидатора или контракта другого типа.

1. Возврат Bookable Session разрешён по образцу D3.1–D3.4: только Emulator,
   новый amendment D3.5, база 638f752, отдельный worktree.
2. BOOKABLE_SESSION_CREATE_BLOCK_SPEC v1.1 → **v1.2 Approved slice spec**;
   SES-D01…D15 подтверждены как есть, без изменения содержания.
3. SES-OD-01: в v1 у фото/видеостудий нет отдельной подкатегории; Creator
   выбирает ближайшую существующую, применимую к Session. Пересмотр — BCK-20.
4. Booking authority нет: только externalBookingUrl. ECL-03/BCK-09 не
   применяются; hold/capacity/confirmed запрещены. maxPartySize — декларация
   внешней группы, не inventory и не доступный остаток.
5. Будущий content.session.authoring — default-off, только local/LV Emulator.
6. Сервер проверяет schedule rules и закрывающие exceptions, не материализует
   слоты и не хранит availability. Legacy eventSlots отклоняются.
7. Catalog/Discover исключены (BCK08-OD-04); существующий owner evaluator
   может вернуть eligible для пункта Collection типа Session после публикации.
8. Mobile — Q4 D3.1, существующий Create flow, personal publisher only;
   без mobile Activate и редактирования после публикации. Полный C3 — backend.
9. **Scope T1 — только документы:** Session v1.2, BCK-07 v0.15, строка session
   в coverage matrix, D3.5 Review с решениями и планом файлов. Затем остановка
   до подтверждения плана. Runtime, флаги, реестр, Emulator gates и commit/push
   разрешаются только отдельным следующим шагом.

Дополнительный ответ владельца в этом чате подтверждает два правила D3.5:

10. Activate старой immutable revision сохраняет её scheduleRevision и
    projectionWindowDays snapshot. Pointer меняется только через CAS по
    ожидаемому текущему pointer. Монотонна последовательность новых
    scheduleRevision, не активный pointer: после rollback номер может
    уменьшиться. Новый scheduleRevision — только через новый draft при
    изменении расписания (Session §10).
11. projectionWindowDays берётся из текущей reference revision (Emulator 30).
    Другое значение клиента — validation_failed без подмены. При activate
    snapshot сверяется с текущей reference revision; расхождение — отказ,
    как для справочных данных D3.1.

Ответ пп. 10–11 сам по себе не подтверждал runtime-план. После docs-only
checkpoint владелец отдельно принял план: «сейчас принимаю план, реализуй».
Это разрешает реализацию §6 и её local Emulator gates. Amendment и BCK-07
остаются Review; Session v1.2 Approved по явному решению владельца.
Commit/push/deploy не разрешены.

## 2. Разрешённые будущие границы

Один существующий Content aggregate и C3 команды; C2 moderation и C1/D2 Media
через owner-service commands. Прямые записи в чужие домены запрещены.
Client claims не устанавливают publisher authority, eligibility, capacity,
attendance, Booking authority или readiness Media.

Server source rules — именно Session §10–§13: ISO weekday 1..7, start < end,
без overnight/overlap/duplicate; 1..4 ranges/day, максимум 28 total; duration
30..180, buffer 0..180, notice 0..10080; current-reference window=30;
valid IANA timezone/confirmation и Session dst_policy_version=1; closing
exceptions с корректными local dates/time, максимум 366 active/future и
private note ≤140; party 1..20, free/fixed positive same-market Money,
безопасный HTTPS external URL. Категория — canonical S applicability;
dynamic criteria advisory-only (SES-D14), не blocking Event/Activity rules.

Session §12: title 5..80, shortDescription 20..180, fullDescription 50..2000,
cover, явное rights confirmation и локализованный alt text. Rights confirmation
не означает production legal proof. Не назначать дополнительные product
лимиты, отсутствующие в Session/common Content contract.

Сервер не запускает materializer, не хранит offers/availability, не создаёт
второй schedule или Booking engine. DST candidate skipping и preview остаются
существующим mobile механизмом Session. Event shift/overlap policy не копируется.
Не включать другие Create-типы, Catalog/Discover, Payments, providers или
production. Collection eligibility — существующий exact-ID read evaluator,
без Catalog projection/Discover enablement для Session.

## 3. Read-only сверка mobile → backend на 638f752

Исходные пути:

- apps/mobile/lib/features/create/domain/entities/session_draft_data.dart;
- apps/mobile/lib/features/create/domain/entities/session_schedule.dart;
- apps/mobile/lib/features/create/data/models/session_draft_mapper.dart;
- apps/mobile/lib/features/create/domain/usecases/validate_session_draft_usecase.dart;
- apps/mobile/lib/features/create/application/session_create_coordinator.dart;
- apps/mobile/lib/features/create/presentation/widgets/session_create_block.dart.

Typed local runtime уже существует. Persistence mapper пишет snake_case:
schema_version, resource_name, timezone_id/confirmed, amenity_ids,
max_party_size, schedule, exceptions, price, external_booking_url,
external_terms_url, legacy_schedule, revision; сохраняет unknownFields.
Schedule содержит schedule_revision, dst_policy_version, duration/buffer/
notice/window и weekly_rules. Exception содержит private_note и audit fields.
Это локальный формат, не доказанная совместимость с Content wire body.

| Область | Обязательство следующего шага |
|---|---|
| Envelope | Чистый wire mapper общих Create полей + typed Session; exact allowlist закрепить shared valid/invalid fixtures до подключения runtime |
| Authority | Personal PublisherRef и server author проверяются owner-service; organizer/client audit fields не являются grant |
| Default/coercion | fromJson имеет defaults/toInt и fallback price mode; raw invalid input не считать валидным из-за локального coercion |
| Persistence mirror | CreateDraftModel сохраняет session_details; повторный typed parse не должен тихо терять raw/unknown поля; конфликт — явный отказ без перезаписи оригинала |
| Legacy | Непустые legacy_schedule/eventSlots не вырезать для успешного publish; явный local отказ и server negative fixture |
| Schedule | Сохранить timezone/rules/exceptions/window без Event conversion; window не подменять 30 на клиенте; первое active schedule=1 при local draft=0 проверяется совместными fixtures |
| Media/location | Использовать существующий Session block; добавить отсутствующее явное pin evidence и rights/alt metadata в тот же draft, без нового flow/provider |
| Privacy | private_note, audit identity и private address не попадают в публичную allowlist/evaluator; owner read отдельно авторизован |
| Q4 | Journaled controller по существующему D3.1 pattern; после публикации закрыть edit/upload/submit, сохранить idempotent publish retry и owner hide/read |

Proposed wire shape: общие camelCase поля + session payload из typed mapper;
media asset references вместо локальных URL/путей. Exact null/absent encoding,
unknown/future refusal, locale/rights/alt round-trip закрепляются fixtures.
Неизвестное обязательное поведение означает blocker, а не permissive default.

## 4. Матрица обязательных зависимостей и отказов

| Зависимость / owner | Явный отказ |
|---|---|
| Отдельное подтверждение этого плана владельцем | Получено после docs-only checkpoint: «сейчас принимаю план, реализуй» |
| Emulator/local/LV + independent flag, existing entry | absent/off, non-Emulator, non-local/non-LV — closed |
| Identity: actor, capability, personal publisher scope | missing/revoked/foreign/page — отказ до изменения |
| Content type validator + composition rules | unknown/unavailable type, unsupported body или нарушение — отказ, без generic fallback |
| Reference Data: market/taxonomy S/locale/revisions/window | missing/stale/unavailable/outage — отказ; window mismatch — validation_failed без substitution |
| Existing IANA helper + Session DST metadata | unknown zone/unconfirmed correction/unsupported policy — отказ; device timezone не authority |
| Content CAS/idempotency/draft/submission/immutable target | stale revision/pointer, approval-body mismatch, same key with other payload — отказ |
| Media owner generation-pinned readiness/restriction | missing/not ready/stale/restricted/outage — отказ на новом переходе, replay по существующему контракту |
| Moderation owner disposition/review | нет действующего approval/grant/revision — отказ |
| Existing Collection exact-ID evaluator | unknown/withheld/unavailable/outage — текущие D3.4 отказы, без foreign writes |
| Internal Booking/provider availability authority | отсутствует намеренно; claims hold/capacity/confirmed/attendance — отказ |

## 5. Submit / publish / activate — аудит существующего pipeline

Путь: apps/backend/functions/src/modules/content/application/content_publication_service.ts.
На базе submit/publish вызывают source validator и composition rules.
Activate проверяет composition rules, **но не вызывает source validator
immutable body**. Это read-only finding, не passing evidence и не исправление
в T1. Будущий fix ограничить Session target внутри того же pipeline.

| Путь | Что обязательно проверять до сохранения |
|---|---|
| submitForPublication | Текущий draft revision, Session source/composition, schedule policy/sequence, capability/eligibility и Media |
| publishApprovedRevision | Именно approved body/revision; повторные текущие source/composition/policy/authority/Media проверки; approval не обход |
| activatePublishedRevision | Именно immutable target, не mutable draft; current-reference + snapshot, source/composition/eligibility/Media и expected-current-pointer CAS; snapshot не переписывается |

Сравнивать сохранённые aggregate/pointer, immutable bodies, receipts, audit и
owner effects, включая отсутствие посторонних изменений. Один одинаковый
запрещённый body обязан отказать на всех трёх путях, в том числе после прежнего
approval/publish. Activation rollback не требует монотонного активного номера.
Новая schedule sequence создаётся только через новый draft, как в §1.

## 6. Принятый владельцем точный план файлов

Пути от корня; Н — новый, М — изменение. Runtime-часть ниже отдельно разрешена владельцем после docs-only checkpoint.
Не создавать дополнительный service/layer, если существующего API достаточно.

### 6.1 Первый docs-only checkpoint: четыре документа

- М docs/product/create/BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md — v1.2 Approved, §10/§22/changelog.
- М docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md — v0.15 Review, exact source/test paths, §46.
- М docs/product/BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md — session row, v0.3 Review.
- Н docs/product/D3_5_SESSION_PUBLICATION_AMENDMENT.md — v0.1 Review, решения и план.

### 6.2 Будущий backend runtime

- Н apps/backend/functions/src/modules/content/domain/type_rules/session_rules.ts — Session source rules/media references; без materializer.
- М apps/backend/functions/src/modules/content/domain/content_type_registry.ts — Session validator + personal-only, остальные types неизменны.
- М apps/backend/functions/src/modules/content/domain/type_rules/validation_context.ts — trusted window в текущем lookup/context.
- М apps/backend/functions/src/modules/content/infrastructure/emulator_reference_data.ts — pinned Session applicability/current policy.
- М apps/backend/functions/src/modules/content/application/content_publication_service.ts — закрыть activate source-validation gap, schedule sequence/CAS/snapshot guards внутри C3.
- М apps/backend/functions/src/shared/feature_flags.ts — independent default-off content.session.authoring.
- М apps/backend/functions/src/content_entry.ts — type allowlist/flag routing, existing Emulator/local/LV guards.
- М apps/backend/functions/src/index.ts — читать flag через существующую entry; без новых production exports.

ReferenceDataPort не менять, если имеющийся ReferenceLookups достаточен.
Если потребуется изменение порта, точный условный путь:
apps/backend/functions/src/modules/content/application/ports/reference_data_port.ts.
Новый policy service, schema/migration или отдельный schedule owner не создавать.
Catalog runtime не менять: на базе его evaluator уже поддерживает Session.

### 6.3 Будущие backend tests и совместные fixtures

Новые:

- apps/backend/functions/test/unit/content/type_rules_session.test.ts;
- apps/backend/functions/test/unit/content/type_rules_session_create_compat.test.ts;
- apps/backend/functions/test/unit/content/emulator_session_reference_data.test.ts;
- apps/backend/functions/test/integration/content_session_enablement.test.ts;
- apps/backend/functions/test/emulator/content_session_callable.test.ts;
- apps/backend/functions/test/emulator/content_session_emulator_flow.test.ts;
- apps/backend/functions/test/support/content_session_world.ts;
- packages/api_contracts/schema/content/v1/fixtures/session_create_compat.json.

Изменяемые существующие regression assertions, без ослабления проверок:

- apps/backend/functions/test/unit/content/type_rules_unavailable.test.ts;
- apps/backend/functions/test/unit/content/content_authoring_types.test.ts;
- apps/backend/functions/test/unit/content/content_domain.test.ts;
- apps/backend/functions/test/integration/content_activity_enablement.test.ts;
- apps/backend/functions/test/integration/content_place_enablement.test.ts;
- apps/backend/functions/test/integration/content_publication_service.test.ts.

Session перестанет быть fixture недоступного типа только после разрешённого
включения; такие проверки используют оставшийся unavailable type. Общие
security/Media/Catalog assertions сохраняются; новые Session cases — в её
suite, без дублирования общих механизмов.

### 6.4 Будущий mobile: существующий Create + Q4

Новые, по текущему D3.1 pattern с общими Content/Media adapters и journal file:

- apps/mobile/lib/features/create/domain/usecases/build_session_content_body.dart;
- apps/mobile/lib/features/create/domain/entities/session_publication.dart;
- apps/mobile/lib/features/create/domain/repositories/session_publication_gateway.dart;
- apps/mobile/lib/features/create/application/session_publication_controller.dart;
- apps/mobile/lib/features/create/data/file_session_publication_journal.dart;
- apps/mobile/lib/app/di/session_publication_composition.dart;
- apps/mobile/lib/features/create/presentation/widgets/session_publication_section.dart;
- apps/mobile/lib/app/presentation/session_publication_panel.dart.

Изменяемые:

- apps/mobile/lib/app/di/service_locator.dart;
- apps/mobile/lib/app/router/app_router.dart;
- apps/mobile/lib/app/router/route_names.dart;
- apps/mobile/lib/features/create/application/controllers/create_controller.dart;
- apps/mobile/lib/features/create/presentation/widgets/session_create_block.dart.

Последние два пути — bounded pin confirmation + required media metadata
в той же форме/draft. Без map provider/picker, второго Create flow, Booking
engine или переноса бизнеса в UI. Test route/panel default-off по Q4, с
non-release/testBackend/loopback guards; gateway commands также guarded.

Новые tests:

- apps/mobile/test/fixtures/create/user_session_draft.dart;
- apps/mobile/test/unit/session_content_body_mapper_test.dart;
- apps/mobile/test/unit/session_publication_controller_test.dart;
- apps/mobile/test/unit/session_publication_test_entry_guard_test.dart;
- apps/mobile/test/backend_local/session_publication_stand_test.dart;
- apps/mobile/test/backend_local/session_publication_ui_stand_test.dart.

Изменяемые tests/support:

- apps/mobile/test/widget/session_create_block_test.dart;
- apps/mobile/test/backend_local/support/stand_backend.dart.

### 6.5 Будущие стендовые запускатели и evidence

Новые:

- apps/backend/functions/test/stand/stand_content_session.ts;
- apps/backend/scripts/stand-d3-5-gate.mjs;
- apps/backend/scripts/stand-d3-5-gate.test.mjs;
- docs/evidence/backend/d3/D3_5_SESSION_2026_10_18.md — фактическую дату gates указать в evidence.

Изменяемые:

- apps/backend/functions/test/stand/stand_content_event.ts — общий manifest shape;
- apps/backend/functions/test/stand/stand_main.ts;
- apps/backend/functions/test/stand/stand_digest.ts;
- apps/backend/scripts/stand-seed.mjs;
- apps/backend/scripts/run-emulator-test-groups.mjs;
- apps/backend/scripts/run-emulator-test-groups.test.mjs;
- apps/backend/scripts/verify-r1-layout.mjs;
- apps/backend/functions/package.json;
- apps/backend/README.md;
- docs/architecture/LAUNCH_STATUS.md;
- четыре документа §6.1 — будущие результаты, не заранее зелёные статусы.

Existing emulator-stand хранит root под LOCALAPPDATA общим для worktrees.
Будущий D3.5 gate обязан использовать отдельный собственный root вне Git,
не reset чужого стенда; verified stop и cleanup выполняются также при failure.
Не менять общие launchers сверх необходимого Session registration и self-tests.

## 7. Обязательная матрица будущей приёмки

| Проверка | Требуемое доказательство |
|---|---|
| Default closed | absent/off flag, non-Emulator/local/LV, unknown type, missing capability/personal scope; запрет до записи |
| Compatibility | Валидные и невалидные shared Dart/TS fixtures; unsupported/future/legacy не теряются; raw input не становится валидным из-за parser defaults |
| Schedule boundary | Bounds времени/чисел/ranges/counts, local dates/leap/DST где применимо, stale revision/window, missing reference и owner outage; без server projection |
| Full C3 | draft → update → media → submit → review → publish → owner hide / moderation restrict-restore → activate → новая revision; ответы + state + immutable bodies + receipts + отсутствие чужих изменений |
| Three-path refusal | Один и тот же запрещённый body на submit, approved publish, immutable activate; сохранённые snapshots/receipts/effects неизменны |
| Rollback | Старый schedule/window snapshot сохранён; CAS защищает текущий pointer; активный номер уменьшается, новая authoring sequence остаётся монотонной |
| Retry/recovery | Lost create/update/publish response, durable resume, interrupted/resumed и repeated seed без duplicates |
| Media/privacy | Generation readiness/restriction/restore, unavailable owner; private fields не выходят в public/evaluator responses |
| Real mobile | Настоящий controller и UI с Create repository против Emulator; Q4, personal server identity, guarded commands, без Activate/edit после publication |
| Regression | Остальные Create-типы и их enablement неизменны; полный Emulator набор одной сессией с проверкой изоляции |
| Stand | Self-tests изменённых runners; воспроизводимые clean/interrupted-resumed/repeated; verified stop, очистка всех собственных fixtures |
| Final gates | flutter analyze, полный flutter test, затронутые backend gates, boundary и diff-check; актуальные spec/LAUNCH_STATUS по фактам |

Неполный, упавший, прерванный или зависший прогон не green. Emulator evidence
не является device, staging или production evidence. Будущие scanner/processor
fakes и test-only staff authority должны быть явно названы в результатах.

## 8. Принятие плана и дальнейшие ограничения

Docs-only checkpoint завершён; затем владелец явно принял план §6 и разрешил
реализацию с local Emulator gates. Не повышать Review до Accepted самостоятельно.
Не коммитить, не push и не deploy.

Если будущая реализация требует не определённого контрактом поведения,
зафиксировать blocker до зависимого кода; не назначать product rules агентом.
Production Publisher/Identity/Privacy/Media gates, Catalog/Discover, Payments,
providers, полноценный map picker, Session templates и l10n не становятся
готовыми через этот bounded amendment.

Runtime/Emulator попытки вне docs-only scope были остановлены и их изменения
убраны. Они не являются evidence этого T1; незавершённый общий прогон не green.
После отдельного принятия плана runtime возвращён в пределах §6. Все gates
проверяются заново; прежние прерванные попытки не становятся зелёными.


## 9. Реализация после отдельного принятия плана

В пределах §6 реализованы Session source validator/media references, registry
v7 с personal-only publisher, independent default-off flag и trusted
ReferenceLookups window=30. Submit/publish проверяют schedule authoring
sequence; activate проверяет именно immutable target, current references и
window snapshot, затем existing composition/Media/CAS. Другие types не получают
нового enablement; новый API, schema, migration, Booking engine не добавлены.

Mobile: текущий Create draft/repository, wire mapper с явным unsupported
refusal и lossless persistence-mirror comparison, общие Content/Media adapters,
durable journal и Q4 controller/test panel. Required pin/rights/alt metadata
добавлены в существующий Session block/controller. Нет mobile Activate или
post-publication edit.

Фактические gates и lifecycle/state/receipts matrix:
[evidence](../evidence/backend/d3/D3_5_SESSION_2026_10_18.md). Авторизованные stand/shared gates завершены; статус остаётся Review, без
самостоятельного перевода в Accepted. Ранние прерванные прогоны не green.


### 9.1 Итоговые gates

- Emulator: 15/15 groups, 307 passed, 0 failed/skipped, 54 tasks; одна сессия,
  complete=true/code=0 и штатный shutdown. После Session прошли все пять
  последующих groups; own fixtures removed, shared checkpoints retained.
- Stand: clean = interrupted/resumed = repeated; настоящий controller 1/1
  и UI 1/1 против Emulator; verified stop/reset собственного isolated root.
- Backend: TypeScript/lint PASS, unit/integration/contract 1059/1059;
  затронутые layout/config/exports/generated/reference/persistence/manifest gates PASS.
- Flutter: analyze без замечаний; полный suite 1665 passed, 71 env-dependent
  skips; Session stand tests выполнены отдельно. API contracts: analyze clean, 25 tests.
- Изменённые runners: self-tests 9/9. Boundary: 0 violations, 71 прежняя
  suppression, 0 stale/expired. Diff/link/decision-text checks PASS.

Ограничения: default-off local/LV Emulator, personal publisher, external URL;
нет Session Catalog/Discover, Booking/capacity/hold/confirmed, Payments или
providers. Scanner/processor — stand fakes, staff grants — test-only. Это
PC-host evidence, не device/staging/production. Map picker/templates/l10n и
production Identity/Privacy/Media gates остаются вне этого slice.
