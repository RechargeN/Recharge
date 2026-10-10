export const bookingFlagIds = Object.freeze({
  create: 'booking.create',
  cancel: 'booking.cancel',
  reconfirm: 'booking.reconfirm',
  read: 'booking.read',
  eventProjectionDelivery: 'booking.eventProjection.delivery',
  reconfirmationDeadlineWorker: 'booking.reconfirmation.deadlineWorker',
});

/**
 * F1: Emulator-only activation of the Booking notification producer (default
 * off). Kept apart from `bookingFlagIds` so enabling the Booking commands never
 * switches the outbox from v1 `suppressedPreActivation` to v2.
 */
export const bookingNotificationFlagIds = Object.freeze({
  effects: 'booking.notification.effects',
});

/** F1: Emulator-only Notifications inbox (default off). */
export const notificationsFlagIds = Object.freeze({
  consumeBooking: 'notifications.consume.booking',
  inbox: 'notifications.inbox',
  preferences: 'notifications.preferences',
});

export const identityFlagIds = Object.freeze({
  establishSession: 'identity.session.establish',
});

export const mediaFlagIds = Object.freeze({
  upload: 'media.upload',
  /** D2: Emulator-only delivery gate (default off). */
  delivery: 'media.delivery',
  /** D2: Emulator-only R2 orphan sweep (default off). */
  reconcile: 'media.reconcile',
});

/** C3: Emulator-only Event authoring through Content (default off). */
export const contentFlagIds = Object.freeze({
  eventAuthoring: 'content.event.authoring',
  /** D3.1: Emulator-only Place authoring through Content (default off). */
  placeAuthoring: 'content.place.authoring',
  /** E2.0: Emulator-only Event → Booking handoff (default off). */
  eventBookingHandoff: 'content.event.bookingHandoff',
  /** D2: Emulator-only reaction to late Media restriction or deletion (default off). */
  mediaAvailability: 'content.mediaAvailability',
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
