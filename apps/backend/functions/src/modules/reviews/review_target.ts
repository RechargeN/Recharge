import { object } from '../moderation/application/k1_workflows.js';
import { safetyRestricted } from '../../shared/safety_instruction.js';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { contentCollections } from '../content/infrastructure/firestore_content_repository.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { identityAuthorityCollections as ids } from '../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
/** Authoritative Content/Identity read adapter; no writes to either owner. */
export async function reviewTarget(
  db: Firestore,
  tx: Transaction,
  contentId: string,
  userId: string,
  now: Date,
  allowHidden = false,
) {
  const pointer = (await tx.get(db.collection(contentCollections.pointers).doc(contentId))).data();
  if (
    !pointer ||
    (!allowHidden && pointer.visibility !== 'visible') ||
    typeof pointer.currentPublishedRevisionId !== 'string'
  )
    return null;
  const revision = (
    await tx.get(
      db.collection(contentCollections.publishedRevisions).doc(pointer.currentPublishedRevisionId),
    )
  ).data();
  const body = object(revision?.body);
  const provenance = object(revision?.provenance);
  if (
    !revision ||
    !body ||
    revision.contentId !== contentId ||
    revision.marketId !== 'LV' ||
    !['place', 'event', 'activity'].includes(String(revision.typeId)) ||
    revision.bodyHash !== sha256Hex(canonicalJson(revision.body)) ||
    (body.visibility !== undefined && body.visibility !== 'public')
  )
    return null;
  const publisher = revision.publisherRef as { type: string; id: string };
  if (!publisher) return null;
  if (!allowHidden && (await safetyRestricted(db, 'content', publisher.id, now, contentId, tx)))
    return null;
  let own = publisher.type === 'user' && publisher.id === userId;
  const draft = (await tx.get(db.collection(contentCollections.drafts).doc(contentId))).data();
  own ||=
    draft?.ownerUserId === userId ||
    draft?.createdByUserId === userId ||
    provenance?.importerActorRef === 'user:' + userId;
  if (publisher.type === 'page') {
    const page = (await tx.get(db.collection(ids.managedPages).doc(publisher.id))).data();
    const members = await tx.get(
      db
        .collection(ids.pageMemberships)
        .where('pageId', '==', publisher.id)
        .where('userId', '==', userId)
        .limit(10),
    );
    if (
      !allowHidden &&
      typeof page?.ownerUserId === 'string' &&
      (await safetyRestricted(db, 'content', page.ownerUserId, now, contentId, tx))
    )
      return null;
    own ||= page?.ownerUserId === userId || members.docs.some((d) => d.get('status') === 'active');
  }
  return {
    typeId: revision.typeId as 'place' | 'event' | 'activity',
    own,
    publishedRevisionId: pointer.currentPublishedRevisionId,
  };
}
