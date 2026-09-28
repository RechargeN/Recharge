import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export interface CollectionAccessRule {
  readonly collectionId: string;
  readonly dataClassId: string;
  readonly singleWriter: string;
  readonly serverReaders: readonly string[];
  readonly clientRead: 'deny' | 'actor_owned';
  readonly clientWrite: 'deny' | 'actor_owned';
  readonly marketScoped: boolean;
  readonly pageScoped: boolean;
}

export class CollectionAccessMatrix {
  readonly #rules: ReadonlyMap<string, DeepReadonly<CollectionAccessRule>>;

  constructor(rules: readonly CollectionAccessRule[]) {
    const map = new Map<string, DeepReadonly<CollectionAccessRule>>();
    for (const rule of rules) {
      if (
        !/^[A-Za-z][A-Za-z0-9]{0,95}$/.test(rule.collectionId) ||
        map.has(rule.collectionId) ||
        rule.singleWriter.trim().length === 0
      )
        throw new TypeError('collection_access_rule_invalid');
      map.set(
        rule.collectionId,
        deepFreeze({ ...rule, serverReaders: [...new Set(rule.serverReaders)].sort() }),
      );
    }
    this.#rules = map;
  }

  decision(collectionId: string):
    | DeepReadonly<CollectionAccessRule>
    | {
        readonly collectionId: string;
        readonly clientRead: 'deny';
        readonly clientWrite: 'deny';
        readonly reason: 'collection_unknown';
      } {
    return (
      this.#rules.get(collectionId) ?? {
        collectionId,
        clientRead: 'deny',
        clientWrite: 'deny',
        reason: 'collection_unknown',
      }
    );
  }
}

export const securityPrivacyCollectionAccess = new CollectionAccessMatrix([
  {
    collectionId: 'privacyRequests',
    dataClassId: 'privacy.request',
    singleWriter: 'privacy-orchestration',
    serverReaders: ['privacy-orchestration', 'audited-support'],
    clientRead: 'deny',
    clientWrite: 'deny',
    marketScoped: false,
    pageScoped: false,
  },
  {
    collectionId: 'privacyDomainTasks',
    dataClassId: 'privacy.task',
    singleWriter: 'privacy-orchestration',
    serverReaders: ['privacy-orchestration', 'domain-task-handler'],
    clientRead: 'deny',
    clientWrite: 'deny',
    marketScoped: true,
    pageScoped: false,
  },
  {
    collectionId: 'securityAuditEvents',
    dataClassId: 'security.audit',
    singleWriter: 'security-audit',
    serverReaders: ['security-privacy', 'incident-response'],
    clientRead: 'deny',
    clientWrite: 'deny',
    marketScoped: true,
    pageScoped: true,
  },
  ...[
    ['securityRateLimitCounters', 'security.rate-limit-counter'],
    ['securityRateLimitAttempts', 'security.rate-limit-attempt'],
    ['securityAudit', 'security.abuse-audit'],
  ].map(([collectionId, dataClassId]) => ({
    collectionId: collectionId ?? '',
    dataClassId: dataClassId ?? '',
    singleWriter: 'security-abuse-control',
    serverReaders: ['security-abuse-control', 'incident-response'],
    clientRead: 'deny' as const,
    clientWrite: 'deny' as const,
    marketScoped: true,
    pageScoped: false,
  })),
  ...[
    ['identityAccounts', 'identity.account'],
    ['identityProviderLinks', 'identity.provider-link'],
    ['identitySessions', 'identity.session'],
    ['identityAccessSnapshots', 'identity.access-snapshot'],
    ['identityCreatorVerifications', 'identity.creator-verification'],
    ['identityManagedPages', 'identity.managed-page'],
    ['identityPageMemberships', 'identity.page-membership'],
  ].map(([collectionId, dataClassId]) => ({
    collectionId: collectionId ?? '',
    dataClassId: dataClassId ?? '',
    singleWriter: 'identity-publisher',
    serverReaders: ['identity-publisher', 'security-privacy'],
    clientRead: 'deny' as const,
    clientWrite: 'deny' as const,
    marketScoped: collectionId === 'identityManagedPages',
    pageScoped:
      collectionId === 'identityManagedPages' || collectionId === 'identityPageMemberships',
  })),
  ...[
    ['bookingEventProjections', 'booking.event-projection', 'event-booking-projection-consumer'],
    ['bookings', 'booking.core', 'booking-authority'],
    ['bookingHolds', 'booking.hold', 'booking-authority'],
    ['bookingPoolLedgers', 'booking.pool-ledger', 'booking-authority'],
    ['bookingUserUsage', 'booking.user-usage', 'booking-authority'],
    ['bookingActiveKeys', 'booking.active-key', 'booking-authority'],
    ['bookingIdempotency', 'booking.idempotency', 'booking-authority'],
    ['bookingAudit', 'booking.audit', 'booking-authority'],
    ['bookingOutbox', 'booking.outbox', 'booking-authority'],
    ['eventBookingOutbox', 'event.booking-outbox', 'content-publication'],
    [
      'bookingProjectionDeliveries',
      'booking.projection-delivery',
      'event-booking-projection-consumer',
    ],
    [
      'bookingProjectionDiscoveryCheckpoints',
      'booking.projection-discovery-checkpoint',
      'event-booking-projection-consumer',
    ],
    [
      'bookingProjectionOperatorAudit',
      'booking.projection-operator-audit',
      'event-booking-projection-consumer',
    ],
    [
      'bookingReconfirmationDeadlineJobs',
      'booking.reconfirmation-deadline-job',
      'booking-authority',
    ],
    [
      'bookingReconfirmationDeadlineCheckpoints',
      'booking.reconfirmation-deadline-checkpoint',
      'booking-authority',
    ],
    [
      'bookingReconfirmationDeadlineOperatorAudit',
      'booking.reconfirmation-deadline-operator-audit',
      'booking-authority',
    ],
    ['bookingPrivacyProgress', 'booking.privacy-progress', 'privacy-orchestration'],
  ].map(([collectionId, dataClassId, singleWriter]) => ({
    collectionId: collectionId ?? '',
    dataClassId: dataClassId ?? '',
    singleWriter: singleWriter ?? '',
    serverReaders: ['booking-authority', 'privacy-orchestration', 'audited-support'],
    clientRead: 'deny' as const,
    clientWrite: 'deny' as const,
    marketScoped: true,
    pageScoped: false,
  })),
]);
