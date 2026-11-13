import type { App } from 'firebase-admin/app';
import { getAppCheck, type VerifyAppCheckTokenResponse } from 'firebase-admin/app-check';

import type { AppCheckEvidence, AppCheckPort } from '../../security/app_check_port.js';

const projectId = 'recharge-dev-n2a01';
const projectNumber = '420479958348';

type TokenVerifier = (token: string) => Promise<VerifyAppCheckTokenResponse>;

/** Explicit dev-only adapter. Construction neither initializes Firebase nor enables enforcement. */
export class DevFirebaseAppCheckPort implements AppCheckPort {
  private readonly allowedAppIds: ReadonlySet<string>;

  constructor(
    firebaseProjectId: string,
    allowedAppIds: readonly string[],
    private readonly verifyToken: TokenVerifier,
    private readonly nowSeconds: () => number = () => Math.floor(Date.now() / 1000),
  ) {
    if (
      firebaseProjectId !== projectId ||
      allowedAppIds.length === 0 ||
      allowedAppIds.some((id) => !/^1:420479958348:(android|ios):[a-f0-9]+$/.test(id))
    ) {
      throw new TypeError('dev_app_check_binding_invalid');
    }
    this.allowedAppIds = new Set(allowedAppIds);
  }

  async verify(token: string | undefined): Promise<AppCheckEvidence> {
    if (token === undefined || token.trim() === '') return { state: 'missing' };
    try {
      // Signature and SDK project audience validation must precede inspecting claims.
      const result = await this.verifyToken(token);
      const claims = result.token;
      const now = this.nowSeconds();
      if (
        !this.allowedAppIds.has(result.appId) ||
        claims.sub !== result.appId ||
        claims.app_id !== result.appId ||
        claims.iss !== `https://firebaseappcheck.googleapis.com/${projectNumber}` ||
        !Array.isArray(claims.aud) ||
        !claims.aud.includes(`projects/${projectNumber}`) ||
        result.alreadyConsumed === true ||
        !Number.isSafeInteger(now) ||
        !Number.isSafeInteger(claims.iat) ||
        !Number.isSafeInteger(claims.exp) ||
        claims.iat > now ||
        claims.exp <= claims.iat
      ) {
        return { state: 'invalid' };
      }
      if (claims.exp <= now) return { state: 'expired' };
      return { state: 'valid', tokenAgeSeconds: now - claims.iat };
    } catch {
      // Do not log token contents, SDK errors containing tokens, or grant a fallback.
      return { state: 'invalid' };
    }
  }
}

/** Caller supplies an explicitly initialized dev app; never resolves the default app implicitly. */
export function createDevFirebaseAppCheckPort(
  app: App,
  allowedAppIds: readonly string[],
): AppCheckPort {
  if (app.options.projectId !== projectId) {
    throw new TypeError('dev_app_check_binding_invalid');
  }
  return new DevFirebaseAppCheckPort(projectId, allowedAppIds, (token) =>
    getAppCheck(app).verifyToken(token),
  );
}
