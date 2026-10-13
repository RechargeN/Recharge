import { writeFileSync } from 'node:fs';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { collectStandState, computeStandDigest } from './stand_digest.js';
import { standInvariantProblems } from './stand_invariants.js';
import { assertStandEnvironment } from './stand_guard.js';
import { checkContentMediaReadiness, createStandContentDraft } from './stand_media.js';
import {
  ownerWithdrawStandContent,
  publishStandSubmission,
  standContentStatus,
  submitStandEventForReview,
} from './stand_moderation.js';
import { runCatalog } from './stand_catalog.js';
import { runBookingDeliver, runHandoff } from './stand_handoff.js';
import { ensureSecondCreator } from './stand_creator_fixture.js';
import { readStandManifest, StandSeedInterrupted } from './stand_content_event.js';
import { seedStand, StandAlreadySeededError } from './stand_seed.js';
import {
  bookingCounts,
  issueExpiredSession,
  revokeActiveSessions,
} from './stand_session_fixture.js';

/** Entry used by scripts/stand-seed.mjs after it has verified the running stand. */
async function main(args: readonly string[]): Promise<void> {
  const [command, ...rest] = args;
  assertStandEnvironment(process.env);
  const firestore = emulatorFirestore();
  if (command === 'seed') {
    const result = await seedStand(process.env, firestore);
    process.stdout.write(
      `${result.reused ? 'reused' : 'seeded'} users=${result.users} pages=${result.pages} bookings=${result.bookings} contentEvent=${result.contentEvent.contentId}\n`,
    );
    return;
  }
  if (command === 'catalog') {
    process.stdout.write(`${JSON.stringify(await runCatalog(firestore, rest))}\n`);
    return;
  }
  if (command === 'handoff') {
    process.stdout.write(`${JSON.stringify(await runHandoff(firestore, rest))}\n`);
    return;
  }
  if (command === 'notifications') {
    // Loaded only for this command, so F1 adds nothing to the start-up time of
    // the other stand commands (B2 measures timing-sensitive sequences).
    const { runNotifications } = await import('./stand_notifications.js');
    process.stdout.write(`${JSON.stringify(await runNotifications(firestore, rest))}
`);
    return;
  }
  if (command === 'booking-actions') {
    // F2: loaded only for this command, like the F1 Notifications commands.
    const { runBookingActions } = await import('./stand_booking_actions.js');
    process.stdout.write(`${JSON.stringify(await runBookingActions(firestore, rest))}
`);
    return;
  }
  if (command === 'media-reconcile') {
    // D2: loaded only for this command, like the F1/F2 commands.
    const { runMediaReconcile } = await import('./stand_media_reconcile.js');
    process.stdout.write(`${JSON.stringify(await runMediaReconcile(firestore))}
`);
    return;
  }
  if (command === 'place') {
    // D3.1: loaded only for this command, like the F1/F2 and D2 commands.
    const { seedContentPlace, standPlaceStatus, verifyStandPlace } =
      await import('./stand_content_place.js');
    const [action] = rest;
    if (action === 'seed') {
      const { reused, manifest } = await seedContentPlace(firestore, {
        interruptAfter: process.env.STAND_SEED_INTERRUPT_AFTER,
      });
      process.stdout.write(`${reused ? 'reused' : 'seeded'} place=${manifest.contentId}\n`);
      return;
    }
    if (action === 'verify') {
      const problems = await verifyStandPlace(firestore);
      if (problems.length > 0) throw new Error(`place invariants violated: ${problems.join('; ')}`);
      process.stdout.write('verified place invariants\n');
      return;
    }
    if (action === 'manifest') {
      const manifest = (await readStandManifest(firestore))?.contentPlace;
      if (manifest === undefined) throw new Error('stand Place is not seeded');
      process.stdout.write(`${JSON.stringify(manifest)}\n`);
      return;
    }
    if (action === 'status') {
      process.stdout.write(`${JSON.stringify(await standPlaceStatus(firestore))}\n`);
      return;
    }
    throw new Error('usage: place seed | verify | manifest | status');
  }
  if (command === 'activity') {
    // D3.2: loaded only for this command, like the D3.1 Place command.
    const { seedContentActivity, standActivityStatus, verifyStandActivity } =
      await import('./stand_content_activity.js');
    const [action] = rest;
    if (action === 'seed') {
      const { reused, manifest } = await seedContentActivity(firestore, {
        interruptAfter: process.env.STAND_SEED_INTERRUPT_AFTER,
      });
      process.stdout.write(`${reused ? 'reused' : 'seeded'} activity=${manifest.contentId}\n`);
      return;
    }
    if (action === 'verify') {
      const problems = await verifyStandActivity(firestore);
      if (problems.length > 0)
        throw new Error(`activity invariants violated: ${problems.join('; ')}`);
      process.stdout.write('verified activity invariants\n');
      return;
    }
    if (action === 'manifest') {
      const manifest = (await readStandManifest(firestore))?.contentActivity;
      if (manifest === undefined) throw new Error('stand Activity is not seeded');
      process.stdout.write(`${JSON.stringify(manifest)}\n`);
      return;
    }
    if (action === 'status') {
      process.stdout.write(`${JSON.stringify(await standActivityStatus(firestore))}\n`);
      return;
    }
    throw new Error('usage: activity seed | verify | manifest | status');
  }
  if (command === 'rental') {
    // D3.3: loaded only for this command, like the Place and Activity commands.
    const { seedContentRental, standRentalStatus, verifyStandRental } =
      await import('./stand_content_rental.js');
    const [action] = rest;
    if (action === 'seed') {
      const { reused, manifest } = await seedContentRental(firestore, {
        interruptAfter: process.env.STAND_SEED_INTERRUPT_AFTER,
      });
      process.stdout.write(`${reused ? 'reused' : 'seeded'} rental=${manifest.contentId}\n`);
      return;
    }
    if (action === 'verify') {
      const problems = await verifyStandRental(firestore);
      if (problems.length > 0)
        throw new Error(`rental invariants violated: ${problems.join('; ')}`);
      process.stdout.write('verified rental invariants\n');
      return;
    }
    if (action === 'manifest') {
      const manifest = (await readStandManifest(firestore))?.contentRental;
      if (manifest === undefined) throw new Error('stand Rental is not seeded');
      process.stdout.write(`${JSON.stringify(manifest)}\n`);
      return;
    }
    if (action === 'status') {
      process.stdout.write(`${JSON.stringify(await standRentalStatus(firestore))}\n`);
      return;
    }
    throw new Error('usage: rental seed | verify | manifest | status');
  }
  if (command === 'collection') {
    // D3.4: loaded only for this command, like the D3.1 Place command.
    const { seedContentCollection, standCollectionStatus, verifyStandCollection } =
      await import('./stand_content_collection.js');
    const [action] = rest;
    if (action === 'seed') {
      const { reused, manifest } = await seedContentCollection(firestore, {
        interruptAfter: process.env.STAND_SEED_INTERRUPT_AFTER,
      });
      process.stdout.write(`${reused ? 'reused' : 'seeded'} collection=${manifest.contentId}\n`);
      return;
    }
    if (action === 'verify') {
      const problems = await verifyStandCollection(firestore);
      if (problems.length > 0)
        throw new Error(`collection invariants violated: ${problems.join('; ')}`);
      process.stdout.write('verified collection invariants\n');
      return;
    }
    if (action === 'manifest') {
      const manifest = (await readStandManifest(firestore))?.contentCollection;
      if (manifest === undefined) throw new Error('stand Collection is not seeded');
      process.stdout.write(`${JSON.stringify(manifest)}\n`);
      return;
    }
    if (action === 'status') {
      process.stdout.write(`${JSON.stringify(await standCollectionStatus(firestore))}\n`);
      return;
    }
    throw new Error('usage: collection seed | verify | manifest | status');
  }
  if (command === 'creator-fixture') {
    const result = await ensureSecondCreator(firestore, new Date().toISOString());
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  if (command === 'booking-deliver') {
    process.stdout.write(`${JSON.stringify(await runBookingDeliver(firestore))}\n`);
    return;
  }
  if (command === 'manifest') {
    // The ids the owner services returned for the seeded objects; tests read them here.
    const manifest = await readStandManifest(firestore);
    if (manifest?.contentEvent === undefined) throw new Error('stand manifest is incomplete');
    process.stdout.write(`${JSON.stringify(manifest)}\n`);
    return;
  }
  if (command === 'digest') {
    const outIndex = rest.indexOf('--out');
    const result = await computeStandDigest(firestore);
    if (outIndex >= 0) {
      const target = rest[outIndex + 1];
      if (target === undefined) throw new Error('--out requires a path');
      writeFileSync(target, `${JSON.stringify(result.normalized, null, 2)}\n`, { flag: 'wx' });
    }
    process.stdout.write(`digest ${result.digest}\n`);
    return;
  }
  if (command === 'verify') {
    const problems = standInvariantProblems(await collectStandState(firestore));
    if (problems.length > 0) throw new Error(`invariants violated: ${problems.join('; ')}`);
    process.stdout.write('verified seed invariants\n');
    return;
  }
  if (command === 'content-draft') {
    const [user, page] = rest;
    if (user === undefined || page === undefined) throw new Error('content-draft <user> <page>');
    process.stdout.write(`${JSON.stringify(await createStandContentDraft(firestore, user, page))}
`);
    return;
  }
  if (command === 'media-readiness') {
    const [user, draftId, assetId] = rest;
    if (user === undefined || draftId === undefined || assetId === undefined)
      throw new Error('media-readiness <user> <draftId> <assetId>');
    process.stdout.write(
      `${JSON.stringify(await checkContentMediaReadiness(firestore, user, draftId, assetId))}
`,
    );
    return;
  }
  if (command === 'moderation-fixture') {
    // Owner-path fixtures for the C2 moderation checks; the staff script is separate.
    const [action, user, subject] = rest;
    const usage =
      'moderation-fixture submit <user> <page> | publish <user> <submissionId> | owner-withdraw <user> <contentId> | status <contentId>';
    let result: unknown;
    if (action === 'submit' && user !== undefined && subject !== undefined) {
      result = await submitStandEventForReview(firestore, user, subject);
    } else if (action === 'publish' && user !== undefined && subject !== undefined) {
      result = await publishStandSubmission(firestore, user, subject);
    } else if (action === 'owner-withdraw' && user !== undefined && subject !== undefined) {
      result = await ownerWithdrawStandContent(firestore, user, subject);
    } else if (action === 'status' && user !== undefined) {
      result = await standContentStatus(firestore, user);
    } else {
      throw new Error(usage);
    }
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }
  if (command === 'bookings') {
    const [label] = rest;
    if (label === undefined) throw new Error('bookings requires a stand user label');
    process.stdout.write(`${JSON.stringify(await bookingCounts(firestore, label))}
`);
    return;
  }
  if (command === 'session-fixture') {
    const [action, label, installationId] = rest;
    if (label === undefined) throw new Error('session-fixture requires a stand user label');
    if (action === 'revoke-active') {
      process.stdout
        .write(`${JSON.stringify({ revoked: await revokeActiveSessions(firestore, label) })}
`);
      return;
    }
    if (action === 'expired' && installationId !== undefined) {
      process.stdout.write(
        `${JSON.stringify(await issueExpiredSession(firestore, label, installationId))}
`,
      );
      return;
    }
    throw new Error(
      'usage: session-fixture revoke-active <label> | expired <label> <installationId>',
    );
  }
  throw new Error(
    'usage: stand_main.js seed | verify | digest [--out <new file>] | session-fixture ...',
  );
}

main(process.argv.slice(2)).catch((error: unknown) => {
  process.stderr.write(
    `${
      error instanceof StandAlreadySeededError
        ? 'refused: '
        : error instanceof StandSeedInterrupted
          ? 'interrupted: '
          : 'failed: '
    }${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exitCode = 1;
});
