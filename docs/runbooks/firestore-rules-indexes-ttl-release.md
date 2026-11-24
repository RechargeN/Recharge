# Выпуск Firestore Rules, индексов и TTL (dev, staging)

Статус: **Draft, 2026-11-24** (план пробелов 26–50, заход 3, пункт 3.3). Не выполнялся.
Production — вне этого runbook (P-29 в O1, отдельное разрешение).

## Почему это нужно

O1 (2026-11-22, B-08): в dev и staging **ноль** выпусков Rules и ноль TTL-политик; составных индексов 14 из 27. Файлы в Git есть (`apps/backend/firestore.rules`, `firestore.indexes.json`), но в облаке их нет:

- без выпуска Rules действует то, что поставил Firebase при создании базы, а не наш deny-all;
- без TTL сроки хранения Booking, receipts и счётчиков rate-limit не исполняются;
- без индексов часть запросов серверных задач падает («нужен индекс»).

## Кто владеет

`modules/firestore/main.tf`: Terraform владеет только самой базой. Rules, индексы и TTL выпускает **Firebase CLI из проверенного RC** — двойного управления нет. Значит, «через IaC» здесь = из файлов RC тем же коммитом, что и функции.

## Три шага, каждый со своим «да»

| Шаг | Что меняется | Риск | Разрешение |
|---|---|---|---|
| A. Rules | `firestore.rules` → активный выпуск | Клиент теряет прямой доступ к Firestore. Приложение ходит только через Functions (Admin SDK Rules не проверяет), поэтому поломки не ожидается | «да» владельца (безопасность) |
| B. Индексы без TTL | составные индексы из RC | Только создание индексов; построение занимает минуты | вместе с A |
| C. TTL | 14 TTL-политик (`fieldOverrides` с `ttl: true`) | **Удаление данных**: Firestore начнёт удалять документы с прошедшим `expiresAt` (брони, квитанции, входящие, счётчики) в течение ~24 ч | **отдельное** «да» владельца |

### Перед любым шагом

1. Проект — только `recharge-dev-n2a01` или `recharge-staging-y9y2y`; сначала dev, затем staging.
2. Checkout — тот же SHA, что у выложенного RC (`git rev-parse HEAD` = RC).
3. Бюджеты SLO по правилу runbook мониторинга (выпуск Rules и TTL — выкатка).
4. Снять «как было»: список выпусков Rules, индексов и field overrides (только чтение), сохранить в записи выкладки.

### A. Rules

```
firebase deploy --only firestore:rules --project <проект>
```

Проверка: в консоли один активный выпуск с хэшем файла из RC; активная проба клиентским SDK без токена на любую коллекцию → `permission-denied`; пробы функций → 401 как раньше; журнал ошибок функций без новых записей.

Откат: выпустить предыдущий ruleset (если его не было — оставить deny-all; открытых правил у нас нет).

### B. Индексы без TTL

Firebase CLI выпускает индексы и `fieldOverrides` одним файлом. Чтобы TTL не включился вместе с индексами, для шага B используется копия файла без `fieldOverrides`, собранная из файла RC (только удаление ключа, остальное байт в байт):

```
node -e "const f=require('fs');const d=JSON.parse(f.readFileSync('firestore.indexes.json'));delete d.fieldOverrides;f.writeFileSync('<scratch>/indexes-no-ttl.json',JSON.stringify(d,null,2))"
firebase deploy --only firestore:indexes --project <проект>   (firebase.json указывает на копию)
```

Без `--force`: существующие индексы и overrides не удаляются.

Проверка: в консоли 26 составных индексов в состоянии READY; ошибки «нужен индекс» в журнале задач пропали.

### C. TTL (отдельное «да»)

Перед шагом: посчитать документы с `expiresAt` в прошлом по каждой из 14 коллекций (только чтение) и показать владельцу, что будет удалено. Реальных пользователей в dev и staging, кроме владельца, нет.

```
firebase deploy --only firestore:indexes --project <проект>   (полный файл RC)
```

Проверка: 14 TTL-политик в состоянии ACTIVE; через сутки число просроченных документов уменьшается; непросроченные на месте.

Откат: снять TTL-политику с поля (удалённое не вернуть, кроме PITR в пределах 7 дней).

## Список TTL (из `firestore.indexes.json`)

`bookings`, `bookingIdempotency`, `bookingOutbox`, `bookingAudit`, `securityRateLimitAttempts`, `securityRateLimitCounters`, `bookingProjectionDeliveries`, `bookingProjectionOperatorAudit`, `bookingReconfirmationDeadlineJobs`, `bookingReconfirmationDeadlineOperatorAudit`, `notificationInboxItems`, `notificationEffectReceipts`, `notificationDeliveryAttempts`, `notificationCommandReceipts` — у всех поле `expiresAt`.

## Тесты

Rules проверяются Emulator-группой «Rules» в CI (Backend R1). Состав индексов и TTL сверяет `verify-execution-manifest.mjs` с манифестом выполнения.
