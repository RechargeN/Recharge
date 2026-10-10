# Задание PVR-01 / заход 05: Единый Creator Profile, Settings и preview

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

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Передачи 00–04, archive manifest, текущий F02 после подготовки.
- Master plan §§1,9,13,15,16; actual routes и current WorkspaceSection embedding.
- Текущий профиль с ScenarioLibraryPanel и canonical Details links, а не старый файл из 012d.

## Разрешённый файловый объём этого захода

- Семь runtime файлов F01–F07 из карты ниже — согласованный набор изменения.
- Tests T01–T05 — обновить только относящиеся expectations и поведение.
- Условные consumers из §13.2 — только при обнаруженной необходимости, с записью причины.
- docs/verification/pvr-01/05-unified-ui.md; docs/verification/PVR_01_VERIFICATION.md.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 05 — согласованное переключение экрана, Settings и preview

**Файлы:** F01–F07, T01–T05; потребители из условного file map только при
реальной необходимости. Это одна согласованная runtime-поставка:
переименование enum нельзя сдавать отдельно с неработающими switch consumers.

### 9.1 Единый личный экран

1. Основой остаётся Creator-композиция. Hero и редактируемые личные данные
   используют прежние источники. Title — Creator; слово VIEWER исчезает.
2. Сохранить Created и доступные действия над собственными drafts/listings.
   Для аккаунта без публикаций — существующее честное empty state, без
   фиктивных публикаций и выдачи publishing rights.
3. `ScenarioLibraryPanel` остаётся общим и в прежнем owner scope.
4. Сохранить Visited shortcut в личном профиле и существующий экран истории.
   Основной вариант: использовать загрузку самого Visit History screen;
   не переносить старую Viewer-only summary подписку без потребности UI.
   Вырезанные preview rows сохраняются в архиве как наработка.
5. Сохранить доступ к Saved/Favorites через личную навигацию и компактное
   действие профиля, если оно требуется для сохранения существующего входа.
   Не создавать вторую библиотеку или новый источник сохранённых объектов.
6. Удалить Viewer-only `_ViewerProfileBody` и `_ViewerUpgradeRow`, затем
   удалить только доказанно неиспользуемые helpers. Общие surface/action
   widgets остаются, если у них есть другие consumers.
7. Для verification/tools использовать существующее действие/состояние
   внутри общего профиля. Не строить новый verification flow или кнопку,
   обещающую немедленный upgrade прав.
8. Удалить `_RoleTrack` как способ выбрать отдельные personal layouts,
   включая fallback без `AccountExperienceScope`. `ProfileWorkspacePage`
   остаётся доступным tool dashboard, если нужен существующим действиям.
   Его Saved/Search/Smart Search/Create/route handoffs не теряются.

### 9.2 Experience и preview

1. `AccountExperience` принимает `personal | professionalPage`.
   В коде имя personal соответствует workspace, в UI — Creator.
2. `effectiveExperience`: активная разрешённая page сохраняет существующий
   приоритет; page preview даёт только presentation; personal и Creator
   preview приводят к personal. Verification не выбирает отдельный layout.
3. `AdminExperiencePreview`: удалить viewer, сохранить creator/professionalPage.
   Обновить mapper, все exhaustive switches, `.values`, ключи выбора и tests.
4. Shell default/fallback — personal. Во время загрузки/ошибки не всплывает
   старый Viewer screen. Сам auth redirect продолжает работать как раньше.
5. Preview не меняет active workspace/PublisherRef и не создаёт page fixture.
   Выход из preview/смена workspace сохраняют прежние reset semantics.

### 9.3 Settings и навигация

1. В `WorkspaceSection` одна строка личного Creator профиля. Subtitle
   отражает фактическую доступность tools/verification, без Viewer.
2. Page rows остаются по точным page IDs; owner и invited manager не
   становятся одним правовым состоянием. Quota/creation/request UI сохраняется.
3. `WorkspaceSectionHost` и inline embedding сохраняются. Не возвращать
   отдельную старую WorkspaceSwitcherPage и не добавлять новый Viewer redirect.
4. Personal bottom navigation сохраняется; page navigation сохраняется.
   Проверить Account destination внутри page и открытие личных Settings.
5. На базе `012d` применять эквивалентное изменение в старом switcher можно
   только если эта база явно выбрана; не править обе реализации «на всякий случай».

**Проверки:** focused tests для изменённых seven-file consumers, analyze
затронутого scope, профиль в personal/page и без inherited scope.
Проверить отсутствие runtime references к удалённым enum values.
**Приёмка:** единый профиль реально достигается из всех существующих входов,
Viewer отсутствует, Creator/Page действия работают. **Откат:** вернуть весь
согласованный cutover набор F01–F07 и соответствующие tests; частичный
возврат enum/consumer запрещён. Пользовательское storage не откатывать.

## Уточнение границ задания

Этот заход выполняется одним агентом последовательно: не разделять enum/model и UI consumers между несогласованными параллельными исполнителями. Сохрани личные функции и Creator actions; ожидаемая модель AccountExperience personal/professionalPage, Admin preview creator/professionalPage. Не менять WorkspaceRef/PublisherRef storage types. Удалить Viewer body/upgrade и fallback selector, но не общий профиль. Сохранить Settings inline WorkspaceSection и существующий ProfileWorkspace dashboard.

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

Focused profile/workspace/shell/identity tests, analyzer, absence scan удалённых runtime symbols, boundary/diff checks. Убедись, что enum и все exhaustive consumers согласованы и app компилируется. Выполни обязательные Flutter gates target AGENTS перед объявлением coding slice Done.


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
| PVR-AC-09 | Creator сохраняет существующие разрешённые tools/listing actions | A05, U07–U09 |
| PVR-AC-13 | Нет отдельной Viewer-композиции или fallback selector | U01/U02, symbol scan |
| PVR-AC-14 | Settings/Admin preview не предлагают Viewer | T02, A07/A08, U15 |
| PVR-AC-15 | Personal и page navigation/Account переходы сохранены | T03, U11 |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/05-unified-ui.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 05; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
