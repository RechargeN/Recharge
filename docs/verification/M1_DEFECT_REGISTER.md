# Release M1 — учёт дефектов P1/P2

Заведён 2026-10-14 в заходе 1 пересмотра M1
([реестр критериев](M1_REOPEN_REGISTER.md)). До этого учёта P1/P2 не было: в M1
была только самооценка «открытых дефектов M1 нет».

Шкала приоритетов принята владельцем 2026-10-14 (Р-08):

- **P1 — блокирующий дефект:** нарушает обязательный критерий, теряет данные,
  ослабляет authority/безопасность или даёт ложный зелёный гейт;
- **P2 — существенное нарушение критерия:** неверное поведение в scope при
  наличии обхода, или расхождение документа и факта в обязательном evidence;
- **P3 — неблокирующее улучшение:** долг UX/документации вне обязательных
  критериев.

Приоритеты ниже пересчитаны по решениям 2026-10-14 (Р-06, Р-09, Р-11).

Запись закрывается только с доказательством: исправление (SHA), повторная
проверка (команда, SHA, журнал) и кто проверил. Решение владельца об
исключении закрывает запись как «принято», а не «исправлено».

| ID | Дефект | Доказательство | Приоритет (предв.) | Исправление | Повторная проверка | Состояние |
|---|---|---|---|---|---|---|
| DEF-01 | Linux gate D1 падает на стадии inspect: `media-tools-linux.mjs:132` вызывает `clamd --version` без файла конфигурации, у распакованного .deb нет `/usr/local/etc/clamd.conf` | GitHub run `38246774477`, `e87883f`, 2026-10-12, шаг «D1 Linux gate» | P1 для D1 (обязательный гейт); вне M1 по Р-06 А | заход 2: `clamdVersion()` пишет `clamdConf` и передаёт `--config-file`; временный каталог удаляется и при ошибке (ветка `claude/d1-linux-fix`) | локально: unit 16/16, настоящий `clamd.exe` 1.5.4 → `ClamAV 1.5.4`. Нужно: Linux `inspect` подтверждает проверку версии (тогда — «исправлен и подтверждён проверкой версии»); D1 закрывает только зелёный `test` с EICAR | исправлен (`dd0f58b`) и подтверждён проверкой версии на Linux: run `38547611633` — `ClamAV 1.5.4`. Linux gate D1 зелёный в run `38567123384` (`83e05cd`) |
| DEF-02 | Документы D1 не отражают запуск и падение Linux gate: §12 пишет, что runner не запускается | `MEDIA_D1_REAL_TOOLS_AMENDMENT.md` §12, §15.8; LAUNCH_STATUS D1 | P2 | заход 2: D1 §12, §15.8 и [D1_LINUX_GATE.md](../evidence/backend/d1/D1_LINUX_GATE.md) записывают попытку 1; строка D1 в LAUNCH_STATUS | закрывается после сверки с evidence попытки 2 (run, SHA, итог) | закрыт: D1 §12, §15.8 и [D1_LINUX_GATE.md](../evidence/backend/d1/D1_LINUX_GATE.md) записывают обе попытки с run, SHA и итогом |
| DEF-03 | Форма Create допускает черновики, которые сервер отклоняет общим `validation_failed`; пользователь не видит поле. Place 10, Activity 10 (+8 граничных отказов), Rental 9, Collection 8 случаев | `*_create_compat.json`, §5.7 D3.1–D3.4 | P2: корректные черновики проходят (обход есть), но обязателен к закрытию для M1 по Р-09 | `4e82352`; тестовые DI-регистрации `5b3060f`, `b91e819` | readiness fixtures, CreatePage widgets, D3.1 полный повтор и D3.2–D3.4; [журналы и пределы](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md), проверил Codex 2026-10-14 | закрыт в scope захода 3; обязательные финальные SHA-гейты остаются |
| DEF-04 | Ошибочная привязка binding rollback к D4.1 | прежняя таблица M1_ACCEPTANCE | P2 | заход 5: ссылка исправлена на B1; import rollback выделен отдельно | native B1 и host B1 на `7cb07fa`, [заход 4](../evidence/backend/m1/M1_STAGE4_ADAPTERS_CREATE.md) | закрыт; независимое ревью финальных документов pass |
| DEF-05 | Backend R0 npm audit blocks the gate; historical production and current dev-CLI findings | Historical runs retained below; 2026-10-17: CLI 15.34.0, production high/critical 0, full graph 3 high from GHSA-vfj7-8cjw-p6xm | Blocking for R0; outside accepted M1 | Compatible security patches + CLI upgrade; time-limited exception proposed, not activated | Strict production audit exit 0; policy tests and live local review; final 21–26 evidence linked below | Historical local risk accepted through 2026-11-16 00:00 UTC; 2026-10-26 strict audits pass without exception. Global/CI proposal remains inactive; see follow-up below |
| DEF-08 | `freshclam` не проверяет скачанную базу на Linux: проверочная загрузка ищет сертификаты в `/usr/local/etc/certs`, директива `CVDCertsDirectory` в `freshclam.conf` до неё не доходит; гейт отклоняет базы | run `38547611633`, `dd0f58b`, 2026-10-14 | P1 для D1 (блокирует `inspect`); вне M1 по Р-06 А | план одобрен 2026-10-14, реализован в ветке `claude/d1-linux-fix`: каталог из проверенного `.deb` обязателен (fail closed до `freshclam`), `freshclam` получает `CVD_CERTS_DIR` — `libclamav` 1.5.4 знает только переменную, не директиву; `--cvdcertsdir` не добавляется без подтверждённой необходимости; TLS не меняется | Linux `inspect` run `38554932983` на `3c32e1c`: «Database test passed» для `daily`, `main`, `bytecode`; `sigtool --info` — OK для всех трёх | исправлен (`3c32e1c`) и подтверждён на Linux (`inspect` и `test`, run `38567123384`) |
| DEF-09 | Отчёт `inspect` не записывает ни одного файла уведомлений `@img/sharp-libvips-linux-x64@1.3.4` (LGPL-3.0-or-later): `npmNotices()` ищет только в корне пакета; §15.5 требует имена, размеры и SHA-256 уведомлений этого пакета | run `38554932983`, `3c32e1c`, раздел «Linux sharp packages» | P2 для D1 (неполный обязательный отчёт); вне M1 по Р-06 А | пробел принят владельцем 2026-10-14 как исключение для этого пакета и версии | решение записано в D1 §15.8 | закрыт как «принято», не «исправлено» |
| DEF-10 | Самопроверка cgroup L2 на Linux обрывает соединение с сервисом (`socket hang up`): гейт падает до L3/L4, tool tests и EICAR; ошибка L2 не превращается в проверку с фактами | run `38555622591`, `db3121f`, стадия `test` | P1 для D1 (блокирует `test`); вне M1 по Р-06 А | вариант А одобрен 2026-10-14: `OOMPolicy=continue` для scope и диагностика L2/L3 с фактами и journal (ветка `claude/d1-linux-fix`) | Linux run `38565997591` (`c50dc72`): L2 ok (`oomKills` 1, хост жив), L3 ok | исправлен и подтверждён на Linux (run `38567123384`) |
| DEF-11 | Самопроверка L4 на Linux не соответствует J4: ограничивала память 16 MiB вместо лимита процессов 1; `node` помещается и продолжает работать | run `38565997591`, `c50dc72` | P1 для D1 (блокирует `test`); вне M1 по Р-06 А | `l4Limits`: `TasksMax` 1, `MemoryMax` 64 MiB (ветка `claude/d1-linux-fix`) | Linux run `38567123384` (`83e05cd`): L4 ok — процесс не стартовал | исправлен и подтверждён на Linux |
| DEF-07 | Существующий тест workflow в `media-tools-linux.test.mjs` читает YAML сырым текстом и падает на CRLF-checkout (Windows, `core.autocrlf=true`); на LF-checkout и на Linux runner проходит | 2026-10-14, свежий worktree `claude/d1-linux-fix`: 15/16 до перевыгрузки файла с LF, 16/16 после; на worktree 7275 (LF) 12/12 | P3 | отдельный слайс (нормализация переводов строк в тесте) | — | открыт |
| DEF-06 | Не записано отдельное основание реализации D4.1 в M1 | checklist §8 и D4.1 | P2 (процесс) | [прямое основание и хронология](../evidence/backend/m1/M1_D4_1_OWNER_BASIS.md); код 3b отделён от docs 3c и текущей приёмки | проверены оригинальные human UUID, ancestry и docs-only diff; независимый reviewer подтвердил | закрыт |

## Дефекты проверки, обнаруженные при завершении захода 3

| ID | Приоритет | Дефект | Исправление и повторная проверка | Состояние |
|---|---|---|---|---|
| M1-ST3-01 | P2 | После чтения валюты из CreateRuntimeDefaults два Place UI boot не регистрировали зависимость; FutureBuilder не показывал draft и тесты истекали по timeout | тестовые DI-регистрации `5b3060f`, `b91e819`; финальный полный D3.1 pass, analyzer 0; проверил Codex 2026-10-14, [evidence](../evidence/backend/m1/M1_STAGE3_CREATE_COMPAT.md) | закрыт |
| M1-ST3-02 | P1 для достоверности гейта | Внешняя сводка записала D3.1 rc=0 при failed UI и `flutter test failed` | старое утверждение успеха отвергнуто; репозиторный gate проверяет exit Flutter; новые прямые запуски без pipeline сохранили exit 1 для failed-повтора и exit 0 для финального pass с проверкой всех summaries; исходный внешний wrapper не используется; проверил Codex 2026-10-14 | закрыт заменой недостоверного evidence; история сохранена |
## Закрытые до заведения учёта (история M1)

| ID | Дефект | Исправление | Проверка |
|---|---|---|---|
| M1-D1 | Повтор `publish` после потерянного ответа давал `idempotency_conflict` | `a93707d` (заход 2) | гейты C3, D3.1–D3.4 на `e3710f6` (журналы 3c) |
| M1-D2 | Контроллеры Place/Activity/Rental/Collection перезаписывали чужую правку при `revision_conflict` | `a93707d`; импорт — `e3710f6` (D4.1 §3.3) | те же гейты и гейт D4 на `e3710f6` |

Эти две записи не переоценивались по шкале Р-08.

## DEF-05: оценка применимости (2026-10-14)

Источник: R0 run `38547610509` на `dd0f58b`, `npm audit --omit=dev --audit-level=high`;
граф — `npm ls --omit=dev` в `apps/backend/functions`; использование — поиск по
`apps/backend/functions/src`. Runtime сейчас только Emulator на loopback,
`firebase.json` запрещает deploy (`predeploy` → `deny-cloud-deploy.mjs`).
Оценка по чтению кода, без эксплуатационных проверок.

| Пакет | Уровень | Путь в графе | Применимость сейчас |
|---|---|---|---|
| `proxy-addr` 2.0.7 | critical (GHSA-jqcg-44mw-7w3h) | `firebase-functions` → `express` | подмена IP при `trust proxy` с доверенной подсетью; `trust proxy` в коде не задаётся; без сетевой экспозиции не эксплуатируется. Обязательно пересмотреть до любого cloud/staging |
| `@grpc/grpc-js` 1.14.4 | high (GHSA-m9gg-hp2v-232j, GHSA-f596-whhp-79r4) | `firebase-admin` → Firestore → `google-gax` | обе касаются gRPC-**сервера** (mTLS auth context, сообщения ошибок); мы клиент, своего gRPC-сервера нет — не применимо |
| `brace-expansion` 2.1.4 | high (3 DoS) | `google-gax` → `rimraf` → `glob` → `minimatch` | DoS на шаблонах от пользователя; недоверенные шаблоны в glob не попадают — не применимо |
| `qs` 6.15.3 | moderate | `firebase-functions` → `express`/`body-parser` | разбор тела/запроса HTTP; сейчас только loopback Emulator; актуально при сетевой экспозиции |
| `uuid` 9.0.1 | moderate | `@google-cloud/storage` → `gaxios`/`teeny-request` | только v3/v5/v6 с переданным `buf`; код проекта `uuid` не импортирует — не применимо |

Вывод: эксплуатируемой уязвимости в текущем runtime не найдено; приоритет не
повышается. `proxy-addr` и `qs` становятся значимыми при сетевой экспозиции —
обязательный пункт перед любым cloud/staging. npm предлагает исправление через
`firebase-admin@14.5.0` (вне заявленного диапазона) — решается в слайсе DEF-05,
не в D1.

## Заход 4: обнаруженные дефекты

| ID | Приоритет | Дефект | Evidence | Состояние |
|---|---|---|---|---|
| M1-ST4-01 | P1 для B1/M1 | Android debug запрещал HTTP loopback настоящему firebase_auth | исходный stage4-b1-platform-repeat.log; debug-only fix `bb25583` только для точного 127.0.0.1 | закрыт: native B1 повтор на `7cb07fa`, exit=0; main/release и Dart guard без изменений |

## Итоговая проверка scope M1 (заход 5)

В финальном runtime `7cb07fa` обязательные локальные дефекты исправлены или исключения явно приняты. DEF-05 остаётся открытым вне M1 по отдельному решению владельца, DEF-07 — P3. Это не утверждение об отсутствии дефектов во всём продукте. [Финальное независимое ревью](../evidence/backend/m1/M1_STAGE5_INDEPENDENT_REVIEW.md) завершено без открытых P1/P2 в принятом scope M1.

## DEF-05 follow-up — 2026-10-17, proposal awaiting owner approval

Owner selected preparation of option 2 with explicit conditions in the 21–26
integration chat. This authorizes the CLI update and preparation/testing of the
exception; **it does not approve its activation in CI**.

- Firebase CLI is pinned to **15.34.0** in package manifest, lock and toolchain.
  Existing Firestore 1.22.0 / Storage rules 1.1.3 versions, sizes and checksums
  still match the new CLI download metadata; no Media artifact change is claimed.
- Production `npm audit --omit=dev --audit-level=high` remains strict, with no
  exceptions: 6 moderate / **0 high / 0 critical**, exit 0.
- Full strict audit: 8 moderate / 3 high / 0 critical, exit 1. The three high
  records are the one advisory propagated through braces → chokidar → CLI.
- Proposed exception: **GHSA-vfj7-8cjw-p6xm only**, braces <=3.0.3, exclusively
  through dev Firebase CLI 15.34.0. Any other high/critical, malformed audit,
  production braces, non-CLI dependency path or unproved dependency scope fails.
- Created **2026-10-17**, expires **2026-11-16 00:00 UTC** (03:00 Moscow).
  At expiry the exception stops applying and requires a fresh upstream review.
  Every attempted use queries published braces versions. A release outside the
  reviewed affected range disables the exception and requires dependency update
  and removal of the exception; registry failure also fails closed.
- Rationale for review: the affected watcher/parser is a development CLI
  dependency used for credential-free local Emulator/CI verification, with
  repository-owned inputs. Residual risk is a CLI/job availability failure from
  a malicious deeply nested brace pattern. This is no production or blanket CLI
  risk acceptance and does not authorize cloud commands or network exposure.
- [Policy JSON](../../apps/backend/config/security/npm-audit-exception.json)
  has `status: proposed`, `approvedBy/approvedAt: null`.
  [Wrapper](../../apps/backend/scripts/verify-npm-audit.mjs) runs its own strict
  production audit, full JSON audit, lock/installed graph checks and upstream
  check. By default it fails `Owner approval pending`. `--review-proposal` is
  local-only and explicitly refuses CI; it is not an activation flag.
- [Policy tests](../../apps/backend/scripts/verify-npm-audit.test.mjs) exercise
  adversarial advisories, production/second hoisted paths, graph/report drift,
  expiry, upstream release and approval guards. Live proposal review succeeds;
  default mode fails as required. Commands: `npm run test:audit-policy`,
  `npm run verify:audit:full -- --review-proposal`, and default
  `npm run verify:audit:full` (expected failure pending approval).
- `.github/workflows/backend-r0.yml` still runs the original strict full
  `npm audit --audit-level=high`; **it does not invoke the exception wrapper**.
  After explicit owner approval, a separate bounded change must record the
  approver/time in policy and replace only that full-graph audit step with
  `npm run verify:audit:full`, retaining the strict production step and adding
  `npm run test:audit-policy` as a required check. Then run GitHub CI on the exact
  published SHA. Until that happens DEF-05 is open, not fixed or accepted.

Upstream reference: [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
The 2026-10-14 applicability assessment above is historical; this follow-up
records the narrowed current findings and does not retroactively approve them.

Final local runtime validation: `9db93bb`; [21–26 acceptance](LOCAL_21_26_ACCEPTANCE_2026_10_17.md).
Policy tests 13/13; full Emulator 14/14 groups with no skips.
[Exact inactive CI patch](DEF05_CI_ACTIVATION_PROPOSAL.patch) passes `git apply --check --unidiff-zero`; not applied.
DEF-05 remains open pending explicit owner approval and subsequent remote CI.


## DEF-05 — bounded local owner acceptance and 2026-10-24–26 audit follow-up

The owner explicitly answered in the 01–32 local completion chat:
«Да, принять только локально до 16.11.2026».

This accepts the risk exclusively for local Emulator work through the original
expiry **2026-11-16 00:00 UTC**, without extending it. The accepted scope is
GHSA-vfj7-8cjw-p6xm through dev Firebase CLI **15.34.0**, with the existing
dependency-graph, upstream-release and strict production checks. It does not
accept another advisory, production use, a new dependency path or a later expiry.

The live 2026-10-23 audit reports production **0 high / 0 critical / 6 moderate**;
the full graph remains **3 high / 0 critical / 8 moderate**. Policy tests pass
13/13 and the live `--review-proposal` check reports
`{"exceptionUsed":true,"reviewOnly":true}`. Published braces remains 3.0.3;
Firebase CLI latest is 15.34.1 and still declares chokidar ^3.6.0. The checked
local dependency tree remains pinned to 15.34.0; no upgrade is implied.

This is a bounded local risk acceptance, **not an upstream fix or global/CI
acceptance**. The policy and inactive CI proposal remain unchanged; the default
strict full audit remains fail-closed. No push, remote CI execution, provisioning
or deployment is authorized by this decision. The historical 2026-10-17 pending
approval statements above describe the global/CI proposal; they do not reopen
the local approval recorded here.

On **2026-10-24**, the audit feed changed: the previous braces advisory was no
longer reported, while new body-parser and Zod high findings were reported.
Commit `363d69dbfc64a8bb8b4f4ab0e21a52efef8f2678` updates only four transitive
lock nodes: body-parser 2.4.0, two nested body-parser 1.20.9, and Zod 4.6.7.
Direct dependency pins and installed Firebase CLI 15.34.0 remain unchanged.
The post-update live audit at 06:48 UTC reports production **0 high / 0 critical /
6 moderate**, full graph **0 high / 0 critical / 10 moderate**. Policy tests pass
13/13 and the live policy result is `{"exceptionUsed":false,"reviewOnly":false}`.
Thus the current local audit passes without using the DEF-05 exception. Braces
was not upgraded; this does not claim an upstream braces fix. The earlier dated
counts remain historical evidence, not the current result. The proposed global
CI exception stays inactive and no remote CI was executed.

Rechecked **2026-10-25 at 08:39 UTC** on the unchanged dependency graph:
production **0 high / 0 critical / 6 moderate**, full graph **0 high / 0 critical /
10 moderate**. The default strict policy (without `--review-proposal`) passes
with `{"exceptionUsed":false,"reviewOnly":false}`; policy self-tests pass 13/13.

Rechecked again **2026-10-26 at 00:10 UTC** on
`7d6ec42b11264005a0f747c6c193d76ce7bc2e18`, with the same lock:
production **0 high / 0 critical / 6 moderate**, full graph **0 high / 0 critical /
10 moderate**. Strict default policy and its 13 self-tests pass; no exception
was used or activated. This is the latest audit in the final local evidence.

Security references:
[body-parser GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828),
[Zod GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5).
The final 01–32 evidence records all new common-tree gates after this dependency
change; no previous stand result is inherited across it. This is technical
evidence for separate owner acceptance, not an automatic Review-to-Accepted
promotion.
