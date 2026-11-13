import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';

export type PublisherRef = PublisherRefV1;

export function createPublisherRef(type: 'user' | 'page', id: string): PublisherRef {
  return deepFreeze({ type, id: parseEntityId(id) });
}
