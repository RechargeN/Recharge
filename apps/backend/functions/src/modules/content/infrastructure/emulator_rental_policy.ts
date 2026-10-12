import type { RentalMarketPolicy } from '../domain/type_rules/validation_context.js';
import {
  taxonomyPair,
  type TaxonomyDataset,
} from '../../reference_data/infrastructure/local_taxonomy_reader.js';

/**
 * TEST-ONLY Rental / Equipment policy of the local `demo-recharge` Emulator
 * (D3.3 §2 Q1a/Q1b), equal to
 * `packages/api_contracts/schema/content/v1/fixtures/rental_reference_policy.json`.
 *
 * It is NOT an accepted policy: BCK-20 has no Rental policy contract yet (open
 * dependency Q1b). The category whitelist and the "required" flags follow the
 * accepted Category System and the mobile `RentalCreatePolicy.safeFallback`;
 * the duration bounds follow RNT-CRT-01 §10.1; the freshness window (7 days),
 * the approximate precision (500 m), the delivery radius (50 km) and the policy
 * version ('1.0') are proposals only.
 *
 * Applicability of a subcategory to Rental is not defined by the accepted
 * taxonomy, so the policy answers only an explicit list of test pairs, and
 * only while that pair exists in the pinned BCK-20 revision. Anything else has
 * no policy and fails closed (`rental.policy_unavailable`).
 */
export const emulatorRentalPolicyId = 'test-only-rental-policy-1';

export const emulatorRentalCategories = Object.freeze([
  'sport',
  'water_activities',
  'winter_seasonal',
  'adrenaline_entertainment',
  'auto_moto',
] as const);

export const emulatorRentalPairs: readonly {
  readonly categoryId: string;
  readonly subcategoryId: string;
}[] = Object.freeze([
  { categoryId: 'sport', subcategoryId: 'cycling' },
  { categoryId: 'water_activities', subcategoryId: 'sup' },
  { categoryId: 'water_activities', subcategoryId: 'kayak' },
  { categoryId: 'winter_seasonal', subcategoryId: 'skiing' },
  { categoryId: 'auto_moto', subcategoryId: 'offroad_trip' },
]);

export const emulatorRentalPolicyBase = Object.freeze({
  policyVersion: '1.0',
  coverageFreshnessDays: 7,
  absoluteMinMinutes: 60,
  absoluteMaxMinutes: 129600,
  minApproximatePrecisionMeters: 500,
  maxDeliveryRadiusKm: 50,
});

/** Category-level "required" flags (mobile `safeFallback`). */
export const emulatorRentalRequirements: Readonly<
  Record<
    (typeof emulatorRentalCategories)[number],
    {
      readonly requiresSizeOrVariant: boolean;
      readonly requiresMinRenterAge: boolean;
      readonly requiresIdAtHandover: boolean;
      readonly requiresSafetyNotice: boolean;
    }
  >
> = Object.freeze({
  sport: {
    requiresSizeOrVariant: true,
    requiresMinRenterAge: false,
    requiresIdAtHandover: false,
    requiresSafetyNotice: false,
  },
  water_activities: {
    requiresSizeOrVariant: false,
    requiresMinRenterAge: false,
    requiresIdAtHandover: false,
    requiresSafetyNotice: true,
  },
  winter_seasonal: {
    requiresSizeOrVariant: true,
    requiresMinRenterAge: false,
    requiresIdAtHandover: false,
    requiresSafetyNotice: false,
  },
  adrenaline_entertainment: {
    requiresSizeOrVariant: false,
    requiresMinRenterAge: true,
    requiresIdAtHandover: false,
    requiresSafetyNotice: true,
  },
  auto_moto: {
    requiresSizeOrVariant: false,
    requiresMinRenterAge: true,
    requiresIdAtHandover: true,
    requiresSafetyNotice: true,
  },
});

/**
 * The policy of one pair, or `undefined` (no policy: fail closed) for a pair
 * outside the test list, a category outside the whitelist, or a pair the
 * pinned BCK-20 revision does not contain.
 */
export function emulatorRentalPolicy(
  dataset: TaxonomyDataset,
  categoryId: string,
  subcategoryId: string,
): RentalMarketPolicy | undefined {
  const listed = emulatorRentalPairs.some(
    (pair) => pair.categoryId === categoryId && pair.subcategoryId === subcategoryId,
  );
  if (!listed) return undefined;
  if (taxonomyPair(dataset, categoryId, subcategoryId) === undefined) return undefined;
  const requirements =
    emulatorRentalRequirements[categoryId as (typeof emulatorRentalCategories)[number]];
  if (requirements === undefined) return undefined;
  return Object.freeze({ enabled: true, ...emulatorRentalPolicyBase, ...requirements });
}
