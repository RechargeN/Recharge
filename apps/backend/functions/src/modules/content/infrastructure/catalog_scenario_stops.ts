import type {
  PublishedObjectMembershipPort,
  PublishedObjectMembershipStatus,
} from '../application/ports/published_object_membership_port.js';
import type { ScenarioStopType } from '../domain/type_rules/validation_context.js';

/** Content type id of each Scenario stop type (Scenario Builder v1.7 §6). */
export const scenarioStopContentTypes: Readonly<
  Record<ScenarioStopType, 'event' | 'place' | 'activity' | 'session'>
> = Object.freeze({
  event: 'event',
  place: 'place',
  activity: 'activity',
  bookable_session: 'session',
});

/** The Catalog-owned exact-id evaluator, as this adapter needs it (structural). */
export interface StopStatusReader {
  status(input: {
    readonly typeId: 'event' | 'place' | 'activity' | 'session';
    readonly contentId: string;
    readonly marketId: string;
  }): Promise<{ readonly status: string }>;
}

/**
 * SCN-PUB-01 SP-08: the current status of one Scenario stop, asked from
 * Catalog exactly. Only `eligible` is `ready`; a hidden or restricted object is
 * `withheld`; any other type, Route included, is `forbidden`; a failure is
 * `unavailable` (fail closed).
 */
export class CatalogScenarioStops implements PublishedObjectMembershipPort {
  constructor(private readonly catalog: StopStatusReader) {}

  async statusOf(input: {
    readonly objectType: string;
    readonly objectId: string;
    readonly marketId: string;
  }): Promise<PublishedObjectMembershipStatus> {
    if (!Object.hasOwn(scenarioStopContentTypes, input.objectType)) return 'forbidden';
    try {
      const { status } = await this.catalog.status({
        typeId: scenarioStopContentTypes[input.objectType as ScenarioStopType],
        contentId: input.objectId,
        marketId: input.marketId,
      });
      switch (status) {
        case 'eligible':
          return 'ready';
        case 'withheld':
        case 'unknown':
        case 'forbidden':
          return status;
        default:
          return 'unavailable';
      }
    } catch {
      return 'unavailable';
    }
  }
}
