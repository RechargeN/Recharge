# Runbooks — указатель

RUN-01…RUN-06 — обязательный набор эксплуатации (мастер-спека backend, D6: «из фактической топологии»). Состояние на 2026-11-24, dev и staging. Production — после решений D-01…D-05 и разрешений P-xx (O1).

| RUN | Тема | Файл | Состояние | Репетиция |
|---|---|---|---|---|
| RUN-01 | Инцидент | [incident.md](incident.md) + раздел «Порядок действий» в [staging-monitoring-alerts-cost.md](staging-monitoring-alerts-cost.md) | Draft; модель SEV — D-05 | tabletop Run 001 — на репетиции 3.5 |
| RUN-02 | Откат | [backend-rollback.md](backend-rollback.md) | Draft; частично проверено 2026-11-17 (код Booking, образ media) | полная — на репетиции 3.5 |
| RUN-03 | Сверка и ремонт | [backend-reconciliation-repair.md](backend-reconciliation-repair.md); локально — [operations-recovery.md](operations-recovery.md) | Draft; консоль в облаке — не до production (решение 2026-11-24) | плановые задачи проверены 2026-11-23 |
| RUN-04 | Privacy: удаление и доступ | [backend-privacy-deletion.md](backend-privacy-deletion.md) | Draft | прогон 2026-11-20 (dev, staging) |
| RUN-05 | Backup, восстановление, DR | [backend-disaster-recovery.md](backend-disaster-recovery.md) | Draft; RPO/RTO — D-04 | N4d 2026-11-16/21 (PITR, backup, повтор на Privacy) |
| RUN-06 | Безопасность и злоупотребления | [backend-security-abuse.md](backend-security-abuse.md), [secret-leak-response.md](secret-leak-response.md) | Draft; заключение D-06 нет | ротация Maps-ключа 2026-11-24 |

## Остальные

| Файл | Зачем |
|---|---|
| [staging-monitoring-alerts-cost.md](staging-monitoring-alerts-cost.md) | оповещения, SLO, бюджет, выключатели, план восстановления бюджета |
| [firestore-rules-indexes-ttl-release.md](firestore-rules-indexes-ttl-release.md) | выпуск Rules, индексов, TTL |
| [backend-deploy-order.md](backend-deploy-order.md), [release.md](release.md) | порядок выкладки |
| [backend-cost-response.md](backend-cost-response.md) | расходы |
| [secrets-rotation.md](secrets-rotation.md) | ротация секретов |
| [branch-protection-setup.md](branch-protection-setup.md) | защита веток |
| [backend-provisioning-and-destroy.md](backend-provisioning-and-destroy.md) | создание и удаление окружений |
| [rollback.md](rollback.md) | откат мобильного релиза (опирается на теги, которых пока нет) |

## Репетиция 3.5 (план, нужно «да» владельца)

Один заход на staging, ~1 ч, с владельцем на связи:
1. Tabletop: условный SEV-2 «бронь не создаётся» — кто узнаёт, что смотрит, какой выключатель.
2. Выключатель создания Booking (`kill-on` → проверка `feature_disabled` → `load-off`).
3. Откат: выкладка предыдущего RC тем же скриптом, пробы, возврат на текущий RC. Цель отката — RC не старше `d09afb8d` (у более старых дефект входа).
4. Запись итогов в `docs/verification/`.
