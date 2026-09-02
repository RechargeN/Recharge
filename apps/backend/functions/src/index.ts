import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall, type CallableRequest } from 'firebase-functions/v2/https';
import {
  inspectBookingCommand,
  inspectBookingQuery,
  type BookingCommand,
  type BookingQuery,
  type RawBookingFailureReason,
} from './contracts/booking_v1.js';
import { getEventAvailability } from './booking/availability_query.js';
import { getMyBooking, listMyBookings } from './booking/booking_queries.js';
import { cancelInternalBooking } from './booking/cancel_internal_booking.js';
import { createInternalBooking } from './booking/create_internal_booking.js';
import { isEmulatorAppCheckAllowed, resolveBookingActor } from './shared/auth_context.js';
import {
  bookingFlagIds,
  isBookingFlagEnabled,
  type BookingFlagId,
} from './shared/feature_flags.js';
import {
  rejected,
  toBookingCommandWireResult,
  unsupported,
  type BookingResult,
} from './shared/failures.js';
import { systemServerClock } from './shared/server_clock.js';

// Preserve the non-product R0 probe while RAW-C adds exactly five Booking exports.
export { r0ToolchainProbe } from './r0_toolchain_probe.js';

const callableOptions = Object.freeze({
  region: 'europe-west1',
  timeoutSeconds: 30,
  enforceAppCheck: false,
  cors: false,
});

export const createInternalBookingV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareCommand(request, bookingFlagIds.create, 'createBooking');
  const result = !prepared.ok
    ? prepared.result
    : await createInternalBooking(
        { firestore: prepared.firestore, clock: systemServerClock },
        prepared.actorId,
        prepared.command,
      );
  return toBookingCommandWireResult(
    result,
    prepared.requestId,
    systemServerClock.now().toISOString(),
  );
});

export const cancelInternalBookingV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareCommand(request, bookingFlagIds.cancel, 'cancelBooking');
  const result = !prepared.ok
    ? prepared.result
    : await cancelInternalBooking(
        { firestore: prepared.firestore, clock: systemServerClock },
        prepared.actorId,
        prepared.command,
      );
  return toBookingCommandWireResult(
    result,
    prepared.requestId,
    systemServerClock.now().toISOString(),
  );
});

export const getMyBookingV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareQuery(request, bookingFlagIds.read, 'getMyBooking');
  const result = !prepared.ok
    ? prepared.result
    : await getMyBooking(prepared.firestore, prepared.actorId, prepared.query);
  return toBookingQueryWireResult('getMyBooking', prepared.requestId, result);
});

export const listMyBookingsV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareQuery(request, bookingFlagIds.read, 'listMyBookings');
  const result = !prepared.ok
    ? prepared.result
    : await listMyBookings(prepared.firestore, prepared.actorId, prepared.query);
  return toBookingQueryWireResult('listMyBookings', prepared.requestId, result);
});

export const getEventAvailabilityV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareQuery(request, bookingFlagIds.read, 'getEventAvailability');
  const result = !prepared.ok
    ? prepared.result
    : await getEventAvailability(prepared.firestore, systemServerClock, prepared.query);
  return toBookingQueryWireResult('getEventAvailability', prepared.requestId, result);
});

async function prepareCommand<T extends BookingCommand['commandType']>(
  request: CallableRequest<unknown>,
  flagId: BookingFlagId,
  commandType: T,
) {
  const inspected = inspectBookingCommand(request.rawRequest.rawBody, request.data);
  if (!inspected.ok) {
    return {
      ok: false as const,
      requestId: 'invalid_request',
      result: rawFailure(inspected.reason),
    };
  }
  if (inspected.value.commandType !== commandType) {
    return {
      ok: false as const,
      requestId: inspected.value.requestId,
      result: unsupported('unsupported_flow'),
    };
  }
  const access = await prepareAccess(request, flagId);
  if (!access.ok) return { ...access, requestId: inspected.value.requestId };
  return {
    ok: true as const,
    actorId: access.actorId,
    firestore: access.firestore,
    requestId: inspected.value.requestId,
    command: inspected.value as Extract<BookingCommand, { commandType: T }>,
  };
}

async function prepareQuery<T extends BookingQuery['queryType']>(
  request: CallableRequest<unknown>,
  flagId: BookingFlagId,
  queryType: T,
) {
  const inspected = inspectBookingQuery(request.rawRequest.rawBody, request.data);
  if (!inspected.ok) {
    return {
      ok: false as const,
      requestId: 'invalid_request',
      result: rawFailure(inspected.reason),
    };
  }
  if (inspected.value.queryType !== queryType) {
    return {
      ok: false as const,
      requestId: inspected.value.requestId,
      result: unsupported('unsupported_flow'),
    };
  }
  const access = await prepareAccess(request, flagId);
  if (!access.ok) return { ...access, requestId: inspected.value.requestId };
  return {
    ok: true as const,
    actorId: access.actorId,
    firestore: access.firestore,
    requestId: inspected.value.requestId,
    query: inspected.value as Extract<BookingQuery, { queryType: T }>,
  };
}

async function prepareAccess(request: CallableRequest<unknown>, flagId: BookingFlagId) {
  const actor = resolveBookingActor(request.auth);
  if (!actor.ok) return { ok: false as const, result: rejected(actor.code) };
  if (!isEmulatorAppCheckAllowed(request.app)) {
    return { ok: false as const, result: rejected('feature_disabled') };
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined || !(await isBookingFlagEnabled(firestore, undefined, flagId))) {
    return { ok: false as const, result: rejected('feature_disabled') };
  }
  return { ok: true as const, actorId: actor.actor.actorId, firestore };
}

function emulatorFirestore() {
  if (
    process.env.FUNCTIONS_EMULATOR !== 'true' ||
    process.env.GCLOUD_PROJECT !== 'demo-recharge' ||
    process.env.FIRESTORE_EMULATOR_HOST === undefined
  ) {
    return undefined;
  }
  if (getApps().length === 0) initializeApp({ projectId: 'demo-recharge' });
  return getFirestore();
}

function rawFailure(reason: RawBookingFailureReason) {
  if (reason === 'unsupported_flow') return unsupported('unsupported_flow');
  return rejected('invalid_contract');
}

function toBookingQueryWireResult(
  queryType: BookingQuery['queryType'],
  requestId: string,
  result: BookingResult<unknown>,
): Readonly<Record<string, unknown>> {
  const base = {
    schemaVersion: 1,
    queryType,
    requestId,
    serverTime: systemServerClock.now().toISOString(),
  } as const;
  if (result.kind !== 'succeeded') {
    if (
      queryType === 'getMyBooking' &&
      result.kind === 'rejected' &&
      result.code === 'permission_denied'
    ) {
      return { ...base, kind: 'notFound' };
    }
    const reason = 'code' in result ? result.code : 'temporarily_unavailable';
    return { ...base, kind: 'unsupportedContract', unsupportedPayload: { reason } };
  }
  const data = result.data as Record<string, unknown>;
  if (queryType === 'getMyBooking') return { ...base, kind: 'found', booking: data.booking };
  if (queryType === 'listMyBookings') return { ...base, kind: 'succeeded', page: data };
  return { ...base, kind: 'succeeded', availability: data };
}
