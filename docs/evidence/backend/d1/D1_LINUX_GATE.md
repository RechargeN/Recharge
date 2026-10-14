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

## Попытка 2 — не запущена

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

Run, SHA и итог записываются сюда после отдельного разрешения на push и CI.
