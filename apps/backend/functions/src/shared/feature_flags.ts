export const bookingFlagIds = Object.freeze({
  create: 'booking.create',
  cancel: 'booking.cancel',
  reconfirm: 'booking.reconfirm',
  read: 'booking.read',
  eventProjectionDelivery: 'booking.eventProjection.delivery',
  reconfirmationDeadlineWorker: 'booking.reconfirmation.deadlineWorker',
});

export const identityFlagIds = Object.freeze({
  establishSession: 'identity.session.establish',
});

export const abuseEmergencySwitchIds = Object.freeze({
  bookingCreate: 'booking.create.incidentDisable',
  bookingCancel: 'booking.cancel.incidentDisable',
  bookingReconfirm: 'booking.reconfirm.incidentDisable',
  bookingQuery: 'booking.query.incidentDisable',
  identitySessionIssue: 'identity.session.issue.incidentDisable',
  identitySessionRotate: 'identity.session.rotate.incidentDisable',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];
