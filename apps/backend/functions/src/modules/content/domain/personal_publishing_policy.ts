import type { ContentTypeId } from '../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';

/**
 * ADR 0023 OQ-2: a User publishes free personal content without identity
 * verification. These types carry no price, booking, rental or money and no
 * 18+ consent. Every other type (Event with booking, Rental, Session,
 * Class/Workshop, Find People) still needs the server verification fact for
 * the personal publisher. An unknown type is risky by default.
 */
export const freePersonalContentTypes: ReadonlySet<ContentTypeId> = new Set<ContentTypeId>([
  'place',
  'activity',
  'collection',
  'route',
  'scenario',
]);

export function identityVerificationRequired(
  typeId: ContentTypeId,
  publisherRef: PublisherRefV1,
): boolean {
  return publisherRef.type !== 'user' || !freePersonalContentTypes.has(typeId);
}
