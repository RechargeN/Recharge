import { parseEntityId, type EntityId } from '../../../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import { parseLocaleId, parseMarketId, type LocaleId, type MarketId } from './identifiers.js';

export interface MandatoryCopyReference {
  readonly schemaVersion: 1;
  readonly referenceId: EntityId;
  readonly marketId: MarketId;
  readonly capabilityId: string;
  readonly purposeId: string;
  readonly locale: LocaleId;
  readonly copyId: EntityId;
  readonly copyRevision: number;
  readonly contentSha256: string;
  readonly approvalState: 'pending' | 'accepted' | 'rejected';
  readonly approvalEvidenceRevision: string | null;
  readonly effectiveAtUtc: UtcInstant;
  readonly expiresAtUtc: UtcInstant | null;
  readonly fallbackPolicy: 'forbidden';
}

export function createMandatoryCopyReference(
  input: Omit<
    MandatoryCopyReference,
    | 'schemaVersion'
    | 'referenceId'
    | 'marketId'
    | 'locale'
    | 'copyId'
    | 'effectiveAtUtc'
    | 'expiresAtUtc'
  > & {
    readonly referenceId: string;
    readonly marketId: string;
    readonly locale: string;
    readonly copyId: string;
    readonly effectiveAtUtc: string;
    readonly expiresAtUtc: string | null;
  },
): DeepReadonly<MandatoryCopyReference> {
  if (!Number.isSafeInteger(input.copyRevision) || input.copyRevision < 1)
    throw new TypeError('mandatory_copy_revision_invalid');
  if (
    !/^[a-z][a-z0-9._-]{0,95}$/.test(input.capabilityId) ||
    !/^[a-z][a-z0-9._-]{0,95}$/.test(input.purposeId)
  )
    throw new TypeError('mandatory_copy_scope_invalid');
  if (!/^sha256:[0-9a-f]{64}$/.test(input.contentSha256))
    throw new TypeError('mandatory_copy_content_hash_invalid');
  if (input.approvalState === 'accepted' && input.approvalEvidenceRevision === null)
    throw new TypeError('mandatory_copy_approval_evidence_missing');
  return deepFreeze({
    ...input,
    schemaVersion: 1,
    referenceId: parseEntityId(input.referenceId),
    marketId: parseMarketId(input.marketId),
    locale: parseLocaleId(input.locale),
    copyId: parseEntityId(input.copyId),
    effectiveAtUtc: parseUtcInstant(input.effectiveAtUtc),
    expiresAtUtc: input.expiresAtUtc === null ? null : parseUtcInstant(input.expiresAtUtc),
  });
}

export function isMandatoryCopyUsable(
  reference: MandatoryCopyReference,
  scope: {
    readonly marketId: MarketId;
    readonly capabilityId: string;
    readonly purposeId: string;
    readonly locale: LocaleId;
  },
  nowUtc: UtcInstant,
): boolean {
  return (
    reference.marketId === scope.marketId &&
    reference.capabilityId === scope.capabilityId &&
    reference.purposeId === scope.purposeId &&
    reference.locale === scope.locale &&
    reference.approvalState === 'accepted' &&
    reference.approvalEvidenceRevision !== null &&
    Date.parse(reference.effectiveAtUtc) <= Date.parse(nowUtc) &&
    (reference.expiresAtUtc === null || Date.parse(reference.expiresAtUtc) > Date.parse(nowUtc))
  );
}
