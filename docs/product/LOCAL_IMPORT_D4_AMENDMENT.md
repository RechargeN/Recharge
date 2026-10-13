# D4 — безопасный импорт локальных данных local → server (только Emulator)

Статус: **Review (2026-10-13), Windows-local Emulator evidence (§10).**
Ветка `claude/d4-local-import` от `e50f9a6` (D3.4), отдельный worktree
`C:/Users/User/.claude/worktrees/recharge-d4`.

## 0. Основание и граница

Заход D4 — «безопасный импорт local → server». В scope: dry-run; проверки
owner и PublisherRef; semantic hash; server ID; local→server mapping;
receipt/checkpoint; resume; deduplication. Прерванный и повторный импорт не
создают дублей. Локальный оригинал нельзя удалять до серверной проверки,
явного подтверждения пользователя и завершения recovery period.

Норматив: BCK-18 §16 и §33.5 (`MOBILE_BACKEND_INTEGRATION_STANDARD.md`),
BCK-07 §18 (`CONTENT_PUBLICATION_BACKEND_SPEC.md`), Release R1 «Безопасный
импорт локальных данных» (`RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md`
§3.5, §3.7). Выполнение импорта было закрыто решением **OD-04 / BCK18-OD-01**
(Open, «Disabled»). Поручение D4 владельца и его ответы (§1) — решение по
OD-04 **только в границах этого захода**: локально и в Emulator, для
черновиков Create четырёх типов. Production, облако и остальные семейства
данных им не открываются.

Не входит: submit и publish (импорт создаёт только серверный черновик);
перенос локальной публикации, модерации, ролей, верификации, членств, квот и
согласий как authority; Route, Scenario, Quick Plan, Session,
Class/Workshop, Find People, избранное, посещения, страницы, Booking (у них
нет серверного владельца или он не готов); identity mapping OD-08; облако.

## 1. Решения владельца (2026-10-13)

1. **Основа** — поверх D3.4: локальный коммит `e50f9a6` в
   `claude/d3-4-collection` (без push), ветка D4 от него. Импортируются Event,
   Place, Activity и Collection.
2. **Дедупликация на сервере по `importSourceKey`**: Content на `createDraft`
   от того же автора с тем же локальным ключом возвращает уже существующий
   черновик.
3. **Фото** импортируются через Media C1.
4. **Recovery period 30 дней**; удаление локального оригинала реализовано и
   доступно только после всех трёх условий.

---

## 2. Сервер: один черновик на автора и источник импорта

- `createDraft` (Session) уже принимал `importSourceKey`
  (`^loc_[A-Za-z0-9_-]{1,120}$`), но не дедуплицировал его. Теперь Content
  хранит привязку `local-import:v1:<createdByUserId>:<importSourceKey>` →
  `draftId` в коллекции привязок импорта `contentExternalBindings` (sha256
  ссылки), с той же проверкой уникальности при commit, что у delegated import.
- Повторный `createDraft` того же автора с тем же ключом **под любым ключом
  идемпотентности** возвращает тот же черновик в текущем состоянии (аудит
  `content.draft.import_replayed`). Тот же ключ для другого типа, рынка или
  PublisherRef — `idempotency_conflict`, никогда не второй черновик. Другой
  автор с тем же локальным ключом — свой черновик. Гонка параллельных
  `createDraft` даёт ровно один черновик (проигравший получает
  `revision_conflict`, повтор возвращает победителя).
- Порядок отказов прежний: тип выключен (`type_disabled`) и права
  проверяются **до** поиска привязки. Контракт ответа Content не меняется.
- Delegated import, черновики без `importSourceKey` и все остальные команды не
  меняются.

## 3. Mobile: инвентаризация и dry-run

### 3.1 Источник

Инвентарь аккаунта: текущий черновик Create и черновики локальной
библиотеки (Scenario, Route), которые только **перечисляются** как
`unsupported` (`type_not_importable:<type>`). Источник только читает.

### 3.2 Классы dry-run (без единого вызова сервера)

| Класс | Когда |
|---|---|
| `create` | тип импортируемый, owner и PublisherRef в порядке, сервер его ещё не получал (или импорт не доведён — `resume`) |
| `alreadyMapped` | квитанция `verified` и semantic hash не изменился; или черновик уже ушёл тестовым путём C3/D3.1/D3.2/D3.4 (`published_by_test_path`) |
| `conflict` | квитанция `verified`, но локальный черновик изменён (`local_changed_since_import`); импортируется снова только по выбору пользователя («Import again») в **тот же** серверный черновик |
| `unsupported` | тип не импортируемый; локальный id нельзя выразить ключом `loc_*`; маппер типа не может нести часть черновика (`unsupported_capability:<список>`) |
| `blocked` | `owner_mismatch` (организатор ≠ аккаунт), `publisher_missing`, `publisher_not_eligible` (локальная предпроверка `PublisherAccessCheck`; окончательно решает сервер) |

### 3.3 Semantic hash

`sha256` канонического JSON (ключи отсортированы, целые double как int)
от `{schema, typeId, localDraftId, publisherRef, body, media}`, где `body` —
тело маппера типа без серверного автора и без серверных медиа, `media` —
SHA-256 байтов каждого файла. Тот же хэш:

- хранится в сессии для каждого одобренного элемента — изменённый после
  одобрения элемент в этой сессии **не импортируется**;
- пишется в квитанцию и сравнивается при следующем dry-run (`alreadyMapped`
  или `conflict`) и перед удалением оригинала.

## 4. Mobile: выполнение

### 4.1 Сессия и checkpoint

Подтверждение пользователя создаёт сессию: id, аккаунт, inventory hash,
упорядоченные id и хэши одобренных элементов, checkpoint, статус
(`approved → running → completed`, `paused` при неизвестном исходе). Checkpoint
сдвигается только после durable-квитанции элемента (`verified` или
`failed`). Журнал — файлы `<support>/import/local-import-receipts-v1.json` и
`local-import-sessions-v1.json`, запись «временный файл → rename», до 200
квитанций и 20 сессий, привязка к аккаунту и publisher; чужие записи хранятся,
но не возвращаются.

### 4.2 Шаги одного элемента

| Шаг | Команда | Квитанция после ответа |
|---|---|---|
| 1. Черновик | `createDraft {}` с `importSourceKey`, ключ `li1-<24 hex>:create` | `created`: contentId, draftId, автор сервера, ревизия |
| 2. Медиа | Media C1: каждое фото к точному черновику; intent — UUIDv5 импорта (не пересекается с тестовыми путями); те же байты — тот же asset | после каждой загрузки; затем `mediaUploaded` |
| 3. Тело | `updateDraft` с ожидаемой ревизией, ключ `…:update:<rev>:<16 hex тела>`; при `revision_conflict` ревизия читается заново (только для своего автора) и тело маппится заново (review Collection принадлежит ревизии, которую создаёт сохранение) | `bodySaved`, хэш отправленного тела |
| 4. Проверка | `getDraft`: тот же contentId, автор, `importSourceKey`, ревизия не меньше, хэш тела = отправленному | `verified`, время; подтверждение прежнего импорта сбрасывается |

- Потерянный ответ (`unknown outcome`): сессия `paused`, следующий запуск
  повторяет шаг с тем же ключом. Потерянные квитанции: сервер по
  `importSourceKey` возвращает тот же черновик (§2).
- Повтор загрузки медиа с тем же intent (ответ потерян или квитанции
  потеряны) получает прежнюю, уже завершённую сессию загрузки, и Media отказывает
  передаче байтов (`session_expired`). Общий загрузчик
  `FunctionsMediaUploadGateway` тогда спрашивает `getAssetStatus`: если сервер
  уже принял ровно эти байты (тот же SHA-256 и размер) для того же черновика —
  `ready` возвращается без повторной передачи, `uploaded`/`validating`/
  `processing` доводятся теми же ключами `:confirm`/`:finalize`; иначе отказ
  остаётся. Обычная загрузка D3.x не меняется (статус не запрашивается).
  Дефект найден стендом G1 (2026-10-13).
- Отказ сервера на шаге 1 (например `type_disabled`) записывается за
  элементом и прогон идёт дальше; на шагах 2–4 — квитанция `failed` с кодом,
  следующий запуск продолжает с durable-шага.
- Импорт **никогда** не делает submit/publish и не переносит локальную
  публикацию или authority.

## 5. Локальный оригинал (recovery)

Удаление доступно только при всех условиях, по порядку:

1. квитанция `verified` (серверная проверка §4.2);
2. явное подтверждение пользователя «Keep the server copy»;
3. прошло 30 дней с подтверждения (`LocalImportCleanupPolicy`);

и сразу перед удалением:

4. свежая серверная проверка: черновик есть, тот же автор, contentId,
   `importSourceKey`, ревизия не меньше;
5. локальный черновик не изменён (тот же semantic hash), а удаляется ровно
   тот сохранённый черновик (`deleteDraftIfUnchanged` — одна сериализованная
   мутация слота черновика).

Иначе — отказ с кодом (`cleanup_<stage>`, `server_check_failed`,
`local_changed_since_import`); ошибка, откат или повторный импорт оригинал не
трогают. Повторный импорт изменённого черновика требует нового подтверждения.

## 6. Тестовый вход

Define `RECHARGE_TEST_LOCAL_IMPORT=true`, не release, binding `testBackend`,
loopback `demo-recharge/europe-west1` — все четыре условия сразу; тот же guard
защищает маршрут `/test/local-import`, каждую команду Content и каждую
загрузку Media. Страница «Import local data (test)»: Dry run, Approve import,
Run/Resume, по каждому элементу — класс, причина, серверное состояние,
судьба локальной копии; «Import again», «Keep the server copy», «Delete local
copy» (только когда разрешено).

## 7. Стенд и гейт D4

`scripts/stand-d4-gate.mjs --yes`: свежий стенд → базовый seed → `place seed`
(включает Place и даёт Page) → на этом ПК `local_import_stand_test.dart`:
потерянный ответ `createDraft` → `paused` → перезапуск возобновляет в тот же
серверный черновик; другая папка установки (квитанции потеряны) → тот же
contentId/draftId; повтор → `nothing_to_import`; удаление оригинала отказано до
подтверждения и до конца периода, после +31 дня — удалено, серверная копия
остаётся → инварианты → остановка.

## 8. Проверки

| № | Что | Уровень и файл |
|---|---|---|
| S1 | привязка импорта: один черновик на автора и ключ, другой автор отдельно, обновление того же черновика | parity (in-memory и Firestore): `content_repository_scenarios.ts` |
| S2 | повтор под другим ключом → тот же текущий черновик; другой publisher/рынок → `idempotency_conflict`; без ключа — без дедупликации; гонка → один черновик | parity: `content_repository_scenarios.ts` |
| S3 | другой тип → конфликт; другой автор → отдельный черновик; выключенный тип — до поиска; повтор не сбрасывает тело | integration: `content_local_import.test.ts` |
| M1 | хэш, scope и ключи, журнал (round trip, изоляция, мусор), политика очистки 30 дней | unit (Dart): `local_import_hash_and_policy_test.dart` |
| M2 | контроллер: закрытый вход, классы dry-run без сервера, импорт с проверкой, потерянные ответы и перезапуск, потерянные квитанции, конфликт и повторный импорт, изменение после одобрения, отказ create, удаление оригинала, Collection, unsupported | unit (Dart): `local_import_controller_test.dart` |
| M3 | инвентарь и защищённое удаление на реальном хранилище Create; guard; отправляемый `createDraft` | unit (Dart): `local_import_store_and_guard_test.dart` |
| M4 | повтор intent Media после завершённой сессии: готовый asset без второй передачи, доведение принятого, отказ при других байтах/черновике/состоянии | unit (Dart): `media_upload_gateway_replay_test.dart` |
| G1 | стенд §7 | гейт `stand-d4-gate.mjs` + `local_import_stand_test.dart` |
| R | регресс: полный бэкенд, `test:emulator`, `flutter analyze`, `flutter test`, boundary, гейт C3 | финальный прогон |

## 9. Откат

Без define тестовый вход закрыт — импорт не вызывается. Серверная привязка
импорта действует только для `createDraft` с `importSourceKey`; полный откат —
revert коммита D4: Content снова хранит `importSourceKey` без дедупликации
(уже созданные привязки остаются неиспользуемыми документами Emulator), mobile
теряет страницу импорта. Локальные черновики и квитанции не мигрируются;
серверные черновики не удаляются.

## 10. Открытые пункты и риски

- OD-04 принят только для этого захода (Emulator, 4 типа); OD-08 (identity
  mapping) открыт: автор берётся из Session, личный PublisherRef — локальный id
  аккаунта, сервер решает окончательно.
- Если черновик уже ушёл тестовым путём D3.x, а журнал того пути потерян,
  импорт создаст отдельный серверный черновик (тестовые пути не ставят
  `importSourceKey`).
- Библиотека черновиков (Scenario/Route) только перечисляется; их импорт — после
  BCK-10/BCK-11.
- Recovery period считается по часам устройства; серверного учёта периода нет.
- Физические устройства, Linux, облако и production не покрыты.

## 11. Карта файлов

Бэкенд (код): `src/modules/content/domain/content_draft.ts`,
`src/modules/content/domain/repositories.ts`,
`src/modules/content/infrastructure/firestore_content_repository.ts`,
`src/modules/content/infrastructure/in_memory_content_repository.ts`,
`src/modules/content/application/content_publication_service.ts`.
Бэкенд (тесты, гейт): `test/support/content_repository_scenarios.ts`,
`test/integration/content_local_import.test.ts` (Н),
`apps/backend/scripts/verify-r1-layout.mjs`,
`apps/backend/scripts/stand-d4-gate.mjs` (Н), `apps/backend/README.md`.

Mobile (новые): `lib/features/create/domain/entities/local_import.dart`,
`domain/repositories/local_import_gateway.dart`,
`domain/usecases/local_import_hash.dart`,
`application/local_import_type_adapters.dart`,
`application/local_import_cleanup_policy.dart`,
`application/local_import_controller.dart`,
`data/file_local_import_journal.dart`,
`data/functions_local_import_gateway.dart`,
`data/create_local_import_store.dart`,
`data/publication_journals_import_mapping.dart`,
`presentation/widgets/local_import_section.dart`,
`lib/app/di/local_import_composition.dart`,
`lib/app/presentation/local_import_panel.dart`; тесты
`test/unit/local_import_hash_and_policy_test.dart`,
`test/unit/local_import_controller_test.dart`,
`test/unit/local_import_store_and_guard_test.dart`,
`test/unit/media_upload_gateway_replay_test.dart`,
`test/backend_local/local_import_stand_test.dart`.
Mobile (изменяемые): `lib/features/create/data/datasources/create_local_datasource.dart`
(`deleteDraftIfUnchanged`),
`lib/features/media/data/functions_media_upload_gateway.dart` (повтор intent,
§4.2), `lib/app/di/service_locator.dart`,
`lib/app/router/route_names.dart`, `lib/app/router/app_router.dart`.

Документы: этот файл (Н), `CONTENT_PUBLICATION_BACKEND_SPEC.md` (§44),
`MOBILE_BACKEND_INTEGRATION_STANDARD.md` (addendum D4),
`BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md` (строка BCK18-OD-01),
`docs/architecture/LAUNCH_STATUS.md` (строка D4),
`docs/evidence/backend/d4/D4_LOCAL_IMPORT_2026-10-13.md` (Н).

## 12. Статус

**Review (2026-10-13).** Windows-local Emulator evidence; не Done; без коммита.
Результаты — в [evidence](../evidence/backend/d4/D4_LOCAL_IMPORT_2026-10-13.md).
