import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import type { EmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';

/**
 * Content on the Firestore Emulator, composed exactly like the C3 callables:
 * Identity eligibility, the real Media readiness check and the C2 moderation
 * verifier (review before publication is mandatory). There is no longer a
 * stand-only "no review" policy. Reference data is the synthetic Emulator
 * constants of `EmulatorSyntheticReferenceData`.
 */
export function createStandContentService(firestore: Firestore, media: EmulatorMediaComposition) {
  const composition = eventAuthoringComposition(firestore, { media });
  return { service: composition.content, repository: composition.contentRepository, composition };
}

/** A complete Event body (C0 + schedule-C1) whose cover is the given Media asset. */
export function standEventBody(coverMediaId: string, slotId: string = randomUUID()) {
  return {
    eventArchetype: 'workshop',
    primaryParticipationMode: 'learn',
    title: 'Ceramics evening',
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    shortDescription: 'Shape your own bowl on the wheel',
    fullDescription:
      'An evening of guided pottery in a friendly studio. All materials and firing are included.',
    media: {
      coverImage: { mediaId: coverMediaId, altText: 'A potter shaping a bowl' },
      gallery: [],
      rightsConfirmed: true,
    },
    format: 'offline',
    location: {
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      formattedAddress: 'Brivibas iela 1, Riga',
      latitude: 56.95,
      longitude: 24.1,
      pinConfirmed: true,
    },
    schedule: {
      timezoneId: 'Europe/Riga',
      scheduleMode: 'oneTime',
      allDay: false,
      localStartDate: '2035-10-10',
      startMinute: 1080,
      durationMinutes: 120,
      allowsPartialAttendance: false,
      bufferBeforeMinutes: 0,
      bufferAfterMinutes: 0,
    },
    eventSlots: [
      {
        id: slotId,
        localDate: '2035-10-10',
        startAtUtc: '2035-10-10T15:00:00.000Z',
        endAtUtc: '2035-10-10T17:00:00.000Z',
      },
    ],
    pricing: { mode: 'free', paymentCollectionMode: 'none' },
    participants: { capacityMode: 'unknown' },
    registration: { mode: 'none' },
    visibility: 'public',
  };
}
