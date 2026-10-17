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

## Закрытие оставшихся пунктов, 2026-10-17

По запросу владельца «закончи заход полностью» подготовлены локальная
интеграция и публикация I1; K3 остаётся вне этого захода.

- R0 устанавливает Flutter 3.44.9 через `subosito/flutter-action`, закреплённый
  SHA `1a449444c387b1966244ae4d4f8c696479add0b2` также внесён в toolchain lock.
  Выполняется `flutter pub get`, затем проверяются и экспортируются пути
  `RECHARGE_DART` и `RECHARGE_FLUTTER_TOOL`. Обязательный тест настоящих
  адаптеров сохранён без skip-маркера. Timeout job увеличен до 60 минут.
- Terraform 1.15.9 установлен в `.r0-tools` штатным installer с проверками
  SHA-256, fingerprint ключа и GPG-подписи manifest. Системная Java оказалась
  21.0.12.1+1; для точного гейта отдельно загружена Temurin 21.0.12+8 из
  официального release с проверкой SHA-256. Глобальные установки не менялись.
- `verify:toolchain` через npm 10.9.8 / Node 22.23.2 с точными JDK/Terraform:
  exit 0, `Exact R0 toolchain and workflow manifest verified`.
- Полный backend `format:check`: exit 0. YAML workflow разобран; извлечённый
  из него шаг экспорта путей выполнен локально, оба файла существуют.
- Повтор `quick-plan` с путями из нового CI-шага: 5/5 pass, 0 skip,
  включая два настоящих Flutter-адаптера; cleanup подтверждён, runner exit 0.
  Этот повтор использовал системную Java 21.0.12.1+1; точная 21.0.12+8
  использована отдельно в успешном `verify:toolchain`.
- Boundary: 623 файла, 71/71 прежних исключений, 0 нарушений, exit 0.

Полные backend/Flutter/AVD результаты выше относятся к исходному коммиту I1
`f32b97f`. В закрытии меняются только CI, toolchain lock и документация;
полные suite и AVD повторно не запускались. Проверка CI на GitHub до push
не считается выполненной; локальная проверка не является Linux evidence.
Локальные журналы закрытия: `apps/backend/.r0-tools/i1-closure-*.log`.
