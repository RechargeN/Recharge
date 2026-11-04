# N1 — подготовка Firebase dev, 2026-11-04

Этап программы «N1: cloud-readiness, без облачных изменений». Зависимости
выполнены: R1-M2 Done (`8e35fa3`), B1-device для Android Done (`22280a5`).
Проверенный candidate — `dd74d90`, чистое дерево; репозиторий этапом не
менялся, облачных чтений и изменений не было.

## Итог

**GO для docs-only подготовки, NO-GO для cloud execution.** Go/no-go пакет и
точный список будущих разрешений подготовлены Codex:
`C:\Users\User\Documents\Codex\2026-11-04\39-n1-text-n1-firebase-dev\outputs`
(`N1-GO-NO-GO-2026-11-04.md`, `N1-FUTURE-AUTHORIZATIONS.md`,
`N1-MINIMAL-DEV-PROFILE.md`, `N1-FLAG-RECONCILIATION.md`,
`N1-NEXT-CHECKPOINT.md`); хэш его `SHA256SUMS.txt` —
`259333eeacd0e11e67841850025589d4f3c083fd8cccd78d91cc79080e58154d`.
Ключевые факты пакета перепроверены по `dd74d90`: SHA execution manifest
`ceaac0cd…bf17c`, dev `guardrailMonthlyEur: 25` с пустыми каналами,
`.github/workflows/backend-deploy.yml`, на который ссылается WIF, отсутствует.

## Решения владельца 2026-11-04

- Минимальный dev для тестов: synthetic-only, до 500 объектов, scale-to-zero.
- Целевой бюджет dev — **€5 в месяц**, пороги €2.50 / €3.75 / €4.50 / €5.
  Согласовано в репозитории тем же днём: execution manifest и checker теперь
  требуют dev `guardrailMonthlyEur: 5`; contract test отвергает прежние €25;
  схема (1…100000) не менялась. SHA manifest — `3ee66a31…3f02` для рабочей
  копии Windows (CRLF) и `a55b9568…d5df` для LF-блоба в Git (прежде
  `ceaac0cd…bf17c` / `a18f4ea5…c7b3`). Будущая authorization record для
  Terraform должна нести SHA той копии, из которой запускается plan. Сумма —
  порог уведомлений, не разрешение расходов.
- Адрес владельца для dev budget/incident уведомлений записан в пакете N1;
  канал в облаке не создан, доставка и подтверждение не проверены, запасной
  контакт эскалации не назначен.

## Что открыто до cloud

Матрица A01–A16 пакета; каждое действие разрешается отдельно, с точным
project ID, SHA, хэшами, операциями, сроком и стоп-условиями. Первое
возможное — A01, credentialed read-only discovery (N2a). Также: поимённая disposition 28 флагов кода вне manifest,
deploy workflow и защита main для WIF, per-identity IAM records, state
custody и recovery, работающие cost/incident controls. iOS, Legal/Privacy и
production gates остаются самостоятельными.
