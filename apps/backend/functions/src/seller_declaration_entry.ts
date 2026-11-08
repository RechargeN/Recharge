import { validateIdentityContract } from './contracts/validate_identity_contract.js';
import type { SellerDeclarationService } from './modules/identity_publisher/application/seller_declaration_service.js';
import { IdentityFailure } from './modules/identity_publisher/domain/failures.js';
import { SellerDeclarationInvalid } from './modules/identity_publisher/domain/seller_declaration.js';

/**
 * ADR 0023 (2026-11-08): the author's own DSA Art. 30 seller declaration.
 * The caller has already authorized the current Recharge Session; `userId` is
 * the server-resolved account, never a value from the payload.
 */
export async function handleSellerDeclarationCommand(input: {
  readonly userId: string;
  readonly data: unknown;
  readonly service: SellerDeclarationService;
  readonly nowUtc: string;
}): Promise<Readonly<Record<string, unknown>>> {
  const rejected = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });
  const command = await validateIdentityContract<{
    readonly commandType: 'declareSeller' | 'getSellerDeclaration';
    readonly expectedRevision?: number;
    readonly declaration?: unknown;
  }>('sellerDeclarationCommand', input.data);
  if (!command.ok) return rejected('invalid_contract');
  try {
    if (command.value.commandType === 'getSellerDeclaration')
      return { schemaVersion: 1, kind: 'succeeded', data: await input.service.read(input.userId) };
    const declared = await input.service.declare({
      userId: input.userId,
      body: command.value.declaration,
      expectedRevision: command.value.expectedRevision ?? -1,
      nowUtc: input.nowUtc,
    });
    return { schemaVersion: 1, kind: 'succeeded', data: declared };
  } catch (error) {
    if (error instanceof SellerDeclarationInvalid) return rejected('invalid_contract');
    if (error instanceof IdentityFailure) {
      if (error.code === 'revision_conflict') return rejected('revision_conflict');
      if (error.code === 'not_found_or_not_accessible') return rejected('account_inactive');
    }
    return rejected('unavailable');
  }
}
