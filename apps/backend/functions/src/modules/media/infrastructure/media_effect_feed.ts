import { FieldPath, type Firestore, type Query } from 'firebase-admin/firestore';

import type { MediaEffectV1 } from '../../../contracts/media_v1.js';
import { mediaCollections } from './firestore_media_repository.js';

/**
 * Read-only feed of committed Media facts for the owning domain's D2 reaction
 * (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §5.3): `(occurredAtUtc, effectId)`
 * order, ids and revisions only — never bytes, URLs or object keys. Nothing here
 * writes. Emulator-only like the repository that writes the facts.
 */
export class FirestoreMediaEffectFeed {
  constructor(private readonly firestore: Firestore) {}

  async effectsAfter(
    after: { readonly occurredAtUtc: string; readonly effectId: string } | null,
    limit: number,
  ): Promise<readonly MediaEffectV1[]> {
    let query: Query = this.firestore
      .collection(mediaCollections.effects)
      .orderBy('occurredAtUtc', 'asc')
      .orderBy(FieldPath.documentId(), 'asc');
    if (after !== null) query = query.startAfter(after.occurredAtUtc, after.effectId);
    const snapshot = await query.limit(limit).get();
    return snapshot.docs.map((document) => document.data() as MediaEffectV1);
  }
}
