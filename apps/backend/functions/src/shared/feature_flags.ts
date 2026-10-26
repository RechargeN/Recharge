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
  /** D3.7: Emulator-only grant of Find People consent (default off; revoke is never gated). */
  findPeopleConsent: 'identity.findPeople.consent',
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
  /** D3.2: Emulator-only Recharge Activity authoring through Content (default off). */
  activityAuthoring: 'content.activity.authoring',
  /** D3.3: Emulator-only Rental / Equipment authoring through Content (default off). */
  rentalAuthoring: 'content.rental.authoring',
  /** D3.4: Emulator-only Collection / Guide authoring through Content (default off). */
  collectionAuthoring: 'content.collection.authoring',
  sessionAuthoring: 'content.session.authoring',
  /** I3 / SCN-PUB-01: Emulator-only public Scenario through Content (default off). */
  scenarioAuthoring: 'content.scenario.authoring',
  /** J2 / RTE-PUB-01: Emulator-only public Route through Content (default off). */
  routeAuthoring: 'content.route.authoring',
  /** D3.6: Emulator-only Class / Workshop authoring through Content (default off). */
  classWorkshopAuthoring: 'content.class_workshop.authoring',
  /** D3.7: Emulator-only Find People authoring through Content (default off). */
  findPeopleAuthoring: 'content.findPeople.authoring',
  /** E2.0: Emulator-only Event → Booking handoff (default off). */
  eventBookingHandoff: 'content.event.bookingHandoff',
  /** D2: Emulator-only reaction to late Media restriction or deletion (default off). */
  mediaAvailability: 'content.mediaAvailability',
});

/** E2: Emulator-only Discover read and Content → Catalog delivery (default off). */
export const catalogFlagIds = Object.freeze({
  discoverRead: 'catalog.discover.read',
  delivery: 'catalog.delivery',
  /** D3.7: Emulator-only Find People projection and read (default off). */
  findPeople: 'catalog.findPeople',
});

export const abuseEmergencySwitchIds = Object.freeze({
  bookingCreate: 'booking.create.incidentDisable',
  bookingCancel: 'booking.cancel.incidentDisable',
  bookingReconfirm: 'booking.reconfirm.incidentDisable',
  bookingQuery: 'booking.query.incidentDisable',
  identitySessionIssue: 'identity.session.issue.incidentDisable',
  identitySessionRotate: 'identity.session.rotate.incidentDisable',
});

/**
 * L2: emergency switches of operational task families (OPS-L2 §5). On means
 * the family is contained: dispatch and effect refuse, the queue stays. Off by
 * default; an unreadable switch counts as on.
 */
export const operationsEmergencySwitchIds = Object.freeze({
  eventProjectionDelivery: 'booking.eventProjection.delivery.incidentDisable',
  reconfirmationDeadlineWorker: 'booking.reconfirmation.deadlineWorker.incidentDisable',
  notificationsConsumeBooking: 'notifications.consume.booking.incidentDisable',
});

/**
 * L3: Emulator-only product analytics (default off). Each switch stops only its
 * own stage; security audit, operations and user commands never read them.
 */
export const productAnalyticsFlagIds = Object.freeze({
  collection: 'productAnalytics.collection',
  aggregation: 'productAnalytics.aggregation',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];

/** I2 bounded Scenario persistence and collaboration, Emulator only. */
export const scenarioFlagIds = Object.freeze({
  sync: 'planning.scenarioI2',
  /** SCN-PUB-01 / I3: immutable public distribution revisions (default off). */
  publication: 'planning.scenarioPublication',
  /** SCN-PUB-01 / I3: unlisted share tokens (default off). */
  share: 'planning.scenarioShare',
});
