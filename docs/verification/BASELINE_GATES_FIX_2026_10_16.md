# Исправление baseline-гейтов backend, 2026-10-16

База: `codex/recharge-integration` @ `a1fcde5`. Ветка `claude/baseline-gates-fix`.
Поручение владельца: исправить два baseline-гейта отдельным заходом (не внутри
K3), затем проверить K3.

## Что было красным и почему

Оба гейта падали на `a1fcde5` до K3 одинаково (проверено на чистом worktree).

**`verify:execution-manifest`** — 9 нарушений: коллекции `libraryEntries`,
`moderationRemoderationQueue`, `trustSafetyReports`, `reviews`,
`contentSafetyHolds`, `catalogSafetyHolds`, `bookingSafetyHolds` получили
индексы в `firestore.indexes.json` (коммиты `8f26a98` Library и `d4e3971`
H/K1/K2), но не попали в `execution-manifest.json` и не имели явного deny в
`firestore.rules`; индексы `bookings` и `contentSubmissions` в манифесте
расходились с файлом индексов.

**`verify:content-persistence:layout`** — скрипт останавливается на первом
нарушении, поэтому остальные были скрыты. Последовательно вскрылись:

1. `modules/content/infrastructure/content_safety_commands.ts` (K2) — только
   type-only импорт `Firestore`, но не был в списке разрешённых адаптеров;
2. внешние пользователи хранилища Content без записи в одобренном списке:
   `library/firestore_library_service.ts`, `library/library_privacy_task_handler.ts`,
   `moderation/application/k1_workflows.ts`, `moderation/application/report_service.ts`,
   `reviews/firestore_review_service.ts`, `reviews/review_target.ts`,
   `trust_safety/firestore_safety_service.ts`;
3. третий составной индекс Content `contentSubmissions (state, marketId, typeId)`
   — нужен очереди модерации K1 (`content_moderation_adapter.reviewQueue`).

## Что сделано

- `firestore.rules`: явный deny для семи коллекций (клиентский доступ и так
  был закрыт правилом по умолчанию; теперь он явный, как у остальных).
- `execution-manifest.json`: семь записей (`clientAccess: deny`,
  `owner: firebase_cli`, TTL и индексы из `firestore.indexes.json`);
  синхронизированы индексы `bookings` и `contentSubmissions`. Diff только
  добавочный, без переформатирования файла.
- `verify-content-persistence-layout.mjs`: `content_safety_commands.ts` в
  списке Emulator-адаптеров; семь внешних пользователей с точными символами
  (пятеро — только guard Emulator-контекста; Library, Reviews и Trust & Safety
  ещё и **читают** указатели, ревизии и черновики Content — записи в
  коллекции Content нет ни у одного, принцип единственного писателя
  соблюдён); третий индекс Content одобрен с ссылкой на запрос.

**На решение владельца:** расширение списков гейта узаконивает фактическое
поведение уже принятых слайсов. Прямые чтения хранилища Content из Library,
Reviews и Trust & Safety (вместо порта чтения Content, как у Catalog) — долг
архитектуры; при желании — отдельный bounded-слайс на перенос за порт.

## Проверки (2026-10-16, этот ПК)

Toolchain: Node 22.23.2, Java `Temurin-21.0.12+8 (build 21.0.12+8-LTS)` —
проверено в журнале прогона. Первый прогон по ошибке взял системную Java
21.0.12.1 (запись `PATH` в виде `C:/…` в Git Bash), он не засчитан и
повторён.

| Гейт | Итог |
|---|---|
| build, format:check, lint, typecheck | pass |
| test:unit / test:contract / test:r1:integration | 735/735 / 55/55 / 254/254 |
| verify:execution-manifest | pass: 62 коллекции, 13 флагов |
| verify:content-persistence:layout | pass: 3 индекса Content, SDK в 5 Emulator-файлах, 17 одобренных внешних пользователей; негативный self-test 1/1 |
| verify:r1 layout/config/exports, verify:toolchain, test:emulator:runner, test:stand | pass |
| test:emulator (полный) | 12/12 групп PASS: 284 pass, 0 fail, 1 skip — Library «real Flutter repositories synchronize…» (`RECHARGE_G_MOBILE=1`, отдельный клиентский прогон Library; не относится к этим изменениям) |

## Поправка 2026-10-17: два гейта в таблице выше не были зелёными

Сводка прогона писала `rc` команды `date`, а не гейта (`$(date …)` в строке
`echo` раскрывался раньше `$?`). Повторная проверка по самим журналам:

- **`format:check` — fail** на `36fabec` и раньше: 11 однострочных индексов
  `firestore.indexes.json` из `d4e3971` не в стиле Prettier. Исправлено
  `prettier --write` (JSON семантически идентичен: 27 индексов, 14 overrides).
- **`verify:toolchain` — fail**: «terraform version command failed». Закреплённого
  Terraform 1.15.9 на этом ПК нет (каталог `.r0-tools` в worktree `g-library-sync`
  больше не содержит `terraform/`, архива в кэше нет). Это окружение, не код;
  локально зелёным станет после `scripts/install-terraform.mjs` (загрузка с
  проверкой SHA-256 и GPG — отдельное разрешение владельца).
- **Инвентарь границ mobile устарел** (`--check-output`: 619 → 620 файлов) — в
  этот прогон не входил; перегенерирован, нарушений 0, исключений 71/71.

Остальные строки таблицы подтверждены по журналам (счётчики тестов, группы
Emulator, сообщения verify-скриптов). Скрипт сводки исправлен: `rc` берётся
сразу после команды.
