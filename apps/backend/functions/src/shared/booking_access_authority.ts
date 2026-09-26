export const bookingAccessCapability = 'booking.self_service' as const;

export interface BookingAccessHint {
  /** Firebase transport identity. Never use this value as a domain User id. */
  readonly firebaseUid: string;
  readonly sessionId: string;
  readonly sessionHandle: string;
  readonly installationId: string;
}

export type BookingAccessDecision =
  | Readonly<{ allowed: true; userId: string }>
  | Readonly<{
      allowed: false;
      reason: 'account_inactive' | 'session_revoked' | 'snapshot_stale' | 'capability_denied';
    }>;

export interface BookingAccessAuthority {
  authorize(
    hint: BookingAccessHint,
    now: Date,
    requiredCapability?: typeof bookingAccessCapability,
  ): Promise<BookingAccessDecision>;
}
