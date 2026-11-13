# Задание PVR-01 / заход 08: Финальные проверки и фактический статус

Готовый текст для передачи исполнителю. Дата подготовки: 2026-10-10. Подготовка этого файла не означает выполнения захода.

Ты выполняешь один заход задачи Recharge PVR-01. Пользователь передаёт тебе это задание отдельно от исходного чата. Выполни только указанный заход и подготовь передачу следующему агенту; самостоятельно следующий заход не начинай.

## Общий контекст

Пользователь решил: всё остаётся как было, но отдельную страницу Viewer убираем. Личный профиль называется Creator; Professional Pages остаются отдельными рабочими контекстами владельца/управляющего. Сохраняются посещения, Favorites/Saved, личные Scenario/Quick Plan, настройки, существующие Creator tools и page actions.

Название UI Creator не выдаёт системную роль, verification или capabilities. System roles User/Creator/Admin, personal/page WorkspaceRef, user/page PublisherRef, exact page membership и mutation guards сохраняются. Личные библиотеки не получают publishing-verification gate. Public identity не становится searchable только из-за имени личного экрана. Scenario viewer/unlistedViewer и PublicPageViewerContext не являются удаляемой страницей.

Изменение ограничено local UI/docs/archive/regression. Новые backend/cloud функции, реальная verification, Follow, Payments и реализация всех Draft profile specs сюда не входят. Общий profile_page.dart содержит и Creator, поэтому его нельзя целиком удалить/вынести из приложения.

## База и обязательное начало

1. Прочитай AGENTS.md целевой копии и применимые вложенные инструкции. Следуй Accepted ADR и состоянию конкретного slice.
2. Master plan: docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md. Исходный подготовленный пакет находится в C:/Users/User/.codex/worktrees/012d/Recharge/docs/product/. Если пакет ещё не перенесён на target, читай оригинал оттуда либо приложенный пользователем документ. Не воссоздавай отсутствующий полный план по памяти.
3. Копия 012d была на старом detached HEAD 06dae4920e8dbf9492267d534397689c345169b1. Поздние исходники найдены в C:/Users/User/.codex/worktrees/7275/Recharge, но её actual HEAD/WIP должен подтвердить заход 00. Default write scope инструмента не доказывает, что это правильная implementation база.
4. Начиная с захода 01 используй target root из передачи 00. Проверь текущий HEAD/status и доступность предыдущих изменений: новый commit или uncommitted WIP допустимы, если их происхождение понятно. Не копируй старые общие файлы поверх позднего кода.
5. В поздней копии switcher встроен в Settings через features/identity/presentation/widgets/workspace_section.dart и app/presentation/workspace_section_host.dart; старые workspace_switcher_page.dart/tests из 012d — другой baseline. Все относительные source paths ниже — от подтверждённого target root.
6. Если передача/входной артефакт отсутствует, сначала поищи его в master report и указанном target. Не выдумывай выполненный этап. Продолжай независимое чтение и сообщи конкретно, чего не хватает для зависимых edits.
7. Сохрани чужой WIP. Перед изменениями перечисли bounded файлы и действия; если этот объём уже явно принят пользователем, повторно разрешение на каждую обычную правку не запрашивай. Авторизация общей цели не даёт оснований молча пометить Proposed ADR Accepted.
8. Не коммить, не пушь, не merge/deploy без отдельной прямой авторизации. Не запускай других агентов или не сообщай в чужие чаты из этого задания: пользователь распределяет заходы сам.

## Входные передачи и условия старта

- docs/verification/pvr-01/00-baseline.md
- docs/verification/pvr-01/01-archive.md
- docs/verification/pvr-01/02-decision.md
- docs/verification/pvr-01/03-spec-migration.md
- docs/verification/pvr-01/04-presentation-access.md
- docs/verification/pvr-01/05-unified-ui.md
- docs/verification/pvr-01/06-regression.md
- docs/verification/pvr-01/07-retirement-restore.md

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Все передачи 00–07, baseline/source root и итоговый diff.
- Master plan §§12–18; все PVR-AC evidence, A/U matrix и archive manifest.
- Действующие инструкции проверок целевой копии.

## Разрешённый файловый объём этого захода

- docs/architecture/LAUNCH_STATUS.md; docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md.
- docs/verification/PVR_01_VERIFICATION.md; docs/verification/pvr-01/08-final-gates.md.
- AGENTS.md — фактический status/date при изменении; ARCHITECTURE_BASELINE.md только при актуальном Viewer presentation утверждении.
- Runtime/tests — только исправления доказанных регрессий с повтором соответствующих gates.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 08 — общие gates, итог и передача

**Файлы:** `docs/architecture/LAUNCH_STATUS.md`, verification report, этот план;
AGENTS status/date при фактическом изменении; остальные — только при
выявленной конкретной регрессии. `ARCHITECTURE_BASELINE.md` обновлять лишь
если он содержит действующую запись о Viewer presentation.

1. Проверить финальный diff против baseline, unrelated WIP не затронут.
   Новые dependencies, Firebase/cloud изменения и schema migration не добавлены.
2. Выполнить `flutter analyze` и полный `flutter test` из `apps/mobile`.
   Сохранить команды, версии, exit codes, counts и длительность.
3. Из корня выполнить boundary gate и `git diff --check`.
   Сравнить boundary baseline; новые violations или новые suppressions
   не использовать как способ скрыть cross-feature import.
4. Проверить новые/untracked Markdown и архив отдельно: обычный `git diff`
   не проверяет содержимое untracked файлов. Проверить trailing whitespace,
   fences, local links, ID declarations и manifest completeness.
5. Сверить матрицу критериев раздела 15 с отчётом. Failed/timeout/hang/not-run
   не равны pass. Не ставить Done с красным обязательным gate.
6. Обновить LAUNCH_STATUS только фактом единого personal UI и архива;
   не записывать полноту больших Creator/Profile Draft specs или production
   readiness. Данные тестов local/mock, device gate ими не заменяется.
7. Передать короткий итог: что изменилось, файлы, путь архива, как вернуть
   выбранные части, результаты проверок, реальные оставшиеся ограничения.
8. Согласование commit/push при необходимости — отдельное действие после
   готового reviewable diff. Автоматический reset/clean чужого WIP не нужен.

**Приёмка:** все критерии PVR-AC выполнены, gates зелёные, отчёт точен.
**Откат:** при необходимости вернуть runtime и согласованные docs по их
дельтам в обратном порядке; архив и пользовательское storage сохраняются.
Последующие независимые изменения не перезаписываются.

## Уточнение границ задания

Проверь итог по исходному запросу пользователя: одна личная страница Creator, Professional Pages и прежние функции/права, архив для возвращения. Не заявляй готовность больших Draft specs или production/device. Если checks красные — конкретный остаток и статус Review/Doing, а не Done. Сохранить unrelated WIP. Commit/push/merge не выполнять без отдельной прямой авторизации.

## Проверки исполнителя

Из apps/mobile: flutter analyze и полный flutter test. Из корня: boundary gate и git diff --check. Новые/untracked docs/archive проверить отдельно. Ни timeout, ни not-run, ни baseline failure не равны pass. Перед Done все применимые PVR-AC должны быть подтверждены.


## Команды и трактовка результата

### 14.1 Focused проверки

Рабочая директория: `<целевой-root>/apps/mobile`.

```powershell
flutter test test/unit/profile_role_summary_test.dart test/unit/identity_workspace_usecase_test.dart test/unit/identity_workspace_repository_test.dart
flutter test test/widget/profile_page_test.dart test/widget/workspace_section_test.dart test/widget/professional_app_shell_test.dart
flutter test test/widget/app_shell_test.dart test/widget/settings_page_test.dart test/widget/visited_places_page_test.dart
```

Это группы для `7275`, где найден `workspace_section_test.dart`.
На другой согласованной базе сначала обновить пути. Не создавать старый
test-файл только чтобы команда совпала. Дополнительную auth/visit/notification
регрессию запускать по матрице; полный финальный suite покрывает весь набор.
После небольшого исправления повторять упавшую/затронутую группу, затем
общие финальные gates. Уже зелёные неизменённые группы не гонять бесконечно.

### 14.2 Финальные gates

Из `<целевой-root>/apps/mobile`:

```powershell
flutter analyze
flutter test
```

Из `<целевой-root>`:

```powershell
dart tools/scripts/check_boundaries.dart --repo-root . --format text
git diff --check
git status --short
```

При необходимости Windows wrapper boundary:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\scripts\check-boundaries.ps1
```

Archive validation: PowerShell `Get-FileHash -Algorithm SHA256` по точным
source/archive paths из manifest, проверка size и полноты. Этого slice
не требует новый пакет, CI subsystem или постоянный backup service.

## Критерии, к которым относится заход

| Критерий | Требование | Evidence |
|---|---|---|
| PVR-AC-01 | Зафиксированы target root/HEAD/WIP и related file map | Заход 00, baseline |
| PVR-AC-02 | Viewer snapshots сняты до runtime edits, hashes совпадают | Заход 01, manifest |
| PVR-AC-03 | Архив содержит source, tests, specs, контекст и restore instructions | Заход 01, inventory |
| PVR-AC-04 | Узкий ADR оформляет только UI/preview замену, роли и gates сохранены | Заход 02, ADR diff |
| PVR-AC-05 | Общие personal rules имеют действующего владельца | Заход 03, retirement map |
| PVR-AC-06 | Все VP-D/VP-AC перенесены/aliased/retired с причиной и статусом | Заход 03, ID audit |
| PVR-AC-07 | Обычный User открывает единый Creator Profile без verification gate на сам экран | A02, U01/U02 |
| PVR-AC-08 | Presentation/preview не создают новые role/capability grants | A02–A08, unit/usecase tests |
| PVR-AC-09 | Creator сохраняет существующие разрешённые tools/listing actions | A05, U07–U09 |
| PVR-AC-10 | Saved и Visit History доступны и используют прежние данные | U03–U05 |
| PVR-AC-11 | Личная Scenario library не gated publishing verification | U06/U07 |
| PVR-AC-12 | Settings/edit/save/logout работают | U10, A12 |
| PVR-AC-13 | Нет отдельной Viewer-композиции или fallback selector | U01/U02, symbol scan |
| PVR-AC-14 | Settings/Admin preview не предлагают Viewer | T02, A07/A08, U15 |
| PVR-AC-15 | Personal и page navigation/Account переходы сохранены | T03, U11 |
| PVR-AC-16 | Page ID/membership/owner/grants не подменяются новым UI | A09–A11 |
| PVR-AC-17 | Workspace payload читается без очистки/переприсвоения данных | U12, repository tests |
| PVR-AC-18 | Publisher существующего draft не меняется от preview/switch | U14 |
| PVR-AC-19 | Logout/login не переносит данные/preview между userIds | A12 |
| PVR-AC-20 | Unknown/error access не считается разрешением; auth redirect сохранён | A01/A06 |
| PVR-AC-21 | UI выдерживает 360 dp и 150% текста | U16, local widget/visual evidence |
| PVR-AC-22 | Privacy/public projection не расширена из-за смены владельца spec | Заход 03, public mapping audit |
| PVR-AC-23 | Archive исключён из runtime; выборочное восстановление проверено | Заход 07, scan/restore drill |
| PVR-AC-24 | Analyze, полный test suite, boundary, diff checks зелёные; LAUNCH_STATUS точен | Заход 08, report |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/08-final-gates.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 08; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
