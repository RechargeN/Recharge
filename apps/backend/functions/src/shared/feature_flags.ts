export const bookingFlagIds = Object.freeze({
  create: 'booking.create',
  cancel: 'booking.cancel',
  read: 'booking.read',
});

export type BookingFlagId = (typeof bookingFlagIds)[keyof typeof bookingFlagIds];
