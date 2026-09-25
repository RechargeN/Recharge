import type { PageCapabilityGrantPolicyPort } from '../application/ports/page_capability_grant_policy_port.js';
import { parseLocalIdentityCapability } from '../domain/capability.js';

const grantableByRole = Object.freeze({
  owner: new Set([
    'content.create',
    'content.submit',
    'content.publish',
    'manage_page',
    'manage_bookings',
    'view_insights',
  ]),
  manager: new Set(['content.create', 'content.submit', 'content.publish', 'manage_page']),
  analyst: new Set(['view_insights']),
  bookingManager: new Set(['manage_bookings']),
});

export class LocalPageCapabilityGrantPolicy implements PageCapabilityGrantPolicyPort {
  mayGrant(input: Parameters<PageCapabilityGrantPolicyPort['mayGrant']>[0]): Promise<boolean> {
    if (input.actor.status !== 'active' || input.actor.role !== 'owner') {
      return Promise.resolve(false);
    }
    if (input.target.status !== 'active') return Promise.resolve(false);
    const requested = input.requestedCapabilityIds.map(parseLocalIdentityCapability);
    if (input.target.role === 'owner' && !requested.includes('manage_page')) {
      return Promise.resolve(false);
    }
    const allowed = grantableByRole[input.target.role];
    return Promise.resolve(requested.every((capabilityId) => allowed.has(capabilityId)));
  }
}
