import type { Firestore } from 'firebase-admin/firestore';
import type { BookingAccessHint } from './shared/booking_access_authority.js';
import type { ServerClock } from './shared/server_clock.js';
import { FirestoreBookingAccessAuthority } from './booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from './platform/config/firestore_feature_flag_gate.js';
import { createK1 } from './moderation_entry.js';
import { FirestoreSafetyService } from './modules/trust_safety/firestore_safety_service.js';
import { safetyCollections as c } from './modules/trust_safety/safety_policy.js';
import { object, exact, fail, ok } from './modules/moderation/application/k1_workflows.js';
import { isEntityId } from './shared/ids.js';

export async function handleK2(
  db: Firestore,
  hint: BookingAccessHint,
  surface: string,
  raw: unknown,
  clock: ServerClock,
) {
  const p = object(raw);
  if (!p || p.schemaVersion !== 1 || !isEntityId(p.requestId)) return fail('invalid_contract');
  const access = await new FirestoreBookingAccessAuthority(db).authorize(hint, clock.now());
  if (!access.allowed) return fail('unauthenticated');
  if (!(await new FirestoreFeatureFlagGate(db, 'local', 'LV').isEnabled('trustSafety.runtime')))
    return fail('feature_disabled');
  const k1 = createK1(db, clock),
    service = new FirestoreSafetyService(db, clock, k1.workflows);
  const actor = { userId: access.userId, sessionId: hint.sessionId };
  if (surface === 'safetyQueryV1') {
    if (!exact(p, ['schemaVersion', 'requestId', 'queryType', 'typeId']))
      return fail('invalid_contract');
    if (p.queryType === 'own') return service.query(hint);
    if (p.queryType === 'staffQueue' && typeof p.typeId === 'string') {
      if (!(await k1.workflows.allowed(actor, 'LV', p.typeId, 'appeal')))
        return fail('staff_denied');
      const sanctions = await db
        .collection(c.sanctions)
        .where('typeId', '==', p.typeId)
        .limit(50)
        .get();
      const appeals = [];
      for (const s of sanctions.docs) {
        const a = await db.collection(c.appeals).doc(s.id).get();
        if (a.exists) appeals.push(a.data());
      }
      return ok({ sanctions: sanctions.docs.map((d) => d.data()), appeals });
    }
    return fail('invalid_contract');
  }
  if (
    surface !== 'safetyCommandV1' ||
    !exact(p, ['schemaVersion', 'requestId', 'operation', 'payload'])
  )
    return fail('invalid_contract');
  const payload = object(p.payload);
  if (!payload) return fail('invalid_contract');
  switch (p.operation) {
    case 'relation':
      return service.relation(hint, { ...payload, schemaVersion: 1, requestId: p.requestId });
    case 'appeal':
      return service.appeal(hint, payload);
    case 'issueSanction':
      return service.issue(actor, payload);
    case 'changeSanction':
      return service.change(actor, payload);
    case 'decideAppeal':
      return service.decideAppeal(actor, payload);
    case 'reconcile': {
      if (!exact(payload, ['sanctionId']) || !isEntityId(payload.sanctionId))
        return fail('invalid_contract');
      const source = await db.collection(c.sanctions).doc(payload.sanctionId).get();
      const typeId = source.get('typeId') as unknown;
      if (
        typeof typeId !== 'string' ||
        !(await k1.workflows.allowed(actor, 'LV', typeId, 'sanction'))
      )
        return fail('staff_denied');
      return service.reconcile(payload.sanctionId);
    }
    default:
      return fail('invalid_contract');
  }
}
