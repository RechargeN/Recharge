import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';

export interface SecurityAuditRecord {
  readonly eventName: string;
  readonly outcome: 'allowed' | 'denied' | 'error';
  readonly actorHash: string | null;
  readonly correlationId: string;
  readonly occurredAtUtc: UtcInstant;
  readonly reasonCode: string;
}

export interface SecurityAuditPort {
  append(record: SecurityAuditRecord): Promise<void>;
}

export class InMemorySecurityAuditPort implements SecurityAuditPort {
  readonly records: DeepReadonly<SecurityAuditRecord>[] = [];

  append(record: SecurityAuditRecord): Promise<void> {
    assertAuditRecord(record);
    this.records.push(
      deepFreeze({ ...record, occurredAtUtc: parseUtcInstant(record.occurredAtUtc) }),
    );
    return Promise.resolve();
  }
}

function assertAuditRecord(record: SecurityAuditRecord): void {
  if (!/^[a-z][a-z0-9._-]{0,95}$/.test(record.eventName)) {
    throw new TypeError('security_audit_event_invalid');
  }
  if (!/^[a-z][a-z0-9._-]{0,95}$/.test(record.reasonCode)) {
    throw new TypeError('security_audit_reason_invalid');
  }
  if (record.actorHash !== null && !/^[0-9a-f]{64}$/.test(record.actorHash)) {
    throw new TypeError('security_audit_actor_hash_invalid');
  }
  if (!/^[A-Za-z0-9._:-]{8,128}$/.test(record.correlationId)) {
    throw new TypeError('security_audit_correlation_invalid');
  }
}
