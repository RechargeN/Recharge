import { parseEntityId, type EntityId } from '../shared/ids.js';
import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../shared/utc_instant.js';
import { parseMarketId, type MarketId } from '../modules/reference_data/domain/identifiers.js';

export type PrincipalType = 'user' | 'service';
export type AppCheckState = 'valid' | 'missing' | 'invalid';
export type SessionState = 'active' | 'stepUpRequired' | 'revoked' | 'expired' | 'compromised';

export type ActorWorkspace =
  | { readonly type: 'personal'; readonly id: EntityId }
  | {
      readonly type: 'page';
      readonly id: EntityId;
      readonly membershipState: 'active' | 'revoked';
    };

export interface ActorContext {
  readonly principalType: PrincipalType;
  readonly actorId: EntityId;
  readonly sessionId: EntityId;
  readonly authenticatedAtUtc: UtcInstant;
  readonly sessionState: SessionState;
  readonly marketId: MarketId;
  readonly workspace: ActorWorkspace;
  readonly appCheckState: AppCheckState;
  readonly accessSnapshotRevision: number;
  readonly activeAccountState: 'active' | 'restricted' | 'blocked' | 'deleted';
  readonly capabilities: readonly string[];
}

export function createServerActorContext(input: {
  readonly principalType: PrincipalType;
  readonly actorId: string;
  readonly sessionId: string;
  readonly authenticatedAtUtc: string;
  readonly sessionState: SessionState;
  readonly marketId: string;
  readonly workspace:
    | { readonly type: 'personal'; readonly id: string }
    | {
        readonly type: 'page';
        readonly id: string;
        readonly membershipState: 'active' | 'revoked';
      };
  readonly appCheckState: AppCheckState;
  readonly accessSnapshotRevision: number;
  readonly activeAccountState: ActorContext['activeAccountState'];
  readonly capabilities: readonly string[];
}): DeepReadonly<ActorContext> {
  if (!Number.isSafeInteger(input.accessSnapshotRevision) || input.accessSnapshotRevision < 0) {
    throw new TypeError('access_snapshot_revision_invalid');
  }
  if (input.capabilities.some((capability) => !/^[a-z][a-z0-9._-]{0,95}$/.test(capability))) {
    throw new TypeError('actor_capability_invalid');
  }
  const workspace =
    input.workspace.type === 'personal'
      ? { type: 'personal' as const, id: parseEntityId(input.workspace.id) }
      : {
          type: 'page' as const,
          id: parseEntityId(input.workspace.id),
          membershipState: input.workspace.membershipState,
        };
  return deepFreeze({
    principalType: input.principalType,
    actorId: parseEntityId(input.actorId),
    sessionId: parseEntityId(input.sessionId),
    authenticatedAtUtc: parseUtcInstant(input.authenticatedAtUtc),
    sessionState: input.sessionState,
    marketId: parseMarketId(input.marketId),
    workspace,
    appCheckState: input.appCheckState,
    accessSnapshotRevision: input.accessSnapshotRevision,
    activeAccountState: input.activeAccountState,
    capabilities: [...new Set(input.capabilities)].sort(),
  });
}

export function rejectClientAuthority(value: unknown): void {
  visitClientValue(value, new WeakSet<object>());
}

function visitClientValue(value: unknown, seen: WeakSet<object>): void {
  if (typeof value !== 'object' || value === null || seen.has(value)) return;
  seen.add(value);
  const forbidden = new Set(
    [
      'role',
      'roles',
      'capability',
      'capabilities',
      'permissions',
      'accessSnapshotRevision',
      'isAdmin',
      'isCreator',
      'age',
      'birthDate',
      'dateOfBirth',
      'ageVerified',
      'sessionState',
    ].map((key) => key.toLowerCase()),
  );
  for (const [key, child] of Object.entries(value)) {
    if (forbidden.has(key.toLowerCase())) {
      throw new TypeError('client_declared_authority_forbidden');
    }
    visitClientValue(child, seen);
  }
}
