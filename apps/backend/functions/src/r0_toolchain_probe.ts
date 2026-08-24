import { onRequest } from 'firebase-functions/v2/https';

export type R0ProbeResult =
  | Readonly<{
      schemaVersion: 1;
      status: 'emulator_only';
      runtimeMajor: 22;
    }>
  | Readonly<{
      schemaVersion: 1;
      status: 'unavailable';
      code: 'emulator_required';
    }>;

export function buildR0ProbeResult(isEmulator: boolean): R0ProbeResult {
  if (!isEmulator) {
    return Object.freeze({
      schemaVersion: 1,
      status: 'unavailable',
      code: 'emulator_required',
    });
  }

  return Object.freeze({
    schemaVersion: 1,
    status: 'emulator_only',
    runtimeMajor: 22,
  });
}

// R0-only wiring probe. It ignores the request and must never be deployed.
export const r0ToolchainProbe = onRequest(
  {
    cors: false,
    invoker: 'private',
  },
  (_request, response) => {
    const result = buildR0ProbeResult(process.env.FUNCTIONS_EMULATOR === 'true');
    if (result.status === 'unavailable') {
      response.status(503).json(result);
      return;
    }

    response.status(200).json(result);
  },
);
