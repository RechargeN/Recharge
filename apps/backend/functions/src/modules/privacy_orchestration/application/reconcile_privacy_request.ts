import type { PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import { transitionPrivacyRequest, type PrivacyRequest } from '../domain/privacy_request.js';

export function reconcilePrivacyRequest(
  request: PrivacyRequest,
  tasks: readonly PrivacyDomainTask[],
  occurredAtUtc: string,
): PrivacyRequest {
  if (tasks.length !== request.requiredDomainIds.length)
    throw new TypeError('privacy_reconciliation_task_gap');
  const taskDomains = new Set(tasks.map((task) => task.domainId));
  if (
    request.requiredDomainIds.some((domainId) => !taskDomains.has(domainId)) ||
    tasks.some(
      (task) => task.requestId !== request.requestId || task.subjectId !== request.subjectId,
    )
  )
    throw new TypeError('privacy_reconciliation_scope_invalid');
  const succeeded = tasks.filter((task) => task.status === 'succeeded');
  if (succeeded.length === tasks.length) {
    return transitionPrivacyRequest({
      request,
      nextStatus: 'completed',
      occurredAtUtc,
      terminalEvidenceIds: succeeded.map((task) => task.evidenceId!).filter(Boolean),
    });
  }
  if (succeeded.length > 0 || tasks.some((task) => task.status === 'failed')) {
    return transitionPrivacyRequest({
      request,
      nextStatus: 'partially_completed',
      occurredAtUtc,
      terminalEvidenceIds: succeeded.map((task) => task.evidenceId!).filter(Boolean),
    });
  }
  return request;
}
