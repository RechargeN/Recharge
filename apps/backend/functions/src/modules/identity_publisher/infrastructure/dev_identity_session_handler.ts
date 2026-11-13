import { inspectIdentitySessionCommand } from '../../../contracts/identity_session_v1.js';
import type { ProviderIdentityProof } from '../application/ports/provider_identity_verifier.js';
import { IdentityFailure } from '../domain/failures.js';
import type { DevIdentitySessionBinding } from './dev_identity_session_binding.js';
import { isReviewedCloudProject } from '../../../shared/cloud_runtime_projects.js';

interface Request {
  readonly method: string;
  readonly callableName: string;
  readonly headers: Readonly<Record<string, string | undefined>>;
  readonly body: Uint8Array;
}
interface Dependencies {
  readonly projectId: string;
  readonly enabled: boolean;
  readonly appCheckMode?: 'observe' | 'enforce';
  readonly sessions: Pick<
    DevIdentitySessionBinding,
    'establish' | 'refresh' | 'recover' | 'revoke' | 'read'
  >;
  readonly admitRequest: () => Promise<boolean>;
  readonly now: () => Date;
}
const commands: Readonly<Record<string, string>> = {
  establishIdentitySessionV1: 'establishIdentitySession',
  refreshIdentitySessionV1: 'refreshIdentitySession',
  recoverIdentitySessionsV1: 'recoverIdentitySessions',
  revokeIdentitySessionV1: 'revokeIdentitySession',
  readIdentitySessionV1: 'readIdentitySession',
};

/** Bounded callable adapter; mandatory ingress admission. Not exported from index/deployed. */
export async function handleDevIdentityRequest(request: Request, deps: Dependencies) {
  const fail = (status: number, code: string) => ({ status, body: { error: { status: code } } });
  if (
    !isReviewedCloudProject(deps.projectId) ||
    !deps.enabled ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined ||
    process.env.FIRESTORE_EMULATOR_HOST !== undefined
  )
    return fail(503, 'UNAVAILABLE');
  if (request.method !== 'POST') return fail(405, 'INVALID_ARGUMENT');
  const commandType = commands[request.callableName];
  if (commandType === undefined) return fail(404, 'NOT_FOUND');
  if (
    !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(request.headers['content-type'] ?? '') ||
    request.body.byteLength > 8192
  )
    return fail(400, 'INVALID_ARGUMENT');
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(request.body));
  } catch {
    return fail(400, 'INVALID_ARGUMENT');
  }
  if (
    typeof body !== 'object' ||
    body === null ||
    Array.isArray(body) ||
    Object.keys(body).length !== 1 ||
    !('data' in body)
  )
    return fail(400, 'INVALID_ARGUMENT');
  const inspected = inspectIdentitySessionCommand(body.data);
  if (!inspected.ok || inspected.value.commandType !== commandType)
    return fail(400, 'INVALID_ARGUMENT');
  const command = inspected.value;
  const provider = request.headers['x-recharge-identity-provider'];
  const authorization = request.headers.authorization;
  const appCheck = request.headers['x-firebase-appcheck'];
  if (
    (provider !== 'google' && provider !== 'apple') ||
    authorization === undefined ||
    !/^Bearer [^\s]{1,8192}$/.test(authorization) ||
    ((appCheck === undefined || appCheck.trim().length === 0) && deps.appCheckMode !== 'observe') ||
    (appCheck !== undefined && appCheck.length > 8192)
  )
    return fail(401, 'UNAUTHENTICATED');
  try {
    if (!(await deps.admitRequest())) return fail(429, 'RESOURCE_EXHAUSTED');
    const credentials = {
      proof: {
        provider,
        providerTenant: deps.projectId,
        proof: authorization.slice(7),
      } satisfies ProviderIdentityProof,
      ...(appCheck === undefined ? {} : { appCheckToken: appCheck }),
      attemptRequestId: command.requestId,
    };
    if (command.commandType === 'revokeIdentitySession') {
      await deps.sessions.revoke(
        { ...credentials, ...command.sessionContext },
        command.allSessions,
      );
      return {
        status: 200,
        body: {
          result: {
            schemaVersion: 1,
            commandType: command.commandType,
            requestId: command.requestId,
            serverTime: deps.now().toISOString(),
            kind: 'succeeded',
            data: { revoked: true },
          },
        },
      };
    }
    const issued =
      command.commandType === 'readIdentitySession'
        ? await deps.sessions.read({ ...credentials, ...command.sessionContext })
        : command.commandType === 'refreshIdentitySession'
          ? await deps.sessions.refresh({ ...credentials, ...command.sessionContext })
          : command.commandType === 'recoverIdentitySessions'
            ? await deps.sessions.recover({
                ...credentials,
                installationId: command.installationId,
              })
            : await deps.sessions.establish({
                ...credentials,
                installationId: command.installationId,
              });
    return {
      status: 200,
      body: {
        result: {
          schemaVersion: 1,
          commandType: command.commandType,
          requestId: command.requestId,
          serverTime: deps.now().toISOString(),
          kind: 'succeeded',
          data: {
            authContext: {
              schemaVersion: 1,
              profile: {
                userId: issued.account.userId,
                accountStatus: issued.account.status,
                systemRoles: issued.account.systemRoles,
              },
              accessSnapshot: issued.accessSnapshot,
            },
            sessionContext: {
              userId: issued.session.userId,
              sessionId: issued.session.sessionId,
              sessionHandle: issued.sessionHandle,
              installationId: issued.session.installationId,
              expiresAtUtc: issued.accessSnapshot.expiresAtUtc,
            },
          },
        },
      },
    };
  } catch (error) {
    const code = error instanceof IdentityFailure ? error.code : 'temporarily_unavailable';
    const retryable = code === 'temporarily_unavailable' || code === 'rate_limited';
    return {
      status: 200,
      body: {
        result: {
          schemaVersion: 1,
          commandType: command.commandType,
          requestId: command.requestId,
          serverTime: deps.now().toISOString(),
          kind: retryable ? 'retryableFailure' : 'rejected',
          error: {
            schemaVersion: 1,
            code,
            retryable,
            correlationId: command.requestId,
            ...(error instanceof IdentityFailure && error.retryAfterSeconds !== undefined
              ? { details: { retryAfter: error.retryAfterSeconds } }
              : {}),
          },
        },
      },
    };
  }
}
