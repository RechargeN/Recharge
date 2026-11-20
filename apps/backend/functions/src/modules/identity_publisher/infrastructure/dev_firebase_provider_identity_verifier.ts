import type { App } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import type {
  ProviderIdentityProof,
  ProviderIdentityVerifier,
} from '../application/ports/provider_identity_verifier.js';
import type { TrustedProviderAssertion } from '../domain/auth_identity.js';
import { isReviewedCloudProject } from '../../../shared/cloud_runtime_projects.js';

type VerifyToken = (token: string, checkRevoked: true) => Promise<DecodedIdToken>;

/** Firebase proof adapter for the existing account authority. No email linking or grants. */
export class DevFirebaseProviderIdentityVerifier implements ProviderIdentityVerifier {
  private readonly projectId: string;

  constructor(
    firebaseProjectId: string,
    private readonly verifyToken: VerifyToken,
  ) {
    // N4a: the reviewed dev or staging project only, never production.
    if (!isReviewedCloudProject(firebaseProjectId)) throw new TypeError('dev_auth_binding_invalid');
    this.projectId = firebaseProjectId;
  }

  async verify(
    proof: ProviderIdentityProof,
    nowUtc: string,
  ): Promise<TrustedProviderAssertion | null> {
    return (await this.verifyIdentity(proof, nowUtc))?.assertion ?? null;
  }

  async verifyIdentity(
    proof: ProviderIdentityProof,
    nowUtc: string,
  ): Promise<{
    readonly firebaseUid: string;
    readonly authTimeSeconds: number;
    readonly assertion: TrustedProviderAssertion;
  } | null> {
    if (
      proof.providerTenant !== this.projectId ||
      (proof.provider !== 'google' && proof.provider !== 'apple') ||
      proof.proof.trim().length === 0
    )
      return null;
    try {
      const token = await this.verifyToken(proof.proof, true);
      const now = Date.parse(nowUtc) / 1000;
      const providerId = `${proof.provider}.com`;
      const subjects: unknown = token.firebase.identities[providerId];
      if (
        !Number.isFinite(now) ||
        token.aud !== this.projectId ||
        token.iss !== `https://securetoken.google.com/${this.projectId}` ||
        token.uid !== token.sub ||
        token.uid.length < 1 ||
        token.uid.length > 128 ||
        !Number.isSafeInteger(token.iat) ||
        !Number.isSafeInteger(token.exp) ||
        !Number.isSafeInteger(token.auth_time) ||
        token.auth_time > token.iat ||
        token.iat > now ||
        token.exp <= now ||
        token.exp <= token.iat ||
        token.firebase.tenant !== undefined ||
        token.firebase.sign_in_provider !== providerId ||
        !Array.isArray(subjects) ||
        subjects.length !== 1 ||
        typeof subjects[0] !== 'string' ||
        subjects[0].length < 1 ||
        subjects[0].length > 512
      )
        return null;
      return Object.freeze({
        firebaseUid: token.uid,
        authTimeSeconds: token.auth_time,
        assertion: Object.freeze({
          provider: proof.provider,
          providerTenant: this.projectId,
          providerSubject: subjects[0],
          verifiedAtUtc: nowUtc,
        }),
      });
    } catch {
      return null;
    }
  }
}

/** Explicit app and revoke-aware SDK verification; never initialize a default app. */
export function createDevFirebaseProviderIdentityVerifier(
  app: App,
): DevFirebaseProviderIdentityVerifier {
  const projectId = app.options.projectId;
  if (!isReviewedCloudProject(projectId) || process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined) {
    throw new TypeError('dev_auth_binding_invalid');
  }
  return new DevFirebaseProviderIdentityVerifier(projectId, (token, checkRevoked) => {
    // Recheck mutable process context for every request, not only construction.
    if (
      app.options.projectId !== projectId ||
      process.env.FIREBASE_AUTH_EMULATOR_HOST !== undefined ||
      process.env.FIRESTORE_EMULATOR_HOST !== undefined
    ) {
      return Promise.reject(new TypeError('dev_auth_binding_invalid'));
    }
    return getAuth(app).verifyIdToken(token, checkRevoked);
  });
}
