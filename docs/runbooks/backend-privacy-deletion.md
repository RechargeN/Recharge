# RUN-04. Privacy: доступ, ограничение, удаление, legal hold (dev, staging)

Статус: **Draft, 2026-11-24.** Основан на облачном прогоне Privacy L1 (2026-11-20, dev и staging, синтетические субъекты) и повторе N4d. Production — после D-04, D-07 и решений PB (`docs/product/PRODUCTION_PREP_OWNER_DECISIONS_2026_11_24.md`).

## Что работает в облаке

| Функция (кодбаза `n4c-booking`, аккаунт `runtime-booking`) | Кто вызывает | Что делает |
|---|---|---|
| `privacyRequestV1` (invoker public, вход Session) | пользователь | подаёт `access`, `restriction`, `erasure`; читает статус **своей** заявки. Субъект — только из Session сервера |
| `privacyOperatorV1` (invoker private, IAM Cloud Run) | оператор | то же для 20 детерминированных синтетических субъектов; ставит и снимает legal hold |
| `runPrivacyRequestsV1` (раз в 5 мин) | планировщик | исполняет задачи по доменам, сверяет заявки |

Выключатель: `N5D_PRIVACY_ENABLED` при выкладке (по умолчанию закрыт; открыт в dev и staging с 2026-11-20).

## Клиента в приложении нет

Пользователь пока не может сам запросить экспорт или удаление (O1 B-16, PRIV-CLIENT в документе решений). До клиента запросы пользователей принимаются вручную через поддержку и исполняются оператором.

## Процедура оператора (синтетика)

Скрипт `private-n4a/n5d_privacy.py` (локально, не в Git):

```
python -I n5d_privacy.py seed     <dev|staging> <n>
python -I n5d_privacy.py submit   <dev|staging> <n> <access|restriction|erasure>
python -I n5d_privacy.py run      <dev|staging> <n>
python -I n5d_privacy.py status   <dev|staging> <n> <requestId>
python -I n5d_privacy.py hold     <dev|staging> <n> <holdId> <domainId>
python -I n5d_privacy.py release  <dev|staging> <n> <holdId> <expectedRevision>
python -I n5d_privacy.py docs     <dev|staging> <n>
```

Субъект — `uuidv5('n5d-synthetic-<n>', namespace)`; вход оператора ничего другого не принимает.

## Как читать итог

| Итог заявки | Значит |
|---|---|
| `completed` | все домены `succeeded` |
| `partially_completed` | часть доменов `blocked` политикой PB (данные заблокированы, но не удалены) — это честный итог, не ошибка |
| `incomplete` | после восстановления копии часть удалений удержана PB |

Аккаунт при `erasure` становится `restricted`; Identity не удаляется до решения PB-01. Media не удаляется (решение владельца 1б от 2026-11-20).

## Legal hold

Ставит только оператор с письменным основанием (PB-06 — решение владельца). Домен под hold сохраняет данные; заявка на удаление завершается `partially_completed`. Снятие — с ожидаемой ревизией hold.

## После восстановления базы

`admitRestoredCopy` повторяет к копии все решения об удалении из рабочей базы (повтор N4d, 2026-11-20: входящие 2 → 0). Ограничение: решения берутся из рабочей базы; если восстанавливается она сама, нужен журнал удалений вне БД (PB-15, D-04) — до production его нет.

## Известное

- Первый прогон N4d 2026-11-20 закрыл копию с `redeletion_failed`; во втором ошибок нет; причина не найдена — при повторе собрать диагностику.
- Ответ `access` показывает статусы доменов без чисел записей (числа в evidence задач).
