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

**B1-device на Android: не Done.** Все три части пройдены на телефоне:
`core`, `release` и `route` (с оператором, после исправления импорта GPX,
найденного на этом же телефоне). Открыт один пункт scope — выбор
изображения и его permissions: в приложении нет picker (MEDIA-PICK-01).
iOS не проверялся: среды нет, один Android его не закрывает.

## Прогоны

| Часть | SHA | Результат |
|---|---|---|
| Host-регрессия изменённого stand-кода | `d21394c` | pass: format, lint, self-tests, `flutter analyze`, `flutter test` 2214/83 skip, boundary 69/71, inventory, полный Emulator 25 групп (438), 21 stand gate с Flutter-клиентами |
| `core` | `8161727` | pass, все 12 шагов (ниже) |
| `release` | `d00e230` | pass; между `8161727` и `d00e230` менялся только release-шаг gate |
| `route` | `d21394c`, `8c8fa18` | частично: диалог, GPS, `am kill`, восстановление — pass; выбор GPX — null (файл серый), затем отказ по имени `.bin` |
| `route` | `b9b899b` | pass с оператором: реальный диалог геолокации, 2 GPS fix, `am kill`, восстановление журнала в паузе без auto-resume (2 точки), `.gpx` выбран в системном окне, имя `recharge-b1-device.gpx`, 479 байт, sha256 совпадает с отправленным, экспорт выполнен |
| Финальные проверки | `d00e230`, `b9b899b` | см. раздел «Финальные проверки» |

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
| MEDIA-PICK-01 | В приложении нет выбора изображения: обложка и галерея задаются путём | follow-up slice; пункт B1-device «выбор изображения» не закрыт |

Исправления самого gate, найденные на телефоне (`9da5300`, `bcae207`,
`aeac829`, `8161727`, `d00e230`): проверка cleartext через `dart:io`
заменена проверкой Dart-guard и APK; ожидание `resumed` после возврата;
тестовая локаль `en` для stand-наборов (система A34 — русская); заглавные
буквы в именах rendezvous (`approved.B`); release проверяет отказ от
cleartext, а не отсутствие INTERNET. Ранние красные прогоны сохранены в
evidence (`core`, `core-2`, `core-3`, `core-4`, `release`) и не засчитаны.

## Не закрыто

- Выбор изображения и его permissions (MEDIA-PICK-01): нужен отдельный
  Approved slice (picker, permissions, лимиты, тесты), затем этот пункт на
  телефоне.
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

## Evidence

`C:\Users\User\Documents\Recharge-evidence\B1-device-2026-11-03`: JSON-журналы
и логи частей (`core-5`, `release-2`, `route-3`), ранние прогоны,
host-регрессия (`host-regression-d21394c`), финальные проверки
(`final-d00e230`, `final-b9b899b`) и скрипты запуска; хэши 168 файлов — в `SHA256SUMS.txt`,
его хэш — `cb4cab20b97f1f0f15c192f6ab57c93db78bf3ee83ae0ead644af9998527f43b`.
