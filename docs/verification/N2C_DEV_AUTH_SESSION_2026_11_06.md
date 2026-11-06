# N2c — dev серверный Auth/Session в recharge-dev-n2a01, 2026-11-06

Статус: **Review**. Работает в dev на Samsung A34; открыты проверки владельца на устройстве (выход, перезапуск офлайн, отмена входа). Только recharge-dev-n2a01 (420479958348), синтетические данные. Push/merge, stage/prod, enforcement App Check и N3a не выполнялись.

## Решения владельца

- App Check dev: SDK debug provider на A34, сервер в observe mode, enforcement выключен; debug token регистрирует владелец (не в чат/Git/state). Play Integrity с установкой через Play — открытый gate перед stage/release.
- Firebase Auth как Identity Platform; Google provider включён владельцем в консоли (OAuth client secret не в Terraform state); API key Android ограничен пакетом, debug SHA-1 и четырьмя клиентскими Firebase API.
- Functions деплоит только Firebase CLI (`n2c-identity-runtime/firebase.n2c.json`, codebase `n2c-identity`); Terraform — инфраструктура и IAM.
- `roles/editor` у App Engine default SA снят (выдан Google автоматически); `roles/editor` у Google APIs Service Agent — записанное исключение (выдан `service-agent-manager`).
- Модель ролей: ADR 0023 (User = Creator, Professional Page как членство, Admin); реализация — отдельный срез.
- Вход держится как в массовых приложениях: стирается только при явном отказе.

## Облако (фактически)

| Шаг | Итог |
|---|---|
| Read-only инвентаризация + refresh-only plan N2b | drift только вычисляемых полей Firestore |
| Plan/apply N2c (`97b1338`) | 20 added, 0 changed, 0 destroyed |
| IAM после apply | Editor у appspot SA снят с разрешения; 19 привязок, стоп-условий нет |
| Секрет `DEV_AUTH_INGRESS_HMAC` | версия 1, значение не выводилось и не сохранялось |
| Plan/apply исправления (`76dd3a6`) | `artifactregistry.writer` на репозитории `gcf-artifacts` (условие на `resource.name` в project-level IAM Artifact Registry не учитывает): 1 added, 1 destroyed |
| Deploy (Firebase CLI) | 5 функций ACTIVE, max 1 экземпляр, `runtime-identity`, секрет v1, cleanup policy `gcf-artifacts` 1 день |
| Включение runtime | `N2C_DEV_AUTH_ENABLED=true`; запросы с неверным токеном → 401 |

Побочные эффекты (Google/Firebase CLI) записаны в `provider-side-effects.allowlist.json` (`n2c`). ADC отзывался после каждого запуска.

## Устройство (A34)

Вход через Google → Firebase → `establishIdentitySessionV1` 200 (2,1 с; App Check observe `missing`). Новый аккаунт — `User` без проверок (по дизайну). Найдено и исправлено:

1. Окно выбора аккаунта (`inactive`) сбрасывало только что созданную сессию — `26cc169`.
2. Холодный старт без сети (после Doze) стирал сессию и SDK-пользователя; снимок прав ~1 ч истекал без тихого обновления — `a25e532`, `7055882`: стирание только на явный отказ, тихое обновление до истечения, автоповтор 2/5/15/30/60 с, вход сохраняется в фоне.

## Проверки

Flutter: analyze 0, boundary 0 нарушений (69/71), полный набор 2296 passed / 83 skipped. Terraform bootstrap: validate, тесты 12/12, `verify:iac:topology` PASS. Скрипты N2c (checker plan, stage, predeploy): 20/20. Backend unit 843/843, security+contract+identity integration 112/112.

## Открыто

Проверки владельца на A34 (выход/revoke, перезапуск офлайн → восстановление при появлении сети, отмена входа); Play Integrity; iOS; реализация ADR 0023; N3a (dev Storage adapter) и N3b (scanner/processor) — заблокированы до N2c Done. Guard квитанции бюджета N2b истёк 2026-11-06 12:11 UTC: следующий Terraform plan требует новой проверки доставки бюджета.
