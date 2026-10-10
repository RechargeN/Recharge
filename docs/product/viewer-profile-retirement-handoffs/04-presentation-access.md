# Задание PVR-01 / заход 04: Разделение представления и полномочий

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

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Передачи 00–03; принятие ADR и фактический access baseline.
- ProfileRoleSummary, все consumers его tier/canCreate/canGenerate.
- IdentityAccessSnapshot, существующие Create guards и app composition — read-only, не создавать параллельную авторизацию.

## Разрешённый файловый объём этого захода

- apps/mobile/lib/features/explore/application/profile_role_summary.dart — основной application файл.
- apps/mobile/test/unit/profile_role_summary_test.dart — основной тест.
- apps/mobile/lib/features/explore/presentation/pages/profile_page.dart — только необходимая подготовка потребителя, без полного cutover.
- docs/verification/pvr-01/04-presentation-access.md; docs/verification/PVR_01_VERIFICATION.md.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 04 — отделить единый внешний вид от реальных разрешений

**Основные файлы:** F02 `profile_role_summary.dart`, T04 его unit tests.
F01 `profile_page.dart` затрагивается только для безопасной подготовки
потребления проекции; переключение экранов завершится в заходе 05.

**Действия:**

1. Для каждого использования `roleSummary` определить назначение: title/badge,
   выбор layout, показ инструмента, разрешение операции, legacy presentation.
   Зафиксировать результат в action-map verification report.
2. Сделать личный layout независимым от `ProfileRoleTier.user/creator`.
   Заголовок Creator и personal layout не должны выбирать готовую
   `profileRoleSummaryForTier(creator)` ради её `canCreate: true`.
3. Реальную role/capability projection строить из текущих данных аккаунта.
   Admin preview влияет на визуальный контекст, не на фактические guards.
   Не подменять AuthUser/IdentityAccessSnapshot fake verified объектом.
4. Выбор названия и представления оставить чистой application-проекцией
   в существующем файле. Новый service/repository/controller для этого
   изменения по умолчанию не нужен; не вводить dependency или storage.
5. Личные действия и публикацию не сводить к одному bool `canCreate`.
   Open profile, open own library, prepare permitted draft, submit,
   publish, create page проверяются своими существующими правилами.
6. Не добавлять импорт Identity data/domain в Explore UI ради новых checks.
   Если на целевой базе недостаёт входа для безопасного отображения,
   передать минимальные данные через существующую app composition; точный
   файл и тест такого изменения дописать в file map до его внесения.
   Business mutation guards продолжают жить в существующих usecases/controllers.
7. Зафиксировать null/loading/error state: общий personal layout может
   показывать загрузку, но неизвестный access не считается разрешением.
   Verified badge и privileged actions не выводятся из слова Creator.
8. Сохранить доступные legacy generator/route actions за прежними условиями.
   Удаление Viewer не является удалением этих функций или назначением
   Pro generator новой страницей/ролью.

**Тесты:** title/layout одинаковы при разных grants; presentation не повышает
права; unverified/pending/revoked и неизвестные данные не дают новые mutation
разрешения; собственный personal Scenario сохраняет прежнюю доступность.
Проверять реальные действия/guards, а не только одинаковую строку enum.

**Приёмка:** новая проекция готова и focused unit tests зелёные; нет второго
источника авторизации. **Откат:** вернуть подготовительный application diff;
до cutover прежний экран продолжает работать.

## Уточнение границ задания

Цель этого захода — компилируемая подготовка. Не удаляй enum values и не сдавай наполовину изменённый экран. Не решай задачу возвратом creator summary для каждого пользователя: она уже содержит canCreate=true. Базовый подход — существующий application helper, без нового пакета/service/storage. Если для безопасного input нужен новый cross-feature consumer, сначала назови точный файл и причину; не добавляй прямой Identity data/domain импорт в Explore UI.

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

Добавь meaningful unit coverage display/access, unknown input, preview и отсутствие новых grants. Запусти targeted tests и analyzer изменённого scope. Для завершённого coding slice выполни требуемые target AGENTS проверки; не выдавай частичный прогон за полный. Boundary/diff checks обязательны.


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
| PVR-AC-08 | Presentation/preview не создают новые role/capability grants | A02–A08, unit/usecase tests |
| PVR-AC-20 | Unknown/error access не считается разрешением; auth redirect сохранён | A01/A06 |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/04-presentation-access.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 04; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
