import type { App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { createDevFirebaseAppCheckPort } from '../../../platform/adapters/dev_firebase_app_check.js';
import { FirestoreIdentityAuthorityRepository } from './firestore_identity_authority_repository.js';
import { createDevFirebaseProviderIdentityVerifier } from './dev_firebase_provider_identity_verifier.js';
import { createHash, randomUUID } from 'node:crypto';
import type { IdentityAuthorityRepository } from '../domain/repositories.js';
import type { ProviderIdentityProof } from '../application/ports/provider_identity_verifier.js';
import { AccountLinkingService } from '../application/account_linking_service.js';
import { SessionAuthorityService } from '../application/session_authority_service.js';
import { IdentityFailure } from '../domain/failures.js';
import type { AppCheckPort } from '../../../security/app_check_port.js';
import {
  FirestoreAbuseRateLimiter,
  type AbuseRateRequest,
} from '../../../platform/security/firestore_abuse_rate_limiter.js';
import type { DevFirebaseProviderIdentityVerifier } from './dev_firebase_provider_identity_verifier.js';

interface Credentials {
  readonly proof: ProviderIdentityProof;
  readonly appCheckToken?: string;
  readonly installationId: string;
  readonly attemptRequestId: string;
}
interface SessionCredentials extends Credentials {
  readonly sessionId: string;
  readonly sessionHandle: string;
}

/** Disconnected dev binding of existing authorities; not an exported endpoint/runtime. */
export class DevIdentitySessionBinding {
  private readonly sessions: SessionAuthorityService;
  constructor(
    projectId: string,
    private readonly repository: IdentityAuthorityRepository,
    private readonly verifier: Pick<DevFirebaseProviderIdentityVerifier, 'verifyIdentity'>,
    private readonly appCheck: AppCheckPort,
    private readonly limiter: Pick<FirestoreAbuseRateLimiter, 'consume'>,
    private readonly now: () => Date = () => new Date(),
    private readonly appCheckMode: 'observe' | 'enforce' = 'enforce',
    private readonly observeAppCheck: (
      state: 'missing' | 'invalid' | 'expired' | 'valid',
    ) => void = () => {},
  ) {
    if (projectId !== 'recharge-dev-n2a01') throw new TypeError('dev_session_binding_invalid');
    this.sessions = new SessionAuthorityService(repository);
  }

  async establish(input: Credentials) {
    const context = await this.authenticate(input);
    await this.bootstrapLimit(input, context);
    const account = await this.account(input, context, true);
    await this.limit(input, context.now, 'identity.session.issue', { accountId: account.userId });
    return this.sessions.issue({
      userId: account.userId,
      sessionId: randomUUID(),
      firebaseUid: context.identity.firebaseUid,
      installationId: input.installationId,
      issuedAtUtc: context.now.toISOString(),
      snapshotExpiresAtUtc: this.expires(context.now),
    });
  }

  async refresh(input: SessionCredentials) {
    const context = await this.authenticate(input);
    const owner = await this.sessions.resolveSessionOwner({
      ...input,
      firebaseUid: context.identity.firebaseUid,
      nowUtc: context.now.toISOString(),
    });
    await this.limit(input, context.now, 'identity.session.rotate', {
      accountId: owner,
      sessionId: input.sessionId,
    });
    return this.sessions.rotate({
      ...input,
      firebaseUid: context.identity.firebaseUid,
      nowUtc: context.now.toISOString(),
      snapshotExpiresAtUtc: this.expires(context.now),
    });
  }

  async recover(input: Credentials) {
    const context = await this.authenticate(input);
    if (context.now.getTime() / 1000 - context.identity.authTimeSeconds > 300) {
      throw new IdentityFailure('unauthenticated');
    }
    await this.bootstrapLimit(input, context);
    const account = await this.account(input, context, false);
    await this.limit(input, context.now, 'identity.session.issue', { accountId: account.userId });
    return this.sessions.recover({
      userId: account.userId,
      sessionId: randomUUID(),
      firebaseUid: context.identity.firebaseUid,
      installationId: input.installationId,
      nowUtc: context.now.toISOString(),
      snapshotExpiresAtUtc: this.expires(context.now),
    });
  }

  async revoke(input: SessionCredentials, allSessions = false): Promise<void> {
    const context = await this.authenticate(input);
    const actorUserId = await this.sessions.resolveSessionOwner({
      ...input,
      firebaseUid: context.identity.firebaseUid,
      nowUtc: context.now.toISOString(),
    });
    if (allSessions) {
      await this.sessions.logoutAll({
        actorUserId,
        currentSessionId: input.sessionId,
        nowUtc: context.now.toISOString(),
      });
    } else {
      await this.sessions.revoke({
        actorUserId,
        sessionId: input.sessionId,
        nowUtc: context.now.toISOString(),
      });
    }
  }

  private async authenticate(input: Credentials) {
    const now = this.now();
    const appCheck = await this.appCheck.verify(input.appCheckToken);
    this.observeAppCheck(appCheck.state);
    if (this.appCheckMode === 'enforce' && appCheck.state !== 'valid')
      throw new IdentityFailure('unauthenticated');
    const identity = await this.verifier.verifyIdentity(input.proof, now.toISOString());
    if (identity === null) throw new IdentityFailure('provider_assertion_invalid');
    return { now, identity };
  }

  private bootstrapLimit(
    input: Credentials,
    context: Awaited<ReturnType<DevIdentitySessionBinding['authenticate']>>,
  ) {
    const { now, identity } = context;
    return this.limit(input, now, 'identity.session.bootstrap', {
      transportIdentityHash: createHash('sha256')
        .update(`dev-identity|${identity.firebaseUid}`)
        .digest('hex'),
    });
  }

  async read(input: SessionCredentials) {
    const context = await this.authenticate(input);
    const result = await this.sessions.readCurrent({
      ...input,
      firebaseUid: context.identity.firebaseUid,
      nowUtc: context.now.toISOString(),
    });
    await this.limit(input, context.now, 'identity.session.query', {
      accountId: result.account.userId,
      sessionId: input.sessionId,
    });
    return result;
  }

  private account(
    input: Credentials,
    context: Awaited<ReturnType<DevIdentitySessionBinding['authenticate']>>,
    accountCreationEnabled: boolean,
  ) {
    // Only the verified assertion crosses into the owning account/linking service.
    const verifier = { verify: () => Promise.resolve(context.identity.assertion) };
    return new AccountLinkingService(this.repository, verifier).ensureAccount({
      proof: input.proof,
      proposedUserId: randomUUID(),
      proposedIdentityId: randomUUID(),
      nowUtc: context.now.toISOString(),
      accountCreationEnabled,
    });
  }

  private async limit(
    input: Credentials,
    now: Date,
    operation: AbuseRateRequest['operation'],
    scope: Pick<AbuseRateRequest, 'accountId' | 'sessionId' | 'transportIdentityHash'>,
  ) {
    const result = await this.limiter.consume({
      ...scope,
      operation,
      attemptRequestId: input.attemptRequestId,
      installationId: input.installationId,
      environmentId: 'recharge-dev-n2a01',
      marketId: 'LV',
      now,
      correlationId: input.attemptRequestId,
    });
    if (!result.allowed) throw new IdentityFailure('rate_limited', result.retryAfterSeconds);
  }

  private expires(now: Date): string {
    return new Date(now.getTime() + 3600000).toISOString();
  }
}

/** Explicit dev app only; no endpoint export, SDK initialization or deployment. */
export function createDevIdentitySessionBinding(
  app: App,
  allowedAppIds: readonly string[],
  options?: {
    readonly appCheckMode: 'observe' | 'enforce';
    readonly observeAppCheck: (state: 'missing' | 'invalid' | 'expired' | 'valid') => void;
  },
): DevIdentitySessionBinding {
  if (
    app.options.projectId !== 'recharge-dev-n2a01' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined ||
    process.env.FIRESTORE_EMULATOR_HOST !== undefined
  ) {
    throw new TypeError('dev_session_binding_invalid');
  }
  const firestore = getFirestore(app);
  return new DevIdentitySessionBinding(
    'recharge-dev-n2a01',
    new FirestoreIdentityAuthorityRepository(firestore),
    createDevFirebaseProviderIdentityVerifier(app),
    createDevFirebaseAppCheckPort(app, allowedAppIds),
    new FirestoreAbuseRateLimiter(firestore),
    () => new Date(),
    options?.appCheckMode ?? 'enforce',
    options?.observeAppCheck ?? (() => {}),
  );
}
