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

export const mediaFlagIds = Object.freeze({
  upload: 'media.upload',
});

/** C3: Emulator-only Event authoring through Content (default off). */
export const contentFlagIds = Object.freeze({
  eventAuthoring: 'content.event.authoring',
  /** E2.0: Emulator-only Event → Booking handoff (default off). */
  eventBookingHandoff: 'content.event.bookingHandoff',
});

/** E2: Emulator-only Discover read and Content → Catalog delivery (default off). */
export const catalogFlagIds = Object.freeze({
  discoverRead: 'catalog.discover.read',
  delivery: 'catalog.delivery',
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
