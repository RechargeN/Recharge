# I1 Quick Plan на исправленной базе — проверка, 2026-10-17

Ветка `claude/i1-quick-plan-rebase` от `bde8b79` (`codex/recharge-integration`
локально: `a1fcde5` → `36fabec` → `bde8b79`, fast-forward, без push). Код I1 —
snapshot незакоммиченной работы worktree `codex/i1-quick-plan` (7ed5, база
`a1fcde5`: 12 изменённых и 12 новых файлов); исходный worktree не менялся.
Спецификация слайса: [QUICK_PLAN_I1_SLICE_SPEC.md](../product/QUICK_PLAN_I1_SLICE_SPEC.md).

## Что добавлено к snapshot I1

- `firestore.rules`: явный deny `quickPlans` и `quickPlanCommandReceipts`
  (клиентский доступ и так закрыт правилом по умолчанию; теперь явный).
- `execution-manifest.json`: две записи `clientAccess: deny`,
  `owner: firebase_cli`, без TTL и составных индексов — документы читаются
  только по id (`<owner>:<planId>`, `<owner>:<sha256(idempotencyKey)>`).
- `rules_default_deny.test.ts`: аноним и аутентифицированный клиент получают
  отказ на чтение и запись обеих коллекций, включая id вида `<uid>:…`.
- Зависимые от Content гейты (`verify-content-persistence-layout.mjs`,
  `content_publication_security.test.ts`): точные записи для
  `quick_plan/firestore_quick_plan_service.ts` (guard Emulator, `sha256Hex`) и
  `quick_plan/quick_plan_contract.ts` (`canonicalJson`, `sha256Hex`). Коллекций
  Content I1 не читает и не пишет.
- Инвентарь границ mobile перегенерирован (623 файла, нарушений 0, 71/71).

## Проверки (этот ПК)

Toolchain: Node 22.23.2, Java `Temurin-21.0.12+8 (build 21.0.12+8-LTS)`
(из журнала прогона), Flutter `C:\src\flutter` с `FLUTTER_ROOT`. Итоги взяты из
самих журналов, не из сводки (см. поправку в
[BASELINE_GATES_FIX_2026_10_16.md](BASELINE_GATES_FIX_2026_10_16.md)).

| Гейт | Итог |
|---|---|
| build, format:check, lint, typecheck | pass |
| test:unit / test:contract / test:r1:integration | 735/735 / 55/55 / 254/254 |
| verify:execution-manifest | pass: 64 коллекции, 13 флагов |
| verify:content-persistence:layout | pass: 3 индекса Content, SDK в 5 Emulator-файлах, 18 одобренных внешних пользователей |
| verify:r1 layout/config/exports, test:emulator:runner (6/6), test:stand (43/43) | pass |
| **verify:toolchain** | **fail (окружение)**: закреплённого Terraform 1.15.9 на ПК нет; код не затронут |
| test:emulator (полный, одна сессия) | 13/13 групп PASS: 290 pass, 0 fail, 1 skip (Library, `RECHARGE_G_MOBILE=1`) |
| Library отдельно с `RECHARGE_G_MOBILE=1` | 9/9, включая настоящие Flutter-репозитории — skip закрыт |
| quick-plan (в полном прогоне) | 5/5, включая два настоящих Flutter-адаптера; cleanup подтверждён |
| Flutter analyze / test | 0 issues / 1652 pass, 0 fail, 69 skip |
| AVD `Medium_Phone_API_36.0_2` (`-read-only`), фаза 1 → `am force-stop` → фаза 2 | обе фазы exit 0; ожидание pending пережило остановку процесса и переустановку APK (`--no-uninstall`); ключи фикстуры удалены; AVD остановлен |
| boundary / inventory `--check-output` / `git diff --check` | pass |
| `stand-mobile-gate` (B1) / `stand-b2-gate` — исполняют изменённый allowlist `booking_callable_adapter.dart` | 4/4 / 3/3 повтора по 5 тестов; exit 0 |

Остальные stand-гейты (D3.x, C1, C3, D4, E2, E2a, F1, F2) в этом заходе не
запускались: I1 не меняет их код.

Первый прогон этого захода (до правок Content-гейтов) упал на
`verify:content-persistence:layout`, интеграционном тесте зависимостей Content и
группе quick-plan (не заданы `RECHARGE_DART`/`RECHARGE_FLUTTER_TOOL` — тест
отказывает, а не пропускает). Повтор выше — после исправлений.

## Карта 69 Flutter-skip

Все в `test/backend_local`; каждый файл исполняется своим гейтом:

| Гейт | Файлы (skip) |
|---|---|
| `stand-d3-1-gate` | place_publication_stand (6), place_publication_ui_stand (1), page_access_revocation_stand (8), publication_two_installs_stand (1) |
| `stand-d3-2-gate` | activity_publication_stand (6), activity_publication_ui_stand (1) |
| `stand-d3-3-gate` | rental_publication_stand (6), rental_publication_ui_stand (1) |
| `stand-d3-4-gate` | collection_publication_stand (7), collection_publication_ui_stand (1) |
| `stand-d3-8-gate` | activity_catalog_stand (1), activity_linked_place_stand (1) |
| `stand-mobile-gate` (B1) | booking_session_lifecycle_stand (4) |
| `stand-b2-gate` | event_booking_ui_stand (5) |
| `stand-c1-gate` / `stand-c3-gate` | media_upload_stand (3) / event_publication_stand (6), event_publication_ui_stand (1) |
| `stand-d4-gate` | local_import_stand (4) |
| `stand-e2-gate` / `stand-e2a-gate` | e2_client (1) / discover_catalog_stand (1) |
| `stand-f1-gate` / `stand-f2-gate` | notifications_inbox_client (1) / f2_client (1) |
| Emulator `library` (`RECHARGE_G_MOBILE=1`) | library_client (1) — исполнен выше |
| Emulator `quick-plan` | quick_plan_client (1) — исполнен выше |

## Открыто, решения владельца

1. **R0 CI и группа quick-plan.** `backend-r0.yml` запускает
   `npm run test:emulator` на раннерах без Flutter; группа quick-plan без
   `RECHARGE_DART`/`RECHARGE_FLUTTER_TOOL` падает по замыслу. После push I1 в
   этом виде Backend R0 станет красным. Варианты: поставить Flutter в R0 и
   задать переменные, или явный CI-маркер по образцу Library
   (`RECHARGE_G_MOBILE`) с локальным обязательным прогоном. Ослаблять тест без
   решения не стал.
2. **Terraform 1.15.9** для `verify:toolchain` — установка через
   `scripts/install-terraform.mjs` (загрузка с проверкой SHA-256 и GPG).
3. Push и merge — отдельное разрешение (Р-14). K3 сюда не входит: его агент
   сам добавляет deny и манифест для пяти коллекций; вставки I1 размещены в
   других местах тех же файлов, чтобы последовательный merge прошёл без
   конфликта.
