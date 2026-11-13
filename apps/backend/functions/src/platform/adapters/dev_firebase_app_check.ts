import type { App } from 'firebase-admin/app';
import { getAppCheck, type VerifyAppCheckTokenResponse } from 'firebase-admin/app-check';

import type { AppCheckEvidence, AppCheckPort } from '../../security/app_check_port.js';
import { cloudProjectNumber, isReviewedCloudProject } from '../../shared/cloud_runtime_projects.js';

type TokenVerifier = (token: string) => Promise<VerifyAppCheckTokenResponse>;

/** Explicit dev-only adapter. Construction neither initializes Firebase nor enables enforcement. */
export class DevFirebaseAppCheckPort implements AppCheckPort {
  private readonly allowedAppIds: ReadonlySet<string>;
  private readonly projectNumber: string;

  constructor(
    firebaseProjectId: string,
    allowedAppIds: readonly string[],
    private readonly verifyToken: TokenVerifier,
    private readonly nowSeconds: () => number = () => Math.floor(Date.now() / 1000),
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    // N4a: dev or staging only; the number is fixed for dev, configured for staging.
    const projectNumber = isReviewedCloudProject(firebaseProjectId)
      ? cloudProjectNumber(firebaseProjectId, environment)
      : null;
    if (
      projectNumber === null ||
      allowedAppIds.length === 0 ||
      allowedAppIds.some(
        (id) => !new RegExp(`^1:${projectNumber}:(android|ios):[a-f0-9]+$`, 'u').test(id),
      )
    ) {
      throw new TypeError('dev_app_check_binding_invalid');
    }
    this.projectNumber = projectNumber;
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
        claims.iss !== `https://firebaseappcheck.googleapis.com/${this.projectNumber}` ||
        !Array.isArray(claims.aud) ||
        !claims.aud.includes(`projects/${this.projectNumber}`) ||
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
  const projectId = app.options.projectId;
  if (!isReviewedCloudProject(projectId)) {
    throw new TypeError('dev_app_check_binding_invalid');
  }
  return new DevFirebaseAppCheckPort(projectId, allowedAppIds, (token) =>
    getAppCheck(app).verifyToken(token),
  );
}
