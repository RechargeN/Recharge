# Задание PVR-01 / заход 07: Retirement документов, cleanup и проверка восстановления

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

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Передачи 00–06 и карта переноса с действующими destinations.
- Archive manifest/source hashes и принятый ADR.
- Полный repo reference scan обеих Viewer specs; consumers удаляемых helpers.

## Разрешённый файловый объём этого захода

- docs/product/identity/VIEWER_PROFILE_FUNCTIONAL_SPEC.md; PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md — заменить retirement pointers после проверки ссылок.
- docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md; PROFILE_DOCUMENTS_INDEX.md и выявленные действующие doc consumers.
- README/SYMBOLS/RESTORE проверенного архива — уточнить; raw snapshots неизменны.
- F01/F02 — только доказанный Viewer dead code после проверки consumers.
- docs/verification/pvr-01/07-retirement-restore.md; docs/verification/PVR_01_VERIFICATION.md.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 07 — закрыть активный Viewer и проверить возвращаемость архива

**Файлы:** два старых Viewer spec paths, retirement map, index, архивные
README/SYMBOLS/RESTORE, потребители ссылок; F01/F02 только для подтверждённого
dead code cleanup. Исходные raw snapshots остаются неизменными.

**Порядок:**

1. Сверить карту переноса со всеми живыми references. Нельзя снять документ
   с активного статуса, пока на его старый definition ссылается действующий spec.
2. На старых Viewer/Public Viewer путях оставить короткие retirement pointers:
   дата, причина, archive link, ссылка на общий Creator и базовую публичную
   проекцию, ссылка на migration map. Это совместимость старых bookmarks,
   не две продолжающиеся спецификации отдельной страницы.
3. Исправить direct links и version headers у текущих consumers. Old section
   links переводить на точные новые anchors, а не на начало огромного файла.
   Не переписывать всю историческую хронику и закрытые slice-отчёты.
4. Поиск runtime должен не находить `AccountExperience.viewer`,
   `AdminExperiencePreview.viewer`, `_ViewerProfileBody`, `_ViewerUpgradeRow`,
   Viewer-only labels и `admin-preview-viewer`, кроме тестов отсутствия.
5. `ProfileRoleTier.user` допустим как внутренний legacy/access input только
   если больше не выбирает отдельный экран. `viewer/unlistedViewer` Scenario,
   `PublicPageViewerContext`, контекст просмотра чужого контента и history
   сохраняются. Не задавать ошибочный gate «слова viewer нигде нет».
6. Проверить references/imports до удаления общих helpers. Удалять только
   невостребованный код от Viewer, сохраняя reused components и actions.
7. Проверить, что приложение, tests, pubspec/assets и build scripts не
   импортируют/пакуют archive. Не добавлять broad analyzer excludes ради
   сохранения старых `.dart` файлов: snapshots уже имеют `.dart.txt`.
8. Выполнить restore drill во временной папке вне runtime: восстановить
   оригинальное имя одного source snapshot, перечитать и сверить hash.
   Сверить исходные paths/import inventory с manifest. Описать результат
   честно: это проверка сохранности и инструкции, не сборка исторического app.
9. Обновить RESTORE текущими replacements. Возврат целого старого общего
   profile-файла поверх будущего кода запрещён; выборочный перенос — default.

**Приёмка:** активные specs не требуют отдельного Viewer, raw copies целы,
инструкция проверена, архив не участвует в runtime.
**Откат:** вернуть retirement pointers/links согласованным doc diff;
runtime rollback остаётся отдельным набором захода 05.

## Уточнение границ задания

Сначала перенеси/перепривяжи всех действующих владельцев правил, затем заменяй Viewer spec pointers. Archived copies не редактировать. Scenario viewer/unlistedViewer, PublicPageViewerContext и history сохранить. Restore drill доказывает сохранность файла/инструкции, а не успешную сборку старого приложения. Во временную папку возвращай одну проверочную копию; не перезаписывай текущий profile_page.dart.

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

### Документы и новые артефакты

Создать:

- `docs/adr/<следующий-свободный-номер>-unified-personal-profile.md`;
- `docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md`;
- `docs/verification/PVR_01_VERIFICATION.md`;
- `docs/archive/viewer-profile/<дата-снимка>/` по manifest захода 01.

Обновить:

- `docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md`;
- `AGENTS.md` с датой версии при изменении;
- `docs/product/VISION.md`;
- `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`;
- `docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md`;
- `docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`;
- `docs/product/identity/PROFILE_DOCUMENTS_INDEX.md`;
- `docs/product/identity/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`;
- `docs/product/identity/PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`;
- `docs/product/identity/PROFESSIONAL_PAGE_DECISION_PACKAGE.md`;
- `docs/architecture/LAUNCH_STATUS.md`.

Заменить на pointers только в заходе 07:

- `docs/product/identity/VIEWER_PROFILE_FUNCTIONAL_SPEC.md`;
- `docs/product/identity/PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`.

Старые Accepted ADR, generated files, assets, dependency manifests и unrelated
исторические specs не редактируются ради общего поиска/замены терминов.

## Проверки исполнителя

Проверь local links/anchors и ID map, hash raw snapshots, отсутствие archive imports/assets/test discovery, допустимые остаточные значения viewer. Выполни restore drill вне runtime. Если изменён Dart — focused/analyzer/boundary и обязательные gates target AGENTS; иначе docs/diff checks.


## Критерии, к которым относится заход

| Критерий | Требование | Evidence |
|---|---|---|
| PVR-AC-05 | Общие personal rules имеют действующего владельца | Заход 03, retirement map |
| PVR-AC-06 | Все VP-D/VP-AC перенесены/aliased/retired с причиной и статусом | Заход 03, ID audit |
| PVR-AC-13 | Нет отдельной Viewer-композиции или fallback selector | U01/U02, symbol scan |
| PVR-AC-14 | Settings/Admin preview не предлагают Viewer | T02, A07/A08, U15 |
| PVR-AC-22 | Privacy/public projection не расширена из-за смены владельца spec | Заход 03, public mapping audit |
| PVR-AC-23 | Archive исключён из runtime; выборочное восстановление проверено | Заход 07, scan/restore drill |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/07-retirement-restore.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 07; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
