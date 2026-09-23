import type { EnvironmentId } from '../../config/environment.js';
import type { MarketId } from '../../config/market_capability.js';
import { deepFreeze, type DeepReadonly } from '../../shared/immutable.js';

export interface OperationalLogRecord {
  readonly level: 'debug' | 'info' | 'warn' | 'error';
  readonly eventName: string;
  readonly correlationId: string;
  readonly environmentId: EnvironmentId;
  readonly marketId: MarketId | null;
  readonly capabilityId: string | null;
  readonly outcome: 'success' | 'failure' | 'denied' | 'cancelled' | 'unknown';
  readonly code: string;
  readonly durationMs: number | null;
}

export interface StructuredLogger {
  write(record: OperationalLogRecord): void;
}

export class InMemoryStructuredLogger implements StructuredLogger {
  readonly records: DeepReadonly<OperationalLogRecord>[] = [];

  write(record: OperationalLogRecord): void {
    assertOperationalRecord(record);
    this.records.push(deepFreeze({ ...record }));
  }
}

export function rejectSensitiveTelemetry(value: unknown): void {
  visit(value, new WeakSet<object>());
}

function visit(value: unknown, seen: WeakSet<object>): void {
  if (typeof value !== 'object' || value === null || seen.has(value)) return;
  seen.add(value);
  const forbidden =
    /^(?:email|phone|fullName|displayName|address|token|secret|password|credential|rawPayload|payload|body)$|(?:email|phone|password|secret|token)$/i;
  for (const [key, child] of Object.entries(value)) {
    if (forbidden.test(key)) throw new TypeError('sensitive_telemetry_field_forbidden');
    visit(child, seen);
  }
}

function assertOperationalRecord(record: OperationalLogRecord): void {
  rejectSensitiveTelemetry(record);
  if (!/^[a-z][a-z0-9._-]{0,95}$/.test(record.eventName)) {
    throw new TypeError('operational_event_invalid');
  }
  if (!/^[a-z][a-z0-9._-]{0,95}$/.test(record.code)) {
    throw new TypeError('operational_code_invalid');
  }
  if (record.correlationId.length < 8 || record.correlationId.length > 128) {
    throw new TypeError('operational_correlation_invalid');
  }
  if (
    record.durationMs !== null &&
    (!Number.isFinite(record.durationMs) || record.durationMs < 0)
  ) {
    throw new TypeError('operational_duration_invalid');
  }
}
