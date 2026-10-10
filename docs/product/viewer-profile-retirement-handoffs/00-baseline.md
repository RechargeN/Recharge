# Задание PVR-01 / заход 00: Актуальная база и исходное поведение

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

- Предыдущего захода нет. Существующий план — Proposed; текущая работа не доказывает начало реализации.

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md.

## Прочитать дополнительно

- AGENTS.md; docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md; docs/adr/0017-admin-experience-preview-and-user-created-pages.md.
- Исходники F01–F07 и tests T01–T05 из карты ниже; router, workspace storage, active_create_publisher_provider.dart.
- Поздние docs/product/identity/*PROFILE* и ссылки на Viewer specs.

## Разрешённый файловый объём этого захода

- docs/verification/PVR_01_VERIFICATION.md — создать индекс проверки и baseline.
- docs/verification/pvr-01/00-baseline.md — отдельная передача следующему агенту.
- docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md — актуализировать только baseline/file map.
- docs/product/viewer-profile-retirement-handoffs/ — при переносе пакета в согласованную целевую копию скопировать только документы.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 00 — выбрать базу и снять исходное поведение

**Цель:** все изменения относятся к одному актуальному состоянию.
**Файлы результата:** этот план; новый `docs/verification/PVR_01_VERIFICATION.md`.
Отчёт содержит baseline, журнал заходов, сценарии и итоги. Большие временные
логи держать вне Git; в отчёте — команды, exit codes и существенные результаты.

**Действия:**

1. Подтвердить целевую копию. По найденным файлам рекомендуется актуальная
   `7275`. Если нужен отдельный checkout, указать HEAD и включаемые WIP;
   новая worktree сама по себе не переносит незакоммиченные изменения.
2. Прочитать её AGENTS и вложенные инструкции. Снять status, branch/HEAD,
   список related dirty/untracked. Зафиксировать source root и дату.
   Недоступный Git допускает дальнейшее чтение, но не утверждение, что
   исходная база для вырезания кода полностью зафиксирована.
3. Найти все `AccountExperience`, `AdminExperiencePreview`, `_ViewerProfileBody`,
   `_ViewerUpgradeRow`, `ProfileRoleTier.user`, `_RoleTrack`,
   `_profilePresentationSummary`, `_profileBadgeLabel`. Для каждого:
   удалить / изменить / оставить как общий / не относится.
4. Найти ссылки на обе Viewer specs во всём repo, включая tooling/tests.
   Отделить действующих потребителей section/decision IDs от historical logs.
5. Проверить сериализацию `.name`/`.index`, JSON readers и storage keys для
   experience/preview. По прочитанной базе workspace уже personal/page,
   preview session-scoped: ожидается отсутствие data migration.
6. Снять action/route baseline: Saved, Visited, Scenario, Created, Create Hub,
   listing search/map, продолжение draft/route, Settings, Page Account.
   Для каждого действия записать текущий gate и существующий тест.
7. Проверить Flutter/Dart версии, dependencies и boundary baseline.
   Запустить существующую профильную группу тестов из раздела 14.
   Полный suite baseline нужен дополнительно только для разбора общего сбоя;
   обязательный полный финальный прогон остаётся в заходе 08.
8. Уточнить file map раздела 13. Существенное расширение scope сначала
   записать в план и согласовать; простые найденные consumers включать в
   уже заявленные категории с объяснением причины.

**Приёмка:** единственный root/HEAD, WIP-карта, список функций, route/storage
карта, честный baseline. Известные сбои не записаны зелёными.
**Откат:** исправление документов анализа; приложение не меняется.

## Уточнение границ задания

Выход 00 должен явно выбрать target root и перечислить WIP, который останется входом следующих заходов. Не требуется чистый Git: требуется известный и сохранённый WIP. Не переключай самовольно на старую 012d только потому, что там разрешена запись. При переносе плана на целевую базу не переносить старые runtime файлы. В отчёт включи перечень доступных команд, точные тестовые пути и подтверждение расположения WorkspaceSection.

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

Сними версии Flutter/Dart, Git status/HEAD и boundary baseline. Запусти существующие targeted группы профиля/identity; результаты не выдавай за финальные gates. Код не меняется. Для новых Markdown проверь whitespace, fences и paths.


## Критерии, к которым относится заход

| Критерий | Требование | Evidence |
|---|---|---|
| PVR-AC-01 | Зафиксированы target root/HEAD/WIP и related file map | Заход 00, baseline |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/00-baseline.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 00; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
