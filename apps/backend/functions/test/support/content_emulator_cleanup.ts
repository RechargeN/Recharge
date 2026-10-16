import { setTimeout as delay } from 'node:timers/promises';
import type { Firestore } from 'firebase-admin/firestore';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { eventBookingHandoffCollections } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { cleanupBookingEmulator } from './booking_emulator.js';

/**
 * Emulator groups share one Firestore. A suite that publishes Content must
 * leave no Content, Catalog, Media, Moderation, handoff or Booking state for
 * later suites that scan those collections. Effect triggers run asynchronously
 * in the Functions Emulator, so cleanup repeats until a quiet round finds
 * every collection empty.
 */
export async function cleanupContentEmulatorState(
  firestore: Firestore,
  extraCollections: readonly string[] = [],
): Promise<void> {
  const names = [
    ...Object.values(contentCollections),
    ...Object.values(catalogCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
    ...Object.values(eventBookingHandoffCollections),
    ...extraCollections,
  ];
  for (let round = 0; round < 10; round += 1) {
    let deleted = 0;
    for (const name of names) {
      for (;;) {
        const page = await firestore.collection(name).limit(200).get();
        if (page.empty) break;
        const batch = firestore.batch();
        for (const document of page.docs) batch.delete(document.ref);
        await batch.commit();
        deleted += page.size;
      }
    }
    await cleanupBookingEmulator(firestore);
    if (deleted === 0 && round > 0) return;
    await delay(500);
  }
  throw new Error('content_emulator_state_not_quiescent');
}
