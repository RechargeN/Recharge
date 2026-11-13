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
  const terminal = tasks.filter((task) =>
    ['succeeded', 'failed', 'cancelled'].includes(task.status),
  );
  // L1: a blocked task did all its accepted steps and waits for a policy. The
  // request is then honestly partial, never completed, and stays open.
  const blocked = tasks.filter((task) => task.status === 'blocked');
  if (
    blocked.length > 0 &&
    terminal.length + blocked.length === tasks.length &&
    terminal.length === succeeded.length
  ) {
    if (request.status === 'partially_completed') return request;
    return transitionPrivacyRequest({
      request,
      nextStatus: 'partially_completed',
      occurredAtUtc,
      terminalEvidenceIds: succeeded.map((task) => task.evidenceId!).filter(Boolean),
    });
  }
  if (terminal.length + blocked.length !== tasks.length) return request;
  if (succeeded.length === tasks.length) {
    const retained = succeeded.some(
      (task) => task.completionOutcome === 'retained_legal_hold' && task.retainedCount > 0,
    );
    return transitionPrivacyRequest({
      request,
      nextStatus: retained ? 'completedWithRetention' : 'completed',
      occurredAtUtc,
      terminalEvidenceIds: succeeded.map((task) => task.evidenceId!).filter(Boolean),
    });
  }
  if (tasks.some((task) => task.status === 'failed' || task.status === 'cancelled')) {
    return transitionPrivacyRequest({
      request,
      nextStatus: 'failed',
      occurredAtUtc,
      terminalEvidenceIds: succeeded.map((task) => task.evidenceId!).filter(Boolean),
    });
  }
  return request;
}
