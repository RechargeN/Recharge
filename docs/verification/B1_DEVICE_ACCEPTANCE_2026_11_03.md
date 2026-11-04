# B1-device — физический Android, 2026-11-03

Этап программы «B1-device: обязательная приёмка локального R1 на физическом
Android». Основа — принятый владельцем M2 (`8e35fa3`, R1 функционально
проверен локально на `b297be1`). Устройство: Samsung A34 (SM-A346B, serial
`RFCW91QHWWJ`), Android 16 (SDK 36), сборка
`samsung/a34xeea/a34x:16/BP2A.250605.031.A3/A346BXXUBEYI7:user/release-keys`,
USB, `adb devices -l` → `device`. AVD не использовался. Стенд `demo-recharge`
остаётся на loopback ПК; телефон достаёт Auth (9099), Functions (5001) и мост
gate (8765) на своём 127.0.0.1 через `adb reverse`, который снимается после
каждого прогона. Push, merge и deploy нет.

Gate и его части описаны в `apps/backend/README.md`, раздел «B1-device».

## Вердикт

**B1-device на Android: Done — принят владельцем 2026-11-04.** Все пункты
scope пройдены на A34. Части `core`, `release`, `route`, `media` и
`route-background` пройдены на телефоне; телефон нашёл и помог исправить
четыре дефекта продукта (раздел «Найдено на телефоне»). Host-регрессия
итогового кода — раздел «Финальные проверки». iOS не проверялся: среды
нет, один Android его не закрывает.

Дополнительно 2026-11-04 Codex прошёл на A34 на `25d5ed5` C3, D4 и E2, C3 с
выбранной на телефоне обложкой, завершение процесса во время нормализации
фото, release и foreground Route/GPX и нашёл B1D-ROUTE-BG-01 (отчёт
`C:\Users\User\Documents\Codex\2026-11-04\38a-b1-device-text-b1-device\outputs\B1-device-2026-11-04.md`).

## Прогоны

| Часть | SHA | Результат |
|---|---|---|
| Host-регрессия изменённого stand-кода | `d21394c` | pass: format, lint, self-tests, `flutter analyze`, `flutter test` 2214/83 skip, boundary 69/71, inventory, полный Emulator 25 групп (438), 21 stand gate с Flutter-клиентами |
| `core` | `8161727` | pass, все 12 шагов (ниже) |
| `release` | `d00e230` | pass; между `8161727` и `d00e230` менялся только release-шаг gate |
| `route` | `d21394c`, `8c8fa18` | частично: диалог, GPS, `am kill`, восстановление — pass; выбор GPX — null (файл серый), затем отказ по имени `.bin` |
| `route` | `b9b899b` | pass с оператором: реальный диалог геолокации, 2 GPS fix, `am kill`, восстановление журнала в паузе без auto-resume (2 точки), `.gpx` выбран в системном окне, имя `recharge-b1-device.gpx`, 479 байт, sha256 совпадает с отправленным, экспорт выполнен |
| `media` | `25d5ed5` | pass с оператором (MEDIA-PICK-01, `7061a5c`): реальный Photo Picker и камера; сохранённые копии — JPEG 1536×2048 (205 КБ и 389 КБ), без EXIF/GPS, ориентация применена; APK, который работал на телефоне, не запрашивает `READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED`, `READ_EXTERNAL_STORAGE` и `CAMERA` |
| `route-background` | `7723d55`, `503973f` | красный: оператор не дошёл до «Разрешений» (пункт не на первом экране); затем `startForeground … requires FOREGROUND_SERVICE`; затем `… requires WAKE_LOCK` |
| `route-background` | `709314b` | pass с оператором: `denied` → «При использовании» → фоновый старт `gps_background_permission_denied` (Android 16 выдаёт фон только в настройках) → «О приложении → Разрешения → Местоположение → Разрешать в любом режиме» → `always` → фоновый старт, `backgroundEnabled`, foreground-сервис геолокации работает 20 с в фоне, после возврата запись продолжается (3 точки) |
| Финальные проверки | `d00e230`, `b9b899b`, `709314b` | см. раздел «Финальные проверки» |

`core` и `release` не повторялись после `fe58aa4`/`b9b899b`: те меняют
только адаптер выбора GPX, который core не использует, и не меняют manifest
release.

`core` на телефоне:

1. Guards: selection suite (release, disabled, localOnly; только loopback
   demo-recharge base) в установленном приложении; стенд отвечает на
   127.0.0.1 телефона; Dart-guard отклоняет 10.0.2.2, LAN, https и не-demo
   base.
2. Debug APK: cleartext разрешён только для `127.0.0.1` без поддоменов,
   base-config запрещает cleartext (`aapt`).
3. Native firebase_auth и FlutterSecureStorage: Session, восстановление,
   revoke, expiry, `localOnly` и rollback.
4. Жизненный цикл, три запуска одного приложения: фон и возврат (состояния
   `inactive → hidden → paused → hidden → inactive → resumed`, та же Session);
   завершение процесса ОС из фона (`am kill`, pid 22722) — холодный старт
   восстановил пользователя Firebase, Session и journal, неизвестный исход
   Booking завершён одной бронью; закрытие пользователем (`am force-stop`, pid
   23587) — Session восстановлена, revoke и expiry исправлены, `localOnly`
   без вызовов. Броней staff: было 1, стало 2, активных 0.
5. B2 Booking UI на телефоне: создание, двойное нажатие, потерянный ответ,
   restart, offline, отказ сервера на lv и ru; итог 8 броней, 0 активных.
6. C3: настоящий CreatePage → обложка из файла приложения → загрузка →
   submit → модерация staff-скриптом на ПК → публикация → hide.
7. D4: локальный импорт, потерянные ответы, удаление оригинала, fenced
   rollback и generations.
8. E2: телефон — клиент B, ПК — клиент A; два пользователя, Session,
   installation id и journals; Create → модерация → публикация →
   Feed/Search → Details той же ревизии → Booking без дубля → cancel; гонка
   hide с бронью, отказ после применения hide.

`release` на телефоне: APK без network security config и debug-ресурса, без
`usesCleartextTraffic`, не debuggable, targetSdk 36; установлен, запущен,
процесс жив через 10 с, crash-буфер пуст; затем удалён. Разрешения записаны:
INTERNET и ACCESS_NETWORK_STATE приходят от плагинов (карты, firebase_auth),
Booking в release отключён кодом (`productionDisabled`).

## Найдено на телефоне

| ID | Что | Итог |
|---|---|---|
| ROUTE-GPX-ANDROID-PICK-01 | MediaStore типизирует `.gpx` как `application/octet-stream`, адаптер просил только `application/gpx+xml`/`application/xml`: файл серый, импорт GPX на Android невозможен (подтверждено владельцем) | исправлено `fe58aa4` (фильтр добавляет `application/octet-stream` и `text/xml`) и `b9b899b`: file_selector на Android кэширует файл как «база + расширение MIME», и `XFile.name` приходил как `recharge-b1-device.bin`; отменяется только это переименование (`.bin` для octet-stream, `.xml` для XML), остальное — отказ, инспектор решает по байтам. Проверено на телефоне (`route` pass) |
| B1D-OBS-01 | `dart:io` не применяет Android network security config: Dart-запрос к LAN уходит в сеть | наблюдение; граница для Dart — `BookingBackendEndpoint.devEmulator`, проверено на телефоне; debug-конфиг покрывает нативные стеки |
| B1D-OBS-02 | Samsung Freecess замораживает приложение, когда экран гаснет; тест не завершается | прогоны шли с периодическим `KEYCODE_WAKEUP`, настройки телефона не менялись; записано в README |
| MEDIA-PICK-01 | В приложении нет выбора изображения: обложка и галерея задаются путём | реализовано `7061a5c` по Approved spec; проверено на телефоне (`media` pass) |
| B1D-ROUTE-BG-01 | Фоновая запись Route на Android невозможна: (а) geolocator_android 5.0.3 добавляет `ACCESS_BACKGROUND_LOCATION` в запрос только из `whileInUse`, поэтому при уже выданном «всегда» отвечает `whileInUse` (найдено Codex); (б) в manifest нет `FOREGROUND_SERVICE`; (в) нет `WAKE_LOCK` | исправлено `fcc2ac8` (выданное «всегда» сохраняется; unit-тесты), `503973f`, `709314b`; проверено на телефоне (`route-background` pass) |

Исправления самого gate, найденные на телефоне (`9da5300`, `bcae207`,
`aeac829`, `8161727`, `d00e230`): проверка cleartext через `dart:io`
заменена проверкой Dart-guard и APK; ожидание `resumed` после возврата;
тестовая локаль `en` для stand-наборов (система A34 — русская); заглавные
буквы в именах rendezvous (`approved.B`); release проверяет отказ от
cleartext, а не отсутствие INTERNET. Ранние красные прогоны сохранены в
evidence (`core`, `core-2`, `core-3`, `core-4`, `release`) и не засчитаны.

## Не закрыто

- B1D-ROUTE-BG-02 (follow-up): ошибка запуска потока геолокации в
  EventChannel теряется, интерфейс показывает «идёт запись» без точек;
  нужен сторож (например, нет ни одной точки за N секунд) по решению
  продукта.
- Решение по `POST_NOTIFICATIONS`: без него на Android 13+ уведомление о
  фоновой записи может быть скрыто, сама запись работает.
- MEDIA-PICK-02: полная очистка копий фото вместе с серверной финализацией
  Media (поправка 1 спецификации MEDIA-PICK-01).
- Из supplemental-сценария Codex не проверены блокировка экрана, отзыв
  разрешения во время записи и расход батареи.
- iOS — отдельная платформа, среды нет; один Android её не закрывает.
- LAN, cloud, реальный Google/Apple Auth и push — вне B1-device.

## Финальные проверки

На `d00e230`, чистое дерево до и после: format:check, lint, script self-tests
106/106, `flutter analyze` — no issues, `flutter test` 2216 pass / 83 skip
(+2 теста ROUTE-GPX-ANDROID-PICK-01), boundary 69/71, inventory
`--check-output`, `git diff --check 8e35fa3 HEAD` — pass.

На `b9b899b` (после исправления имени GPX) те же проверки — pass:
`flutter test` 2217 pass / 83 skip, script self-tests 106/106, `flutter
analyze` — no issues, boundary 69/71, inventory, diff-check; дерево чистое.

На `709314b` (MEDIA-PICK-01 и B1D-ROUTE-BG-01) — host-регрессия всех gates
с Flutter-клиентами: toolchain, format, lint, stand и script self-tests
107/107, `flutter analyze` — no issues, `flutter test` 2240 pass / 83 skip,
boundary 69/71, полный Emulator 25 групп (438 pass), raw-body и 21 stand
gate (B1, B2, C1, C3, D3.1–D3.8 с activity delivery и linked Place, D4,
E2a, E2, F1, F2, I3, J2) — pass. Красный: inventory `--check-output` —
`MOBILE_BOUNDARY_INVENTORY.md` не перегенерирован после MEDIA-PICK-01 (692
файла вместо 685, исключения те же); перегенерирован в коммите этого
документа и проверен на нём.

## Evidence

`C:\Users\User\Documents\Recharge-evidence\B1-device-2026-11-03`: JSON-журналы
и логи частей (`core-5`, `release-2`, `route-3`, `media-3`,
`route-background-4`), ранние прогоны, host-регрессии
(`host-regression-d21394c`, `host-regression-709314b`), финальные проверки
(`final-d00e230`, `final-b9b899b`) и скрипты запуска; хэши 248 файлов — в
`SHA256SUMS.txt`, его хэш —
`36c5c03d9524c1043850dcc8cb48c32133990415af53c2a3026173fd36466cbd`.
