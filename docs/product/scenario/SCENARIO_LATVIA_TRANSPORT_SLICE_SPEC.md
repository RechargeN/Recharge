# RECHARGE — Scenario Latvia Transport Foundation

Версия: 1.0

Статус: **Approved**

Дата: 2026-07-31

Slice: **SCN-SB-04**

## 1. Решение

Scenario поддерживает планирование по всей Латвии. Рига является первым
рынком проверки качества, но не ограничением domain model, draft schema или
интерфейса.

На текущем этапе общественный транспорт использует только **плановое
расписание**. Интерфейс обязан показывать пометку
`Плановое расписание · не live`. Статическое GTFS-расписание, ручной ввод и
расчётное значение нельзя называть live, фактическим прибытием или гарантией
рейса.

Личный автомобиль является полноценным основным режимом Scenario. Он не
считается fallback общественного транспорта и доступен наравне с walking,
bicycle, taxi и transit.

## 2. Продуктовые границы

1. `Route != Scenario != Quick Plan`.
2. Перемещение между соседними остановками является Scenario leg.
3. Междугородний автобус или поезд может быть отдельным
   `plannedTransport` item, если он занимает самостоятельный временной блок.
4. Автомобильная поездка не создаёт Route aggregate, GPX, anchors или
   elevation.
5. Неизвестное время, расстояние или стоимость не преобразуются в ноль.
6. Сбой или отсутствие источника расписания не блокирует личный draft:
   пользователь может внести данные вручную.
7. Данные расписания являются snapshot. Они не синхронизируются молча после
   сохранения Scenario.
8. Автоматическая покупка билетов, бронирование и live vehicle positions не
   входят в slice.
9. Никакие API keys, Firebase или платные provider integrations не добавляются.

## 3. География и источники

Market по умолчанию — `LV`, timezone по умолчанию — `Europe/Riga`, валюта —
`EUR`. Эти значения приходят из config и не зашиваются в бизнес-логику
конкретного города.

Будущие бесплатные read-only источники:

- региональные и междугородние автобусы ATD в GTFS;
- внутренние поезда в GTFS;
- муниципальные feeds, подключаемые по отдельным операторам.

SCN-SB-04 создаёт versioned domain contract, local/manual runtime и UI.
Автоматическая загрузка и обновление официальных GTFS выполняются отдельным
slice `SCN-LV-DATA-01` после data-source review. До него приложение не
притворяется, что показывает полный национальный feed.

## 4. Транспортные предпочтения

В контексте Scenario пользователь задаёт:

- основной режим;
- разрешённые режимы;
- профиль личного автомобиля, если он используется.

Начальные значения для нового Scenario:

- основной режим — `car`;
- разрешены `car`, `walking` и `transit`;
- плановое расписание включено;
- live logistics выключен.

Пользователь может отключить автомобиль и выбрать другой основной режим.
Основной режим обязан входить в множество разрешённых режимов.

### 4.1 Профиль личного автомобиля

Минимальный local draft:

- `enabled`;
- необязательное название автомобиля;
- расход топлива в литрах на 100 км;
- цена топлива за литр в display currency;
- необязательное количество доступных пассажирских мест;
- включать ли расчёт топлива в бюджет.

Значения расхода и цены не заполняются выдуманными default. Пока пользователь
не указал оба значения и расстояние leg неизвестно, топливная стоимость
остаётся unknown.

Парковка, платный въезд, паром и другие расходы вводятся как явная стоимость
leg или отдельный time/cost block. Они не смешиваются с ценой топлива.

## 5. Leg и честность данных

Поддерживаемые источники leg:

| Source | Значение | UI label |
|---|---|---|
| `schedule` | статическое плановое расписание | `Плановое расписание · не live` |
| `manual` | значение ввёл пользователь | `Введено вручную` |
| `estimate` | локальная или provider-оценка | `Расчётное время` |
| `provider` | будущий approved routing provider | label по контракту provider |
| `unknown` | значение отсутствует | `Время в пути не указано` |

`provider` сам по себе не означает live. Фактическое значение может быть
названо live только после отдельного Approved provider contract с realtime
semantics. SCN-SB-04 такой capability не включает.

Leg хранит:

- постоянный id;
- day/from/to ids;
- travel mode;
- source и status;
- duration и distance, если известны;
- явную стоимость;
- `updatedAtUtc`;
- для schedule — provenance и freshness;
- warning code;
- manual lock.

### 5.1 Актуальность расписания

Schedule snapshot содержит:

- provider/feed code;
- service date;
- feed update timestamp;
- retrieval timestamp;
- carrier;
- service/route label;
- origin/destination labels;
- planned departure/arrival;
- source URL, если disclosure разрешён.

Состояния:

- `current` — snapshot применим к выбранной service date;
- `stale` — feed или service date устарели;
- `unknown` — timestamp отсутствует;
- `notApplicable` — leg не использует расписание.

Stale snapshot сохраняется и показывается с предупреждением. Он не
перезаписывается нулём и не удаляется.

## 6. Planned transport item

Пользователь может добавить отдельный блок:

- автобус;
- поезд;
- трамвай/троллейбус;
- паром;
- самолёт;
- другой транспорт.

В SCN-SB-04 автоматически поддерживается только ручной snapshot. Поля:

- kind;
- carrier;
- service label;
- departure и arrival;
- start/end location;
- duration;
- стоимость;
- schedule provenance/freshness.

Для dated Scenario departure/arrival относятся к выбранной дате. Для template
Scenario допускается предпочтительное локальное время, но Review показывает
`Выберите дату, чтобы проверить расписание`.

## 7. Application rules

1. Изменение основного режима увеличивает revision.
2. Отключение режима, используемого существующим leg, не удаляет leg и создаёт
   warning.
3. Добавление/удаление/reorder item инвалидирует только соседние derived legs.
4. Manual locked leg не перезаписывается.
5. Schedule snapshot применяется только к совпадающим day/from/to/service date.
6. Для автомобильного leg можно указать duration/distance/cost вручную.
7. Топливная оценка вычисляется только при известных distance, consumption и
   fuel price:

   `fuelCost = distanceKm / 100 × litresPer100Km × pricePerLitre`

8. Итоги отдельно показывают:
   - activity;
   - private/local travel;
   - planned transport;
   - waiting;
   - known cost;
   - unresolved values.
9. Save personal Scenario разрешён с unknown legs; Start показывает blocking
   issue для критического dated gap.
10. UI не выполняет перечисленные расчёты.

## 8. UX

### Context

Блок `Как передвигаемся`:

- choice основного транспорта;
- multi-select дополнительных режимов;
- раскрываемый профиль автомобиля;
- пояснение, что режим можно менять для каждого перехода.

### Composer

Между соседними остановками показывается transport leg card:

- иконка и режим;
- duration/distance;
- source label;
- schedule warning;
- `Изменить`.

Действия:

- `Добавить плановый транспорт`;
- `Указать дорогу вручную`;
- `Использовать основной транспорт`.

### Review

Обязательные пояснения:

- `Плановое расписание · не live`;
- время последнего обновления, если известно;
- количество неизвестных переходов;
- отдельные totals activity/private travel/planned transport;
- предупреждение о необходимости перепроверить рейс перед поездкой.

## 9. Persistence и migration

Scenario schema повышается с v1 до v2.

- v1 drafts читаются без потери данных;
- отсутствующий primary mode выводится детерминированно:
  `car`, если он разрешён, иначе первый разрешённый режим, иначе `walking`;
- v1 не получает выдуманный vehicle profile;
- неизвестные будущие поля сохраняются;
- top-level Create schema не повышается, потому что Scenario имеет собственную
  вложенную versioned schema.

## 10. Acceptance criteria

1. Новый Scenario по умолчанию допускает car/walking/transit и выбирает car.
2. Пользователь может выбрать любой разрешённый основной режим.
3. Основной режим не может остаться запрещённым.
4. Car profile проходит JSON round trip.
5. Schedule metadata проходит JSON round trip.
6. Старый Scenario v1 восстанавливается как v2.
7. В интерфейсе нет слова live для static/manual/estimated transit.
8. Planned transport создаётся с постоянными item/location ids.
9. Manual car leg сохраняет duration/distance/cost и lock.
10. Fuel estimate не вычисляется из неизвестных значений.
11. Stale schedule сохраняется и показывает warning.
12. Unknown duration не считается нулём.
13. Save personal draft остаётся доступен без сети.
14. Route domain не получает Scenario-полей.
15. UI не содержит расчётной бизнес-логики.
16. Unit/widget tests покрывают primary car, migration, schedule label и
    persistence.
17. `flutter analyze` и `flutter test` зелёные.
18. `git diff --check` зелёный.

## 11. Следующий slice

`SCN-LV-DATA-01`:

- read-only загрузка официальных GTFS;
- проверка licence/source availability;
- parser и compact local index;
- feed version/freshness;
- Latvia-wide stop/service search;
- offline cache и last-known-good snapshot;
- operator-specific municipal adapters;
- отсутствие live claims;
- kill switch и ручной fallback.

Этот следующий slice не меняет SCN-SB-04 semantics и не является условием
работоспособности personal Scenario.
