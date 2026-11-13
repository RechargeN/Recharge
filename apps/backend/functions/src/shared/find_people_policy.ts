/**
 * D3.7 local owner policy for Find People (owner decisions FP-OD-01..04 in the
 * T3 chat, 2026-10-19). Local/LV Emulator only: these values do not accept
 * OD-11, are not production limits and give no Legal/Privacy approval.
 */
export const findPeoplePolicy = Object.freeze({
  policyRevision: 'fp-local-owner-policy-2026-10-19',
  marketId: 'LV',
  /** FP-OD-02: the public point is the centre of a ~1 km grid cell. */
  publicGeoPrecisionMeters: 1000,
  publicGeoPolicyRevision: 'fp-public-geo-grid-1000m-v1',
  /** FP-OD-03: consent lasts until the meeting ends, at most this long. */
  consentMaxDays: 30,
  consentPurposeId: 'find_people.public_listing',
  consentPolicyRevision: 'fp-consent-local-v1',
  /** FP-OD-03: exact meeting data is erased this long after its public life ended. */
  privateLocationRetentionDays: 30,
  /** FP-OD-04: synthetic server attestation, adults only. */
  ageSurfaceId: 'find_people',
  agePolicyRevision: 'fp-age-18plus-synthetic-v1',
});

const metersPerDegreeLatitude = 111_320;
const dayMs = 86_400_000;

function round6(value: number): number {
  return Math.round(value * 1e6) / 1e6;
}

/**
 * The centre of the grid cell that contains the point (FP-OD-02). Pure and
 * deterministic: the same point always maps to the same centre, and a centre
 * maps to itself, so a published centre can be verified without the source.
 */
export function publicCellCentre(
  latitude: number,
  longitude: number,
  precisionMeters: number = findPeoplePolicy.publicGeoPrecisionMeters,
): { readonly latitude: number; readonly longitude: number } {
  const latStep = precisionMeters / metersPerDegreeLatitude;
  const band = Math.floor(latitude / latStep);
  const centreLatitude = (band + 0.5) * latStep;
  const lngStep =
    precisionMeters / (metersPerDegreeLatitude * Math.cos((centreLatitude * Math.PI) / 180));
  const column = Math.floor(longitude / lngStep);
  return {
    latitude: round6(centreLatitude),
    longitude: round6((column + 0.5) * lngStep),
  };
}

/** True when the point is exactly the centre of its own cell (published-body check). */
export function isPublicCellCentre(
  latitude: number,
  longitude: number,
  precisionMeters: number = findPeoplePolicy.publicGeoPrecisionMeters,
): boolean {
  const centre = publicCellCentre(latitude, longitude, precisionMeters);
  return centre.latitude === latitude && centre.longitude === longitude;
}

export function consentExpiresAt(grantedAtUtc: string): string {
  return new Date(Date.parse(grantedAtUtc) + findPeoplePolicy.consentMaxDays * dayMs).toISOString();
}

export function retentionDeadline(lifeEndUtc: string): string {
  return new Date(
    Date.parse(lifeEndUtc) + findPeoplePolicy.privateLocationRetentionDays * dayMs,
  ).toISOString();
}

/**
 * A decimal coordinate pair inside public text ("56.9496, 24.1052"): it would
 * publish the exact point the cell is meant to hide.
 */
export function containsCoordinatePair(value: string): boolean {
  return /-?\d{1,3}[.,]\d{3,}\s*[,;/ ]\s*-?\d{1,3}[.,]\d{3,}/u.test(value);
}
