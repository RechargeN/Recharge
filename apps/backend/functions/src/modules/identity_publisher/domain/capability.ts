export const localIdentityCapabilities = [
  'content.create',
  'content.submit',
  'content.publish',
  'manage_page',
  'manage_bookings',
  'view_insights',
] as const;

export type LocalIdentityCapability = (typeof localIdentityCapabilities)[number];

export function parseLocalIdentityCapability(value: string): LocalIdentityCapability {
  if (!localIdentityCapabilities.includes(value as LocalIdentityCapability))
    throw new TypeError('capability_unsupported');
  return value as LocalIdentityCapability;
}
