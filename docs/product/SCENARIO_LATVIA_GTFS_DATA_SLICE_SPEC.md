# RECHARGE — Scenario Latvia GTFS Data

Версия: 1.0

Статус: **Approved**

Дата: 2026-07-31

Slice: **SCN-LV-DATA-01**

## 1. Решение

Scenario получает provider-neutral read-only слой планового общественного
транспорта. Первая поставка поддерживает официальные статические GTFS:

- региональные и междугородние автобусы ATD;
- внутренние поезда Vivi;
- последующие муниципальные feeds через тот же adapter contract.

Это **плановое расписание**, а не фактическое движение транспорта. Любой
результат в UI маркируется `Плановое расписание · не live`.

## 2. Источники и лицензии

| Provider | Код | URL | Лицензия | Заявленная частота |
|---|---|---|---|---|
| Autotransporta direkcija | `lv_atd_bus` | `https://www.atd.lv/sites/default/files/GTFS/gtfs-latvia-lv.zip` | CC0 1.0 | ежедневно |
| Vivi | `lv_vivi_train` | `https://vivi.lv/uploads/GTFS.zip` | CC0 1.0 | ежемесячно |

Source URL, provider code, retrieval time и digest сохраняются в manifest.
Отсутствие `feed_info.txt` не заменяется выдуманной датой публикации.

Муниципальный feed считается подключённым только после отдельной проверки
его актуального download URL, календарного покрытия и licence metadata.

## 3. Границы

Входит:

- безопасная загрузка ZIP по HTTPS без ключей и платного API;
- GTFS parser для `agency`, `stops`, `routes`, `trips`, `stop_times`,
  `calendar`, `calendar_dates` и необязательного `feed_info`;
- время GTFS больше `24:00:00`;
- service calendar с date exceptions;
- compact in-memory index;
- поиск остановок и прямых рейсов;
- version/freshness manifest;
- offline last-known-good cache;
- manual kill switch и ручной fallback.

Не входит:

- GTFS Realtime, vehicle positions и фактическое прибытие;
- гарантированные пересадки;
- покупка билетов, availability мест и актуальная цена;
- фоновая синхронизация;
- Firebase или собственный backend;
- утверждение о полном покрытии муниципального транспорта всей Латвии.

## 4. Безопасность данных

1. Разрешён только HTTPS.
2. Ограничиваются размер download, число ZIP entries, размер каждого entry и
   общий распакованный размер.
3. ZIP path traversal и вложенные архивы отклоняются.
4. Файлы GTFS должны лежать в корне архива.
5. Обязательные таблицы и заголовки проверяются до замены cache.
6. Архив хешируется SHA-256.
7. Cache заменяется только после успешного parse.
8. При неудачном refresh используется предыдущий валидный snapshot.
9. Повреждённый cache не возвращает частичные результаты.
10. Сбой расписания никогда не блокирует personal Scenario draft.
11. ZIP parsing выполняется вне UI isolate; пользовательские действия и
    autosave Scenario не блокируются разбором национального feed.

## 5. Freshness

- `current`: service date покрыта календарём feed и возраст retrieval не
  превышает provider policy;
- `stale`: snapshot старше provider policy или service date вне покрытия;
- `unknown`: feed не содержит достаточных metadata;
- `unavailable`: нет валидного cache.

Freshness не означает, что транспорт идёт вовремя.

## 6. Поиск

Stop search:

- нормализованный поиск по имени;
- provider filter;
- координаты только при валидных WGS84 значениях;
- стабильная сортировка по точному prefix, затем по имени и id.

Service search:

- конкретная local service date;
- origin должен предшествовать destination в одном trip;
- учитываются `calendar.txt` и `calendar_dates.txt`;
- departure фильтруется по seconds from service day;
- результаты сортируются по departure, arrival, provider и trip id;
- неизвестные/невалидные времена не превращаются в ноль.

## 7. Application contract

Repository не знает о Flutter UI и не изменяет Scenario draft. Coordinator
загружает providers, выполняет поиск и возвращает immutable результаты.
Применение выбранного рейса к `ScenarioScheduleSnapshotDraft` будет отдельным
bounded integration step после проверки data foundation.

## 8. Acceptance criteria

1. ATD и Vivi описаны declarative provider config.
2. Parser корректно обрабатывает CSV quoting, UTF-8 BOM и время после 24:00.
3. Calendar exceptions имеют приоритет над weekly calendar.
4. Поиск не возвращает trip с обратным порядком остановок.
5. Повреждённый refresh не уничтожает last-known-good.
6. Cache manifest содержит provider, source URL, SHA-256 и retrieval time.
7. Kill switch запрещает network refresh, но не чтение cache.
8. Domain/Application не импортируют Flutter, HTTP или filesystem.
9. Tests покрывают parser, calendar, search, limits и cache recovery.
10. `flutter analyze`, `flutter test` и `git diff --check` зелёные либо
    существующие несвязанные stabilization blockers явно зафиксированы.

## 9. Migration и rollback

Scenario draft schema не меняется, поэтому data migration отсутствует.
GTFS cache имеет собственный `schema_version=1` и читается fail-closed.

Rollback выполняется без потери Scenario:

1. `networkRefreshEnabled=false` немедленно отключает новые загрузки.
2. Уже сохранённый last-known-good остаётся доступным для чтения.
3. Полное отключение repository/coordinator возвращает Scenario к ручному
   planned-transport snapshot из SCN-SB-04.
4. Cache не является источником пользовательских данных и может быть очищен
   отдельным maintenance action; Scenario drafts и выбранные snapshots не
   удаляются.
5. Не требуется downgrade write, Firebase migration или изменение Route /
   Quick Plan aggregates.
