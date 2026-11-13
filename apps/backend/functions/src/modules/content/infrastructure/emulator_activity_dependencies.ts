import type { ContentBody, ContentTypeId } from '../../../contracts/content_v1.js';
import type { ContentTypeRule } from '../domain/content_type_registry.js';

/**
 * D3.2 §2.4: what the Emulator authoring composition cannot resolve for
 * Recharge Activity fails closed. The accepted Activity validator checks only
 * that `location.linkedPlaceId` is a permanent id; whether that Place exists
 * and is live belongs to the Catalog owner (ACT-CRT-01 §13 step 5), and Place
 * is not in the Catalog (BCK08-OD-04). So here any linked Place is refused,
 * instead of being accepted unverified. Rules here only add issues.
 */
export const activityLinkedPlaceUnresolved = 'activity.linked_place_unresolved';

export function activityEmulatorDependencies(body: ContentBody): readonly string[] {
  const location = body.location;
  if (typeof location !== 'object' || location === null || Array.isArray(location)) return [];
  return 'linkedPlaceId' in location ? [activityLinkedPlaceUnresolved] : [];
}

/** Rules the Emulator authoring composition adds to accepted validators. */
export const emulatorCompositionRules: ReadonlyMap<ContentTypeId, ContentTypeRule> = new Map<
  ContentTypeId,
  ContentTypeRule
>([['activity', activityEmulatorDependencies]]);
