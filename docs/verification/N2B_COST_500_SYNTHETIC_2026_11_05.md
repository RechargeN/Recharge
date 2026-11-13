# N2b — смета на месяц для 500 synthetic объектов

Расчётная сумма **€3.52/месяц**, включая условный налоговый запас 25% и дополнительный резерв €1. Это модель с допущениями, не гарантия, тарифное предложение или жёсткий cap.

500 business objects суммарно (Place/Route/остальные типы), плюс до 4 500 связанных документов. Firestore eur3: средний объём базы с индексами и metadata до 0.1 GiB, PITR включён весь месяц и считается отдельно ещё для 0.1 GiB. Не умножаем PITR на семь: официальная модель использует средний размер БД. Media: по 1 MiB на объект (~0.49 GiB), до 1 GiB с запасом на soft-delete/старые копии; STANDARD europe-west1. Versioned state EU — до 0.1 GiB всех версий. Месяц — до 31 дней.

Операции считаем по gross-объёму, без вычета free tier/credits: 100 000 document+billable index reads, 10 000 writes, 2 000 deletes; 2 000 storage class A, 20 000 class B; суммарный internet egress Firestore+Storage <=2 GiB. Budget Pub/Sub до 0.01 GiB включая publish/delivery/retention, Logging до 0.1 GiB. Один synthetic delivery probe, без фоновых циклов.

| Статья | Объём | Предполагаемая ставка EUR | Сумма EUR |
|---|---:|---:|---:|
| Firestore document/index reads | 100000 | 0.00000120 | 0.1200 |
| Firestore writes | 10000 | 0.00000300 | 0.0300 |
| Firestore deletes | 2000 | 0.00000060 | 0.0012 |
| Firestore eur3 data incl indexes GiB-month | 0.1 | 0.40000000 | 0.0400 |
| Firestore PITR GiB-month | 0.1 | 0.40000000 | 0.0400 |
| Media europe-west1 incl soft-delete/old copies GiB-month | 1 | 0.04000000 | 0.0400 |
| EU versioned Terraform state GiB-month | 0.1 | 0.04000000 | 0.0040 |
| Storage class A operations | 2000 | 0.00001500 | 0.0300 |
| Storage class B operations | 20000 | 0.00000150 | 0.0300 |
| Combined Firestore/Storage internet egress GiB | 2 | 0.30000000 | 0.6000 |
| PubSub publish+delivery+retention allowance GiB | 0.01 | 0.10000000 | 0.0010 |
| Logging ingestion allowance GiB | 0.1 | 0.80000000 | 0.0800 |
| Log-alert policy and bootstrap service overhead reserve | 1 | 1.00000000 | 1.0000 |

Подытог €2.0162; условный налоговый запас €0.5040; дополнительный резерв €1; итого €3.5202. До €5 остаётся €1.4798.

Использованные EUR ставки — намеренно заданные консервативные плановые допущения, а не проверенные account-specific SKU цены и не пересчёт валюты. Перед apply/readback следует сравнить фактические EUR SKU с этими допущениями; если модель выходит за €5, ordinary resources не запускать и пакет пересмотреть. Резерв покрывает малую погрешность, но не неограниченное потребление.

Источники структуры начислений (проверены 2026-11-05):
- [Firestore pricing](https://cloud.google.com/firestore/pricing): операции, indexes, storage, PITR отдельно; в EUR действуют EUR SKU, не USD из страницы.
- [PITR billing](https://firebase.google.com/docs/firestore/pricing#pitr_data): средний размер, оплачивается и без free tier.
- [Storage pricing](https://cloud.google.com/storage/pricing): region/class, operations, egress и retained/soft-deleted data.
- [Pub/Sub pricing](https://cloud.google.com/pubsub/pricing): publish/delivery/retention.
- [Observability pricing](https://cloud.google.com/products/observability/pricing): Logging и alerting; €1 выделен как плановый запас, не цитата тарифа.

В этом bootstrap нет Functions/Cloud Run deployment, платных Maps/Routes/Places/AI API вызовов, SMS/phone Auth, imports, load/abuse тестов, scheduled exports или recovery bucket. Их стоимость не включена и их запуск пакетом не разрешается. Смета оценивает хранение и ограниченные synthetic операции, а не доказывает готовность облачного runtime приложения. Тестовые данные этим заходом не загружаются.

Контроль: RechargeN — Finance/Incident owner; Codex выполняет только утверждённые действия. При €2.50 проверить расходы и первое 50%% письмо; €3.75 — прекратить необязательные synthetic операции; €4.50/€5 — прекратить весь необязательный workload, сохранить IAM/budget/evidence. Не отвязывать billing, не удалять данные. Budget уведомления задерживаются и не ограничивают расходы; workload envelope выше проверяется оператором, а не автоматическим hard cap.
