# RECHARGE — Scenario Fuel Cleanup Slice Specification

Версия: v1.0 (2026-08-04).

Статус: **Done**.

Slice: **SCN-FUEL-CLEANUP-01 — remove fuel inputs and inferred fuel cost from
Scenario**.

## 1. Решение

Scenario поддерживает `Own car` как способ передвижения, но не спрашивает тип
топлива, расход или цену за литр и не рассчитывает стоимость топлива. Время,
расстояние, ручной locked leg и явно введённый `travel_extra` сохраняются.

Отдельного fuel-type enum в runtime до slice не существовало. Удаляются:

- `includeFuelInBudget`;
- `litresPer100Km`;
- `fuelPricePerLitre`;
- автоматический cost component `fuel`;
- поля `Consumption`, `Fuel price` и переключатель fuel budget в Create UI.

## 2. Границы

Slice не меняет Route, Quick Plan, AI generation, official/static transport
snapshot, Recheck/Replace, publication, live providers или booking. Он не
добавляет внешний API, Firebase, сеть или платный сервис.

## 3. Runtime и persistence

1. Новый Scenario по-прежнему допускает car/walking/transit и использует car
   как текущий primary default.
2. `ScenarioVehicleProfileDraft` сохраняет только нейтральные vehicle metadata:
   enabled, optional label и passenger seats. Fuel-полей в canonical runtime
   больше нет.
3. Manual car leg хранит только время, расстояние и optional explicit
   `travel_extra`; стоимость из расстояния автоматически не выводится.
4. Mapper принимает старый JSON с fuel-ключами как известный legacy payload,
   игнорирует их и не записывает обратно.
5. Legacy derived component с exact code `fuel` удаляется при чтении и перед
   записью. Остальные cost components, включая `travel_extra`, сохраняются.
6. Scenario schema остаётся v2: удалённые поля были optional, отсутствие
   backward-readable для старого mapper, а текущий mapper терпим к старым
   неизвестным ключам.

## 4. UX acceptance

- `Own car` доступен как primary/allowed travel mode;
- нет `Own car profile`, `Consumption`, `L/100 km`, `Fuel price`, `€/L` и
  `Include estimated fuel in budget`;
- ручные duration/distance/extra cost работают как раньше;
- интерфейс не показывает legacy fuel estimate после открытия старого draft;
- никакой fuel-настройки нет в скрытом жесте, secondary sheet или Review.

## 5. Migration и rollback

Миграция выполняется консервативно при чтении без отдельной destructive write:
старый документ остаётся читаемым, а нормализованный runtime не содержит fuel.
При следующем обычном сохранении устаревшие fuel-ключи и derived component не
возвращаются. Это удаление только вычисляемой оценки, не booking/payment fact.

Rollback к старому клиенту безопасен: отсутствующие optional fuel-ключи дают
его прежние defaults и не мешают читать Scenario. Откат кода не требует
очистки drafts/cache и не удаляет Scenario, stops, legs, time или distance.

## 6. Tests и Done

- domain/application: car leg без extra cost имеет пустой cost и никогда не
  создаёт `fuel`; explicit `travel_extra` сохраняется;
- mapper: legacy fuel keys/component читаются, отбрасываются и не появляются в
  normalized JSON;
- widget: car остаётся, все fuel controls отсутствуют;
- полный `flutter analyze`;
- полный последовательный `flutter test --concurrency=1`;
- boundary gate;
- `git diff --check`.

Статус меняется на Done только после всех четырёх зелёных gates и синхронизации
`SCENARIO_BUILDER_SPEC.md`, `LAUNCH_STATUS.md` и `AGENTS.md`.

## 7. Evidence

Завершено 2026-08-04:

- targeted fuel cleanup set — 15 tests passed;
- `flutter analyze` — 0 issues;
- полный `flutter test --concurrency=1` — 590 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions, новых
  нарушений нет;
- `git diff --check` — passed, только platform line-ending warnings.
