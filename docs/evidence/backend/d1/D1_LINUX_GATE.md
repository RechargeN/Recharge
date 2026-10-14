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
