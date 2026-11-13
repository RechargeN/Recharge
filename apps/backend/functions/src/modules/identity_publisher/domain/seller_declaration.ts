import type {
  Dac7ActivityType,
  SellerDeclarationBodyV1,
  SellerDeclarationV1,
} from '../../../contracts/identity_v1.js';
import { parseEntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant } from '../../../shared/utc_instant.js';
import { IdentityFailure } from './failures.js';

/**
 * ADR 0023, owner decision 2026-11-08 (marketplace rule, DSA Art. 30): before a
 * paid or bookable publication goes live its author declares whether they act
 * as a private person or a trader, with contacts and — for a trader — the
 * registration data. DAC7 activity types are recorded per activity, with no
 * shared threshold. The declaration is the author's own statement: it is never
 * an identity verification and grants no role.
 */
export type SellerDeclaration = SellerDeclarationV1;

/** The declaration does not satisfy the contract (answered as `invalid_contract`). */
export class SellerDeclarationInvalid extends Error {
  constructor() {
    super('invalid_contract');
    this.name = 'SellerDeclarationInvalid';
  }
}

const emailPattern = /^[^@\s]{1,64}@[^@\s]{1,189}\.[^@\s]{2,}$/u;
const phonePattern = /^\+[1-9][0-9]{6,14}$/u;
const registrationPattern = /^[A-Za-z0-9 ./-]{3,40}$/u;
const vatPattern = /^[A-Z]{2}[A-Za-z0-9]{2,13}$/u;
const postalPattern = /^[A-Za-z0-9 -]{2,12}$/u;
const countryPattern = /^[A-Z]{2}$/u;
const activityTypes: ReadonlySet<Dac7ActivityType> = new Set(['personalServices', 'rentalOfGoods']);

const text = (value: unknown, min: number, max: number): string | null => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length >= min && trimmed.length <= max ? trimmed : null;
};

/** The normalized declaration body, or `invalid_contract` (fail closed). */
export function parseSellerDeclarationBody(value: unknown): SellerDeclarationBodyV1 {
  const invalid = (): never => {
    throw new SellerDeclarationInvalid();
  };
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return invalid();
  const body = value as Record<string, unknown>;
  const status = body.status;
  if (status !== 'private' && status !== 'trader') return invalid();
  const contactIn = body.contact as Record<string, unknown> | undefined;
  if (typeof contactIn !== 'object' || contactIn === null) return invalid();
  const email = contactIn.email === undefined ? undefined : text(contactIn.email, 3, 254);
  const phone = contactIn.phone;
  if (email === null || (email !== undefined && !emailPattern.test(email))) return invalid();
  if (phone !== undefined && (typeof phone !== 'string' || !phonePattern.test(phone)))
    return invalid();
  if (email === undefined && phone === undefined) return invalid();
  const types = body.dac7ActivityTypes;
  if (
    !Array.isArray(types) ||
    types.length > 2 ||
    new Set(types).size !== types.length ||
    types.some((type) => !activityTypes.has(type as Dac7ActivityType))
  )
    return invalid();
  const contact = {
    ...(email === undefined ? {} : { email }),
    ...(phone === undefined ? {} : { phone }),
  };
  const traderIn = body.trader as Record<string, unknown> | undefined;
  if (status === 'private') {
    if (traderIn !== undefined) return invalid();
    return { status, contact, dac7ActivityTypes: [...(types as Dac7ActivityType[])].sort() };
  }
  if (typeof traderIn !== 'object' || traderIn === null) return invalid();
  const legalName = text(traderIn.legalName, 2, 160);
  const registrationNumber = text(traderIn.registrationNumber, 3, 40);
  const vatId = traderIn.vatId;
  const addressIn = traderIn.address as Record<string, unknown> | undefined;
  if (
    legalName === null ||
    registrationNumber === null ||
    !registrationPattern.test(registrationNumber)
  )
    return invalid();
  if (vatId !== undefined && (typeof vatId !== 'string' || !vatPattern.test(vatId)))
    return invalid();
  if (typeof addressIn !== 'object' || addressIn === null) return invalid();
  const line1 = text(addressIn.line1, 2, 160);
  const city = text(addressIn.city, 1, 80);
  const postalCode = text(addressIn.postalCode, 2, 12);
  const countryCode = addressIn.countryCode;
  if (
    line1 === null ||
    city === null ||
    postalCode === null ||
    !postalPattern.test(postalCode) ||
    typeof countryCode !== 'string' ||
    !countryPattern.test(countryCode)
  )
    return invalid();
  return {
    status,
    contact,
    trader: {
      legalName,
      registrationNumber,
      ...(vatId === undefined ? {} : { vatId }),
      address: { line1, city, postalCode, countryCode },
    },
    dac7ActivityTypes: [...(types as Dac7ActivityType[])].sort(),
  };
}

/**
 * The next revision of a user's declaration. `expectedRevision` is the
 * revision the author saw (0 for none): a concurrent change is refused.
 */
export function declareSeller(
  current: SellerDeclaration | null,
  input: {
    readonly userId: string;
    readonly body: unknown;
    readonly expectedRevision: number;
    readonly nowUtc: string;
  },
): SellerDeclaration {
  if ((current?.revision ?? 0) !== input.expectedRevision)
    throw new IdentityFailure('revision_conflict');
  return deepFreeze({
    schemaVersion: 1,
    userId: parseEntityId(input.userId),
    declaration: parseSellerDeclarationBody(input.body),
    revision: (current?.revision ?? 0) + 1,
    declaredAtUtc: parseUtcInstant(input.nowUtc),
  });
}
