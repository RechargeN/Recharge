import type { PageCreationPolicyPort } from '../application/ports/page_creation_policy_port.js';

export class LocalPageCreationPolicy implements PageCreationPolicyPort {
  constructor(
    private readonly enabled: boolean,
    private readonly maximumOwnedPages: number,
  ) {}

  evaluate(input: {
    readonly ownedPageCount: number;
  }): Promise<'allowed' | 'disabled' | 'quota_exceeded'> {
    if (!this.enabled) return Promise.resolve('disabled');
    return Promise.resolve(
      input.ownedPageCount < this.maximumOwnedPages ? 'allowed' : 'quota_exceeded',
    );
  }
}
