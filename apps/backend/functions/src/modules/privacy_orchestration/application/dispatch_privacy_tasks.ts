import { createHash } from 'node:crypto';
import { createPrivacyDomainTask, type PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyRequest } from '../domain/privacy_request.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';

export interface PrivacyTaskSeed {
  readonly domainId: string;
  readonly marketId: MarketId | null;
  readonly targetRevision: number;
}

export function buildPrivacyDomainTasks(
  request: PrivacyRequest,
  seeds: readonly PrivacyTaskSeed[],
  occurredAtUtc: string,
): readonly PrivacyDomainTask[] {
  const domains = new Set(seeds.map((seed) => seed.domainId));
  if (
    seeds.length !== request.requiredDomainIds.length ||
    domains.size !== request.requiredDomainIds.length ||
    request.requiredDomainIds.some((domainId) => !domains.has(domainId))
  )
    throw new TypeError('privacy_task_scope_widening_or_gap');
  return Object.freeze(
    seeds.map((seed) =>
      createPrivacyDomainTask({
        ...seed,
        taskId: privacyDomainTaskId(
          request.requestId,
          seed.domainId,
          seed.marketId,
          seed.targetRevision,
        ),
        requestId: request.requestId,
        subjectId: request.subjectId,
        occurredAtUtc,
      }),
    ),
  );
}

export function privacyDomainTaskId(
  requestId: string,
  domainId: string,
  marketId: MarketId | null,
  targetRevision: number,
): string {
  const digest = createHash('sha256')
    .update(
      `privacy_domain_task_v1|${requestId.length}:${requestId}|${domainId.length}:${domainId}|${marketId ?? '-'}|${targetRevision}`,
      'utf8',
    )
    .digest();
  const bytes = Buffer.from(digest.subarray(0, 16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x50;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
