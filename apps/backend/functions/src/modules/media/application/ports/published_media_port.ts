/**
 * The owning domain's answer to the D2 delivery gate
 * (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §4, step 2): the pin of an asset
 * while a publicly visible current revision attaches it, the owner does not
 * suppress it and the publisher confirmed its revocation epoch; otherwise `null`.
 * Structural: Media does not import the owning domain.
 */
export interface PublishedMediaPin {
  readonly contentId: string;
  readonly pointerRevision: number;
  readonly publishedRevisionId: string;
  readonly sourceGeneration: string;
  readonly variantManifestRevision: string;
  readonly revocationEpoch: number;
}

export interface PublishedMediaPort {
  deliverablePin(request: {
    readonly contentId: string;
    readonly assetId: string;
  }): Promise<PublishedMediaPin | null>;
}
