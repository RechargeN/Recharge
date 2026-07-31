# RECHARGE — Scenario Latvia Transit Selection Roadmap

Версия: v1.0 (2026-07-31).

Статус: **Planned execution roadmap**.

Родительский slice: **SCN-LV-DATA-02**.

Документ определяет порядок реализации пользовательского выбора официального
планового рейса и его сохранения в Scenario. Он не включает runtime-изменения
и не означает, что перечисленные задачи уже выполнены. До начала кода
соответствующий раздел `02A–02E` должен быть явно принят как slice spec либо
вынесен в отдельную Approved slice spec без расширения описанных границ.

Источники истины:

- [SCENARIO_BUILDER_SPEC.md](SCENARIO_BUILDER_SPEC.md) v1.5;
- [SCENARIO_LATVIA_TRANSPORT_SLICE_SPEC.md](SCENARIO_LATVIA_TRANSPORT_SLICE_SPEC.md);
- [SCENARIO_LATVIA_GTFS_DATA_SLICE_SPEC.md](SCENARIO_LATVIA_GTFS_DATA_SLICE_SPEC.md);
- [ARCHITECTURE_BASELINE.md](../architecture/ARCHITECTURE_BASELINE.md);
- Accepted ADR из `docs/adr/`.

## 1. Целевой результат

Пользователь редактирует planned-transport item в Scenario и выбирает один из
двух явных способов:

1. `Ввести вручную` — существующий offline fallback SCN-SB-04.
2. `Найти в официальном расписании` — поиск в локальном snapshot официального
   статического GTFS, реализованного SCN-LV-DATA-01.

Для поиска пользователь:

- при необходимости явно загружает или обновляет feed;
- выбирает provider;
- выбирает начальную и конечную остановки одного provider;
- задаёт дату и время отправления;
- получает прямые рейсы без пересадок;
- открывает точный preview выбранного рейса;
- явно применяет immutable snapshot в Scenario.

После Apply Scenario хранит собственную точную копию использованных данных.
Последующее обновление GTFS cache не меняет draft молча. Пользователь может
явно перепроверить рейс и заменить snapshot одним undoable действием.

Во всех состояниях показывается:

- `Плановое расписание · не live`;
- provider и источник;
- дата рейса;
- время получения feed;
- freshness `current`, `stale`, `unknown` или `unavailable`;
- предупреждение, что задержки, билет, цена, место и пересадка не
  подтверждены.

## 2. Неподвижные границы

1. Route, Scenario и Quick Plan остаются разными aggregates.
2. GTFS repository не изменяет Scenario draft.
3. UI не содержит расчёт, валидацию, mapping или freshness business logic.
4. Поиск работает только по прямому рейсу внутри одного provider snapshot.
5. Время GTFS после `24:00` сохраняет service-day semantics.
6. Duration округляется вверх до целой минуты; неполная минута не теряется.
7. Template Scenario не применяет официальный рейс до выбора конкретной даты.
8. Manual planned-transport item остаётся полностью работоспособным без сети,
   feed и cache.
9. Snapshot не называется live и не обещает фактическое прибытие.
10. Firebase, backend, API keys и платные сервисы не добавляются.
11. Fares, билеты, места, vehicle positions и гарантированные пересадки не
    выводятся из отсутствующих данных.
12. Каждый этап требует отдельного file plan и подтверждения перед кодом.

## 3. Карта реализации

```text
SCN-LV-DATA-01  Official static GTFS foundation                 Done
       ↓
SCN-LV-DATA-02A Snapshot contract and persistence               Planned
       ↓
SCN-LV-DATA-02B Search workflow and transient application state Planned
       ↓
SCN-LV-DATA-02C Create UI: official schedule picker             Planned
       ↓
SCN-LV-DATA-02D Atomic Apply, Recheck and Replace                Planned
       ↓
SCN-LV-DATA-02E Review, quality and release gate                Planned
       ↓
SCN-LV-DATA-02  Direct official schedule selection milestone
```

Подзадачи выполняются последовательно. Родительский slice получает `Done`
только после завершения `02A–02E` и общего stabilization gate.

## 4. SCN-LV-DATA-02A — Snapshot contract and persistence

### Результат

Scenario schema способен без потери смысла хранить точный выбранный
официальный рейс и восстанавливать его независимо от GTFS cache.

### Scope

- расширить schedule snapshot только additive optional-полями:
  - provider display name;
  - licence name;
  - provider route id и trip id;
  - origin и destination stop ids;
  - SHA-256 выбранного feed;
  - departure/arrival service-day offsets;
- добавить service date в выбранный service option;
- создать один domain/application mapper из GTFS result в Scenario snapshot;
- считать duration через ceiling секунд до минут;
- сохранить неизвестные будущие поля;
- обеспечить round trip старых manual snapshots без migration write.

### Основные файлы

- `apps/mobile/lib/features/create/domain/entities/scenario_transit_schedule.dart`;
- `apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart`;
- `apps/mobile/lib/features/create/data/mappers/scenario_draft_mapper.dart`;
- новый provider-neutral snapshot builder/use case;
- unit и mapper tests.

Точные пути уточняются file plan перед реализацией; параллельная схема не
создаётся.

### Acceptance criteria

1. Старый v2 draft читается и записывается без потери manual данных.
2. Новый snapshot имеет постоянные Scenario ids и не ссылается на cache object.
3. Cross-midnight trip корректно сохраняет дату и day offset.
4. Duration `61` секунд становится `2` минутами, а не `1`.
5. Unknown duration остаётся unknown.
6. Mapper не импортирует Flutter, HTTP или filesystem.
7. Malformed provider result отклоняется типизированной ошибкой до draft
   mutation.

### Rollback

Новые поля optional. Старый mapper продолжает читать draft; UI остаётся на
ручном режиме. Downgrade write и массовая миграция не требуются.

## 5. SCN-LV-DATA-02B — Search workflow and transient state

### Результат

Отдельный application controller управляет загрузкой feed, поиском остановок и
рейсов, не засоряя глобальный Create state и не изменяя Scenario до Apply.

### Scope

- feature config с отдельными флагами показа picker и network refresh;
- состояния `idle/loading/ready/empty/failure`;
- provider manifest/freshness;
- debounced stop search;
- origin и destination одного provider;
- поиск по date + depart-after;
- stale async guards по operation id и request fingerprint;
- cancellation/dispose safety;
- явные `Download`, `Update`, `Retry`, `Use cached` и `Manual entry`;
- bounded result limits.

### Основные файлы

- новый `scenario_transit_config.dart`;
- новый `scenario_transit_picker_state.dart`;
- новый `scenario_transit_picker_controller.dart`;
- существующие Create providers/coordinator wiring;
- controller tests.

### Acceptance criteria

1. Открытие picker не начинает network refresh автоматически.
2. Kill switch запрещает download/update, но не чтение last-known-good.
3. Поздний результат старого запроса не перезаписывает новый.
4. Ошибка feed не меняет Scenario и всегда оставляет manual fallback.
5. Destination не ищется в другом provider незаметно для пользователя.
6. Empty, offline, stale cache и corrupt cache имеют разные честные состояния.
7. Ни query, ни пользовательский текст поиска не сохраняются в Scenario draft.

### Rollback

Отключение picker flag убирает официальный поиск. Data foundation и manual
Scenario продолжают работать без удаления cache или draft.

## 6. SCN-LV-DATA-02C — Create UI official schedule picker

### Результат

В существующем config-driven Scenario Composer появляется доступный sheet
выбора официального планового рейса.

### Scope

- entry choice `Ввести вручную` / `Найти в официальном расписании`;
- provider и freshness card;
- date rule:
  - dated Scenario использует дату соответствующего day;
  - template Scenario просит выбрать дату и не позволяет Apply до этого;
- поля origin, destination и depart-after;
- список прямых рейсов с carrier, service, departure, arrival и duration;
- selection preview с provenance и warnings;
- loading/empty/error/offline/stale состояния;
- 360 dp и увеличенный text scale;
- semantic labels, focus order и screen-reader announcements.

### Основные файлы

- новый `scenario_transit_schedule_picker_sheet.dart`;
- существующий `scenario_composer_section.dart`;
- существующие presentation helpers/tokens без нового feature theme;
- widget и accessibility tests.

### Acceptance criteria

1. Пользователь может пройти весь поиск без знания GTFS-терминов.
2. Рейс нельзя применить без provider, даты, origin, destination и selection.
3. Template Scenario объясняет, зачем нужна дата.
4. Каждый результат явно помечен `Плановое расписание · не live`.
5. UI не показывает fare, available seats, delay или transfer guarantee.
6. 360×800 и text scale 1.5 не имеют overflow.
7. Back/close не изменяют draft.

### Rollback

Feature flag скрывает entry и sheet; существующая ручная форма остаётся
основным путём.

## 7. SCN-LV-DATA-02D — Atomic Apply, Recheck and Replace

### Результат

Выбранный рейс применяется к Scenario одной командой, участвует в
undo/redo/autosave и может быть явно перепроверен либо заменён.

### Scope

- source revision guard перед Apply;
- атомарное создание/замена planned-transport snapshot;
- постоянные item/location ids;
- сохранение item id, day, order, role, note и пользовательской cost при
  Replace, если пользователь явно не выбрал иное;
- одна undo entry на Apply или Replace;
- один autosave после успешной mutation;
- `Recheck` только сравнивает cache и snapshot;
- diff preview до `Replace`;
- stale/not-found/new-time outcomes;
- никакого silent refresh сохранённого Scenario.

### Основные файлы

- существующие Scenario coordinator/create controller;
- snapshot build/apply use case;
- Create persistence/autosave wiring;
- application, persistence и widget integration tests.

### Acceptance criteria

1. Cancel и failed Apply оставляют draft byte-for-byte эквивалентным.
2. Revision conflict не затирает более свежую пользовательскую правку.
3. Apply создаёт ровно одно undoable изменение и ровно один autosave.
4. Undo возвращает точное предыдущее состояние; redo — точный snapshot.
5. Recheck не мутирует draft.
6. Replace показывает diff и требует явного подтверждения.
7. Исчезнувший из нового feed рейс не удаляет старый snapshot.
8. Перезапуск приложения восстанавливает применённый snapshot без GTFS cache.

### Rollback

Отключение Apply action оставляет draft читаемым и редактируемым вручную.
Применённые snapshots не удаляются и показываются как сохранённые плановые
данные.

## 8. SCN-LV-DATA-02E — Review, quality and release gate

### Результат

Пользователь видит происхождение и ограничения данных в Composer и Review, а
родительский slice имеет доказанный безопасный release/rollback.

### Scope

- Review summary для official/manual snapshots;
- provider, service date, retrieved-at, digest/freshness disclosure;
- отдельные warnings для stale, unknown и unavailable;
- напоминание перепроверить расписание перед поездкой;
- analytics только по enum/result codes, без stop queries и personal notes;
- негативные тесты честности данных;
- regression manual flow;
- documentation/status update и rollback check.

### Acceptance criteria

1. Snapshot нигде не называется live.
2. `current` не интерпретируется как `идёт вовремя`.
3. Время, цена, fare и availability не превращаются из unknown в zero/free.
4. Personal Scenario сохраняется при недоступном repository.
5. Manual planned transport не регрессирует.
6. Full `flutter analyze` — 0 issues.
7. Full sequential `flutter test` — green.
8. Boundary check и `git diff --check` — green.
9. Parent `SCN-LV-DATA-02` переводится в `Done` только с фактическими
   результатами проверок в `LAUNCH_STATUS.md`.

### Rollback

1. Выключить picker/apply feature flag.
2. Оставить чтение уже сохранённых official snapshots.
3. Вернуть основной entry на manual mode.
4. Не удалять пользовательские drafts и не очищать cache автоматически.

## 9. Не входит в SCN-LV-DATA-02

- поиск с пересадками и гарантии стыковок;
- объединение рейсов разных providers;
- realtime delays, cancellations и vehicle positions;
- fares, ticket deep links, покупка или бронирование;
- seat/room availability;
- фоновое бесшумное обновление feed;
- полный муниципальный охват Латвии без проверки каждого источника;
- production backend/Firebase sync;
- public/unlisted publication и moderation.

## 10. Последующий backlog

Эти направления не должны проникать в `SCN-LV-DATA-02`:

| ID | Направление | Gate |
|---|---|---|
| SCN-LV-JOURNEY-01 | Пересадки и multi-leg journey planning | Отдельный provider-neutral journey contract, корректная timezone/service-day модель и доказанные transfer rules |
| SCN-LV-MUNI-01 | Дополнительные муниципальные GTFS providers | Проверка актуального URL, licence, календарного покрытия, качества и отдельный adapter fixture для каждого source |
| SCN-LV-RT-01 | GTFS Realtime и фактические обновления | Post-stabilization provider ADR, backend/operations, quotas, observability, freshness SLA и kill switch |
| SCN-BOOK-01 | Внешний ticket/booking handoff | Подтверждённый legal/commercial contract, availability recheck и явный уход к provider |
| SCN-PUB-01 | Public/unlisted Scenario templates | PublisherRef, capability guards, moderation и независимое копирование template |

Ни одно направление из таблицы не считается начатым или обещанным текущим
roadmap.

## 11. Definition of Done родительского slice

`SCN-LV-DATA-02` завершён только когда:

1. `02A–02E` имеют статус `Done` с evidence.
2. Manual и official flows работают независимо.
3. Сохранённый snapshot автономен от cache и не обновляется молча.
4. Template/date, cross-midnight, stale/offline и revision-conflict случаи
   покрыты тестами.
5. Нет платных/network-зависимостей для базового чтения сохранённого Scenario.
6. Все repository gates зелёные.
7. `LAUNCH_STATUS.md` отражает фактическое, а не запланированное состояние.
