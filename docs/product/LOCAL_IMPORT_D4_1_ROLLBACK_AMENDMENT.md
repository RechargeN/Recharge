# D4.1 — безопасный откат импорта local → server (только Emulator)

Статус: **Draft — ожидает утверждения владельцем до кода** (2026-10-13).
Основа: D4 ([LOCAL_IMPORT_D4_AMENDMENT.md](LOCAL_IMPORT_D4_AMENDMENT.md)),
Latvia roadmap §3.7 «Безопасный импорт локальных данных», п. 3 «Откат без
потери оригинала»; заход 3 приёмки M1
([checklist](../verification/M1_LOCAL_CONTOUR_CHECKLIST.md)).

## 0. Граница

D4 §9 «Откат» описывает откат **реализации** (revert коммита). Откат
**результата импорта** пользователем в D4 отсутствует: серверный черновик,
созданный импортом, нельзя снять. D4.1 добавляет именно его и защищает
локальный оригинал от гонки с cleanup.

В scope: откат своего импортированного черновика, поколения binding,
серверный резерв cleanup с fencing token, клиентский журнал намерений,
UI импорта и отката, а также исправление класса D2 в контроллере импорта
(автоматическая перезапись при `revision_conflict`, см. заход 2).

Не входит: откат submitted или published контента; восстановление откатанного
черновика; импорт других семейств данных; облако, устройства, production.

## 1. Решения владельца (2026-10-13)

| Вопрос | Решение |
|---|---|
| Допустимый откат | Только своего импортированного черновика, ни разу не submitted и не published |
| Серверные правки | Ревизия черновика должна точно совпадать с ревизией из receipt; иначе отказ без override |
| Состояние черновика | Tombstone; не удалять физически и не воскрешать |
| Binding | Tombstone поколения; новый импорт создаёт следующее поколение |
| Повторы | Receipt и все ключи включают поколение; старый retry возвращает старый результат и не создаёт новый черновик |
| Параллельный повторный импорт | Атомарное выделение поколения и ровно одного черновика |
| Media | Content снимает ссылки; удаление только через штатный orphan reconcile с grace и fenced hold |
| Cleanup | Серверный резерв с уникальным fencing token, поколением и installation id |
| Истёкший резерв | Не снимается автоматически; rollback остаётся запрещённым до безопасного восстановления |
| Удалённый оригинал | Rollback запрещён локально и сервером |
| Receipt после rollback | `rolledBack` навсегда снимает право cleanup этого оригинала |

**Порядок cleanup.** (1) durable локальное намерение; (2) серверный резерв;
(3) удаление оригинала; (4) `completeImportCleanup` с точным token. После
удаления оригинала `releaseImportCleanup` запрещён. Потерянный ответ
восстанавливается повтором complete. Устаревший token не завершает и не снимает
новый резерв.

**Порядок rollback.** Сначала durable `rollbackPending`. При неизвестном
исходе cleanup запрещён, пока не получено окончательное серверное состояние.

**Инвариант.** Нет достижимого состояния, в котором утрачены и локальный
оригинал, и пригодная серверная копия.

## 2. Сервер

### 2.1 Binding импорта и поколения

Binding `local-import:v1:<createdByUserId>:<importSourceKey>` в
`contentExternalBindings` получает поля:

| Поле | Значение |
|---|---|
| `generation` | целое ≥ 1; у binding из D4 без поля — 1 |
| `state` | `active` или `rolledBack` (tombstone поколения) |
| `draftId` | черновик текущего поколения |
| `cleanup` | отсутствует, либо `{state: reserved \| done, fencingToken, generation, installationId, reservedAtUtc, leaseExpiresAtUtc, completedAtUtc?}` |

`createDraft` с `importSourceKey`:
- `active` → прежний черновик текущего поколения (дедупликация D4 без изменений);
- `rolledBack` → в одной транзакции `generation + 1`, новый черновик и
  `state: active`; гонка параллельных импортов даёт ровно один черновик,
  проигравший получает его же при повторе;
- повтор старой команды тем же idempotency key возвращает сохранённый
  результат своего поколения и ничего не создаёт.

Черновик получает аддитивное поле `importGeneration`; ключи клиента включают
поколение (§3.2).

### 2.2 Новые команды `contentCommandV1` (только Session, свой автор)

| Команда | Payload | Успех | Отказы |
|---|---|---|---|
| `rollbackImportedDraft` | `draftId`, `importSourceKey`, `generation`, `expectedRevision` | черновик `status: rolledBack` (tombstone, `revision + 1`), binding `state: rolledBack`, аудит `content.draft.import_rolled_back` | чужой автор или binding — `not_found`; у Content есть submission или публикация — `import_rollback_not_allowed`; ревизия — `revision_conflict`; поколение — `import_generation_mismatch`; резерв cleanup любой давности — `cleanup_reserved`; cleanup завершён — `original_removed` |
| `reserveImportCleanup` | `importSourceKey`, `generation`, `draftId`, `installationId`, `fencingToken` | `cleanup.state: reserved`, lease (тестовая константа стенда 900 с) | `rolledBack` — `import_rolled_back`; другой token при живом или истёкшем резерве — `cleanup_reserved`; `done` — `original_removed`; поколение — `import_generation_mismatch` |
| `completeImportCleanup` | `importSourceKey`, `generation`, `fencingToken` | `cleanup.state: done`; повтор — тот же результат | другой token — `cleanup_token_mismatch`; нет резерва — `cleanup_not_reserved` |
| `releaseImportCleanup` | `importSourceKey`, `generation`, `fencingToken` | резерв снят | `done` — `original_removed`; другой token — `cleanup_token_mismatch` |

Все четыре команды идут через существующий `contentCommandV1`; новых export
нет. Rollback и submit — транзакции над одним черновиком: побеждает первая,
вторая получает типизированный отказ. Rollback и reserve — транзакции над
одним binding: то же.

Новая query `getImportBinding` (`importSourceKey`) отдаёт автору поколение,
`state`, `draftId` и состояние cleanup без чужих данных: по ней клиент
восстанавливает неизвестный исход.

### 2.3 Media

`isMediaReferenced` не учитывает тела черновиков `rolledBack`. Asset
откатанного черновика становится сиротой и удаляется только штатным orphan
reconcile после grace и под fenced hold (BCK-14 AC-87). Asset, на который
ссылается другой черновик или ревизия, остаётся.

## 3. Клиент

### 3.1 Состояния receipt

Добавляются `rollbackPending`, `rolledBack`, `cleanupReserved` и поле
`generation`. Переходы:

| Из | Действие | В |
|---|---|---|
| `verified` / подтверждён | rollback: сначала durable `rollbackPending` с ключом и ожидаемой ревизией | `rolledBack` после ответа или чтения binding |
| `rollbackPending` | неизвестный исход | остаётся; cleanup запрещён; повтор тем же ключом или `getImportBinding` |
| подтверждён, период прошёл | cleanup: durable намерение с новым token → reserve | `cleanupReserved` |
| `cleanupReserved` | удаление оригинала (`deleteDraftIfUnchanged`), `localDeletedAtUtc`, затем complete | локальный оригинал удалён, сервер `done` |
| `cleanupReserved`, оригинал на месте | отмена пользователем | release тем же token |
| `rolledBack` | — | cleanup запрещён навсегда; повторный импорт требует нового одобрения и даёт `generation + 1` |

Rollback и cleanup одного элемента сериализуются локально (один журнал,
одна мутация за раз); между установками их разделяет серверный binding.

### 3.2 Ключи

Ключи `createDraft`, `updateDraft`, Media и новых команд включают поколение:
`local-import:g<generation>:…`. Ключи D4 без поколения считаются поколением 1.

### 3.3 Исправление класса D2

`_saveBody` контроллера импорта больше не перечитывает ревизию и не
перезаписывает чужую правку при `revision_conflict`: элемент получает
`conflict`, правка на сервере сохраняется.

### 3.4 UI

Секция импорта показывает «Roll back import» только для допустимого receipt
(подтверждение диалогом), состояния ожидания, успеха и типизированных
отказов; «Delete local copy» идёт по протоколу §1.

## 4. Обязательные сценарии и где они проверяются

| № | Сценарий | Проверки |
|---|---|---|
| 1 | Успешный rollback: оригинал побайтово сохранён, cleanup запрещён | integration, unit контроллера, стенд |
| 2 | Повтор, потерянный ответ, restart в `rollbackPending` | unit, стенд |
| 3 | Чужой автор, конфликт ревизий, submitted/published — отказ | integration, Emulator |
| 4 | Rollback против submit — один победитель | Emulator (настоящие транзакции Firestore) |
| 5 | Cleanup против rollback на одной и двух установках | unit, Emulator, стенд |
| 6 | Restart и потерянные ответы до и после удаления оригинала | unit, стенд |
| 7 | Истёкший резерв, устаревшие fencing tokens | integration, Emulator |
| 8 | Старый retry после rollback; два параллельных новых импорта | integration, Emulator |
| 9 | Media orphan reconcile после grace; asset с другой ссылкой сохраняется | integration |
| 10 | UI импорта и rollback: подтверждение, ожидание, успех, отказы | widget |

## 5. Карта файлов 3b

Пути от корня репозитория; «Н» — новый, «М» — изменяемый. Проверено на
`a93707d`: каждый путь «М» существует, каждый путь «Н» отсутствует. Карта
закрытая: файл вне неё — отклонение, которое сначала утверждается.

**Backend, код:**

| | Путь | Что |
|---|---|---|
| М | `apps/backend/functions/src/contracts/content_v1.ts` | четыре команды, query `getImportBinding`, `status: rolledBack`, `importGeneration`, коды отказов |
| М | `apps/backend/functions/src/content_entry.ts` | типы результатов новых команд и query |
| Н | `apps/backend/functions/src/modules/content/domain/local_import_binding.ts` | чистый lifecycle binding: поколения, tombstone, резерв, fencing |
| М | `apps/backend/functions/src/modules/content/domain/content_draft.ts` | переход черновика в `rolledBack` |
| М | `apps/backend/functions/src/modules/content/domain/repositories.ts` | чтение и запись binding в транзакции |
| М | `apps/backend/functions/src/modules/content/infrastructure/firestore_content_repository.ts` | binding с поколением и cleanup; `isMediaReferenced` без `rolledBack` |
| М | `apps/backend/functions/src/modules/content/infrastructure/in_memory_content_repository.ts` | то же для паритета |
| Н | `apps/backend/functions/src/modules/content/application/content_local_import_lifecycle.ts` | четыре команды и query |
| М | `apps/backend/functions/src/modules/content/application/content_publication_service.ts` | диспетчеризация; поколение в `createDraft` |

**Контракты:**

| | Путь |
|---|---|
| М | `packages/api_contracts/schema/content/v1/content_command.schema.json` |
| М | `packages/api_contracts/schema/content/v1/content_query.schema.json` |
| М | `packages/api_contracts/schema/content/v1/content_result.schema.json` |
| М | `packages/api_contracts/schema/content/v1/content_draft.schema.json` |
| М | `packages/api_contracts/schema/content/v1/fixtures/valid.json` |
| М | `packages/api_contracts/schema/content/v1/fixtures/invalid.json` |

`packages/api_contracts/CHANGELOG.md` не меняется: схемы Content ранее
менялись без записи в нём.

**Backend, тесты и gates:**

| | Путь | Что |
|---|---|---|
| М | `apps/backend/functions/test/support/content_repository_scenarios.ts` | паритет binding in-memory/Firestore |
| М | `apps/backend/functions/test/integration/content_local_import.test.ts` | поколения, старый retry, параллельный импорт |
| Н | `apps/backend/functions/test/integration/content_local_import_rollback.test.ts` | rollback, cleanup, fencing, Media orphan |
| Н | `apps/backend/functions/test/emulator/content_local_import_rollback.test.ts` | гонки на настоящих транзакциях Firestore |
| М | `apps/backend/functions/test/contract/content_fixture_parity.test.ts` | новые фикстуры |
| М | `apps/backend/scripts/verify-r1-layout.mjs` | регистрация нового integration-теста (корень `test/integration` закреплён) |
| М | `apps/backend/scripts/run-emulator-test-groups.mjs` | новая группа `import` с измеренным лимитом |
| М | `apps/backend/scripts/run-emulator-test-groups.test.mjs` | последовательность групп |
| М | `apps/backend/functions/package.json` | `test:emulator:import` |
| М | `apps/backend/scripts/stand-d4-gate.mjs` | стенд-сценарии rollback и cleanup |
| М | `apps/backend/README.md` | D4.1 и таблица групп Emulator |

Новый исходный файл `src/modules/content/...` в layout-верификаторах не
регистрируется: `verify-r1-layout.mjs` закрепляет `test/integration`, а не
`src/modules/content`; `verify-content-persistence-layout.mjs` проверяет только
отсутствие cloud SDK в ядре Content.

**Mobile:**

| | Путь | Что |
|---|---|---|
| М | `apps/mobile/lib/features/create/domain/entities/local_import.dart` | состояния, поколение, намерения |
| М | `apps/mobile/lib/features/create/domain/repositories/local_import_gateway.dart` | новые команды и query |
| М | `apps/mobile/lib/features/create/data/functions_local_import_gateway.dart` | их вызовы через `contentCommandV1` / `contentQueryV1` |
| М | `apps/mobile/lib/features/create/application/local_import_controller.dart` | rollback, протокол cleanup, восстановление, D2 |
| М | `apps/mobile/lib/features/create/application/local_import_cleanup_policy.dart` | запрет cleanup при `rollbackPending` / `rolledBack` |
| М | `apps/mobile/lib/features/create/presentation/widgets/local_import_section.dart` | кнопка, подтверждение, состояния |

`file_local_import_journal.dart` и `local_import_panel.dart` не меняются:
журнал сериализует receipt через его `toJson`/`fromJson`, панель только
встраивает секцию. Новых файлов в `lib/features` нет, inventory не меняется.

**Mobile, тесты:**

| | Путь |
|---|---|
| М | `apps/mobile/test/unit/local_import_controller_test.dart` |
| М | `apps/mobile/test/unit/local_import_hash_and_policy_test.dart` |
| М | `apps/mobile/test/unit/local_import_store_and_guard_test.dart` |
| Н | `apps/mobile/test/widget/local_import_section_test.dart` |
| М | `apps/mobile/test/backend_local/local_import_stand_test.dart` |

**Документы:**

| | Путь |
|---|---|
| Н | `docs/product/LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md` (этот файл, 3a) |
| М | `docs/product/LOCAL_IMPORT_D4_AMENDMENT.md` (3a) |
| М | `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md` |
| М | `docs/product/MOBILE_BACKEND_INTEGRATION_STANDARD.md` |
| М | `docs/product/BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md` |
| М | `docs/architecture/LAUNCH_STATUS.md` (строка D4) |
| Н | `docs/evidence/backend/d4/D4_1_ROLLBACK.md` |

## 6. Проверки 3b

Backend: format, lint, typecheck, unit, contract, integration, Emulator-группы
`content-media`, `collection` и новая `import`; гейты D4 и C1. Mobile:
`flutter analyze`, полный `flutter test`, boundary, inventory
`--check-output`, оба diff-check с waiver.

## 7. Откат реализации

Вход импорта и отката закрывается (define выключен), возвращается только
совместимый код. Tombstones черновиков, binding с поколениями, аудит и
receipts сохраняются; откатанные черновики не воскрешаются; локальные
оригиналы не трогаются.

## 8. Открытые пункты

- Длительность lease резерва — тестовая константа стенда, не production policy.
- Production, облако, OD-08 (identity mapping), устройства — вне scope.
