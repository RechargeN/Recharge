import type { ContentBody } from '../../../../contracts/content_v1.js';
import { isEntityId } from '../../../../shared/ids.js';
import {
  containsCoordinatePair,
  findPeoplePolicy,
  isPublicCellCentre,
  publicCellCentre,
} from '../../../../shared/find_people_policy.js';
import {
  IssueCollector,
  hasOnlyKeys,
  isEnumValue,
  isIanaZone,
  isInstant,
  isInt,
  isNumberIn,
  isRecord,
  isStringList,
  isText,
  type ContentRuleIssues,
  type ContentValidationContext,
  type Json,
} from './validation_context.js';

/**
 * D3.7 (T3) Find People source rules. The draft body is the private source:
 * `findPeople.meeting.exact` is the only place exact meeting data may live.
 * The published body is a separate public projection built here, on the
 * server, from an allowlist (§3.2). Only the bounded T3 subset is accepted;
 * everything else is an explicit `*_unsupported` refusal, never a default.
 * The rules mirror the implemented mobile validator (FP-CRT-FIND-01).
 */

const topKeys = new Set([
  'title',
  'shortDescription',
  'fullDescription',
  'contentLocale',
  'categoryId',
  'subcategoryId',
  'tags',
  'findPeople',
]);

const commonKeys = [
  'schemaVersion',
  'skillLevel',
  'pace',
  'languageCodes',
  'participationGoal',
  'experienceRequirements',
  'equipmentNotes',
  'accessibilityNotes',
  'houseRuleIds',
  'houseRulesNote',
  'visibility',
  'schedule',
  'meeting',
  'group',
  'cost',
  'hosts',
] as const;
const sourceKeys = new Set<string>([...commonKeys, 'revision', 'confirmations']);
const publishedKeys = new Set<string>([...commonKeys, 'projection']);

/** Known fields of the full product (spec v3.1) that T3 does not serve. */
const unsupportedKeys: Readonly<Record<string, string>> = Object.freeze({
  applicationQuestions: 'find_people.application_questions_unsupported',
  plannedExpenseItems: 'find_people.expense_items_unsupported',
  coHosts: 'find_people.co_hosts_unsupported',
  shareLinkExpiresAtUtc: 'find_people.share_links_unsupported',
  allowParticipantInvites: 'find_people.participant_invites_unsupported',
  publishAtUtc: 'find_people.scheduled_publish_unsupported',
  onlineProvider: 'find_people.meeting_mode_unsupported',
  onlineAccessSecretRef: 'find_people.meeting_mode_unsupported',
  backupMeetingPlan: 'find_people.backup_plan_unsupported',
  media: 'find_people.media_unsupported',
});

/** Coordinates or a geo object anywhere except `meeting.exact` (§3.1). */
const geoKeys = new Set([
  'latitude',
  'longitude',
  'lat',
  'lng',
  'lon',
  'geo',
  'publicGeo',
  'exactGeo',
  'location',
  'coordinates',
  'point',
  'publicLocation',
]);
const clientAgeKey = /^(?:age|birthdate|dateofbirth|ageverified|guardianconsent|dob)$/iu;

const skillLevels = ['any', 'beginner', 'intermediate', 'advanced'] as const;
const goals = ['social', 'practice', 'team_up', 'shared_trip', 'accountability', 'other'] as const;
const approvalModes = ['manual', 'automatic'] as const;
const verificationLevels = ['none', 'phone', 'identity_document', 'organization'] as const;
const waitlistPolicies = ['first_come', 'host_review'] as const;
const seatFitPolicies = ['strict_order', 'first_fitting'] as const;
const costTypes = ['free', 'estimated', 'unknown'] as const;
const splitModes = ['none', 'equal', 'settle_later'] as const;
const conversationPolicies = ['accepted_only', 'applicants_and_accepted'] as const;
/** `findPeopleHouseRuleOptions` of the mobile Create config. */
export const findPeopleHouseRules: ReadonlySet<string> = new Set([
  'be_on_time',
  'respect_boundaries',
  'no_harassment',
  'no_sales',
  'no_substances',
  'bring_required_gear',
  'follow_venue_rules',
  'leave_no_trace',
]);
const configId = /^[a-z][a-z0-9_]{0,63}$/u;
const languagePattern = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/u;

/** Mobile `_containsContactOrPayment`: e-mail, link, handle, phone or payment hint. */
export function containsFindPeopleContact(value: string): boolean {
  const normalized = value.toLowerCase();
  return (
    /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/iu.test(value) ||
    /https?:\/\/|www\./iu.test(value) ||
    /(?<!\w)@[a-z0-9_]{3,}/iu.test(value) ||
    /\+?\d[\d\s().-]{7,}\d/u.test(value) ||
    normalized.includes('paypal') ||
    normalized.includes('revolut') ||
    normalized.includes('bank transfer')
  );
}

/** Mobile `_looksResidential`: private homes and access details are refused. */
function looksResidential(value: string): boolean {
  const normalized = value.toLowerCase();
  return [
    'apartment',
    'flat ',
    'door code',
    'home address',
    'квартира',
    'код двери',
    'домашний адрес',
  ].some((marker) => normalized.includes(marker));
}

/**
 * Coordinates may appear only under `allowedParent`: `meeting.exact` in the
 * private source, the server-built `meeting.publicLocation` in a published body
 * (where an `exact` object is itself forbidden).
 */
function scanForbiddenKeys(
  value: unknown,
  issues: IssueCollector,
  allowedParent: 'exact' | 'publicLocation',
  inside = false,
  depth = 0,
): void {
  if (depth > 12) return;
  if (Array.isArray(value)) {
    for (const item of value) scanForbiddenKeys(item, issues, allowedParent, inside, depth + 1);
    return;
  }
  if (!isRecord(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (clientAgeKey.test(key)) issues.add('find_people.client_age_forbidden');
    const allowed = key === allowedParent;
    if (!inside && !allowed && (geoKeys.has(key) || key === 'exact'))
      issues.add('find_people.public_geo_forbidden');
    scanForbiddenKeys(child, issues, allowedParent, inside || allowed, depth + 1);
  }
}

function publicText(
  value: unknown,
  issues: IssueCollector,
  code: string,
  min: number,
  max: number,
): void {
  if (!issues.require(isText(value, min, max), code)) return;
  checkPublicTextSafety(value as string, issues);
}

function optionalPublicText(
  value: unknown,
  issues: IssueCollector,
  code: string,
  max: number,
): void {
  if (value === undefined || value === null) return;
  publicText(value, issues, code, 0, max);
}

function checkPublicTextSafety(value: string, issues: IssueCollector): void {
  if (containsFindPeopleContact(value)) issues.add('find_people.public_contact_forbidden');
  if (containsCoordinatePair(value)) issues.add('find_people.public_coordinates_forbidden');
}

type Mode = 'source' | 'published';

function validate(body: ContentBody, context: ContentValidationContext, mode: Mode) {
  const issues = new IssueCollector();
  for (const key of Object.keys(body)) {
    if (topKeys.has(key)) continue;
    const specific = unsupportedKeys[key];
    issues.add(specific ?? `find_people.unknown_field:${key}`);
  }
  scanForbiddenKeys(body, issues, mode === 'source' ? 'exact' : 'publicLocation');
  issues.require(context.marketId === findPeoplePolicy.marketId, 'find_people.market');
  issues.require(
    context.publisherRef.type === 'page' ||
      (context.publisherRef.type === 'user' && context.publisherRef.id === context.createdByUserId),
    'find_people.publisher_ineligible',
  );
  publicText(body.title, issues, 'find_people.title', 5, 80);
  publicText(body.shortDescription, issues, 'find_people.short_description', 20, 180);
  publicText(body.fullDescription, issues, 'find_people.full_description', 50, 2000);
  const locale =
    typeof body.contentLocale === 'string'
      ? context.lookups.supportsLocale(body.contentLocale)
      : false;
  issues.require(
    locale === true,
    locale === undefined ? 'find_people.locale_unavailable' : 'find_people.locale',
  );
  const applies =
    typeof body.categoryId === 'string' && typeof body.subcategoryId === 'string'
      ? context.lookups.subcategoryApplies('find_people', body.categoryId, body.subcategoryId)
      : false;
  issues.require(
    applies === true,
    applies === undefined ? 'find_people.taxonomy_unavailable' : 'find_people.category',
  );
  if (body.tags !== undefined) {
    if (issues.require(isStringList(body.tags, 8, 64), 'find_people.tags'))
      for (const tag of body.tags as string[]) checkPublicTextSafety(tag, issues);
  }
  const data = body.findPeople;
  if (!isRecord(data)) {
    issues.add('find_people.payload');
    return issues.result();
  }
  const allowed = mode === 'source' ? sourceKeys : publishedKeys;
  for (const key of Object.keys(data)) {
    if (allowed.has(key)) continue;
    issues.add(unsupportedKeys[key] ?? `find_people.unknown_field:${key}`);
  }
  issues.require(data.schemaVersion === 1, 'find_people.schema');
  if (mode === 'source')
    issues.require(isInt(data.revision, 0, Number.MAX_SAFE_INTEGER), 'find_people.schema');
  else issues.require(data.projection === 'public_v1', 'find_people.projection');
  validateActivity(data, issues);
  if (data.visibility !== 'public')
    issues.add(
      data.visibility === 'unlisted' || data.visibility === 'invite_only'
        ? 'find_people.visibility_unsupported'
        : 'find_people.visibility',
    );
  validateSchedule(data.schedule, context, issues);
  validateMeeting(data.meeting, context, issues, mode);
  validateGroup(data.group, issues);
  validateCost(data.cost, context, issues);
  validateHosts(data.hosts, context, issues, mode);
  if (mode === 'source') {
    const confirmations = data.confirmations;
    if (isRecord(confirmations)) {
      hasOnlyKeys(
        confirmations,
        new Set(['safetyRulesAccepted', 'accuracyConfirmed', 'ageRequirementConfirmed']),
        issues,
        'find_people.confirmations',
      );
      issues.require(confirmations.safetyRulesAccepted === true, 'find_people.safety_rules');
      issues.require(confirmations.accuracyConfirmed === true, 'find_people.accuracy');
      // A declaration about the request's audience, never an age authority.
      issues.require(confirmations.ageRequirementConfirmed === true, 'find_people.adult_only');
    } else issues.add('find_people.safety_rules');
  }
  return issues.result();
}

function validateActivity(data: Json, issues: IssueCollector): void {
  issues.require(isEnumValue(data.skillLevel, skillLevels), 'find_people.skill_level');
  if (data.pace !== undefined && data.pace !== null)
    issues.require(typeof data.pace === 'string' && configId.test(data.pace), 'find_people.pace');
  const languages = data.languageCodes;
  issues.require(
    Array.isArray(languages) &&
      languages.length >= 1 &&
      languages.length <= 3 &&
      new Set(languages).size === languages.length &&
      languages.every((code) => typeof code === 'string' && languagePattern.test(code)),
    'find_people.languages',
  );
  issues.require(isEnumValue(data.participationGoal, goals), 'find_people.participation_goal');
  const requirements = data.experienceRequirements;
  if (
    issues.require(
      isStringList(requirements, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER),
      'find_people.experience_requirements',
    )
  )
    for (const item of requirements as string[]) checkPublicTextSafety(item, issues);
  optionalPublicText(data.equipmentNotes, issues, 'find_people.equipment_notes', 500);
  optionalPublicText(data.accessibilityNotes, issues, 'find_people.accessibility_notes', 500);
  optionalPublicText(data.houseRulesNote, issues, 'find_people.house_rules_note', 500);
  const rules = data.houseRuleIds;
  issues.require(
    Array.isArray(rules) &&
      rules.length <= 10 &&
      new Set(rules).size === rules.length &&
      rules.every((id) => typeof id === 'string' && findPeopleHouseRules.has(id)),
    'find_people.house_rules',
  );
}

function validateSchedule(
  value: unknown,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  if (!isRecord(value)) {
    issues.add('find_people.schedule');
    return;
  }
  hasOnlyKeys(
    value,
    new Set(['mode', 'timezoneId', 'slot', 'applicationDeadlineUtc']),
    issues,
    'find_people.schedule',
  );
  if (value.mode !== 'single') {
    issues.add(
      value.mode === 'time_poll' || value.mode === 'recurring'
        ? 'find_people.schedule_mode_unsupported'
        : 'find_people.schedule',
    );
    return;
  }
  issues.require(isIanaZone(value.timezoneId), 'find_people.timezone');
  const slot = value.slot;
  if (!isRecord(slot)) {
    issues.add('find_people.single_slot');
    return;
  }
  hasOnlyKeys(slot, new Set(['id', 'startAtUtc', 'endAtUtc']), issues, 'find_people.slot');
  issues.require(isEntityId(slot.id), 'find_people.slot_id');
  if (!isInstant(slot.startAtUtc) || !isInstant(slot.endAtUtc)) {
    issues.add('find_people.single_slot');
    return;
  }
  const start = Date.parse(slot.startAtUtc);
  const end = Date.parse(slot.endAtUtc);
  const minutes = (end - start) / 60_000;
  issues.require(minutes >= 30 && minutes <= 24 * 60, 'find_people.slot_duration');
  // FP-OD-03: the request lives until its meeting ends; an ended one is refused.
  issues.require(end > Date.parse(context.nowUtc), 'find_people.meeting_ended');
  issues.require(
    isInstant(value.applicationDeadlineUtc) && Date.parse(value.applicationDeadlineUtc) < start,
    'find_people.application_deadline',
  );
}

function validateMeeting(
  value: unknown,
  context: ContentValidationContext,
  issues: IssueCollector,
  mode: Mode,
): void {
  if (!isRecord(value)) {
    issues.add('find_people.meeting');
    return;
  }
  if (value.mode !== 'in_person') {
    issues.add(
      value.mode === 'online' || value.mode === 'hybrid'
        ? 'find_people.meeting_mode_unsupported'
        : 'find_people.meeting',
    );
    return;
  }
  publicText(value.publicAreaLabel, issues, 'find_people.public_area', 1, Number.MAX_SAFE_INTEGER);
  const policy = context.lookups.findPeoplePublicGeo?.();
  issues.require(policy !== undefined, 'find_people.geo_policy_unavailable');
  if (mode === 'source') {
    hasOnlyKeys(
      value,
      new Set(['mode', 'publicAreaLabel', 'publicPlaceConfirmed', 'exact']),
      issues,
      'find_people.meeting',
    );
    issues.require(value.publicPlaceConfirmed === true, 'find_people.public_place');
    const exact = value.exact;
    if (!isRecord(exact)) {
      issues.add('find_people.exact_location_required');
      return;
    }
    hasOnlyKeys(
      exact,
      new Set(['latitude', 'longitude', 'placeName', 'addressLine', 'instructions']),
      issues,
      'find_people.exact',
    );
    if (isNumberIn(exact.latitude, -90, 90) && isNumberIn(exact.longitude, -180, 180)) {
      const inside = context.lookups.pointInServiceArea(exact.latitude, exact.longitude);
      issues.require(
        inside === true,
        inside === undefined
          ? 'find_people.service_area_unavailable'
          : 'find_people.location_outside_market',
      );
    } else issues.add('find_people.exact_location_required');
    issues.require(
      isText(exact.placeName, 1, Number.MAX_SAFE_INTEGER),
      'find_people.meeting_place_name',
    );
    if (
      issues.require(
        isText(exact.addressLine, 1, Number.MAX_SAFE_INTEGER),
        'find_people.exact_address',
      )
    )
      issues.require(!looksResidential(exact.addressLine as string), 'find_people.unsafe_location');
    if (exact.instructions !== undefined && exact.instructions !== null)
      issues.require(isText(exact.instructions, 0, 500), 'find_people.meeting_instructions');
    return;
  }
  hasOnlyKeys(
    value,
    new Set(['mode', 'publicAreaLabel', 'publicLocation']),
    issues,
    'find_people.meeting',
  );
  const location = value.publicLocation;
  if (!isRecord(location)) {
    issues.add('find_people.public_location');
    return;
  }
  hasOnlyKeys(
    location,
    new Set(['latitude', 'longitude', 'precisionMeters', 'policyRevision']),
    issues,
    'find_people.public_location',
  );
  issues.require(
    policy !== undefined &&
      location.precisionMeters === policy.precisionMeters &&
      location.policyRevision === policy.policyRevision &&
      isNumberIn(location.latitude, -90, 90) &&
      isNumberIn(location.longitude, -180, 180) &&
      isPublicCellCentre(location.latitude, location.longitude, policy.precisionMeters),
    'find_people.public_location',
  );
}

function validateGroup(value: unknown, issues: IssueCollector): void {
  if (!isRecord(value)) {
    issues.add('find_people.group');
    return;
  }
  hasOnlyKeys(
    value,
    new Set([
      'targetGroupSize',
      'hostSeatCount',
      'approvalMode',
      'allowPartyApplications',
      'maxSeatsPerApplication',
      'verificationRequirement',
      'waitlistEnabled',
      'waitlistPolicy',
      'waitlistSeatFitPolicy',
      'attendanceConfirmationRequired',
      'guestPolicy',
    ]),
    issues,
    'find_people.group',
  );
  const target = value.targetGroupSize;
  if (!issues.require(isInt(target, 2, 20), 'find_people.group_size')) return;
  const hosts = value.hostSeatCount;
  issues.require(isInt(hosts, 1, (target as number) - 1), 'find_people.host_seats');
  if (value.approvalMode === 'invite_only') issues.add('find_people.visibility_unsupported');
  else issues.require(isEnumValue(value.approvalMode, approvalModes), 'find_people.approval_mode');
  issues.require(typeof value.allowPartyApplications === 'boolean', 'find_people.party');
  const seats = value.maxSeatsPerApplication;
  if (value.allowPartyApplications === true)
    issues.require(
      isInt(seats, 1, 4) &&
        isInt(hosts, 1, (target as number) - 1) &&
        seats <= (target as number) - hosts,
      'find_people.party_seats',
    );
  else issues.require(seats === 1, 'find_people.party_disabled');
  issues.require(
    isEnumValue(value.verificationRequirement, verificationLevels),
    'find_people.verification_requirement',
  );
  issues.require(typeof value.waitlistEnabled === 'boolean', 'find_people.waitlist');
  issues.require(isEnumValue(value.waitlistPolicy, waitlistPolicies), 'find_people.waitlist');
  issues.require(isEnumValue(value.waitlistSeatFitPolicy, seatFitPolicies), 'find_people.waitlist');
  issues.require(
    typeof value.attendanceConfirmationRequired === 'boolean',
    'find_people.attendance_confirmation',
  );
  issues.require(value.guestPolicy === 'authenticated_adults_only', 'find_people.guest_policy');
}

function validateCost(
  value: unknown,
  context: ContentValidationContext,
  issues: IssueCollector,
): void {
  if (!isRecord(value)) {
    issues.add('find_people.cost');
    return;
  }
  hasOnlyKeys(
    value,
    new Set(['costType', 'expectedSpend', 'costNote', 'expenseSplitMode', 'cancellationPolicyId']),
    issues,
    'find_people.cost',
  );
  issues.require(isEnumValue(value.costType, costTypes), 'find_people.cost_type');
  const spend = value.expectedSpend;
  if (value.costType === 'estimated') {
    const valid =
      isRecord(spend) &&
      Object.keys(spend).every((key) => key === 'amountMinor' || key === 'currencyCode') &&
      isInt(spend.amountMinor, 1, Number.MAX_SAFE_INTEGER) &&
      spend.currencyCode === context.market.currencyCode;
    issues.require(valid, 'find_people.estimated_cost');
  } else issues.require(spend === undefined || spend === null, 'find_people.cost_amount_forbidden');
  optionalPublicText(value.costNote, issues, 'find_people.cost_note', 300);
  if (value.expenseSplitMode === 'itemized') issues.add('find_people.expense_items_unsupported');
  else issues.require(isEnumValue(value.expenseSplitMode, splitModes), 'find_people.expense_split');
  issues.require(
    typeof value.cancellationPolicyId === 'string' && configId.test(value.cancellationPolicyId),
    'find_people.cancellation_policy',
  );
}

function validateHosts(
  value: unknown,
  context: ContentValidationContext,
  issues: IssueCollector,
  mode: Mode,
): void {
  if (!isRecord(value)) {
    issues.add('find_people.hosts');
    return;
  }
  hasOnlyKeys(
    value,
    new Set(
      mode === 'source'
        ? [
            'responsibleHostUserIds',
            'conversationPolicy',
            'quietHoursStartMinute',
            'quietHoursEndMinute',
          ]
        : ['responsibleHostUserIds', 'conversationPolicy'],
    ),
    issues,
    'find_people.hosts',
  );
  const hostIds = value.responsibleHostUserIds;
  // T3: the author is the one responsible host; co-hosts are not served.
  issues.require(
    Array.isArray(hostIds) && hostIds.length === 1 && hostIds[0] === context.createdByUserId,
    'find_people.responsible_host',
  );
  issues.require(
    isEnumValue(value.conversationPolicy, conversationPolicies),
    'find_people.conversation_policy',
  );
  if (mode === 'source')
    for (const key of ['quietHoursStartMinute', 'quietHoursEndMinute'] as const)
      if (value[key] !== undefined && value[key] !== null)
        issues.require(isInt(value[key], 0, 1439), 'find_people.quiet_hours');
}

/** The private source rule (draft body at submit and approved publish). */
export function validateFindPeopleBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  return validate(body, context, 'source');
}

/** The public projection rule (immutable published body at activation). */
export function validateFindPeoplePublishedBody(
  body: ContentBody,
  context: ContentValidationContext,
): ContentRuleIssues {
  return validate(body, context, 'published');
}

/** Find People has no media in T3: Media readiness is checked for nothing. */
export function findPeopleMediaIds(): readonly string[] {
  return [];
}

function copyIfPresent(target: Record<string, unknown>, source: Json, keys: readonly string[]) {
  for (const key of keys)
    if (source[key] !== undefined && source[key] !== null)
      target[key] = structuredClone(source[key]);
}

/**
 * §3.2: the public body of a published revision, built field by field from a
 * validated private source. Exact meeting data, confirmations and private host
 * settings are never copied; the public point is the server-computed centre of
 * the ~1 km cell that contains the exact point.
 */
export function findPeoplePublicBody(
  source: ContentBody,
  policy: { readonly precisionMeters: number; readonly policyRevision: string },
): ContentBody {
  const data = source.findPeople as Json;
  const meeting = data.meeting as Json;
  const exact = meeting.exact as Json;
  const group = data.group as Json;
  const cost = data.cost as Json;
  const hosts = data.hosts as Json;
  const schedule = data.schedule as Json;
  const slot = schedule.slot as Json;
  const centre = publicCellCentre(
    exact.latitude as number,
    exact.longitude as number,
    policy.precisionMeters,
  );
  const findPeople: Record<string, unknown> = {
    schemaVersion: 1,
    projection: 'public_v1',
    skillLevel: data.skillLevel,
    languageCodes: structuredClone(data.languageCodes),
    participationGoal: data.participationGoal,
    experienceRequirements: structuredClone(data.experienceRequirements),
    houseRuleIds: structuredClone(data.houseRuleIds),
    visibility: 'public',
    schedule: {
      mode: 'single',
      timezoneId: schedule.timezoneId,
      slot: { id: slot.id, startAtUtc: slot.startAtUtc, endAtUtc: slot.endAtUtc },
      applicationDeadlineUtc: schedule.applicationDeadlineUtc,
    },
    meeting: {
      mode: 'in_person',
      publicAreaLabel: meeting.publicAreaLabel,
      publicLocation: {
        latitude: centre.latitude,
        longitude: centre.longitude,
        precisionMeters: policy.precisionMeters,
        policyRevision: policy.policyRevision,
      },
    },
    group: {
      targetGroupSize: group.targetGroupSize,
      hostSeatCount: group.hostSeatCount,
      approvalMode: group.approvalMode,
      allowPartyApplications: group.allowPartyApplications,
      maxSeatsPerApplication: group.maxSeatsPerApplication,
      verificationRequirement: group.verificationRequirement,
      waitlistEnabled: group.waitlistEnabled,
      waitlistPolicy: group.waitlistPolicy,
      waitlistSeatFitPolicy: group.waitlistSeatFitPolicy,
      attendanceConfirmationRequired: group.attendanceConfirmationRequired,
      guestPolicy: group.guestPolicy,
    },
    cost: (() => {
      const result: Record<string, unknown> = {
        costType: cost.costType,
        expenseSplitMode: cost.expenseSplitMode,
        cancellationPolicyId: cost.cancellationPolicyId,
      };
      if (isRecord(cost.expectedSpend))
        result.expectedSpend = {
          amountMinor: cost.expectedSpend.amountMinor,
          currencyCode: cost.expectedSpend.currencyCode,
        };
      copyIfPresent(result, cost, ['costNote']);
      return result;
    })(),
    hosts: {
      responsibleHostUserIds: structuredClone(hosts.responsibleHostUserIds),
      conversationPolicy: hosts.conversationPolicy,
    },
  };
  copyIfPresent(findPeople, data, [
    'pace',
    'equipmentNotes',
    'accessibilityNotes',
    'houseRulesNote',
  ]);
  const body: Record<string, unknown> = {
    title: source.title,
    shortDescription: source.shortDescription,
    fullDescription: source.fullDescription,
    contentLocale: source.contentLocale,
    categoryId: source.categoryId,
    subcategoryId: source.subcategoryId,
    findPeople,
  };
  copyIfPresent(body, source, ['tags']);
  return body;
}

/** The meeting end of a body (source or public), or null when it cannot be read. */
export function findPeopleMeetingEnd(body: unknown): string | null {
  if (!isRecord(body) || !isRecord(body.findPeople)) return null;
  const schedule = body.findPeople.schedule;
  if (!isRecord(schedule) || !isRecord(schedule.slot)) return null;
  return isInstant(schedule.slot.endAtUtc) ? schedule.slot.endAtUtc : null;
}

/** The single responsible host of a body, or null. */
export function findPeopleHostUserId(body: unknown): string | null {
  if (!isRecord(body) || !isRecord(body.findPeople) || !isRecord(body.findPeople.hosts))
    return null;
  const ids = body.findPeople.hosts.responsibleHostUserIds;
  return Array.isArray(ids) && ids.length === 1 && typeof ids[0] === 'string' ? ids[0] : null;
}

/** Whether a draft body still holds private meeting data (retention, §5.3). */
export function hasFindPeopleExactLocation(body: unknown): boolean {
  return (
    isRecord(body) &&
    isRecord(body.findPeople) &&
    isRecord(body.findPeople.meeting) &&
    body.findPeople.meeting.exact !== undefined
  );
}

/** The body without private meeting data (retention erasure, §5.3). */
export function withoutFindPeopleExactLocation(body: Json): ContentBody {
  const copy = structuredClone(body) as Record<string, unknown>;
  const data = copy.findPeople;
  if (isRecord(data) && isRecord(data.meeting)) {
    const meeting = { ...(data.meeting as Record<string, unknown>) };
    delete meeting.exact;
    (data as Record<string, unknown>).meeting = meeting;
  }
  return copy;
}
