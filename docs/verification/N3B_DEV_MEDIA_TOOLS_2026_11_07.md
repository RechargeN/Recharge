# N3b — dev-cloud scanner/processor (ClamAV, sharp), 2026-11-07

Статус: **Review — код и IaC локально, облако не выполнялось.** Только recharge-dev-n2a01. Вариант (в) владельца: проверка через `ScannerPort`/`ProcessorPort` operator-smoke на синтетических байтах; Media/Content runtime в облаке не поднимается. Решения D-01…D-12 (лимит €5, без автоудаления, без AI moderation и третьих сторон). Push/merge не выполнялись.

## Что сделано

**Один образ, три роли** (`apps/backend/media-tools-runtime/`):

- `cloud_tools_host.ts` — из D1 stand host: тот же протокол `local_tools_protocol.ts`, `0.0.0.0:$PORT`, режим `scanner` (clamd только на 127.0.0.1) или `processor` (sharp в отдельном worker с жёстким сроком). Нет `/v1/control/*` и `/v1/selftest/*`, нет stand-исключения базы: `clean` только при `OK` на **свежей официальной** базе (≤ 7 сут по `VERSION`). Секрет сервиса — в `x-recharge-tools-token`; `Authorization` занят Google ID token для Cloud Run IAM. Логи — одна JSON-строка на запрос без байтов, hash, токенов и имён сигнатур (`bytesBucket`, `result`, `failureClass`, `dbState`, `coldStart`).
- `scanner_prepare.ts` — при старте сканера: новейший набор из зеркала, каждый файл сверяется с манифестом набора (размер + SHA-256), затем ожидание clamd. Любой сбой → host стартует без clamd → ответ `inconclusive`, после чего инстанс завершается, и Cloud Run поднимает новый со свежим набором (нужно, т.к. Cloud Run запускает инстанс при создании сервиса — ещё до первого прогона зеркала).
- `mirror_store.ts` / `publish_databases.ts` — частное зеркало официальных баз: `cvd/<sha256>.cvd` + `sets/<UTC>.json`, только create-only (`ifGenerationMatch=0`), без перезаписи и удаления (D-07); `.cld`/неполный набор останавливает job.
- `container/`: `Dockerfile` (Debian bookworm-slim по digest; Node 22.23.2, ClamAV 1.5.4 `.deb` (SHA-256 + GPG Talos `5BADCA26…6771`), sharp и его замыкание по npm SRI — всё из `media-tools.lock.json` и Functions lock; при сборке проверяется отсутствие недостающих библиотек, `clamd 1.5.4` и нативный `sharp-linux-x64`), `start.sh`, `fetch-verify.sh`, `cloudbuild.yaml` (регион, свой SA, `CLOUD_LOGGING_ONLY`).
- `scripts/package-media-tools-runtime.mjs` — локальный stage контекста сборки (замыкание импортов; Firebase/Firestore/fake/stand запрещены), тег образа = tree digest.

**Адаптеры портов в Functions:** `cloud_tools_client.ts` — `CloudToolsScanner`/`CloudToolsProcessor` поверх общего ядра, вынесенного из `local_tools_client.ts` (`scanThroughTools`/`processThroughTools`): те же проверки generation/SHA-256 источника, схема ответа, пересчёт hash вариантов, запись вариантов create-only через `ObjectBytesPort`. Привязка fail-closed: `RECHARGE_MEDIA_TOOLS=dev-cloud`, ровно `recharge-dev-n2a01`, без Emulator-переменных, URL сервисов зашиты (`https://media-{scanner,processor}-420479958348.europe-west1.run.app`). ID token — metadata server, кэш 45 мин. `media_security.test.ts`: файл в allowlist, разрешены только `node:http`/`node:https`; signed URL, delivery, `process.env`, `fetch`, `net/fs/child_process` по-прежнему запрещены. Dev-композиция Media не подключается (N3a.2 отложен).

**Terraform** (`bootstrap/dev/n3b_media_tools.tf`, `n3b_enabled=false` по умолчанию, отдельная запись N3b с проверкой commit/manifest/digest/ingress/0..1/`automaticDeletion=false`/`aiModeration=false`/срока):

- фаза 1 (digest пуст): API `cloudscheduler`; SA `media-tools-build`, `media-tools-scanner`, `media-tools-processor`, `clamav-mirror` (`deletion_policy=PREVENT`); AR `media-tools` (immutable tags, без cleanup, без платного сканирования); бакеты `recharge-dev-n2a01-clamav-mirror` и `-media-tools-build` (private, uniform, без lifecycle, PREVENT); контейнер секрета `MEDIA_TOOLS_TOKEN`; custom role зеркала create/get/list; только resource-level гранты;
- фаза 2 (digest из записи): Cloud Run `media-scanner` (1 vCPU/4 GiB, conc 2, 60 s) и `media-processor` (1 vCPU/1 GiB, conc 1, 30 s), min 0/max 1, CPU только на запрос, startup boost, ingress all + IAM (invoker — только оператор), job `clamav-mirror` (2 GiB, 900 s, 1 retry), Scheduler пн/чт 04:17 UTC.
- `scripts/check-n3b-plan.mjs` — независимый checker плана (ничего не update/replace/delete; адреса, формы, IAM, digest, нет allUsers/секретов/ключей).
- Manifest: строки владельцев `cloudRun.mediaTools`, `artifactRegistry.mediaTools`, `storage.clamavMirror`, `scheduler.clamavMirror` (Terraform, D-06); новый SHA `9ef9dd43…2f38`, синтетические записи тестов перевыпущены.
- `provider-side-effects.allowlist.json` — ожидаемые эффекты N3b и стоп-условия (сверить после каждой фазы).

## Отклонения от плана файлов (с причинами)

1. **Ingress all + IAM**, а не internal: internal недоступен ни operator-smoke с ПК, ни Functions без VPC-коннектора (платный). Совпадает с пакетом готовности §10; allUsers запрещены тестом и checker.
2. **Зеркало через freshclam из того же проверенного `.deb`**, а не cvdupdate: официальный инструмент, проверяет подписи CVD, не нужны непиненные Python-зависимости. В сканере freshclam не запускается.
3. **Расписание дважды в неделю** вместо раза: при раз в неделю `daily` под конец недели выходит за 7 суток → `inconclusive`. Рост зеркала ограничен content-addressed хранением (неизменные `main`/`bytecode` не копируются).
4. **Четыре SA** вместо трёх (scanner и processor раздельно) — меньше прав у процесса, который разбирает недоверенные изображения.
5. **Один секрет на оба сервиса**: второй фактор к IAM; у processor нет invoker на scanner.

## Найдено при первом plan (2026-11-07)

В облаке Firebase Auth были включены вход по email (ссылкой) и анонимный вход — вручную, вне Terraform; утверждённое состояние N2c: только Google. Код приложения их не использует. Решение владельца 2026-11-07: вернуть в выключенное состояние. `check-n3b-plan` разрешает ровно это одно обновление существующего ресурса и только с точным diff (три флага, только в сторону «выключено»); любое другое обновление по-прежнему запрещено.

## Проверки (локально)

| Гейт | Результат |
|---|---|
| media-tools-runtime: typecheck + tests (host scanner/processor, самоперезапуск без базы, зеркало, fetch) | 12/12 |
| scripts: `check-n3b-plan` 8/8, `package-media-tools-runtime` 4/4 | pass |
| Terraform `fmt`/`validate`/`test` (bootstrap 6 + n2c 6 + **n3b 10**) | 22/22 |
| `verify:iac:topology --require-terraform`, `verify:execution-manifest` | pass |
| Functions lint, typecheck, format, `verify:cloud-context` | pass |
| Functions unit 856 + contract 70 + integration 272 (вкл. cloud client 6/6, `media_security`) | 1198/1198 |

## Облако (не выполнено; один заход владельца)

Вход в браузере → проверка доставки бюджетного письма (guard N2b истёк) и ваше подтверждение → записи N2b/N2c/N3b → plan/checker/apply фазы 1 → секрет через stdin → Cloud Build → plan/checker/apply фазы 2 → первый запуск job зеркала → operator-smoke (чистый PNG → `clean`, EICAR из памяти → `rejected`, чужой секрет/без доступа → `inconclusive`, processor → `display`/`thumb` create-only в media-бакете, замер холодного старта) → IAM-проверка → revoke. Ничего не удаляется.

## Стоимость

Простой — €0 (min 0, CPU на запрос). Сборки — в бесплатных минутах Cloud Build; AR ≈ 0.6 ГБ на образ (free tier 0.5 ГБ, далее ≈ €0.05/мес); зеркало ≈ 0.3 ГБ + ~60 МБ на запуск без удаления (≈ €0.01–0.03/мес первые месяцы); Scheduler в бесплатных 3 jobs. В пределах €5 (D-05).
