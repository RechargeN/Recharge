import { createHash } from 'node:crypto';

import { onCall } from 'firebase-functions/v2/https';

import { inspectBookingCallableRawBody } from '../support/booking_callable_raw_body.js';
import { createBookingSchemaRegistry } from '../support/booking_schema_registry.js';
import { computeBookingSemanticHash } from '../support/booking_semantic_hash.js';

type ProbeResult =
  | Readonly<{
      kind: 'accepted';
      rawByteLength: number;
      rawSha256: string;
      semanticHash: string;
    }>
  | Readonly<{
      kind: 'rejected';
      reason: string;
      rawByteLength: number;
      rawSha256: string;
    }>;

const registryPromise = createBookingSchemaRegistry();

// Test-fixture export. The disposable runner copies it into an isolated source;
// product src/index.ts never imports or exports this callable.
export const bookingRawBodyProbeV1 = onCall(
  {
    region: 'europe-west1',
    cors: false,
    timeoutSeconds: 30,
  },
  async (request): Promise<ProbeResult> => {
    const rawBody = request.rawRequest.rawBody;
    const rawByteLength = rawBody.byteLength;
    const rawSha256 = createHash('sha256').update(rawBody).digest('hex');
    const registry = await registryPromise;
    const validateCommand = registry.validator('booking_command.schema.json');
    const inspection = inspectBookingCallableRawBody(rawBody, request.data, validateCommand);

    if (!inspection.ok) {
      return {
        kind: 'rejected',
        reason: inspection.reason,
        rawByteLength,
        rawSha256,
      };
    }

    const semanticHash = computeBookingSemanticHash(
      JSON.stringify(inspection.command),
      { kind: 'user', id: 'raw-body-probe-user' },
      validateCommand,
    ).digest;
    return {
      kind: 'accepted',
      rawByteLength,
      rawSha256,
      semanticHash,
    };
  },
);
