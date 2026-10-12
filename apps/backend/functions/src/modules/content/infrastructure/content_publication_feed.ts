import { FieldPath, type Firestore, type Query } from 'firebase-admin/firestore';

import type { ContentEffectV1 } from '../../../contracts/content_v1.js';
import type { PublicationPointer } from '../domain/publication_pointer.js';
import type { PublishedRevision } from '../domain/published_revision.js';
import type { EffectCursor } from '../domain/repositories.js';
import {
  contentCollections,
  type FirestoreContentRepository,
} from './firestore_content_repository.js';

/**
 * Read-only publication feed that Content (BCK-07) offers its read-side
 * consumers: committed facts of all objects in `(occurredAtUtc, effectId)`
 * order, the stored facts of one object, current pointers and immutable
 * published revisions. Nothing here writes, and drafts are never exposed.
 * Emulator-only like the repository it reads through.
 */
export class ContentPublicationFeed {
  constructor(
    private readonly firestore: Firestore,
    private readonly repository: FirestoreContentRepository,
  ) {}

  async effectsAfter(
    after: { readonly occurredAtUtc: string; readonly effectId: string } | null,
    limit: number,
  ): Promise<readonly ContentEffectV1[]> {
    let query: Query = this.firestore
      .collection(contentCollections.effects)
      .orderBy('occurredAtUtc', 'asc')
      .orderBy(FieldPath.documentId(), 'asc');
    if (after !== null) query = query.startAfter(after.occurredAtUtc, after.effectId);
    const snapshot = await query.limit(limit).get();
    return snapshot.docs.map((document) => document.data() as ContentEffectV1);
  }

  async latestEffect(): Promise<{ occurredAtUtc: string; effectId: string } | null> {
    const snapshot = await this.firestore
      .collection(contentCollections.effects)
      .orderBy('occurredAtUtc', 'desc')
      .orderBy(FieldPath.documentId(), 'desc')
      .limit(1)
      .get();
    const last = snapshot.docs[0];
    if (last === undefined) return null;
    return { occurredAtUtc: String(last.get('occurredAtUtc')), effectId: last.id };
  }

  effectsForContent(
    contentId: string,
    after: EffectCursor | null,
    limit: number,
  ): Promise<readonly ContentEffectV1[]> {
    return this.repository.transact((tx) => tx.effectsPage(contentId, after, limit));
  }

  /** Current pointers in content-id order (one bounded page). */
  async pointersPage(
    afterContentId: string | null,
    limit: number,
  ): Promise<readonly PublicationPointer[]> {
    let query: Query = this.firestore
      .collection(contentCollections.pointers)
      .orderBy(FieldPath.documentId(), 'asc');
    if (afterContentId !== null) query = query.startAfter(afterContentId);
    const ids = (await query.select().limit(limit).get()).docs.map((document) => document.id);
    // Decoded by the repository itself, never by the reader.
    return this.repository.transact(async (tx) => {
      const pointers: PublicationPointer[] = [];
      for (const id of ids) {
        const pointer = await tx.pointer(id);
        if (pointer !== null) pointers.push(pointer);
      }
      return pointers;
    });
  }

  pointer(contentId: string): Promise<PublicationPointer | null> {
    return this.repository.transact((tx) => tx.pointer(contentId));
  }

  publishedRevision(publishedRevisionId: string): Promise<PublishedRevision | null> {
    return this.repository.transact((tx) => tx.publishedRevision(publishedRevisionId));
  }
}
