export const bookingFlagIds = Object.freeze({
  create: 'booking.create',
  cancel: 'booking.cancel',
  read: 'booking.read',
});

export const identityFlagIds = Object.freeze({
  establishSession: 'identity.session.establish',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];
