import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { error as logError } from 'firebase-functions/logger';
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
import { bookingFlagIds, type BookingFlagId } from './shared/feature_flags.js';
import { identityFlagIds } from './shared/feature_flags.js';
import { createEmulatorBookingCompositionRoot } from './platform/bootstrap/booking_composition_root.js';
import {
  bookingWireErrorCode,
  rejected,
  toBookingCommandWireResult,
  unsupported,
  type BookingResult,
} from './shared/failures.js';
import { systemServerClock } from './shared/server_clock.js';
import type { FirestoreFailureLogRecord } from './shared/firestore_failure.js';
import { classifyFirestoreFailure } from './shared/firestore_failure.js';
import { bookingAccessCapability } from './shared/booking_access_authority.js';
import { inspectIdentitySessionCommand } from './contracts/identity_session_v1.js';
import { establishEmulatorIdentitySession } from './modules/identity_publisher/application/emulator_identity_session_service.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { IdentityFailure } from './modules/identity_publisher/domain/failures.js';

// Preserve R0 while exposing only the explicitly approved, Emulator-only callables.
// R1 platform composition is internal-only and intentionally has no transport export.
export { r0ToolchainProbe } from './r0_toolchain_probe.js';

const callableOptions = Object.freeze({
  region: 'europe-west1',
  timeoutSeconds: 30,
  enforceAppCheck: false,
  cors: false,
});

const bookingFailureLogger = Object.freeze({
  error(record: FirestoreFailureLogRecord): void {
    logError(record.eventName, record);
  },
});

export const establishIdentitySessionV1 = onCall<unknown>(callableOptions, async (request) => {
  const requestId = bookingTransportHint(request.data).requestId;
  if (request.auth === undefined || request.auth.uid.length === 0) {
    return identitySessionFailure(requestId, 'unauthenticated', false);
  }
  if (!isEmulatorAppCheckAllowed(request.app)) {
    return identitySessionFailure(requestId, 'feature_disabled', false);
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined) return identitySessionFailure(requestId, 'feature_disabled', false);
  try {
    const flags = new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
    if (!(await flags.isEnabled(identityFlagIds.establishSession))) {
      return identitySessionFailure(requestId, 'feature_disabled', false);
    }
    const inspected = inspectIdentitySessionCommand(request.data);
    if (!inspected.ok) {
      return identitySessionFailure(
        requestId,
        inspected.reason === 'unsupported_schema' ? 'unsupported_schema' : 'invalid_contract',
        false,
      );
    }
    const session = await establishEmulatorIdentitySession({
      firestore,
      firebaseUid: request.auth.uid,
      installationId: inspected.value.installationId,
      now: systemServerClock.now(),
    });
    return {
      schemaVersion: 1,
      commandType: 'establishIdentitySession',
      requestId: inspected.value.requestId,
      serverTime: systemServerClock.now().toISOString(),
      kind: 'succeeded',
      data: { sessionContext: session },
    };
  } catch (error) {
    if (error instanceof IdentityFailure) {
      const retryable = error.code === 'temporarily_unavailable';
      return identitySessionFailure(requestId, error.code, retryable);
    }
    const classified = classifyFirestoreFailure(error, {
      correlationId: requestId,
      operationName: 'establish_identity_session',
      logger: bookingFailureLogger,
    });
    if (classified.kind === 'succeeded') {
      return identitySessionFailure(requestId, 'temporarily_unavailable', false);
    }
    return identitySessionFailure(
      requestId,
      classified.code,
      classified.kind === 'retryableFailure',
    );
  }
});

export const createInternalBookingV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareCommand(request, bookingFlagIds.create, 'createBooking');
  const result = !prepared.ok
    ? prepared.result
    : await createInternalBooking(
        {
          firestore: prepared.firestore,
          clock: systemServerClock,
          failureLogger: bookingFailureLogger,
          mutationAuthorization: {
            hint: prepared.accessHint,
            expectedUserId: prepared.actorId,
            flagId: bookingFlagIds.create,
            authority: prepared.composition.accessAuthority,
            featureFlags: prepared.composition.featureFlags,
          },
        },
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
        {
          firestore: prepared.firestore,
          clock: systemServerClock,
          failureLogger: bookingFailureLogger,
          mutationAuthorization: {
            hint: prepared.accessHint,
            expectedUserId: prepared.actorId,
            flagId: bookingFlagIds.cancel,
            authority: prepared.composition.accessAuthority,
            featureFlags: prepared.composition.featureFlags,
          },
        },
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
    : await getMyBooking(
        {
          firestore: prepared.firestore,
          clock: systemServerClock,
          failureLogger: bookingFailureLogger,
        },
        prepared.actorId,
        prepared.query,
      );
  return toBookingQueryWireResult('getMyBooking', prepared.requestId, result);
});

export const listMyBookingsV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareQuery(request, bookingFlagIds.read, 'listMyBookings');
  const result = !prepared.ok
    ? prepared.result
    : await listMyBookings(
        {
          firestore: prepared.firestore,
          clock: systemServerClock,
          failureLogger: bookingFailureLogger,
        },
        prepared.actorId,
        prepared.query,
      );
  return toBookingQueryWireResult('listMyBookings', prepared.requestId, result);
});

export const getEventAvailabilityV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareQuery(request, bookingFlagIds.read, 'getEventAvailability');
  const result = !prepared.ok
    ? prepared.result
    : await getEventAvailability(
        prepared.firestore,
        systemServerClock,
        prepared.query,
        bookingFailureLogger,
      );
  return toBookingQueryWireResult('getEventAvailability', prepared.requestId, result);
});

async function prepareCommand<T extends BookingCommand['commandType']>(
  request: CallableRequest<unknown>,
  flagId: BookingFlagId,
  commandType: T,
) {
  const hint = bookingTransportHint(request.data);
  const access = prepareTransport(request);
  if (!access.ok) return { ...access, requestId: hint.requestId };
  let actorId: string;
  try {
    const decision = await access.composition.accessAuthority.authorize(
      access.accessHint,
      systemServerClock.now(),
      bookingAccessCapability,
    );
    if (!decision.allowed) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('permission_denied'),
      };
    }
    actorId = decision.userId;
    if (!(await access.composition.featureFlags.isEnabled(flagId))) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    }
  } catch (error) {
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: classifyFirestoreFailure(error, {
        correlationId: hint.requestId,
        operationName: 'booking_command_feature_flag',
        logger: bookingFailureLogger,
      }),
    };
  }
  const inspected = inspectBookingCommand(request.rawRequest.rawBody, request.data);
  if (!inspected.ok) {
    return {
      ok: false as const,
      requestId: hint.requestId,
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
  return {
    ok: true as const,
    accessHint: access.accessHint,
    actorId,
    composition: access.composition,
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
  const hint = bookingTransportHint(request.data);
  const access = prepareTransport(request);
  if (!access.ok) return { ...access, requestId: hint.requestId };
  const inspected = inspectBookingQuery(request.rawRequest.rawBody, request.data);
  if (!inspected.ok) {
    return {
      ok: false as const,
      requestId: hint.requestId,
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
  let actorId: string;
  try {
    const decision = await access.composition.accessAuthority.authorize(
      access.accessHint,
      systemServerClock.now(),
    );
    if (!decision.allowed) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('permission_denied'),
      };
    }
    actorId = decision.userId;
    if (!(await access.composition.featureFlags.isEnabled(flagId))) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    }
  } catch (error) {
    return {
      ok: false as const,
      requestId: hint.requestId,
      result: classifyFirestoreFailure(error, {
        correlationId: hint.requestId,
        operationName: 'booking_query_access_authority',
        logger: bookingFailureLogger,
      }),
    };
  }
  return {
    ok: true as const,
    actorId,
    firestore: access.firestore,
    requestId: inspected.value.requestId,
    query: inspected.value as Extract<BookingQuery, { queryType: T }>,
  };
}

function prepareTransport(request: CallableRequest<unknown>) {
  const actor = resolveBookingActor(request.auth, sessionContextFrom(request.data));
  if (!actor.ok) return { ok: false as const, result: rejected(actor.code) };
  if (!isEmulatorAppCheckAllowed(request.app)) {
    return { ok: false as const, result: rejected('feature_disabled') };
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined) {
    return { ok: false as const, result: rejected('feature_disabled') };
  }
  const composition = createEmulatorBookingCompositionRoot(firestore);
  return { ok: true as const, accessHint: actor.actor, firestore, composition };
}

function sessionContextFrom(value: unknown): unknown {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>).sessionContext
    : undefined;
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
  if (reason === 'unsupported_schema') return unsupported('unsupported_schema');
  if (reason === 'unsupported_flow') return unsupported('unsupported_flow');
  return rejected('invalid_contract');
}

function identitySessionFailure(requestId: string, code: string, retryable: boolean) {
  return {
    schemaVersion: 1,
    commandType: 'establishIdentitySession',
    requestId,
    serverTime: systemServerClock.now().toISOString(),
    kind: retryable ? 'retryableFailure' : 'rejected',
    error: {
      schemaVersion: 1,
      code,
      retryable,
      correlationId: requestId,
    },
  } as const;
}

function bookingTransportHint(value: unknown): Readonly<{
  requestId: string;
  schemaVersion?: number;
}> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return { requestId: 'invalid_request' };
  }
  const record = value as Record<string, unknown>;
  const requestId =
    typeof record.requestId === 'string' &&
    /^(?!__name__$)[A-Za-z0-9_-]{1,128}$/u.test(record.requestId)
      ? record.requestId
      : 'invalid_request';
  return Number.isSafeInteger(record.schemaVersion)
    ? { requestId, schemaVersion: Number(record.schemaVersion) }
    : { requestId };
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
    if (result.kind === 'unsupportedContract') {
      return { ...base, kind: 'unsupportedContract', unsupportedPayload: { reason: result.code } };
    }
    return {
      ...base,
      kind: result.kind,
      error: {
        schemaVersion: 1,
        code: bookingWireErrorCode(result.code),
        retryable: result.kind === 'retryableFailure',
        correlationId: requestId,
      },
    };
  }
  const data = result.data as Record<string, unknown>;
  if (queryType === 'getMyBooking') return { ...base, kind: 'found', booking: data.booking };
  if (queryType === 'listMyBookings') return { ...base, kind: 'succeeded', page: data };
  return { ...base, kind: 'succeeded', availability: data };
}
