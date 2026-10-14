# D1-L — запуски Linux gate

Норматив: [MEDIA_D1_REAL_TOOLS_AMENDMENT.md](../../../product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md)
§15. Workflow `.github/workflows/backend-d1-linux.yml` запускается только push в
`codex/recharge-integration` с изменением workflow или
`apps/backend/ci/d1-linux-stage.json`. Skip, timeout и inconclusive не
засчитываются. Зелёный `inspect` не делает D1 зелёным: D1 закрывает только
зелёный `test`, включая EICAR (§1, §12).

## Попытка 1 — failed

| Поле | Значение |
|---|---|
| Run | `38246774477`, https://github.com/RechargeN/Recharge/actions/runs/38246774477 |
| Дата | 2026-10-12 12:04:53Z, триггер push |
| SHA | `e87883f` (`codex/recharge-integration`) |
| Стадия | `inspect` |
| Итог | failed за 34 с на шаге «D1 Linux gate (stage from apps/backend/ci/d1-linux-stage.json)» |
| Что прошло | checkout, Node, JDK, отказ от cloud-контекста, `npm ci`; ClamAV `.deb`: SHA-256 и GPG (good signature, ключ `5BADCA2665EF59DCF8A23D8B707F0DB480836771`) |
| Ошибка | `clamd --version exited 1: ERROR: Can't open/parse the config file /usr/local/etc/clamd.conf` |
| Причина | clamd 1.5.4 разбирает конфигурацию до ответа на `--version`; у распакованного `.deb` нет конфигурации по умолчанию. Воспроизведено 2026-10-14 на Windows-сборке той же версии: без конфигурации — та же ошибка, с `--config-file` проектного `clamdConf` — `ClamAV 1.5.4` |
| Не дошло до | `freshclam`, официальные базы, отчёт `inspect`, стадия `test`, EICAR |

Дефекты: DEF-01, DEF-02 в
[M1_DEFECT_REGISTER.md](../../../verification/M1_DEFECT_REGISTER.md).

## Попытка 2 — failed (проверка версии исправлена)

| Поле | Значение |
|---|---|
| Run | `38547611633`, https://github.com/RechargeN/Recharge/actions/runs/38547611633 |
| Дата | 2026-10-14 10:09:44Z, триггер push `e87883f..dd0f58b` (разрешение владельца на один push) |
| SHA | `dd0f58b` (`codex/recharge-integration`) |
| Стадия | `inspect` |
| Итог | failed за 33 с на шаге «D1 Linux gate» |
| ClamAV `.deb` | артефакт `clamav-linux` 105 819 396 Б, SHA-256 `28d6efc5b4423e7830c3559339552eb53870a9eac51ac4efb37d60530d329886`; подпись 801 Б, SHA-256 `1fa7a94df398345b89aeaf8eb4098834946296560266ff17b4cd05f9d8679a15`; ключ Talos 3858 Б, SHA-256 `5bfca75f112f04b89cd992f5f925018e8dfc28e0e7f6e33f6a4c33ed9e29d911`; GPG good signature, ключ `5BADCA2665EF59DCF8A23D8B707F0DB480836771` |
| Проверка версии (DEF-01) | **прошла**: `ClamAV 1.5.4`; certs `/tmp/Recharge/tools/clamav-1.5.4-linux/usr/local/etc/certs` |
| `freshclam` | `daily` remote version 28153 скачан во временный каталог; проверочная загрузка: «Failed to create a new code-signature verifier: Can't verify: Invalid certs directory '/usr/local/etc/certs'» → «Broken or not a CVD file» → «Database test FAILED», exit 8 |
| Реакция гейта | каталог баз перенесён в `_rejected` (по §15.2), гейт остановлен |
| Не получено | `main`, `bytecode`, `sigtool --info`, SHA-256 баз, тексты `COPYING`/уведомлений, отчёт `inspect`; стадия `test` и EICAR не запускались |
| Причина (гипотеза) | каталог сертификатов задан только директивой `CVDCertsDirectory` в `freshclam.conf`; проверочная загрузка базы берёт путь по умолчанию. `freshclam` 1.5.4 принимает также `--cvdcertsdir=DIR` и переменную `CVD_CERTS_DIR` (по `freshclam.exe --help` Windows-сборки той же версии). Не проверено на Linux |

Дефекты: DEF-01 — подтверждён проверкой версии; новый DEF-08 — сертификаты
для проверки баз.

### Backend R0 на том же push

Run `38547610509` (`dd0f58b`): failed на обоих runner'ах (`ubuntu-24.04`,
`windows-2025`), шаг «Audit production dependency graph»
(`npm audit --omit=dev --audit-level=high`); следующие шаги не выполнялись.
Отчёт: 10 уязвимостей (1 critical, 2 high, 7 moderate): `proxy-addr`
1.1.0–2.0.7 critical (GHSA-jqcg-44mw-7w3h), `@grpc/grpc-js` 1.14.0–1.14.4 high
(GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4), `brace-expansion` 2.0.0–2.1.6 high
(GHSA-q2hr-2g5m-vwhr, GHSA-qhr7-859c-m2p7, GHSA-6j4f-fj2g-mc7p), `qs` и `uuid`
moderate, цепочка `gaxios`/`teeny-request`/`@google-cloud/storage`/
`firebase-admin` (исправление npm предлагает через `firebase-admin@14.5.0`, вне
заявленного диапазона). Учитывается отдельно (DEF-05), не D1.

### Исправление попытки 2 (до push)

Исправление: `clamdVersion()` в `apps/backend/scripts/media-tools-linux.mjs`
пишет `clamdConf` во временный каталог, вызывает
`clamd --config-file=<conf> --version` и удаляет каталог и при ошибке; ошибка
сохраняет код выхода и вывод. Локальная проверка до push: unit
`media-tools-linux.test.mjs` 16/16 (из них 4 новых); `clamdVersion()` на
настоящем `clamd.exe` 1.5.4 (Windows) — `ClamAV 1.5.4`, временных каталогов
после успеха и после ошибки нет. Также 2026-10-14 на этом ПК: `format:check`,
`lint`, `typecheck`, `verify:toolchain`, `test:media-tools` — pass; Windows
D1-гейт `stand-d1-gate.mjs --yes` — pass (Windows-path модуль Linux не
загружает). Это не Linux evidence.

## Попытка 3 — inspect success (исправление DEF-08)

| Поле | Значение |
|---|---|
| Run | `38554932983`, https://github.com/RechargeN/Recharge/actions/runs/38554932983 |
| Дата | 2026-10-14 11:12:22Z, push `dd0f58b..3c32e1c` (разрешение владельца) |
| SHA | `3c32e1c` |
| Стадия | `inspect`; итог **success**: «every database verified and carries COPYING»; тесты не запускались |
| ClamAV `.deb` | 105 819 396 Б, SHA-256 `28d6efc5b4423e7830c3559339552eb53870a9eac51ac4efb37d60530d329886`; GPG good, ключ `5BADCA2665EF59DCF8A23D8B707F0DB480836771`; `clamd` — ClamAV 1.5.4 |
| Сертификат CVD | `usr/local/etc/certs/clamav.crt` из `.deb`, 1976 Б, SHA-256 `60200e4b4b1b1b7257bb4550487aeb142034341f3300a8526e77a3134a940e9d` |
| `freshclam` | `daily`, `main`, `bytecode`: «Database test passed» для каждой; всего 112 824 212 Б из 400 000 000 |

| База | Версия | Сборка | Сигнатур | Проверка подписи (`sigtool --info`) | Байт | SHA-256 | COPYING |
|---|---|---|---|---|---|---|---|
| bytecode.cvd | 339 | 11 Sep 2025 08:29 -0400 | 80 | OK | 281 702 | `6d4aa01f219e988060fc419f495d07f27e0cdf1a2cccc065971da922c76f7ffb` | есть |
| daily.cvd | 28153 | 14 Oct 2026 06:24 +0000 | 355 765 | OK | 23 442 609 | `19e1680c80116ac7c53d87572b4df8746bd976b774da082a1be962cda8be50bb` | есть |
| main.cvd | 63 | 16 Dec 2025 23:18 +0000 | 3 287 027 | OK | 89 072 577 | `0b2182d229f46981ec8f535382222f7c9dfdd656b250ad47988b910a8d302365` | есть |

Лицензионные уведомления баз: в каждой из трёх баз один файл `COPYING`, 17 992 Б,
SHA-256 `32b1062f7da84967e7019d01ab805935caa7ab7321a7ced0e30ebe75e5df1670` (одинаковый);
текст — GNU General Public License, Version 2, June 1991. Других файлов
уведомлений (`LICENSE*`, `NOTICE*`, `README*`) в базах нет. Полный текст — в
step summary run.

Пакеты sharp для Linux: `@img/sharp-linux-x64@0.35.5` (Apache-2.0) — `LICENSE`
10 273 Б, SHA-256 `73ba74dfaa520b49a401b5d21459a8523a146f3b7518a833eea5efa85130bf68`;
`@img/sharp-libvips-linux-x64@1.3.4` (LGPL-3.0-or-later) — **ни одного файла
уведомлений не записано**: `npmNotices()` ищет только в корне пакета, а там их
нет. §15.5 требует записать имена, размеры и SHA-256 уведомлений пакета — пробел
открыт (DEF-09) и выносится владельцу до стадии `test`.

Backend R0 на том же push: run `38554933834` — failed на обоих runner (шаг
«Audit production dependency graph», 10 уязвимостей: 1 critical, 2 high, 7
moderate — без изменений, DEF-05).

### Исправление попытки 3 (до push)

Исправление: сертификат проверки CVD берётся только из проверенного `.deb`
(`usr/local/etc/certs/clamav.crt`): каталог и файл обязаны быть обычными (не
ссылкой и не junction), читаемыми и непустыми, иначе гейт останавливается до
`freshclam` и до любого скачивания (`cvdCerts()`). `freshclam` получает
`CVD_CERTS_DIR` (единственная форма, которую знает `libclamav` 1.5.4) и прежнюю
директиву `CVDCertsDirectory` (`freshclamInvocation()`); `--cvdcertsdir` не
добавлен; `sigtool` и `clamd` не менялись; TLS скачивания не менялся. SHA-256 и
размер `clamav.crt` попадают в журнал и в отчёт `inspect`.

Локальная проверка до push (2026-10-14, этот ПК): `media-tools-linux.test.mjs`
20/20 (4 новых: сертификат из `.deb`; отказ при отсутствии каталога, файла,
пустом файле, файле-каталоге и каталоге-junction; запуск `freshclam` с
`CVD_CERTS_DIR` и директивой без `--cvdcertsdir`; статическая проверка, что
`freshclam` запускается только через `freshclamInvocation()`);
`format:check`, `lint`, `typecheck`, `verify:toolchain`, `test:media-tools`,
`build` — pass; Windows D1-гейт — pass. Это не Linux evidence.

## Решение владельца после попытки 3

2026-10-14: отчёт `inspect` принят; пробел DEF-09 принят явно (только
`@img/sharp-libvips-linux-x64` 1.3.4); стадия переключена на `test` отдельным
коммитом; push разрешён владельцем.

## Попытка 4 — test, failed на самопроверке cgroup

| Поле | Значение |
|---|---|
| Run | `38555622591`, https://github.com/RechargeN/Recharge/actions/runs/38555622591 |
| Дата | 2026-10-14 11:18:19Z, push `3c32e1c..db3121f` (разрешение владельца) |
| SHA | `db3121f`, стадия `test` |
| Прошло | ClamAV `.deb` и сертификат (как в попытке 3); `freshclam` — три базы, «Database test passed»; inspect без открытых пунктов; build; «D1 unit tests and the Media guard» 37/37, skipped 0; самопроверка cgroup: L1 ok, L6 ok |
| Ошибка | сразу после запроса пробы L2 (`allocate` 1024 MiB при `MemoryMax` 768 MiB): `stand-d1-linux-gate: socket hang up`; L2, L3, L4 не записаны; в `finally` L5 ok (scope остановлены, порты закрыты) |
| Не дошло до | запуск инструментов с официальными базами, tool tests, EICAR, путь Storage |
| Гипотеза (не подтверждена) | на Linux превышение `MemoryMax` вызывает OOM-kill; у systemd для unit по умолчанию `DefaultOOMPolicy=stop` — после OOM-kill останавливается весь scope вместе с хостом сервиса, соединение обрывается. Scope создаются без `OOMPolicy`. Журнал systemd/ядра в выводе гейта не сохраняется, поэтому причина не доказана |

Дефект: DEF-10. Backend R0 run `38555622810` — как прежде (DEF-05).

## Попытка 5 — не запущена (исправление DEF-10, вариант А)

Исправление (план одобрен владельцем 2026-10-14): scope сервиса и `clamd`
создаются с `-p OOMPolicy=continue` — OOM-kill завершает только процесс сверх
лимита, а не весь scope (по умолчанию systemd `DefaultOOMPolicy=stop`).
Самопроверка: ошибка пробы L2 или L3 не роняет гейт, а записывается как
проваленная проверка с фактами (scope активен, `oom_kill`, пик памяти, жив ли
хост) и выдержкой `journalctl` по scope и строкам ядра об OOM; при мёртвом хосте
L3 записывается проваленной с причиной, не пропущенной; L4 выполняется
независимо. Диагностика покажет, сработало ли именно `OOMPolicy`.

Предварительная вычитка оставшегося пути `test` (разрешение владельца на серию
push в рамках D1, 2026-10-14): `clamd` с официальными базами получал каталог
сертификатов только директивой в `clamd.conf`, а загрузку и проверку CVD делает
та же `libclamav`, что проигнорировала директиву в DEF-08. Добавлено
`CVD_CERTS_DIR` в окружение `clamd` (`clamdLaunchEnv()`), директива сохранена.
Числа гейта сверены с тестами: в tool tests ровно 2 пропуска «L1 only» в
режиме official; путь Storage — 7 тестов без пропусков.

Локально (2026-10-14, этот ПК): `media-tools-linux.test.mjs` 26/26 (+1: окружение `clamd`) (новые:
`OOMPolicy=continue` в аргументах scope; вердикт L2 при обрыве соединения —
проваленная проверка с фактами; L2 проходит только при ограниченном воркере и
живом хосте; ошибка пробы становится данными; аргументы `journalctl`;
статическая проверка, что L2 и L3 идут через `attemptProbe`); `format:check`,
`lint`, `typecheck`, `verify:toolchain`, `test:media-tools`, `build` — pass;
Windows D1-гейт — pass. Это не Linux evidence.
