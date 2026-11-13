import { randomUUID } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FirestoreBookingAccessAuthority } from '../../booking/firestore_booking_access_authority.js';
import type { BookingAccessHint } from '../../shared/booking_access_authority.js';
import type { ServerClock } from '../../shared/server_clock.js';
import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import {
  assertContentEmulatorContext,
  scenarioPublicationStanding,
} from '../content/infrastructure/firestore_content_repository.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { FirestoreFeatureFlagGate } from '../../platform/config/firestore_feature_flag_gate.js';
import { exact, record } from '../library/library_contract.js';
import {
  quickPlanCollections,
  quickPlanFlag,
  rejectScenario as reject,
  type Result,
} from './quick_plan_contract.js';
import { scenarioFlagIds } from '../../shared/feature_flags.js';
import { relationEffects } from '../../shared/safety_visibility.js';
import { safetyRestricted } from '../../shared/safety_instruction.js';
import { mapScenarioDistribution, type DistributionResult } from './scenario_distribution.js';
import type { PrivacyPlannedEffect } from '../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import {
  isShareToken,
  newShareToken,
  scenarioPublicationCollections,
  scenarioStopLookup,
  shareHashMatches,
  shareTokenHash,
  shareTtlDays,
  type ScenarioRevisionRecord,
  type ScenarioShareRecord,
  type ScenarioStopsPort,
} from './scenario_publication.js';

interface Child {
  id: string;
}
interface Day extends Child {
  itemIds: string[];
}
interface Item extends Child {
  durationMinutes: number | null;
  startLocationId: string;
  endLocationId: string;
  dayId: string;
}
interface Location extends Child {
  title: string;
  point: { latitude: number; longitude: number };
  disclosure: string;
}
interface ScenarioDto {
  title: string;
  scenario: {
    revision: number;
    days: Day[];
    items: Item[];
    locations: Location[];
    legs: Child[];
    origin: Record<string, unknown> | null;
    displayCurrencyCode: string;
  };
}
interface Plan {
  scenarioId: string;
  ownerId: string;
  status: string;
  revision: number;
  draft: ScenarioDto | null;
  updatedAtUtc: string;
  /** SCN-PUB-01: the one active unlisted share, if any. */
  activeShare?: { shareId: string; expiresAtUtc: string } | null;
}
interface Member {
  actorId: string;
  scenarioId: string;
  status: string;
  role?: string;
  generation: number;
  revision: number;
}
interface Invite {
  scenarioId: string;
  ownerId: string;
  recipientId: string;
  status: string;
  expiresAtUtc: string;
  generation: number;
  role: string;
}
interface Receipt {
  hash: string;
  binding: string;
  result: Result;
}
interface QuickStep {
  id: string;
  title: string;
  latitude: number;
  longitude: number;
  durationMinutes: number;
}
interface QuickSource {
  ownerId: string;
  status: string;
  revision: number;
  plan: { id: string; currencyCode: string; steps: QuickStep[] };
}

export const scenarioFlag = scenarioFlagIds.sync;
export const scenarioCollections = Object.freeze({
  plans: 'scenarios',
  members: 'scenarioMembers',
  invites: 'scenarioInvites',
  receipts: 'scenarioCommandReceipts',
  ...scenarioPublicationCollections,
});
const publicationCommands = ['distribute', 'share', 'unshare'];
const ulid = (v: unknown): v is string =>
  typeof v === 'string' && /^[0-7][0-9A-HJKMNP-TV-Z]{25}$/.test(v);
const revision = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const fields = [
  'schemaVersion',
  'requestId',
  'actorContext',
  'idempotencyKey',
  'commandType',
  'scenarioId',
  'expectedRevision',
  'generation',
  'draft',
  'recipientId',
  'role',
  'inviteId',
  'expiresAtUtc',
  'sourceId',
  'sourceRevision',
  'sourceHash',
  'selectedStopIds',
  'replayHash',
  'ttlDays',
];

/** Bounded canonical Scenario DTO. No Create envelope, publisher, Route or grants. */
export function validScenarioDraft(value: unknown): value is ScenarioDto {
  const d = record(value),
    s = record(d?.scenario);
  if (
    !d ||
    !exact(d, ['title', 'scenario']) ||
    typeof d.title !== 'string' ||
    d.title.length > 256 ||
    !s ||
    !exact(s, [
      'schemaVersion',
      'updatesEnabled',
      'revision',
      'format',
      'dateMode',
      'defaultTimezoneId',
      'displayCurrencyCode',
      'party',
      'constraints',
      'days',
      'locations',
      'items',
      'unscheduledItemIds',
      'legs',
      'totals',
      'origin',
      'capabilities',
    ]) ||
    s.schemaVersion !== 2 ||
    !revision(s.revision) ||
    !['city', 'day', 'weekend', 'trip'].includes(String(s.format)) ||
    !['template', 'dated'].includes(String(s.dateMode)) ||
    typeof s.defaultTimezoneId !== 'string' ||
    typeof s.displayCurrencyCode !== 'string' ||
    !/^[A-Z]{3}$/.test(s.displayCurrencyCode) ||
    !Array.isArray(s.days) ||
    s.days.length > 30 ||
    !Array.isArray(s.items) ||
    s.items.length > 250 ||
    !Array.isArray(s.locations) ||
    s.locations.length > 500 ||
    !Array.isArray(s.legs) ||
    s.legs.length > 500 ||
    !Array.isArray(s.unscheduledItemIds) ||
    !record(s.party) ||
    !record(s.constraints) ||
    !record(s.totals) ||
    !record(s.capabilities) ||
    record(s.capabilities)!.publicPublish !== false ||
    record(s.capabilities)!.unlistedShare !== false ||
    record(s.capabilities)!.liveLogistics !== false ||
    // Keep envelope headroom below the existing 256 KiB callable response cap.
    Buffer.byteLength(JSON.stringify(d)) > 240 * 1024
  )
    return false;
  const ids = new Set<string>();
  for (const group of [s.days, s.items, s.locations, s.legs])
    for (const raw of group) {
      const child = record(raw);
      if (!child || !isEntityId(child.id) || ids.has(child.id)) return false;
      ids.add(child.id);
    }
  const dayIds = new Set(s.days.map((raw) => record(raw)!.id));
  const itemIds = new Set(s.items.map((raw) => record(raw)!.id));
  const locationIds = new Set(s.locations.map((raw) => record(raw)!.id));
  const placed = new Set<unknown>();
  for (const raw of s.days) {
    const day = record(raw)!;
    if (!Array.isArray(day.itemIds)) return false;
    for (const id of day.itemIds) {
      if (!itemIds.has(id) || placed.has(id)) return false;
      const item = record(s.items.find((raw) => record(raw)!.id === id));
      if (item?.dayId !== day.id) return false;
      placed.add(id);
    }
  }
  for (const id of s.unscheduledItemIds) {
    if (!itemIds.has(id) || placed.has(id)) return false;
    const item = record(s.items.find((raw) => record(raw)!.id === id));
    if (item?.dayId !== null) return false;
    placed.add(id);
  }
  if (placed.size !== itemIds.size) return false;
  for (const raw of s.locations) {
    const location = record(raw)!,
      point = record(location.point);
    if (
      typeof location.title !== 'string' ||
      location.title.length > 256 ||
      !point ||
      typeof point.latitude !== 'number' ||
      !Number.isFinite(point.latitude) ||
      Math.abs(point.latitude) > 90 ||
      typeof point.longitude !== 'number' ||
      !Number.isFinite(point.longitude) ||
      Math.abs(point.longitude) > 180 ||
      !['private', 'approximate', 'public'].includes(String(location.disclosure))
    )
      return false;
  }
  for (const raw of s.items) {
    const item = record(raw)!;
    if (item.dayId !== null && !dayIds.has(item.dayId)) return false;
    for (const ref of [item.startLocationId, item.endLocationId])
      if (ref !== null && !locationIds.has(ref)) return false;
    if (
      item.durationMinutes !== null &&
      (!revision(item.durationMinutes) || item.durationMinutes === 0)
    )
      return false;
  }
  for (const raw of s.legs) {
    const leg = record(raw)!;
    if (
      !dayIds.has(leg.dayId) ||
      !itemIds.has(leg.fromItemId) ||
      !itemIds.has(leg.toItemId) ||
      !locationIds.has(leg.fromLocationId) ||
      !locationIds.has(leg.toLocationId)
    )
      return false;
  }
  return true;
}

/** Extends canonical Create save with one transactional owner creation writer. */
export class FirestoreScenarioService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
    /** SCN-PUB-01: Catalog-owned stop status; without it catalog stops fail closed. */
    private readonly stops?: ScenarioStopsPort,
  ) {
    assertContentEmulatorContext(db);
  }
  private flag(tx: Transaction, id: string) {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(id, tx);
  }
  private async actor(tx: Transaction, hint: BookingAccessHint) {
    try {
      const a = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return a.allowed ? a.userId : null;
    } catch (e) {
      if (e instanceof TypeError) return null;
      throw e;
    }
  }
  private enabled(tx: Transaction) {
    return new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(scenarioFlag, tx);
  }
  private memberRef(id: string, actor: string) {
    return this.db.collection(scenarioCollections.members).doc(id + ':' + actor);
  }
  private allowed(p: Plan | undefined, m: Member | undefined, actor: string) {
    return p?.status === 'active' && (p.ownerId === actor || m?.status === 'active');
  }
  private entry(p: Plan, m: Member | undefined, actor: string) {
    const draft =
      p.ownerId === actor || p.draft === null
        ? p.draft
        : { ...p.draft, scenario: { ...p.draft.scenario, origin: null } };
    return {
      scenarioId: p.scenarioId,
      revision: p.revision,
      status: p.status,
      generation: p.ownerId === actor ? 0 : m?.generation,
      role: p.ownerId === actor ? 'owner' : m?.role,
      updatedAtUtc: p.updatedAtUtc,
      ...(p.status === 'active' ? { draft } : {}),
    };
  }
  async query(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const r = record(raw);
    if (
      !r ||
      !exact(r, [
        'schemaVersion',
        'requestId',
        'scenarioId',
        'recipientId',
        'cursor',
        'shareToken',
      ]) ||
      r.schemaVersion !== 1 ||
      !isEntityId(r.requestId) ||
      (r.scenarioId !== undefined && !ulid(r.scenarioId)) ||
      (r.recipientId !== undefined && (!isEntityId(r.recipientId) || r.scenarioId === undefined))
    )
      return reject('request_invalid');
    if (r.shareToken !== undefined)
      return r.scenarioId === undefined && r.recipientId === undefined && r.cursor === undefined
        ? this.resolveShare(hint, r.shareToken)
        : reject('request_invalid');
    const cursor = record(r.cursor);
    if (
      r.cursor !== undefined &&
      (r.scenarioId !== undefined ||
        !cursor ||
        !exact(cursor, ['ownedAfter', 'sharedAfter', 'ownedDone', 'sharedDone']) ||
        typeof cursor.ownedDone !== 'boolean' ||
        typeof cursor.sharedDone !== 'boolean' ||
        [cursor.ownedAfter, cursor.sharedAfter].some(
          (v) =>
            v !== null &&
            (typeof v !== 'string' || v.length < 1 || v.length > 160 || v.includes('/')),
        ))
    )
      return reject('request_invalid');
    return this.db.runTransaction(async (tx) => {
      const actor = await this.actor(tx, hint);
      if (!actor) return reject('unauthenticated');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      if (r.scenarioId === undefined) {
        let ownQuery = this.db
          .collection(scenarioCollections.plans)
          .where('ownerId', '==', actor)
          .orderBy('__name__')
          .limit(101);
        let sharedQuery = this.db
          .collection(scenarioCollections.members)
          .where('actorId', '==', actor)
          .orderBy('__name__')
          .limit(101);
        if (typeof cursor?.ownedAfter === 'string')
          ownQuery = ownQuery.startAfter(cursor.ownedAfter);
        if (typeof cursor?.sharedAfter === 'string')
          sharedQuery = sharedQuery.startAfter(cursor.sharedAfter);
        const owned = cursor?.ownedDone ? null : await tx.get(ownQuery);
        const memberships = cursor?.sharedDone ? null : await tx.get(sharedQuery);
        const ownDocs = owned?.docs.slice(0, 100) ?? [],
          sharedDocs = memberships?.docs.slice(0, 100) ?? [];
        const entries: Result[] = [];
        for (const doc of ownDocs)
          if ((doc.data() as Plan).status === 'active')
            entries.push(this.summary(doc.data() as Plan, undefined, actor));
        for (const doc of sharedDocs) {
          const m = doc.data() as Member;
          if (m.status !== 'active') continue;
          const p = (
            await tx.get(this.db.collection(scenarioCollections.plans).doc(m.scenarioId))
          ).data() as Plan | undefined;
          if (this.allowed(p, m, actor) && p!.ownerId !== actor)
            entries.push(this.summary(p!, m, actor));
        }
        const ownedDone = !owned || owned.size <= 100,
          sharedDone = !memberships || memberships.size <= 100;
        return {
          schemaVersion: 1,
          kind: 'succeeded',
          entries,
          hasMore: !ownedDone || !sharedDone,
          cursor:
            ownedDone && sharedDone
              ? null
              : {
                  ownedDone,
                  sharedDone,
                  ownedAfter: ownDocs.at(-1)?.id ?? cursor?.ownedAfter ?? null,
                  sharedAfter: sharedDocs.at(-1)?.id ?? cursor?.sharedAfter ?? null,
                },
        };
      }
      const p = (
        await tx.get(this.db.collection(scenarioCollections.plans).doc(r.scenarioId as string))
      ).data() as Plan | undefined;
      const m = (await tx.get(this.memberRef(r.scenarioId as string, actor))).data() as
        Member | undefined;
      if (r.recipientId !== undefined) {
        if (p?.status !== 'active' || p.ownerId !== actor) return reject('not_found_or_forbidden');
        const target = (
          await tx.get(this.memberRef(r.scenarioId as string, r.recipientId as string))
        ).data() as Member | undefined;
        return {
          schemaVersion: 1,
          kind: 'succeeded',
          membership: target
            ? { status: target.status, role: target.role ?? null, revision: target.revision }
            : null,
        };
      }
      if (!this.allowed(p, m, actor)) return reject('not_found_or_forbidden');
      return { schemaVersion: 1, kind: 'succeeded', entry: this.entry(p!, m, actor) };
    });
  }
  private summary(p: Plan, m: Member | undefined, actor: string) {
    const { draft, ...entry } = this.entry(p, m, actor);
    return { ...entry, title: draft?.title ?? '' };
  }
  async command(hint: BookingAccessHint, raw: unknown): Promise<Result> {
    const c = record(raw);
    if (
      !c ||
      !exact(c, fields) ||
      c.schemaVersion !== 1 ||
      !isEntityId(c.requestId) ||
      !isEntityId(c.actorContext) ||
      !isIdempotencyKey(c.idempotencyKey) ||
      !ulid(c.scenarioId) ||
      !revision(c.expectedRevision) ||
      !revision(c.generation) ||
      ![
        'save',
        'delete',
        'invite',
        'accept',
        'cancel',
        'revoke',
        'role',
        'expand',
        ...publicationCommands,
      ].includes(String(c.commandType))
    )
      return reject('request_invalid');
    const type = String(c.commandType),
      id = c.scenarioId;
    const optional: Record<string, string[]> = {
      save: ['draft'],
      delete: [],
      invite: ['recipientId', 'role', 'inviteId', 'expiresAtUtc'],
      accept: ['inviteId'],
      cancel: ['recipientId', 'inviteId'],
      revoke: ['recipientId'],
      role: ['recipientId', 'role'],
      expand: [
        'draft',
        'sourceId',
        'sourceRevision',
        'sourceHash',
        'selectedStopIds',
        'replayHash',
      ],
      distribute: [],
      share: ['ttlDays'],
      unshare: [],
    };
    if (
      !exact(c, [
        'schemaVersion',
        'requestId',
        'actorContext',
        'idempotencyKey',
        'commandType',
        'scenarioId',
        'expectedRevision',
        'generation',
        ...optional[type]!,
      ])
    )
      return reject('request_invalid');
    const compactReplay = type === 'expand' && c.replayHash !== undefined;
    if (
      compactReplay &&
      (typeof c.replayHash !== 'string' ||
        !/^[a-f0-9]{64}$/.test(c.replayHash) ||
        c.draft !== undefined)
    )
      return reject('request_invalid');
    if ((type === 'save' || (type === 'expand' && !compactReplay)) && !validScenarioDraft(c.draft))
      return reject('request_invalid');
    if (['invite', 'cancel', 'revoke', 'role'].includes(type) && !isEntityId(c.recipientId))
      return reject('request_invalid');
    if (['invite', 'role'].includes(type) && !['editor', 'viewer'].includes(String(c.role)))
      return reject('request_invalid');
    if (['invite', 'accept', 'cancel'].includes(type) && !isEntityId(c.inviteId))
      return reject('request_invalid');
    if (
      type === 'expand' &&
      (!isEntityId(c.sourceId) ||
        !revision(c.sourceRevision) ||
        typeof c.sourceHash !== 'string' ||
        !Array.isArray(c.selectedStopIds) ||
        c.selectedStopIds.length > 32 ||
        new Set(c.selectedStopIds).size !== c.selectedStopIds.length ||
        !c.selectedStopIds.every(isEntityId))
    )
      return reject('request_invalid');
    if (
      type === 'share' &&
      c.ttlDays !== undefined &&
      (!Number.isInteger(c.ttlDays) ||
        Number(c.ttlDays) < 1 ||
        Number(c.ttlDays) > shareTtlDays.max)
    )
      return reject('request_invalid');
    // SCN-PUB-01: the distribution is mapped and its stops resolved before any
    // transaction; the transaction then requires exactly the revision mapped.
    const prepared =
      type === 'distribute' || type === 'share'
        ? await this.prepareDistribution(id, type === 'share' ? 'unlisted' : 'public')
        : undefined;
    return this.db.runTransaction(async (tx) => {
      const actor = await this.actor(tx, hint);
      if (!actor) return reject('unauthenticated');
      if (actor !== c.actorContext) return reject('actor_changed');
      if (!(await this.enabled(tx))) return reject('feature_disabled');
      const planRef = this.db.collection(scenarioCollections.plans).doc(id);
      const p = (await tx.get(planRef)).data() as Plan | undefined;
      const m = (await tx.get(this.memberRef(id, actor))).data() as Member | undefined;
      const receiptRef = this.db
        .collection(scenarioCollections.receipts)
        .doc(actor + ':' + sha256Hex(String(c.idempotencyKey)));
      const receipt = (await tx.get(receiptRef)).data() as Receipt | undefined;
      const hash = sha256Hex(
        canonicalJson(Object.fromEntries(Object.entries(c).filter(([k]) => k !== 'requestId'))),
      );
      const binding = sha256Hex(
        canonicalJson(
          Object.fromEntries(
            Object.entries(c).filter(([k]) => !['requestId', 'draft', 'replayHash'].includes(k)),
          ),
        ),
      );
      const owner = p?.ownerId === actor;
      const creating =
        !p &&
        (type === 'save' || type === 'expand') &&
        c.expectedRevision === 0 &&
        c.generation === 0;
      if (!creating && type !== 'accept' && !this.allowed(p, m, actor))
        return reject('not_found_or_forbidden');
      if (!creating && type !== 'accept' && c.generation !== (owner ? 0 : m?.generation))
        return reject('access_revoked');
      let source: QuickSource | undefined;
      if (type === 'expand') {
        if (
          !(await new FirestoreFeatureFlagGate(this.db, 'local', 'LV').isEnabled(quickPlanFlag, tx))
        )
          return reject('feature_disabled');
        source = (
          await tx.get(
            this.db.collection(quickPlanCollections.plans).doc(actor + ':' + String(c.sourceId)),
          )
        ).data() as QuickSource | undefined;
        if (source?.ownerId !== actor || source.status !== 'active')
          return reject('source_unavailable');
      }
      let invite: Invite | undefined;
      let target: Member | undefined;
      const recipient = (c.recipientId as string | undefined) ?? actor;
      if (['invite', 'accept', 'cancel', 'revoke', 'role'].includes(type))
        target = (await tx.get(this.memberRef(id, recipient))).data() as Member | undefined;
      if (['invite', 'accept', 'cancel'].includes(type))
        invite = (
          await tx.get(this.db.collection(scenarioCollections.invites).doc(String(c.inviteId)))
        ).data() as Invite | undefined;
      if (type === 'accept') {
        if (
          !p ||
          p.status !== 'active' ||
          !invite ||
          invite.scenarioId !== id ||
          invite.recipientId !== actor ||
          invite.ownerId !== p.ownerId ||
          !['pending', 'accepted'].includes(invite.status) ||
          (invite.status === 'pending' && invite.expiresAtUtc <= this.clock.now().toISOString()) ||
          invite.generation !== (target?.generation ?? 0) ||
          (invite.status === 'accepted' && target?.status !== 'active')
        )
          return reject('not_found_or_forbidden');
      }
      // Replays are disclosed only after current authority, generation and invite checks.
      if (receipt)
        return (
          compactReplay
            ? receipt.hash === c.replayHash && receipt.binding === binding
            : receipt.hash === hash
        )
          ? receipt.result
          : reject('idempotency_conflict');
      // An acknowledged compact intent can only recover its receipt, never create.
      if (compactReplay) return reject('intent_not_found');
      const finish = (result: Result) => {
        tx.create(receiptRef, { actorId: actor, hash, binding, result });
        return result;
      };
      if (publicationCommands.includes(type)) {
        // Editing a shared Scenario never grants publication (SP-01).
        if (!owner) return reject('not_found_or_forbidden');
        return this.publicationCommand(
          tx,
          type,
          c,
          p,
          planRef,
          actor,
          prepared,
          (result, stored) => {
            tx.create(receiptRef, { actorId: actor, hash, binding, result: stored ?? result });
            return result;
          },
        );
      }
      if (['invite', 'cancel', 'revoke', 'role', 'delete'].includes(type) && !owner)
        return reject('not_found_or_forbidden');
      if (type === 'save' && !creating && !owner && m?.role !== 'editor')
        return reject('not_found_or_forbidden');
      if (type === 'save' || type === 'expand') {
        if (!creating && type === 'expand') return reject('id_collision');
        if (Number(p?.revision ?? 0) !== c.expectedRevision) return reject('revision_conflict');
        if (type === 'expand') {
          if (
            source!.revision !== c.sourceRevision ||
            sha256Hex(canonicalJson(source!.plan)) !== c.sourceHash
          )
            return reject('source_revision_conflict');
          if (!this.conversionMatches(c, source!.plan)) return reject('conversion_invalid');
        }
        const proposed = c.draft as ScenarioDto;
        const draft = p?.draft
          ? { ...proposed, scenario: { ...proposed.scenario, origin: p.draft.scenario.origin } }
          : proposed;
        if (draft.scenario.revision !== Number(c.expectedRevision) + 1)
          return reject('revision_conflict');
        // Both ordinary Create saves and Expand invoke this single owner creation writer.
        const next = this.saveInTransaction(tx, planRef, p, actor, id, draft);
        return finish({ schemaVersion: 1, kind: 'succeeded', entry: this.entry(next, m, actor) });
      }
      if (type === 'delete') {
        if (p!.revision !== c.expectedRevision) return reject('revision_conflict');
        // SP-11: no implicit cascade; withdraw the publication and revoke the share first.
        if (
          (await this.shareStanding(tx, p!)) ||
          (await scenarioPublicationStanding(this.db, tx, id))
        )
          return reject('publication_active');
        this.writeDeleted(tx, planRef, p!);
        return finish({ schemaVersion: 1, kind: 'succeeded' });
      }
      if (type === 'accept') {
        if (invite!.status === 'accepted')
          return finish({ schemaVersion: 1, kind: 'succeeded', generation: target!.generation });
        tx.set(this.memberRef(id, actor), {
          actorId: actor,
          scenarioId: id,
          status: 'active',
          role: invite!.role,
          generation: invite!.generation,
          revision: (target?.revision ?? 0) + 1,
        });
        tx.update(this.db.collection(scenarioCollections.invites).doc(String(c.inviteId)), {
          status: 'accepted',
        });
        return finish({ schemaVersion: 1, kind: 'succeeded', generation: invite!.generation });
      }
      if (recipient === p!.ownerId) return reject('request_invalid');
      if ((target?.revision ?? 0) !== c.expectedRevision) return reject('membership_conflict');
      if (type === 'invite') {
        const account = (
          await tx.get(this.db.collection('identityAccounts').doc(recipient))
        ).data();
        if (account?.status !== 'active' || invite || target?.status === 'active')
          return reject('recipient_unavailable');
        if (
          typeof c.expiresAtUtc !== 'string' ||
          !Number.isFinite(Date.parse(c.expiresAtUtc)) ||
          Date.parse(c.expiresAtUtc) <= this.clock.now().getTime() ||
          Date.parse(c.expiresAtUtc) > this.clock.now().getTime() + 7 * 86400000
        )
          return reject('request_invalid');
        const generation = (target?.generation ?? 0) + 1;
        tx.set(this.memberRef(id, recipient), {
          actorId: recipient,
          scenarioId: id,
          status: 'pending',
          generation,
          revision: (target?.revision ?? 0) + 1,
        });
        tx.create(this.db.collection(scenarioCollections.invites).doc(String(c.inviteId)), {
          scenarioId: id,
          ownerId: actor,
          recipientId: recipient,
          role: c.role,
          status: 'pending',
          generation,
          expiresAtUtc: new Date(c.expiresAtUtc).toISOString(),
        });
        return finish({
          schemaVersion: 1,
          kind: 'succeeded',
          membershipRevision: (target?.revision ?? 0) + 1,
        });
      }
      if (
        type === 'cancel' &&
        (!invite ||
          invite.scenarioId !== id ||
          invite.recipientId !== recipient ||
          invite.status !== 'pending')
      )
        return reject('not_found_or_forbidden');
      if (type === 'role' && target?.status !== 'active') return reject('not_found_or_forbidden');
      tx.set(this.memberRef(id, recipient), {
        actorId: recipient,
        scenarioId: id,
        status: type === 'role' ? 'active' : 'revoked',
        ...(type === 'role' ? { role: c.role } : {}),
        generation: (target?.generation ?? 0) + 1,
        revision: (target?.revision ?? 0) + 1,
      });
      if (type === 'cancel')
        tx.update(this.db.collection(scenarioCollections.invites).doc(String(c.inviteId)), {
          status: 'cancelled',
        });
      return finish({
        schemaVersion: 1,
        kind: 'succeeded',
        membershipRevision: (target?.revision ?? 0) + 1,
      });
    });
  }
  protected saveInTransaction(
    tx: Transaction,
    ref: FirebaseFirestore.DocumentReference,
    current: Plan | undefined,
    actor: string,
    id: string,
    draft: ScenarioDto,
  ): Plan {
    const next = {
      scenarioId: id,
      ownerId: current?.ownerId ?? actor,
      status: 'active',
      revision: (current?.revision ?? 0) + 1,
      updatedAtUtc: this.clock.now().toISOString(),
      draft,
      // A share points at an immutable revision; saving the draft keeps it as it is.
      ...(current?.activeShare ? { activeShare: current.activeShare } : {}),
    };
    tx.set(ref, next);
    return next;
  }
  private async prepareDistribution(
    id: string,
    mode: 'public' | 'unlisted',
  ): Promise<{ revision: number; draftHash: string; result: DistributionResult } | undefined> {
    const p = (await this.db.collection(scenarioCollections.plans).doc(id).get()).data() as
      Plan | undefined;
    if (p?.status !== 'active' || p.draft === null) return undefined;
    const lookup = await scenarioStopLookup(p.draft, this.stops);
    return {
      revision: p.revision,
      draftHash: sha256Hex(canonicalJson(p.draft)),
      result: mapScenarioDistribution(p.draft, mode, lookup),
    };
  }
  private writeDeleted(tx: Transaction, ref: FirebaseFirestore.DocumentReference, p: Plan): void {
    tx.set(ref, { ...p, status: 'deleted', draft: null, revision: p.revision + 1 });
  }
  /**
   * L1 erasure (PB-00): the owner's own delete, with the same guards. A Scenario
   * with an active publication or share stays (PB-02, SP-11 has no cascade); one
   * with an active or pending member is shared and stays (PB-12).
   */
  async privacyErasure(
    tx: Transaction,
    ref: FirebaseFirestore.DocumentReference,
    data: Record<string, unknown>,
  ): Promise<PrivacyPlannedEffect> {
    const p = data as unknown as Plan;
    if (p.status === 'deleted') return { outcome: 'unchanged' };
    if (
      (await this.shareStanding(tx, p)) ||
      (await scenarioPublicationStanding(this.db, tx, ref.id))
    )
      return { outcome: { blocked: 'PB-02' } };
    const members = await tx.get(
      this.db.collection(scenarioCollections.members).where('scenarioId', '==', ref.id).limit(101),
    );
    if (members.docs.some((member) => ['active', 'pending'].includes(String(member.get('status')))))
      return { outcome: { blocked: 'PB-12' } };
    return { outcome: 'erased', write: () => this.writeDeleted(tx, ref, p) };
  }
  private async shareStanding(tx: Transaction, p: Plan): Promise<boolean> {
    if (!p.activeShare) return false;
    const share = (
      await tx.get(this.db.collection(scenarioCollections.shares).doc(p.activeShare.shareId))
    ).data() as ScenarioShareRecord | undefined;
    return (
      share?.status === 'active' && Date.parse(share.expiresAtUtc) > this.clock.now().getTime()
    );
  }
  /** SCN-PUB-01 owner commands: immutable public revision, unlisted share, revocation. */
  private async publicationCommand(
    tx: Transaction,
    type: string,
    c: Record<string, unknown>,
    p: Plan,
    planRef: FirebaseFirestore.DocumentReference,
    actor: string,
    prepared: Awaited<ReturnType<FirestoreScenarioService['prepareDistribution']>>,
    finish: (result: Result, stored?: Result) => Result,
  ): Promise<Result> {
    const now = this.clock.now();
    const shares = this.db.collection(scenarioCollections.shares);
    if (type === 'unshare') {
      // Reducing access is never gated by the share flag.
      if (!p.activeShare) return finish({ schemaVersion: 1, kind: 'succeeded', revoked: false });
      const ref = shares.doc(p.activeShare.shareId);
      const share = (await tx.get(ref)).data() as ScenarioShareRecord | undefined;
      if (share?.status === 'active') tx.update(ref, { status: 'revoked' });
      tx.update(planRef, { activeShare: null });
      return finish({ schemaVersion: 1, kind: 'succeeded', revoked: true });
    }
    const flag = type === 'share' ? scenarioFlagIds.share : scenarioFlagIds.publication;
    if (!(await this.flag(tx, flag))) return reject('feature_disabled');
    // Concurrent edits: the mapped revision must be exactly the current one.
    if (
      prepared === undefined ||
      p.revision !== c.expectedRevision ||
      prepared.revision !== p.revision ||
      prepared.draftHash !== sha256Hex(canonicalJson(p.draft))
    )
      return reject('revision_conflict');
    if (!prepared.result.ok)
      return reject('distribution_invalid', { issues: prepared.result.issues });
    const { distribution, contentHash } = prepared.result;
    const previous =
      type === 'share' && p.activeShare
        ? ((await tx.get(shares.doc(p.activeShare.shareId))).data() as
            ScenarioShareRecord | undefined)
        : undefined;
    const revisionId = randomUUID();
    const revision: ScenarioRevisionRecord = {
      scenarioId: p.scenarioId,
      ownerId: actor,
      purpose: type === 'share' ? 'unlisted' : 'public',
      sourceRevision: p.revision,
      contentHash,
      distribution,
      createdAtUtc: now.toISOString(),
    };
    tx.create(this.db.collection(scenarioCollections.revisions).doc(revisionId), revision);
    if (type === 'distribute')
      return finish({
        schemaVersion: 1,
        kind: 'succeeded',
        scenarioRevisionId: revisionId,
        contentHash,
        distribution,
      });
    const days = c.ttlDays === undefined ? shareTtlDays.default : Number(c.ttlDays);
    const expiresAtUtc = new Date(now.getTime() + days * 86400000).toISOString();
    const token = newShareToken();
    const shareId = shareTokenHash(token);
    // One active link per Scenario: a new one rotates the previous immediately.
    if (previous?.status === 'active')
      tx.update(shares.doc(p.activeShare!.shareId), { status: 'rotated' });
    const share: ScenarioShareRecord = {
      scenarioId: p.scenarioId,
      ownerId: actor,
      revisionId,
      status: 'active',
      expiresAtUtc,
      restriction: null,
      createdAtUtc: now.toISOString(),
    };
    tx.create(shares.doc(shareId), share);
    tx.update(planRef, { activeShare: { shareId, expiresAtUtc } });
    const result = {
      schemaVersion: 1,
      kind: 'succeeded',
      scenarioRevisionId: revisionId,
      expiresAtUtc,
    };
    // The receipt never holds the token: a lost answer is recovered by rotation.
    return finish({ ...result, token }, { ...result, tokenUnavailable: true });
  }
  /** SP-03: an authenticated reader with the current token sees the share snapshot only. */
  private resolveShare(hint: BookingAccessHint, token: unknown): Promise<Result> {
    if (!isShareToken(token)) return Promise.resolve(reject('not_found'));
    const shareId = shareTokenHash(token);
    return this.db.runTransaction(async (tx) => {
      const actor = await this.actor(tx, hint);
      if (!actor) return reject('unauthenticated');
      if (!(await this.flag(tx, scenarioFlagIds.share))) return reject('feature_disabled');
      const share = (
        await tx.get(this.db.collection(scenarioCollections.shares).doc(shareId))
      ).data() as ScenarioShareRecord | undefined;
      if (!share || !shareHashMatches(shareId, token)) return reject('not_found');
      const p = (
        await tx.get(this.db.collection(scenarioCollections.plans).doc(share.scenarioId))
      ).data() as Plan | undefined;
      if (
        share.status !== 'active' ||
        share.restriction !== null ||
        p?.status !== 'active' ||
        p.ownerId !== share.ownerId ||
        p.activeShare?.shareId !== shareId
      )
        return reject('not_found');
      if (Date.parse(share.expiresAtUtc) <= this.clock.now().getTime())
        return reject('token_expired');
      const revision = (
        await tx.get(this.db.collection(scenarioCollections.revisions).doc(share.revisionId))
      ).data() as ScenarioRevisionRecord | undefined;
      if (revision?.purpose !== 'unlisted' || revision.scenarioId !== share.scenarioId)
        return reject('not_found');
      // K2: a restricted owner or a block between the two hides the share.
      const now = this.clock.now();
      if (await safetyRestricted(this.db, 'catalog', share.ownerId, now, undefined, tx))
        return reject('not_found');
      if (
        actor !== share.ownerId &&
        (await relationEffects(this.db, actor, share.ownerId, tx)).blocked
      )
        return reject('not_found');
      return {
        schemaVersion: 1,
        kind: 'succeeded',
        share: {
          scenarioId: share.scenarioId,
          expiresAtUtc: share.expiresAtUtc,
          distribution: revision.distribution,
        },
      };
    });
  }
  private conversionMatches(c: Record<string, unknown>, source: QuickSource['plan']) {
    const draft = c.draft as ScenarioDto,
      s = draft.scenario;
    const origin = record(s.origin);
    if (
      origin?.type !== 'quick_plan_conversion' ||
      origin.sourceId !== c.sourceId ||
      origin.sourceRevision !== c.sourceRevision ||
      s.displayCurrencyCode !== source.currencyCode ||
      s.days.length !== 1 ||
      s.legs.length !== 0 ||
      s.items.length !== (c.selectedStopIds as unknown[]).length ||
      s.locations.length !== s.items.length
    )
      return false;
    const stops = source.steps.filter((v: QuickStep) =>
      (c.selectedStopIds as string[]).includes(v.id),
    );
    if (stops.length !== s.items.length) return false;
    const sourceIds = new Set([source.id, ...source.steps.map((v: QuickStep) => v.id)]);
    for (const group of [s.days, s.items, s.locations])
      for (const child of group) if (sourceIds.has(child.id)) return false;
    return stops.every((stop: QuickStep, index: number) => {
      const item = s.items[index]!,
        location = s.locations[index]!;
      return (
        location.title === stop.title &&
        location.point?.latitude === stop.latitude &&
        location.point?.longitude === stop.longitude &&
        location.disclosure === 'private' &&
        item.durationMinutes === (stop.durationMinutes > 0 ? stop.durationMinutes : null) &&
        item.startLocationId === location.id &&
        item.endLocationId === location.id &&
        item.dayId === s.days[0]!.id &&
        s.days[0]!.itemIds[index] === item.id
      );
    });
  }
}
