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
