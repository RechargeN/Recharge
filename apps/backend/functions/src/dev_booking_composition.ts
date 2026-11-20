import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { emergencySwitchState } from './modules/operations/emergency_switch.js';
import { error as logError } from 'firebase-functions/logger';

import { getEventAvailability } from './booking/availability_query.js';
import { getMyBooking, listMyBookings } from './booking/booking_queries.js';
import { cancelInternalBooking } from './booking/cancel_internal_booking.js';
import { createInternalBooking } from './booking/create_internal_booking.js';
import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import { reconfirmInternalBooking } from './booking/reconfirm_internal_booking.js';
import {
  inspectBookingCommand,
  inspectBookingQuery,
  type BookingCommand,
  type BookingQuery,
} from './contracts/booking_v1.js';
import {
  FirestoreAbuseRateLimiter,
  localNetworkRiskHash,
} from './platform/security/firestore_abuse_rate_limiter.js';
import { resolveBookingActor } from './shared/auth_context.js';
import {
  bookingAccessCapability,
  type BookingAccessDecision,
} from './shared/booking_access_authority.js';
import type { ReviewedCloudProject } from './shared/cloud_runtime_projects.js';
import {
  bookingWireErrorCode,
  rejected,
  retryable,
  toBookingCommandWireResult,
  unsupported,
  type BookingResult,
} from './shared/failures.js';
import {
  abuseEmergencySwitchIds,
  bookingFlagIds,
  type BookingFlagId,
} from './shared/feature_flags.js';
import {
  classifyFirestoreFailure,
  type FirestoreFailureLogRecord,
} from './shared/firestore_failure.js';
import { systemServerClock, type ServerClock } from './shared/server_clock.js';

/**
 * N4c step 1 (owner-approved 2026-11-16): the cloud Booking runtime for the
 * reviewed non-production projects. Same use cases, authority, rate limits and
 * wire results as the Emulator entry (`index.ts`); only the composition differs:
 * the Firestore flag store is Emulator-only, so activation is the deploy switch.
 *
 * Not in this runtime: the Event outbox consumer, the delivery retry and the
 * reconfirmation deadline worker. They depend on Event publication and the
 * Operations switches, neither of which runs in the cloud yet, and the Booking
 * notification producer stays on v1 (`suppressedPreActivation`).
 */
export const devBookingCallables = Object.freeze([
  'createInternalBookingV1',
  'cancelInternalBookingV1',
  'reconfirmInternalBookingV1',
  'getMyBookingV1',
  'listMyBookingsV1',
  'getEventAvailabilityV1',
] as const);
export type DevBookingCallable = (typeof devBookingCallables)[number];

export function isDevBookingCallable(value: unknown): value is DevBookingCallable {
  return devBookingCallables.includes(value as DevBookingCallable);
}

const interactiveFlags: ReadonlySet<string> = new Set([
  bookingFlagIds.create,
  bookingFlagIds.cancel,
  bookingFlagIds.reconfirm,
  bookingFlagIds.read,
]);

/**
 * Deploy-switch flags: the four interactive Booking capabilities are on while
 * the runtime is open. The one containment switch is the cost kill switch of
 * `backend-cost-response.md`: it stops NEW Booking creation only. Cancel,
 * reconfirm and reads are never contained, so a user can always release a
 * place. Workers and anything unknown stay off.
 */
export class DeploySwitchBookingFlags {
  constructor(
    private readonly createDisabled: boolean,
    private readonly firestore?: Firestore,
  ) {}

  /**
   * Round 2.1 (owner approval 2026-11-18): the kill switch is also an
   * Operations emergency switch of this environment, so containment takes
   * seconds instead of a redeploy. Either one contains; the switch fails
   * closed (no pointer in the cloud, a read error) like every L2 switch.
   */
  async isEnabled(capabilityId: string, transaction?: Transaction): Promise<boolean> {
    if (capabilityId === abuseEmergencySwitchIds.bookingCreate) {
      if (this.createDisabled) return true;
      if (this.firestore === undefined) return false;
      return (
        (await emergencySwitchState(this.firestore, capabilityId, transaction)) === 'contained'
      );
    }
    return interactiveFlags.has(capabilityId);
  }
}

export interface DevBookingComposition {
  readonly accessAuthority: FirestoreBookingAccessAuthority;
  readonly abuseRateLimiter: FirestoreAbuseRateLimiter;
  readonly featureFlags: DeploySwitchBookingFlags;
}

export function createDevBookingComposition(
  firestore: Firestore,
  createDisabled = false,
): DevBookingComposition {
  return Object.freeze({
    accessAuthority: new FirestoreBookingAccessAuthority(firestore),
    abuseRateLimiter: new FirestoreAbuseRateLimiter(firestore),
    featureFlags: new DeploySwitchBookingFlags(createDisabled, firestore),
  });
}

const failureLogger = Object.freeze({
  error(record: FirestoreFailureLogRecord): void {
    logError(record.eventName, record);
  },
});

export interface DevBookingRequest {
  readonly callable: DevBookingCallable;
  /** Verified transport identity (Firebase uid, or a synthetic load actor in staging). */
  readonly firebaseUid: string;
  readonly rawBody: Buffer;
  readonly data: unknown;
  readonly firestore: Firestore;
  readonly projectId: ReviewedCloudProject;
  readonly composition: DevBookingComposition;
  readonly ip?: string;
  readonly clock?: ServerClock;
}

const commandOf = {
  createInternalBookingV1: 'createBooking',
  cancelInternalBookingV1: 'cancelBooking',
  reconfirmInternalBookingV1: 'reconfirmBooking',
} as const;
const queryOf = {
  getMyBookingV1: 'getMyBooking',
  listMyBookingsV1: 'listMyBookings',
  getEventAvailabilityV1: 'getEventAvailability',
} as const;

export async function handleDevBooking(
  input: DevBookingRequest,
): Promise<Readonly<Record<string, unknown>>> {
  const clock = input.clock ?? systemServerClock;
  if (input.callable in commandOf) {
    const commandType = commandOf[input.callable as keyof typeof commandOf];
    const prepared = await prepareCommand(input, clock, commandType);
    return toBookingCommandWireResult(
      prepared.ok ? await runCommand(input, clock, prepared) : prepared.result,
      prepared.requestId,
      clock.now().toISOString(),
    );
  }
  const queryType = queryOf[input.callable as keyof typeof queryOf];
  const prepared = await prepareQuery(input, clock, queryType);
  return toQueryWireResult(
    queryType,
    prepared.requestId,
    prepared.ok ? await runQuery(input, clock, prepared) : prepared.result,
    clock,
  );
}

type PreparedCommand = Extract<Awaited<ReturnType<typeof prepareCommand>>, { ok: true }>;
type PreparedQuery = Extract<Awaited<ReturnType<typeof prepareQuery>>, { ok: true }>;

type CommandData = Readonly<{ booking: unknown; outcome?: 'reconfirmed' }>;

function runCommand(
  input: DevBookingRequest,
  clock: ServerClock,
  prepared: PreparedCommand,
): Promise<BookingResult<CommandData>> {
  const flagId: BookingFlagId =
    prepared.command.commandType === 'createBooking'
      ? bookingFlagIds.create
      : prepared.command.commandType === 'cancelBooking'
        ? bookingFlagIds.cancel
        : bookingFlagIds.reconfirm;
  const dependencies = {
    firestore: input.firestore,
    clock,
    failureLogger,
    mutationAuthorization: {
      hint: prepared.accessHint,
      expectedUserId: prepared.actorId,
      flagId,
      authority: input.composition.accessAuthority,
      featureFlags: input.composition.featureFlags,
    },
  };
  const command = prepared.command;
  if (command.commandType === 'createBooking')
    return createInternalBooking(dependencies, prepared.actorId, command);
  if (command.commandType === 'cancelBooking')
    return cancelInternalBooking(dependencies, prepared.actorId, command);
  return reconfirmInternalBooking(dependencies, prepared.actorId, command);
}

function runQuery(
  input: DevBookingRequest,
  clock: ServerClock,
  prepared: PreparedQuery,
): Promise<BookingResult<unknown>> {
  const dependencies = { firestore: input.firestore, clock, failureLogger };
  const query = prepared.query;
  if (query.queryType === 'getMyBooking')
    return getMyBooking(dependencies, prepared.actorId, query);
  if (query.queryType === 'listMyBookings')
    return listMyBookings(dependencies, prepared.actorId, query);
  return getEventAvailability(input.firestore, clock, query, failureLogger);
}

function access(input: DevBookingRequest) {
  const data = input.data;
  const sessionContext =
    typeof data === 'object' && data !== null && !Array.isArray(data)
      ? (data as Record<string, unknown>).sessionContext
      : undefined;
  return resolveBookingActor({ uid: input.firebaseUid, token: {} }, sessionContext);
}

async function prepareCommand(
  input: DevBookingRequest,
  clock: ServerClock,
  commandType: BookingCommand['commandType'],
) {
  const hint = transportHint(input.data);
  const actor = access(input);
  if (!actor.ok)
    return { ok: false as const, requestId: hint.requestId, result: rejected(actor.code) };
  let actorId: string;
  try {
    const decision = await input.composition.accessAuthority.authorize(
      actor.actor,
      clock.now(),
      bookingAccessCapability,
    );
    if (!decision.allowed)
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: accessFailure(decision.reason),
      };
    actorId = decision.userId;
    const flagId =
      commandType === 'createBooking'
        ? bookingFlagIds.create
        : commandType === 'cancelBooking'
          ? bookingFlagIds.cancel
          : bookingFlagIds.reconfirm;
    const incidentSwitch =
      commandType === 'createBooking'
        ? abuseEmergencySwitchIds.bookingCreate
        : commandType === 'cancelBooking'
          ? abuseEmergencySwitchIds.bookingCancel
          : abuseEmergencySwitchIds.bookingReconfirm;
    if (
      !(await input.composition.featureFlags.isEnabled(flagId)) ||
      (await input.composition.featureFlags.isEnabled(incidentSwitch))
    )
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    const networkRiskHash = localNetworkRiskHash(input.ip, clock.now());
    const rateDecision = await input.composition.abuseRateLimiter.consume({
      operation:
        commandType === 'createBooking'
          ? 'booking.create'
          : commandType === 'cancelBooking'
            ? 'booking.cancel'
            : 'booking.reconfirm',
      attemptRequestId: hint.requestId,
      accountId: actorId,
      installationId: actor.actor.installationId,
      sessionId: actor.actor.sessionId,
      ...(networkRiskHash === undefined ? {} : { networkRiskHash }),
      environmentId: input.projectId,
      marketId: 'LV',
      now: clock.now(),
      correlationId: hint.requestId,
    });
    if (!rateDecision.allowed)
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('rate_limited', rateDecision.retryAfterSeconds),
      };
  } catch (error) {
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: gateFailure(error, hint.requestId, 'booking_command_feature_flag'),
    };
  }
  const inspected = inspectBookingCommand(input.rawBody, input.data);
  if (!inspected.ok)
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: rawFailure(inspected.reason),
    };
  if (inspected.value.commandType !== commandType)
    return {
      ok: false as const,
      requestId: inspected.value.requestId,
      result: unsupported('unsupported_flow'),
    };
  return {
    ok: true as const,
    accessHint: actor.actor,
    actorId,
    requestId: inspected.value.requestId,
    command: inspected.value,
  };
}

async function prepareQuery(
  input: DevBookingRequest,
  clock: ServerClock,
  queryType: BookingQuery['queryType'],
) {
  const hint = transportHint(input.data);
  const actor = access(input);
  if (!actor.ok)
    return { ok: false as const, requestId: hint.requestId, result: rejected(actor.code) };
  let actorId: string;
  try {
    const decision = await input.composition.accessAuthority.authorize(actor.actor, clock.now());
    if (!decision.allowed)
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: accessFailure(decision.reason),
      };
    actorId = decision.userId;
    if (
      !(await input.composition.featureFlags.isEnabled(bookingFlagIds.read)) ||
      (await input.composition.featureFlags.isEnabled(abuseEmergencySwitchIds.bookingQuery))
    )
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    const networkRiskHash = localNetworkRiskHash(input.ip, clock.now());
    const rateDecision = await input.composition.abuseRateLimiter.consume({
      operation: 'booking.query',
      attemptRequestId: hint.requestId,
      accountId: actorId,
      installationId: actor.actor.installationId,
      sessionId: actor.actor.sessionId,
      ...(networkRiskHash === undefined ? {} : { networkRiskHash }),
      environmentId: input.projectId,
      marketId: 'LV',
      now: clock.now(),
      correlationId: hint.requestId,
    });
    if (!rateDecision.allowed)
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('rate_limited', rateDecision.retryAfterSeconds),
      };
  } catch (error) {
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: gateFailure(error, hint.requestId, 'booking_query_access_authority'),
    };
  }
  const inspected = inspectBookingQuery(input.rawBody, input.data);
  if (!inspected.ok)
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: rawFailure(inspected.reason),
    };
  if (inspected.value.queryType !== queryType)
    return {
      ok: false as const,
      requestId: inspected.value.requestId,
      result: unsupported('unsupported_flow'),
    };
  return {
    ok: true as const,
    actorId,
    requestId: inspected.value.requestId,
    query: inspected.value,
  };
}

function gateFailure(error: unknown, requestId: string, operationName: string) {
  if (error instanceof Error && error.message === 'abuse_policy_unavailable')
    return retryable('temporarily_unavailable', 60);
  return classifyFirestoreFailure(error, {
    correlationId: requestId,
    operationName,
    logger: failureLogger,
  });
}

function rawFailure(reason: string) {
  if (reason === 'unsupported_schema') return unsupported('unsupported_schema');
  if (reason === 'unsupported_flow') return unsupported('unsupported_flow');
  return rejected('invalid_contract');
}

function accessFailure(reason: Extract<BookingAccessDecision, { allowed: false }>['reason']) {
  if (reason === 'snapshot_stale') return retryable('session_refresh_required');
  if (reason === 'session_revoked') return rejected('session_revoked');
  if (reason === 'session_expired') return rejected('session_expired');
  return rejected('permission_denied');
}

function transportHint(value: unknown): Readonly<{ requestId: string }> {
  if (typeof value !== 'object' || value === null || Array.isArray(value))
    return { requestId: 'invalid_request' };
  const requestId = (value as Record<string, unknown>).requestId;
  return {
    requestId:
      typeof requestId === 'string' && /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(requestId)
        ? requestId
        : 'invalid_request',
  };
}

function toQueryWireResult(
  queryType: BookingQuery['queryType'],
  requestId: string,
  result: BookingResult<unknown>,
  clock: ServerClock,
): Readonly<Record<string, unknown>> {
  const base = {
    schemaVersion: 1,
    queryType,
    requestId,
    serverTime: clock.now().toISOString(),
  } as const;
  if (result.kind === 'succeeded') {
    const data = result.data as Record<string, unknown>;
    if (queryType === 'getMyBooking') return { ...base, kind: 'found', booking: data.booking };
    if (queryType === 'listMyBookings') return { ...base, kind: 'succeeded', page: data };
    return { ...base, kind: 'succeeded', availability: data };
  }
  if (
    queryType === 'getMyBooking' &&
    result.kind === 'rejected' &&
    result.code === 'permission_denied'
  )
    return { ...base, kind: 'notFound' };
  if (result.kind === 'unsupportedContract')
    return { ...base, kind: 'unsupportedContract', unsupportedPayload: { reason: result.code } };
  return {
    ...base,
    kind: result.kind,
    error: {
      schemaVersion: 1,
      code: bookingWireErrorCode(result.code),
      retryable: result.kind === 'retryableFailure',
      correlationId: requestId,
      ...(result.kind === 'retryableFailure' && result.retryAfterSeconds !== undefined
        ? { details: { retryAfterSeconds: result.retryAfterSeconds } }
        : {}),
    },
  };
}
