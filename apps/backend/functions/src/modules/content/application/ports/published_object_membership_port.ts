import type { CollectionObjectType } from '../../domain/type_rules/validation_context.js';

/**
 * Consumer boundary only (D3.4): whether a Collection item references an
 * allowed published object is decided by Catalog from the Content owner's
 * source, never by Content or by a client snapshot.
 *
 * - `ready`: published, visible, of this type and market;
 * - `withheld`: a published object of this type and market that its owner hid
 *   or moderation restricted (the author may acknowledge it, CLG §11);
 * - `unknown`: no publication with this id;
 * - `forbidden`: another type, market or visibility policy;
 * - `unavailable`: the answer could not be obtained (fail closed).
 */
export type PublishedObjectMembershipStatus =
  'ready' | 'withheld' | 'unknown' | 'forbidden' | 'unavailable';

export interface PublishedObjectMembershipPort {
  statusOf(input: {
    readonly objectType: CollectionObjectType;
    readonly objectId: string;
    readonly marketId: string;
  }): Promise<PublishedObjectMembershipStatus>;
}
