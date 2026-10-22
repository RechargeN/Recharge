# J2 Route publication — проверка, 2026-10-21

Checkout: отдельный worktree `.claude/worktrees/recharge-j2-route-pub`, локальная
ветка `claude/j2-route-publication` от `codex/recharge-integration` `b4368e0`
(32/J1). Работа Codex не затронута. Push и deploy нет. Контракт:
[RTE-PUB-01](../product/route/ROUTE_J2_PUBLICATION_BCK11_AMENDMENT.md) (Accepted).

Toolchain: Node 22.23.2, Temurin 21.0.12+8, Flutter из `C:\src\flutter`. Всё
ниже — локальный PC-host Emulator, не устройство, не hosted CI и не production.

## Покрытие решений

| Решение | Проверка |
|---|---|
| RP-01 immutable snapshot, CAS, hash, автор | Emulator 5: stale revision → `revision_conflict`; одна ревизия → один снимок; поздний J1 save не меняет снимок; чужой пользователь не создаёт draft; подделанное распределение отклоняется на submit; опубликован заголовок ревизии, а не поздняя правка |
| RP-02 trimmed geometry, recorded GPS ≥ 200 м | unit 1–2; Emulator 4: без trim и с 199 м → `privacy_trim_required`, 200/200 → снимок; waypoint у скрытого старта удалён; публичный старт ≠ реальный |
| RP-03/§5 allowlist | unit 1, 5: нет anchors, trim-радиусов, provenance, `note`; любое лишнее поле → отказ; Emulator 1, 8: Feed/Map/Details/exact read без приватных маркеров |
| RP-04 personal или Page | unit 6; Emulator 2: Page публикует, доверие у Page своё; mobile unit: publisher из active workspace фиксируется один раз |
| RP-06 модерация и доверие | Emulator 1–3: первая — `under_review`; после approve следующая — `approved_for_publication` с `policyDecisionId` одобрения; снятие автором не влияет; staff `restrict` и `reject` с классом причины снимают доверие; чистая ручная модерация возвращает; reject без класса и approve с классом → `invalid_contract` |
| RP-07 direct и gaps | unit 3 |
| RP-10 категория `route` | unit 6: пара без `route` в applicableTypes → `route.category` |
| RP-11 delete | Emulator 6: pending и published → `publication_active`; после withdraw delete стирает геометрию снимков (hash остаётся), activate прежней ревизии отклоняется |
| RP-12 B превью | unit 4: детерминировано, ≤ 256 точек, только точки trimmed-трека, концы сегментов сохранены; Emulator 1: превью в карточке и Map leaf, полный трек только в Details |
| RP-13 фильтры | unit 7: text/category/geo применяются, price/time → `route_filter_inapplicable` |
| RP-16 флаги | Emulator 7: `route.publication` выключен → `feature_disabled` без записи; Catalog без `RECHARGE_TEST_ROUTE_CATALOG` → `type_disabled` |
| Нет Scenario/Quick Plan/RouteMode | digest Scenario и Quick Plan в `after()` группы; снимки без `RouteMode`/`scenario`/`stops` |
| Реальные Flutter-адаптеры | Emulator 8: GPX preview/apply → J1 `importRoute` → контроллер J2: trim, `distribute`, Content draft, submit (автоодобрение заработанным доверием), publish; Catalog показывает Route с превью; только loopback |

## Прогоны

- Группа `route-j2`: 8/8 pass, включая реальные Flutter-адаптеры; cleanup:
  Route, снимки, Content, Media, Moderation, trust, Catalog и флаги удалены,
  Auth-пользователь Flutter удалён, digest Scenario/Quick Plan не изменился.
- Полный Emulator-набор одной сессией: 21/21 групп PASS, rc 0; сумма `# pass`
  по логам групп — 750, `# fail` — 0, строк `not ok` нет.
- Backend: typecheck, lint, format:check, unit 787/787, `verify-content-persistence-layout`,
  `verify-execution-manifest`, `verify-r1-exports`, тесты раннера групп (7/7) — зелёные.
- Mobile: `flutter analyze` — no issues; `flutter test` — 1765 pass, 79 skip
  (backend_local и прочие тесты, которые запускает Emulator-раннер), rc 0;
  новые unit-тесты контроллера и guard — 12/12.
- Boundary gate — passed (0 нарушений, 71 существующая suppression); scoped
  `git diff --check` — passed.
- Ранние красные прогоны и исправления: закреплённые тесты реестра типов
  ожидали `route` недоступным (обновлены вместе с ревизией реестра v10);
  ожидание отказа на createDraft вместо submit (черновик Content намеренно
  создаётся без полной валидации); Flutter-сессия создаёт свою учётку, поэтому
  сценарий 8 сам верифицирует Creator и даёт ему заработать доверие; prettier
  случайно переформатировал манифест вне своей области — файл восстановлен из
  HEAD и изменён точечно.

## Не проверено

Устройство Android/iOS, hosted CI, cloud и production; mobile Discover/Details
для Route (отдельный DTL-slice по RP-15, см. §9 контракта).

## Приёмка

Владелец принял J2 в local/Emulator объёме 2026-10-22, без push и deploy.

## Интеграция в `codex/recharge-integration` (2026-10-22)

По поручению владельца J2 влит в локальную `codex/recharge-integration` после
того, как Codex закончил: ветка не менялась с `b4368e0` (база J2), её worktree
был чистым, свежих изменений и процессов Codex в нём не было. Слияние —
fast-forward до `5d364f3`, без push.

Гейты в checkout интеграционной ветки на `5d364f3`: build, typecheck, lint,
format:check, unit 787/787, persistence layout, execution manifest, r1
exports, тесты раннера, boundary gate, `flutter analyze` (no issues),
`flutter test` (1765 pass, 79 skip) — зелёные.

Полный Emulator-набор: 19/21 групп PASS. Две группы упали по времени, когда
машину параллельно нагружали игра (`eu4`, Steam) и другая сессия Claude: все
группы шли в 1,5–3 раза медленнее, `booking` прошёл все тесты, но превысил
лимит группы 240 с (`timedOut=true`), Flutter-клиент `scenario-i2` не дождался
ответа callable за 82 с. Отдельный перезапуск на том же коммите: `scenario-i2`
PASS (17/17, 105 с), `booking` PASS (62/62, 211 с). Код Scenario, Quick Plan и
Booking в J2 не менялся.

## Закрытие J2 (2026-10-22)

Добавлено: typed publisher в черновике Route (новый Route-блок берёт его из
active workspace; маппер, Create-контроллер и публикация; unit-тесты), stand
seed `route`, `stand-j2-gate.mjs` с самопроверками (3/3) и UI stand test
тестовой страницы.

Финальный прогон одной сессией в checkout `codex/recharge-integration` на
`75fd5c4` (машина занята меньше, `FUNCTIONS_DISCOVERY_TIMEOUT=120`):

- build, typecheck, lint, format:check, unit 787/787, persistence layout,
  execution manifest, r1 exports, тесты раннера, boundary gate — зелёные;
- `flutter analyze` — no issues; `flutter test` — 1768 pass, 80 skip, rc 0;
- полный Emulator-набор — 21/21 групп PASS, rc 0; сумма `# pass` 750,
  `# fail` 0, строк `not ok` нет;
- `stand-j2-gate.mjs --yes` — пройден: чистый, прерванный после
  `distribute` и возобновлённый, повторный seed с равными digest; UI stand
  test 1/1 (Save → hide ends → Prepare → cover → Submit с автоодобрением →
  Publish → Hide, без приватных маркеров в опубликованной ревизии);
  проверенная остановка и очистка stand.

Первый запуск stand-gate остановился на старте stand: Functions Emulator не
загрузил код за 10 с по умолчанию на перегруженной машине (Android-эмулятор,
Steam); с `FUNCTIONS_DISCOVERY_TIMEOUT=120` прошёл. Это отмечено в README.
