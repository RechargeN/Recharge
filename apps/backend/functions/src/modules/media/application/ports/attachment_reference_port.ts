/**
 * The owning domain answers whether an asset is still referenced by one of its
 * records (drafts or immutable revisions). Media consults it before deletion,
 * detach and orphan cleanup; a failure or an unknown answer counts as
 * "referenced" so nothing is deleted on doubt.
 */
export interface AttachmentReferencePort {
  isReferenced(assetId: string): Promise<boolean>;
}
