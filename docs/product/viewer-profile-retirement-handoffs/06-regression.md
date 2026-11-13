# Задание PVR-01 / заход 06: Регрессия доступа, функций и данных

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

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Передачи 00–05, action-map baseline, cutover diff.
- Master plan §10: A01–A12 и U01–U16; §15: PVR-AC.
- Текущие storage readers, Create/Publisher guards и личные libraries для подтверждения ожидаемого поведения.

## Разрешённый файловый объём этого захода

- Tests T01–T05 и дополнительная существующая регрессия из карты ниже.
- F01–F07 и условные consumers — только исправление конкретных обнаруженных регрессий.
- docs/verification/pvr-01/06-regression.md; docs/verification/PVR_01_VERIFICATION.md.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 06 — проверить действия, данные и переходы

**Цель:** доказать сохранение функций, а не только исчезновение слова Viewer.
**Файлы:** tests из раздела 13, implementation файлы только для исправления
обнаруженных регрессий, verification report. Existing tests не удалять
целиком из-за смены expected heading: сохранять проверки действий и маршрутов.

### 10.1 Матрица аккаунтов

Использовать контролируемые local/mock fixtures, а не личные данные пользователя.
Каждая строка проверяется с фактическими access inputs; title Creator не
используется как доказательство полномочий. Если будущий AccountStatus ещё
не поддержан runtime, его документационный перенос проверяется отдельно,
без добавления полного account-state engine ради этого slice.

| ID | Исходное состояние | Что проверять |
|---|---|---|
| A01 | Нет сессии | Auth-gate и возврат к допустимому исходному маршруту |
| A02 | Активный User, verification notStarted | Один Creator screen; личные функции; прежний отказ protected mutations |
| A03 | Verification pending/rejected/expired/revoked | Тот же тип профиля; статус не выдаёт publishing rights |
| A04 | Verified без нужной capability | Отказ конкретной операции, личные функции остаются |
| A05 | Verified с нужными grants | Прежние Creator actions доступны и выполняют правильные handoffs |
| A06 | Snapshot отсутствует/загружается/error | Нет ложного verified badge/permission, нет Viewer fallback |
| A07 | Admin personal и Creator preview | Presentation не меняет grants/PublisherRef |
| A08 | Admin page preview, страниц нет | Прежний пустой preview, без fake page/membership |
| A09 | Owner страницы A | Правильный page workspace, owner tools в прежнем объёме |
| A10 | Invited manager с ограниченными grants | Не получает owner-права или доступ к странице B |
| A11 | Membership/page доступ отозван | Прежнее восстановление/отказ, без обхода через личный Creator title |
| A12 | Logout A → login B | Нет личных данных, preview или workspace аккаунта A у B |

Для A03 сохранить operation-specific поведение: не считать, что любой
restricted status всегда запрещает вообще все действия. Новые ограничения
не изобретаются; сравнение идёт с контрактом соответствующей операции.

### 10.2 Матрица пользовательских действий

| ID | Действие | Ожидаемый результат и доказательство |
|---|---|---|
| U01 | Открыть Profile из personal nav | Единственный Creator layout, без Viewer option |
| U02 | Открыть `/profile/workspace` прямо | Тот же personal context, нет скрытого legacy selector |
| U03 | Saved/Favorites | Прежний route и прежние записи; пустое состояние честное |
| U04 | Visited → конкретное место | История доступна; canonical Details link сохранён |
| U05 | Добавить/удалить self-reported visit | Прежние repository/usecase условия, не новый storage |
| U06 | Открыть личный Scenario | User-owned library, без publishing verification gate |
| U07 | Create Scenario/доступный draft | Общий form engine и текущий route, без возврата старого builder |
| U08 | Created/listing/search/map | Собственный scope, прежние параметры handoff и readiness |
| U09 | Draft/route continuation и legacy tools | Сохранены доступные действия; legacy names не образуют новый профиль |
| U10 | Редактировать профиль и Settings | Сохранение, повторное открытие, logout, прежние keys |
| U11 | Personal → page A → personal | Прежние nav/IDs, один личный профиль, preview сброшен по прежнему правилу |
| U12 | Перезапуск с сохранённым personal/page | Читается прежняя schemaVersion; нет data reset |
| U13 | Ноль/одна/три страницы и запрос четвёртой | Прежние quota, pending request и notifications |
| U14 | Смена workspace при существующем draft | Publisher существующего draft не переписан |
| U15 | Не-Admin открывает Settings | Admin preview недоступен |
| U16 | 360 dp, text scale 150%, длинные имя/название страницы | Нет overflow/обрезанных действий, scroll и tap доступны |

Отдельно проверить error/empty/loading Profile, Visit History, Created и
Settings; back navigation не приводит на удалённую presentation-ветку.
Скриншоты нужны только для визуальной проверки изменённых состояний;
нет необходимости снимать весь продукт или создавать новые golden baselines
без существующего для этих экранов процесса.

### 10.3 Проверка сохранности данных

На тестовом storage подготовить два аккаунта, personal preference, две
страницы с разными memberships, посещение, Saved, личный Scenario и draft
с фиксированным publisher. После переключений проверить те же IDs и значения.
Документировать чтение старого workspace payload. Никаких новых writes
role/verification/membership из открытия профиля или preview.

**Приёмка:** все затронутые сценарии имеют тест/ручное local evidence или
явное обоснование «docs-only future contract»; нет необъяснённых N/A.
**Откат:** исправить конкретную регрессию и повторить затронутые проверки;
при отказе от cutover вернуть согласованный набор захода 05. Не стирать данные
и не «чинить» тест выдачей фиктивной capability всем аккаунтам.

## Уточнение границ задания

Не считать выполненной матрицу, где проверены только заголовки/enum. Нужны route/action/data assertions: userId isolation, exact page access, старый workspace payload, Publisher non-rewrite, Scenario без publishing verification. Будущие AccountStatus из Draft не реализовывать ради теста: перенесённый contract отмечается docs-only, с конкретным обоснованием. Уже существующие регрессии не скрывать выдачей фиктивных grants или удалением теста.

## Развёрнутая карта упоминаемых файлов

Это справочник полного slice. Право редактирования в текущем заходе ограничено
списком «Разрешённый файловый объём» выше; остальные строки нужны для чтения
и понимания зависимостей, а не для попутной реализации следующих заходов.

### Семь основных runtime файлов

| ID | Файл | Изменение | Заход |
|---|---|---|---|
| F01 | `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart` | Единый layout, сохранённые actions, удалить Viewer body/selector | 04–05, cleanup 07 |
| F02 | `apps/mobile/lib/features/explore/application/profile_role_summary.dart` | Развести display и actual access, не выдавать Creator rights из title | 04–05 |
| F03 | `apps/mobile/lib/core/identity/account_experience.dart` | personal/page experience | 05 |
| F04 | `apps/mobile/lib/features/identity/application/state/identity_workspace_state.dart` | effectiveExperience и preview mapper | 05 |
| F05 | `apps/mobile/lib/app/presentation/recharge_app_shell.dart` | personal fallback, сохранить nav | 05 |
| F06 | `apps/mobile/lib/features/identity/domain/entities/admin_experience_preview.dart` | Удалить viewer presentation value | 05 |
| F07 | `apps/mobile/lib/features/identity/presentation/widgets/workspace_section.dart` | Один personal tile, labels и preview | 05 |

F06 находится в domain, но содержит enum presentation preview; удаление
значения не меняет role/capability model. Другой domain rewrite не планируется.

### Условные consumers: сначала read-only, правка с конкретной причиной

| Файл | Допустимая причина правки |
|---|---|
| `apps/mobile/lib/app/presentation/workspace_section_host.dart` | Fallback label/composition, если остаётся старый UI смысл |
| `apps/mobile/lib/app/router/app_router.dart` | Нужный presentation input/устаревший entrypoint; routes не переделывать целиком |
| `apps/mobile/lib/app/router/route_names.dart` | Только реально найденный Viewer route/legacy alias; в прочитанной базе отдельного URL нет |
| `apps/mobile/lib/features/explore/presentation/pages/settings_page.dart` | Viewer label/link, если есть; сохранить inline WorkspaceSection host |
| `apps/mobile/lib/features/identity/application/controllers/identity_workspace_controller.dart` | Viewer-specific preview mapping/reset, если после enum правки он нужен |
| `docs/architecture/ARCHITECTURE_BASELINE.md` | Действующая запись об отдельном Viewer presentation |

Перечисленные ниже файлы — проверяемые границы, не план массовых изменений:
`identity_access_snapshot.dart`, `workspace_ref.dart`, identity local datasource,
`active_create_publisher_provider.dart`, Create controllers/usecases,
`scenario_library_panel.dart`, Visit History/Favorites repositories.
Если там обнаружена отдельная существующая ошибка, сначала определить, мешает
ли она PVR-01. Не превращать удаление страницы в переписывание backend/access.

### Тесты

| ID | Файл | Основные сценарии |
|---|---|---|
| T01 | `apps/mobile/test/widget/profile_page_test.dart` | Единый профиль, личные функции, Created, handoffs, fallback, small screen |
| T02 | `apps/mobile/test/widget/workspace_section_test.dart` | Нет Viewer выбора, один personal row, page ownership/preview |
| T03 | `apps/mobile/test/widget/professional_app_shell_test.dart` | Page preview/nav и возврат personal |
| T04 | `apps/mobile/test/unit/profile_role_summary_test.dart` | Display не повышает actual access |
| T05 | `apps/mobile/test/unit/identity_workspace_usecase_test.dart` | Preview, scopes, snapshot и восстановление |

Существующая дополнительная регрессия:

- `apps/mobile/test/widget/app_shell_test.dart`;
- `apps/mobile/test/widget/settings_page_test.dart`;
- `apps/mobile/test/widget/visited_places_page_test.dart`;
- `apps/mobile/test/unit/identity_workspace_repository_test.dart`;
- `apps/mobile/test/unit/identity_notification_sink_test.dart`;
- `apps/mobile/test/unit/visit_history_repository_test.dart`;
- `apps/mobile/test/unit/visited_places_controller_test.dart`;
- `apps/mobile/test/unit/auth_controller_test.dart`;
- `apps/mobile/test/unit/auth_repository_impl_test.dart`.

Точные тесты существующих Create/Scenario guards выбрать из текущей базы
по action-map, не выдумывать отсутствующие test paths. При отсутствии покрытия
общей Scenario library/Publisher non-rewrite добавить поведенческий case в
ближайший существующий профильный/identity тест и указать его в отчёте.
Новые тесты нужны для риска регрессии, не для механического повторения enum.

## Проверки исполнителя

Выполни всю применимую A/U матрицу из задания. Добавляй тесты риска, не зеркала реализации. После исправления повтори затронутые проверки, выполни обязательные gates target AGENTS. Device/cloud не заявлять по local/mock evidence.


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

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/06-regression.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 06; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
