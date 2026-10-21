import type { Firestore } from 'firebase-admin/firestore';

import type {
  RouteRevisionPort,
  RouteRevisionStatus,
} from '../content/application/ports/route_revision_port.js';
import { routeCollections } from './route_contract.js';

/** RP-01: Route's answer to Content about one pinned distribution revision. */
export class FirestoreRouteRevisionReader implements RouteRevisionPort {
  constructor(private readonly db: Firestore) {}

  async verify(input: {
    readonly routeId: string;
    readonly routeRevisionId: string;
    readonly contentHash: string;
    readonly authorUserId: string;
  }): Promise<RouteRevisionStatus> {
    try {
      const revision = (
        await this.db.collection(routeCollections.revisions).doc(input.routeRevisionId).get()
      ).data();
      if (revision === undefined) return 'unknown';
      if (
        revision.routeId !== input.routeId ||
        revision.ownerId !== input.authorUserId ||
        revision.contentHash !== input.contentHash
      )
        return 'forbidden';
      if (revision.status !== 'active') return 'stale';
      const route = (
        await this.db
          .collection(routeCollections.routes)
          .doc(`${input.authorUserId}:${input.routeId}`)
          .get()
      ).data();
      return route?.status === 'active' ? 'ok' : 'stale';
    } catch {
      return 'unavailable';
    }
  }
}
