import type { ContentTypeId } from '../../../../contracts/content_v1.js';

export type MediaReadiness =
  { readonly ready: true; readonly mediaRevision: string } | { readonly ready: false };

/** BCK-14 remains the Media authority; pending or unknown media is not ready. */
export interface MediaReadinessPort {
  check(input: {
    readonly contentId: string;
    readonly typeId: ContentTypeId;
    readonly mediaIds: readonly string[];
  }): Promise<MediaReadiness>;
}
