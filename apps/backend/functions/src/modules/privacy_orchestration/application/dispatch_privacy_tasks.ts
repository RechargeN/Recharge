import { createPrivacyDomainTask, type PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyRequest } from '../domain/privacy_request.js';
import type { MarketId } from '../../reference_data/domain/identifiers.js';

export interface PrivacyTaskSeed {
  readonly taskId: string;
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
    new Set(seeds.map((seed) => seed.taskId)).size !== seeds.length ||
    request.requiredDomainIds.some((domainId) => !domains.has(domainId))
  )
    throw new TypeError('privacy_task_scope_widening_or_gap');
  return Object.freeze(
    seeds.map((seed) =>
      createPrivacyDomainTask({
        ...seed,
        requestId: request.requestId,
        subjectId: request.subjectId,
        occurredAtUtc,
      }),
    ),
  );
}
