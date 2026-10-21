/** BCK-06 consent of one user for one Find People publication (D3.7 §5.1). */
export type FindPeopleConsentState =
  | {
      readonly state: 'active';
      readonly consentRevision: number;
      readonly expiresAtUtc: string;
    }
  | { readonly state: 'missing' | 'revoked' | 'expired' | 'unavailable' };

/**
 * The owner authorities Content asks about Find People (D3.7 §5–§6): the
 * synthetic 18+ attestation (FP-OD-04), BCK-06 consent and the fresh public
 * read gate (consent, age, meeting end, K2 relations, T&S). Content never
 * stores these answers as a standing permission; a missing port fails closed.
 */
export interface FindPeoplePrivacyPort {
  /** True only for a current server attestation of an adult in this market. */
  isAdult(input: {
    readonly userId: string;
    readonly marketId: string;
    readonly nowUtc: string;
  }): Promise<boolean>;
  consent(input: {
    readonly contentId: string;
    readonly userId: string;
    readonly nowUtc: string;
  }): Promise<FindPeopleConsentState>;
  /** Whether this viewer may receive this public revision now. */
  publicReadAllowed(input: {
    readonly viewerUserId: string;
    readonly contentId: string;
    readonly publisherRef: { readonly type: string; readonly id: string };
    /** The single responsible host of the revision (`null` refuses). */
    readonly hostUserId: string | null;
    /** The meeting end of the revision (`null` refuses). */
    readonly meetingEndUtc: string | null;
    readonly nowUtc: string;
  }): Promise<boolean>;
}
