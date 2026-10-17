# K3 — ограниченные Admin/Support operations

Дата: 2026-10-16. База: `a1fcde5cb53fa99fe034611cbfdc1063e7b96ae8`,
ветка `codex/k3`, отдельный worktree `C:/Users/User/.codex/worktrees/k3/Recharge`.
Статус: **Done — bounded local/Emulator scope**. Локальный executable scope
разрешён прямым запросом владельца; это не Approval всей BCK-19.

## Проверенные зависимости

| Contract | Фактический статус базы |
|---|---|
| BCK-03 v0.3.22 | Review; local platform/Identity schemas, validators и disabled Session/Booking callables Present; product API absent |
| BCK-04 v0.4.35 | Review; local R1 security/privacy и disposable Emulator evidence; independent/qualified/production gates pending |
| BCK-05 v0.2.43 | Review; local R0/R1 tooling/config и credential-free CI; dev/stage/production evidence pending |
| BCK-06 v0.8 | Review; local in-memory/Emulator Identity authority и disabled Session callable; production decisions pending |
| BCK-19 v0.3 (вход) | Review; K3 local amendment v0.3.1 не закрывает production owner decisions |
| H/K2 `d4e3971` | Подтверждён ancestor `a1fcde5` |

## Scope и authority

[BCK-19 v0.3](ADMIN_SUPPORT_BACKEND_SPEC.md) существует на integration-базе и
остаётся Review. Прежний вывод об отсутствии backend относился к `efa9` на
`06dae49` и не описывает K3 checkout. Integration worktree не изменяется.

Один `AdminSupportService` реализует local-only scoped read, immutable repair
proposal, approval exact revision/hash и resumable execution. Нет нового
callable, UI, generic patch, экспорта данных или прямой записи в domain storage.
Единственные mutations — существующий `ModerationService.decide` для `restrict`
и `restore`, затем verified Content `applyModerationDisposition`.

Production staff identity/MFA/JIT, risk tiers, retention и approval policy не
придумываются. `test-only-k3-two-person-v1` — явный **synthetic server fixture**,
не Accepted product policy: active case, LV/type, exact content IDs, members,
разрешённые операции и обязательный approval TTL (положительный, максимум час).
Отсутствующая/неизвестная policy закрывает доступ. Клиент policy/grants не задаёт.
Сервис конструируется только в подтверждённом loopback demo-recharge Emulator.
Внешнего endpoint нет: StaffActor — trusted internal input, не client claims.

## Матрица capability → scope → чтение → proposal → approval → execution

Имена `adminRead/Propose/Approve/Execute` — только local fixture action IDs.
Они проверяются существующей server-side staff authority вместе с case member
allowlist; это не новые production capabilities. Session/account/grant expiry,
revocation, feature flag и LV/type проверяются по текущим backend records.

| Capability | Scope | Чтение | Proposal | Approval | Execution |
|---|---|---|---|---|---|
| `adminRead` | Active case + exact target IDs + LV/type | Только contentId/revision/visibility; audit до выдачи | Нет | Нет | Чтение статуса/receipt refs, без payload/reason |
| `adminPropose` | Case membership + exact targets | Не даёт reveal | Immutable ID/revision + typed command input, expected revisions, hash, proposer, case-policy hash | Нет | Нет |
| `adminApprove` | Та же case-policy и exact proposal revision/hash | Не даёт reveal | Не меняет оригинал | Другой principal; immutable record и server TTL | Повторно проверяется approver session/grant |
| `adminExecute` | Тот же case-policy, session-bound executor | Для выдачи статуса отдельно нужен `adminRead` | Не меняет оригинал | Обязательное неистёкшее approval | До 10 уникальных targets; owner commands и receipts |
| `restrict` | Текущий owner staff grant LV/type | Не даёт reveal | Команда фиксируется в proposal | Exact proposal | Отдельное право применения |
| `restore` | Текущий owner staff grant LV/type + исходный decision ID | Не даёт reveal | Новый proposal и approval | Exact proposal | Отдельное право снятия; `restrict` недостаточно |

## Execution и начало действия

Новая proposal revision требует нового approval. Approval/execution не меняют
proposal. Изменение case policy/targets/membership делает прежнее approval
непригодным. Перед каждым owner dispatch повторяются проверки executor,
approver, approval hash/expiry и scope; owner проверяет актуальную object
revision. Повтор уже выполненной команды получает сохранённый owner receipt,
а не повторяет проверку исходной revision против уже изменённого объекта.

Эффект начинается при **durable commit verified Content owner transaction**.
Proposal/approval сами ничего не меняют. Каждый target имеет стабильный owner
idempotency key и checkpoint. Сбой после owner commit оставляет `unknown`;
повтор восстанавливает тот же receipt. Общий `succeeded` возможен только после
всех обязательных receipts. `pending` с `partiallyCompleted` и per-target
`pending/unknown/completed/refused` делает частичное выполнение явным. Глобальной
атомарности/автоматического rollback нет: компенсация — новый approved repair.

Executor привязан к исходной session; смена executor/session и обновление
истёкшего approval не выполняются молча. Новые полномочия не изменяют старый
proposal. K3 runtime доказан на Event; другие Content types не объявлены проверенными этим набором. Ремонт здесь касается только Content visibility; T&S sanctions,
Booking, Identity, Media, Payments и прочие domain repairs вне scope.

## Acceptance и evidence

`test/emulator/admin_support.test.ts` вызывает реальные Moderation и Content
services; source Content создаётся/публикуется через существующие Media,
Identity и Content owner flows. Mock success owner не используется.

Покрываются:

1. Missing capability, чужие type/target scopes, expired/revoked session и
   отозванный grant; отсутствие policy и client actor/capability assertions.
2. Self-approval, execution без approval, immutable conflict, новая revision без
   approval, tampered payload, expired approval, stale target revision.
3. Раздельные `restrict`/`restore` grants, recheck approver/executor revocation
   и закрытого case.
4. Сохранение proposal и посторонних canonical pointer fields; partial repair
   не меняет отказавший target.
5. Response allowlist и audit failure: данные не возвращаются.
6. Fault injection после реального owner commit перед K3 result write: видимое
   unknown, восстановление receipt, один эффект; повтор partial multi-target.
7. TypeScript AST ownership contract для всего Admin module; положительные
   контроли запрещённых domain writes, foreign refs и storage API escapes.
8. Полная очистка Admin/Content/Media/Moderation/Booking, новых Identity records,
   новых Storage objects и восстановление flag snapshots с assertions.

## Follow-up: explicit registration пяти коллекций

По замечанию review добавлены explicit client deny в `firestore.rules` и
manifest entries ровно для `adminSupportCases`, `adminRepairProposals`,
`adminRepairApprovals`, `adminRepairExecutions`, `adminReadAudit`. Resource owner
остаётся `firebase_cli`; `clientAccess: deny`, TTL и composite indexes пусты.
Это регистрация существующих server-only records, не новая retention policy,
grant или runtime capability. До неё клиентский доступ уже закрывал fallback
Rules deny; после неё запрет также явно связан с инфраструктурным inventory.

Contract regression проверяет реальные имена `adminCollections`, explicit deny
и уникальную manifest entry; отрицательные контроли удаляют deny/entry и
подтверждают отказ. Rules runtime проверяет read/write для anonymous и
authenticated клиента во всех пяти коллекциях, затем удаляет свою Auth fixture.

### База и происхождение evidence

Рабочая ветка остаётся `codex/k3` на `a1fcde5`; `36fabec` из отдельного
baseline-захода **не слит**. Текущий patch целиком чисто применён поверх
`36fabec` во временном validation fixture tree
`C:/Users/User/AppData/Local/Temp/recharge-k3-registration-WidWAq`.
Чужие worktrees и ветки не изменялись. Порядок интеграции: сначала `36fabec`,
потом K3. Статусные выводы ниже относятся к этой combined snapshot, а не к
неисправленной базе `a1fcde5` отдельно.

Переданный owner report о предыдущей проверке K3 на `36fabec` является внешним
evidence. Ниже отдельно фиксируются собственные повторные проверки актуальной
дельты; прежние baseline failures не объявляются исправленными самой K3.

| Gate | Собственная проверка combined snapshot |
|---|---|
| execution manifest | PASS: 67 collections, 13 flags; provisioning/apply authority остаётся denied |
| Content persistence | PASS: 3 indexes, 5 SDK adapters, 18 exact outside users |
| runner + persistence self-tests | 7/7 PASS |
| backend unit | 735/735 PASS |
| backend contract | 58/58 PASS, включая K3 ownership/registration controls |
| backend integration | 254/254 PASS |
| lint / typecheck | PASS в собственном K3 checkout |
| full single-session Emulator | PASS: 13/13 groups, 292 passed / 1 existing skip, `complete: true`, `code: 0`; exact Temurin 21.0.12+8; K1 13/13, K3 7/7 и cleanup подтверждён. Session `recharge-emulator-tests-ZLLbd0` |
| fresh K1 diagnostic retry | PASS без изменений кода/таймаутов; не заменяет зелёный полный набор |
| Dart boundary / self-test | Повторно PASS: 620 files, 71 прежнее исключение, 0 violations |
| Flutter | Предыдущая собственная проверка: analyze clean, 1648 passed / 68 skipped; mobile не менялся |
| diff-check | PASS для tracked и всех новых файлов |

Прежние 9 manifest/index расхождений и Content persistence failure относятся к
базе `a1fcde5`. Исправление принадлежит `36fabec`; оба гейта повторно зелёные
на актуальном combined snapshot. Exact Java теперь найдена и проверена:
`C:/Users/User/AppData/Local/Temp/recharge-stage1-temurin-21.0.12-8/jdk-21.0.12+8`,
`Temurin-21.0.12+8`, `build 21.0.12+8-LTS`; Node 22.23.2 / npm 10.9.8.
Первый собственный прогон на `21.0.12.1+1` сохраняется только как исторический,
а не доказательство exact pin.

Прямые read adapters Library/Reviews/Trust & Safety не менялись; перенос за
Content read port остаётся отдельным архитектурным решением/slice. Проверка
combined snapshot не означает нового blanket approval этого долга или
production staff policy. Общий BCK-19, RUN-03/G5 и production остаются gated.

## Изменённые файлы

- `apps/backend/functions/src/modules/admin_support/admin_support_service.ts` — единственный новый runtime service.
- `apps/backend/functions/test/emulator/admin_support.test.ts` — real-owner runtime, negative/fault/partial checks и cleanup.
- `apps/backend/functions/test/contract/admin_support_ownership.test.ts` — ownership AST gate и положительные контроли.
- `apps/backend/functions/test/integration/content_publication_security.test.ts` — точный guard-only import seam.
- `apps/backend/firestore.rules` и `apps/backend/config/manifests/execution-manifest.json` — explicit deny и inventory пяти K3 collections.
- `apps/backend/functions/test/emulator/rules_default_deny.test.ts` — anonymous/authenticated deny и Auth fixture cleanup.
- `apps/backend/functions/package.json` — K3 group command.
- `apps/backend/scripts/run-emulator-test-groups.mjs` и `.test.mjs` — одна новая группа и self-test snapshot.
- `apps/backend/scripts/verify-content-persistence-layout.mjs` — только guardOnly entry K3.
- `docs/product/ADMIN_SUPPORT_BACKEND_SPEC.md` — local amendment v0.3.1.
- `docs/product/K3_ADMIN_SUPPORT_READINESS.md` — scope, матрица, evidence и blockers.
- `docs/architecture/LAUNCH_STATUS.md` — Done для bounded local scope; BCK-19 остаётся Review.

### Закрытие gate: полный Emulator-набор

В общей сессии `recharge-emulator-tests-fxMfI8` K1 завис на HTTP query после
`Failed to load function` для `moderationQueryV1`. Worker был запрошен в
18:14:18 UTC, ошибка зафиксирована около 18:14:48, runtime initialized — около
18:14:53. Это согласуется с превышением 30-секундного старта worker, но
окончательная причина не доказана. K1 group превысил 180000 ms; следующий его
task помечен `notRun`. Остальные 12 групп прошли, включая K3 и его cleanup.

Повтор только K1 в свежей сессии `recharge-emulator-tests-zL8F5H` прошёл
за 47821 ms, без изменения source, fixtures или timeout policy. Это
диагностическое evidence; тот общий прогон остался **INCONCLUSIVE**.

После запроса довести K3 до Done выполнен новый полный набор без изменений
runtime source, fixtures или timeout policy. Сессия
`recharge-emulator-tests-ZLLbd0`: все 13 групп PASS, 292 passed / 1 existing
skip, `complete: true`, `code: 0`; внешний runner также завершился с exit 0.
K1 прошёл за 47426 ms, K3 за 23646 ms. Ранее наблюдавшийся worker-load failure
не повторился; его первопричина не объявляется доказанной или исправленной.
Это собственный полный single-session результат актуальной combined snapshot,
а не сумма целевых повторов. Локальные acceptance gates закрыты; K3 — **Done
в bounded local/Emulator scope**. Интеграция baseline и K3, production policy,
RUN-03/G5 и device/cloud gates этим статусом не разрешаются.
Emulator остановлен; собственная Auth fixture нового Rules test удалена,
cleanup K3 подтверждён after-hook assertions. Изменений активных runtime
artifacts во время общей сессии не было.

Итоговый журнал: `C:/Users/User/AppData/Local/Temp/recharge-k3-done-emulator.log`; machine-readable summary: `C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-ZLLbd0/summary.json`.

Логи follow-up: `C:/Users/User/AppData/Local/Temp/recharge-k3-registration-`
`{unit,contract,integration,selftests,emulator,k1-retry}.log`; общий Emulator пишет
отдельный `summary.json`, путь фиксируется в основном журнале. Исторические
логи K3 `recharge-emulator-tests-feOaje` не заменяются результатами follow-up.

## Rollback и ограничения

Удалить Admin service/tests/group registration и вернуть документацию;
реальные локальные visibility effects компенсируются только owner `restore`,
не storage patch. Тестовые fixtures удаляются after-hook. Shared module owners,
mobile и function exports не менялись. Rollback регистрации удаляет только пять новых explicit deny/manifest entries; fallback deny продолжает закрывать клиентский доступ.
Staging/production access, BCK19 owner decisions и RUN-03/G5 остаются gated.
Нет commit, push, merge или deploy.

## Общая интеграционная приёмка 21–26 (2026-10-17)

Предыдущие записи, включая «Нет commit, push, merge», относятся к исходному K3 worktree.
Его snapshot перенесён без изменения исходной работы: `022bcb0` поверх I1,
общая runtime revision `9db93bb`. Финальный single-session Emulator: 14/14 групп,
299 pass / 0 skip, K3 7/7 и cleanup. [Полный отчёт](../verification/LOCAL_21_26_ACCEPTANCE_2026_10_17.md).
DEF-05 proposal не активирована в CI; BCK-19/production gates остаются открытыми.
