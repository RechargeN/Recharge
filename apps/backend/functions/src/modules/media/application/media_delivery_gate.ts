import { createHash } from 'node:crypto';

import { rejected, succeeded, type MediaResult } from '../domain/failures.js';
import { revocationEpochOf, type MediaAsset } from '../domain/media_asset.js';
import type { MediaRepository } from '../domain/repositories.js';
import type { ObjectBytesPort, ObjectRead } from './ports/object_store_port.js';
import type { PublishedMediaPin, PublishedMediaPort } from './ports/published_media_port.js';

/** One delivered public variant: bytes and their identity, never a URL or a key. */
export interface DeliveredVariant {
  readonly assetId: string;
  readonly profile: string;
  readonly format: string;
  readonly sha256: string;
  readonly byteLength: number;
  readonly bytes: Buffer;
}

export interface MediaDeliveryRequest {
  readonly contentId: string;
  readonly assetId: string;
  readonly profile: string;
}

export interface MediaDeliveryGateDeps {
  readonly repository: MediaRepository;
  readonly published: PublishedMediaPort;
  readonly objects: ObjectBytesPort;
  /** Largest variant handed out in one response (local test bound). */
  readonly maxBytes: number;
}

/** Everything the gate needs from the Media record, matched against the pin. */
function deliverable(
  asset: MediaAsset | null,
  pin: PublishedMediaPin,
  profile: string,
): (MediaAsset['variantRefs'][number] & { readonly assetRevision: number }) | null {
  if (
    asset === null ||
    asset.entityBinding?.domain !== 'content' ||
    asset.entityBinding.entityId !== pin.contentId ||
    asset.lifecycle !== 'ready' ||
    asset.deliveryDisabled ||
    asset.visibilityClass !== 'publicDerived' ||
    asset.sourceGenerationRef?.providerGeneration !== pin.sourceGeneration ||
    asset.variantManifestRevision !== pin.variantManifestRevision ||
    revocationEpochOf(asset) !== pin.revocationEpoch
  )
    return null;
  const variant = asset.variantRefs.find((item) => item.profile === profile);
  return variant === undefined ? null : { ...variant, assetRevision: asset.revision };
}

/**
 * D2 delivery gate (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §4). Every request
 * is decided again from authoritative records, nothing is cached and no handle
 * survives the response:
 *
 * 2. the owning domain names the pin of a publicly visible, unsuppressed and
 *    confirmed attachment;
 * 3. Media's own record is `ready`, not disabled, public-derived, at the pinned
 *    generation and manifest and at the confirmed revocation epoch;
 * 4. the variant's bytes are read at its generation and match the manifest;
 * 5. the owning domain is asked again: same pointer revision;
 * 6. Media is read again last: same asset revision.
 *
 * Every refusal after the Session check is `not_found`. A restriction committed
 * before step 6 refuses the request; one committed after it still lets that one
 * response go out (window W1), and a publication change after step 5 does too
 * (window W2). Each module is read in its own short transaction.
 */
export class MediaDeliveryGate {
  constructor(private readonly deps: MediaDeliveryGateDeps) {}

  async deliver(request: MediaDeliveryRequest): Promise<MediaResult<DeliveredVariant>> {
    const pin = await this.#pin(request);
    if (pin === null) return rejected('not_found');
    const first = await this.#media(request, pin);
    if (first === null) return rejected('not_found');
    let read: ObjectRead;
    try {
      read = await this.deps.objects.readVariant(
        first.variantId,
        first.providerGeneration,
        Math.min(this.deps.maxBytes, first.byteLength),
      );
    } catch {
      return rejected('not_found');
    }
    if (read.kind !== 'complete') return rejected('not_found');
    const sha256 = createHash('sha256').update(read.bytes).digest('hex');
    if (sha256 !== first.sha256 || read.bytes.length !== first.byteLength)
      return rejected('not_found');
    // Step 5: the publication is still the one that was checked.
    const again = await this.#pin(request);
    if (again === null || again.pointerRevision !== pin.pointerRevision)
      return rejected('not_found');
    // Step 6, last: Media has not changed since step 3.
    const last = await this.#media(request, again);
    if (last === null || last.assetRevision !== first.assetRevision) return rejected('not_found');
    return succeeded({
      assetId: request.assetId,
      profile: first.profile,
      format: first.format,
      sha256,
      byteLength: read.bytes.length,
      bytes: read.bytes,
    });
  }

  async #pin(request: MediaDeliveryRequest): Promise<PublishedMediaPin | null> {
    try {
      const pin = await this.deps.published.deliverablePin({
        contentId: request.contentId,
        assetId: request.assetId,
      });
      return pin !== null && pin.contentId === request.contentId ? pin : null;
    } catch {
      return null;
    }
  }

  #media(request: MediaDeliveryRequest, pin: PublishedMediaPin) {
    return this.deps.repository.transact(async (tx) =>
      deliverable(await tx.asset(request.assetId), pin, request.profile),
    );
  }
}
