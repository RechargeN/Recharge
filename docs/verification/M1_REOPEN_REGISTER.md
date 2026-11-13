> **Текущее состояние 2026-10-15:** обязательные критерии принятого scope M1 закрыты, исключения приняты; первый локальный контур проверен. Исторический аудит и решения ниже сохранены. Полная приёмка 20 заходов остаётся отдельной.

# Release M1 и 20 заходов — реестр незакрытых критериев (заход 1)

Дата 2026-10-14. Ветка `claude/m1-reopen` от `ce6014a` (`codex/recharge-integration`).
Документ только фиксирует состояние, решения и карты файлов. Он **не подтверждает
выполнение** ни одного критерия и не меняет статусы. Учёт дефектов —
[M1_DEFECT_REGISTER.md](M1_DEFECT_REGISTER.md).

Итог на дату документа: **повторные локальные прогоны зелёные; полная приёмка
20 заходов и закрытие M1 не подтверждены.** Вердикт
[M1_ACCEPTANCE.md](../evidence/backend/m1/M1_ACCEPTANCE.md) остаётся evidence
runtime `e3710f6` и сохраняется без изменений как история.

## 0. Источники и evidence

| Что | Где |
|---|---|
| Критерий Release M1 | roadmap `RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md` §3.7 «Release M1 и Release M2» |
| Условия merge (Proposed) | roadmap §3.6 «Условия будущего merge в `main`» |
| Checklist и приёмка M1 | [M1_LOCAL_CONTOUR_CHECKLIST.md](M1_LOCAL_CONTOUR_CHECKLIST.md), [M1_ACCEPTANCE.md](../evidence/backend/m1/M1_ACCEPTANCE.md) |
| D1 | `docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md` §1, §8, §12, §15 |
| Совместимость Create → сервер | §5.7 амендментов D3.1–D3.4 и `packages/api_contracts/schema/content/v1/fixtures/{place,activity,rental,collection}_create_compat.json` |

Повторный прогон аудита 2026-10-13/14 на runtime `e3710f65ba595e14d4ebd578bcb208670eb81a1d`
(чистый worktree, локальная Windows-среда M1): `flutter analyze` 0 issues;
`flutter test` 1616 passed / 67 skipped / 0 failed; boundary 0 нарушений, 71/71;
inventory `--check-output` pass; `stand:acceptance` pass, digest
`d263cfb7…abbb42` равен M1; гейты B1 4/4, B2 3/3 (5/5 в каждом), E2 два клиента
1/1 и 1/1. Журналы вне Git, в scratchpad сессии аудита. Остальные гейты M1
(в том числе `test:emulator` 250/250) **не повторялись**: это историческое
evidence `e3710f6`. После любого runtime-изменения заходов 2–4 оно не
переносится на новый SHA.

## 1. Реестр критериев

Обязательность: **О** — обязателен по тексту захода или roadmap; **Р** —
обязательность зависит от решения владельца (§2); **В** — вне M1 по checklist §3
(само исключение — решение §2).

| ID | Критерий и источник | Обяз. | Evidence и SHA | Пробел | Закрывающий гейт |
|---|---|---|---|---|---|
| K-01 | Заход Р: единственная рабочая копия, правило общих файлов, судьба WIP, политика worktree | О (для Р) | IDP WIP `be17822` перенесён как `941f618`, сверка `e87883f` (`IDP_WIP_DISPOSITION_2026_10_12.md`); карта 27 пересечений в `C1_E2_CLOSURE_REVIEW.md` (`2529a54`) | решения владельца нет; roadmap §3.7 и BCK-02 называют содержание Р blocker | решение Р-01, Р-02 (§2) |
| K-02 | D1: Linux gate — EICAR, официальные базы, нативная сборка, cgroup (D1 §1, §8, §12) | О для D1; В для M1 | Windows-local гейт pass на `e3710f6`, EICAR «not run here»; GitHub run `38246774477` на `e87883f` 2026-10-12 — **failed**, стадия inspect: `clamd --version` → «Can't open/parse the config file /usr/local/etc/clamd.conf» | гейт красный; D1 §12/§15.8 и LAUNCH_STATUS не отражают запуск и падение | заход 2 |
| K-03 | B1 real FirebaseAuth и secure storage | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-04 | Map revisionRef и hide через настоящий controller | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-05 | CreatePage draft edit/save/cover и дальнейший Event lifecycle | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-06 | Совместимость Create → сервер, Place (D3.1 §5.7) | Р | закрыт заходом 3: runtime `4e82352`, тестовые исправления до `b91e819`; [evidence](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md) | readiness/поля отказа и корректные стендовые черновики проверены; пределы SHA описаны в evidence | заход 3 закрыт; финальные SHA-гейты — заходы 4–5 |
| K-07 | То же, Activity (D3.2 §5.7) | Р | закрыт заходом 3: runtime `4e82352`, тестовые исправления до `b91e819`; [evidence](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md) | readiness/поля отказа и корректные стендовые черновики проверены; пределы SHA описаны в evidence | заход 3 закрыт; финальные SHA-гейты — заходы 4–5 |
| K-08 | То же, Rental (D3.3 §5.7) | Р | закрыт заходом 3: runtime `4e82352`, тестовые исправления до `b91e819`; [evidence](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md) | readiness/поля отказа и корректные стендовые черновики проверены; пределы SHA описаны в evidence | заход 3 закрыт; финальные SHA-гейты — заходы 4–5 |
| K-09 | То же, Collection (D3.4 §5.7) | Р | закрыт заходом 3: runtime `4e82352`, тестовые исправления до `b91e819`; [evidence](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md) | readiness/поля отказа и корректные стендовые черновики проверены; пределы SHA описаны в evidence | заход 3 закрыт; финальные SHA-гейты — заходы 4–5 |
| K-10 | M1: «состав записан в плане файлов этапа до кода» (roadmap §3.7) | О | checklist §1: у большинства строк класс «восстановлено после реализации» | реконструкция не является планом до кода; одобрение выведено из общего указания | решение Р-03 |
| K-11 | Учёт P1/P2 и независимое ревью финального состава M1 | О | [реестр дефектов](M1_DEFECT_REGISTER.md), [независимое ревью](../evidence/backend/m1/M1_STAGE5_INDEPENDENT_REVIEW.md) на `7cb07fa` и финальных документах | закрыт в scope M1; DEF-05 вне M1 и DEF-07 P3 сохраняются | заход 5 |
| K-12 | M1: исключение терминального `revokeMembership` из клиентского M1 (checklist §3) | Р | backend-only тест `identity_publisher_authority.test.ts` | исключение не подтверждено явно | решение Р-04 |
| K-13 | M1: waiver трёх документов в diff-check (checklist §6) | Р | SHA-256 трёх blob совпали в 3c | waiver не подтверждён явно | решение Р-05 |
| K-14 | M1: исключение Linux gate D1 из M1 (checklist §3) | Р | — | исключение не подтверждено явно, а D1 по своей поправке без Linux не Done | решение Р-06 |
| K-15 | Binding rollback — B1, import rollback — отдельно D4.1 | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-16 | D4.1 имеет отдельное прямое human-основание и implementation/acceptance commits | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-17 | C1: «иной способ upload — сначала варианты и отдельное подтверждение» | О (процесс) | `uploadMediaBytesV1` описан в `apps/backend/README.md` §C1 | записи о вариантах и подтверждении до кода нет | решение Р-12 |
| K-18 | B2 Loading и mutation busy, три прогона по пять тестов | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |
| K-19 | Новый полный Emulator: 250 passed / 0 failed / 0 skipped, девять групп | О | финальный SHA `7cb07fa`; [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт в принятом локальном scope; пределы записаны в evidence | заходы 4–5 |

## 2. Решения владельца, нужные до заходов 2–5

Каждое решение принимается отдельно. Принятие решения **не подтверждает**
выполнение критерия.

| ID | Вопрос | Предложение | Влияет на |
|---|---|---|---|
| Р-01 | Канонический рабочий checkout мобильных этапов | интеграция — `codex/recharge-integration` в `C:/Users/User/.codex/worktrees/7275/Recharge`; каждый заход — своя ветка и worktree от неё, слияние обратно по одному; `Desktop/Recharge` (`be17822`) не используется для работ, пока владелец не решит иначе | K-01 |
| Р-02 | Правило общих файлов | `LAUNCH_STATUS.md`, `AGENTS.md`, `apps/backend/README.md`, `apps/mobile/lib/app/di/service_locator.dart`, `app_router.dart`, `create_controller.dart`, roadmap и checklist M1 правит только активный заход, указавший их в карте файлов; два захода одновременно один файл не меняют; слияние в интеграцию последовательно, three-way, без замены файлов | K-01 |
| Р-03 | Состав M1 §1 со строками «восстановлено после реализации» | принять как **реконструкцию**, явно так и называя; либо изменить критерий roadmap. Выдавать её за план до кода нельзя | K-10 |
| Р-04 | Исключение терминального `revokeMembership` | принять с backend-only evidence или потребовать owner-path второго участника | K-12 |
| Р-05 | Waiver трёх документов §6 | принять в текущей узкой форме | K-13 |
| Р-06 | Linux gate D1 в M1 | вариант А: M1 локальный, D1-Linux вне M1, но D1 не Done до зелёного Linux; вариант Б: M1 требует зелёный D1-Linux | K-02, K-14 |
| Р-07 | Независимое ревью для M1 | требование «из независимой проверки» есть только в условиях merge §3.6 (Proposed). Для M1 обязателен учёт «нет открытых P1/P2». Владелец решает: (а) M1 требует только учёт P1/P2 с доказательствами; (б) M1 дополнительно требует независимое ревью — тогда это записывается в roadmap §3.7 явно | K-11 |
| Р-08 | Шкала приоритетов | P1 — нарушает обязательный критерий M1, теряет данные, ослабляет authority/безопасность или даёт ложный зелёный гейт; P2 — неверное поведение в scope M1 с обходом или расхождение документа и факта в обязательном evidence; P3 — долг UX/документации вне обязательных критериев | K-11 |
| Р-09 | Целевое поведение Create → сервер для четырёх типов | серверные инварианты не ослабляются; форма показывает обязательные требования заранее; сохранение неполного черновика отделено от готовности к submit/publish; отказ сервера объясняется пользователю. **Ограничение:** по BCK-07 код нарушения клиенту не передаётся. Привязка к полям возможна либо клиентской проверкой тех же правил, либо изменением контракта BCK-07 (передача кодов) — это отдельное решение | K-06…K-09, заход 3 |
| Р-10 | Платформа для настоящих `firebase_auth` и secure storage (B1) | варианты: Android Emulator на этом ПК (AVD API 36 есть) через `adb reverse` с сохранением loopback-guard A1; Windows desktop, если плагины там поддерживаются. Способ соединения подтверждается до кода; guard A1 без отдельного решения не меняется | K-03 |
| Р-11 | Трактовка C3 «через mobile Create» | обязательна ли форма Create (UI) или достаточно черновика из `CreateRepository` | K-05 |
| Р-12 | Способ upload C1 (`uploadMediaBytesV1`) | явно принять задним числом как Emulator-only канал (не production) либо открыть замену | K-17 |
| Р-13 | Статус M1 в LAUNCH_STATUS до захода 5 | вернуть `Done` → `Review` сейчас, чтобы статус не утверждал неподтверждённое; результаты проверок сохраняются | статус |
| Р-14 | Push/CI для захода 2 | отдельное разрешение на push ветки и запуск `backend-d1-linux.yml` | заход 2 |

### 2.1 Принятые решения (владелец, 2026-10-14)

Гейт захода 1 пройден: решения ниже приняты. Ни одно из них не подтверждает
выполнение критерия.

| ID | Решение |
|---|---|
| Р-01 | Как предложено: интеграция в worktree 7275, каждый заход — своя ветка; `Desktop/Recharge` для работ не используется |
| Р-02 | Как предложено; слияния в интеграцию последовательно |
| Р-03 | Принято как реконструкция. Исключение из «плана до кода» записано в roadmap §3.7 (v1.33); хронология сохраняется |
| Р-04 | Принято. Терминальный `revokeMembership` — backend; обратимый отзыв доступа Page обязательно проверяется на клиенте |
| Р-05 | Принято только для трёх перечисленных документов с хешами и конкретными нарушениями; вне waiver diff-check зелёный |
| Р-06 | Вариант А: Linux-gate вне M1; D1 не Done до зелёного Linux; полная приёмка 20 заходов остаётся открытой |
| Р-07 | Вариант б: учёт P1/P2 и независимое ревью финального состава M1; вписано в roadmap §3.7 |
| Р-08 | Шкала принята в различении: P1 — блокирующий дефект; P2 — существенное нарушение критерия; P3 — неблокирующее улучшение |
| Р-09 | Как предложено. Неполный черновик сохраняется, если это разрешает контракт; готовность к submit/publish проверяется заранее |
| Р-10 | Android Emulator с `adb reverse`; соединение и сохранение loopback-ограничения подтверждаются до кода |
| Р-11 | Форма Create обязательна; тестовая страница критерий C3 не закрывает |
| Р-12 | `uploadMediaBytesV1` принят 2026-10-14, после реализации, только для Emulator; production-канал не утверждён |
| Р-13 | M1 возвращён в Review с перечнем открытых критериев |
| Р-14 | Push и CI — отдельное разрешение на каждый конкретный запуск |

Следствия для реестра: K-05 обязателен (Р-11); K-06…K-09 обязательны в
форме Р-09; K-10, K-12, K-13, K-14, K-17 закрыты решениями как «принято», не
как «исправлено»; K-02 остаётся обязательным для D1 и вне M1.

## 3. Независимое ревью: применимость

- Roadmap §3.7, критерий Release M1: «нет открытых P1/P2». Слова «независимая
  проверка» в нём нет.
- Roadmap §3.6, условия merge в `main` (статус **Proposed**): «нет открытых
  P1/P2 из независимой проверки».
- Требование merge в M1 молча не переносится. До решения Р-07 обязательным для
  M1 считается учёт P1/P2 с доказательством закрытия; независимое ревью —
  обязательно для merge, если условия §3.6 будут приняты.

## 4. Рабочая копия (факты, без операций)

- `Desktop/Recharge`: detached `be17822`, AGENTS.md версии 2026-10-01; от
  интеграции отличается на 1512 файлов. Untracked `.claude/skills/`.
- Интеграция: `codex/recharge-integration` @ `ce6014a` в worktree 7275, на 15
  коммитов впереди `origin` (D3.3, D3.4, D4, M1 — только локально).
- Worktree: 21. Ветки M1 (`claude/m1-1-contract`, `claude/m1-2-page-reliability`,
  `claude/m1-3-import-rollback`) — предки интеграции.
- Stash `8d18535` («preserve integration WIP … 2026-10-12»): 9 из 10 файлов
  побайтно равны версиям `8a6c2de` (до D3.1), `LAUNCH_STATUS.md` по строкам
  статуса равен `9de403d`; untracked-часть пуста. По содержимому это откат
  D3.1/D3.2 к прежним версиям, уникальной работы не найдено. Решение по stash,
  удаление worktree и push — **отдельные операции**, этим заходом не
  выполняются.

## 5. Карты файлов следующих заходов (предварительные)

Каждая карта подтверждается перед кодом своего захода; пути проверены на
`ce6014a`.

**Заход 2 — D1 Linux.**
`apps/backend/scripts/media-tools-linux.mjs` (вызов `clamd --version`, строка
132), `apps/backend/scripts/media-tools-linux.test.mjs`; при необходимости
`apps/backend/scripts/stand-d1-linux-gate.mjs`, `apps/backend/ci/d1-linux-stage.json`,
`.github/workflows/backend-d1-linux.yml`; документы
`docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md` §12, §15.8 и новый
`docs/evidence/backend/d1/D1_LINUX_GATE.md`; строка D1 в
`docs/architecture/LAUNCH_STATUS.md`. Запуск CI — после Р-14.

**Заход 3 — Create и сервер, четыре типа.**
Mobile: `apps/mobile/lib/features/create/domain/usecases/validate_{place,activity,rental,collection}_draft_usecase.dart`,
`build_{place,activity,rental,collection}_content_body.dart`,
контроллеры `apps/mobile/lib/features/create/application/{place,activity,rental}_publication_controller.dart`,
`collection_content_publication_controller.dart`, конфиги и блоки формы Create
соответствующих типов (уточнить), тесты unit/widget. Контракт:
`packages/api_contracts/schema/content/v1/fixtures/*_create_compat.json`.
Документы: §5.7 четырёх амендментов. Изменение BCK-07 (передача кодов) — только
по отдельному решению Р-09.

**Заход 4 — B1, E2, C3.**
B1: `apps/mobile/lib/features/booking/data/booking_firebase_auth_emulator.dart`,
`booking_functions_transport.dart` (только чтение, если дефекта нет), новые
тесты под выбранную платформу (Р-10), `apps/backend/scripts/stand-mobile-gate.mjs`.
E2: `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart`,
`apps/mobile/lib/features/discover/data/repositories/catalog_discover_repository.dart`,
`apps/mobile/test/backend_local/discover_catalog_stand_test.dart`.
C3: тест прохождения формы Create Event на стенде; `stand-c3-gate.mjs`.
Отчёты — `docs/evidence/backend/m1/`.

**Заход 5 — приёмка M1.**
`docs/verification/M1_DEFECT_REGISTER.md`, `M1_LOCAL_CONTOUR_CHECKLIST.md`,
`docs/evidence/backend/m1/M1_ACCEPTANCE.md` (новая приёмка отдельным
документом или разделом; прежняя сохраняется), roadmap §3.7 (если меняется
требование), `LAUNCH_STATUS.md`.

## 6. Rollback

Только документальные изменения этого захода: `git revert` коммита захода 1.
Ни код, ни статусы, ни ветки, ни stash им не меняются.

## 7. Ход заходов

- Заход 1 — закрыт 2026-10-14 (решения Р-01…Р-14).
- Заход 2 — закрыт 2026-10-14: K-02 закрыт evidence — Linux gate D1 зелёный,
  run `38567123384` на `83e05cd`, включая EICAR напрямую и через Storage
  ([D1_LINUX_GATE.md](../evidence/backend/d1/D1_LINUX_GATE.md)). Дефекты DEF-01,
  DEF-02, DEF-08, DEF-10, DEF-11 закрыты; DEF-09 принят владельцем. D1 Done —
  принято владельцем 2026-10-14.

## Заходы 4–5: текущая сверка

Все обязательные runtime gates повторены на `7cb07fa`; прежнее `250/250` на `e3710f6` — только история. 67 пропущенных общим suite тестов имеют конкретные отдельные успешные прогоны. K-11 закрыт независимым ревью финального состава без открытых P1/P2 в scope M1; текущая приёмка записана в M1_ACCEPTANCE. Принятые решения §2.1 сохраняются; полная приёмка всех 20 заходов не следует из M1 автоматически.
