export const abusePolicyId = 'bck09_abuse_v1' as const;
export const abusePolicyRevision = 1 as const;

export type AbuseOperation =
  | 'booking.create'
  | 'booking.cancel'
  | 'booking.reconfirm'
  | 'booking.query'
  | 'identity.session.bootstrap'
  | 'identity.session.issue'
  | 'identity.session.rotate';

export type AbuseSubjectKind =
  | 'actorInstallation'
  | 'account'
  | 'installation'
  | 'session'
  | 'transportIdentity'
  | 'networkRisk';

export interface AbuseBucketRule {
  readonly subjectKind: AbuseSubjectKind;
  readonly windowSeconds: number;
  readonly limit: number;
  readonly enforcing: boolean;
}

const bookingRules = Object.freeze({
  'booking.create': Object.freeze([
    rule('actorInstallation', 10, 5),
    rule('actorInstallation', 60, 10),
    rule('account', 60, 20),
    rule('installation', 60, 20),
    rule('networkRisk', 60, 60, false),
  ]),
  'booking.cancel': Object.freeze([
    rule('actorInstallation', 10, 10),
    rule('actorInstallation', 60, 20),
    rule('account', 60, 40),
    rule('installation', 60, 40),
  ]),
  'booking.reconfirm': Object.freeze([
    rule('actorInstallation', 10, 10),
    rule('actorInstallation', 60, 20),
    rule('account', 60, 40),
    rule('installation', 60, 40),
  ]),
  'booking.query': Object.freeze([rule('account', 60, 240)]),
} satisfies Record<string, readonly AbuseBucketRule[]>);

const identityRules = Object.freeze({
  'identity.session.bootstrap': Object.freeze([
    rule('transportIdentity', 15 * 60, 5),
    rule('installation', 15 * 60, 10),
    rule('networkRisk', 60 * 60, 60, false),
  ]),
  'identity.session.issue': Object.freeze([
    rule('account', 15 * 60, 5),
    rule('installation', 15 * 60, 10),
    rule('networkRisk', 60 * 60, 60, false),
  ]),
  'identity.session.rotate': Object.freeze([
    rule('session', 60 * 60, 6),
    rule('account', 60 * 60, 20),
  ]),
} satisfies Record<string, readonly AbuseBucketRule[]>);

export const maximumActiveFiniteBookings = 5;
export const maximumActiveUnlimitedBookings = 50;
export const maximumActiveSessions = 3;
export const bookingCompletionGraceMinutes = 120;
export const automaticRetryWindowDays = 7;
export const reconciliationScheduleSeconds = Object.freeze([0, 60, 300, 900, 3600, 21600]);

export function abuseRulesFor(operation: AbuseOperation): readonly AbuseBucketRule[] {
  if (operation in bookingRules) {
    return bookingRules[operation as keyof typeof bookingRules];
  }
  return identityRules[operation as keyof typeof identityRules];
}

function rule(
  subjectKind: AbuseSubjectKind,
  windowSeconds: number,
  limit: number,
  enforcing = true,
): AbuseBucketRule {
  return Object.freeze({ subjectKind, windowSeconds, limit, enforcing });
}
