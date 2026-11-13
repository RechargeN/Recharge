# N4a — immutable release candidate: dev, затем staging, 2026-11-13

Статус: **In progress.** План файлов `N4A-STAGING-RC-FILE-PLAN-2026-11-13.md` и решения владельца 2026-11-13 (пункты 3–13) утверждены. Production и перенос данных из Emulator не разрешены и не выполнялись. Ничего не удаляется.

## Решения владельца, применённые здесь

- Project ID staging: **`recharge-staging-y9y2y`** (выбран агентом по приоритету `recharge-staging-<суффикс>`). Проверка доступности перед созданием: `projects.describe` даёт 403 и для занятого, и для свободного ID, поэтому окончательно доступность подтверждает создание проекта в Terraform. Если ID занят, создание падает без последствий, и выбирается другой ID.
- Биллинг — тот же аккаунт, что у dev. Бюджет staging — **€5/месяц с уведомлениями. Это алерт, а не жёсткий лимит расходов** (`hardStop: false` в манифесте): Google Cloud не останавливает траты при достижении бюджета.
- В staging разворачиваются оба блока: Identity/Session, Content+Media, Notifications/push и N3b (ClamAV/sharp на Cloud Run, зеркало базы ClamAV). Образ переносится из dev по digest, без пересборки.
- Cloud Scheduler: до $0,20/месяц подтверждено (4-е и следующие задания в биллинг-аккаунте платные).
- Мобильный staging-flavor — отдельный заход N4b. Вход Google в staging владелец включает вручную в N4b. Секреты не попадают в Git и Terraform.
- App Check — режим наблюдения. TTL и любое автоматическое удаление запрещены. Политика очистки Artifact Registry не ставится, потому что это тоже автоматическое удаление.

## Сделано (код)

- **Вход без зашитого dev-проекта.** `functions/src/shared/cloud_runtime_projects.ts` — список разрешённых проектов (dev, staging; production нет). На него переведены все проверки: входы трёх кодбаз, проверка Firebase-токена, App Check (номер проекта: для dev фиксированный, для staging берётся из `.env`), привязка Session, ограничитель частоты, хранилище Media (`<project>-media`), сервисы N3b (URL по номеру проекта), проверка хранения Content.
- **Упаковщики:** проект и номер передаются параметрами (по умолчанию dev). `.env.<project>` создаётся для каждого проекта отдельно. Новый `codeTreeSha256` (код без `.env`) одинаков для dev- и staging-сборок одного RC. Проверки перед деплоем привязывают сборку к её проекту.
- **RC:** `scripts/build-release-candidate.mjs` и схема `config/release-candidate.schema.json`. В RC записываются:
  - коммит и цели (только dev и staging, `production: false`);
  - хеши дерева контрактов, правил, индексов (без TTL) и reference-данных — по объектам Git;
  - версии toolchain (Node, Terraform, провайдер google, firebase-tools, Flutter);
  - хеши lock-файлов;
  - `codeTreeSha256` трёх кодбаз, digest образа media-tools, хеш `NOTICE.md`.

  Режим `--verify` пересобирает всё и сравнивает.
- **Terraform `bootstrap/stage`:** копия dev-корня для `recharge-staging-y9y2y`, своё окружение `stage`, пакет Android `.stage`, бюджет €5. Тесты на mock-провайдере (33/33). Политика `check-n4a-plan.mjs`: только создание, только staging-проект, без прав на удаление и автоудаления, без базовых ролей и публичных участников, бюджет €5, Cloud Run 0..1 экземпляр.
- **Перенос образа:** `scripts/copy-image-by-digest.mjs` — Docker Registry v2, байт в байт, со сверкой SHA-256 каждого слоя и манифеста.
- **Общие проверки:** квитанция бюджетного письма и запись apply принимают staging (окружение `stage`).

## Облако

(заполняется по ходу: dev на RC → A34 → staging по фазам)
