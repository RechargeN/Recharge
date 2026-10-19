# I2 Scenario persistence/collaboration — проверка, 2026-10-18

Checkout: изолированный worktree `721e/Recharge`, detached на I1 `f32b97f`
(родитель `bde8b79`); I2 — незакоммиченные изменения поверх. Коммита, push и
deploy нет. Спецификация: [SCENARIO_I2_SLICE_SPEC.md](../product/SCENARIO_I2_SLICE_SPEC.md).
Это локальное Emulator-evidence, не устройства, staging или production.

Первичная read-only сверка 2026-10-18, до доработок ниже: исходный полный прогон подтверждён файлом
`C:\Users\User\AppData\Local\Temp\recharge-emulator-tests-xmuZXR\summary.json`
(`complete: true`, `code: 0`); повтор I2 —
`C:\Users\User\AppData\Local\Temp\recharge-emulator-tests-kVrcBw\summary.json`.
В журнале последнего I2 есть подтверждение cleanup. Полный прогон предшествует
дополнению Flutter-теста конфликтов; после дополнения повторялась группа I2,
а не весь набор. На этой сверке runtime не менялся и проверки не перезапускались.

## Что сделано на финальной проверке diff

- Форматирование: 3 Dart-файла (`create_repository_impl.dart`,
  `scenario_sync_client.dart`, новый блок `booking_functions_transport_test.dart`)
  и 2 TS-файла (`firestore_scenario_service.ts`, `scenario_i2.test.ts`) не
  проходили `dart format` / `format:check`. Применено только форматирование,
  без изменения логики; ранее существовавшие строки теста транспорта не
  переформатированы.
- Пробел против §Required evidence п. 4: Flutter-тест двух клиентов не проверял
  конфликт одной ревизии в обоих порядках доставки. Добавлено в
  `test/backend_local/scenario_i2_client_test.dart`: для порядков owner→editor и
  editor→owner первый `saveIfRevision` сохраняется, второй получает `conflict`,
  на сервере остаётся заголовок победителя, а отклонённый payload
  (`revision_conflict`, исходный draft) читается из зашифрованного журнала новым
  экземпляром клиента после рестарта и повторной серверной проверки доступа.

## Ранние неуспешные прогоны (по журналу реализации)

1. Первый Emulator-запуск остановился до старта: внешний allowlist callable в
   `run-emulator-tests.mjs` не содержал `scenarioCommandV1`/`scenarioQueryV1`.
2. Flutter-клиент отказал до HTTP: transport guard принял
   `draft.scenario.capabilities` за authority claims. Добавлено узкое исключение
   только для булевых полей этого пути; тест транспорта проверяет, что прочие
   пути и callables по-прежнему отвергаются.
3. Срок приглашения: Flutter отправлял микросекунды, сервер сравнивал строку с
   точностью до миллисекунд; сервер нормализует срок через `Date`.

## Исторические проверки 2026-10-17 (этот ПК)

Toolchain: Node 22.23.2 (`%LOCALAPPDATA%\Recharge\tools`), Temurin 21.0.12+8,
Flutter 3.44.9 (`C:\src\flutter`). Каждый rc снят сразу после команды; итоги
сверены с журналами (`not ok`, `# fail`, `exited with code`).

| Гейт | Итог |
|---|---|
| test:emulator (полный, одна сессия, `RECHARGE_DART`/`RECHARGE_FLUTTER_TOOL`/`RECHARGE_G_MOBILE=1`) | exit 0; 14/14 групп PASS; 304 pass, 0 fail, 0 skip |
| scenario-i2 повторно, после дополнения Flutter-теста | exit 0; 12/12, Flutter-клиенты `+1: All tests passed` |
| format:check, lint, typecheck | pass |
| test:unit / test:contract / test:r1:integration | 735/735 / 55/55 / 254/254 |
| verify:execution-manifest, verify:content-persistence:layout, verify:r1 layout/config/exports | pass |
| test:emulator:runner (самопроверка изменённого запускателя) | 6/6 |
| flutter analyze --no-pub | No issues found |
| flutter test --no-pub (полный) | 1653 pass, 0 fail, 70 skip |
| boundary / inventory `--check-output` / `git diff --check` (+ новые файлы) | pass (624 файла, 0 нарушений, 71/71) / pass / pass |
| stand-mobile-gate (B1) / stand-b2-gate — исполняют изменённые allowlist и transport guard | exit 0: 4/4 / exit 0: 3/3 повтора по 5 тестов; стенд оставлен `stopped` |

70 Flutter-skip = 69 из карты I1 + `scenario_i2_client_test.dart`, который
исполняется Emulator-группой scenario-i2 (выше). На этом историческом этапе
`verify:toolchain` не запускался из-за отсутствия закреплённого Terraform;
этот пробел закрыт 2026-10-18 установкой локального точного toolchain.

## Соответствие §Required evidence

| № | Где доказано |
|---|---|
| 1 | Emulator: authority (pending invite, wrong recipient, spoofed role, stranger, session expiry) |
| 2 | Emulator: cancel terminal, accept/revoke обоих порядков, membership CAS, expiry, повторный accept |
| 3 | Emulator: revoke fences read/save/replay/queue после re-invite; гонка revoke с транзакциями |
| 4 | Emulator: два редактора, оба порядка; Flutter: оба порядка + durable conflict payload после рестарта |
| 5 | Emulator: redaction provenance, список без draft/ownerId, membership только owner |
| 6 | Emulator + Flutter: потерянный ответ Expand, рестарт, прерванная транзакция — один target |
| 7 | Emulator: правка source в гонке с Expand — pinned snapshot или conflict, независимость |
| 8 | Emulator: spy на `saveInTransaction` — одна команда создания для save и Expand |
| 9 | Flutter против Emulator: приглашение, shared read/edit, revoke с офлайн-очередью, Expand через существующий facade |
| 10 | Таблица выше; cleanup каждой коллекции группы и Auth-пользователей Flutter-фикстуры в `before`/`after` |

## Доработка 2026-10-18

- R0 workflow готовит тот же Flutter 3.44.9 по release SHA, задаёт реальные
  Dart/Flutter paths и `RECHARGE_G_MOBILE=1`; нет skip/workaround для I1/I2/Library.
  Проверка cloud context предшествует dependency bootstrap. Самопроверка не
  только читает YAML, но и исполняет настройку runtime в изолированных временных
  файлах; runner timeout покрывает полный набор и подготовительные gates.
- Обычный Create save использует стабильный fingerprint payload: одинаковый
  retry повторяет intent, разные правки одной ревизии получают разные keys и
  обычный revision conflict вместо ложного idempotency conflict.
- Журнал ограничен 2 MiB. Успешные Expand intents становятся компактными
  source-bound receipts; неизвестный результат остаётся полным pending до
  подтверждения. Удаляется только повторно загружаемый cache; pending,
  conflicts и intent receipts не выбрасываются. Capacity failure происходит
  до dispatch. Старый успешный receipt не откатывает более новый cache.
- Save участника без read получает текущую server generation; offline queue
  может использовать ранее сохранённую generation, но сервер проверяет её
  заново. Auth/feature-disabled ошибки сохраняют очередь для повтора.
- Список owner/shared Scenario имеет cursor pagination и не обрезается после
  100 записей. Каждая страница остаётся transaction-authorized. Проверка
  структуры draft отвергает дубли/висячие ссылки и нечисловые координаты.
- Source-unavailable на повторе Expand не отзывает независимый target и не
  закрывает его допустимый cache. Это проверяется реальным Flutter-адаптером.
- Устранено расхождение с принятым размером Scenario: 30 дней / 250 items.
  Реальный Flutter transport проверяет 200 scheduled + 50 unscheduled items,
  чтение последнего элемента и его данных; canonical DTO занимает 222701 байт.
  Бюджет draft — 240 KiB с запасом до callable response cap 256 KiB; отдельные
  пределы locations/legs — 500 записей. Превышение дней/items/байт отвергается
  до записи. Это persistence resource budget, а не publication readiness.
- Выбранные stops копируются в порядке source snapshot (Set выбора не задаёт
  новый порядок). Подмена порядка готового DTO отвергается; второго converter нет.

## Итоговая проверка 2026-10-18

Финальный runtime: HEAD `f32b97f`, 26 изменённых/новых source, test, config и workflow
файлов (документация не включена), SHA-256
`72026ba37daabac86b3e87c93d3658f4311cd5618a50089024365745922f009c`.
Алгоритм: последовательные `path + NUL + raw bytes + NUL` в лексическом порядке
путей. После полного Emulator-прогона каждый файл и общий fingerprint совпали;
runtime во время проверки не менялся.

| Гейт | Итог на финальном snapshot |
|---|---|
| Полный Emulator-набор одной отдельной сессией | exit 0; 14/14 групп; 307 pass, 0 fail, 0 skip |
| I2 внутри общего набора | 15/15, включая настоящие Flutter Session/HTTP adapters, 30 дней / 250 items и cleanup |
| Backend typecheck / lint / format:check | pass |
| Backend unit / contract / integration | 735 / 55 / 254 pass, 0 fail |
| Execution manifest / content layout / R1 layout, config, exports | pass |
| Самопроверки runner + content-layout | 8/8 |
| Exact toolchain | pass; закреплённые Node/npm, Temurin и Terraform, без ослабления pin |
| flutter analyze --no-pub | exit 0; No issues found |
| Полный flutter test --no-pub, последовательно после Emulator | exit 0; 1661 pass, 70 skip, 0 fail |
| Boundary / inventory --check-output | pass; 624 файла, 0 нарушений, 71 прежнее исключение |
| Generated output / reproducibility | pass; 1118 файлов; два одинаковых logical build |
| git diff --check и whitespace новых файлов | pass |

70 Flutter-skip: 69 унаследованы от I1, ещё один — отдельный I2 backend-local
test entry. Сам I2 entry действительно исполнен общим Emulator-набором, а не
пропущен в нём; native device/AVD evidence этот запуск не заменяет.

Summary общего набора:
`C:\Users\User\AppData\Local\Temp\recharge-emulator-tests-4qlZ2T\summary.json`
(`complete: true`, `code: 0`). `scenario-i2.log` содержит подтверждение удаления
всех собственных Scenario/Quick Plan, Identity, flags и Auth fixtures; Content и
Catalog digest до/после I2 совпадает. Emulator штатно завершён, service/hub/log
порты освобождены. Повторная сборка выполнялась только после его остановки.

Журналы в `apps/backend/`: `i2-serial-emulator.log`,
`i2-capacity-{typecheck,lint,format,unit-loopback,contract,integration,selftests}.log`,
`i2-capacity-analyze-verbose.log`, `i2-serial-{toolchain,reproducibility,generated,fingerprint,flutter}.log`.
Logical build SHA-256:
`84beb0eca06911e8fe17ad0006fea4c64060cb53f1718c069f5212b91197f31b`.

Первый sandbox unit-запуск не имел доступа к четырём loopback HTTP-фикстурам
media tests; тот же набор повторён с локальным сетевым доступом и прошёл 735/735
без изменения тестов или реализации.

Промежуточный `recharge-emulator-tests-aUjAD7` не является зелёным общим
evidence: I2 прошёл 15/15 с подтверждённым cleanup, но Content/Media исчерпал
group timeout во время параллельного полного Flutter-прогона. Сессия остановлена,
её порты освобождены; Flutter-прогон также прерван (1636 pass к моменту остановки)
и не засчитывается. Полный Emulator-повтор выполнен последовательно, без изменения
runtime, таймаутов и тестов. Конкуренция ресурсов — причина выбранного порядка
повтора, а не доказанный дефект или исправление доменного кода.

## Оставшиеся границы

- Hosted Linux/Windows R0 CI ещё не запускался: workflow подготовлен локально;
  публикация ветки/запуск через push не разрешались.
- Native AVD для I2 не запускался; доказаны два installation с раздельными
  Session/HTTP через настоящие Flutter-адаптеры в Emulator.
- Production, invited/unlisted Quick Plan authority, публикация и Route вне
  scope; `planning.scenarioI2` остаётся default-off. Offline-устройство не
  позволяет гарантированно отозвать уже доставленные данные.
