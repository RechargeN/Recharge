# Viewer Profile: подробный план удаления отдельной страницы с архивом

Версия: 2.4. Дата: 2026-10-10. Первый анализ: 2026-10-09.
Slice: `PVR-01` — Personal profile / Viewer retirement.
Статус: **In progress / итог not_ready: bounded scope §6.1/§13 принят, ADR 0021 Accepted; единый local/mock UI и retirement реализованы, регрессионная приёмка не закрыта.**

Пользователь подтвердил результат: «всё то же самое, что и было,
но убираем Viewer как лишнюю страницу». Исходный запрос — подробный план.
Этот документ заменяет первоначальный пятиэтапный план.

## 1. Конечный результат и границы

### 1.1 Пользовательская модель

Остаётся единственный личный профиль **Creator** и отдельные Professional
Pages, которыми аккаунт владеет или управляет. В Settings один личный профиль
и список доступных страниц. Отдельного Viewer-экрана, Viewer preview и
перехода «из Viewer в Creator» больше нет. Старые наработки лежат в архиве.

| Понятие | Решение |
|---|---|
| Имя личного интерфейса | Creator |
| Системные роли | Прежние `User / Creator / Admin`; название UI не записывается в role |
| Верификация | Прежний отдельный факт, не следствие открытия профиля |
| Create/submit/publish | Прежние gates конкретного действия; открытие инструмента не выдаёт mutation authority |
| Личный workspace | Прежний `WorkspaceRef{personal, userId}` |
| Страница | Прежний `WorkspaceRef{page, pageId}` и membership точного pageId |
| Publisher | Прежний `{type: user | page, id}`; переключение не переписывает существующий draft |
| Admin | Отдельные служебные инструменты и presentation preview |
| Публичность | Личный Creator Profile не делает каждый аккаунт публичным/searchable |

### 1.2 Обязательное сохранение функций

| Область | Что сохраняется |
|---|---|
| Creator | Created, существующие listing/draft actions и доступные tools |
| Личные функции | Favorites/Saved, Visit History, существующая Scenario library |
| Quick Plan | Существующие входы и данные, отдельный aggregate |
| Профиль/Settings | Редактирование личных полей, настройки, logout |
| Personal navigation | Home / Favorites / Smart Search / Notifications / Profile |
| Professional Page | Её экран, navigation, Account и возврат в personal |
| Page ownership | IDs, owner, memberships, quota, pending requests, local notifications |
| Доступ | Auth-gate, права конкретной операции, изоляция данных между аккаунтами |
| Privacy | Перенос описания не раскрывает личные библиотеки в публичной карточке |

Входит: устранение отдельной презентации Viewer, перенос общих используемых
требований, архив, регрессия. Новые функции из Draft specs не реализуются
из-за переноса текста. Реальная верификация, Follow, Payments, account
deletion, новые public profiles и production backend не входят в этот slice.

## 2. Проверенные исходники и уточнение первого плана

### 2.1 База

Заход 00 выполнен 2026-10-10. TARGET_ROOT:
C:/Users/User/.codex/worktrees/7275/Recharge; branch codex/recharge-integration;
HEAD 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.
[Передача 00](../verification/pvr-01/00-baseline.md) содержит полный WIP,
hashes и route/storage/action baseline. Mobile/tests чисты; backend/media WIP
сохранён как вход. 4d5f и исходный пакет 012d на старом detached
06dae4920e8dbf9492267d534397689c345169b1 не являются implementation базой.
AGENTS target версии 2026-09-29; вложенных AGENTS нет.
ADR 0015/0017 Accepted, новый PVR ADR не создан; план остаётся Proposed.
Flutter 3.44.9/Dart 3.12.2; baseline 56 + 22 tests passed;
boundary 0 violations/71 suppressed. Финальные gates не выполнены.
Switcher расположен в WorkspaceSection через WorkspaceSectionHost,
router внедряет его в SettingsPage.workspaceSectionBuilder.
Runtime из 012d не переносился. Предыдущих выполненных передач нет.

### 2.2 Существенные точки кода

Все короткие пути этой таблицы находятся внутри `apps/mobile/lib/` поздней копии.

| Наблюдение | Файл/символ |
|---|---|
| Один `/profile`, отдельного Viewer route нет | `app/router/app_router.dart`, `ProfilePage` |
| Viewer — ветка в общем файле | `features/explore/presentation/pages/profile_page.dart`, `_ViewerProfileBody` |
| Scenario library уже общая | тот же файл, `ScenarioLibraryPanel` до ветвления |
| Visit summary загружается только для `isUser` | тот же файл, `_scheduleVisitedLoad` |
| У Creator есть Visited shortcut | тот же файл, `_ProfileDashboardTabs` |
| Selector может вернуться при отсутствии scope | тот же файл, `ProfileWorkspacePage`, `_RoleTrack` |
| Creator summary содержит `canCreate: true` | `features/explore/application/profile_role_summary.dart` |
| Three-way experience | `core/identity/account_experience.dart` |
| Verification выбирает отдельный Viewer body | `features/identity/application/state/identity_workspace_state.dart` |
| Fallback — Viewer | `app/presentation/recharge_app_shell.dart` |
| Viewer labels/preview внутри Settings | `features/identity/presentation/widgets/workspace_section.dart` |
| Publisher уже зависит от workspace | `app/application/active_create_publisher_provider.dart` |

Символы указаны вместо старых строк: номера между копиями меняются.
`features/auth/presentation/pages/profile_page.dart` старой копии — другая
простая заготовка; активный router импортирует профиль из `features/explore`.

### 2.3 Риски и решения

| Риск | Решение |
|---|---|
| Удалить Creator вместе с общим файлом | Snapshot целого файла, затем точечное вырезание Viewer |
| Потерять посещения/избранное/планы | Список функций до изменения и поведенческая регрессия |
| Выдать всем create/publish через UI | Разделить presentation и реальный access |
| Требовать verification для личных библиотек | Перенести условную формулу доступа из Viewer, не расширять старую Creator-формулу |
| Потерять AccountStatus/privacy | Пораздельный перенос и карта старых decision/AC IDs |
| Затереть поздние Scenario/Settings изменения | Работать на актуальной базе, не переносить старые общие файлы поверх неё |
| Удалить другой смысл viewer | Сохранять Scenario roles и public-viewer context |

## 3. Порядок заходов

Последовательность: `00 → 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08`.
Каждый заход — ограниченная работа с результатом, проверками и откатом;
это не обещание фиксированного времени и не обязательный отдельный commit.
После каждого захода записывать изменённые файлы, результаты, остатки и
следующий шаг. Commit/push/merge требуют отдельной авторизации пользователя.

| Заход | Работа | Зависимость | Результат |
|---|---|---|---|
| 00 | Точная база и исходное поведение | Старт реализации | Baseline, WIP, окончательный file map |
| 01 | Проверенный архив | 00 | Полные snapshots и восстановление |
| 02 | Узкий ADR и bounded contract | 00–01 | Оформленная замена UI/preview решения |
| 03 | Перенос общих требований | 02 | Действующий владелец каждого общего правила |
| 04 | Presentation и access | 02–03 | Внешний вид не выдаёт прав |
| 05 | Экран, enums, Settings, preview | 01, 04 | Согласованный cutover без половинчатого runtime |
| 06 | Доступ и пользовательская регрессия | 05 | Матрица сценариев выполнена |
| 07 | Retirement docs, cleanup, restore drill | 03, 05–06 | Архив пригоден, активные ссылки исправлены |
| 08 | Общие gates и фактический статус | 00–07 | Критерии Done подтверждены |

## 4. Заход 00 — выбрать базу и снять исходное поведение

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

## 5. Заход 01 — полный архив Viewer до первой правки

**Цель:** сохранить контекст, достаточный для последующей адаптации.
**Папка:** `docs/archive/viewer-profile/<дата-снимка>/`; дата фактического
копирования, а не дата плана. Архив не становится runnable Flutter package.

```text
README.md
MANIFEST.md
RESTORE.md
SYMBOLS.md
specs/docs/product/identity/...
context/docs/adr/...
context/AGENTS.md.txt
source/apps/mobile/lib/.../*.dart.txt
tests/apps/mobile/test/.../*.dart.txt
context/apps/mobile/pubspec.yaml.txt
context/apps/mobile/pubspec.lock.txt
```

**Состав:**

1. Viewer/Public Viewer specs целиком, с исходными версиями и содержимым.
2. Документальный контекст: Creator/Public Creator, Professional Page/Public
   Professional Page, Profile Documents Index, Professional Page Decision
   Package, Identity Publisher slice, VISION, ADR 0015/0016/0017.
3. Семь основных runtime файлов F01–F07 раздела 13 целиком; исходники
   условных файлов — перед их изменением. Общий `profile_page.dart`
   сохраняется полностью из-за приватных widgets и локальных helpers.
4. Tests T01–T05 и изменяемые дополнительные тесты. В SYMBOLS перечислить
   зависимости от ScenarioLibraryPanel, VisitHistory, Favorites, Create,
   routing, auth providers и design tokens; общий код не «переезжает» из app.
5. Pubspec/lock и toolchain version — сведения для восстановления.
6. Релевантный WIP сохраняется фактическими байтами с отдельной отметкой;
   HEAD не описывает untracked/dirty содержимое. Unrelated WIP, credentials,
   user storage, cache/build и `.git` в архив не входят.

**Manifest:** исходный root/relative path, archive path, назначение, HEAD,
dirty state, byte size, SHA-256, doc version. Hash source = hash raw copy.
При добавлении `.txt` меняется имя, не содержимое/переводы строк.
Контекстный AGENTS хранить как `.txt`, чтобы он не стал инструкцией архива.

**SYMBOLS.md:** Viewer-only symbols, общие widgets, внешние данные/импорты,
старые entrypoints и их замены. Один `_ViewerProfileBody` не самодостаточен.

**RESTORE.md:** два сценария — выборочно адаптировать идею/UI к текущему
приложению либо исследовать старый профиль на точной исторической базе.
Указать необходимую Git history/WIP/dependencies. Архив не обещает собрать
старое приложение без SDK, репозитория и зависимостей.

**Проверки:** перечитать все snapshots, сверить sizes/hashes, manifest
completeness, ссылки и отсутствие archive в package graph/lib/test/assets.
README явно помечает Historical/reference; старые Draft/Accepted headers
внутри снимков не делают архив действующим источником решений.

**Приёмка:** проверенный архив существует до удаления runtime-ветки.
**Откат:** архив можно оставить; после правок исходников не обновлять его
как будто это первоначальное состояние. Новый baseline — новый snapshot.

## 6. Заход 02 — узкий ADR и договорённость об объёме

**Файлы:** новый `docs/adr/<следующий-свободный-номер>-unified-personal-profile.md`,
план и verification report. Номер определяется на целевой базе.

**ADR должен зафиксировать:**

1. Из ADR 0015 меняется UI-терминология: единый личный Creator Profile;
   существование страницы не означает verification/role grant.
2. В ADR 0017 заменяется набор Admin previews на Creator/Professional Page.
   Разные access/verification состояния по-прежнему покрываются тестами,
   без отдельной продуктовой страницы Viewer.
3. Сохраняются system roles, mandatory auth, PublisherRef, page membership,
   privacy, User-owned personal planning и прежние operation gates.
4. Личные библиотеки доступны без publishing verification. Отказ конкретной
   операции не отправляет пользователя на иной вид личного профиля.
5. Архивирование, ожидаемая нулевая data migration, local gates и rollback.

Продуктовая цель уже выбрана пользователем, повторное обсуждение нужности
Viewer не требуется. Proposed ADR получает Accepted только после принятия
конкретного текста; runtime опирается на согласованный bounded file plan.
Основание — приоритет Accepted ADR и правило 9 AGENTS. Это не требует
принятия всех открытых решений больших Draft profile specs.

**Приёмка:** указано, какие UI/preview положения заменяются; техническая
роль Creator и authority не переопределены. **Откат:** Proposed правится
doc diff; принятое решение позднее меняется новым ADR по правилам repo.


### 6.1 Результат authoring захода 02 и bounded contract

Подготовлен [ADR 0021: Unified Personal Profile](../adr/0021-unified-personal-profile.md),
Status: Accepted (2026-10-10). authoring_done=true; decision_accepted=true.
Пользователь явно принял конкретный текст ADR 0021 и bounded scope §6.1/§13.
[Передача 02](../verification/pvr-01/02-decision.md) фиксирует evidence/остаток.

После принятия ADR меняет только личную UI-терминологию ADR 0015 §2 и набор
presentation previews ADR 0017; authority и обязательная auth сохраняются.
Личный UI Creator не назначает роль Creator. Личные библиотеки/owned planning
не требуют publishing verification; прежние operation-specific gates остаются.

Согласуемый bounded file plan для будущего local cutover — точная карта §13:
F01–F07, уже названные conditional consumers только по конкретной причине,
T01–T05 и существующая дополнительная регрессия. Документационный перенос
остаётся перечисленным scope захода 03; Draft/Open maturity не повышается.
Runtime changes выполняются только в отдельно переданном заходе после принятия
ADR и bounded плана; принятие ADR само не запускает остальные заходы.
Нет permission/domain/store rewrite, новых зависимостей, backend/cloud,
Follow/Payments/real verification или полной реализации Draft profile specs.

Архив 01 проверен и неизменяем. Expected data migration=0 подтверждено базой:
WorkspaceRef personal/page и PublisherRef user/page остаются, preview session-only.
Обнаруженный storage consumer требует narrow compatibility plan до cutover.
Local acceptance остаётся §15 и полными gates 08; rollback остаётся §16.

## 7. Заход 03 — перенести общие требования и сохранить их происхождение

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

## 8. Заход 04 — отделить единый внешний вид от реальных разрешений

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

## 9. Заход 05 — согласованное переключение экрана, Settings и preview

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

## 10. Заход 06 — проверить действия, данные и переходы

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

## 11. Заход 07 — закрыть активный Viewer и проверить возвращаемость архива

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

## 12. Заход 08 — общие gates, итог и передача

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

## 13. Полная карта файлов

Пути даны относительно целевого repo root. Это proposed список для `7275`.
Заход 00 подтверждает точные текущие consumers; старые пути `012d` не смешиваются
с поздней архитектурой. Новые большие abstractions по умолчанию не нужны.

### 13.1 Семь основных runtime файлов

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

### 13.2 Условные consumers: сначала read-only, правка с конкретной причиной

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

### 13.3 Тесты

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

### 13.4 Документы и новые артефакты

Создать при выполнении соответствующих заходов:

- `docs/adr/<следующий-свободный-номер>-unified-personal-profile.md`;
- `docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md`;
- `docs/verification/PVR_01_VERIFICATION.md`;
- `docs/verification/pvr-01/00-baseline.md` — `08-final-gates.md`: отдельные
  отчёты передачи между агентами, точные имена в пакете заданий;
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

### 13.5 File map подтверждён заходом 00

F01–F07/T01–T05 существуют без related WIP. Runtime scan: 8 файлов —
основные семь и уже заявленный identity_workspace_controller.dart.
В F01 также изменить _profilePageTitle/_profileContextLine в пределах той же
категории; ProfileRoleTier.user сохранить как actual access classification.
Host/Settings fallback уже общий, Viewer URL нет; route_names остаётся без
правки при отсутствии новой конкретной причины. Controller имеет generic
preview/reset и preview.name для telemetry, не storage.
ScenarioLibraryPanel находится в
apps/mobile/lib/features/explore/presentation/widgets/scenario_library_panel.dart.
Дополнительные guard tests: apps/mobile/test/unit/create_controller_test.dart,
apps/mobile/test/unit/create_exact_scenario_open_test.dart. Общая Scenario library
и Publisher non-rewrite требуют cases в ближайшем существующем профильном/
Create тесте будущей регрессии. Tests в 00 не менялись.
Существенного расширения scope не выявлено. Карта consumers/hashes — в 00.

## 14. Команды проверки и фиксация evidence

Все команды выполняются в целевой копии из захода 00, не автоматически в
старой `012d`. Сначала проверить toolchain/dependencies. Не обновлять lockfile
или Flutter packages просто ради выполнения проверки.

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

### 14.3 Формат отчёта каждого захода

```text
Заход / статус / дата:
Target root / HEAD / branch:
Исходный relevant WIP и его сохранность:
Изменённые файлы:
Полученный результат:
Проверки: cwd, command, exit code, count/result, log reference:
PVR-AC и A/U сценарии, закрытые этим заходом:
Не выполнено / причина / влияние:
Следующий заход:
Способ отката конкретной дельты:
```

Статусы заходов: Not started / In progress / Review / Done.
Blocked допустим как описание конкретной внешней зависимости, с указанием
чего именно не хватает; сложная или объёмная работа сама по себе не blocker.
Не смешивать terminal command evidence, локальный UI preview, device и cloud.

## 15. Проверяемые критерии PVR-01

Общий результат Done только при выполнении всех применимых критериев.
Для будущих Draft правил проверяется перенос документации, а не реализация
отложенной функции. В evidence указывать точный test case или doc-map row.

| ID | Критерий | Где доказывается |
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

## 16. Правила данных, отката и возвращения Viewer в будущем

### 16.1 Data compatibility

Ожидаемое решение — без schema/key migration: personal/page уже сохранены
в таком виде, system role Viewer не существует, preview не сохраняется как
workspace. Это нужно подтвердить на baseline. Если найдены persisted
experience names/ordinals, описать отдельный narrow compatibility reader
до удаления enum: старое Viewer → personal presentation, без выдачи role,
без удаления записей и без переписывания publisher. Такая находка меняет
file map и тесты; её нельзя скрыть под словом «UI-only».

Смена enum ordinals сама по себе безопасна только при отсутствии их storage
consumers. Не переименовывать `WorkspaceType.personal` в `creator` и
`PublisherType.user` в `creator`. Они описывают данные, не заголовок страницы.

### 16.2 Откат в ходе реализации

| Момент | Как вернуться |
|---|---|
| После baseline/archive | Оставить архив; app ещё исходный |
| После doc migration | Вернуть согласованную doc delta и ссылки; source snapshots неизменны |
| После preparation | Вернуть F02 и его тестовые изменения, если отказались от реализации |
| После cutover | Вернуть весь согласованный F01–F07 + consumers/tests набор |
| После retirement pointers | Вернуть pointers вместе с зависимыми ссылками, не отдельно один spec |
| После последующего независимого WIP | Обратный patch только PVR-01; никаких blanket reset/copy-over |

Архив остаётся даже после rollback: это полезный исторический снимок.
Данные аккаунтов, страницы, favorites/visits/plans и access records не
восстанавливаются из source archive и не очищаются при откате UI.

### 16.3 Возврат через месяцы

1. Открыть README/SYMBOLS/RESTORE и выбрать, что возвращается: идея блока,
   widget, layout либо отдельная продуктовая страница.
2. Найти оригинальный файл/версию/hash и сравнить с актуальным аналогом.
3. Перенести минимальный нужный код в текущие слои и adapters; восстановить
   тесты поведения с текущими API. Не подменять общий profile-файл старым.
4. Если возвращается отдельная страница/preview, оформить новое продуктовое
   решение и routes/capability checks под актуальные ADR.
5. Пройти текущие проверки. Архив сохраняет материал, но не отменяет
   накопившуюся разницу API, dependencies и архитектуры.

## 17. Что нельзя делать в ходе этого плана

- Удалять общий `profile_page.dart` или переносить весь Explore/Auth в архив.
- Назначать всем role Creator/verification ради исчезновения Viewer.
- Ограничивать Favorites, Visits или личные Scenario Creator verification.
- Превращать every personal profile в публичный searchable Creator card.
- Копировать старый `012d` profile/router поверх позднего Scenario/Settings кода.
- Исправлять каждый `viewer` string во всём monorepo без анализа его смысла.
- Молча принимать Draft security/Follow/minors/retention решения при переносе.
- Удалять meaningful tests вместо адаптации их пользовательских сценариев.
- Добавлять runtime feature flag для хранения Viewer-кода «на потом»:
  для возвращения предусмотрен архив, отдельная активная ветка UI не нужна.
- Объявлять Done по targeted analyze при непрошедшем обязательном полном gate.

## 18. Управление выполнением и текущий статус

Заходы после согласования bounded плана выполняются последовательно без
повторного запроса разрешения на каждую обычную правку. Принятие конкретного
ADR можно оформить вместе с согласованием его текста и implementation scope.
Отдельное решение нужно при реальном расширении scope, смене target/WIP
состава или действиях вроде commit/push, ранее не авторизованных.

| Заход | Фактический результат |
|---|---|
| 00 | ready: подтверждён target7275, baseline и WIP; [передача00](../verification/pvr-01/00-baseline.md) |
| 01 | ready: immutable archive снят до cutover; [передача01](../verification/pvr-01/01-archive.md) |
| 02 | ready: конкретный ADR0021 Accepted пользователем; [передача02](../verification/pvr-01/02-decision.md) |
| 03 | ready: общие правила/VP IDs перенесены без повышения Draft maturity; [передача03](../verification/pvr-01/03-spec-migration.md) |
| 04 | ready: display/access preparation; [передача04](../verification/pvr-01/04-presentation-access.md) |
| 05 | ready в bounded UI scope: единый Creator, прежние actions/guards; [передача05](../verification/pvr-01/05-unified-ui.md) |
| 06 | not_ready: Saved account isolation и behavioral evidence gaps; [передача06](../verification/pvr-01/06-regression.md) |
| 07 | ready только docs/archive: retired pointers, selective restore; не закрывает06; [передача07](../verification/pvr-01/07-retirement-restore.md) |
| 08 | not_ready для итоговой приёмки: actual gates и PVR-AC verdict в [передаче08](../verification/pvr-01/08-final-gates.md) |

Исходный пакет заданий в §19 — инструкции, не evidence исполнения.
Единый UI и сохранённый архив не означают выполнение всей A/U матрицы.
Открыты A12 (Favorites storage/API не scoped userId), A01 auth round-trip,
U14 реальная связка workspace switch/existing draft publisher, единая
двухаккаунтная fixture §10.3 и оставшиеся UI reopen/loading/error/back cases.
Future AccountStatus остаётся docs-only Draft. Ни новый title, ни зелёный
suite не подтверждают отсутствующие сценарии автоматически.

Итог PVR-01: **In progress, не Done**. Favorites isolation требует отдельно
согласованного bounded scope и policy владельца старого общего storage key;
эта миграция не добавляется молча в UI retirement. Полный verdict критериев
§15 и локальные gates — в отчёте08; device/cloud/production не заявляются.

## 19. Готовые задания для других агентов

[Инструкция и девять отдельных заданий](viewer-profile-retirement-handoffs/README.md).
Каждый файл содержит контекст без истории чата, входные отчёты, файловый scope,
действия, проверки, критерии и требования к передаче следующему исполнителю.

Последовательность:

1. [00 — база](viewer-profile-retirement-handoffs/00-baseline.md).
2. [01 — архив](viewer-profile-retirement-handoffs/01-archive.md).
3. [02 — ADR](viewer-profile-retirement-handoffs/02-decision.md).
4. [03 — перенос спецификаций](viewer-profile-retirement-handoffs/03-spec-migration.md).
5. [04 — display/access](viewer-profile-retirement-handoffs/04-presentation-access.md).
6. [05 — единый UI](viewer-profile-retirement-handoffs/05-unified-ui.md).
7. [06 — регрессия](viewer-profile-retirement-handoffs/06-regression.md).
8. [07 — retirement/restore](viewer-profile-retirement-handoffs/07-retirement-restore.md).
9. [08 — финальные gates](viewer-profile-retirement-handoffs/08-final-gates.md).

Заходы исполняются последовательно на подтверждённой базе. Следующий агент
проверяет отдельный отчёт предыдущего и фактические файлы. Краткий индекс
в `docs/verification/PVR_01_VERIFICATION.md` не заменяет evidence.
Каждый исполнитель ограничивается своим заданием. Новые чаты/агенты
подготовкой этого пакета не создаются и сообщения им не отправляются.
