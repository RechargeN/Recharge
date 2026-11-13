import type { Firestore } from 'firebase-admin/firestore';

import { runReconfirmationDeadlineWorker } from '../../src/booking/reconfirmation_deadline_worker.js';
import { bookingFlagIds } from '../../src/shared/feature_flags.js';
import { bookingInvariantProblems } from '../support/booking_invariants.js';
import { setLocalFlag } from '../support/notifications_world.js';

/**
 * F2 stand commands. The stand seed keeps reconfirmation and its deadline
 * worker off (B-gates unchanged); only the F2 gate switches them on. The
 * worker runs with the real stand time — the Emulator does not run schedules.
 */
const groups: Readonly<Record<string, readonly string[]>> = {
  reconfirm: [bookingFlagIds.reconfirm],
  'deadline-worker': [bookingFlagIds.reconfirmationDeadlineWorker],
};

const usage =
  'usage: booking-actions flags on|off <reconfirm|deadline-worker> | deadline | invariants';

export async function runBookingActions(
  firestore: Firestore,
  args: readonly string[],
): Promise<unknown> {
  const [action, first, second] = args;
  if (action === 'flags' && (first === 'on' || first === 'off') && second !== undefined) {
    const ids = groups[second];
    if (ids === undefined) throw new Error(usage);
    for (const id of ids) await setLocalFlag(firestore, id, first === 'on');
    return { flags: ids, enabled: first === 'on' };
  }
  if (action === 'deadline')
    return runReconfirmationDeadlineWorker(firestore, new Date().toISOString());
  if (action === 'invariants') {
    const problems = await bookingInvariantProblems(firestore);
    return { ok: problems.length === 0, problems };
  }
  throw new Error(usage);
}
