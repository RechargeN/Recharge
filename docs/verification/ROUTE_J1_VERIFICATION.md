# J1 Route storage, sync and safe GPX — проверка, 2026-10-20

Checkout: изолированный worktree `.claude/worktrees/recharge-j1-route`, detached
на `codex/recharge-integration` `b23cb99` (после I3); J1 — незакоммиченные
изменения поверх. Коммита, push и deploy нет. Спецификация:
[ROUTE_J1_STORAGE_SYNC_GPX_SLICE_SPEC.md](../product/route/ROUTE_J1_STORAGE_SYNC_GPX_SLICE_SPEC.md).

Toolchain: Node 22.23.2, npm 10.9.8, Temurin 21.0.12+8, Flutter 3.44.9
(`verify:toolchain` зелёный). Всё ниже — локальный PC-host Emulator, не
устройство, не hosted CI и не production.

## Покрытие обязательных проверок

| # | Проверка | Где |
|---|---|---|
| 1 | Single/multi-segment GPX, round trip через каноническую модель | `route_j1_gpx_safety_test.dart` (import, canonical identity), `route_j1_client_test.dart` (сервер → второе устройство, canonical JSON равен) |
| 2 | XXE file/network, DTD/entity expansion, parameter entity, XInclude, PI, широкая структура, глубина, огромные text/extension, bytes/points, malformed/truncated | `route_j1_gpx_safety_test.dart`: под `IOOverrides`/`HttpOverrides`-ловушками, loopback-сервер — 0 соединений; Emulator: враждебные/oversized команды не меняют сохранённый Route (canonical digest равен) |
| 3 | Границы каждого лимита (ровно / +1) | mobile: 5 MiB, 200 000 точек, 1 000 000 событий, глубина 64, 32 атрибута, 2048 символов атрибута, 10 000 символов текста (и в extensions), 10 000 waypoints, 5 000 сегментов, 1 000 кандидатов, picker до чтения; backend: 10 000 точек, 120 сегментов, 100 anchors, 250 waypoints, тексты 120/1000/200, 204 800 байт, trim 2000 |
| 4 | Координаты вне диапазона, NaN/Infinity/экспонента/hex, elevation, порядок, gaps, версии | оба набора unit-тестов; explicit gap сохраняется и считается в summary |
| 5 | XML escaping, запрещённые metadata/extensions не проходят import → persistence → export | safety-тест + Flutter-адаптеры (DTO и GPX без author/creator/time/extensions/routeId) |
| 6 | Privacy trim: края, удаление всего, gaps, summary, отсутствие исходных координат, нет fallback | `route_contract.test.ts`, Emulator trimmed view (декодированная геометрия и waypoints), Flutter: экспорт из view без 7 удалённых точек, `privacy_trim_empty` без экспорта |
| 7 | Два клиента: edit/edit, edit/delete, trim/edit в обоих порядках | Emulator service matrix и два реальных Flutter-клиента одного владельца |
| 8 | Потерянный ответ, прерванный import, перезапуск, offline, refresh, повтор | Flutter-адаптеры: lost import + reboot → 1 Route; повтор intent — no-op; изменённый — `idempotency_conflict`; offline + reboot + refresh |
| 9 | Logout/login другим пользователем | чужая geometry/очередь не видны и не отправляются; forged `ownerContext` → `owner_changed`; чужой `get` → `null` |
| 10 | Реальные Flutter adapters против Emulator, существующий preview/apply/export | `route_j1_client_test.dart` через `RouteGpxTransferController` → `RouteCreateCoordinator.importGpx` → `RouteSyncClient` → `exportTrimmed` |
| 11 | Quick Plan/Scenario не меняются, нет внешних сетевых обращений | digest Catalog/Content/Quick Plan/Scenario в `after()`; HTTP-клиент Flutter-теста пропускает только `127.0.0.1:5001`; routing-порт бросает при вызове |

## Прогоны

- Группа `route-j1` (финальный прогон после исправлений): 9/9 pass, включая
  реальные Flutter-адаптеры; cleanup: routes/receipts пусты, Auth-пользователи
  удалены, Identity/flags очищены.
- Ранние прогоны группы были красными и исправлены: порядок ключей в
  ожидании теста; отсутствовал callable в mobile allowlist; ожидание числа
  `trkpt` (общие точки соседних сегментов пишутся один раз — 15 точек view,
  13 `trkpt`).
- Backend gates: toolchain, format, lint, typecheck, unit 757/757, contract,
  r1 integration, stand, manifest, persistence layout, r1 layout/config/exports,
  audit policy, generated, reproducibility — зелёные. `test:emulator:runner`
  сначала красный (нет named-скрипта группы) → исправлено, 7/7.
- Boundary self-test и boundary зелёные; inventory был stale → перегенерирован,
  `--check-output` зелёный; `git diff --check` чистый; api_contracts зелёный.
- Flutter: `flutter analyze` 0 issues; `flutter test` 1704 passed / 74 skipped
  (новый skip — backend-local J1 вне Emulator-группы).
- После финальной правки (очистка неиспользуемых ID-маппингов журнала) все
  gates выше повторены на финальном снапшоте и зелёные.
- Полный Emulator-набор в одной сессии на финальном снапшоте (2026-10-20
  14:49–15:15 UTC, логи `%TEMP%/recharge-emulator-tests-RORljT`): 18/18 групп,
  344 passed, 0 failed, 0 skipped, `complete: true`; `route-j1` 9/9; Scenario
  I2/I3, Quick Plan и остальные группы без регрессий. Предыдущий полный прогон
  (до финальной правки, `il1zS8`) тоже 344/344. Одна попытка между ними
  не стартовала: порты Emulator держал параллельный прогон другой сессии
  в этом же worktree; это не результат J1.

## Ограничения

- Только текущая ревизия + tombstone; истории ревизий нет.
- GPX-байты не уходят на сервер: парсинг только в mobile `RouteGpxInspector`.
  Серверная проверка provenance — по команде и зарегистрированному токену
  источника; содержимое более поздних `save` с `importedGpx` проверяется по
  lineage, а не по исходному файлу. `recordedGps` — `deviceDeclared`, не verified.
- `routed`/`generated` геометрия не хранится (`license_blocked`).
- Trim по радиусу от конечных точек; повторный вход в радиус не вырезается. Диагностический признак не
  создаёт popup или дополнительного подтверждения; результат виден в preview.
- Не-геометрические детали Route (conditions, quality, media) не синхронизируются.
- Нет UI-входа: test entry `RECHARGE_TEST_ROUTE_SYNC` и адаптеры.
- Device, hosted CI, retention/DSR и production — не проверены.

## 2026-10-21 common closure

Task30–32 shared validation and privacy repairs: [common evidence](T3_I3_J1_COMMON_VERIFICATION.md).
Bounded Review/owner acceptance boundary retained; historical results above
are not substituted for the final common-version run.
