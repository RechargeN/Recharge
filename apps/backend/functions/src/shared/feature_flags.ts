export const bookingFlagIds = Object.freeze({
  create: 'booking.create',
  cancel: 'booking.cancel',
  read: 'booking.read',
  eventProjectionDelivery: 'booking.eventProjection.delivery',
});

export const identityFlagIds = Object.freeze({
  establishSession: 'identity.session.establish',
});

export const abuseEmergencySwitchIds = Object.freeze({
  bookingCreate: 'booking.create.incidentDisable',
  bookingCancel: 'booking.cancel.incidentDisable',
  bookingQuery: 'booking.query.incidentDisable',
  identitySessionIssue: 'identity.session.issue.incidentDisable',
  identitySessionRotate: 'identity.session.rotate.incidentDisable',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];
