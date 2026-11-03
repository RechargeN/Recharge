# R1 M2 — полная локальная приёмка, 2026-11-03

Этап программы «M2: полная локальная приёмка R1» (не путать с MOB-ARCH M2).
Candidate: `8330738` (`codex/recharge-integration` `b1bf615` + языковое ревью
`44fd676` + правило A34 + B1-local recheck). Все прогоны — на этом SHA в одном
чистом worktree (`.claude/worktrees/recharge-fold`), последовательно, rc
каждого шага записан сразу после команды, логи сверены. Дерево до и после
прогонов чистое. Push, merge и deploy нет.

Toolchain: Node 22.23.2, npm 10.9.8, Temurin 21.0.12+8, Terraform 1.15.9,
Firebase CLI из lock, Flutter 3.44.9 / Dart 3.12.2. Локальный Emulator стенд
`demo-recharge` на loopback ПК.

## Вердикт

**M2 не пройден.** Вердикт «R1 функционально проверен локально» не выдаётся:
три обязательных gate красные (дефекты ниже). Функциональные клиентские и
Emulator-проверки зелёные, но красные gates не обходятся и не ослабляются.
Статусы этапов B–L этим отчётом не меняются (остаются по LAUNCH_STATUS).

Владелец решил 2026-11-03 вести M2, не дожидаясь отдельной приёмки
Review-этапов: M2 перепроверяет их на одном SHA и даёт матрицу для приёмки.

## Красные gates и дефекты (follow-up slices)

| ID | Gate | Причина | Вид |
|---|---|---|---|
| M2-F1 | `test:r1:integration` (270/272), `stand-d2-gate` (70/72) | `content_publication_security.test` (Content ownership): закреплённые списки не знают модулей и callable-ов перевода ADR 0022 — `content_translation/*`, `index.ts`, `privacy_domain_task_runner.ts`; `translateContentV1`, `offerContentTranslationV1`, `syncContentTranslationsV1`, `sweepContentTranslationsV1`, `purgeContentTranslationsOnHoldV1`. Появились в `317b5d9` (stage 1) и `03a1e04` (amendment 1); тест последний раз обновлён в `b0fae53` (L3). Нужен review границы Content ownership, а не механическое обновление списков | дефект интеграции ADR 0022 |
| M2-F2 | boundary inventory `--check-output` | `MOBILE_BOUNDARY_INVENTORY.md` не перегенерирован после L4.9.5: в документе 640 файлов и 71 исключение, фактически 685 и 69 | устаревший generated-документ |
| M2-F3 | `verify:audit:full` | «Invalid advisory propagation graph»: новая moderate GHSA-g3hv-75wg-m249 (`minimatch <11.0.1`, через eslint) даёт в отчёте npm цикл `eslint ↔ @eslint-community/eslint-utils`; верификатор считает любой цикл ошибкой. Production и full graph: 0 high/critical, moderate 32 (на 2026-10-26 было 6/10) | дефект верификатора + новые moderate |

`test:media-tools` в цепочке: 21/24, `tokens, readiness and request checks`
→ `fetch failed`. Повтор файла (5/5) и всего набора (22 pass, 2 skip, 0 fail)
зелёные; записано как разовый сбой, оба прогона в evidence.

Native B1 на A34 в конце цепочки не запускался: телефон пропал из
`adb devices` (Windows видел ADB Interface). Для M2 это не требуется; native
B1 на A34 зелёный на `5da203f`, от которого `8330738` отличается только docs
([B1-local recheck](B1_LOCAL_RECHECK_2026_11_03.md)).

## Зелёные проверки на `8330738`

| Группа | Результат |
|---|---|
| Toolchain, cloud-context, format, lint, typecheck, generated, reproducibility, taxonomy, execution manifest, Content persistence / R1 layout, config, exports | pass |
| Backend unit / contract | 824 / 68 pass |
| Stand, Emulator runner, Reference Data, Security/Privacy, Identity/Publisher, audit policy, script self-tests | 43, 7, 8, 13, 15, 13, 93 pass |
| Полный Emulator | 25 групп PASS, 438 pass, 0 fail, 0 skip; raw-body probe pass |
| `flutter analyze` / `flutter test` | 0 issues / 2214 pass, 83 skip, 0 fail |
| Boundary self-test, boundary, `git diff --check` | pass (69/71) |
| Stand gates (реальные Flutter-клиенты и адаптеры) | A2, B1, B2, C1, C2, C3, D1, D3.1, D3.1 activity delivery, D3.2, D3.3, D3.4, D3.5, D3.6, D3.7, D3.8, D3.8 linked Place, D4, E1, E2a, E2, F1, F2, I3, J2 — pass |

## Матрица требований M2

| Требование | Evidence на `8330738` | Итог |
|---|---|---|
| Event | C3 (CreatePage → cover → модерация → публикация), B2 (Booking UI), E2 (два клиента) | pass |
| Place / Activity | D3.1, D3.2, D3.1 activity delivery, D3.8 и linked Place | pass |
| Rental / Collection | D3.3, D3.4, группы `rental`, `collection` | pass |
| Bookable Session / Class / Find People | D3.5, D3.6, D3.7, группы `session`, `class-workshop`, `find-people` | pass |
| Scenario / Route | I3, J2, группы `scenario-i2/i3`, `route-j1/j2`, `quick-plan` | pass |
| B Auth/Session, Booking | B1, B2, группа `booking`, raw-body | pass |
| C Media, модерация, Create | C1, C2, C3; D2 — **red (M2-F1)** | red |
| D real tools, restrictions, типы, import | D1, D3.x, D4 pass; D2 red (M2-F1) | red |
| E Catalog/Discover, F Notifications/Booking actions | E1, E2a, E2, F1, F2 | pass |
| G Library, H Reviews, K Moderation/T&S/Admin | группы `library`, `reviews-safety`, `moderation-k1`, `admin-support-k3` | pass |
| I Quick Plan/Scenario, J Route | `quick-plan`, `scenario-i2/i3`, `route-j1/j2`, I3, J2 | pass |
| L Privacy, Operations, Analytics, Localization | `privacy-l1`, `operations-l2`, `analytics-l3`, `content-translation`, mobile l10n tests; Content ownership для ADR 0022 — **red (M2-F1)** | red |
| Два пользователя и два независимых клиента | E2, F2 (два `flutter test` процесса), I1/I2 группы | pass |
| Клиентские flow/adapters с реальным Emulator | все stand gates выше | pass |
| Failure, retry, concurrency, revocation, import, recovery, rollback | B2 (lost response, offline, double tap, restart), B1 (revoke/expiry/localOnly), C3 (прерванный seed), D4 (lost answers, fenced rollback), E2 (hide race), F1 (outages), F2, A2 (export/import), L1/L2 | pass |
| Полные gates | M2-F1, M2-F2, M2-F3 | red |

## Оставлено для B1-device (в M2 не считается пройденным)

Физический Android по USB: `adb reverse` без изменения loopback-границы,
project identity и загруженные Functions с устройства; вход, Session
restore/revoke/expiry и `localOnly` в установленном приложении; реальные
permissions и выбор изображения (в приложении нет picker — cover и gallery
задаются путём); фон/возврат, закрытие пользователем, завершение процесса ОС,
restart с Session и operation journal; Booking, retry/unknown-outcome без
дублей; Create → cover → модерация → публикация → Discover → Details → Booking
на телефоне; два пользователя: телефон и второй клиент; Route GPS, GPX picker и
export; Import и binding rollback на клиенте; release-сборка и guards. iOS —
отдельно, среды нет.

## Evidence

Логи, `summary.tsv`, `env.txt`, скрипт цепочки и отчёт npm audit:
`C:\Users\User\Documents\Recharge-evidence\M2-2026-11-03`, SHA-256 файлов — в
`SHA256SUMS.txt`, его хэш —
`364aa41122328b99616463386fab64da7145db67cc90a4bfbb290ca6b0fc5f2a`.
