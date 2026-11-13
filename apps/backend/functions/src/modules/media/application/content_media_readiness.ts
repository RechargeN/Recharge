import type { PublisherRefV1 } from '../../../contracts/identity_v1.js';
import type { MediaFamily } from '../../../contracts/media_v1.js';
import { revocationEpochOf } from '../domain/media_asset.js';
import {
  attachmentsRevision,
  checkAttachment,
  type MediaAttachment,
  type MediaConfirmation,
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
      /** The revocation epoch of every attachment at this instant (D2 §3). */
      readonly confirmations: readonly MediaConfirmation[];
    }
  | { readonly ready: false; readonly reason: NotReadyReason };

/**
 * Structural shape of Content's availability question (D2 §5.2): what Media
 * says about an attached asset now. Ids, states, generations and epochs only.
 */
export type ContentMediaAvailabilityState =
  'deliverable' | 'restricted' | 'held' | 'not_ready' | 'deleted' | 'absent';

export interface ContentMediaAvailability {
  readonly assetId: string;
  readonly state: ContentMediaAvailabilityState;
  readonly revocationEpoch: number;
  readonly sourceGeneration?: string;
  readonly variantManifestRevision?: string;
}

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
    const confirmations: MediaConfirmation[] = [];
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
        if (!check.ok || asset === null)
          return { ready: false as const, reason: check.ok ? 'asset_unknown' : check.reason };
        attachments.push(check.attachment);
        confirmations.push({ assetId: asset.assetId, revocationEpoch: revocationEpochOf(asset) });
      }
      return null;
    });
    if (outcome !== null) return outcome;
    const sorted = [...attachments].sort((left, right) =>
      left.assetId.localeCompare(right.assetId),
    );
    return {
      ready: true,
      mediaRevision: attachmentsRevision(sorted),
      attachments: sorted,
      confirmations: [...confirmations].sort((left, right) =>
        left.assetId.localeCompare(right.assetId),
      ),
    };
  }

  /**
   * Current availability of attached assets, from Media's own records, in one
   * short read. A restriction, deletion or hold is reported as such; whether a
   * Content revision still may show the asset is Content's decision.
   */
  async availability(assetIds: readonly string[]): Promise<readonly ContentMediaAvailability[]> {
    const ids = [...new Set(assetIds)].sort();
    return this.deps.repository.transact(async (tx) => {
      const answers: ContentMediaAvailability[] = [];
      for (const assetId of ids) {
        const asset = await tx.asset(assetId);
        if (asset === null) {
          answers.push({ assetId, state: 'absent', revocationEpoch: 0 });
          continue;
        }
        const state: ContentMediaAvailabilityState =
          asset.lifecycle === 'deleting' || asset.lifecycle === 'deleted'
            ? 'deleted'
            : asset.restricted === true
              ? 'restricted'
              : asset.deletionHold !== undefined
                ? 'held'
                : asset.lifecycle !== 'ready' ||
                    asset.deliveryDisabled ||
                    asset.visibilityClass !== 'publicDerived'
                  ? 'not_ready'
                  : 'deliverable';
        const generation = asset.sourceGenerationRef?.providerGeneration;
        const manifest = asset.variantManifestRevision;
        answers.push({
          assetId,
          state,
          revocationEpoch: revocationEpochOf(asset),
          ...(generation === undefined ? {} : { sourceGeneration: generation }),
          ...(manifest === undefined ? {} : { variantManifestRevision: manifest }),
        });
      }
      return answers;
    });
  }
}
