import type { ContentBody, ContentTypeId } from '../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import { isInternalRegistration } from './event_internal_registration.js';
import { isRecord } from './type_rules/validation_context.js';

/**
 * ADR 0023, owner decision 2026-11-08 ("risk by money"): a User publishes any
 * personal content without identity verification unless the publication takes
 * money or reserves places — a price above zero, place booking, rental or
 * shared expenses. Those need the server verification fact (or a verified
 * Page). Drafts are free to create and edit; the check runs where content
 * leaves the draft (submit, publish, activation).
 *
 * Rental and Session always rent or book. Event: a fixed price or Recharge
 * internal registration. Class/Workshop: a fixed price. Find People: an
 * estimated shared cost. Place, Activity, Route, Scenario and Collection carry
 * no price, booking or payment of the author (a Place's entry price describes
 * a third party). An unknown type is risky.
 */
export function contentInvolvesMoney(typeId: ContentTypeId, body: ContentBody): boolean {
  const section = (key: string): Record<string, unknown> | null => {
    const value = (body as Record<string, unknown>)[key];
    return isRecord(value) ? value : null;
  };
  switch (typeId) {
    case 'place':
    case 'activity':
    case 'route':
    case 'scenario':
    case 'collection':
      return false;
    case 'rental':
    case 'session':
      return true;
    case 'event':
      return section('pricing')?.mode !== 'free' || isInternalRegistration(body);
    case 'class_workshop': {
      const price = section('class_workshop')?.price;
      return !isRecord(price) || price.mode !== 'free';
    }
    case 'find_people': {
      const cost = section('findPeople')?.cost;
      return !isRecord(cost) || cost.costType === 'estimated';
    }
    default:
      return true;
  }
}

/**
 * Whether the publisher needs the identity verification fact. A Page always
 * keeps its own verification rule; a personal publisher only when the
 * publication involves money (`involvesMoney`, computed from the body where
 * content leaves the draft; absent while a draft is created or edited).
 */
export function identityVerificationRequired(
  publisherRef: PublisherRefV1,
  involvesMoney: boolean,
): boolean {
  return publisherRef.type !== 'user' || involvesMoney;
}
