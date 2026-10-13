# Release M1 — checklist первого локального контура

Статус: **утверждён владельцем 2026-10-13** — состав §1 (включая строки
«восстановлено после реализации»), исключение §3 и waiver §6 приняты указанием
владельца закрыть все заходы M1 без остановки на формальные подтверждения.
Заход 2 закрыл S1–S7, заход 3 — импорт, откат и итоговую приёмку (§8).
**Итог: «первый локальный контур проверен»** на runtime SHA
`e3710f65ba595e14d4ebd578bcb208670eb81a1d`
([M1_ACCEPTANCE.md](../evidence/backend/m1/M1_ACCEPTANCE.md)).
База: `3738cce02f7c580b416182da674e7a5f5dd8bd50` (`codex/recharge-integration`).
Норматив: Latvia roadmap §3.7 «Release M1 и Release M2».

Единственное допустимое название успеха — «первый локальный контур проверен».
Это не Release R1, не production-, staging- или cloud-ready. Любой обязательный
пункт в состоянии red или inconclusive оставляет M1 открытым.

Утверждение владельца нужно для трёх решений этого документа:

1. состав M1 из §1, включая строки с классом «восстановлено после реализации»;
2. исключение терминального `revokeMembership` из клиентского M1 (§3);
3. waiver трёх закреплённых документов (§6).

## 1. Состав M1 и источники

«Карта до кода» — документ сам фиксирует, что план и карта файлов приняты до
реализации. Git этого порядка не доказывает: все amendment закоммичены вместе
с кодом или позже. «Восстановлено после реализации» — состав взят из README,
closure review, evidence или скриптов гейтов, написанных вместе с кодом или
после него; такие строки владелец принимает явно.

| Slice | Источник состава | Класс | Git | Гейт |
|---|---|---|---|---|
| B1-local | `apps/backend/README.md` §B1/B2, `C1_E2_CLOSURE_REVIEW.md` | восстановлено после реализации | README в коммите кода `fc3ab4f`, review в `2529a54` | `stand-mobile-gate.mjs` |
| B2-local | то же | восстановлено после реализации | то же | `stand-b2-gate.mjs` |
| C1 | README §C1, closure review; основа Media — карта BCK14-LOCAL-01 | подключение стенда — восстановлено после реализации; основа — карта до кода | карта `7c34eb1` до кода `9d61c90` | `stand-c1-gate.mjs` |
| C2 | README §C2, closure review | восстановлено после реализации | `fc3ab4f`, `2529a54` | `stand-c2-gate.mjs` |
| C3 | README §C3, closure review; основа persistence — карта BCK07-PERSIST-01 | подключение — восстановлено после реализации; persistence — карта до кода | карта `aca58cd` до кода `e9427a7` | `stand-c3-gate.mjs` |
| E1 | README §E1, closure review | восстановлено после реализации | `fc3ab4f`, `2529a54` | `stand-e1-gate.mjs` |
| E2a, E2.0, E2b | `EVENT_INTERNAL_REGISTRATION_E2_0_AMENDMENT.md` §10 «Закрытая карта файлов» | карта до кода (Accepted 2026-10-06) | документ добавлен после кода, `2529a54` | `stand-e2a-gate.mjs`, `stand-e2-gate.mjs` |
| F1 | `NOTIFICATIONS_F1_INBOX_AMENDMENT.md` §16 | карта до кода (Accepted 2026-10-08) | вместе с кодом, `64139b9` | `stand-f1-gate.mjs` |
| F2 | `BOOKING_ACTIONS_F2_AMENDMENT.md` §9 | карта до кода (Accepted 2026-10-08) | вместе с кодом, `29ed76e` | `stand-f2-gate.mjs` |
| D1 | `MEDIA_D1_REAL_TOOLS_AMENDMENT.md` §11; D1-L — §15 «план до кода» | карта до кода (план принят 2026-10-09) | вместе с кодом, `a1419e8`; D1-L `94e2b5e` | `stand-d1-gate.mjs` |
| D2 | `MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §12 «Карта файлов (фактическая)» | план принят 2026-10-09; карта в документе — восстановлена после реализации | вместе с кодом, `8a6c2de` | `stand-d2-gate.mjs` |
| D3.1 | `PLACE_D3_1_PUBLICATION_AMENDMENT.md` §10 | смешанно: 52 файла из карты, принятой на ревью; 6 добавлены при реализации | вместе с кодом, `fd56758` | `stand-d3-1-gate.mjs` |
| D3.2 | `ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md` (своей карты файлов нет) | восстановлено после реализации | вместе с кодом, `b1e678a` | `stand-d3-2-gate.mjs` |
| D3.7, D3.8, D3.9, D10, D11 | разделы-дополнения D3.2 amendment, `docs/evidence/backend/d3/*` | восстановлено после реализации | `49c1b05`…`f05c97f` | D3.7, D10, D11 — `stand-d3-2-gate.mjs`; D3.8 — `stand-d3-8-gate.mjs --yes`; D3.9 — `stand-d3-8-gate.mjs --yes --linked-place` |
| D3.3 | `RENTAL_D3_3_PUBLICATION_AMENDMENT.md` §11 «Точный план файлов (после решений)» | карта до кода | вместе с кодом, `cd937b4` | `stand-d3-3-gate.mjs` |
| D3.4 | `COLLECTION_D3_4_PUBLICATION_AMENDMENT.md` §11 | решения владельца до кода (§1); карта — восстановлена после реализации | вместе с кодом, `e50f9a6` | `stand-d3-4-gate.mjs` |
| D4 | `LOCAL_IMPORT_D4_AMENDMENT.md` §11 | решения владельца до кода (§1); карта — восстановлена после реализации | вместе с кодом, `3d77018`, `4724552` | `stand-d4-gate.mjs` |
| Стенд A1/A2 | README §A1/A2 | восстановлено после реализации | — | `stand:acceptance`, `test:stand` |

Пять доступных Create-типов M1: Event, Place, Activity, Rental, Collection.
Route, Scenario, Session, Class/Workshop и Find People в M1 не входят.

## 2. Обязательные сценарии захода 2

Каждый сценарий проверяется клиентом через настоящие адаптеры на стенде.

| № | Сценарий | Типы |
|---|---|---|
| S1 | Обрыв до отправки на `submit` и на `publish`: до сервера ничего не дошло, честный offline, поздний повтор успешен | все пять |
| S2 | Потерянный ответ на `submit` и на `publish`: сервер обработал запрос, клиент показывает неизвестный исход, повтор с тем же ключом даёт одну submission и одну публикацию | все пять |
| S3 | Восстановление после неизвестного исхода и restart: новый контроллер над тем же журналом восстанавливается без дублей | все пять |
| S4 | Повторный save после restart переиспользует тот же серверный черновик | Event, Collection |
| S5 | Обратимый отказ Page через capabilities: `setCapabilities` снимает с владельца `content.create`, `content.submit`, `content.publish` (остаётся `manage_page`); клиент со старым состоянием получает типизированный отказ, локальный черновик и журнал не меняются, на сервере нет новой ревизии, submission и публикации; после возврата прав тот же контроллер публикует ровно один раз | Event, Place |
| S6 | Обратимый отказ Page через suspended state: `decidePage` `verified → suspended` даёт отказ, `suspended → verified` — успех | Place |
| S7 | Один пользователь, две установки, один черновик: вторая установка получила привязку восстановлением данных приложения; её save поверх старой ревизии получает `revision_conflict`, правка первой установки не потеряна, локальный черновик второй цел, после обновления сохранение проходит | Place |

## 3. Исключено из клиентского M1

**Терминальный `revokeMembership`.** Допустимой фикстуры нет: отзыв требует
второго активного участника Page, а owner-пути добавить участника нет —
членство создаётся только вместе со страницей. Новый owner-path не
добавляется. Evidence остаётся backend-only:
`apps/backend/functions/test/integration/identity_publisher_authority.test.ts`,
тест «membership and account revocation invalidate cached authority»
(`test:r1:integration`, 245/245 на `3738cce`).

**Вне M1 (внешние gates):** Linux-gate D1 (EICAR, официальные базы ClamAV,
cgroup), `infra:r1:validate` и `infra:r1:plan`, Linux-паритет GitHub Actions,
физические Android/iOS (B1-device), cloud, staging, production.

Двухклиентские сценарии E2 и F2 проверены на уровне адаптеров. Для M1 этого
достаточно: UI каждого пути проверен одноклиентскими UI-тестами (B2, C3,
D3.1–D3.4, D3.8).

## 4. Среда

| Параметр | Значение |
|---|---|
| ОС | Windows 11 Home 10.0.26100 |
| Mobile | Flutter 3.44.9, Dart 3.12.2 |
| Backend | Node 22.23.2, npm 10.9.8, Temurin 21.0.12+8, Terraform 1.15.9, firebase-tools 15.28.1 |
| Зависимости | `npm ci --ignore-scripts --offline` и `flutter pub get --offline` из локальных кешей; lockfile не меняются |
| IaC topology | локальный provider mirror `apps/backend/infra/terraform/.terraform` |
| Стенд | `demo-recharge`, только 127.0.0.1; `FUNCTIONS_DISCOVERY_TIMEOUT=60`; гейты строго последовательно |
| Клиент | `flutter test --no-pub <файл>` из `apps/mobile`, запускает сам гейт; headless `flutter_tester` на ПК, без adb, устройств, LAN и cloud |

Session выдаётся не чаще 5 раз на аккаунт за 15 минут: новые стенд-тесты
переиспользуют сохранённые Session.

## 5. Команды gates

Mobile, из `apps/mobile`:

```text
flutter analyze --no-pub
flutter test --no-pub
```

Из корня репозитория:

```text
dart tools/scripts/check_boundaries.dart --self-test
dart tools/scripts/check_boundaries.dart --repo-root . --format text
dart tools/scripts/check_boundaries.dart --repo-root . --format markdown --output docs/architecture/MOBILE_BOUNDARY_INVENTORY.md --check-output
```

Inventory считает только `apps/mobile/lib/features`; новые тесты его не
меняют. Любое изменение Dart-файлов в этом корне требует перегенерации.

`packages/api_contracts`: `flutter test --no-pub`, `flutter analyze --no-pub`.

Backend, из `apps/backend/functions`: `verify:cloud-context`,
`verify:toolchain`, `format:check`, `lint`, `typecheck`, `test:unit`,
`test:contract`, `test:r1:integration`, `test:r1`, все `verify:*`
(r1 layout/config/exports, reference-data, security-privacy,
identity-publisher, content-persistence, execution-manifest, iac:topology,
taxonomy, generated, reproducibility), `node ../scripts/verify-notifications-layout.mjs`,
`test:reference-data`, `test:security-privacy`, `test:identity-publisher`,
`test:media-tools`, `test:emulator:runner`, `test:stand`, `test:emulator`,
`node ../scripts/stand-acceptance.mjs --yes`.

Стенд-гейты, из `apps/backend/functions`, по одному:
`node ../scripts/stand-<гейт>-gate.mjs --yes` для `mobile`, `b2`, `c1`, `c2`,
`c3`, `e1`, `e2a`, `e2`, `f1`, `f2`, `d1`, `d2`, `d3-1`, `d3-2`, `d3-3`,
`d3-4`, `d3-8`, `d4`, и отдельно
`node ../scripts/stand-d3-8-gate.mjs --yes --linked-place` (D3.9).

Diff-check (PowerShell):

```powershell
$baseCommit = git merge-base main HEAD
git diff --check $baseCommit HEAD
git diff --check $baseCommit HEAD -- . `
  ':(exclude)docs/product/REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_EXECUTION_REVIEW.md' `
  ':(exclude)docs/product/REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_FOLLOWUP_AUTHORIZATION.md' `
  ':(exclude)docs/product/viewer-profile-retirement-handoffs/02-decision.md'
git diff --check
```

1. Полный diff-check коммитов допускает **только** три нарушения из §6.
2. Diff-check коммитов без трёх waiver-файлов — без нарушений.
3. Diff-check рабочего дерева — без нарушений.

CRLF: сравнение коммитов идёт по blob-ам, нормализованным `core.autocrlf=true`,
и не зависит от настроек машины. Рабочее дерево проверяется с настройками
репозитория по умолчанию; принудительный `core.autocrlf=false` не является
этим gate.

## 6. Waiver закреплённых документов

Три файла сохраняются байт в байт: их SHA-256 записаны в других документах, и
правка EOF сломала бы цепочку доказательств. Хеш считается по содержимому blob
в Git (LF). Waiver покрывает **только** перечисленное нарушение в этом
содержимом. Любое изменение файла, другое нарушение или нарушение на другой
строке waiver не покрывает: gate красный.

| Файл | SHA-256 blob | Нарушение | Где закреплён хеш |
|---|---|---|---|
| `docs/product/REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_EXECUTION_REVIEW.md` | `ec9acd16b3b1695d20fc891d49f4a2cb7287e6c15f285010e08d18422e5b15fd` | `:186: new blank line at EOF.` | `..._EXT_G1_EXECUTION_DECISION.md` строки 10 и 35; `..._EXT_G1_FOLLOWUP_AUTHORIZATION.md` строка 33 (`parentExecutionReviewHash`) |
| `docs/product/REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_FOLLOWUP_AUTHORIZATION.md` | `46e25cb53bf8b6a5c34c460ed698ee164c8e8e605ed74c4a6c63dd29f87b55ec` | `:186: new blank line at EOF.` | `..._EXT_G1_FOLLOWUP_OWNER_REVIEW.md` строки 8 и 101 |
| `docs/product/viewer-profile-retirement-handoffs/02-decision.md` | `5d4b291f99e19d7e8463069ab341e0cf6f6aabc9098e397c093cb0a1ccbcd653` | `:108: new blank line at EOF.` | `docs/verification/pvr-01/00-baseline.md` строка 396 |

Не затрагиваются и waiver не требуют: `docs/archive/**` (атрибут
`-text -diff`, хеши в `MANIFEST.md`), Accepted ADR 0016 (тот же EOF был уже в
`main`), `docs/product/archive/S1_CORE_SPEC.md` и `S1_DISC_SPEC.md`
(переименованы без изменения содержимого).

## 7. Skipped-тесты и гейты

Полный `flutter test` пропускает 67 тестов в 22 файлах `test/backend_local/`:
им нужен стенд. Каждый файл прогоняет свой гейт. Сопоставление построено
JSON-отчётом `flutter test --no-pub test/backend_local -r json` на итоговом
runtime SHA `e3710f6`; таблица — в
[M1_ACCEPTANCE.md](../evidence/backend/m1/M1_ACCEPTANCE.md#skipped-тесты-и-гейты).
На `3738cce` их было 44 в 20 файлах; заход 2 добавил 21, заход 3b — 2.

## 8. Клиентское покрытие

Прогон всех gates на `3738cce` 2026-10-13 был зелёным, кроме inventory и
diff-check, которые закрыл заход 1.

| Пункт | Статус | Где проверено |
|---|---|---|
| S1–S3: сбои `submit`/`publish` и восстановление, пять типов | закрыт, заход 2 | гейты C3, D3.1–D3.4 |
| S4: повторный save после restart, Event и Collection | закрыт, заход 2 | гейты C3, D3.4 |
| S5, S6: обратимый отказ Page через клиента | закрыт, заход 2 | гейт D3.1, отдельный свежий стенд |
| S7: две установки на одном черновике | закрыт, заход 2 | гейт D3.1, отдельный свежий стенд |
| Откат серверного результата импорта (roadmap §3.7 п. 3) | закрыт, заход 3b (D4.1) | гейт D4, Emulator-группа `import`, integration; [evidence](../evidence/backend/d4/D4_1_ROLLBACK.md) |
| Гонка cleanup оригинала и rollback, на одной и на двух установках | закрыт, заход 3b | гейт D4 (две установки), Emulator-группа `import` (настоящие транзакции), unit контроллера |
| UI импорта и отката | закрыт, заход 3b | widget `test/widget/local_import_section_test.dart` |
| Итоговая приёмка всех gates на одном финальном SHA | закрыт, заход 3c | чистый worktree `e3710f6`, все gates §5; [M1_ACCEPTANCE.md](../evidence/backend/m1/M1_ACCEPTANCE.md) |

Заход 2 нашёл и исправил два runtime-дефекта клиента:

- **D1.** Повтор `publish` после потерянного ответа отправлял новый
  `expectedPointerRevision` под прежним ключом и получал
  `idempotency_conflict`, хотя публикация на сервере была одна. Теперь намерение
  publish журналируется до вызова и повторяется без изменений (пять типов).
- **D2.** При `revision_conflict` контроллеры Place, Activity, Rental и
  Collection сами перечитывали ревизию и перезаписывали чужую правку. Теперь
  незавершённая запись журналируется с payload; повторяется только она,
  чужая ревизия даёт конфликт, а запись поверх неё — только по явному «Save my
  version» в UI. Тот же приём в `local_import_controller.dart` исправлен в
  заходе 3b (D4.1 §3.3): элемент получает `revision_conflict`, правка на
  сервере сохраняется.

Новые стенд-тесты увеличили число skipped в полном `flutter test` до 67;
сопоставление построено в итоговой приёмке (§7).
