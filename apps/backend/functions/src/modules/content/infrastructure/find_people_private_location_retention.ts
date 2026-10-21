import { randomUUID } from 'node:crypto';
import type { DocumentReference, Firestore } from 'firebase-admin/firestore';

import { retentionDeadline } from '../../../shared/find_people_policy.js';
import {
  consentDocumentId,
  findPeopleIdentityCollections,
} from '../../identity_publisher/infrastructure/find_people_privacy_authority.js';
import {
  findPeopleMeetingEnd,
  hasFindPeopleExactLocation,
  withoutFindPeopleExactLocation,
} from '../domain/type_rules/find_people_rules.js';
import {
  assertContentEmulatorContext,
  contentCollections,
} from './firestore_content_repository.js';

export const findPeopleRetentionActor = 'system:find-people-retention';

export interface FindPeopleRetentionReport {
  readonly scanned: number;
  /** Drafts whose exact meeting data was erased in this run. */
  readonly purgedDraftIds: readonly string[];
  /** Stored command answers redacted together with them. */
  readonly redactedAnswers: number;
}

function parse(value: unknown): Record<string, unknown> | null {
  if (typeof value !== 'string') return null;
  try {
    const parsed = JSON.parse(value) as unknown;
    return typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function earliest(values: readonly (string | null | undefined)[]): string | null {
  let best: number | null = null;
  for (const value of values) {
    if (typeof value !== 'string') continue;
    const at = Date.parse(value);
    if (Number.isFinite(at) && (best === null || at < best)) best = at;
  }
  return best === null ? null : new Date(best).toISOString();
}

/**
 * D3.7 §5.3 (FP-OD-03): erase exact Find People meeting data 30 days after its
 * public life ended. The life ends at the earliest of consent revoke, consent
 * expiry, meeting end and owner hide/unpublish; a draft with none of these ends
 * 30 days after its creation (legacy fallback never extends retention). Content-owned: it rewrites only Content
 * records (the draft, with its revision bumped, and the stored answers of its
 * own create/update commands) and writes an audit entry without values. It is
 * never behind a feature flag. Emulator-only, like the Content repository.
 */
export async function purgeFindPeoplePrivateLocations(
  db: Firestore,
  nowUtc: string,
): Promise<FindPeopleRetentionReport> {
  assertContentEmulatorContext(db);
  const drafts = await db
    .collection(contentCollections.drafts)
    .where('typeId', '==', 'find_people')
    .get();
  const purgedDraftIds: string[] = [];
  let redactedAnswers = 0;
  if (!Number.isFinite(Date.parse(nowUtc))) throw new Error('invalid retention instant');
  for (const snapshot of drafts.docs) {
    const result = await db.runTransaction(async (tx) => {
      // All decision inputs are transactional: a concurrent edit, receipt,
      // consent or pointer update retries against one consistent state.
      const draft = (await tx.get(snapshot.ref)).data();
      if (draft === undefined || draft.typeId !== 'find_people') return null;
      const body = parse(draft.bodyJson);
      const contentId = String(draft.contentId);
      const author = String(draft.createdByUserId ?? '');
      const consent = (
        await tx.get(
          db
            .collection(findPeopleIdentityCollections.consents)
            .doc(consentDocumentId(contentId, author)),
        )
      ).data();
      const pointer = (
        await tx.get(db.collection(contentCollections.pointers).doc(contentId))
      ).data();
      const answers = await tx.get(
        db.collection(contentCollections.idempotency).where('actorUserId', '==', author),
      );
      const events = await tx.get(
        db.collection(contentCollections.audit).where('subjectId', '==', contentId),
      );
      const consentHistory = await tx.get(
        db.collection(findPeopleIdentityCollections.consentReceipts).where('userId', '==', author),
      );
      const updates: { ref: DocumentReference; outcomeJson: string }[] = [];
      const ends: (string | null | undefined)[] = [
        consent?.revokedAtUtc as string | undefined,
        consent?.expiresAtUtc as string | undefined,
        body === null ? null : findPeopleMeetingEnd(body),
      ];
      for (const answer of answers.docs) {
        const data = answer.data();
        if (data.commandType !== 'createDraft' && data.commandType !== 'updateDraft') continue;
        const outcome = parse(data.outcomeJson);
        if (outcome === null || outcome.draftId !== snapshot.id) continue;
        // Historical bodies matter even when the current body has no exact.
        if (typeof outcome.body === 'object' && outcome.body !== null)
          ends.push(findPeopleMeetingEnd(outcome.body));
        if (!hasFindPeopleExactLocation(outcome.body)) continue;
        updates.push({
          ref: answer.ref,
          outcomeJson: JSON.stringify({
            ...outcome,
            body: withoutFindPeopleExactLocation(outcome.body as Record<string, unknown>),
          }),
        });
      }
      for (const event of events.docs) {
        if (
          ['content.publication.withdraw', 'content.publication.archive'].includes(
            String(event.get('action')),
          )
        )
          ends.push(event.get('occurredAtUtc') as string);
      }
      for (const receipt of consentHistory.docs) {
        const historical = receipt.get('result.consent') as Record<string, unknown> | undefined;
        if (historical?.contentId === contentId)
          ends.push(
            historical.revokedAtUtc as string | undefined,
            historical.expiresAtUtc as string | undefined,
          );
      }
      // Legacy hidden records without an event cannot safely use mutable
      // pointer.updatedAtUtc. Use original creation, never migration time.
      if (
        pointer?.ownerHold != null &&
        !events.docs.some((event) =>
          ['content.publication.withdraw', 'content.publication.archive'].includes(
            String(event.get('action')),
          ),
        )
      )
        ends.push(draft.createdAtUtc as string | undefined);
      // No meeting/consent/event: retain the accepted 30+30 day draft bound,
      // anchored to creation so later unrelated writes cannot extend it.
      const origin = earliest([
        draft.createdAtUtc as string,
        ...answers.docs.map((a) => a.get('recordedAtUtc') as string),
      ]);
      const lifeEnd = earliest(ends) ?? (origin === null ? null : retentionDeadline(origin));
      // Legacy records without any trustworthy timestamp are overdue, not
      // granted a fresh retention period by a migration or this job.
      const due = lifeEnd === null || Date.parse(nowUtc) >= Date.parse(retentionDeadline(lifeEnd));
      const exact = body !== null && hasFindPeopleExactLocation(body);
      if (!due || (!exact && updates.length === 0)) return null;
      if (exact)
        tx.update(snapshot.ref, {
          bodyJson: JSON.stringify(withoutFindPeopleExactLocation(body)),
          revision: Number(draft.revision) + 1,
          updatedAtUtc: nowUtc,
        });
      for (const update of updates) tx.update(update.ref, { outcomeJson: update.outcomeJson });
      const auditId = randomUUID();
      tx.create(db.collection(contentCollections.audit).doc(auditId), {
        auditId,
        occurredAtUtc: nowUtc,
        actorUserId: findPeopleRetentionActor,
        action: 'content.find_people.private_location_purged',
        subjectId: snapshot.id,
        outcome: 'succeeded',
      });
      return { exact, count: updates.length };
    });
    if (result === null) continue;
    if (result.exact) purgedDraftIds.push(snapshot.id);
    redactedAnswers += result.count;
  }
  return Object.freeze({ scanned: drafts.size, purgedDraftIds, redactedAnswers });
}
