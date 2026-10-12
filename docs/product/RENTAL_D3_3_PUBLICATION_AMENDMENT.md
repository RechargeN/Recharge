# D3.3 — Rental / Equipment через Create, Content, Media и модерацию (только Emulator)

Статус: **Done (принято владельцем 2026-10-12) как ограниченный Emulator-slice; Windows-local Emulator evidence (§13); ограничения и долг — §12.1.** Решения владельца 2026-10-12:
Q1 — тестовая политика Emulator с явным списком тестовых пар (проверка пар
через BCK-20 reader; числа — предложения; зависимость BCK-20 открыта);
Q2, Q5, Q6 — как в §2; Q3 — (a) публикует только подтвердивший;
Q4 — activate Rental закрыт; Q7 — только общий `validation_failed`.
База: локальная `codex/recharge-integration` —
`651d1e427e1721cd5f9a4511fda15b17ed149777` (заходы 3–11 закоммичены; на GitHub
этой ревизии нет). Ветка `claude/d3-3-rental`, worktree
`C:\Users\User\.claude\worktrees\recharge-d3-3`.

Устроено как поправки D3.1/D3.2: **A** — Emulator lifecycle, **B** —
совместимость с формой Create (проверенное подмножество), **C** — Catalog/Discover
(без изменений).

## Что изменилось в ревизии 2

- База перенесена с `b1e678a` на `651d1e4`; учтены BCK-20 reader (D4/D8),
  подробности `validation_failed` (D6), activate/edit Activity (D7), проверка
  связанного Place на activate (D9), общий IO Place/Activity (D11), именованные
  группы Emulator (D3).
- Q1 разделён на **Q1a таксономию** (существующий BCK-20 reader) и **Q1b политику**
  (контракта нет — отдельная зависимость); 7 дней / 500 м / 50 км — только
  предложения.
- Q3 пересмотрен для двух участников lifecycle; чужое подтверждение не
  переписывается.
- Q4 пересмотрен: activate Rental закрыт до решения; добавлены отрицательные
  сценарии.
- Q5 — fail closed без увеличения окна.
- Добавлен Q7 (публичные подробности ошибок Rental) и точный план файлов (§11).

## 0. Основание и граница

Заход D3.3 — «только Rental / Equipment»: подключить принятый Rental validator,
обязательную обложку, Media readiness, включение только в Emulator, lifecycle
C3 и существующий mobile Create flow. `rental.cover_required` не ослабляется.

Не входит: изменения `rental_rules.ts` и реестра типов; Catalog/Discover и
Booking для Rental; семантика `unknown` (§8.3 спецификации); локальный
direct-publish RNT-PUB-01; Activate и правка после публикации на mobile; выбор
фото групп; другие типы; облако и deploy.

## 1. Аудит на `651d1e4`

### 1.1 Сервер

- `rental_rules.ts` (RNT-CRT-01 V1, Approved) зарегистрирован `available`.
  Media readiness проверяет ровно `rentalMediaIds` = `mediaRefs` + `photoRefs`
  групп. `rental.cover_required`: `mediaRefs` — 1..13 строк.
- Политика рынка/категории — **только** `lookups.rentalPolicy(category,
  subcategory)` (`RentalMarketPolicy`). Нет ответа → `rental.policy_unavailable`.
  **Провайдера нет ни в одной композиции**, включая Emulator: сейчас любая
  Rental в Emulator отклоняется.
- Валидатор Rental таксономию (`subcategoryApplies`) не вызывает: применимость
  пары сегодня определяется только наличием политики.
- Зависимости от времени и участника: свежесть `coverage.confirmedAtUtc`
  (`coverageFreshnessDays` от `nowUtc`), `attestation.policyVersion ===
  policy.policyVersion`, `attestation.acceptedByUserId === actorUserId`,
  `acceptedAtUtc <= now`, `createdByUserId` блоков — постоянный id.
- Где запускается валидатор: submit и publish (тело одобренной ревизии
  черновика, `actorUserId` = кто выполняет команду). **Activate валидатор не
  запускает**: проверяются тип, справочники (только факт разрешения), правила
  композиции, связанный Place (D9) и медиа целевой ревизии.
- Publish не привязан к автору черновика: его выполняет любой участник с
  `content.publish` для `publisherRef`; submit и update — только автор.
- Публичные подробности `validation_failed` (D6) — allowlist только для
  `activity.*`; коды `rental.*` уходят общим отказом без подробностей.
- Catalog: `catalogEnabledTypes = {event}` — Rental исключается
  (`type_disabled`); Booking handoff Rental игнорирует.

### 1.2 Таксономия (BCK-20)

- Принятый артефакт `category-system-1.4.3` читается `readLocalTaxonomy`
  (точная ревизия; неизвестная/недоступная/битая → явный код).
- Принятая Category System: `rental` **не** перечисляется в `applicableTypes`;
  белый список категорий Rental задаёт сам тип («каталог не знает про аренду»):
  `sport`, `water_activities`, `winter_seasonal`, `adrenaline_entertainment`,
  `auto_moto` (все пять есть в BCK-20; 16–36 подкатегорий каждая).
- Применимость **подкатегорий** к Rental не определена ни в Category System, ни
  в BCK-20. Существование пары в BCK-20 применимость не подтверждает.
  (Единственная пара с `rental` в `applicableTypes` — `other/other_event`,
  общий «открытый» профиль; к белому списку Rental она не относится.)

### 1.3 Mobile

- `RentalDraftData` почти совпадает с телом сервера; приватные данные —
  отдельно (`RentalPrivateAuthoringData`), проекция их не читает.
- Фото: в блоке Rental выбора фото нет; `rentalData.mediaRefs` и `photoRefs`
  групп UI не заполняет. Обложка — общее обязательное поле формы
  `draft.media.coverImage` (+ `gallery`).
- Политика — `RentalCreatePolicy.safeFallback` (белый список групп, флаги по
  группе); подкатегория — свободный текст без проверки; версии политики нет,
  у аттестации константа `'1.0'`; `acceptedByUserId` и `createdByUserId` блоков —
  локальный id; id групп и блоков — `loc_*` (`replaceLocalIds` есть).
- Общий IO D11 (`publication_journal_file.dart`, `publication_media_type.dart`)
  и шлюз с `typeId` — переиспользуются.

### 1.4 Расхождения: форма допускает → сервер отклоняет

| Правило сервера | Mobile | Решение |
|---|---|---|
| `rental.cover_required` | `mediaRefs` пуст; обложка в `draft.media` | Q2 |
| `rental.policy_unavailable` | политики на сервере нет | Q1b |
| `rental.subcategory_required`; применимость пары | свободный текст | Q1a |
| `rental.coverage_stale` | свежесть не проверяется | Q5 |
| `rental.attestation_user`, `availability_block_author` | локальный id | Q3 |
| `rental.attestation_stale_policy` | константа `'1.0'` | Q1b |
| `handover_precision_too_fine`, `delivery_radius` (max) | не проверяются | Q1b |
| `rental.external_url_fragment` | не проверяется | фикстура §B |
| `rental.local_id_unreplaced` | `loc_*` | UUIDv5 (§4) |

Обратного не найдено, кроме валюты платы за доставку (сервер проверяет только
формат кода).

## 2. Решения на утверждение

### Q1a. Таксономия Rental — через существующий BCK-20 reader

Предложение: Emulator-справочники для Rental читают ту же принятую ревизию
`category-system-1.4.3`; пара принимается, только если категория в белом
списке Rental **и** подкатегория существует в этой категории BCK-20.
Неизвестная/недоступная ревизия → явный отказ (`policy_unavailable` по проводу,
как у Activity). Это проверяет существование пары, **но не её применимость к
аренде**: применимость подкатегорий Rental — отдельное решение владельца
(варианты: (i) любая подкатегория белой категории; (ii) явный список пар в
политике Rental Q1b; (iii) профиль/флаг Rental в BCK-20 — изменение Category
System). До решения: **(ii)** с минимальным тестовым списком пар, помеченным
как test-only, либо Rental остаётся выключенным.

Белый список категорий — сейчас только в mobile (`safeFallback`); его серверная
копия относится к политике Rental (Q1b), а не к таксономии.

### Q1b. Политика Rental — отсутствующий контракт BCK-20 (зависимость)

**Зависимость:** в BCK-20 нет контракта политики Rental. Нужен принятый источник
для каждого поля `RentalMarketPolicy` (`enabled`/белый список и применимые пары,
`policyVersion`, `coverageFreshnessDays`, `absoluteMin/MaxMinutes`,
`minApproximatePrecisionMeters`, `maxDeliveryRadiusKm`, четыре флага
«требуется») с версией, по которой аттестация сверяется.

До его появления — только тестовая политика Emulator с явной пометкой
`test-only-rental-policy-1`, **не принятая политика**:

| Поле | Предложение | Источник предложения |
|---|---|---|
| белый список | 5 групп | Category System, `safeFallback` |
| `absoluteMin/MaxMinutes` | 60 / 129600 | спецификация §10.1 (рекомендация V1) |
| флаги «требуется» | по группам `safeFallback` | mobile |
| `coverageFreshnessDays` | 7 — **предложение** | §8.3 (Draft-рекомендация) |
| `minApproximatePrecisionMeters` | 500 — **предложение** | не задано спецификацией |
| `maxDeliveryRadiusKm` | 50 — **предложение** | не задано спецификацией |
| `policyVersion` | `'1.0'` — **предложение** | константа аттестации mobile |

Вариант владельца: не включать Rental в Emulator до появления контракта Q1b.

### Q2. Фото листинга (bounded)

`mediaRefs` = обложка + галерея из `draft.media` через Media C1, как у
Place/Activity. Непустые `rentalData.mediaRefs` или `photoRefs` групп → черновик
не отправляется (`unsupported_capability:rental.listing_media` /
`rental.group_photos`). Выбор фото групп — не в D3.3.

### Q3. Аттестация и участники lifecycle

Контракт: «текущая версия политики, принятая **действующим** пользователем;
скопированное подтверждение не годится» (§14); сервер сверяет
`acceptedByUserId` с исполнителем **и на submit, и на publish**.

- **Один участник** (автор = исполнитель publish): маппер ставит в
  `acceptedByUserId` серверный id **текущей Session** — только если локальное
  подтверждение дал этот же вошедший пользователь (`acceptedByUserId` формы =
  id текущего аккаунта); иначе черновик не отправляется
  (`attestation_required`). Чужое подтверждение не переписывается. То же для
  `createdByUserId` блоков (блок, созданный другим пользователем, не
  отправляется).
- **Два участника** (A создал, подтвердил и отправил; B — другой участник
  Page с `content.publish` — публикует): по текущему контракту publish B
  отклоняется (`validation_failed`, `rental.attestation_user`); B не может
  переподтвердить чужой черновик (update привязан к автору). Варианты:
  (a) принять: публикует только подтвердивший — fail closed; (b) изменить
  контракт: publish проверяет подтверждение автора одобренной ревизии, а не
  исполнителя — изменение правила валидатора, вне D3.3. **Предложение: (a)**,
  с тестом на двух участников.
- Зависимость теста: в Emulator есть только владельческое членство
  (`createOwnerMembership`); для участника B нужна тестовая запись активного
  членства с `content.publish` через Identity-репозиторий Emulator. Если
  eligibility не допускает не-владельцев — сценарий B фиксируется как
  `publisher_not_eligible`, а зависимость — как открытый пункт.

### Q4. Activate целевой immutable revision — закрыт до решения

Ранее проверенная публикация не гарантирует допустимость активации сегодня.
Activate Rental сейчас не проверяет ни политику, ни версию, ни свежесть.

- **До решения владельца activate для Rental отклоняется** (тип-специфичный
  отказ в композиции Emulator; указатель и эффекты не меняются). Hide и чтение
  владельцем остаются.
- Отрицательные сценарии (целевая ревизия опубликована при действовавшей
  политике): (1) политика стала недоступна; (2) версия политики изменилась;
  (3) подтверждение доступности устарело. Каждый → отказ без изменения
  указателя, ревизий и эффектов. Контроль: activate Activity/Place не
  затронут.
- Варианты разрешения позже: (A) activate прогоняет принятый валидатор Rental
  на целевой ревизии под текущей политикой и временем (fail closed, без
  `unknown`); (B) activate разрешён при устаревшей доступности **только** с
  принятой семантикой `unknown` (§8.3) — вне scope.

### Q5. Свежесть на publish — fail closed

Publish повторно валидирует: истёкшее подтверждение → `validation_failed`;
нужен новый draft с подтверждением → submit → review. Окно не увеличивается
ради тестов; тест времени — через управляемые часы (FakeClock/ServerClock), а
не через значение политики.

### Q6. Mobile (bounded)

Существующий publication flow по образцу Activity: черновик, медиа, submit,
publish, hide; тестовый вход `RECHARGE_TEST_RENTAL_PUBLICATION` (default off).
Activate и правка после публикации на mobile — вне D3.3.

### Q7. Публичные подробности ошибок Rental

Предложение: allowlist `rental.*` → путь поля в `validation_details.ts` для
полей, которые есть в форме (с общим сообщением для остальных), и показ возле
полей блока Rental через существующий feedback D6. Альтернатива: в D3.3 только
общий `validation_failed`.

## 3. Часть A (план, после решений)

- `content.rental.authoring` (default off); `emulatorAuthoringTypes` +
  `rental`; `authoringTypesFor` с четвёртым флагом. Collection и типы без
  валидатора выключены.
- Справочники Emulator для Rental: таксономия через BCK-20 reader (Q1a),
  `rentalPolicy` из тестовой политики (Q1b); ответы других типов не меняются.
- Activate Rental: отказ (Q4).
- Lifecycle: черновик `{}` → обложка и галерея → тело → submit (валидатор +
  readiness `rentalMediaIds`) → ревью C2 → publish → hide. Эффекты: Catalog
  `excluded: type_disabled`, Discover отказ, Booking игнорирует, D2 для фото.
- Отрицательные сценарии: нет обложки; обложка не готова (`media_not_ready`);
  категория вне списка / пара не применима / ревизия таксономии неизвестна;
  устаревшее подтверждение на submit и на publish (часы); устаревшая версия
  аттестации; publish вторым участником (Q3); приватное поле; activate ×3 (Q4).

## 4. Часть B (план, после решений)

Маппер: `RentalDraftData` + `draft.media` → публичное тело §7;
`RentalPrivateAuthoringData` не читается. UUIDv5 групп и блоков (ссылки
`groupId` переносятся); серверный id Session в аттестации и блоках — только по
правилу Q3; `mediaRefs` из `draft.media` (Q2). Не отправляется черновик
целиком: непустые `rentalData.mediaRefs` / `photoRefs`, чужая аттестация или
блок, `unknownFields`. Фикстура совместимости — строки §1.4 плюс граничные
случаи политики.

## 5. Часть C

Без изменений: Rental исключён из Catalog (BCK08-OD-04); mobile Discover —
локальный источник.

## 6. Стенд и гейт

`stand-seed.mjs rental seed | verify | manifest | status`;
`stand-d3-3-gate.mjs`: чистый = прерванный и возобновлённый = повторный seed
(digest); mobile против стенда. Подтверждение покрытия в seed — начало текущих
суток UTC (повтор в пределах прогона даёт тот же payload).

## 7. Обязательные повторы

По затронутым общим файлам: `content_entry.ts`, `index.ts`,
`emulator_reference_data.ts`, сервис Content (если Q4 реализуется в нём),
`validation_details.ts` (Q7), стенд → гейты D3.3, D3.2, D3.1, C3 и
`test:emulator` (все группы). Прочие гейты — только если затронуты их
механизмы.

## 8. Откат

Выключить `content.rental.authoring`; полный откат — revert коммита D3.3.

## 9. Координация

Emulator-прогоны и гейты — только при остановленном общем стенде и без
прогонов Codex (общие порты и `%LOCALAPPDATA%\Recharge\emulator-stand`;
гейт делает `reset`).

## 10. Открытые решения владельца

Q1a (применимость подкатегорий), Q1b (контракт политики или тестовая политика;
числа), Q2, Q3 (a/b), Q4 (закрыто сейчас; A/B позже), Q5, Q6, Q7.

## 11. Точный план файлов (после решений)

«Н» — новый, «М» — изменяемый. Пути от `apps/backend/functions/` (бэкенд),
`apps/mobile/` (mobile), корня (остальное).

### 11.1 Бэкенд: код (8)

| Файл | | Назначение |
|---|---|---|
| `src/shared/feature_flags.ts` | М | `contentFlagIds.rentalAuthoring` |
| `src/content_entry.ts` | М | `rental` в списке Emulator, `authoringTypesFor`, правило activate Rental (Q4) |
| `src/index.ts` | М | четвёртый флаг в `prepareContentCaller` |
| `src/modules/content/infrastructure/emulator_reference_data.ts` | М | Rental: BCK-20 reader (Q1a) + `rentalPolicy` (Q1b) |
| `src/modules/content/infrastructure/emulator_rental_policy.ts` | Н | тестовая политика и список пар (Q1a(ii)/Q1b) |
| `src/modules/content/infrastructure/emulator_rental_dependencies.ts` | Н | отказ activate Rental (Q4) |
| `src/modules/content/application/content_publication_service.ts` | М | только если отказ activate нельзя выразить портом композиции: необязательный порт правил активации по типу |
| `src/modules/content/domain/validation_details.ts` | М | allowlist `rental.*` (Q7) |

### 11.2 Бэкенд: тесты, стенд, скрипты (16)

| Файл | | Назначение |
|---|---|---|
| `test/unit/content/emulator_rental_policy.test.ts` | Н | политика = фикстура; пары; BCK-20 ревизия |
| `test/unit/content/type_rules_rental_create_compat.test.ts` | Н | коды по фикстуре совместимости |
| `test/unit/content/content_authoring_types.test.ts` | М | 16 сочетаний флагов, список типов |
| `test/unit/content/validation_details.test.ts` | М | Rental allowlist (Q7) |
| `test/integration/content_rental_enablement.test.ts` | Н | матрица флагов; activate ×3 (Q4); свежесть на publish (часы); два участника (Q3) |
| `test/integration/content_publication_security.test.ts` | М | allow-list импортов `content_entry.ts` |
| `test/emulator/content_rental_callable.test.ts` | Н | матрица по проводу; совместимость по проводу |
| `test/emulator/content_rental_emulator_flow.test.ts` | Н | lifecycle, эффекты, D2, отрицательные сценарии |
| `test/support/content_rental_world.ts` | Н | мир Emulator Rental (+ второй участник Page, Q3) |
| `test/stand/stand_content_rental.ts` | Н | seed / verify / status |
| `test/stand/stand_content_event.ts` | М | `contentRental` в манифесте |
| `test/stand/stand_main.ts` | М | команда `rental` |
| `test/stand/stand_digest.ts`, `stand_digest.test.ts` | М | метки `seed-rental` |
| `../scripts/stand-seed.mjs` | М | `rental` |
| `../scripts/stand-d3-3-gate.mjs` | Н | гейт D3.3 |
| `../scripts/run-emulator-test-groups.mjs`, `../scripts/verify-r1-layout.mjs` | М | тесты Rental в группе `place-activity` (или новая группа с измеренным timeout); регистрация integration-теста |

### 11.3 Контракты (2)

| Файл | | Назначение |
|---|---|---|
| `packages/api_contracts/schema/content/v1/fixtures/rental_reference_policy.json` | Н | тестовая политика и пары (Q1a/Q1b), сверка с `safeFallback` |
| `packages/api_contracts/schema/content/v1/fixtures/rental_create_compat.json` | Н | тела маппера и коды |

### 11.4 Mobile (≈16)

| Файл | | Назначение |
|---|---|---|
| `lib/features/create/domain/entities/rental_publication.dart` | Н | запись журнала, вложения |
| `lib/features/create/domain/repositories/rental_publication_gateway.dart` | Н | source, journal, gate |
| `lib/features/create/domain/usecases/build_rental_content_body.dart` | Н | маппер, scope UUIDv5, правила Q2/Q3 |
| `lib/features/create/data/file_rental_publication_journal.dart` | Н | на `PublicationJournalFile` (D11) |
| `lib/features/create/application/rental_publication_controller.dart` | Н | без activate/edit (Q6) |
| `lib/features/create/presentation/widgets/rental_publication_section.dart` | Н | секция |
| `lib/app/presentation/rental_publication_panel.dart` | Н | тестовая страница |
| `lib/app/di/rental_publication_composition.dart` | Н | guard, define, wiring |
| `lib/app/di/service_locator.dart`, `lib/app/router/app_router.dart`, `lib/app/router/route_names.dart` | М | регистрация и маршрут |
| `lib/features/create/presentation/widgets/rental_create_block.dart` (+ feedback) | М | только при Q7: подробности возле полей |
| `test/fixtures/create/user_rental_draft.dart` | Н | черновик и случаи совместимости |
| `test/unit/rental_content_body_mapper_test.dart`, `rental_publication_controller_test.dart`, `rental_publication_test_entry_guard_test.dart`, `rental_reference_policy_fixture_test.dart` | Н | unit |
| `test/backend_local/rental_publication_stand_test.dart`, `rental_publication_ui_stand_test.dart` | Н | против стенда |
| `test/backend_local/support/stand_backend.dart`, `test/unit/content_publication_gateway_type_test.dart` | М | seed/manifest Rental; `typeId: rental` |

### 11.5 Документы (5)

Эта поправка; §42 `CONTENT_PUBLICATION_BACKEND_SPEC.md`; строки
`LAUNCH_STATUS.md` и `BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md`; пометка в
`create/RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md`; раздел `apps/backend/README.md`.

## 12. Реализация (ревизия 3) и находки

Сделано по §11 без Q7-файлов (`validation_details.ts`, подробности в форме не
трогались) и без изменения `rental_rules.ts` и реестра типов.

- **Отказ activate** — необязательный порт сервиса Content
  `activationClosedTypes` (пустой по умолчанию); композиция Emulator передаёт
  `{rental}`. Отказ `type_disabled` до чтения целевой ревизии: указатель,
  ревизии и эффекты не меняются. Контроль в тесте: без порта та же активация
  проходит при недоступной политике, сменённой версии и устаревшем
  подтверждении — правила Rental на activate не применяются.
- **Политика** — `emulator_rental_policy.ts` = `rental_reference_policy.json`
  (сверка с `safeFallback` и таксономией mobile Dart-тестом); пары сверяются с
  ревизией BCK-20 через `readLocalTaxonomy`; вне списка — нет политики.
- **Маппер**: ревизия блока в Create считается с 0 (не правился), в контракте —
  с 1; маппер отправляет `revision + 1` (перенумерация, не новое значение).
  Дополнительно не отправляются: исключения по датам в часах работы
  (`rental.hours_exceptions`), чужая аттестация (`rental.attestation_foreign`)
  и чужой блок (`rental.block_foreign`).
- **Фикстура совместимости** — 10 случаев, у каждого ровно один код валидатора;
  по проводу каждый непустой случай — `validation_failed` без кода (тело
  пересчитывается на текущие сутки и на вызывающего Creator, чтобы тест не
  устаревал).
- **Группа Emulator `rental`** — отдельная от `place-activity`; замер 74 188 мс,
  timeout 180 000 мс (инвариант runner: ≥ 1,75 × замер + 30 с).

### 12.1 Находки и решения владельца (2026-10-12)

1. **Lifecycle (вне D3.3).** Истёкшее подтверждение после одобрения: publish
   отклоняется (fail closed), одобренную submission нельзя вернуть на ревью
   (`moderation_decision_stale`), черновик `submitted` нельзя изменить
   (`revision_conflict`). Решение: отдельный общий Content-slice — отзыв
   submission владельцем, аннулирование прежнего approval и новый цикл
   submit → review → publish **с сохранением `contentId`**.
   **Ограничение D3.3 до этого slice:** если подтверждение доступности Rental
   истекло между одобрением и публикацией, эту Rental нельзя ни опубликовать,
   ни изменить; путь вперёд — только новый Rental-черновик (новый `contentId`),
   а у уже опубликованной Rental застрявший черновик блокирует её дальнейшие
   ревизии. Тест фиксирует это поведение.
2. **D2 и закрытый activate — принято как временное ограничение.** Снятие
   ограничения фото не снимает подавление; активация издателем для Rental
   закрыта (Q4). Проверено фактически (Emulator):
   - после снятия ограничения новая ревизия, **повторно использующая те же
     media id**, проходит ревью и публикацию; подавление очищается, фото снова
     выдаётся (pin есть);
   - пока ограничение действует, ревизия с этим же фото отклоняется на submit
     (`media_not_ready`), указатель не меняется; ревизия без этого фото
     публикуется, подавление очищается, остальные фото выдаются.
   То есть восстановление — через новую ревизию с полным ревью, и только после
   снятия ограничения (или без этого фото).
3. **`revision + 1` — принято** как преобразование нумерации модели (Create
   считает с 0) в нумерацию wire-контракта (с 1). Закреплено тестами: маппер
   не изменяет черновик; повторное преобразование даёт ту же ревизию; сохранение
   через контроллер не переписывает черновик Create (ревизия блока остаётся 0);
   существующие черновики автоматически не меняются.
4. **Allow-list с базы исправлен отдельным коммитом** `72f01d3` (`canonicalJson`,
   `sha256Hex` у `content_catalog_source.ts`); проверено отдельно на
   `651d1e4` + исправление: `test:r1:integration` 220/220.
5. **Тестовая политика Rental остаётся только в Emulator.** Отсутствие
   принятого контракта политики Rental в BCK-20 блокирует дальнейшее
   runtime-подключение Rental за пределами Emulator.
6. **Расхождения формы и сервера** (§12, строгость, которой нет в форме)
   допустимы по Q7 (общий отказ), но остаются явным **долгом UX**.
7. **Пропуски Flutter:** D3.3 добавил ровно пять пропусков — стендовые тесты
   Rental (`rental_publication_stand_test.dart` — 4,
   `rental_publication_ui_stand_test.dart` — 1); без стенда они пропускаются, в
   гейте D3.3 выполняются и проходят. Из существующих тестовых файлов изменён
   только `test/backend_local/support/stand_backend.dart` (seed/manifest
   Rental, без тестов).

## 13. Проверки (Windows-local)

База коммита D3.3: `72f01d3` (= `651d1e4` + исправление allow-list, §12.1 п. 4).
Отпечаток: пути, отличающиеся от базы, и неотслеживаемые файлы, «путь TAB
SHA-256 (без CR)», отсортировано; первые 12 hex SHA-256 списка; исключены
только этот документ и `LAUNCH_STATUS.md`.

**Полный прогон** на `651d1e4+wt:060d7e713d1a` (до решений §12.1; отпечаток до
и после совпал, 50 файлов):

| Проверка | Результат |
|---|---|
| `test:emulator` (7 групп) | 223/223 за 831 с |
| гейт D3.3 | пройден: чистый = прерванный и возобновлённый = повторный seed (digest), mobile против стенда — контроллер 4/4, UI 1/1 |
| гейты D3.2, D3.1, C3 | пройдены (D3.1 — с реальной выдачей фото Place 4/4) |
| `test:r1:integration` | 228/229 — единственное падение: allow-list с базы (исправлено `72f01d3`) |

**Повтор затронутого** на `72f01d3+wt:19d16b0c94f0` (после решений §12.1:
тесты восстановления D2, тесты `revision + 1`, границы группы `rental`,
документы; отпечаток до и после совпал, 50 файлов):

| Проверка | Результат |
|---|---|
| сборка, typecheck, lint, Prettier, `git diff --check` | чисто |
| boundary | 0 нарушений, 71/71 |
| `test:unit` / `test:r1:integration` / `test:contract` | 710/710 / **229/229** / 54/54 |
| тесты стенда / тесты runner | 42/42 / 6/6 |
| стражи `verify-*` (6) | пройдены |
| Emulator-группа `rental` | 13/13 (callable 4, flow 9, включая два сценария восстановления D2); 87 744 мс при timeout 210 000 мс (baseline 88 186 мс) |
| `flutter analyze` / `flutter test` | 0 замечаний / 1533 пройдено, 37 пропущено (новые пропуски — только 5 стендовых Rental-тестов, §12.1 п. 7) |

Гейты и прочие Emulator-группы на втором отпечатке не повторялись: изменились
только тесты группы `rental`, mobile unit-тесты, граница группы и документы;
стенд, seed и стендовые mobile-тесты не менялись. Остальные гейты (D2, D1, F2,
F1, E2, E2a, E1, C2, C1, B2, mobile, acceptance) не повторялись: их механизмы
D3.3 не меняет (§7).
