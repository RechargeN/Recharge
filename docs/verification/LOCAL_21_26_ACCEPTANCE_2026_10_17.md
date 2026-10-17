# Заходы 21–26 — общая локальная приёмка, 2026-10-17

Статус: **принятый local/Emulator scope реализован и проверен; финальная CI-приёмка ждёт отдельного утверждения DEF-05 и публикации**.
Runtime revision: `9db93bb`; последующий documentation commit не меняет runtime.
Исходная интеграция: `4a16720`. K3 перенесён snapshot из `codex/k3` на базе
`a1fcde5`; исходный worktree сохранён без изменений. I1 уже присутствует через
`f32b97f`. Код, runtime artifacts и lockfile во время финальной сессии не менялись.

## Матрица критериев принятого scope

| Заход | Реализованные обязательные критерии | Проверка общей ревизии |
|---|---|---|
| 21 / G | Owner/session authority; Favorites и только explicit self-reported Place Visit; CAS/idempotency/tombstones; revision-pinned paging; Privacy erasure; изоляция durable queue | Library 9/9, включая реальные Flutter repositories |
| 22 / H | Eligibility и запрет own targets; stable review/edit/delete; rating projection/rebuild; exact-revision moderation; private output | H cases в reviews-safety 13/13 |
| 23 / K1 | Current scoped grants; immutable decisions/idempotency; report privacy/triage; owner dispatch/recovery; deny direct domain writes | moderation-k1 13/13 |
| 24 / K2 | Bilateral block/directional mute; scoped sanctions; independent appeals; overlap/expiry; explicit owner reconcile; partial recovery и сохранность Booking | K2 cases в том же reviews-safety 13/13, не дополнительный набор |
| 25 / K3 | Case/action/target scope; audit before disclosure; immutable proposal; separate approval revision/hash/TTL; current authority recheck; owner Event visibility restrict/restore; stable receipt/unknown/partial execution | admin-support-k3 7/7, ownership AST contract, Rules/manifest и cleanup |
| 26 / I1 | Existing Quick Plan aggregate; owner-only persistence; CAS/delete-wins; encrypted durable queue; import validation/collision; lost-response/auth/restart recovery | quick-plan 5/5, включая два настоящих Flutter adapters |

Scope задают specs в `docs/product`: `LIBRARY_G_LOCAL_SLICE_SPEC.md`,
`REVIEWS_H_LOCAL_SLICE_SPEC.md`, `MODERATION_K1_LOCAL_SLICE_SPEC.md`,
`TRUST_SAFETY_K2_LOCAL_SLICE_SPEC.md`, `K3_ADMIN_SUPPORT_READINESS.md`,
`QUICK_PLAN_I1_SLICE_SPEC.md`. Новых production-policy решений этот этап не принимает.

## Проверки

Node 22.23.2 / npm 10.9.8 / Temurin 21.0.12+8 / Terraform 1.15.9 /
Flutter 3.44.9 / Firebase CLI 15.34.0. Ambient Node 20 и Java 21.0.12.1+1
не использованы для финального backend набора.

| Гейт | Фактический результат |
|---|---|
| Exact toolchain, format, lint, typecheck | exit 0 |
| Backend unit / contract / integration / stand | 735 / 58 / 254 / 43 pass, 0 fail/skip |
| Manifest / Content layout / R1 layout/config/exports | exit 0; 69 collections, 13 flags, 19 exact Content outside consumers |
| Runner + persistence self-tests / audit policy tests | 7/7 / 13/13 |
| Generated-output safety / reproducibility | exit 0; logical digest `8647d114542369ccd17338f4533bfde6921ae270b40fb72acfa36b36d21c47a6` |
| Raw-body probe | 20/20 vectors, exit 0; disposable source удалён, port освобождён |
| Full Emulator — одна финальная сессия | **14/14 groups, 299 pass, 0 fail, 0 skip, complete:true, code:0**; внешний runner exit 0 |
| Library / Quick Plan mobile adapters | Выполнены внутри этой же сессии с `RECHARGE_G_MOBILE=1` и Dart/Flutter tool paths; cleanup assertions прошли |
| Flutter analyze / full suite | 0 issues / 1652 pass, 0 fail, 69 skip |
| Boundary self-test / repo check / inventory | exit 0; 623 files, 71/71 прежних исключений, 0 violations/stale/expired |
| Terraform fmt / backendless readonly-lock init / validate | exit 0; no plan/apply |
| Production audit | Strict `--omit=dev --audit-level=high`: exit 0; 6 moderate, 0 high/critical |
| Full raw audit | **exit 1**, 8 moderate / 3 high / 0 critical; ожидаемый открытый approval gate, не зелёный audit |
| Proposed audit wrapper | Local review exit 0; default exit 1 (`Owner approval pending`); CI review-mode запрещён |
| Diff checks | clean |

Полный Flutter прогон выполнен в этом же заходе на `022bcb0`. Git objects
`apps/mobile`, `packages`, `pubspec.yaml` и `pubspec.lock` идентичны на
`022bcb0` и `9db93bb` (сверены напрямую). Последующие изменения backend-only;
их интеграция с настоящими мобильными клиентами проверена в финальном Emulator.
69 Flutter-skip находятся в 24 файлах `test/backend_local`; два файла Library/I1
выполнены в общем Emulator, оставшиеся 22 — отдельные stand-gates, не повторённые
в этом этапе. [Карта skip](I1_REBASE_CHECK_2026_10_17.md#карта-69-flutter-skip).
B1/B2 и native Android AVD I1 сохранены как прежнее evidence `f32b97f`;
повторно в этом этапе они не запускались. AVD не является physical-device/iOS evidence.

Журналы: `apps/backend/.r0-tools/closure-21-26-final-check/`.
Финальная Emulator-сессия: `recharge-emulator-tests-JLURKC`; summary SHA-256
`3d6b65703edc348a97ac4cae6237fc54994b2fcb1fbcb04c309fac4c5a9a0f90`.
Все локальные rc фиксируются непосредственно от команды, до записи времени.

## DEF-05: подготовлено, но не активировано

[Реестр DEF-05](M1_DEFECT_REGISTER.md) содержит обоснование, проверки и owner conditions.
[Policy JSON](../../apps/backend/config/security/npm-audit-exception.json):
только GHSA-vfj7-8cjw-p6xm через dev Firebase CLI 15.34.0;
`status: proposed`, approval fields null; expires **2026-11-16 00:00 UTC**
(03:00 Москва). Production audit без исключений. Другие high/critical,
production braces, другой путь зависимости, истечение срока или публикация
версии вне affected range закрывают gate; upstream проверяется при каждом запуске.

[Точный CI patch для утверждения](DEF05_CI_ACTIVATION_PROPOSAL.patch) подготовлен
и прошёл `git apply --check --unidiff-zero`, **не применён**. Он сохраняет strict production step,
добавляет policy tests и меняет только full audit step на wrapper. До owner approval
сам wrapper отказывает, а действующий workflow по-прежнему вызывает strict full audit.
После утверждения нужны запись approver/time, применение patch, повтор policy/toolchain
checks и отдельно разрешённый push; затем GitHub checks точного опубликованного SHA.
CI success, merge main, cloud, deploy и activation этим отчётом не заявляются.

## Исправления и история негриновых прогонов

- K3 snapshot сохранён в `.r0-tools/k3-snapshot`, исходные tracked/untracked
  файлы сверены с ним. При переносе сохранены обе группы K3/I1, self-test теперь
  знает 14 групп и 52 invocations; digest исходных 40 invocations неизменён.
- Intermediate sessions были намеренно остановлены до обновлений lockfile/CLI;
  их complete:false не считается полным pass. Останавливалось только проверенное
  собственное process tree; порты освобождены до изменений runtime artifacts.
  Собственный leftover raw-body temporary source архивирован из Functions source.
- Старый raw-body positive corpus нарушал current canonical requestId pattern.
  Реальный fail сохранён; `eba4517` исправляет только test corpus: ASCII IDs,
  Unicode в displayName и новый explicit invalid-ID negative. Schema/validator
  не ослаблялись. Первый PowerShell wrapper терял полную stderr-диагностику;
  исправленный local wrapper сохраняет настоящий rc и полную ошибку.
- Новый policy JSON сначала был отклонён R1 exact layout. `9db93bb` добавляет
  ровно один путь, сохраняет reject unknown и проверяет запрет CI activation
  proposed policy. Итог выше — новый полный набор после исправления.

## Открытые внешние gates и rollback

Открыты полные Reviews/Reports/Staff UI и отсутствующие contact/profile/message
integrations; production Auth/staff MFA/JIT/IAM и approval policy; qualified
Security/Privacy/Legal review, retention/DSR, staffing/SLO и age authority;
Quick Plan invited/unlisted grants, production sync и conflict-resolution UI;
physical Android/iOS, cloud/staging, deployed-index readiness и production нагрузка.
Канонические BCK-10/BCK-12/BCK-19/BCK-22 не становятся Approved/Done от local slices.

Rollback: сохранить refs и исходные worktrees; source changes возвращать отдельным
согласованным revert. Остановить вход независимыми default-off flags; существующие
moderation/safety effects снимать только owner compensation/reconcile. Сохранять
audit, receipts, tombstones и mobile journals; не удалять domain state ради rollback.

## Затронутые файлы

```text
.github/workflows/backend-r0.yml
apps/backend/config/manifests/execution-manifest.json
apps/backend/config/security/npm-audit-exception.json
apps/backend/firestore.rules
apps/backend/functions/package-lock.json
apps/backend/functions/package.json
apps/backend/functions/src/modules/admin_support/admin_support_service.ts
apps/backend/functions/test/contract/admin_support_ownership.test.ts
apps/backend/functions/test/emulator/admin_support.test.ts
apps/backend/functions/test/emulator/booking_callable_raw_body_probe_client.ts
apps/backend/functions/test/emulator/rules_default_deny.test.ts
apps/backend/functions/test/integration/content_publication_security.test.ts
apps/backend/scripts/run-emulator-test-groups.mjs
apps/backend/scripts/run-emulator-test-groups.test.mjs
apps/backend/scripts/verify-content-persistence-layout.mjs
apps/backend/scripts/verify-npm-audit.mjs
apps/backend/scripts/verify-npm-audit.test.mjs
apps/backend/scripts/verify-r1-layout.mjs
apps/backend/toolchain.lock.json
docs/architecture/LAUNCH_STATUS.md
docs/product/ADMIN_SUPPORT_BACKEND_SPEC.md
docs/product/K3_ADMIN_SUPPORT_READINESS.md
docs/product/QUICK_PLAN_I1_SLICE_SPEC.md
docs/verification/DEF05_CI_ACTIVATION_PROPOSAL.patch
docs/verification/I1_REBASE_CHECK_2026_10_17.md
docs/verification/LOCAL_21_26_ACCEPTANCE_2026_10_17.md
docs/verification/M1_DEFECT_REGISTER.md
```
