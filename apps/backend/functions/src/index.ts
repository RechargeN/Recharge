import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { error as logError } from 'firebase-functions/logger';
import { onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
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
import { reconfirmInternalBooking } from './booking/reconfirm_internal_booking.js';
import { resolveBookingActor } from './shared/auth_context.js';
import {
  abuseEmergencySwitchIds,
  bookingFlagIds,
  type BookingFlagId,
} from './shared/feature_flags.js';
import { identityFlagIds } from './shared/feature_flags.js';
import { createEmulatorBookingCompositionRoot } from './platform/bootstrap/booking_composition_root.js';
import {
  bookingWireErrorCode,
  rejected,
  retryable,
  toBookingCommandWireResult,
  unsupported,
  type BookingResult,
} from './shared/failures.js';
import { systemServerClock } from './shared/server_clock.js';
import type { FirestoreFailureLogRecord } from './shared/firestore_failure.js';
import { classifyFirestoreFailure } from './shared/firestore_failure.js';
import {
  bookingAccessCapability,
  type BookingAccessDecision,
} from './shared/booking_access_authority.js';
import { inspectIdentitySessionCommand } from './contracts/identity_session_v1.js';
import {
  establishEmulatorIdentitySession,
  recoverEmulatorIdentitySessions,
  rotateEmulatorIdentitySession,
} from './modules/identity_publisher/application/emulator_identity_session_service.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { IdentityFailure } from './modules/identity_publisher/domain/failures.js';
import { decideAppCheck } from './security/app_check_policy.js';
import { localNetworkRiskHash } from './platform/security/firestore_abuse_rate_limiter.js';
import {
  processEventBookingOutboxDocument,
  runPendingEventBookingDeliveries,
} from './booking/event_projection_runtime.js';
import { runReconfirmationDeadlineWorker } from './booking/reconfirmation_deadline_worker.js';

// Preserve R0 while exposing only the explicitly approved, Emulator-only callables.
// R1 platform composition is internal-only and intentionally has no transport export.
export { r0ToolchainProbe } from './r0_toolchain_probe.js';
import {
  handleMediaBytes,
  handleMediaCommand,
  handleMediaDelivery,
  handleMediaQuery,
  type MediaCaller,
  type MediaDeliveryCaller,
} from './media_entry.js';
import { deliverMediaEffects, reconcileMediaReferences } from './media_effects_entry.js';
import {
  authoringTypesFor,
  handleContentCommand,
  handleContentQuery,
  type ContentCaller,
} from './content_entry.js';
import { handleDiscoverQuery, type DiscoverCaller } from './catalog_entry.js';
import { deliverContentEffects } from './content_effects_entry.js';
import {
  consumeBookingNotificationEffect,
  handleNotificationsCommand,
  handleNotificationsQuery,
  notificationFeatures,
  type NotificationsCaller,
} from './notifications_entry.js';
import { catalogFlagIds, contentFlagIds, mediaFlagIds } from './shared/feature_flags.js';

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
    return identitySessionFailure(requestId, 'establishIdentitySession', 'unauthenticated', false);
  }
  const appCheck = localAppCheckDecision(request.app);
  if (!appCheck.allowed) {
    return identitySessionFailure(
      requestId,
      'establishIdentitySession',
      appCheck.code === 'app_check_required' ? 'app_check_required' : 'temporarily_unavailable',
      appCheck.code !== 'app_check_required',
      appCheck.code === 'policy_unavailable' ? 60 : undefined,
    );
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined)
    return identitySessionFailure(requestId, 'establishIdentitySession', 'feature_disabled', false);
  try {
    const flags = new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
    if (!(await flags.isEnabled(identityFlagIds.establishSession))) {
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        'feature_disabled',
        false,
      );
    }
    if (await flags.isEnabled(abuseEmergencySwitchIds.identitySessionIssue)) {
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        'feature_disabled',
        false,
      );
    }
    const inspected = inspectIdentitySessionCommand(request.data);
    if (!inspected.ok) {
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        inspected.reason === 'unsupported_schema' ? 'unsupported_schema' : 'invalid_contract',
        false,
      );
    }
    if (inspected.value.commandType !== 'establishIdentitySession') {
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        'invalid_contract',
        false,
      );
    }
    const session = await establishEmulatorIdentitySession({
      firestore,
      firebaseUid: request.auth.uid,
      installationId: inspected.value.installationId,
      attemptRequestId: inspected.value.requestId,
      ...(localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now()) === undefined
        ? {}
        : {
            networkRiskHash: localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now())!,
          }),
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
      const retryable = error.code === 'temporarily_unavailable' || error.code === 'rate_limited';
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        error.code,
        retryable,
        error.retryAfterSeconds,
      );
    }
    const classified = classifyFirestoreFailure(error, {
      correlationId: requestId,
      operationName: 'establish_identity_session',
      logger: bookingFailureLogger,
    });
    if (classified.kind === 'succeeded') {
      return identitySessionFailure(
        requestId,
        'establishIdentitySession',
        'temporarily_unavailable',
        false,
      );
    }
    return identitySessionFailure(
      requestId,
      'establishIdentitySession',
      classified.code,
      classified.kind === 'retryableFailure',
    );
  }
});

export const refreshIdentitySessionV1 = onCall<unknown>(callableOptions, async (request) => {
  const requestId = bookingTransportHint(request.data).requestId;
  const commandType = 'refreshIdentitySession' as const;
  if (request.auth === undefined || request.auth.uid.length === 0) {
    return identitySessionFailure(requestId, commandType, 'unauthenticated', false);
  }
  const appCheck = localAppCheckDecision(request.app);
  if (!appCheck.allowed) {
    return identitySessionFailure(
      requestId,
      commandType,
      appCheck.code === 'app_check_required' ? 'app_check_required' : 'temporarily_unavailable',
      appCheck.code !== 'app_check_required',
      appCheck.code === 'policy_unavailable' ? 60 : undefined,
    );
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined) {
    return identitySessionFailure(requestId, commandType, 'feature_disabled', false);
  }
  try {
    const flags = new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
    if (!(await flags.isEnabled(identityFlagIds.establishSession))) {
      return identitySessionFailure(requestId, commandType, 'feature_disabled', false);
    }
    const inspected = inspectIdentitySessionCommand(request.data);
    if (!inspected.ok || inspected.value.commandType !== commandType) {
      return identitySessionFailure(
        requestId,
        commandType,
        !inspected.ok && inspected.reason === 'unsupported_schema'
          ? 'unsupported_schema'
          : 'invalid_contract',
        false,
      );
    }
    const session = await rotateEmulatorIdentitySession({
      firestore,
      sessionId: inspected.value.sessionContext.sessionId,
      sessionHandle: inspected.value.sessionContext.sessionHandle,
      firebaseUid: request.auth.uid,
      installationId: inspected.value.sessionContext.installationId,
      attemptRequestId: inspected.value.requestId,
      now: systemServerClock.now(),
    });
    return identitySessionSuccess(commandType, inspected.value.requestId, {
      userId: session.session.userId,
      sessionId: session.session.sessionId,
      sessionHandle: session.sessionHandle,
      installationId: session.session.installationId,
      expiresAtUtc: session.accessSnapshot.expiresAtUtc,
    });
  } catch (error) {
    return mapIdentitySessionError(error, requestId, commandType, 'refresh_identity_session');
  }
});

export const recoverIdentitySessionsV1 = onCall<unknown>(callableOptions, async (request) => {
  const requestId = bookingTransportHint(request.data).requestId;
  const commandType = 'recoverIdentitySessions' as const;
  if (request.auth === undefined || request.auth.uid.length === 0) {
    return identitySessionFailure(requestId, commandType, 'unauthenticated', false);
  }
  if (!hasRecentFirebaseAuthentication(request.auth.token.auth_time, systemServerClock.now())) {
    return identitySessionFailure(requestId, commandType, 'recent_auth_required', false);
  }
  const appCheck = localAppCheckDecision(request.app);
  if (!appCheck.allowed) {
    return identitySessionFailure(
      requestId,
      commandType,
      appCheck.code === 'app_check_required' ? 'app_check_required' : 'temporarily_unavailable',
      appCheck.code !== 'app_check_required',
      appCheck.code === 'policy_unavailable' ? 60 : undefined,
    );
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined) {
    return identitySessionFailure(requestId, commandType, 'feature_disabled', false);
  }
  try {
    const flags = new FirestoreFeatureFlagGate(firestore, 'local', 'LV');
    if (!(await flags.isEnabled(identityFlagIds.establishSession))) {
      return identitySessionFailure(requestId, commandType, 'feature_disabled', false);
    }
    const inspected = inspectIdentitySessionCommand(request.data);
    if (!inspected.ok || inspected.value.commandType !== commandType) {
      return identitySessionFailure(
        requestId,
        commandType,
        !inspected.ok && inspected.reason === 'unsupported_schema'
          ? 'unsupported_schema'
          : 'invalid_contract',
        false,
      );
    }
    const now = systemServerClock.now();
    const networkRiskHash = localNetworkRiskHash(request.rawRequest.ip, now);
    const session = await recoverEmulatorIdentitySessions({
      firestore,
      firebaseUid: request.auth.uid,
      installationId: inspected.value.installationId,
      attemptRequestId: inspected.value.requestId,
      ...(networkRiskHash === undefined ? {} : { networkRiskHash }),
      now,
    });
    return identitySessionSuccess(commandType, inspected.value.requestId, session);
  } catch (error) {
    return mapIdentitySessionError(error, requestId, commandType, 'recover_identity_sessions');
  }
});

export const consumeEventBookingOutboxV1 = onDocumentCreated(
  {
    document: 'eventBookingOutbox/{outboxId}',
    region: 'europe-west1',
    retry: false,
  },
  async (event) => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    await processEventBookingOutboxDocument(
      firestore,
      event.params.outboxId,
      systemServerClock.now().toISOString(),
    );
  },
);

export const retryEventBookingProjectionDeliveriesV1 = onSchedule(
  { schedule: 'every 5 minutes', region: 'europe-west1', retryCount: 0 },
  async () => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    await runPendingEventBookingDeliveries(firestore, systemServerClock.now().toISOString(), 20);
  },
);

export const releaseMissedReconfirmationsV1 = onSchedule(
  { schedule: 'every 5 minutes', region: 'europe-west1', retryCount: 0 },
  async () => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    await runReconfirmationDeadlineWorker(firestore, systemServerClock.now().toISOString(), 20);
  },
);

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

export const reconfirmInternalBookingV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareCommand(request, bookingFlagIds.reconfirm, 'reconfirmBooking');
  const result = !prepared.ok
    ? prepared.result
    : await reconfirmInternalBooking(
        {
          firestore: prepared.firestore,
          clock: systemServerClock,
          failureLogger: bookingFailureLogger,
          mutationAuthorization: {
            hint: prepared.accessHint,
            expectedUserId: prepared.actorId,
            flagId: bookingFlagIds.reconfirm,
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
        result: bookingAccessFailure(decision.reason),
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
    const incidentSwitch =
      commandType === 'createBooking'
        ? abuseEmergencySwitchIds.bookingCreate
        : commandType === 'cancelBooking'
          ? abuseEmergencySwitchIds.bookingCancel
          : abuseEmergencySwitchIds.bookingReconfirm;
    if (await access.composition.featureFlags.isEnabled(incidentSwitch)) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    }
    const rateDecision = await access.composition.abuseRateLimiter.consume({
      operation:
        commandType === 'createBooking'
          ? 'booking.create'
          : commandType === 'cancelBooking'
            ? 'booking.cancel'
            : 'booking.reconfirm',
      attemptRequestId: hint.requestId,
      accountId: actorId,
      installationId: access.accessHint.installationId,
      sessionId: access.accessHint.sessionId,
      ...(localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now()) === undefined
        ? {}
        : {
            networkRiskHash: localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now())!,
          }),
      environmentId: 'local',
      marketId: 'LV',
      now: systemServerClock.now(),
      correlationId: hint.requestId,
    });
    if (!rateDecision.allowed) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('rate_limited', rateDecision.retryAfterSeconds),
      };
    }
  } catch (error) {
    if (error instanceof Error && error.message === 'abuse_policy_unavailable') {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('temporarily_unavailable', 60),
      };
    }
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
        result: bookingAccessFailure(decision.reason),
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
    if (await access.composition.featureFlags.isEnabled(abuseEmergencySwitchIds.bookingQuery)) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: rejected('feature_disabled'),
      };
    }
    const rateDecision = await access.composition.abuseRateLimiter.consume({
      operation: 'booking.query',
      attemptRequestId: hint.requestId,
      accountId: actorId,
      installationId: access.accessHint.installationId,
      sessionId: access.accessHint.sessionId,
      ...(localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now()) === undefined
        ? {}
        : {
            networkRiskHash: localNetworkRiskHash(request.rawRequest.ip, systemServerClock.now())!,
          }),
      environmentId: 'local',
      marketId: 'LV',
      now: systemServerClock.now(),
      correlationId: hint.requestId,
    });
    if (!rateDecision.allowed) {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('rate_limited', rateDecision.retryAfterSeconds),
      };
    }
  } catch (error) {
    if (error instanceof Error && error.message === 'abuse_policy_unavailable') {
      return {
        ok: false as const,
        requestId: hint.requestId,
        result: retryable('temporarily_unavailable', 60),
      };
    }
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
  const appCheck = localAppCheckDecision(request.app);
  if (!appCheck.allowed) {
    return {
      ok: false as const,
      result:
        appCheck.code === 'app_check_required'
          ? rejected('app_check_required')
          : retryable('temporarily_unavailable', 60),
    };
  }
  const firestore = emulatorFirestore();
  if (firestore === undefined) {
    return { ok: false as const, result: rejected('feature_disabled') };
  }
  const composition = createEmulatorBookingCompositionRoot(firestore);
  return { ok: true as const, accessHint: actor.actor, firestore, composition };
}

function localAppCheckDecision(app: unknown) {
  return decideAppCheck({
    environmentId: 'local',
    projectId: process.env.GCLOUD_PROJECT,
    functionsEmulator: process.env.FUNCTIONS_EMULATOR,
    firestoreEmulatorHost: process.env.FIRESTORE_EMULATOR_HOST,
    evidenceState: app === undefined ? 'missing' : 'valid',
  });
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
  const defaultApp =
    getApps().find((app) => app.name === '[DEFAULT]') ??
    initializeApp({ projectId: 'demo-recharge' });
  return getFirestore(defaultApp);
}

function rawFailure(reason: RawBookingFailureReason) {
  if (reason === 'unsupported_schema') return unsupported('unsupported_schema');
  if (reason === 'unsupported_flow') return unsupported('unsupported_flow');
  return rejected('invalid_contract');
}

function bookingAccessFailure(
  reason: Extract<BookingAccessDecision, { allowed: false }>['reason'],
) {
  if (reason === 'snapshot_stale') return retryable('session_refresh_required');
  if (reason === 'session_revoked') return rejected('session_revoked');
  if (reason === 'session_expired') return rejected('session_expired');
  return rejected('permission_denied');
}

function identitySessionFailure(
  requestId: string,
  commandType: 'establishIdentitySession' | 'refreshIdentitySession' | 'recoverIdentitySessions',
  code: string,
  retryable: boolean,
  retryAfterSeconds?: number,
) {
  return {
    schemaVersion: 1,
    commandType,
    requestId,
    serverTime: systemServerClock.now().toISOString(),
    kind: retryable ? 'retryableFailure' : 'rejected',
    error: {
      schemaVersion: 1,
      code,
      retryable,
      correlationId: requestId,
      ...(retryAfterSeconds === undefined ? {} : { details: { retryAfterSeconds } }),
    },
  } as const;
}

function identitySessionSuccess(
  commandType: 'establishIdentitySession' | 'refreshIdentitySession' | 'recoverIdentitySessions',
  requestId: string,
  sessionContext: Readonly<Record<string, unknown>>,
) {
  return {
    schemaVersion: 1,
    commandType,
    requestId,
    serverTime: systemServerClock.now().toISOString(),
    kind: 'succeeded',
    data: { sessionContext },
  } as const;
}

function mapIdentitySessionError(
  error: unknown,
  requestId: string,
  commandType: 'refreshIdentitySession' | 'recoverIdentitySessions',
  operationName: string,
) {
  if (error instanceof IdentityFailure) {
    const retryable = error.code === 'temporarily_unavailable' || error.code === 'rate_limited';
    return identitySessionFailure(
      requestId,
      commandType,
      error.code,
      retryable,
      error.retryAfterSeconds,
    );
  }
  const classified = classifyFirestoreFailure(error, {
    correlationId: requestId,
    operationName,
    logger: bookingFailureLogger,
  });
  return identitySessionFailure(
    requestId,
    commandType,
    classified.kind === 'succeeded' ? 'temporarily_unavailable' : classified.code,
    classified.kind === 'retryableFailure',
  );
}

function hasRecentFirebaseAuthentication(authTime: unknown, now: Date): boolean {
  if (typeof authTime !== 'number' || !Number.isFinite(authTime)) return false;
  const ageSeconds = Math.floor(now.getTime() / 1000) - authTime;
  return ageSeconds >= -60 && ageSeconds <= 5 * 60;
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
        ...(result.kind === 'retryableFailure' && result.retryAfterSeconds !== undefined
          ? { details: { retryAfterSeconds: result.retryAfterSeconds } }
          : {}),
      },
    };
  }
  const data = result.data as Record<string, unknown>;
  if (queryType === 'getMyBooking') return { ...base, kind: 'found', booking: data.booking };
  if (queryType === 'listMyBookings') return { ...base, kind: 'succeeded', page: data };
  return { ...base, kind: 'succeeded', availability: data };
}

// Emulator-only Media entry (C1). Disabled unless the local `media.upload` flag is
// on; the Session is validated by the same backend-time authority as Booking.
export const mediaCommandV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareMediaCaller(request);
  return prepared.ok ? handleMediaCommand(prepared.caller, request.data) : prepared.result;
});

export const mediaQueryV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareMediaCaller(request);
  return prepared.ok ? handleMediaQuery(prepared.caller, request.data) : prepared.result;
});

export const uploadMediaBytesV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareMediaCaller(request);
  return prepared.ok ? handleMediaBytes(prepared.caller, request.data) : prepared.result;
});

async function prepareMediaCaller(
  request: CallableRequest<unknown>,
): Promise<
  | { readonly ok: true; readonly caller: MediaCaller }
  | { readonly ok: false; readonly result: Readonly<Record<string, unknown>> }
> {
  const refuse = (code: string) => ({
    ok: false as const,
    result: { schemaVersion: 1, kind: 'rejected', code },
  });
  const access = prepareTransport(request);
  if (!access.ok) return refuse('unauthenticated');
  const now = systemServerClock.now();
  const decision = await access.composition.accessAuthority.authorize(
    access.accessHint,
    now,
    bookingAccessCapability,
  );
  if (!decision.allowed) return refuse('unauthenticated');
  if (!(await access.composition.featureFlags.isEnabled(mediaFlagIds.upload))) {
    return refuse('family_unavailable');
  }
  return {
    ok: true,
    caller: {
      actor: { userId: decision.userId as never, sessionId: access.accessHint.sessionId as never },
      firestore: access.firestore,
    },
  };
}

// Emulator-only D2 delivery gate (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md §4).
// Disabled unless the local `media.delivery` flag is on; the Session is validated
// by the same backend-time authority as Booking. Every request is decided again
// from the publication and Media's own record; no URL or handle is ever issued.
export const mediaDeliveryV1 = onCall<unknown>(callableOptions, async (request) => {
  const refuse = (code: string) => ({ schemaVersion: 1, kind: 'rejected', code });
  const access = prepareTransport(request);
  if (!access.ok) return refuse('unauthenticated');
  const decision = await access.composition.accessAuthority.authorize(
    access.accessHint,
    systemServerClock.now(),
    bookingAccessCapability,
  );
  if (!decision.allowed) return refuse('unauthenticated');
  if (!(await access.composition.featureFlags.isEnabled(mediaFlagIds.delivery)))
    return refuse('capability_denied');
  const caller: MediaDeliveryCaller = { firestore: access.firestore };
  return handleMediaDelivery(caller, request.data);
});

// Emulator-only D2 reaction: every committed Media fact lets Content check the
// publications that attach the asset. Disabled unless `content.mediaAvailability`
// is on; a stopped run is resumed by the next fact or the scheduled sweep.
export const consumeMediaEffectV1 = onDocumentCreated(
  {
    document: 'mediaEffects/{effectId}',
    region: 'europe-west1',
    retry: false,
  },
  async () => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    const outcome = await deliverMediaEffects(firestore, {
      flags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
    });
    if (outcome.status === 'failed' || outcome.status === 'stopped')
      logError('media_effect_consumer_incomplete', outcome);
  },
);

// Emulator-only D2 sweeps: R1 (Content ↔ Media, `content.mediaAvailability`) and
// R2 (Media orphans, `media.reconcile`). No retention policy is configured here,
// so R2 deletes nothing (`policy_unavailable`).
export const reconcileMediaReferencesV1 = onSchedule(
  { schedule: 'every 15 minutes', region: 'europe-west1', retryCount: 0 },
  async () => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    await reconcileMediaReferences(firestore, {
      flags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
    });
  },
);

// Emulator-only authoring through Content: Event (C3) and Place (D3.1). The
// surface is open while at least one local authoring flag (`content.event.authoring`,
// `content.place.authoring`) is on; each type's own flag gates the commands that
// create or change publishable content (D3.1 §2.2), while the owner's hide and
// reads stay available. Owner commands and queries only: the Content service
// re-checks Session, verified Creator, exact Page, Media readiness and the C2
// review on every call; dispositions are never accepted here.
export const contentCommandV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareContentCaller(request);
  return prepared.ok ? handleContentCommand(prepared.caller, request.data) : prepared.result;
});

export const contentQueryV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareContentCaller(request);
  return prepared.ok ? handleContentQuery(prepared.caller, request.data) : prepared.result;
});

async function prepareContentCaller(
  request: CallableRequest<unknown>,
): Promise<
  | { readonly ok: true; readonly caller: ContentCaller }
  | { readonly ok: false; readonly result: Readonly<Record<string, unknown>> }
> {
  const refuse = (code: string) => ({
    ok: false as const,
    result: { schemaVersion: 1, kind: 'rejected', code },
  });
  const access = prepareTransport(request);
  if (!access.ok) return refuse('unauthenticated');
  const now = systemServerClock.now();
  const decision = await access.composition.accessAuthority.authorize(
    access.accessHint,
    now,
    bookingAccessCapability,
  );
  if (!decision.allowed) return refuse('unauthenticated');
  const enabledTypes = authoringTypesFor({
    eventAuthoring: await access.composition.featureFlags.isEnabled(contentFlagIds.eventAuthoring),
    placeAuthoring: await access.composition.featureFlags.isEnabled(contentFlagIds.placeAuthoring),
  });
  if (enabledTypes.size === 0) return refuse('type_disabled');
  return {
    ok: true,
    caller: {
      actor: { userId: decision.userId as never, sessionId: access.accessHint.sessionId as never },
      firestore: access.firestore,
      enabledTypes,
    },
  };
}

// Emulator-only Discover read over the local Catalog (E2). Disabled unless the
// local `catalog.discover.read` flag is on; the Session is validated by the same
// backend-time authority as Booking. Read-only: it never projects or delivers.
export const discoverQueryV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareDiscoverCaller(request);
  return prepared.ok ? handleDiscoverQuery(prepared.caller, request.data) : prepared.result;
});

async function prepareDiscoverCaller(
  request: CallableRequest<unknown>,
): Promise<
  | { readonly ok: true; readonly caller: DiscoverCaller }
  | { readonly ok: false; readonly result: Readonly<Record<string, unknown>> }
> {
  const refuse = (code: string) => ({
    ok: false as const,
    result: { schemaVersion: 1, kind: 'rejected', code },
  });
  const access = prepareTransport(request);
  if (!access.ok) return refuse('unauthenticated');
  const decision = await access.composition.accessAuthority.authorize(
    access.accessHint,
    systemServerClock.now(),
    bookingAccessCapability,
  );
  if (!decision.allowed) return refuse('unauthenticated');
  if (!(await access.composition.featureFlags.isEnabled(catalogFlagIds.discoverRead))) {
    return refuse('feature_disabled');
  }
  return { ok: true, caller: { firestore: access.firestore } };
}

// Emulator-only delivery of committed Content effects (E2). Every enabled
// consumer (Catalog; Booking handoff from E2.0) runs from its own checkpoint, so
// one failing never marks or blocks another. No retry: a failed consumer is
// resumed by the next effect or by the stand command.
export const consumeContentEffectV1 = onDocumentCreated(
  {
    document: 'contentEffects/{effectId}',
    region: 'europe-west1',
    retry: false,
  },
  async () => {
    const firestore = emulatorFirestore();
    if (firestore === undefined) return;
    const outcomes = await deliverContentEffects(firestore, {
      flags: new FirestoreFeatureFlagGate(firestore, 'local', 'LV'),
    });
    for (const outcome of outcomes)
      if (outcome.status === 'failed' || outcome.status === 'stopped')
        logError('content_effect_consumer_incomplete', outcome);
  },
);

// Emulator-only Notifications inbox (F1). Both callables need a valid Session
// (same backend-time authority as Booking) and their own local flag; the
// caller is the Session subject, never a client-supplied user id.
export const notificationsQueryV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareNotificationsCaller(request);
  return prepared.ok ? handleNotificationsQuery(prepared.caller, request.data) : prepared.result;
});

export const notificationsCommandV1 = onCall<unknown>(callableOptions, async (request) => {
  const prepared = await prepareNotificationsCaller(request);
  return prepared.ok ? handleNotificationsCommand(prepared.caller, request.data) : prepared.result;
});

async function prepareNotificationsCaller(
  request: CallableRequest<unknown>,
): Promise<
  | { readonly ok: true; readonly caller: NotificationsCaller }
  | { readonly ok: false; readonly result: Readonly<Record<string, unknown>> }
> {
  const refuse = (code: string) => ({
    ok: false as const,
    result: { schemaVersion: 1, kind: 'rejected', code },
  });
  const access = prepareTransport(request);
  if (!access.ok) return refuse('unauthenticated');
  const decision = await access.composition.accessAuthority.authorize(
    access.accessHint,
    systemServerClock.now(),
    bookingAccessCapability,
  );
  if (!decision.allowed) return refuse('unauthenticated');
  const features = await notificationFeatures(access.firestore);
  if (!features.inbox && !features.preferences) return refuse('feature_disabled');
  return {
    ok: true,
    caller: { firestore: access.firestore, userId: decision.userId, features },
  };
}

// Emulator-only consumer of Booking notification obligations (F1). A trusted
// backend context without a Session: the source path, producer, schema and
// local consumer flag are checked. No retry: a failed or disabled consumer
// leaves the obligation for the stand reconciliation, never for Booking.
export const consumeNotificationEffectV1 = onDocumentCreated(
  {
    document: 'bookingOutbox/{outboxId}',
    region: 'europe-west1',
    retry: false,
  },
  async (event) => {
    const firestore = emulatorFirestore();
    if (firestore === undefined || event.data === undefined) return;
    try {
      const outcome = await consumeBookingNotificationEffect(firestore, {
        collection: event.data.ref.parent.id,
        outboxId: event.params.outboxId,
        data: event.data.data(),
      });
      if (outcome === 'source_refused' || outcome === 'failed_unrecorded')
        logError('notification_effect_unconsumed', { outcome });
    } catch (error) {
      logError('notification_effect_unconsumed', {
        outcome: 'claim_failed',
        code: (error as { code?: unknown } | null)?.code ?? 'unexpected',
      });
    }
  },
);
