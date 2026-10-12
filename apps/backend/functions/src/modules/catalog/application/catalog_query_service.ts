import type { PlaceLinkService } from './place_link_service.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import { availabilityNotConnectedReason, catalogTestOnlyConfig } from '../domain/catalog_config.js';
import type {
  CatalogEventItem,
  CatalogActivityItem,
  CatalogItem,
  CatalogOccurrence,
} from '../domain/catalog_item.js';
import { parseDiscoverQuery, type DiscoverQuery } from '../domain/discover_query.js';
import {
  compareKeys,
  evaluate,
  occurrenceState,
  projectionFreshness,
  referenceFreshness,
  strictest,
  type Freshness,
  type SortKey,
} from '../domain/evaluation.js';
import type {
  CatalogRepository,
  ItemVersionRecord,
  ProjectionSetRecord,
} from '../domain/repositories.js';
import {
  issueCursor,
  issueSnapshot,
  verifyCursor,
  verifySnapshot,
  type SnapshotClaims,
} from '../domain/snapshot.js';
import type { ReferenceRevisionsPort } from './ports.js';

export type CatalogQueryFailure = {
  readonly kind: 'unsupported' | 'invalid' | 'stale' | 'unavailable';
  readonly code: string;
};

export interface CatalogEventCard {
  readonly ref: { readonly typeId: 'event'; readonly contentId: string };
  readonly publishedRevisionId: string;
  readonly title: string;
  readonly shortDescription: string;
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly format: string;
  readonly city: string | null;
  readonly venueName: string | null;
  readonly point: CatalogEventItem['point'];
  readonly notMappable: CatalogEventItem['notMappable'];
  readonly timezoneId: string;
  readonly occurrence: CatalogOccurrence & { readonly state: 'running' | 'upcoming' };
  readonly remainingOccurrences: number;
  readonly price: CatalogEventItem['price'];
  readonly coverMediaId: string | null;
  readonly distanceMeters: number | null;
  /** Booking availability is not connected to E1: never "available". */
  readonly availability: { readonly status: 'not_connected'; readonly reason: string };
  /** The object has a newer listed revision than this snapshot shows. */
  readonly changedSinceSnapshot: boolean;
  readonly projectedAtUtc: string;
}

export type CatalogCard =
  | CatalogEventCard
  | (CatalogActivityItem & {
      readonly ref: { readonly typeId: 'activity'; readonly contentId: string };
      readonly distanceMeters: number | null;
      readonly changedSinceSnapshot: boolean;
      readonly projectedAtUtc: string;
    });

export interface CatalogFreshness {
  readonly overall: Freshness;
  readonly projection: Freshness;
  readonly reference: Freshness;
  readonly availability: 'not_connected';
}

export interface FeedPage {
  readonly kind: 'succeeded';
  readonly snapshotToken: string;
  readonly snapshot: SnapshotClaims;
  readonly freshness: CatalogFreshness;
  readonly items: readonly CatalogCard[];
  readonly nextCursor: string | null;
  readonly totalEligible: number;
}

export interface MapResult {
  readonly kind: 'succeeded';
  readonly snapshotToken: string;
  readonly snapshot: SnapshotClaims;
  readonly freshness: CatalogFreshness;
  /** Every leaf is a member of the Feed result of the same token. */
  readonly leaves: readonly {
    readonly ref: { readonly typeId: 'event' | 'activity'; readonly contentId: string };
    readonly point: NonNullable<CatalogEventItem['point']>;
    readonly title: string;
  }[];
  readonly notMappable: number;
  readonly totalEligible: number;
}

export interface DetailsResult {
  readonly kind: 'succeeded';
  readonly state: 'listed' | 'excluded' | 'absent';
  readonly reason: string | null;
  readonly item: CatalogItem | null;
  readonly changedSinceSnapshot: boolean;
}

interface Eligible {
  readonly version: ItemVersionRecord;
  readonly item: CatalogItem;
  readonly key: SortKey;
  readonly occurrence: CatalogOccurrence | null;
  /** At the snapshot's pinned server time. */
  readonly occurrenceState: 'running' | 'upcoming';
  readonly remaining: number;
  readonly distance: number | null;
  readonly changed: boolean;
}

interface Resolved {
  readonly query: DiscoverQuery;
  readonly pageSize: number;
  readonly token: string;
  readonly claims: SnapshotClaims;
  readonly set: ProjectionSetRecord;
  readonly eligible: readonly Eligible[];
  readonly freshness: CatalogFreshness;
}

/**
 * Read side of the local Catalog. Feed, Search, Map and Details of one applied
 * query share one snapshot (set, revision, policies and the pinned server
 * time). Within a snapshot the order is total and stable; an object hidden
 * after the snapshot is still removed (a tombstone always wins), and a newer
 * listed revision is reported as changed, never silently swapped in.
 */
export class CatalogQueryService {
  constructor(
    private readonly repository: CatalogRepository,
    private readonly references: ReferenceRevisionsPort,
    private readonly clock: ServerClock,
    private readonly activityEnabled = false,
    private readonly placeLinks?: PlaceLinkService,
  ) {}

  placeLink(input: { readonly placeId: string; readonly marketId: string }) {
    return this.placeLinks?.check(input) ?? Promise.resolve({ status: 'unavailable' as const });
  }
  placeCandidates(input: {
    readonly marketId: string;
    readonly text: string;
    readonly after?: string;
    readonly limit: number;
  }) {
    return (
      this.placeLinks?.candidates(input) ?? Promise.resolve({ status: 'unavailable' as const })
    );
  }
  async #publicActivity(item: CatalogActivityItem): Promise<CatalogActivityItem> {
    const { linkedPlaceId, linkedPlace: ignored, ...publicItem } = item;
    void ignored;
    if (!linkedPlaceId) return publicItem;
    const result = await this.placeLink({ placeId: linkedPlaceId, marketId: item.marketId });
    return result.status === 'eligible' ? { ...publicItem, linkedPlace: result.place } : publicItem;
  }

  async feed(request: {
    readonly query: unknown;
    readonly snapshotToken?: string;
    readonly cursor?: string;
  }): Promise<FeedPage | CatalogQueryFailure> {
    const resolved = await this.#resolve(
      request.query,
      request.snapshotToken,
      request.cursor !== undefined,
    );
    if ('code' in resolved) return resolved;
    let start = 0;
    if (request.cursor !== undefined) {
      const cursor = verifyCursor(request.cursor, resolved.token);
      if (!cursor.ok) return { kind: 'invalid', code: cursor.code };
      start = resolved.eligible.findIndex((entry) => compareKeys(entry.key, cursor.lastKey) > 0);
      if (start < 0) start = resolved.eligible.length;
    }
    const page = resolved.eligible.slice(start, start + resolved.pageSize);
    const last = page[page.length - 1];
    const more = start + page.length < resolved.eligible.length;
    return {
      kind: 'succeeded',
      snapshotToken: resolved.token,
      snapshot: resolved.claims,
      freshness: resolved.freshness,
      items: page.map((entry) => this.#card(entry)),
      nextCursor: more && last !== undefined ? issueCursor(resolved.token, last.key) : null,
      totalEligible: resolved.eligible.length,
    };
  }

  /** Literal Search: the same filters and snapshot as Feed, text required. */
  async search(request: {
    readonly query: unknown;
    readonly snapshotToken?: string;
    readonly cursor?: string;
  }): Promise<FeedPage | CatalogQueryFailure> {
    const parsed = parseDiscoverQuery(request.query, this.activityEnabled);
    if (parsed.ok && parsed.query.textTokens.length === 0)
      return { kind: 'invalid', code: 'text_required' };
    return this.feed(request);
  }

  async map(request: {
    readonly query: unknown;
    readonly snapshotToken?: string;
    readonly viewport?: {
      readonly minLatitude: number;
      readonly maxLatitude: number;
      readonly minLongitude: number;
      readonly maxLongitude: number;
    };
  }): Promise<MapResult | CatalogQueryFailure> {
    const viewport = request.viewport;
    if (
      viewport !== undefined &&
      !(
        [
          viewport.minLatitude,
          viewport.maxLatitude,
          viewport.minLongitude,
          viewport.maxLongitude,
        ].every((value) => typeof value === 'number' && Number.isFinite(value)) &&
        viewport.minLatitude < viewport.maxLatitude &&
        viewport.minLongitude < viewport.maxLongitude
      )
    )
      return { kind: 'invalid', code: 'viewport_invalid' };
    const resolved = await this.#resolve(request.query, request.snapshotToken, false);
    if ('code' in resolved) return resolved;
    const leaves = [];
    let notMappable = 0;
    for (const entry of resolved.eligible) {
      const point = entry.item.point;
      if (point === null) {
        notMappable += 1;
        continue;
      }
      if (
        viewport !== undefined &&
        (point.latitude < viewport.minLatitude ||
          point.latitude > viewport.maxLatitude ||
          point.longitude < viewport.minLongitude ||
          point.longitude > viewport.maxLongitude)
      )
        continue;
      leaves.push({
        ref: { typeId: entry.item.typeId, contentId: entry.item.contentId },
        point,
        title: entry.item.title,
      });
    }
    return {
      kind: 'succeeded',
      snapshotToken: resolved.token,
      snapshot: resolved.claims,
      freshness: resolved.freshness,
      leaves,
      notMappable,
      totalEligible: resolved.eligible.length,
    };
  }

  /** The exact object: listed, excluded (with the reason) or absent. */
  async details(request: {
    readonly contentId: string;
    readonly snapshotToken?: string;
    readonly query?: unknown;
  }): Promise<DetailsResult | CatalogQueryFailure> {
    const set = await this.#activeSet();
    if (set === null) return { kind: 'unavailable', code: 'catalog_not_initialized' };
    const versions = await this.repository.versionsForContent(set.setId, request.contentId);
    const current = versions.find((version) => version.validToRevision === null);
    if (current === undefined)
      return {
        kind: 'succeeded',
        state: 'absent',
        reason: null,
        item: null,
        changedSinceSnapshot: false,
      };
    if (current.item?.typeId === 'activity') {
      if (!this.activityEnabled) return { kind: 'unsupported', code: 'type_disabled:activity' };
      const pinned = await this.references.readTaxonomyRevision?.(
        current.item.referenceRevisions.taxonomyRevisionId ?? '',
      );
      if (!pinned?.ok)
        return { kind: 'unavailable', code: pinned?.code ?? 'taxonomy_revision_unavailable' };
    }
    let changed = false;
    if (request.snapshotToken !== undefined && request.query !== undefined) {
      const parsed = parseDiscoverQuery(request.query, this.activityEnabled);
      if (!parsed.ok) return { kind: parsed.kind, code: parsed.code };
      const check = verifySnapshot(
        request.snapshotToken,
        parsed.fingerprint,
        this.clock.now().getTime(),
      );
      if (!check.ok) return { kind: 'stale', code: check.code };
      const atSnapshot = versionAt(versions, check.claims.projectionSetRevision);
      changed =
        atSnapshot?.publishedRevisionId !== current.publishedRevisionId ||
        atSnapshot?.state !== current.state;
    }
    return {
      kind: 'succeeded',
      state: current.state,
      reason: current.reason,
      item:
        current.state === 'listed'
          ? current.item?.typeId === 'activity'
            ? await this.#publicActivity(current.item)
            : current.item
          : null,
      changedSinceSnapshot: changed,
    };
  }

  async #activeSet(): Promise<ProjectionSetRecord | null> {
    return this.repository.transact(async (tx) => {
      const pointer = await tx.activePointer();
      return pointer === null ? null : tx.set(pointer.setId);
    });
  }

  async #resolve(
    rawQuery: unknown,
    snapshotToken: string | undefined,
    paging: boolean,
  ): Promise<Resolved | CatalogQueryFailure> {
    const parsed = parseDiscoverQuery(rawQuery, this.activityEnabled);
    if (!parsed.ok) return { kind: parsed.kind, code: parsed.code };
    const requestNow = this.clock.now().getTime();
    const set = await this.#activeSet();
    if (set === null) return { kind: 'unavailable', code: 'catalog_not_initialized' };
    const currents = new Map(
      await Promise.all(
        parsed.query.typeIds.map(
          async (typeId) =>
            [typeId, await this.references.current(parsed.query.marketId, typeId)] as const,
        ),
      ),
    );
    const current = currents.get(parsed.query.typeIds[0] ?? 'event') ?? null;
    const referenceRevision =
      parsed.query.typeIds.length === 1
        ? current === null
          ? 'unknown'
          : Object.values(current).sort().join('|')
        : [...currents]
            .map(
              ([typeId, refs]) =>
                typeId + ':' + (refs === null ? 'unknown' : Object.values(refs).sort().join('|')),
            )
            .sort()
            .join(';');

    let token: string;
    let claims: SnapshotClaims;
    if (snapshotToken !== undefined) {
      const check = verifySnapshot(snapshotToken, parsed.fingerprint, requestNow);
      if (!check.ok)
        return {
          kind: 'stale',
          code: paging && check.code === 'snapshot_expired' ? 'cursor_expired' : check.code,
        };
      // A snapshot of a set that is no longer active cannot be served or merged.
      if (check.claims.projectionSetId !== set.setId)
        return { kind: 'stale', code: 'snapshot_superseded' };
      token = snapshotToken;
      claims = check.claims;
    } else {
      if (paging) return { kind: 'invalid', code: 'cursor_without_snapshot' };
      const issued = issueSnapshot({
        queryFingerprint: parsed.fingerprint,
        projectionSetId: set.setId,
        projectionSetRevision: set.revision,
        referenceDatasetRevision: referenceRevision,
        nowMs: requestNow,
      });
      token = issued.token;
      claims = issued.claims;
    }

    const versions = (
      await Promise.all(
        parsed.query.typeIds.map((typeId) =>
          this.repository.versionsForSet(
            set.setId,
            parsed.query.marketId,
            typeId,
            catalogTestOnlyConfig.candidateLimit * 4 + 1,
          ),
        ),
      )
    ).flat();
    const byContent = new Map<string, ItemVersionRecord[]>();
    for (const version of versions) {
      const list = byContent.get(version.contentId) ?? [];
      list.push(version);
      byContent.set(version.contentId, list);
    }
    if (
      byContent.size > catalogTestOnlyConfig.candidateLimit ||
      versions.length > catalogTestOnlyConfig.candidateLimit * 4
    )
      return { kind: 'invalid', code: 'query_too_broad' };

    const snapshotNow = Date.parse(claims.nowUtc);
    const eligible: Eligible[] = [];
    let reference: Freshness = current === null ? 'unknown' : 'fresh';
    for (const list of byContent.values()) {
      const atSnapshot = versionAt(list, claims.projectionSetRevision);
      const latest = list.find((version) => version.validToRevision === null);
      if (atSnapshot?.state !== 'listed' || atSnapshot.item === null) continue;
      // Tombstone wins over the snapshot: hidden now means not served.
      if (latest !== undefined && latest.state !== 'listed') continue;
      if (atSnapshot.item.typeId === 'activity') {
        if (!this.activityEnabled) continue;
        const pinned = await this.references.readTaxonomyRevision?.(
          atSnapshot.item.referenceRevisions.taxonomyRevisionId ?? '',
        );
        if (!pinned?.ok)
          return { kind: 'unavailable', code: pinned?.code ?? 'taxonomy_revision_unavailable' };
      }
      // Media suppression from the current pointer wins over old snapshots.
      const latestActivity = latest?.item?.typeId === 'activity' ? latest.item : null;
      const rawSnapshotItem =
        latest?.item && latest.sourcePointerRevision > atSnapshot.sourcePointerRevision
          ? {
              ...atSnapshot.item,
              coverMediaId:
                latest.item.coverMediaId === null ||
                latest.publishedRevisionId !== atSnapshot.publishedRevisionId
                  ? null
                  : atSnapshot.item.coverMediaId,
              ...(atSnapshot.item.typeId === 'activity' && latestActivity
                ? {
                    galleryMediaIds: atSnapshot.item.galleryMediaIds.filter((id) =>
                      latestActivity.galleryMediaIds.includes(id),
                    ),
                  }
                : {}),
            }
          : atSnapshot.item;
      const snapshotItem =
        rawSnapshotItem.typeId === 'activity'
          ? await this.#publicActivity(rawSnapshotItem)
          : rawSnapshotItem;
      const evaluation = evaluate(snapshotItem, parsed.query, snapshotNow);
      if (!evaluation.eligible) continue;
      reference = strictest(
        reference,
        referenceFreshness(
          atSnapshot.item.referenceRevisions,
          currents.get(atSnapshot.item.typeId) ?? null,
        ),
      );
      eligible.push({
        version: atSnapshot,
        item: snapshotItem,
        key: evaluation.key,
        occurrence: evaluation.occurrence,
        occurrenceState:
          (evaluation.occurrence === null
            ? 'running'
            : occurrenceState(evaluation.occurrence, snapshotNow)) === 'upcoming'
            ? 'upcoming'
            : 'running',
        remaining: evaluation.remainingOccurrences,
        distance: evaluation.distanceMeters,
        changed:
          latest !== undefined && latest.publishedRevisionId !== atSnapshot.publishedRevisionId,
      });
    }
    eligible.sort((left, right) => compareKeys(left.key, right.key));
    const projection = projectionFreshness(set.lastSourceSyncAtUtc, requestNow);
    return {
      query: parsed.query,
      pageSize: parsed.pageSize,
      token,
      claims,
      set,
      eligible,
      freshness: {
        overall: strictest(projection, reference),
        projection,
        reference,
        availability: 'not_connected',
      },
    };
  }

  #card(entry: Eligible): CatalogCard {
    const item = entry.item;
    if (item.typeId === 'activity')
      return {
        ...item,
        ref: { typeId: 'activity', contentId: item.contentId },
        distanceMeters: entry.distance,
        changedSinceSnapshot: entry.changed,
        projectedAtUtc: entry.version.projectedAtUtc,
      };
    if (entry.occurrence === null) throw new Error('catalog_event_occurrence_missing');
    return {
      ref: { typeId: 'event', contentId: item.contentId },
      publishedRevisionId: item.publishedRevisionId,
      title: item.title,
      shortDescription: item.shortDescription,
      categoryId: item.categoryId,
      subcategoryId: item.subcategoryId,
      format: item.format,
      city: item.city,
      venueName: item.venueName,
      point: item.point,
      notMappable: item.notMappable,
      timezoneId: item.timezoneId,
      occurrence: { ...entry.occurrence, state: entry.occurrenceState },
      remainingOccurrences: entry.remaining,
      price: item.price,
      coverMediaId: item.coverMediaId,
      distanceMeters: entry.distance,
      availability: { status: 'not_connected', reason: availabilityNotConnectedReason },
      changedSinceSnapshot: entry.changed,
      projectedAtUtc: entry.version.projectedAtUtc,
    };
  }
}

/** The version of one object valid at catalog revision `revision`. */
function versionAt(
  versions: readonly ItemVersionRecord[],
  revision: number,
): ItemVersionRecord | undefined {
  return versions.find(
    (version) =>
      version.validFromRevision <= revision &&
      (version.validToRevision === null || version.validToRevision > revision),
  );
}
