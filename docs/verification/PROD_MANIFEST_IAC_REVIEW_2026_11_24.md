# Production manifest и IaC против работающего staging — review

- Дата: **2026-11-24**, база `main` = `15df1cbc`
- План пробелов 26–50, заход 3, пункт 3.4
- Итог: **production-корень сейчас не описывает то, что работает в staging**. Список ниже — что перенести. `apply` остаётся `denied`; код меняется только после решений D-03, D-04, D-09 (значения зависят от них).

## Как устроено сейчас

| | Staging | Production |
|---|---|---|
| Корень Terraform | `infra/terraform/bootstrap/stage/` (~2 000 строк, 9 файлов: Identity, runtime, Content+Media, media-tools, push, Booking, оповещения) | `infra/terraform/envs/prod/` (~300 строк, общие модули) |
| Как создан | применён по шагам N2b…N4e с решениями владельца | не применялся; `apply: denied` |
| Манифест | `environments.stage`: runtime-booking, -identity, -media, -notifications `deployed: true` | `environments.prod`: runtime-media и runtime-notifications `deployed: false` |

Вывод: production нужно строить не из `envs/prod`, а **переносом `bootstrap/stage` в `bootstrap/prod`** с параметрами production, иначе корень разойдётся с тем, что проверено на staging.

## Расхождения (из O1 B-07, B-08, B-10…B-12, сверено с кодом)

| # | Что | Staging (работает) | Production сейчас | Что сделать | Зависит от |
|---|---|---|---|---|---|
| 1 | Корень | `bootstrap/stage` | `envs/prod` | Создать `bootstrap/prod` копией stage с переменными; `envs/prod` оставить шаблоном или удалить после review | D-11 |
| 2 | Runtime-аккаунты | 4 runtime `deployed: true` с ролями | media, notifications `deployed: false`; модуль accounts не пишет ролей | Манифест prod = stage; роли из `bootstrap/stage/*.tf` | D-09 |
| 3 | API | Identity Toolkit, Secure Token, Firebase Rules, FCM, API Keys включены | нет в списке | Добавить в список API prod | — |
| 4 | Media-tools, мониторинг, SLO, backup schedule, Identity config | есть (`n3b_media_tools.tf`, `n4e_alerts.tf`, …) | нет | Перенести файлы | D-02 (пороги SLO) |
| 5 | PITR | включён | `point_in_time_recovery = false` по умолчанию | `true` | D-04 |
| 6 | Backup | ежедневно, 7 дней | нет расписания, recovery bucket выключен | ежедневно, 14 дней (рекомендация D-04); журнал удалений в отдельном bucket | D-04 |
| 7 | Бюджет | €5, пороги 50/75/90/100, Pub/Sub, 1 адрес | €150 Proposed, каналов нет, Pub/Sub не передан | Сумма и два адресата | D-01, D-03 |
| 8 | Квоты экземпляров | 1 (чтение — concurrency 10) | `null` | Значения из D-03 | D-03 |
| 9 | Secrets | `DEV_AUTH_INGRESS_HMAC`, `MEDIA_TOOLS_TOKEN` по одной версии | `secretReferences: []` | Объявить ссылки (значения вводит владелец, P-25) | — |
| 10 | Rules, индексы, TTL | ещё не выпущены (runbook `firestore-rules-indexes-ttl-release.md`) | — | Тот же порядок A/B/C | 3.3 |
| 11 | App Check | observe, debug-токен A34 | `null` | Play Integrity + enforce для production | D-06, P-26 |
| 12 | Guard | `dataScope == synthetic`, `marketActivation == false` | тот же guard | Отдельный guard production с реальными данными — только после D-07/D-08 | D-07, D-08, D-11 |
| 13 | WIF | — | ждёт immutable subject; в GitHub `use_immutable_subject: false` | Включить immutable subject в GitHub до P-24 | — |
| 14 | Kill switch | `N4C_BOOKING_CREATE_DISABLE` через redeploy | `booking.create.incidentDisable` | Один механизм в обоих | D-03 |
| 15 | Код | `cloud_runtime_projects.ts`, `cloud_environment.dart`, RC допускают только dev и staging | — | Добавить production только в P-13, после решений | D-11 |

## Что можно сделать без решений владельца

- Пункт 3 (API) и пункт 9 (объявление секретов без значений) — механические, но меняют production-корень, который сейчас не применяется. Делать в одном PR с пунктом 1, чтобы не править `envs/prod`, который будет заменён.

## Оценка

Перенос `bootstrap/stage` → `bootstrap/prod` с тестами Terraform и проверкой манифеста — 2–3 дня работы агента после решений D-03, D-04, D-09, D-11. Применение — отдельные разрешения P-15…P-32.
