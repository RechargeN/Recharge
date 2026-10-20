import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { before, after, test } from 'node:test';
import { getAuth } from 'firebase-admin/auth';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { quickPlanCollections } from '../../src/modules/quick_plan/quick_plan_contract.js';
import { FirestoreRouteService } from '../../src/modules/route/firestore_route_service.js';
import { routeCollections as cols, routeFlag } from '../../src/modules/route/route_contract.js';
import {
  decodeSegment,
  encodeElevation,
  encodePolyline,
  type Point,
} from '../../src/modules/route/route_geometry.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db = emulatorFirestore(),
  now = new Date();
const service = new FirestoreRouteService(db, { now: () => now });
async function identity(uid: string, installationId: string) {
  const s = await establishEmulatorIdentitySession({
    firestore: db,
    firebaseUid: uid,
    installationId,
    attemptRequestId: randomUUID(),
    now,
  });
  return {
    userId: s.userId,
    hint: {
      firebaseUid: uid,
      sessionId: s.sessionId,
      sessionHandle: s.sessionHandle,
      installationId,
    },
  };
}
let a: Awaited<ReturnType<typeof identity>>, b: typeof a, other: typeof a;
const uid = 'j1-' + randomUUID(),
  foreignUid = 'j1-' + randomUUID();
let protectedDigest: string;
async function sideEffectDigest() {
  const values = [];
  for (const name of [
    ...Object.values(catalogCollections),
    ...Object.values(contentCollections),
    ...Object.values(quickPlanCollections),
    'scenarios',
    'scenarioRevisions',
    'scenarioMembers',
  ]) {
    const docs = await db.collection(name).get();
    values.push([name, docs.docs.map((d) => [d.id, d.data()]).sort()]);
  }
  return sha256Hex(canonicalJson(values));
}
async function cleanup() {
  for (const name of Object.values(cols)) {
    for (;;) {
      const docs = await db.collection(name).limit(200).get();
      if (docs.empty) break;
      const batch = db.batch();
      docs.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    assert.equal((await db.collection(name).limit(1).get()).empty, true);
  }
}
before(async () => {
  await cleanupBookingEmulator(db);
  await cleanup();
  await setLocalFlag(db, routeFlag, true);
  await setLocalFlag(db, 'identity.session.establish', true);
  a = await identity(uid + '-backend', 'j1-backend-a');
  b = await identity(uid + '-backend', 'j1-backend-b');
  other = await identity(foreignUid + '-backend', 'j1-other');
  protectedDigest = await sideEffectDigest();
});
after(async () => {
  try {
    assert.equal(
      await sideEffectDigest(),
      protectedDigest,
      'J1 must not mutate Catalog, Content, Quick Plan or Scenario',
    );
  } finally {
    await cleanup();
    await cleanupBookingEmulator(db);
    for (const id of [uid, foreignUid]) {
      try {
        await getAuth().deleteUser(id);
      } catch (e) {
        if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
      }
    }
    process.stdout.write(
      'J1 cleanup verified: routes/receipts empty; owned Auth users deleted; Identity/flags cleared.\n',
    );
  }
});

const sourceId = 'gpx-0123456789abcdef';
const walk = (n: number, start = 0, ele: number | null = 120): Point[] =>
  Array.from({ length: n }, (_, i) => ({
    latE7: 569_496_000,
    lonE7: 241_052_000 + (start + i) * 1000,
    eleDm: ele,
  }));
/** Two imported parts and the user-confirmed direct bridge between them. */
function importedRoute(title = 'Imported') {
  const first = walk(10),
    second = walk(10, 20);
  const parts = [first, [first[9]!, second[0]!], second];
  const anchors = [first[0]!, first[9]!, second[0]!, second[9]!].map((p) => ({
    anchorId: randomUUID(),
    latE7: p.latE7,
    lonE7: p.lonE7,
  }));
  return {
    schemaVersion: 1,
    coordinatePolicy: 'wgs84-e7-dm-v1',
    title,
    shape: 'oneWay',
    turningAnchorId: null,
    profile: { id: 'walking', version: 1 },
    anchors,
    segments: parts.map((points, order) => ({
      segmentId: randomUUID(),
      order,
      fromAnchorId: anchors[order]!.anchorId,
      toAnchorId: anchors[order + 1]!.anchorId,
      sourceKind: order === 1 ? 'intentionalDirect' : 'importedGpx',
      derivation: 'original',
      sourceId: order === 1 ? 'author-direct' : sourceId,
      parentSegmentId: null,
      polyline: encodePolyline(points),
      elevation: encodeElevation(points),
    })),
    waypoints: [
      {
        waypointId: randomUUID(),
        segmentId: null,
        anchorId: null,
        latE7: 569_496_100,
        lonE7: 241_052_100,
        eleDm: null,
        typeId: 'other',
        trackState: 'offTrackConfirmed',
        title: 'Home <door> & "gate"',
        description: null,
        note: 'private note',
        safetyNote: null,
      },
      {
        waypointId: randomUUID(),
        segmentId: null,
        anchorId: null,
        latE7: 569_496_000,
        lonE7: 241_062_000,
        eleDm: 130,
        typeId: 'viewpoint',
        trackState: 'offTrackConfirmed',
        title: 'View',
        description: null,
        note: null,
        safetyNote: null,
      },
    ],
  };
}
type RouteBody = ReturnType<typeof importedRoute>;
function importCommand(route: RouteBody = importedRoute(), routeId = randomUUID()) {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: a.userId,
    idempotencyKey: 'import-' + randomUUID(),
    commandType: 'import',
    routeId,
    expectedRevision: 0,
    route,
    importSource: {
      sourceId,
      parserVersion: 'gpx-inspector-v2',
      transformations: [
        { code: 'strip-timestamps', count: null },
        { code: 'strip-metadata', count: null },
        { code: 'quantize-e7-dm', count: null },
        { code: 'drop-consecutive-duplicates', count: 0 },
        { code: 'direct-gap-bridge', count: 1 },
      ],
    },
  };
}
function command(
  routeId: string,
  type: string,
  revision: number,
  body: Record<string, unknown> = {},
  owner = a.userId,
) {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: owner,
    idempotencyKey: type + '-' + randomUUID(),
    commandType: type,
    routeId,
    expectedRevision: revision,
    ...body,
  };
}
const get = (hint: typeof a.hint, routeId: string) =>
  service.query(hint, { schemaVersion: 1, requestId: randomUUID(), queryType: 'get', routeId });
const trimmed = (hint: typeof a.hint, routeId: string, expectedRevision: number) =>
  service.query(hint, {
    schemaVersion: 1,
    requestId: randomUUID(),
    queryType: 'trimmedView',
    routeId,
    expectedRevision,
  });
async function created() {
  const c = importCommand();
  const r = await service.command(a.hint, c);
  assert.equal(r.kind, 'succeeded', JSON.stringify(r));
  return { id: c.routeId, route: c.route, command: c };
}
const retitled = (route: RouteBody, title: string) => ({ ...route, title });
const docOf = async (id: string) =>
  (
    await db
      .collection(cols.routes)
      .doc(a.userId + ':' + id)
      .get()
  ).data();

void test('import stamps provenance and summary; owner entry is allowlisted and private', async () => {
  const { id } = await created();
  const r = await get(a.hint, id);
  const entry = r.entry as Record<string, unknown>;
  assert.deepEqual(Object.keys(entry).sort(), [
    'privacyTrim',
    'provenance',
    'revision',
    'route',
    'routeId',
    'status',
    'summary',
    'updatedAtUtc',
  ]);
  assert.deepEqual(entry.provenance, {
    origin: 'gpxImport',
    verification: 'unverified',
    parserVersion: 'gpx-inspector-v2',
    transformations: importCommand().importSource.transformations,
  });
  const summary = entry.summary as Record<string, number>;
  assert.equal(summary.pointCount, 22);
  assert.equal(summary.segmentCount, 3);
  assert.equal(summary.gapCount, 0);
  assert.equal(summary.minElevationMeters, 12);
  // Foreign owner: no existence oracle, no write, no list entry.
  assert.equal((await get(other.hint, id)).entry, null);
  assert.equal((await service.command(other.hint, command(id, 'delete', 1))).code, 'owner_changed');
  assert.equal(
    (await service.command(other.hint, command(id, 'delete', 1, {}, other.userId))).code,
    'not_found',
  );
  const list = await service.query(other.hint, {
    schemaVersion: 1,
    requestId: randomUUID(),
    queryType: 'list',
    cursor: null,
  });
  assert.deepEqual(list.entries, []);
  assert.equal((await get({ ...a.hint, sessionHandle: 'forged' }, id)).code, 'unauthenticated');
  const sessionRef = db.collection('identitySessions').doc(b.hint.sessionId);
  const session = (await sessionRef.get()).data()!;
  await sessionRef.update({ idleExpiresAtUtc: '2020-01-01T00:00:00.000Z' });
  try {
    assert.equal((await service.command(b.hint, command(id, 'delete', 1))).code, 'unauthenticated');
  } finally {
    await sessionRef.set(session);
  }
});

void test('edit/edit both orders: first commit wins, the other gets an explicit conflict', async () => {
  for (const reverse of [false, true]) {
    const { id, route } = await created();
    const edits = [
      command(id, 'save', 1, { route: retitled(route, 'A') }),
      command(id, 'save', 1, { route: retitled(route, 'B') }),
    ];
    const first = reverse ? 1 : 0;
    assert.equal((await service.command(first ? b.hint : a.hint, edits[first]!)).kind, 'succeeded');
    assert.equal(
      (await service.command(first ? a.hint : b.hint, edits[1 - first]!)).code,
      'revision_conflict',
    );
    const entry = (await get(a.hint, id)).entry as { route: RouteBody; revision: number };
    assert.equal(entry.route.title, first ? 'B' : 'A');
    assert.equal(entry.revision, 2);
  }
});

void test('trim/edit both orders: CAS conflict, and a save never removes the trim', async () => {
  for (const trimFirst of [false, true]) {
    const { id, route } = await created();
    const trim = command(id, 'setPrivacyTrim', 1, {
      privacyTrim: { startMeters: 20, endMeters: 13 },
    });
    const edit = command(id, 'save', 1, { route: retitled(route, 'edited') });
    const [winner, loser] = trimFirst ? [trim, edit] : [edit, trim];
    assert.equal((await service.command(a.hint, winner)).kind, 'succeeded');
    assert.equal((await service.command(b.hint, loser)).code, 'revision_conflict');
    if (!trimFirst) {
      assert.equal(
        (
          await service.command(a.hint, {
            ...trim,
            idempotencyKey: 'trim-' + randomUUID(),
            expectedRevision: 2,
          })
        ).kind,
        'succeeded',
      );
    }
    // A later current-revision save keeps the trim: it cannot carry trim fields.
    const revision = trimFirst ? 2 : 3;
    assert.equal(
      (
        await service.command(
          a.hint,
          command(id, 'save', revision, { route: retitled(route, 'later') }),
        )
      ).kind,
      'succeeded',
    );
    assert.equal(
      (
        await service.command(
          a.hint,
          command(id, 'save', revision + 1, { route, privacyTrim: null }),
        )
      ).code,
      'request_invalid',
    );
    const entry = (await get(a.hint, id)).entry as Record<string, unknown>;
    assert.deepEqual(entry.privacyTrim, {
      policy: 'endpoint-radius-v1',
      startMeters: 20,
      endMeters: 13,
    });
    // An old client replaying a weaker trim on a stale revision cannot undo it.
    assert.equal(
      (
        await service.command(
          b.hint,
          command(id, 'setPrivacyTrim', 1, { privacyTrim: { startMeters: 0, endMeters: 0 } }),
        )
      ).code,
      'revision_conflict',
    );
  }
});

void test('edit/delete both orders: delete wins, tombstone drops geometry, nothing resurrects', async () => {
  for (const deleteFirst of [false, true]) {
    const { id, route, command: imported } = await created();
    const edit = command(id, 'save', 1, { route: retitled(route, 'offline') });
    const del = command(id, 'delete', 1);
    if (deleteFirst) {
      assert.equal((await service.command(b.hint, del)).kind, 'succeeded');
      assert.equal((await service.command(a.hint, edit)).code, 'deleted');
    } else {
      assert.equal((await service.command(a.hint, edit)).kind, 'succeeded');
      assert.equal((await service.command(b.hint, del)).kind, 'succeeded');
    }
    // Replayed import receipt is historical; a new import or trim hits the tombstone.
    assert.equal((await service.command(a.hint, imported)).kind, 'succeeded');
    assert.equal(
      (await service.command(a.hint, { ...imported, idempotencyKey: 'import-' + randomUUID() }))
        .code,
      'deleted',
    );
    assert.equal(
      (
        await service.command(
          a.hint,
          command(id, 'setPrivacyTrim', 3, { privacyTrim: { startMeters: 1, endMeters: 1 } }),
        )
      ).code,
      'deleted',
    );
    const entry = (await get(a.hint, id)).entry as Record<string, unknown>;
    assert.deepEqual(Object.keys(entry).sort(), ['revision', 'routeId', 'status', 'updatedAtUtc']);
    assert.equal(entry.status, 'deleted');
    const stored = (await docOf(id))!;
    assert.equal(stored.route, undefined);
    assert.equal(stored.provenance, undefined);
    // Receipts never hold geometry, so the tombstone really drops it.
    const receipts = await db.collection(cols.receipts).where('ownerId', '==', a.userId).get();
    assert.ok(receipts.docs.every((d) => !JSON.stringify(d.data()).includes('polyline')));
  }
});

void test('lost response, repeated intent, changed payload and ID collision', async () => {
  const c = importCommand();
  const first = await service.command(a.hint, c);
  assert.deepEqual(await service.command(b.hint, { ...c, requestId: randomUUID() }), first);
  assert.equal(
    (await service.command(a.hint, { ...c, route: retitled(c.route, 'changed') })).code,
    'idempotency_conflict',
  );
  assert.equal(
    (await service.command(a.hint, { ...c, idempotencyKey: 'import-' + randomUUID() })).code,
    'id_collision',
  );
  const all = await db.collection(cols.routes).where('ownerId', '==', a.userId).get();
  assert.equal(all.docs.filter((d) => d.get('routeId') === c.routeId).length, 1);
  // The same key is actor-scoped: another owner's identical key is independent.
  const foreign = {
    ...importCommand(importedRoute(), c.routeId),
    ownerContext: other.userId,
    idempotencyKey: c.idempotencyKey,
  };
  assert.equal((await service.command(other.hint, foreign)).kind, 'succeeded');
  assert.equal(((await get(a.hint, c.routeId)).entry as { revision: number }).revision, 1);
});

void test('hostile, oversized and unverifiable commands leave the stored Route unchanged', async () => {
  const { id, route } = await created();
  const before = canonicalJson(await docOf(id));
  const tooMany = structuredClone(route);
  tooMany.segments[0]!.polyline = encodePolyline(walk(10_001));
  tooMany.segments[0]!.elevation = null;
  const longText = structuredClone(route);
  longText.waypoints[1]!.note = 'x'.repeat(205_000);
  const reKind = structuredClone(route);
  reKind.segments[0]!.sourceKind = 'recordedGps';
  const unregistered = structuredClone(route);
  unregistered.segments[2]!.segmentId = randomUUID();
  unregistered.segments[2]!.sourceId = 'gpx-ffffffffffffffff';
  const routed = structuredClone(route);
  routed.segments[1]!.sourceKind = 'routed';
  const outOfRange = structuredClone(route);
  outOfRange.anchors[0]!.latE7 = 900_000_001;
  for (const [body, expected] of [
    [tooMany, 'point_limit_exceeded'],
    [longText, 'payload_too_large'],
    [reKind, 'provenance_unverified'],
    [unregistered, 'provenance_unverified'],
    [routed, 'license_blocked'],
    [outOfRange, 'invalid_geometry'],
  ] as const)
    assert.equal(
      (await service.command(a.hint, command(id, 'save', 1, { route: body }))).code,
      expected,
    );
  assert.equal(
    (await service.command(a.hint, command(id, 'save', 1, { route, extensions: { a: 1 } }))).code,
    'request_invalid',
  );
  assert.equal(canonicalJson(await docOf(id)), before);
  // Split lineage: a new importedGpx segment from the registered source is accepted.
  const split = structuredClone(route);
  split.segments[2]!.segmentId = randomUUID();
  assert.equal(
    (await service.command(a.hint, command(id, 'save', 1, { route: split }))).kind,
    'succeeded',
  );
  // An authored first save cannot smuggle importedGpx geometry.
  assert.equal(
    (await service.command(a.hint, command(randomUUID(), 'save', 0, { route: importedRoute() })))
      .code,
    'provenance_unverified',
  );
});

void test('trimmed view: pinned revision, allowlist, no removed geometry, no untrimmed fallback', async () => {
  const { id, route } = await created();
  assert.equal(
    (
      await service.command(
        a.hint,
        command(id, 'setPrivacyTrim', 1, { privacyTrim: { startMeters: 5000, endMeters: 0 } }),
      )
    ).code,
    'privacy_trim_invalid',
  );
  assert.equal(
    (
      await service.command(
        a.hint,
        command(id, 'setPrivacyTrim', 1, { privacyTrim: { startMeters: 2000, endMeters: 0 } }),
      )
    ).code,
    'privacy_trim_empty',
  );
  assert.equal(
    (
      await service.command(
        a.hint,
        command(id, 'setPrivacyTrim', 1, { privacyTrim: { startMeters: 20, endMeters: 13 } }),
      )
    ).kind,
    'succeeded',
  );
  assert.equal((await trimmed(a.hint, id, 1)).code, 'revision_conflict');
  assert.equal((await trimmed(other.hint, id, 2)).code, 'not_found');
  const r = await trimmed(a.hint, id, 2);
  const view = r.view as Record<string, unknown>;
  assert.deepEqual(Object.keys(view).sort(), [
    'endMeters',
    'policy',
    'revision',
    'routeId',
    'segments',
    'startMeters',
    'summary',
    'variantHash',
    'warnings',
    'waypoints',
  ]);
  const json = JSON.stringify(view);
  for (const forbidden of ['anchor', 'note', 'bounds', 'provenance', 'segmentId', 'sourceKind'])
    assert.equal(json.includes(forbidden), false, forbidden);
  const segments = view.segments as { polyline: string; elevation: string | null }[];
  const kept = segments.flatMap((s) => decodeSegment(s.polyline, s.elevation, 10_000));
  const removed = [...walk(10).slice(0, 4), ...walk(10, 20).slice(7)];
  for (const p of removed)
    assert.equal(
      kept.some((k) => k.latE7 === p.latE7 && k.lonE7 === p.lonE7),
      false,
    );
  assert.equal((view.summary as { pointCount: number }).pointCount, 22 - 7);
  // The waypoint next to the hidden start is removed; titles keep raw text for escaping.
  assert.deepEqual(
    (view.waypoints as { title: string }[]).map((w) => w.title),
    ['View'],
  );
  // Repeated reads of one revision and trim are byte-identical.
  assert.deepEqual(await trimmed(a.hint, id, 2), r);
  // A later edit that makes the trim empty blocks export instead of falling back.
  const tiny = structuredClone(route);
  tiny.segments = [tiny.segments[0]!];
  tiny.segments[0]!.polyline = encodePolyline(walk(3));
  tiny.segments[0]!.elevation = null;
  tiny.anchors = tiny.anchors.slice(0, 2);
  tiny.anchors[1]!.lonE7 = walk(3)[2]!.lonE7;
  tiny.waypoints = [];
  const saved = await service.command(a.hint, command(id, 'save', 2, { route: tiny }));
  assert.equal(saved.kind, 'succeeded', JSON.stringify(saved));
  assert.equal((await trimmed(a.hint, id, 3)).code, 'privacy_trim_empty');
});

void test('owner list pages are bounded and stable', async () => {
  const ids: string[] = [];
  for (let i = 0; i < 52; i++) {
    const c = importCommand(importedRoute('list ' + i));
    c.ownerContext = other.userId;
    await service.command(other.hint, c);
    ids.push(c.routeId);
  }
  const seen: string[] = [];
  let cursor: string | null = null;
  for (let page = 0; page < 5; page++) {
    const r = await service.query(other.hint, {
      schemaVersion: 1,
      requestId: randomUUID(),
      queryType: 'list',
      cursor,
    });
    const entries = r.entries as { routeId: string; title: string }[];
    assert.ok(entries.length <= 50);
    for (const e of entries)
      assert.deepEqual(Object.keys(e).sort(), [
        'revision',
        'routeId',
        'status',
        'title',
        'updatedAtUtc',
      ]);
    seen.push(...entries.map((e) => e.routeId));
    cursor = r.cursor as string | null;
    if (!r.hasMore) break;
  }
  for (const id of ids) assert.ok(seen.includes(id));
  assert.equal(new Set(seen).size, seen.length);
});

void test(
  'real Flutter adapters: GPX preview/apply/export, two clients, recovery and account isolation',
  { timeout: 240000 },
  async () => {
    const dart = process.env.RECHARGE_DART,
      flutter = process.env.RECHARGE_FLUTTER_TOOL;
    assert.ok(
      dart && flutter,
      'J1 requires real Flutter adapters: set RECHARGE_DART and RECHARGE_FLUTTER_TOOL',
    );
    for (const id of [uid, foreignUid])
      await getAuth().createUser({
        uid: id,
        email: id + '@example.invalid',
        password: 'emulator-only-password-123',
      });
    const result = await new Promise<number>((resolve, reject) => {
      const child = spawn(
        dart,
        [
          flutter,
          'test',
          '--no-pub',
          '--dart-define=RECHARGE_TEST_ROUTE_SYNC=true',
          'test/backend_local/route_j1_client_test.dart',
        ],
        {
          cwd: path.resolve(process.cwd(), '../../mobile'),
          env: {
            ...process.env,
            RECHARGE_J1_LOCAL: '1',
            RECHARGE_J1_UID: uid,
            RECHARGE_J1_OTHER_UID: foreignUid,
          },
          stdio: ['ignore', 'pipe', 'pipe'],
          shell: false,
        },
      );
      child.stdout.on('data', (d: Buffer) => process.stdout.write(d));
      child.stderr.on('data', (d: Buffer) => process.stderr.write(d));
      child.once('error', reject);
      child.once('close', (code) => resolve(code ?? 1));
    });
    assert.equal(result, 0);
  },
);
