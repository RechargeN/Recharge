import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import {
  IssueCollector,
  hasOnlyKeys,
  hasUnreplacedLocalId,
  intervalsOverlap,
  isCurrencyCode,
  isEnumValue,
  isInstant,
  isIanaZone,
  isInt,
  isMinorUnits,
  isNumberIn,
  isOpeningPeriod,
  isRecord,
  isSafeHttpsUrl,
  isStringList,
  isText,
  weeklyIntervals,
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
  type OpeningPeriod,
  type RentalMarketPolicy,
} from './validation_context.js';

/**
 * Rental / Equipment source rules (RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC
 * RNT-CRT-01, Approved) — the §14 submit invariants over the §7 payload.
 *
 * The body is the PUBLIC listing only. The private authoring extension of §7.3
 * (exact address/geo, handover instructions, per-group and per-block notes) is
 * local-only and is rejected explicitly here. Limits come from the versioned
 * market/category policy resolved by the pinned reference authority; a missing
 * policy is `unknown` and fails closed.
 */
export const rentalDefaultLimits = Object.freeze({
  titleMin: 3,
  titleMax: 80,
  shortDescriptionMin: 20,
  shortDescriptionMax: 240,
  fullDescriptionMin: 50,
  fullDescriptionMax: 4000,
  maxGroups: 50,
  maxQuantity: 999,
  maxMediaRefs: 13,
});

const conditions = ['new', 'like_new', 'good', 'worn'] as const;
const groupStatuses = ['available', 'paused', 'retired'] as const;
const blockSources = [
  'manual_external_rental',
  'maintenance',
  'owner_unavailable',
  'other',
] as const;
const blockStatuses = ['active', 'cancelled'] as const;
const disclosures = ['approximate_area', 'public_business_address'] as const;
const scheduleModes = ['opening_hours', 'by_arrangement'] as const;
const billingUnits = [60, 1440, 10080] as const;
const collectionMethods = ['none', 'at_handover', 'external_provider', 'other'] as const;

/** Private authoring data (§7.3) that must never reach the public listing. */
const privateKeys = new Set([
  'privateAuthoring',
  'exactPickupAddress',
  'exactPickupGeo',
  'handoverInstructions',
  'inventoryNotesByGroupId',
  'availabilityNotesByBlockId',
]);

const topLevelKeys = new Set([
  'title',
  'shortDescription',
  'fullDescription',
  'categoryId',
  'subcategoryId',
  'categoryConfirmed',
  'brandModel',
  'mediaRefs',
  'inventoryGroups',
  'availability',
  'handover',
  'terms',
  'pricing',
  'fulfillment',
  'attestation',
]);

const msPerDay = 24 * 60 * 60 * 1000;

export function validateRentalBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  const issues = new IssueCollector();
  rejectPrivateFields(body, issues);
  hasOnlyKeys(body, topLevelKeys, issues, 'rental');
  const policy = validateListing(body, issues, context);
  const groups = validateInventory(body.inventoryGroups, policy, issues);
  validateAvailability(body.availability, groups, policy, issues, context);
  validateHandover(body.handover, policy, issues);
  const terms = validateTerms(body.terms, body.inventoryGroups, policy, issues);
  validatePricing(body.pricing, terms, issues);
  validateFulfillment(body.fulfillment, issues);
  validateAttestation(body.attestation, policy, issues, context);
  issues.require(!hasUnreplacedLocalId(body), 'rental.local_id_unreplaced');
  return issues.result();
}

/** Listing photos then per-group photos: the exact set Media must confirm. */
export function rentalMediaIds(body: ContentBody): readonly string[] {
  const ids: string[] = [];
  if (Array.isArray(body.mediaRefs))
    for (const ref of body.mediaRefs) if (typeof ref === 'string') ids.push(ref);
  if (Array.isArray(body.inventoryGroups))
    for (const group of body.inventoryGroups)
      if (isRecord(group) && Array.isArray(group.photoRefs))
        for (const ref of group.photoRefs) if (typeof ref === 'string') ids.push(ref);
  return [...new Set(ids)];
}

function rejectPrivateFields(value: unknown, issues: IssueCollector, depth = 0): void {
  if (depth > 8) return;
  if (Array.isArray(value)) {
    for (const item of value) rejectPrivateFields(item, issues, depth + 1);
    return;
  }
  if (!isRecord(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (privateKeys.has(key)) issues.add(`rental.private_field_forbidden:${key}`);
    rejectPrivateFields(child, issues, depth + 1);
  }
}

function validateListing(
  body: ContentBody,
  issues: IssueCollector,
  context: ContentValidationContext,
): RentalMarketPolicy | undefined {
  const limits = rentalDefaultLimits;
  issues.require(isText(body.title, limits.titleMin, limits.titleMax), 'rental.title_length');
  issues.require(
    isText(body.shortDescription, limits.shortDescriptionMin, limits.shortDescriptionMax),
    'rental.short_description_length',
  );
  issues.require(
    isText(body.fullDescription, limits.fullDescriptionMin, limits.fullDescriptionMax),
    'rental.full_description_length',
  );
  if (body.brandModel !== undefined)
    issues.require(isText(body.brandModel, 1, 100), 'rental.brand_model_length');
  // A runtime default category is never a deliberate choice (§5).
  issues.require(body.categoryConfirmed === true, 'rental.category_not_confirmed');
  const media = body.mediaRefs;
  if (
    issues.require(
      isStringList(media, limits.maxMediaRefs, 128) && media.length >= 1,
      'rental.cover_required',
    )
  )
    issues.require(
      new Set(media as string[]).size === (media as string[]).length,
      'rental.media_duplicate',
    );

  const categoryOk = isText(body.categoryId, 1, 64);
  const subcategoryOk = isText(body.subcategoryId, 1, 64);
  issues.require(categoryOk, 'rental.category_required');
  issues.require(subcategoryOk, 'rental.subcategory_required');
  if (!categoryOk || !subcategoryOk) return undefined;
  const policy = context.lookups.rentalPolicy?.(
    body.categoryId as string,
    body.subcategoryId as string,
  );
  if (policy === undefined) {
    // Unknown policy is not permission: submit fails closed.
    issues.add('rental.policy_unavailable');
    return undefined;
  }
  issues.require(policy.enabled, 'rental.market_policy_unsupported');
  return policy;
}

interface GroupInfo {
  readonly quantity: number;
  readonly status: string;
}

function validateInventory(
  value: unknown,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
): ReadonlyMap<string, GroupInfo> {
  const groups = new Map<string, GroupInfo>();
  if (!issues.require(Array.isArray(value), 'rental.inventory_required')) return groups;
  const list = value as unknown[];
  issues.require(
    list.length >= 1 && list.length <= rentalDefaultLimits.maxGroups,
    'rental.inventory_group_count',
  );
  for (const item of list) {
    if (!isRecord(item)) {
      issues.add('rental.inventory_group_invalid');
      continue;
    }
    hasOnlyKeys(
      item,
      new Set([
        'id',
        'label',
        'quantity',
        'condition',
        'sizeOrVariant',
        'includedAccessories',
        'photoRefs',
        'status',
      ]),
      issues,
      'rental.group',
    );
    const id = item.id;
    if (!isEntityId(id)) issues.add('rental.inventory_group_id_invalid');
    else if (groups.has(id)) issues.add('rental.inventory_group_id_duplicate');
    issues.require(isText(item.label, 1, 80), 'rental.inventory_group_label');
    const quantityOk = issues.require(
      isInt(item.quantity, 1, rentalDefaultLimits.maxQuantity),
      'rental.inventory_group_quantity',
    );
    issues.require(isEnumValue(item.condition, conditions), 'rental.inventory_group_condition');
    issues.require(isEnumValue(item.status, groupStatuses), 'rental.inventory_group_status');
    if (item.sizeOrVariant !== undefined)
      issues.require(isText(item.sizeOrVariant, 1, 80), 'rental.inventory_group_size');
    else if (policy?.requiresSizeOrVariant === true)
      issues.add('rental.inventory_group_size_required');
    if (item.includedAccessories !== undefined)
      issues.require(
        isStringList(item.includedAccessories, 20, 80),
        'rental.inventory_group_accessories',
      );
    if (item.photoRefs !== undefined)
      issues.require(isStringList(item.photoRefs, 5, 128), 'rental.inventory_group_photos');
    if (isEntityId(id) && quantityOk && typeof item.status === 'string')
      groups.set(id, { quantity: item.quantity as number, status: item.status });
  }
  issues.require(
    [...groups.values()].some((group) => group.status === 'available'),
    'rental.inventory_no_available_group',
  );
  return groups;
}

interface ActiveBlock {
  readonly start: number;
  readonly end: number;
  readonly units: number;
}

function validateAvailability(
  value: unknown,
  groups: ReadonlyMap<string, GroupInfo>,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(isRecord(value), 'rental.availability_required')) return;
  const availability = value as Json;
  hasOnlyKeys(
    availability,
    new Set(['timeZoneId', 'coverage', 'blocks']),
    issues,
    'rental.availability',
  );
  issues.require(isIanaZone(availability.timeZoneId), 'rental.availability_timezone');
  validateCoverage(availability.coverage, policy, issues, context);
  const blocks = availability.blocks ?? [];
  if (!issues.require(Array.isArray(blocks), 'rental.availability_blocks_invalid')) return;
  const ids = new Set<string>();
  const byGroup = new Map<string, ActiveBlock[]>();
  for (const block of blocks as unknown[]) {
    if (!isRecord(block)) {
      issues.add('rental.availability_block_invalid');
      continue;
    }
    hasOnlyKeys(
      block,
      new Set([
        'id',
        'groupId',
        'startsAtUtc',
        'endsAtUtc',
        'unitsBlocked',
        'source',
        'status',
        'revision',
        'createdByUserId',
        'createdAtUtc',
        'updatedAtUtc',
      ]),
      issues,
      'rental.block',
    );
    const id = block.id;
    if (!isEntityId(id)) issues.add('rental.availability_block_id_invalid');
    else if (ids.has(id)) issues.add('rental.availability_block_id_duplicate');
    else ids.add(id);
    issues.require(isEntityId(block.createdByUserId), 'rental.availability_block_author');
    issues.require(isEnumValue(block.source, blockSources), 'rental.availability_block_source');
    issues.require(isEnumValue(block.status, blockStatuses), 'rental.availability_block_status');
    issues.require(isInt(block.revision, 1, 1000000), 'rental.availability_block_revision');
    issues.require(
      isInstant(block.createdAtUtc) && isInstant(block.updatedAtUtc),
      'rental.availability_block_timestamps',
    );
    const group = typeof block.groupId === 'string' ? groups.get(block.groupId) : undefined;
    if (group === undefined) issues.add('rental.availability_block_group_unknown');
    const unitsOk = isInt(block.unitsBlocked, 1, rentalDefaultLimits.maxQuantity);
    issues.require(unitsOk, 'rental.availability_block_units');
    const intervalOk =
      isInstant(block.startsAtUtc) &&
      isInstant(block.endsAtUtc) &&
      Date.parse(block.startsAtUtc) < Date.parse(block.endsAtUtc);
    // Half-open [start, end): adjacent intervals never overlap.
    issues.require(intervalOk, 'rental.availability_block_interval');
    if (
      block.status === 'active' &&
      intervalOk &&
      unitsOk &&
      group !== undefined &&
      typeof block.groupId === 'string'
    ) {
      const bucket = byGroup.get(block.groupId) ?? [];
      bucket.push({
        start: Date.parse(block.startsAtUtc as string),
        end: Date.parse(block.endsAtUtc as string),
        units: block.unitsBlocked as number,
      });
      byGroup.set(block.groupId, bucket);
    }
  }
  for (const [groupId, active] of byGroup) {
    const quantity = groups.get(groupId)?.quantity ?? 0;
    issues.require(
      peakConcurrentUnits(active) <= quantity,
      'rental.availability_capacity_exceeded',
    );
  }
}

/** Sweep line over half-open intervals: ends are processed before starts. */
function peakConcurrentUnits(blocks: readonly ActiveBlock[]): number {
  const events = blocks.flatMap((block) => [
    { at: block.start, delta: block.units },
    { at: block.end, delta: -block.units },
  ]);
  events.sort((left, right) => left.at - right.at || left.delta - right.delta);
  let current = 0;
  let peak = 0;
  for (const event of events) {
    current += event.delta;
    peak = Math.max(peak, current);
  }
  return peak;
}

function validateCoverage(
  value: unknown,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  // An empty calendar is not availability: coverage must be explicit and fresh.
  if (!issues.require(isRecord(value), 'rental.coverage_required')) return;
  const coverage = value as Json;
  hasOnlyKeys(
    coverage,
    new Set(['startsAtUtc', 'endsAtUtc', 'confirmedAtUtc']),
    issues,
    'rental.coverage',
  );
  if (
    !issues.require(
      isInstant(coverage.startsAtUtc) &&
        isInstant(coverage.endsAtUtc) &&
        isInstant(coverage.confirmedAtUtc) &&
        Date.parse(coverage.startsAtUtc) < Date.parse(coverage.endsAtUtc),
      'rental.coverage_invalid',
    )
  )
    return;
  const confirmedAt = Date.parse(coverage.confirmedAtUtc as string);
  const now = Date.parse(context.nowUtc);
  issues.require(confirmedAt <= now, 'rental.coverage_confirmed_in_future');
  if (policy !== undefined)
    issues.require(
      now - confirmedAt <= policy.coverageFreshnessDays * msPerDay,
      'rental.coverage_stale',
    );
}

function validateHandover(
  value: unknown,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
): void {
  if (!issues.require(isRecord(value), 'rental.handover_required')) return;
  const handover = value as Json;
  hasOnlyKeys(
    handover,
    new Set([
      'pickupPlaceName',
      'publicAreaLabel',
      'publicAddress',
      'publicGeo',
      'publicGeoPrecisionMeters',
      'disclosure',
      'scheduleMode',
      'openingHours',
      'deliveryAvailable',
      'deliveryRadiusKm',
      'deliveryFee',
      'deliveryTerms',
    ]),
    issues,
    'rental.handover',
  );
  issues.require(isText(handover.pickupPlaceName, 1, 100), 'rental.handover_place_name');
  issues.require(isText(handover.publicAreaLabel, 1, 100), 'rental.handover_area_label');
  const geo = handover.publicGeo;
  issues.require(
    isRecord(geo) && isNumberIn(geo.latitude, -90, 90) && isNumberIn(geo.longitude, -180, 180),
    'rental.handover_geo',
  );
  issues.require(isInt(handover.publicGeoPrecisionMeters, 1, 100000), 'rental.handover_precision');
  if (handover.publicAddress !== undefined)
    issues.require(isText(handover.publicAddress, 1, 300), 'rental.handover_address');
  if (issues.require(isEnumValue(handover.disclosure, disclosures), 'rental.handover_disclosure')) {
    if (handover.disclosure === 'public_business_address')
      issues.require(
        handover.publicAddress !== undefined,
        'rental.handover_public_address_required',
      );
    else {
      // An approximate area never carries an address, and its geo is coarsened.
      issues.require(
        handover.publicAddress === undefined,
        'rental.handover_approximate_has_address',
      );
      if (policy !== undefined && isInt(handover.publicGeoPrecisionMeters, 1, 100000))
        issues.require(
          handover.publicGeoPrecisionMeters >= policy.minApproximatePrecisionMeters,
          'rental.handover_precision_too_fine',
        );
    }
  }
  if (
    issues.require(
      isEnumValue(handover.scheduleMode, scheduleModes),
      'rental.handover_schedule_mode',
    )
  ) {
    if (handover.scheduleMode === 'opening_hours')
      validateOpeningHours(handover.openingHours, issues);
  }
  validateDelivery(handover, policy, issues);
}

function validateOpeningHours(value: unknown, issues: IssueCollector): void {
  if (
    !issues.require(
      Array.isArray(value) && value.length >= 1 && value.length <= 28,
      'rental.handover_hours_required',
    )
  )
    return;
  const rules = value as unknown[];
  if (
    !issues.require(
      rules.every((rule) => isOpeningPeriod(rule, true)),
      'rental.handover_hours_invalid',
    )
  )
    return;
  issues.require(
    !intervalsOverlap(weeklyIntervals(rules as OpeningPeriod[])),
    'rental.handover_hours_overlap',
  );
}

function validateDelivery(
  handover: Json,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
): void {
  if (!issues.require(typeof handover.deliveryAvailable === 'boolean', 'rental.delivery_flag'))
    return;
  const hasChildren =
    handover.deliveryRadiusKm !== undefined ||
    handover.deliveryFee !== undefined ||
    handover.deliveryTerms !== undefined;
  if (handover.deliveryAvailable === false) {
    // A disabled option clears its children; leftovers would be a hidden offer.
    issues.require(!hasChildren, 'rental.delivery_not_cleared');
    return;
  }
  const radius = handover.deliveryRadiusKm;
  const radiusOk =
    typeof radius === 'number' &&
    Number.isFinite(radius) &&
    radius > 0 &&
    (policy === undefined || radius <= policy.maxDeliveryRadiusKm);
  issues.require(radiusOk, 'rental.delivery_radius');
  const fee = handover.deliveryFee;
  // Explicit fee, zero included: an absent fee is not the same as free.
  issues.require(
    isRecord(fee) && isMinorUnits(fee.minorUnits) && isCurrencyCode(fee.currencyCode),
    'rental.delivery_fee_required',
  );
  issues.require(isText(handover.deliveryTerms, 1, 500), 'rental.delivery_terms_required');
}

interface TermsInfo {
  readonly offeredMinMinutes: number | undefined;
}

function validateTerms(
  value: unknown,
  groups: unknown,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
): TermsInfo {
  if (!issues.require(isRecord(value), 'rental.terms_required'))
    return { offeredMinMinutes: undefined };
  const terms = value as Json;
  hasOnlyKeys(
    terms,
    new Set([
      'offeredMinMinutes',
      'offeredMaxMinutes',
      'minRenterAge',
      'idRequiredAtHandover',
      'usageRestrictions',
      'safetyNotice',
      'includedAccessoriesConfirmation',
    ]),
    issues,
    'rental.terms',
  );
  const min = terms.offeredMinMinutes;
  const max = terms.offeredMaxMinutes;
  const rangeOk = issues.require(
    isInt(min, 1, 10000000) && isInt(max, 1, 10000000),
    'rental.duration_invalid',
  );
  if (rangeOk) {
    issues.require((min as number) <= (max as number), 'rental.duration_range_invalid');
    if (policy !== undefined) {
      issues.require(
        (min as number) >= policy.absoluteMinMinutes &&
          (max as number) <= policy.absoluteMaxMinutes,
        'rental.duration_outside_platform_bounds',
      );
    }
  }
  if (terms.minRenterAge !== undefined)
    issues.require(isInt(terms.minRenterAge, 0, 99), 'rental.min_renter_age');
  else if (policy?.requiresMinRenterAge === true) issues.add('rental.min_renter_age_required');
  issues.require(typeof terms.idRequiredAtHandover === 'boolean', 'rental.id_requirement');
  if (policy?.requiresIdAtHandover === true)
    issues.require(terms.idRequiredAtHandover === true, 'rental.id_requirement_required');
  if (terms.usageRestrictions !== undefined)
    issues.require(isText(terms.usageRestrictions, 1, 1000), 'rental.usage_restrictions');
  if (terms.safetyNotice !== undefined)
    issues.require(isText(terms.safetyNotice, 1, 1000), 'rental.safety_notice');
  else if (policy?.requiresSafetyNotice === true) issues.add('rental.safety_notice_required');
  issues.require(
    typeof terms.includedAccessoriesConfirmation === 'boolean',
    'rental.accessories_confirmation',
  );
  const hasAccessories =
    Array.isArray(groups) &&
    groups.some(
      (group) =>
        isRecord(group) &&
        Array.isArray(group.includedAccessories) &&
        group.includedAccessories.length > 0,
    );
  if (hasAccessories)
    issues.require(
      terms.includedAccessoriesConfirmation === true,
      'rental.accessories_not_confirmed',
    );
  return { offeredMinMinutes: isInt(min, 1, 10000000) ? min : undefined };
}

function validatePricing(value: unknown, terms: TermsInfo, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'rental.pricing_required')) return;
  const pricing = value as Json;
  hasOnlyKeys(
    pricing,
    new Set([
      'currencyCode',
      'billingUnitMinutes',
      'rateSteps',
      'billingRounding',
      'deposit',
      'damagePolicy',
      'lateReturnPolicy',
      'cancellationPolicyId',
      'cancellationPolicyNote',
    ]),
    issues,
    'rental.pricing',
  );
  // The currency is the listing's own explicit choice, never inferred from market.
  const currencyOk = issues.require(
    isCurrencyCode(pricing.currencyCode),
    'rental.currency_invalid',
  );
  const currency = currencyOk ? (pricing.currencyCode as string) : undefined;
  const unitOk = issues.require(
    (billingUnits as readonly unknown[]).includes(pricing.billingUnitMinutes),
    'rental.billing_unit',
  );
  if (unitOk && terms.offeredMinMinutes !== undefined)
    issues.require(
      (pricing.billingUnitMinutes as number) <= terms.offeredMinMinutes,
      'rental.billing_unit_exceeds_min_duration',
    );
  issues.require(pricing.billingRounding === 'started_unit', 'rental.billing_rounding');
  validateRateSteps(pricing.rateSteps, currency, issues);
  validateDeposit(pricing.deposit, currency, issues);
  issues.require(isText(pricing.damagePolicy, 1, 1000), 'rental.damage_policy_required');
  if (pricing.lateReturnPolicy !== undefined)
    issues.require(isText(pricing.lateReturnPolicy, 1, 1000), 'rental.late_return_policy');
  issues.require(
    isText(pricing.cancellationPolicyId, 1, 64),
    'rental.cancellation_policy_required',
  );
  if (pricing.cancellationPolicyNote !== undefined)
    issues.require(
      isText(pricing.cancellationPolicyNote, 1, 500),
      'rental.cancellation_policy_note',
    );
}

function validateRateSteps(
  value: unknown,
  currency: string | undefined,
  issues: IssueCollector,
): void {
  if (
    !issues.require(
      Array.isArray(value) && value.length >= 1 && value.length <= 20,
      'rental.rate_steps_required',
    )
  )
    return;
  const steps = value as unknown[];
  let previousUnits = 0;
  let previousPrice = Number.POSITIVE_INFINITY;
  steps.forEach((step, index) => {
    if (
      !isRecord(step) ||
      !isInt(step.minUnits, 1, 100000) ||
      !isRecord(step.unitPrice) ||
      !isMinorUnits(step.unitPrice.minorUnits)
    ) {
      issues.add('rental.rate_step_invalid');
      return;
    }
    if (currency !== undefined)
      issues.require(step.unitPrice.currencyCode === currency, 'rental.rate_step_currency');
    if (index === 0) issues.require(step.minUnits === 1, 'rental.rate_first_step');
    else issues.require(step.minUnits > previousUnits, 'rental.rate_thresholds_not_increasing');
    issues.require(step.unitPrice.minorUnits <= previousPrice, 'rental.rate_price_increases');
    previousUnits = step.minUnits;
    previousPrice = step.unitPrice.minorUnits;
  });
}

function validateDeposit(
  value: unknown,
  currency: string | undefined,
  issues: IssueCollector,
): void {
  // A missing policy is not zero: submit is blocked until it is explicit.
  if (!issues.require(isRecord(value), 'rental.deposit_required')) return;
  const deposit = value as Json;
  hasOnlyKeys(deposit, new Set(['amount', 'collectionMethod', 'terms']), issues, 'rental.deposit');
  const amount = deposit.amount;
  const amountOk =
    isRecord(amount) && isMinorUnits(amount.minorUnits) && isCurrencyCode(amount.currencyCode);
  if (!issues.require(amountOk, 'rental.deposit_amount')) return;
  const money = amount as Json;
  if (currency !== undefined)
    issues.require(money.currencyCode === currency, 'rental.deposit_currency');
  const methodOk = issues.require(
    isEnumValue(deposit.collectionMethod, collectionMethods),
    'rental.deposit_method',
  );
  if (!methodOk) return;
  if (money.minorUnits === 0)
    issues.require(deposit.collectionMethod === 'none', 'rental.deposit_zero_needs_none');
  else {
    issues.require(deposit.collectionMethod !== 'none', 'rental.deposit_method_required');
    issues.require(isText(deposit.terms, 1, 500), 'rental.deposit_terms_required');
  }
}

function validateFulfillment(value: unknown, issues: IssueCollector): void {
  if (!issues.require(isRecord(value), 'rental.fulfillment_required')) return;
  const fulfillment = value as Json;
  hasOnlyKeys(fulfillment, new Set(['mode', 'externalBookingUrl']), issues, 'rental.fulfillment');
  // V1 has one mode; in-app contact or phone are separate products.
  issues.require(fulfillment.mode === 'external_link', 'rental.fulfillment_mode');
  const url = fulfillment.externalBookingUrl;
  const safe = issues.require(isSafeHttpsUrl(url), 'rental.external_url_unsafe');
  if (safe) issues.require(new URL(url as string).hash === '', 'rental.external_url_fragment');
}

function validateAttestation(
  value: unknown,
  policy: RentalMarketPolicy | undefined,
  issues: IssueCollector,
  context: ContentValidationContext,
): void {
  if (!issues.require(isRecord(value), 'rental.attestation_required')) return;
  const attestation = value as Json;
  hasOnlyKeys(
    attestation,
    new Set([
      'policyVersion',
      'acceptedAtUtc',
      'acceptedByUserId',
      'hasRightToOffer',
      'listingAccurate',
      'prohibitedItemsAcknowledged',
    ]),
    issues,
    'rental.attestation',
  );
  issues.require(
    attestation.hasRightToOffer === true &&
      attestation.listingAccurate === true &&
      attestation.prohibitedItemsAcknowledged === true,
    'rental.attestation_incomplete',
  );
  // Acceptance belongs to the acting user and to the current policy version.
  issues.require(attestation.acceptedByUserId === context.actorUserId, 'rental.attestation_user');
  if (policy !== undefined)
    issues.require(
      attestation.policyVersion === policy.policyVersion,
      'rental.attestation_stale_policy',
    );
  else
    issues.require(isText(attestation.policyVersion, 1, 64), 'rental.attestation_policy_version');
  issues.require(
    isInstant(attestation.acceptedAtUtc) &&
      Date.parse(attestation.acceptedAtUtc) <= Date.parse(context.nowUtc),
    'rental.attestation_time',
  );
}
