import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { MediaFamily } from '../../../contracts/media_v1.js';
import {
  attachmentsRevision,
  checkAttachment,
  type MediaAttachment,
  type NotReadyReason,
} from '../domain/media_attachment.js';
import type { MediaRepository } from '../domain/repositories.js';

/**
 * Structural shape of the Content readiness port (BCK-07 v0.11 §37.2). Media
 * does not import the Content module: the wiring checks compatibility.
 */
export interface ContentMediaCheckInput {
  readonly contentId: string;
  readonly typeId: string;
  readonly marketId: string;
  readonly publisherRef: PublisherRefV1;
  readonly mediaIds: readonly string[];
  /** Required for rollback: the references stored in the target revision. */
  readonly pinned?: readonly MediaAttachment[];
}

export type ContentMediaReadiness =
  | {
      readonly ready: true;
      readonly mediaRevision: string;
      readonly attachments: readonly MediaAttachment[];
    }
  | { readonly ready: false; readonly reason: NotReadyReason };

export interface ContentMediaReadinessDeps {
  readonly repository: MediaRepository;
  /** Server-owned family flags; a disabled family is never ready. */
  readonly enabledFamilies: ReadonlySet<MediaFamily>;
}

/**
 * Answers Content's readiness question from Media's own records. The answer is
 * evidence, never an attach: Content freezes the returned references in its
 * immutable revision. Missing or doubtful binding data is never `ready`.
 */
export class ContentMediaReadinessAdapter {
  constructor(private readonly deps: ContentMediaReadinessDeps) {}

  async check(input: ContentMediaCheckInput): Promise<ContentMediaReadiness> {
    const ids = [...new Set(input.mediaIds)];
    const pinned = input.pinned;
    if (pinned !== undefined) {
      // Rollback verifies exactly the stored references: same set, nothing added.
      const pinnedIds = new Set<string>(pinned.map((item) => item.assetId));
      if (
        pinnedIds.size !== pinned.length ||
        pinnedIds.size !== ids.length ||
        !ids.every((id) => pinnedIds.has(id))
      )
        return { ready: false, reason: 'stale_generation' };
    }
    const attachments: MediaAttachment[] = [];
    const outcome = await this.deps.repository.transact(async (tx) => {
      for (const id of ids) {
        const asset = await tx.asset(id);
        if (asset !== null && !this.deps.enabledFamilies.has(asset.family))
          return { ready: false as const, reason: 'policy_unavailable' as const };
        const expected = pinned?.find((item) => item.assetId === id);
        const check = checkAttachment(
          asset,
          {
            contentId: input.contentId,
            publisherRef: input.publisherRef,
            marketId: input.marketId,
          },
          expected,
        );
        if (!check.ok) return { ready: false as const, reason: check.reason };
        attachments.push(check.attachment);
      }
      return null;
    });
    if (outcome !== null) return outcome;
    const sorted = [...attachments].sort((left, right) =>
      left.assetId.localeCompare(right.assetId),
    );
    return { ready: true, mediaRevision: attachmentsRevision(sorted), attachments: sorted };
  }
}
