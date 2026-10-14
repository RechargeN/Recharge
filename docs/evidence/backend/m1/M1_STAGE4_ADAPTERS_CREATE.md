# Заход 4 — реальные адаптеры и Create; evidence итогового SHA

Проверенный SHA: `7cb07fa9a1b531d08660f51800172f506459bc5b`. Последнее runtime-исправление — `bb25583626e6b47f931c4971b31c097d00d6ccd6`; последующие коммиты меняют только тесты. Все финальные прогоны выполнялись на чистом checkout этого SHA. Документальная приёмка следует отдельно.

## Прямое evidence и пределы

| Критерий | Прямой прогон | Что подтверждено | Предел |
|---|---|---|---|
| B1 | `stand-mobile-gate.mjs --yes --android emulator-5554`, `stage4-gate-native.log` | настоящий FirebaseAuthIdTokenProvider, native firebase_auth и FlutterSecureStorage; создание Session, восстановление новым store/runtime, замена отозванной и истёкшей Session, localOnly и возврат, signOut/clear | Android Emulator API 36; проверка адаптеров, не UI; новый runtime не означает завершение приложения ОС |
| E2 Map | `stand-e2a-gate.mjs --yes`, `stage4-gate-e2a.log` | настоящий DiscoverFeedController, используемый Map, CatalogDiscoverRepository, совпадение revisionRef Map/Feed/Details, отсутствие скрытого объекта после обновления области | renderer Map и физическое устройство не исполнялись |
| C3 | `stand-c3-gate.mjs --yes`, `stage4-gate-c3.log` | 6 controller-сценариев и 1 UI-сценарий: настоящая CreatePage редактирует существующий draft, сохраняет title/description/cover; тот же draft проходит upload/submit/status/publish/My Objects/hide | остальные поля seeded draft заданы заранее; после Save явный переход в существующий harness publication, не доказательство production-навигации или заполнения пустой формы целиком |
| B2 loading | `stand-b2-gate.mjs --yes`, `stage4-gate-b2.log` | три отдельных прогона по 5 тестов; видимое initial Loading и progress до ответа сервера, busy во время mutation, двойной submit | headless widget UI с реальным локальным сервером |
| Binding rollback | native B1 и `stand-mobile-gate.mjs --yes`, `stage4-gate-mobile.log` | testBackend → localOnly → testBackend; localOnly не вызывает Dart Functions HTTP, secure Session сохраняется | это переключение binding, не D4.1 import rollback |

Native B1 потребовал единственного runtime-исправления после отдельной карты файлов: debug Android policy разрешает cleartext только точному `127.0.0.1`, base policy остаётся запретной. Main/release manifest и Dart loopback guard не менялись. Дефект M1-ST4-01 закрывается только успешным повтором native B1 на финальном SHA. Тестовый bridge Session expiry/revoke доступен лишь на loopback и использует whitelist seeded viewer; это управляющая фикстура, а не замена Auth/Session adapters.

## Итоговые пакетные проверки

- Flutter mobile: 1635 passed / 67 skipped / 0 failed; analyze 0 issues.
- API contracts: 25 passed, analyze 0 issues.
- Boundary: 619 файлов, 71/71 подавлений, 0 нарушений; inventory --check-output pass.
- Backend: format/lint/typecheck, 731 unit, 55 contract, 254 integration; обязательные layout/contracts/generated/taxonomy/security/identity/reproducibility и offline IaC topology pass. Digest `a32a6845065ecb6b09380716539bc9af6ef25896fa426098a58406ef90b21e4f`.
- Полный обязательный `test:emulator`: 250 passed / 0 failed / 0 skipped, девять групп: platform, booking, content-media, handoff-notifications, place-activity, rental, collection, import, rules-reference. UTC 2026-10-14 19:42:58–20:01:11. Это новое evidence на финальном SHA; прежнее 250/250 на e3710f6 остаётся историческим.
- Waiver: только три ранее принятых EOF blob с неизменными SHA-256; остальные diff-проверки без нарушений.

## Среда и исключения

Windows, Flutter 3.44.9 / Dart 3.12.2, Node 22.23.2, Temurin 21.0.12+8. demo-recharge на 127.0.0.1; Android AVD API 36 подключён adb reverse к локальным Functions/Auth и fixture bridge. Гейты последовательно, build до запуска стенда, свежий seed и verified stop. Зависимости из локального кеша, offline provider mirror скопирован без state/credentials.

Linux official-database и EICAR tests пропущены в Windows D1/media-tools по принятому Р-06 А (Linux вне M1). Отдельный D1 Linux run 38567123384 на 83e05cd сохраняет собственные SHA и пределы. Он не считается повтором на 7cb07fa. Терминальный revokeMembership — backend-only по Р-04. Реконструкция файлов M1 и узкий EOF waiver приняты Р-03/Р-05. Реальные devices, OS kill/background, cloud/staging/production и новые рынки вне этой приёмки.

## Журналы и сопоставление пропусков

Финальный manifest, gate ledger и полное сопоставление каждого из 67 пропущенных тестов публикуются с результатом захода 5. Каждый mapping содержит файл, точное имя теста, отдельный gate, команду, SHA, exit и журнал. Нельзя считать общий suite доказательством выполнения этих 67 тестов.

Неуспешные ранние запуски сохранены отдельно: настоящий cleartext-дефект B1, неверный locator C3 и ошибочный вызов C1 без аргументов. Они не обозначены зелёными и не замещают финальные прогоны.

Все обязательные stand gates завершены exit=0 на этом SHA; точные команды и время — `stage4-gate-runs.jsonl`. Все 67 skipped сопоставлены отдельным успешным прогонам в `M1_STAGE4_SKIPPED_EVIDENCE.json`. Для E2/F1/F2 внешний журнал содержит только +1 All tests passed; соответствие дополнительно проверено по конкретному единственному test в выбранном gate source file.
