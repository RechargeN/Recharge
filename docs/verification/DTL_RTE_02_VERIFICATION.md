# DTL-RTE-02 Route из Catalog в Discover/Details — проверка, 2026-10-22

Checkout: worktree `.claude/worktrees/recharge-j2-route-pub`, локальная ветка
`claude/j2-route-publication` на `a568b49` (= локальная
`codex/recharge-integration`, J2 Done) плюс незакоммиченные изменения slice:
25 путей кода и тестов (mobile, stand, stand-gate) и документы. Все прогоны
ниже — на этом состоянии кода; после них менялись только документы
(этот файл, LAUNCH_STATUS, AGENTS.md, §7 spec, ссылка в J2 evidence). Commit, push и deploy нет по поручению
владельца. Spec:
[DTL-RTE-02](../product/discover/DTL_RTE_02_ROUTE_CATALOG_DISCOVER_SLICE_SPEC.md)
v0.2, RD-01…RD-12 утверждены 2026-10-22.

Toolchain: Node 22.23.2, Temurin 21.0.12+8, Flutter из `C:\src\flutter`. Всё
ниже — локальный PC-host Emulator и Flutter-тесты на хосте, не устройство,
не hosted CI и не production.

## Покрытие решений и критериев

| Решение / критерий | Проверка |
|---|---|
| RD-01, RD-10, RD-AC-04 модель и allowlist | unit `route_catalog_discover_test.dart`: wire-парсер принимает карточку и Details J2, unit отклоняет `anchors`, `privacyTrim`, `provenance`, `bounds`, `durationSeconds`, `note` у waypoint, `track` в карточке и превью > 256 точек; парсер (код) также отклоняет `ownerId`, `waypointId`, Details без `track` и неизвестный тип publisher; id publisher в модель не попадает; stand: после публикации в карточке и Details нет приватных маркеров |
| RD-03, RD-AC-02 сегменты | unit: одна линия на сегмент, direct пунктиром, разрыв не склеен; stand: Details Page-route содержит 2 сегмента трека → 2 линии, карточка и Map leaf несут только превью |
| RD-04 карточка и Map | unit: подписи расстояния и «прямых участков: N»; stand: карточка в результатах Search, Map leaf с превью |
| RD-05 когда в ленте | unit репозитория: дефолтный запрос без `route` в `typeIds`, запрос с текстом — с ним, с выключенным Route-входом — без него; stand: дефолтная лента без Route, Search «walk» показывает personal и Page Route |
| RD-06, RD-AC-08 включение | define `RECHARGE_TEST_ROUTE_CATALOG` + те же четыре условия; без define stand-тест пропускается, а полный `flutter test` (локальный путь RTE-08 и DTL-RTE-01) зелёный |
| RD-07, RD-AC-05 актуальность | stand: `page-revise` → Details отдаёт `CATALOG_ROUTE_REVISION_CHANGED` → «Маршрут обновился»/«Обновить» → новое название; `page-withdraw` → lookup пустой, Route исчез из ленты; `page-restore` → снова в ленте с новой ревизией; unit: сброс snapshot после новой ревизии |
| RD-08, RD-AC-07 offline и restart | stand: новый runtime после restart снова открывает тот же Route из Catalog; guard выключен → «Нет связи»/«Повторить», старых данных нет |
| RD-09 действия | widget: у Catalog Route нет sticky-панели, карточек события, жалобы и «В Scenario»; «Открыть на карте» — в hero, «Сохранить» и «Поделиться» — в общем app bar renderer (отдельной проверкой нажатий не покрыты) |
| RD-11, RD-AC-06 publisher | widget и stand: «Автор» у personal, «Страница» у Page |
| RD-12, RD-AC-03 числа | widget и stand: у Page-route нет высот → строки «Набор высоты» нет; у personal есть; duration, bounds, сложности и покрытия нет нигде |
| RD-AC-09 границы | diff не трогает `features/create` и backend publication-код; новых aggregate, хранилищ и writer нет; boundary gate 0 нарушений |
| Stand seed | `verifyStandRoute`: доверие Page, Page-route в Catalog с publisher `page`, `gapCount` 1, `ascent` null; digest с меткой `seed-route-page` |

## Прогоны (одна версия, последовательно)

Скрипт гейтов идёт по шагам и пишет rc каждого шага сразу после него; итог
сверен с логами (`# fail`, `not ok`, `timedOut`), а не только с rc.

- Backend: build, typecheck, lint, format:check — rc 0; unit 787/787;
  stand unit (`stand_digest`, `stand_seed`) 22/22; persistence layout,
  execution manifest, r1 exports, тесты раннера групп, самопроверки
  `stand-j2-gate` — зелёные.
- Boundary gate: 671 Dart-файл, 0 нарушений, 71/71 существующих suppression.
- Mobile: `flutter pub get`, `flutter analyze` — no issues; `flutter test` —
  1780 pass, 81 skip (backend_local, включая новый stand-тест, запускаются
  раннером Emulator и stand-gate), rc 0. Новые unit/widget-тесты slice —
  12/12.
- Полный Emulator-набор (`npm run test:emulator`) одной сессией: 21/21 групп
  PASS, rc 0; сумма `# pass` по логам групп — 750, `# fail` — 0, строк
  `not ok` и `timedOut` нет. `route-j2` — 8/8 (108 с).
- `stand-j2-gate.mjs --yes` (`FUNCTIONS_DISCOVERY_TIMEOUT=120`) — пройден, rc 0:
  чистый seed (теперь с Page-route), прерванный после снимка и возобновлённый,
  повторный seed с равными digest; UI stand test публикации Route — 1/1;
  новый UI stand test «Route в Discover/Details» с defines
  `RECHARGE_TEST_DISCOVER_CATALOG` и `RECHARGE_TEST_ROUTE_CATALOG` — 1/1, без
  skip (82 с); инварианты base и Route после тестов сохранены; проверенная
  остановка и очистка stand.

## Ранние красные прогоны и исправления

- Stand-тест не находил текст Details: ленивый `ListView` не строил нижние
  секции — тело рисуется в `SingleChildScrollView`.
- На PC-хосте у integration binding нет platform view Google Maps
  (`MissingPluginException`), поэтому stand-тест рисует тело Details и
  проверяет линии через `buildRouteSegmentPolylines`; hero с картой проверен
  widget-тестом.
- Карточка Catalog требовала `contentId` в проекции — берётся из `ref`.
- `dart format` по каталогам задел 5 чужих файлов — они возвращены через
  `git checkout`, дальше форматировались только свои файлы.

## Не проверено

- Отдельный stand-сценарий «запоздалого ответа»: покрыт механизмом
  `FutureProvider` по id и unit-тестом сброса snapshot.
- Модераторское ограничение и удаление на stand отдельно не прогонялись: они
  дают тот же `excluded`/`absent`, что и снятие автором, — путь общий.
- Deep link `route/{contentId}` на устройстве.

Отдельно — **device**: Android/iOS (карта Google Maps, share, restart и
offline на телефоне) не проверялись. **Production**: hosted CI, cloud,
Firebase и deploy не входят в slice.

## Приёмка

Владелец принял DTL-RTE-02 в local/Emulator объёме 2026-10-22, без push и
deploy. По поручению владельца изменения закоммичены в локальную ветку
`claude/j2-route-publication` тремя коммитами поверх `a568b49`: `9818da1`
(mobile), `dbc95fa` (stand) и docs. Код в коммитах совпадает с проверенной
рабочей копией (`de3cc1c` — docs). Push нет.

## Интеграция в `codex/recharge-integration` (2026-10-22)

По поручению владельца DTL-RTE-02 влит в локальную `codex/recharge-integration`
после проверки, что Codex там не работает: worktree интеграции был чистым,
ветку после `a568b49` никто не менял, сборок, тестов и эмулятора Codex в нём
не было. Слияние — fast-forward `a568b49` → `de3cc1c`, без push.

Гейты в checkout интеграционной ветки на `de3cc1c` (0 изменённых путей),
последовательно одной сессией, `FUNCTIONS_DISCOVERY_TIMEOUT=120`:

- build, typecheck, lint, format:check — rc 0; unit 787/787; stand unit
  22/22; persistence layout, execution manifest, r1 exports, тесты раннера
  групп, самопроверки `stand-j2-gate` — зелёные;
- boundary gate — 0 нарушений;
- `flutter analyze` — no issues; `flutter test` — 1780 pass, 81 skip, rc 0;
- полный Emulator-набор — 21/21 групп PASS, rc 0; сумма `# pass` по логам
  групп 750, `# fail` 0, строк `not ok` и `timedOut` нет; `route-j2` 8/8;
- `stand-j2-gate.mjs --yes` — пройден: UI stand test публикации Route 1/1 и
  UI stand test «Route в Discover/Details» 1/1 без skip, инварианты после
  тестов сохранены, проверенная остановка и очистка stand.

После прогона worktree интеграции остался чистым. Запись этой перепроверки
— отдельный docs-коммит, тоже fast-forward в интеграцию.
