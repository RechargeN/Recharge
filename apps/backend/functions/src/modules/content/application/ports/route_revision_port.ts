/**
 * J2 / RTE-PUB-01 RP-01 consumer boundary: whether a Content body is pinned to
 * an existing immutable BCK-11 `RouteRevision` of the author's own, still
 * active Route. Route answers from its own records; Content never reads them.
 *
 * - `ok`: the revision exists with this Route, owner and hash;
 * - `unknown`: no such revision;
 * - `forbidden`: another owner or Route, or a different hash;
 * - `stale`: the Route or the snapshot is no longer active;
 * - `unavailable`: the answer could not be obtained (fail closed).
 */
export type RouteRevisionStatus = 'ok' | 'unknown' | 'forbidden' | 'stale' | 'unavailable';

export interface RouteRevisionPort {
  verify(input: {
    readonly routeId: string;
    readonly routeRevisionId: string;
    readonly contentHash: string;
    /** The Content author; a Page publisher never owns the Route itself. */
    readonly authorUserId: string;
  }): Promise<RouteRevisionStatus>;
}
