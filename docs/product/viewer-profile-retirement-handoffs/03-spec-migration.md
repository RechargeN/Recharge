# Задание PVR-01 / заход 03: Перенос общих требований из Viewer

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

Проверь не только слово Done, но и ссылки на результаты, реальные файлы и проверки. Report index: docs/verification/PVR_01_VERIFICATION.md. Для зависимого изменения политики/runtime требуется принятое конкретное ADR из захода 02; не путай authoring_done с decision_accepted.

## Прочитать дополнительно

- Передачи 00–02; конкретный новый ADR и подтверждённый статус его принятия.
- Обе Viewer specs целиком и соответствующие Creator/Page consumers.
- Архивный manifest для source versions; master plan §7 и §15.

## Разрешённый файловый объём этого захода

- AGENTS.md — UI policy/дата; не объявлять runtime завершённым.
- docs/product/VISION.md; docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md.
- docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md; PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md.
- docs/product/identity/PROFILE_DOCUMENTS_INDEX.md; PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md; PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md; PROFESSIONAL_PAGE_DECISION_PACKAGE.md.
- docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md — новый reference map.
- docs/verification/pvr-01/03-spec-migration.md; docs/verification/PVR_01_VERIFICATION.md.

Остальные файлы читаются как контекст. Содержательное расширение сначала отрази в плане и объясни, не включай unrelated cleanup. Общий отчёт обновляй добавлением результата своего захода; предыдущие доказательства не переписывай.

## Подробные действия: Заход 03 — перенести общие требования и сохранить их происхождение

**Цель:** после снятия Viewer-документов с активного статуса ни одно общее
правило не останется только в архиве, а личные функции не станут verified-only.

**Изменяемые документы:** `AGENTS.md`, `docs/product/VISION.md`,
`docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` и документы из каталога
`docs/product/identity/`: Creator Profile, Public Creator Profile,
Profile Documents Index, Professional Page, Public Professional Page,
Professional Page Decision Package. Имена файлов полностью перечислены в
разделе 13. Viewer-файлы пока сохраняются: retirement pointers — заход 07.

**Новый результат:**
`docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md`, reference-карта
переноса. Она не задаёт собственных domain rules. Для каждого элемента:
source version/section/ID, текущий статус, destination/anchor, treatment,
обнаруженный конфликт, owning aggregate и проверивший заход.

### 7.1 Правила переноса

1. Создать внутри Creator spec явно выделенный раздел «Общая личная часть».
   Существующие verification/publishing разделы оставить отдельной частью.
   Открытие единого профиля не требует Creator grants; конкретные операции
   требуют своих прежних условий. Не добавлять новый общий aggregate.
2. Перенести используемые определения `UserProfile`, `AccountStatus`,
   personal libraries и privacy. Сохранить owning contracts Scenario,
   Quick Plan, Booking, Identity, Media; profile не становится их хранилищем.
3. Исправить старую формулу Creator spec, где full verified identity
   требовалась для всего его прежнего узкого scope: verification применяется
   только к требующим её действиям. Переименование заголовка недостаточно.
4. В Public Creator spec выделить базовую контекстную identity projection
   и отдельно существующую публичную карточку eligible Creator. Это разные
   условия видимости, даже при едином личном профиле владельца.
5. Сохранять Draft/Open/Approved/Accepted maturity каждого правила.
   Назначение нового файла не разрешает реализацию отложенной функции.
6. Не перенумеровывать массово `VP-D*`/`VP-AC-*`: сохранить IDs с пометкой
   transferred и новой ссылкой. При слиянии одинаковых правил указать
   alias → canonical ID. Один ID не должен получить два разных значения.
7. Не решать попутно вопросы Legal, minors, Follow, retention и step-up.
   Их прежние открытые вопросы, владельцы и зависимости переходят в карту.

### 7.2 Пораздельная карта Viewer v1.17

Destination ниже — раздел действующей спецификации, который нужно создать
или дополнить. Точные anchors фиксируются в retirement map при переносе.

| Исходный раздел | Действующее место после переноса | Обработка |
|---|---|---|
| §0 authority/current boundary | Creator §0 + index | Развести текущий runtime и Draft full-release |
| §1 product definition, §3 access/workspace | Creator: общая личная часть / access | Удалить отдельный Viewer surface, сохранить auth-only личный доступ |
| §2 extensions policy | Creator scope / originating contracts | Сохранить требования к Approved bounded slices |
| §4 UserProfile, libraries, invariants | Creator: личные данные и библиотеки | Сохранить ownership, IDs и source-of-truth |
| §5 Scenario/Quick Plan | Creator: личные планы | Ссылки на их собственные contracts; различия aggregates/roles остаются |
| §6 Saved/activity | Creator: сохранённое и активность | Сохранить раздельные библиотеки |
| §7 Visit History | Creator: посещения | Self-reported, без автопревращения booking/GPS в visit |
| §8 participation | Creator: участие | Booking/admission владеют своими правилами |
| §9 Reviews | Creator: отзывы | Авторство отзывов и отзывы о контенте различаются |
| §10 Photos | Creator: личные фото | Сохранить Media/privacy зависимости и зрелость |
| §11 publishing boundary | Creator: publishing | Сохранить границу личного и publisher-bound контента |
| §12 public projection | Public Creator: базовая проекция | Перенаправить на перенесённые Public Viewer правила |
| §13 modules vs capabilities | Creator: access matrix | Модуль UI не становится capability grant |
| §14 IA | Creator: IA | Заменить дублирующую Viewer-композицию общей личной |
| §15 AccountStatus/sessions | Creator: общий account lifecycle | Сохранить все состояния, precedence и session restrictions |
| §16 notifications/settings | Creator: настройки и уведомления | Сохранить personal/page scope и recipients |
| §17 security/offline | Creator: общая безопасность | Сохранить ограничения, не заявляя новый runtime |
| §18 UX states | Creator: состояния личного UI | Дедупликация с происхождением каждого требования |
| §19 roadmap | Creator roadmap + retirement map | Отдельную Viewer page снять; общие future задачи сохранить |
| §20 AC, §21 tests | Creator: перенесённые AC/tests | Сохранить IDs, отделить критерии PVR-01 от будущих |
| §22 decisions | Creator: transferred decisions + map | Перенести статус каждого VP-D, не принимать автоматически |
| §23 Done | Creator: merged DoD | Удалить требование существования отдельного Viewer UI |
| §24 lifecycle | Creator: personal lifecycle | Сохранить ownership/concurrency/deletion/notification ссылки |
| §25 relations | Index + связанные specs | Исправить владельцев определений |
| Appendix A | Ссылки на действующие exclusions | Сохранить относящиеся ограничения |
| Appendix B history | Архив | Историю не выдавать за новые правила |

### 7.3 Public Viewer v1.0

| Исходный раздел | Действующее место | Проверка |
|---|---|---|
| §0/§1 authority и definition | Public Creator: базовая контекстная проекция | Она не становится самостоятельной searchable page |
| §2 visibility defaults | Там же, visibility | Прежние defaults для обычного аккаунта |
| §3 Public User Projection | Там же, allowlisted fields | Приватные поля не добавлены |
| §4 discoverability/block/deletion | Там же, разрешение контекстной проекции | Нельзя обходить block/deleted-account правила |
| §5 Follow | Transferred open decision | Сохранить совместную зависимость PP-D44/PCP-D02 |
| §6 never exposes | Там же, exclusions | Личные планы, контакты/security и другие запрещённые поля не раскрыты |

### 7.4 Проверка открытых решений

В прочитанном Viewer decision tracking есть `VP-D01`–`VP-D16`.
В retirement map перечислить каждый, а не только несколько заметных:

- D01/D03/D05/D07/D09/D11/D13/D16: сохранить Open/default и исходный вопрос;
- D02: сохранить partial default и нерешённую часть Quick Plan;
- D04: сохранить backend dependency;
- D06: сохранить partial default и нерешённые retention/legal условия;
- D08/D10: сохранить product/legal/child-safety gate без придуманного решения;
- D12: сохранить joint Follow decision;
- D14: сохранить legal/privacy dependency;
- D15: сохранить необходимость security review.

Это контроль полноты переноса, не новое утверждение допустимости defaults.
При изменении исходной версии использовать её фактическую таблицу.
`AccountStatus` axis, verification, moderation и session step-up не сливать.
Не устранять за счёт переименования уже известные открытые security вопросы.

**Проверки:** поиск всех старых ссылок, уникальность declarations IDs,
валидность новых anchors, сопоставление enum shapes и version headers.
Проверить отдельно Creator/Public Creator/Page consumers `AccountStatus`,
block/privacy и deletion references. На Draft package остаётся Draft-статус.

**Приёмка:** каждый живой общий раздел имеет destination; каждый старый
decision/AC ID перенесён, aliased либо явно retired с причиной.
**Откат:** обратный doc diff с восстановлением согласованного набора ссылок;
исторические исходники доступны в архиве захода 01.

## Уточнение границ задания

Начинай содержательное изменение целевой политики после принятия ADR 02; если он только Proposed, подготовь read-only impact map и запроси недостающее принятие, не маркируя перенос готовым. Работу внутри этого захода можно разбить на 03A: личные правила; 03B: публичная базовая проекция; 03C: consumers/ID map. Это один bounded docs результат, а не повод заново согласовывать обычные правки. Оба Viewer-файла пока не заменять pointers — это заход 07. Общие требования переносить с исходным статусом; security/Follow/legal/minors решения не принимать автоматически.

## Развёрнутая карта упоминаемых файлов

Это справочник полного slice. Право редактирования в текущем заходе ограничено
списком «Разрешённый файловый объём» выше; остальные строки нужны для чтения
и понимания зависимостей, а не для попутной реализации следующих заходов.

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

Сверь все VP-D и VP-AC declarations: каждый перенесён, aliased или retired с причиной. Проверь exact destinations/anchors, статусы maturity, enum shapes, version headers и все live references. Markdown/diff checks, без Flutter при отсутствии runtime edits.


## Критерии, к которым относится заход

| Критерий | Требование | Evidence |
|---|---|---|
| PVR-AC-05 | Общие personal rules имеют действующего владельца | Заход 03, retirement map |
| PVR-AC-06 | Все VP-D/VP-AC перенесены/aliased/retired с причиной и статусом | Заход 03, ID audit |
| PVR-AC-22 | Privacy/public projection не расширена из-за смены владельца spec | Заход 03, public mapping audit |

В этом заходе закрывай только то, что реально подтверждено. Подготовка для будущего сценария не равна его успешной runtime проверке. Номера разделов внутри выдержек выше относятся к master plan.

## Передача следующему агенту

Создай docs/verification/pvr-01/03-spec-migration.md и добавь ссылку в docs/verification/PVR_01_VERIFICATION.md. Не создавай фиктивный отчёт другого захода. В своей передаче обязательно укажи:

- STAGE: 03; RESULT: ready / not_ready / needs_user_decision; фактическую дату.
- TARGET_ROOT, HEAD, branch и relevant WIP на входе и выходе; отсутствие commit не означает отсутствие результата.
- Входные передачи и что проверено по ним; actual ADR path/status и основание принятия, если применимо.
- Все изменённые/новые файлы; значимые symbols/routes; границы собственной дельты.
- Для файлов, важных следующему заходу, paths и SHA-256 итогового содержимого; если последующие edits меняют hash, это должно быть объяснено новой передачей.
- Проверки: рабочая директория, точная команда, exit code, число/результат тестов, существенные ограничения и ссылку на evidence.
- PVR-AC и A/U сценарии: подтверждено / не проверялось / docs-only с объяснением; не маскировать failure статусом N/A.
- Точный путь архива и manifest при наличии, не менять сохранённый source snapshot.
- Нерешённые вопросы, конкретный откат своей дельты, что готово для следующего захода и чего ему ещё нельзя предполагать.

В финальном сообщении пользователю дай короткий результат, файлы, проверки и ссылку на свою передачу. Следующий заход автоматически не выполняй.
