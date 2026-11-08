import type { ContentBody, ContentTypeId } from '../../../contracts/content_v1.js';
import { isRecord } from './type_rules/validation_context.js';

/**
 * ADR 0023, owner decision 2026-11-08 (marketplace rule, DSA Art. 30).
 *
 * - `none`: free content; publishes without any declaration or verification.
 * - `external`: paid, or a legally significant booking concluded outside
 *   Recharge (external link, payment on site). Needs the author's seller
 *   declaration (private / trader, contacts, trader registration data).
 * - `inApp`: Recharge itself concludes the contract (in-app payment or
 *   booking). A trader also needs the identity verification before sales start.
 *
 * Rental and Session book through an external link today; an Event with a
 * fixed price, a Class/Workshop with a fixed price and Find People with an
 * estimated shared cost are paid. Free internal Event registration takes no
 * money and concludes no sale (owner, 2026-11-08): `none`. In-app payment
 * collection would be `inApp`. An unknown type is the strictest.
 */
export type ContentCommerce = 'none' | 'external' | 'inApp';

export function contentCommerce(typeId: ContentTypeId, body: ContentBody): ContentCommerce {
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
      return 'none';
    case 'rental':
    case 'session':
      return 'external';
    case 'event': {
      const pricing = section('pricing');
      if (pricing?.paymentCollectionMode === 'internal') return 'inApp';
      return pricing?.mode === 'free' ? 'none' : 'external';
    }
    case 'class_workshop': {
      const price = section('class_workshop')?.price;
      return isRecord(price) && price.mode === 'free' ? 'none' : 'external';
    }
    case 'find_people': {
      const cost = section('findPeople')?.cost;
      return isRecord(cost) && cost.costType !== 'estimated' ? 'none' : 'external';
    }
    default:
      return 'inApp';
  }
}
