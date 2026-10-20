/**
 * SP-06 consumer boundary: whether a Content body is pinned to an existing
 * immutable BCK-10 public revision of the publisher's own, still active
 * Scenario. Planning answers from its own records; Content never reads them.
 *
 * - `ok`: the revision exists with this Scenario, owner, purpose and hash;
 * - `unknown`: no such revision;
 * - `forbidden`: another owner, Scenario or purpose, or a different hash;
 * - `stale`: the Scenario is no longer active;
 * - `unavailable`: the answer could not be obtained (fail closed).
 */
export type ScenarioRevisionStatus = 'ok' | 'unknown' | 'forbidden' | 'stale' | 'unavailable';

export interface ScenarioRevisionPort {
  verify(input: {
    readonly scenarioId: string;
    readonly scenarioRevisionId: string;
    readonly contentHash: string;
    readonly ownerUserId: string;
  }): Promise<ScenarioRevisionStatus>;
}
