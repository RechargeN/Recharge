import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import type { PrivacyDomainTask } from '../domain/privacy_domain_task.js';
import type { PrivacyTaskRepository } from '../domain/repositories.js';

export class InMemoryPrivacyTaskRepository implements PrivacyTaskRepository {
  readonly #tasks = new Map<string, DeepReadonly<PrivacyDomainTask>>();

  createMany(tasks: readonly PrivacyDomainTask[]): Promise<void> {
    for (const task of tasks) {
      const existing = this.#tasks.get(task.taskId);
      if (existing !== undefined && JSON.stringify(existing) !== JSON.stringify(task))
        throw new TypeError('immutable_privacy_task_conflict');
      this.#tasks.set(task.taskId, existing ?? deepFreeze({ ...task }));
    }
    return Promise.resolve();
  }

  listByRequest(requestId: string): Promise<readonly DeepReadonly<PrivacyDomainTask>[]> {
    return Promise.resolve(
      Object.freeze(
        [...this.#tasks.values()]
          .filter((task) => task.requestId === requestId)
          .sort((left, right) => left.domainId.localeCompare(right.domainId)),
      ),
    );
  }

  save(
    task: PrivacyDomainTask,
    expectedRevision: number,
  ): Promise<'saved' | 'revision_conflict' | 'not_found'> {
    const existing = this.#tasks.get(task.taskId);
    if (existing === undefined) return Promise.resolve('not_found');
    if (existing.revision !== expectedRevision || task.revision !== expectedRevision + 1)
      return Promise.resolve('revision_conflict');
    this.#tasks.set(task.taskId, deepFreeze({ ...task }));
    return Promise.resolve('saved');
  }
}
