# L4.8 — коды отказов в схемах модулей (L4-G09): предложение

- ID: **LOCALIZATION-L4-8-PROPOSAL**
- Версия: **0.2**
- Дата: **2026-11-01**
- Статус: **Accepted (вариант A, 2026-11-01); этап B реализован, Review**
- База: `5ee6308`, ветка `claude/l4-8-error-codes-proposal`
- Решение: владелец (RechargeN) одобрил вариант A с рекомендациями D1–D8 (§8)
- Связано: [amendment L4](LOCALIZATION_L4_R1_AMENDMENT.md), L4-G09;
  [BCK-03](BACKEND_API_CONTRACT_STANDARD.md) §14, §25;
  [API_CONTRACTS_WORKFLOW](../api/API_CONTRACTS_WORKFLOW.md);
  [CONTRACT_CHANGE_TEMPLATE](../api/CONTRACT_CHANGE_TEMPLATE.md)

## 1. Вывод

Коды отказов шести модулей можно зафиксировать без изменения данных на
проводе. Для Identity Session нужно только сузить уже существующее поле
`error.code` до enum. Для Library, Quick Plan, Scenario и Route схем нет
вообще, поэтому предлагается добавить минимальные схемы только для отказов.

Рекомендация: одобрить вариант A из §5. Пользователь получит конкретные
сообщения вместо общих, а новый код нельзя будет добавить, минуя каталог.

Формулировка G09 устарела в одном месте: «их UI показывает английские
предложения». После L4.6 таких предложений в этих модулях нет, экраны
показывают общий локализованный текст (§3). Поэтому цель этапа B —
точность сообщений и контракт, а не перевод оставшегося английского.

## 2. Какие коды отправляет backend

Метод: разбор `reject(…)`, `rejected(…)`, `fail(…)`, `code:`, `reason:` и
TS-union в коде на базе `5ee6308`, плюс ручной разбор вызовов с вычисляемым
кодом. Это разбор текста, а не доказательство полноты: на этапе B список
должен подтвердить контрактный тест (§6).

Форма отказа в Library, Quick Plan, Scenario и Route плоская:
`{schemaVersion, kind: 'rejected', code, …}`. В Identity Session код лежит в
`error.code`. Параметр `code` в этих модулях (кроме Privacy и Identity)
объявлен как `string`, поэтому компилятор его не проверяет.

**Общие для транспорта** (`prepareTransport`, `resolveBookingActor`,
`index.ts`), приходят в Library, Quick Plan, Scenario и Route:
`unauthenticated`, `permission_denied`, `app_check_required`,
`feature_disabled`, `temporarily_unavailable` (retryable). Коды проверки сессии
(`session_refresh_required` и другие) этот транспорт не отдаёт, что подтвердил
компилятор на этапе B.

| Модуль | Callable | Коды модуля (кроме общих) |
|---|---|---|
| Library | `libraryCommandV1`, `libraryQueryV1` | `request_invalid`, `owner_changed`, `processing_restricted`, `idempotency_conflict`, `revision_conflict`, `object_unavailable`, `place_timezone_invalid`, `visit_date_future`, `snapshot_changed`, `cursor_invalid` |
| Quick Plan | `quickPlanCommandV1`, `quickPlanQueryV1` | `request_invalid`, `owner_changed`, `idempotency_conflict`, `id_collision`, `revision_conflict`, `deleted`, `access_denied`, `access_revoked`, `invite_limit`, `target_unavailable` |
| Scenario | `scenarioCommandV1`, `scenarioQueryV1` | `request_invalid`, `actor_changed`, `idempotency_conflict`, `id_collision`, `revision_conflict`, `source_revision_conflict`, `source_unavailable`, `conversion_invalid`, `distribution_invalid`, `intent_not_found`, `membership_conflict`, `recipient_unavailable`, `publication_active`, `access_revoked`, `not_found`, `not_found_or_forbidden`, `token_expired` |
| Route | `routeCommandV1`, `routeQueryV1` | `request_invalid`, `owner_changed`, `idempotency_conflict`, `id_collision`, `revision_conflict`, `deleted`, `not_found`, `payload_too_large`, `point_limit_exceeded`, `invalid_geometry`, `license_blocked`, `provenance_unverified`, `privacy_trim_invalid`, `privacy_trim_empty`, `privacy_trim_required`, `title_required`, `distribution_limit`, `publication_active` |
| Privacy intake | **нет callable** (§4) | `access_denied`, `subject_mismatch`, `invalid_contract`, `idempotency_conflict`, `request_not_found`, `revision_conflict` |
| Identity Session | `establishIdentitySessionV1`, `refreshIdentitySessionV1`, `recoverIdentitySessionsV1` | `unauthenticated`, `app_check_required`, `feature_disabled`, `invalid_contract`, `unsupported_schema`, `recent_auth_required`, `account_blocked`, `not_found_or_not_accessible`, `revision_conflict`, `session_limit_reached`, `rate_limited`, `contention`, `temporarily_unavailable` |

Коды, не вошедшие в таблицу, и почему:

- `capability_denied`, `target_not_found`, `moderation_decision_stale`
  (`scenario_publication.ts`) возвращаются как `kind: 'refused'` для
  moderation-адаптера и не проходят через `reject`: компилятор принял список
  Scenario без них.
- `temporarily_unavailable` в `library_privacy_task_handler.ts` относится к
  внутренней privacy-задаче, это не ответ клиенту.
- Остальные коды `PrivacyFailureCode` схлопываются функцией `failure()` в
  `invalid_contract`.
- `IdentityFailureCode` объявляет 21 код. В таблице только те, что были найдены
  первым поиском. На этапе B в схему вошёл весь union (итого 27 кодов с
  транспортом): любой из кодов может попасть в ответ через `error.code`, и только
  так компилятор может это проверить. Это уточняет D5.

## 3. Что доходит до экрана

| Модуль | Клиент | Что видит пользователь | Нет в каталоге |
|---|---|---|---|
| Library | `LibrarySyncClient` → `LibraryFailure(code)` → `ServerFavoritesRepository`, `ServerVisitedPlacesRepository` | Контроллеры Favorites и Visited ловят исключение и показывают общий текст («favorites_load_failed», «visits_load_failed»). Код не доходит | 8 из 15 |
| Quick Plan | `QuickPlanSyncClient` → `QuickPlanFailure(code)` → `ScenarioBuilderController.syncError` (тип `Object?`) | Фиксированные `quickPlanAccessUnavailable`, `quickPlanNotConfirmed`. Код не доходит | 8 из 15 |
| Scenario | `ScenarioSyncClient` → `ScenarioSyncFailure(code)`, `create_repository_impl` | Только за тестовым входом `RECHARGE_TEST_SCENARIO_I2`; экранной обработки кода нет | 14 из 22 |
| Route | `RouteSyncClient` → `RouteSyncFailure(code)` → `_LocalRefusal` → `RouteContentPublicationController.message` | Единственный модуль, где код доходит: `_messageLine` → `routeTrimRequired`, `routeTrimEmpty`, остальное → `UserMessageCatalog.publication`. Незарегистрированные коды дают общий текст | 15 из 23 |
| Privacy intake | Mobile-клиента нет | Ничего | 3 из 6 |
| Identity Session | `BookingFunctionsTransport` → `BookingCallableFailure(code)`, `_` заменяется на `-` | Обрабатывается в транспорте (восстановление сессии), дальше сообщения транспорта и платформы | 4 из 13 |

«Нет в каталоге» считается по кодам из §2 вместе с общими для транспорта. Код
учтён как имеющийся, если такой ключ есть в любом семействе каталога, поэтому
число — нижняя граница работы: смысл одинаковых кодов в разных модулях нужно
сверять. Нужно только для оценки объёма.

Клиентские коды в схему не входят, их производит сам клиент. Они идут в
семейство `_clientLocal` каталога: `answer_invalid`, `transport_unavailable`,
`journal_capacity_exceeded`, `import_not_reappliable`, `intent_rejected`,
`invalid_response`, `page_limit_exceeded`, `test_entry_disabled`,
`public_object_reference_required`, `explicit_self_report_required`.

Находки, которые стоит решить отдельно от контракта:

1. **Два написания кода.** `BookingFunctionsTransport` заменяет `_` на `-`
   (`session-revoked`), а `LibraryFailure(error.code)` и `RouteSyncFailure`
   получают такой код как есть. Значит, один отказ приходит и как
   `session_expired`, и как `session-expired`. Каталог должен либо
   нормализовать написание, либо регистрировать оба.
2. **Снята на этапе B.** В v0.1 здесь был вопрос о недостижимой ветке клиента
   для `session-revoked` и `session-expired`. Это была ошибка поиска:
   `assertCurrentSession` (`domain/session.ts`) бросает оба кода, ветка рабочая.
3. **Отклонение от BCK-03 §14.** Целевая форма — `{code, domainCode,
   messageKey, retryable}`. Плоская форма этих модулей ей не соответствует.

## 4. Privacy intake: особый случай

`PrivacyRequestIntakeService` используется только в собственном файле и
тестах: callable в `index.ts` нет, mobile-клиента нет. Контракт «схема ↔
каталог» покроет код, который пользователь сейчас увидеть не может. Условие
готовности захода требует все шесть модулей, поэтому здесь нужен отдельный
ответ (решение D4).

## 5. Варианты

| | A. Схемы только для отказов (рекомендация) | B. Полные схемы результата | C. Только реестр в документе |
|---|---|---|---|
| Что добавляется | `library/v1`, `quick_plan/v1`, `scenario/v1`, `route/v1`: `*_refusal.schema.json`; enum в `identity_session_result` | То же плюс все успешные ответы и команды | Таблица кодов в BCK-03 |
| Данные на проводе | Без изменений | Без изменений, но большие схемы могут вскрыть расхождения | Без изменений |
| Контракт с каталогом | Да, тот же механизм `_serverContracts` | Да | Нет: нечего проверять тестом |
| Объём | Небольшой | Большой, сравним с отдельным заходом на модуль | Минимальный |
| Риск | Схема отказов живёт отдельно от успешных ответов | Срок и новые блокеры | Коды снова разойдутся |

### Решения, которые нужны от владельца

| # | Вопрос | Рекомендация |
|---|---|---|
| D1 | Вариант A, B или C | **A** |
| D2 | Есть ли полномочия на новые домены схем. `API_CONTRACTS_WORKFLOW` §1 требует Accepted ADR для кросс-языковых схем и называет ADR 0019 только для Booking | Подтвердить или оформить запись. Другие домены схем уже существуют; об основании для новых пусть скажет владелец |
| D3 | Оставить плоскую форму отказа или переводить на `domainCode` из BCK-03 §14 | **Оставить** плоскую в v1 и записать как отклонение: смена формы ломает клиентов. Миграция — отдельно, в `v2` |
| D4 | Privacy intake: схема и каталог сейчас или после появления callable | **Сейчас схема, enum и каталог без UI**, с явной пометкой «транспорта нет». Иначе условие «все шесть модулей» надо смягчить до пяти |
| D5 | Identity Session: сужать `error.code` до enum (сейчас `string, minLength 1`) | **Да**, с `forward`-фикстурой: неизвестный код на клиенте даёт общий текст |
| D6 | Как backend подтверждает соответствие схеме | **Union-тип вместо `code: string` в `reject`** плюс контрактный тест «множество кодов = enum» |
| D7 | Новый код — это breaking? BCK-03 §25: добавление enum-значения «зависит от направления и профиля» | **Non-breaking** для этих модулей: отказ не влияет на деньги и полномочия, неизвестный код на клиенте даёт общий текст. Для `processing_restricted`, `account_blocked`, `app_check_required` — проверить отдельно |
| D8 | Что показывать при anti-enumeration: `not_found_or_forbidden`, `target_unavailable`, `recipient_unavailable`, `not_found_or_not_accessible` | **Один нейтральный текст**, не различающий «нет» и «нельзя» (BCK-03 §14 п. 7) |

## 6. Заявка на изменение контракта (если выбран A)

Заполнено по `CONTRACT_CHANGE_TEMPLATE.md`.

**Change Summary**

- Type: `non-breaking` (проводные данные не меняются; условие — решения D5, D7).
- Affected contract files, новые: `library/v1/library_refusal.schema.json`,
  `quick_plan/v1/quick_plan_refusal.schema.json`,
  `scenario/v1/scenario_refusal.schema.json`,
  `route/v1/route_refusal.schema.json`,
  `privacy/v1/privacy_intake_refusal.schema.json`; у каждого `fixtures/`
  (valid, invalid, forward). Изменяемый: `identity/v1/identity_session_result.schema.json`.
- Related ticket: L4-G09.

**Contract Impact**

- Endpoints: шесть пар callable из §2. Поведение не меняется.
- Request changes: нет. Response changes: только описание уже отправляемых
  отказов.

**Consumer Impact**

- Модули: `features/library`, `features/scenarios`, `features/create` (route,
  scenario), `features/booking` (транспорт сессии), `features/favorites`,
  `features/visited`, `core/localization`.
- Consumer update owner: **не назначен**, нужно имя.
- Migration: старые клиенты ничего не заметят.

**Codegen And Validation**: см. этап B. Генерируемый код правится только
генератором.

**Breaking Change Section**: не применяется при D3 «оставить» и D7 «non-breaking».

### Этап B после одобрения

1. Схемы, фикстуры, `reject(code: …Code)`, контрактный тест backend ↔ схема.
2. Семейства `UserMessageCatalog` (`library`, `quickPlan`, `scenario`,
   `route`, `privacyIntake`, `identitySession`), контракт и положительный
   контроль в `server_error_contract_test`.
3. Экраны: `syncError` типа `Object?` и общие тексты Favorites и Visited
   заменяются сообщением каталога; Route идёт через новое семейство.
4. Нормализация `_` и `-` (находка 1) и проверка находки 2.

Сообщения: большинство кодов ложится на уже существующие `error*`:

| Смысл | Коды | Сообщение |
|---|---|---|
| Конфликт, обновите | `revision_conflict`, `source_revision_conflict`, `snapshot_changed`, `idempotency_conflict`, `id_collision`, `membership_conflict` | `errorConflictRefresh` |
| Нет или нет доступа | `not_found`, `not_found_or_forbidden`, `not_found_or_not_accessible`, `access_denied`, `access_revoked`, `deleted`, `object_unavailable`, `source_unavailable`, `target_unavailable`, `recipient_unavailable`, `intent_not_found`, `request_not_found` | `errorNotFound` или новый нейтральный (D8) |
| Войдите, сессия | `unauthenticated`, `owner_changed`, `actor_changed`, `recent_auth_required` | `errorSignInRequired`, `errorSessionExpired` |
| Неверный запрос, обновите приложение | `request_invalid`, `cursor_invalid`, `invalid_contract`, `unsupported_schema`, `conversion_invalid`, `distribution_invalid`, `invalid_geometry`, `subject_mismatch` | `errorInvalidRequest`, `errorUpdateApp` |
| Нужен свой текст | `visit_date_future`, `place_timezone_invalid`, `processing_restricted`, `invite_limit`, `payload_too_large`, `point_limit_exceeded`, `license_blocked`, `provenance_unverified`, `privacy_trim_invalid`, `title_required`, `distribution_limit`, `publication_active`, `token_expired`, `session_limit_reached`, `account_blocked` | примерно 15 новых ключей lv/en/ru |

Проверки этапа B (из задания): полный Emulator-набор одной сессией; backend
`lint`, `typecheck`, `format:check`, `test:unit`, `test:contract`,
`verify:generated`; все mobile-проверки; гейты затронутых клиентов (j2, i3,
b2, плюс `library_client_test`, `quick_plan_client_test`, `route_j1_client_test`,
`scenario_i2_client_test` через эмуляторные группы).

## 7. Статус

| Этап | Состояние |
|---|---|
| A | Одобрен: вариант A с рекомендациями D1–D8 |
| B | Реализован, см. §8 и amendment §21 |

## 8. Решение и результат этапа B

Владелец одобрил вариант A с рекомендациями D1–D8. Отдельно остаётся открытым:
ответственный за обновление клиентов не назначен (§6), запись основания для новых
доменов схем (D2) сделана этим одобрением и другого документа не имеет.

- Новые схемы и фикстуры: `library/v1`, `quick_plan/v1`, `scenario/v1`, `route/v1`,
  `privacy/v1/privacy_intake_refusal`; `failureCode` в `identity_session_result`.
- Backend: `reject` и `rejected` принимают только коды своего модуля, проводные
  ответы не менялись; `module_refusal_contract.test.ts` сравнивает списки со
  схемами.
- Mobile: шесть новых семейств каталога, `CodedRefusal`, `refusal`, `forError`; оба
  написания кода (`_` и `-`) читаются как один; контракт в
  `server_error_contract_test` с положительным контролем.
- Экраны: загрузка и команды Favorites и Visit history, сообщения Quick Plan,
  сохранение Scenario, панель публикации Route. Незнакомый код даёт прежний текст
  экрана. Privacy intake покрыт контрактом, но на экран не выходит: нет транспорта.
