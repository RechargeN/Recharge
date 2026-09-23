export interface PageCreationPolicyPort {
  evaluate(input: {
    readonly userId: string;
    readonly ownedPageCount: number;
    readonly marketId: string;
  }): Promise<'allowed' | 'disabled' | 'quota_exceeded'>;
}
