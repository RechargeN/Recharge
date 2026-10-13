# Release M1 — итоговая приёмка (заход 3c)

Дата 2026-10-13. Checklist:
[M1_LOCAL_CONTOUR_CHECKLIST.md](../../../verification/M1_LOCAL_CONTOUR_CHECKLIST.md).

**Вердикт: «первый локальный контур проверен».** Все обязательные пункты
checklist — состав §1, сценарии §2, клиентское покрытие §8 и gates §5 — зелёные
на одном runtime SHA, на чистом изолированном worktree; открытых обязательных
локальных критериев нет. Прогон 2026-10-13 22:14 — 2026-10-14 00:19 (+03:00).

Это не Release R1 и не production-, staging- или cloud-ready. Вне M1 остаются
внешние gates checklist §3: Linux-gate D1, `infra:r1:validate` и
`infra:r1:plan`, Linux-паритет GitHub Actions, физические Android/iOS
(B1-device: реальные permissions, background/foreground, завершение приложения
ОС, USB, сохранение данных на устройстве), cloud, staging, production.

## SHA

| Что | SHA |
|---|---|
| Проверенный runtime | `e3710f65ba595e14d4ebd578bcb208670eb81a1d` (`claude/m1-3-import-rollback`, заход 3b) |
| Документальное завершение | коммит, который добавляет этот файл; его родитель — runtime SHA, и он меняет только `docs/verification/M1_LOCAL_CONTOUR_CHECKLIST.md`, `docs/evidence/backend/m1/M1_ACCEPTANCE.md` и `docs/architecture/LAUNCH_STATUS.md` |

Цепочка M1: `3738cce` (база) → `1ad1c96` (заход 1, контракт и документальные
gates) → `a93707d` (заход 2, доступ Page и надёжность публикации) → `1749d1d`
(3a, amendment D4.1) → `e3710f6` (3b, реализация D4.1) → документальный коммит
3c. Ни один runtime-файл после `e3710f6` не менялся; это проверено
`git diff --name-only e3710f6 HEAD` и повтором документальных gates (ниже).

## Среда и способ прогона

| Параметр | Значение |
|---|---|
| Checkout | чистый worktree `C:\Users\User\.claude\worktrees\recharge-m1-3c`, `git worktree add --detach` на runtime SHA; `git status --short` после установки зависимостей и после всех gates — 0 записей |
| Зависимости | `npm ci --ignore-scripts --offline` из локального кеша; `flutter pub get --offline`; provider mirror Terraform скопирован из worktree 7275 (только чтение); lockfile не менялись, загрузок не было |
| ОС | Windows 11 Home 10.0.26100 |
| Mobile | Flutter 3.44.9, Dart 3.12.2 |
| Backend | Node 22.23.2, npm 10.9.8, Temurin 21.0.12+8, Terraform 1.15.9, firebase-tools 15.28.1 |
| Стенд | `demo-recharge`, только 127.0.0.1 (Auth 9099, Firestore 8080, Functions 5001, Storage 9199, Pub/Sub 8085); `FUNCTIONS_DISCOVERY_TIMEOUT=60`; gates строго последовательно, каждый на свежем стенде со своим seed и verified stop |
| Клиент | каждый гейт сам запускает `flutter test --no-pub <файл>` из `apps/mobile`: headless `flutter_tester` на этом ПК против стенда через настоящие адаптеры (Session, Content, Media, Booking, Notifications); E2 и F2 — два независимых процесса `flutter test` (клиенты A и B) со своими пользователями, Session, installation id и журналами; без adb, устройств, LAN и cloud |
| Журналы | вне checkout: `C:\Users\User\AppData\Local\Temp\claude\C--Users-User-Desktop-Recharge\fb5bbe95-84a3-45b7-aa07-ad5cdfdf0985\scratchpad\logs\3c\` (`summary.txt` и журнал каждого шага); группы Emulator — каталоги `recharge-emulator-tests-*` во временной папке ОС |

## Результаты

Все шаги — на runtime SHA в чистом worktree, строго последовательно; каждый
шаг записан в `summary.txt` с кодом выхода и длительностью.

| Проверка | Результат |
|---|---|
| Установка: `npm ci --ignore-scripts --offline`, `flutter pub get --offline`, mirror Terraform | pass; `git status --short` — 0 записей |
| Backend `verify:cloud-context`, `verify:toolchain`, `format:check`, `lint`, `typecheck` | pass |
| `test:unit` / `test:contract` / `test:r1:integration` | 729/729 / 55/55 / 254/254 |
| `verify:*`: r1 layout/config/exports, reference-data layout/contracts, security-privacy layout/contracts, identity-publisher layout/contracts, content-persistence, execution-manifest, iac:topology, taxonomy, generated, reproducibility; `verify-notifications-layout.mjs` | pass (IaC: fmt, validate и mock-provider тесты трёх окружений) |
| `test:reference-data`, `test:security-privacy`, `test:identity-publisher`, `test:media-tools`, `test:emulator:runner`, `npm ls --all` | pass |
| `test:r1` | pass: все credential-free локальные gates R1 |
| `flutter analyze` | 0 issues |
| `flutter test` | 1616 passed, 67 skipped (стенд-тесты, см. ниже), 0 failed |
| Boundary | self-test pass; 614 файлов, 0 нарушений, 71/71 |
| Inventory `--check-output` | pass |
| `packages/api_contracts`: `flutter test` / `flutter analyze` | 25/25 / 0 issues |
| `test:stand` | 43/43 |
| `test:emulator` (9 групп последовательно) | 250/250: platform 10, booking 62, content-media 69, handoff-notifications 34, place-activity 29, rental 13, collection 13, import 8, rules-reference 12; каждая группа в своём лимите |
| `stand:acceptance` (A1/A2) | pass, нормализованное состояние `d263cfb7…abbb42`, verified stop |
| Гейт B1 (`stand-mobile-gate`) | pass, клиент 4/4 |
| Гейт B2 | pass 3/3 прогона, клиент 5/5 в каждом |
| Гейт C1 | pass, клиент 4/4 |
| Гейт C2 | pass (backend-only: модерация через test-only staff registry) |
| Гейт C3 | pass, controller 6/6 (S1–S4), UI 1/1 |
| Гейт E1 | pass (backend-only: локальный Catalog) |
| Гейт E2a | pass, клиент 1/1 |
| Гейт E2 | pass, два независимых клиента 1/1 и 1/1 |
| Гейт F1 | pass, клиент 1/1 |
| Гейт F2 | pass, два независимых клиента 1/1 и 1/1 |
| Гейт D1 | pass, Windows-local (Linux-gate D1 — вне M1) |
| Гейт D2 | pass, Windows-local Emulator |
| Гейт D3.1 | pass: controller 6/6, UI 1/1; свежий стенд — отзыв доступа Page 8/8 (S5, S6, UI); свежий стенд — две установки 1/1 (S7); инварианты |
| Гейт D3.2 | pass, controller 6/6, UI 1/1 |
| Гейт D3.3 | pass, controller 6/6, UI 1/1 |
| Гейт D3.4 | pass, controller 7/7, UI 1/1 |
| Гейт D3.8 | pass, клиент 1/1 |
| Гейт D3.9 (`stand-d3-8-gate.mjs --linked-place`) | pass, клиент 1/1 |
| Гейт D4 (D4 и D4.1) | pass, клиент 4/4 |
| Стенд после всех gates | `stopped` |
| Diff-check коммитов от `merge-base main HEAD` (`06dae49`) | ровно три нарушения §6: `:186`, `:186`, `:108` «new blank line at EOF»; SHA-256 трёх blob совпадают с §6 |
| Diff-check коммитов без трёх waiver-файлов | без нарушений |
| Diff-check рабочего дерева | без нарушений; `git status --short` после всех gates — 0 записей |

Информационно, не gate checklist §5: в `packages/design_system/test` лежит
только `.gitkeep`, поэтому `flutter test` там завершается «no test files»
(так же на `3738cce`); `flutter analyze` пакета — 0 issues.

## Требования M1 и где они проверены

| Требование | Где | Способ клиентского прогона |
|---|---|---|
| Пять доступных типов: Event, Place, Activity, Rental, Collection | гейты C3, D3.1, D3.2, D3.3, D3.4 (+ D3.8 Catalog, D3.9 linked Place) | controller- и UI-тесты `*_publication_stand_test.dart`, `*_publication_ui_stand_test.dart` против стенда |
| Два пользователя и два независимых клиента | гейты E2, F2; S7 (одна учётная запись, две установки, гейт D3.1); D4.1 (две установки, гейт D4) | E2, F2 — два процесса `flutter test`; S7 и D4.1 — два контроллера с разными журналами и Session-хранилищами в одном процессе |
| Повторные нажатия и сетевые отказы | B2 (двойное нажатие, потерянный ответ, offline), C1 (загрузка), S1–S3 для пяти типов (C3, D3.1–D3.4), D4 (потерянный create), D4.1 (потерянные rollback, reserve, complete) | `content_fault_client.dart` обрывает до отправки или теряет ответ; `_LosingPort` теряет ответ после коммита сервера |
| Lifecycle и restart, поддерживаемые локальной средой | B1 (Session переживает restart, отозванная восстанавливается через owner path, истёкшая заменяется), B2 (журнал брони после restart), S3 и S4 (новый контроллер над тем же журналом), D4/D4.1 (restart в `paused`, `rollbackPending`, после удаления оригинала) | новый контроллер или runtime над тем же журналом; завершение приложения ОС и background — B1-device, вне M1 |
| Отзыв Session и Page | B1 (revoked и expired Session); S5 (`setCapabilities`), S6 (`decidePage` suspended → verified), гейт D3.1 | клиент со старым состоянием получает типизированный отказ; терминальный `revokeMembership` — только backend evidence (checklist §3) |
| Конкурентное редактирование и Booking | S7 (`revision_conflict`, запись поверх только по «Save my version»); Emulator `booking` (contention) и `handoff-notifications` (action races); E2, F2; D4.1 гонки rollback/submit и rollback/reserve (Emulator `import`) | S7 и D4.1 — клиент на стенде; гонки транзакций — Emulator |
| Import | гейт D4 (D4 и D4.1) | `local_import_stand_test.dart`, 4 сценария |
| Восстановление стенда | `stand:acceptance` (A1/A2), `test:stand` | — |
| Откат binding | D4.1: rollback, поколения, fenced cleanup | integration, Emulator `import`, unit, widget, гейт D4 |
| Полные gates | все строки таблицы результатов | — |

## Skipped-тесты и гейты

Полный `flutter test` пропускает 67 тестов в 22 файлах `test/backend_local/`:
им нужен стенд. Сопоставление построено заново на runtime SHA JSON-отчётом
`flutter test --no-pub test/backend_local -r json`; каждый файл прошёл в своём
гейте.

| Файл | Skipped | Гейт |
|---|---:|---|
| `booking_session_lifecycle_stand_test.dart` | 4 | B1 |
| `event_booking_ui_stand_test.dart` | 5 | B2 |
| `media_upload_stand_test.dart` | 3 (ещё 1 тест проходит в обычном наборе) | C1 |
| `event_publication_stand_test.dart` | 6 | C3 |
| `event_publication_ui_stand_test.dart` | 1 | C3 |
| `discover_catalog_stand_test.dart` | 1 | E2a |
| `e2_client_test.dart` | 1 (два процесса A и B) | E2 |
| `notifications_inbox_client_test.dart` | 1 | F1 |
| `f2_client_test.dart` | 1 (два процесса) | F2 |
| `place_publication_stand_test.dart` | 6 | D3.1 |
| `place_publication_ui_stand_test.dart` | 1 | D3.1 |
| `page_access_revocation_stand_test.dart` | 8 | D3.1 (свежий стенд) |
| `publication_two_installs_stand_test.dart` | 1 | D3.1 (свежий стенд) |
| `activity_publication_stand_test.dart` | 6 | D3.2 |
| `activity_publication_ui_stand_test.dart` | 1 | D3.2 |
| `rental_publication_stand_test.dart` | 6 | D3.3 |
| `rental_publication_ui_stand_test.dart` | 1 | D3.3 |
| `collection_publication_stand_test.dart` | 7 | D3.4 |
| `collection_publication_ui_stand_test.dart` | 1 | D3.4 |
| `activity_catalog_stand_test.dart` | 1 | D3.8 |
| `activity_linked_place_stand_test.dart` | 1 | D3.9 (`--linked-place`) |
| `local_import_stand_test.dart` | 4 | D4 |

Итого 67. Рост с 44 на `3738cce`: заход 2 добавил 21 (S1–S4 в пяти типах,
S5/S6, S7), заход 3b — 2 (D4.1). Число пройденных в гейтах тестов совпадает со
skipped каждого файла (C1 прогоняет и тот, что проходит в обычном наборе).

## Дефекты M1 и follow-up

Найдены и исправлены bounded-слайсами внутри утверждённых заходов:

- заход 2, **D1** — повтор `publish` после потерянного ответа давал
  `idempotency_conflict`; **D2** — контроллеры Place, Activity, Rental,
  Collection перезаписывали чужую правку при `revision_conflict`
  ([evidence](M1_STAGE2_PAGE_RELIABILITY.md));
- заход 3b — тот же класс D2 в контроллере импорта
  ([evidence](../d4/D4_1_ROLLBACK.md)).

Открытых дефектов M1 нет; отдельных follow-up slices по итогам приёмки не
требуется. Остаются внешние gates, перечисленные в начале документа, и
слияние веток M1 (push и merge вне scope этого захода).

## Повтор документальных gates после документального коммита

Документальный коммит меняет только три документа из раздела «SHA». Перед ним
на рабочем дереве поверх `e3710f6` повторены: inventory `--check-output`,
boundary, diff-check коммитов (с waiver и без) и рабочего дерева;
`git diff --name-only e3710f6` показал только эти три файла.
