import { randomUUID } from 'node:crypto';
import { FieldPath, type Firestore, type Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import {
  assertContentEmulatorContext,
  routePublicationStanding,
} from '../content/infrastructure/firestore_content_repository.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import {
  hashCommand,
  parseCommand,
  parseQuery,
  parseRoute,
  reject,
  routeCollections as cols,
  routeFlag,
  routeLimits,
  routePublicationFlag,
  type ParsedRoute,
  type PrivacyTrim,
  type Result,
} from './route_contract.js';
import { buildRouteDistribution, visibleWaypoints } from './route_distribution.js';
import {
  encodeElevation,
  encodePolyline,
  GeometryError,
  privacyTrimPolicy,
  summarize,
  trimTrack,
} from './route_geometry.js';

type Stored = Record<string, unknown>;

/**
 * J1 owner-only Route storage. Session, flag, receipt and compare-and-set are
 * checked in one transaction that writes the Route and its receipt together.
 * No Catalog, Scenario, Quick Plan, Storage or network effects.
 *
 * J2 / RTE-PUB-01: `distribute` pins the current revision to an immutable
 * `routeRevisions/{routeRevisionId}` snapshot of the privacy-trimmed public
 * distribution (RP-01/02). Content only ever reads it through the revision
 * port; delete reads the Content pointer and submissions without writing them.
 */
export class FirestoreRouteService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }
  private async owner(tx: Transaction, hint: BookingAccessHint): Promise<string | null> {
    try {
      const d = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return d.allowed ? d.userId : null;
    } catch (e) {
      if (e instanceof TypeError) return null;
      throw e;
    }
  }
  private enabled(tx: Transaction, flag: string = routeFlag) {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(flag, tx);
  }
  private ref(owner: string, routeId: string) {
    return this.db.collection(cols.routes).doc(owner + ':' + routeId);
  }

  async command(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    // Validation (size first, then structure and geometry) finishes before any read.
    const parsed = parseCommand(raw);
    if (!parsed.ok) return reject(parsed.code);
    const c = parsed.value;
    const hash = hashCommand(c);
    return this.db.runTransaction(async (tx) => {
      const owner = await this.owner(tx, hint);
      if (!owner) return reject('unauthenticated');
      if (owner !== c.ownerContext) return reject('owner_changed');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      const ref = this.ref(owner, c.routeId);
      const receiptRef = this.db
        .collection(cols.receipts)
        .doc(owner + ':' + sha256Hex(c.idempotencyKey));
      const receipt = (await tx.get(receiptRef)).data();
      const current = (await tx.get(ref)).data();
      if (receipt) {
        if (receipt.hash !== hash) return reject('idempotency_conflict');
        return this.withDistribution(tx, receipt.result as Result);
      }
      // A disabled publication flag records nothing: the command can be retried.
      if (c.commandType === 'distribute' && !(await this.enabled(tx, routePublicationFlag)))
        return reject('feature_disabled');
      const finish = (result: Result) => {
        // Receipts are compact: no geometry, so a tombstone really drops it.
        tx.create(receiptRef, { ownerId: owner, hash, result });
        return result;
      };
      const revision = Number(current?.revision ?? 0);
      if (current?.status === 'deleted')
        return finish(reject('deleted', { serverRevision: revision }));
      const now = this.clock.now().toISOString();
      const done = (status: string, next: number) =>
        finish({
          schemaVersion: 1,
          kind: 'succeeded',
          routeId: c.routeId,
          revision: next,
          status,
        });
      switch (c.commandType) {
        case 'import': {
          if (current) return finish(reject('id_collision', { serverRevision: revision }));
          tx.set(ref, {
            ownerId: owner,
            routeId: c.routeId,
            revision: 1,
            status: 'active',
            createdAtUtc: now,
            updatedAtUtc: now,
            route: c.route!.dto,
            privacyTrim: { policy: privacyTrimPolicy, startMeters: 0, endMeters: 0 },
            provenance: {
              origin: 'gpxImport',
              verification: 'unverified',
              importSourceIds: [c.importSource!.sourceId],
              parserVersion: c.importSource!.parserVersion,
              transformations: c.importSource!.transformations,
            },
            summary: summarize(c.route!.track),
          });
          return done('active', 1);
        }
        case 'save': {
          if (!current && c.expectedRevision !== 0)
            return finish(reject('not_found', { serverRevision: 0 }));
          if (current && c.expectedRevision !== revision)
            return finish(reject('revision_conflict', { serverRevision: revision }));
          const provenance = (current?.provenance as Stored | undefined) ?? {
            origin: 'authored',
            verification: 'unverified',
            importSourceIds: [],
          };
          const verdict = verifySave(c.route!, current, provenance);
          if (verdict) return finish(reject(verdict, { serverRevision: revision }));
          // A save never carries trim: the stored decision is kept as it is.
          tx.set(ref, {
            ownerId: owner,
            routeId: c.routeId,
            revision: revision + 1,
            status: 'active',
            createdAtUtc: (current?.createdAtUtc as string | undefined) ?? now,
            updatedAtUtc: now,
            route: c.route!.dto,
            privacyTrim: (current?.privacyTrim as Stored | undefined) ?? {
              policy: privacyTrimPolicy,
              startMeters: 0,
              endMeters: 0,
            },
            provenance,
            summary: summarize(c.route!.track),
            // J2: distributed snapshots stay listed so a later delete can erase them.
            ...(current === undefined || distributionsOf(current).length === 0
              ? {}
              : { distributions: distributionsOf(current) }),
          });
          return done('active', revision + 1);
        }
        case 'setPrivacyTrim': {
          if (!current) return finish(reject('not_found', { serverRevision: 0 }));
          if (c.expectedRevision !== revision)
            return finish(reject('revision_conflict', { serverRevision: revision }));
          const stored = parseRoute(current.route);
          if (!stored.ok) return finish(reject('invalid_geometry'));
          try {
            trimTrack(stored.value.track, c.privacyTrim!.startMeters, c.privacyTrim!.endMeters);
          } catch (e) {
            if (e instanceof GeometryError) return finish(reject(e.code));
            throw e;
          }
          tx.update(ref, {
            revision: revision + 1,
            updatedAtUtc: now,
            privacyTrim: { policy: privacyTrimPolicy, ...c.privacyTrim! },
          });
          return done('active', revision + 1);
        }
        case 'delete': {
          if (!current) return finish(reject('not_found', { serverRevision: 0 }));
          // RP-11: no implicit cascade; the publication is withdrawn first.
          if (await routePublicationStanding(this.db, tx, c.routeId))
            return finish(reject('publication_active', { serverRevision: revision }));
          // The snapshots lose their geometry; only ids and hashes stay.
          for (const item of distributionsOf(current))
            tx.update(this.db.collection(cols.revisions).doc(item.routeRevisionId), {
              status: 'erased',
              distribution: null,
              erasedAtUtc: now,
            });
          // Delete wins over a concurrent edit; the ID stays terminal (I1 rule).
          tx.set(ref, {
            ownerId: owner,
            routeId: c.routeId,
            revision: revision + 1,
            status: 'deleted',
            createdAtUtc: current.createdAtUtc as string,
            updatedAtUtc: now,
          });
          return done('deleted', revision + 1);
        }
        case 'distribute': {
          if (!current) return finish(reject('not_found', { serverRevision: 0 }));
          if (c.expectedRevision !== revision)
            return finish(reject('revision_conflict', { serverRevision: revision }));
          const known = distributionsOf(current);
          const same = known.find((item) => item.revision === revision);
          if (same) {
            // One snapshot per revision: a new key for the same revision returns it.
            const stored = (
              await tx.get(this.db.collection(cols.revisions).doc(same.routeRevisionId))
            ).data();
            return this.distributed(finish, c.routeId, revision, stored);
          }
          if (known.length >= routeLimits.distributions)
            return finish(reject('distribution_limit', { serverRevision: revision }));
          const stored = parseRoute(current.route);
          if (!stored.ok) return finish(reject('invalid_geometry'));
          const built = buildRouteDistribution(stored.value, current.privacyTrim as PrivacyTrim);
          if (!built.ok) return finish(reject(built.code, { serverRevision: revision }));
          const routeRevisionId = randomUUID();
          const record = {
            routeRevisionId,
            routeId: c.routeId,
            ownerId: owner,
            sourceRevision: revision,
            status: 'active',
            contentHash: built.contentHash,
            distribution: built.distribution,
            createdAtUtc: now,
          };
          tx.create(this.db.collection(cols.revisions).doc(routeRevisionId), record);
          // Not a new J1 revision: owner sync and CAS stay exactly as they were.
          tx.update(ref, { distributions: [...known, { revision, routeRevisionId }] });
          return this.distributed(finish, c.routeId, revision, record);
        }
      }
    });
  }

  /** The receipt holds ids and the hash only; the geometry stays in the snapshot. */
  private distributed(
    finish: (result: Result) => Result,
    routeId: string,
    revision: number,
    stored: Stored | undefined,
  ): Result {
    if (stored?.status !== 'active') return finish(reject('deleted'));
    const compact = {
      schemaVersion: 1,
      kind: 'succeeded',
      routeId,
      revision,
      status: 'active',
      routeRevisionId: stored.routeRevisionId,
      contentHash: stored.contentHash,
    };
    finish(compact);
    return { ...compact, distribution: stored.distribution };
  }

  /** A replayed `distribute` answers with its snapshot again, or `deleted` once erased. */
  private async withDistribution(tx: Transaction, result: Result): Promise<Result> {
    if (typeof result.routeRevisionId !== 'string') return result;
    const stored = (
      await tx.get(this.db.collection(cols.revisions).doc(result.routeRevisionId))
    ).data();
    return stored?.status === 'active'
      ? { ...result, distribution: stored.distribution }
      : reject('deleted');
  }

  async query(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const q = parseQuery(raw);
    if (!q) return reject('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const owner = await this.owner(tx, hint);
      if (!owner) return reject('unauthenticated');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      if (q.queryType === 'list') {
        let query = this.db
          .collection(cols.routes)
          .where('ownerId', '==', owner)
          .orderBy(FieldPath.documentId())
          .limit(routeLimits.listPage + 1);
        if (q.cursor) query = query.startAfter(owner + ':' + q.cursor);
        const docs = (await tx.get(query)).docs;
        const page = docs.slice(0, routeLimits.listPage).map((d) => {
          const v = d.data();
          return {
            routeId: v.routeId as string,
            revision: v.revision as number,
            status: v.status as string,
            updatedAtUtc: v.updatedAtUtc as string,
            ...(v.status === 'active' ? { title: (v.route as Stored).title } : {}),
          };
        });
        const hasMore = docs.length > routeLimits.listPage;
        return {
          schemaVersion: 1,
          kind: 'succeeded',
          ownerId: owner,
          entries: page,
          hasMore,
          cursor: hasMore ? page[page.length - 1]!.routeId : null,
        };
      }
      const v = (await tx.get(this.ref(owner, q.routeId!))).data();
      if (q.queryType === 'get')
        return { schemaVersion: 1, kind: 'succeeded', ownerId: owner, entry: v ? entry(v) : null };
      // Trimmed view: a separate allowlist pinned to one revision and one trim.
      if (!v || v.status !== 'active') return reject('not_found');
      if (v.revision !== q.expectedRevision)
        return reject('revision_conflict', { serverRevision: v.revision });
      const route = parseRoute(v.route);
      if (!route.ok) return reject('invalid_geometry');
      const trim = v.privacyTrim as PrivacyTrim;
      try {
        return {
          schemaVersion: 1,
          kind: 'succeeded',
          view: trimmedView(q.routeId!, v.revision as number, route.value, trim),
        };
      } catch (e) {
        if (e instanceof GeometryError) return reject(e.code);
        throw e;
      }
    });
  }
}

function distributionsOf(v: Stored): { revision: number; routeRevisionId: string }[] {
  return Array.isArray(v.distributions)
    ? (v.distributions as { revision: number; routeRevisionId: string }[])
    : [];
}

/** Owner entry allowlist: no owner, receipt, session or hash data. */
function entry(v: Stored): Stored {
  const base = {
    routeId: v.routeId,
    revision: v.revision,
    status: v.status,
    updatedAtUtc: v.updatedAtUtc,
  };
  if (v.status !== 'active') return base;
  const p = v.provenance as Stored;
  return {
    ...base,
    route: v.route,
    privacyTrim: v.privacyTrim,
    provenance: {
      origin: p.origin,
      verification: p.verification,
      ...(p.parserVersion ? { parserVersion: p.parserVersion } : {}),
      ...(p.transformations ? { transformations: p.transformations } : {}),
    },
    summary: v.summary,
  };
}

/**
 * `importedGpx` only for segments that keep their stored ID and kind, or that
 * descend from an import source registered by this Route's import command.
 * A stored segment ID never changes its source kind or parent.
 */
function verifySave(route: ParsedRoute, current: Stored | undefined, provenance: Stored) {
  const registered = (provenance.importSourceIds as string[] | undefined) ?? [];
  const stored = new Map<string, Stored>();
  const storedRoute = current ? parseRoute(current.route) : null;
  if (storedRoute?.ok)
    for (const raw of storedRoute.value.dto.segments as Stored[])
      stored.set(raw.segmentId as string, raw);
  for (const s of route.segments) {
    const before = stored.get(s.segmentId);
    if (
      before &&
      (before.sourceKind !== s.sourceKind || before.parentSegmentId !== s.parentSegmentId)
    )
      return 'provenance_unverified';
    if (s.sourceKind === 'importedGpx' && !before && !registered.includes(s.sourceId))
      return 'provenance_unverified';
  }
  return null;
}

function trimmedView(routeId: string, revision: number, route: ParsedRoute, trim: PrivacyTrim) {
  const result = trimTrack(route.track, trim.startMeters, trim.endMeters);
  // Waypoints next to a hidden endpoint would reveal it: they are removed.
  const waypoints = visibleWaypoints(route, trim).map((w) => ({
    latE7: w.latE7,
    lonE7: w.lonE7,
    eleDm: w.eleDm,
    typeId: w.typeId,
    title: w.title,
  }));
  const body = {
    routeId,
    revision,
    policy: privacyTrimPolicy,
    startMeters: trim.startMeters,
    endMeters: trim.endMeters,
    segments: result.track.map((s) => ({
      polyline: encodePolyline(s.points),
      elevation: encodeElevation(s.points),
      connected: s.connected,
    })),
    waypoints,
    summary: summarize(result.track),
    warnings: { reenteredStart: result.reenteredStart, reenteredEnd: result.reenteredEnd },
  };
  return { ...body, variantHash: sha256Hex(canonicalJson(body)) };
}
