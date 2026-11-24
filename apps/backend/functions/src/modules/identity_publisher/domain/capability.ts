export const localIdentityCapabilities = [
  'content.create',
  'content.submit',
  'content.publish',
  'manage_page',
  'manage_bookings',
  'view_insights',
  'booking.self_service',
] as const;

export type LocalIdentityCapability = (typeof localIdentityCapabilities)[number];

export function parseLocalIdentityCapability(value: string): LocalIdentityCapability {
  if (!localIdentityCapabilities.includes(value as LocalIdentityCapability))
    throw new TypeError('capability_unsupported');
  return value as LocalIdentityCapability;
}

/**
 * ADR 0023: every active User authors free personal content and books for
 * themselves. One list for every personal access snapshot (Session establish,
 * refresh, recovery and the access snapshot service), so the phone sees the
 * same authority the commands enforce. Money still needs the seller
 * declaration and verification, checked per command, not here.
 */
export const personalCapabilityIds: readonly LocalIdentityCapability[] = Object.freeze([
  'booking.self_service',
  'content.create',
  'content.submit',
  'content.publish',
]);
