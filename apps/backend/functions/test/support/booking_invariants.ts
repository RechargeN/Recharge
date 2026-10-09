import type { Firestore } from 'firebase-admin/firestore';

import { activeBookingKeyId } from '../../src/inventory/active_key.js';
import {
  bookingCollections,
  bookingUserUsageId,
  finitePoolLedgerId,
} from '../../src/booking/transactions.js';
import { notificationCollections } from '../../src/modules/notifications/infrastructure/firestore_notifications_repository.js';

/**
 * F2 §6: the final invariants a race must leave behind, read from the stored
 * state, never from command answers. Returns every problem found.
 *
 * 1. allocation/usage: each finite ledger holds exactly the units of its active
 *    Bookings; each usage document counts exactly its user's active Bookings
 *    and names them; no value is negative; one active key per active Booking
 *    and none for a cancelled one (so nothing was released twice or kept);
 * 2. revisions: each Booking has exactly one outbox record per revision;
 * 3. notifications: at most one inbox record per outbox record and per
 *    Booking revision.
 */
export async function bookingInvariantProblems(firestore: Firestore): Promise<string[]> {
  const problems: string[] = [];
  const bookings = (await firestore.collection(bookingCollections.bookings).get()).docs.map(
    (document) => document.data(),
  );
  const active = bookings.filter((booking) => booking.state === 'confirmed');

  const ledgers = await firestore.collection(bookingCollections.poolLedgers).get();
  for (const document of ledgers.docs) {
    const ledger = document.data();
    const held = active
      .filter(
        (booking) =>
          booking.occurrenceId === ledger.occurrenceId &&
          booking.inventoryPoolId === ledger.poolId &&
          booking.channel === ledger.channel,
      )
      .reduce((sum, booking) => sum + Number(booking.participantUnits), 0);
    if (ledger.confirmedUnits !== held)
      problems.push(
        `ledger ${String(ledger.occurrenceId)}: confirmedUnits ${String(ledger.confirmedUnits)} != active units ${String(held)}`,
      );
    if (Number(ledger.confirmedUnits) < 0) problems.push(`ledger ${document.id} negative`);
  }
  for (const booking of active.filter((value) => value.inventoryPoolId !== undefined)) {
    const id = finitePoolLedgerId(
      String(booking.occurrenceId),
      String(booking.inventoryPoolId),
      String(booking.channel),
    );
    if (!ledgers.docs.some((document) => document.id === id))
      problems.push(`active finite Booking ${String(booking.id)} has no ledger`);
  }

  const users = new Set(
    bookings.map((booking) => `${String(booking.userId)}|${String(booking.marketId)}`),
  );
  for (const key of users) {
    const [userId, marketId] = key.split('|') as [string, 'LV' | 'EE' | 'LT'];
    const usage = (
      await firestore
        .collection(bookingCollections.userUsage)
        .doc(bookingUserUsageId(userId, marketId))
        .get()
    ).data();
    const mine = active.filter(
      (booking) => booking.userId === userId && booking.marketId === marketId,
    );
    const finite = mine
      .filter((booking) => booking.inventoryPoolId !== undefined)
      .map((booking) => String(booking.id));
    const unlimited = mine
      .filter((booking) => booking.inventoryPoolId === undefined)
      .map((booking) => String(booking.id));
    const finiteSlots = ((usage?.activeFiniteSlots ?? []) as { bookingId: string }[]).map(
      (slot) => slot.bookingId,
    );
    const unlimitedSlots = ((usage?.activeUnlimitedSlots ?? []) as { bookingId: string }[]).map(
      (slot) => slot.bookingId,
    );
    if (Number(usage?.activeFiniteBookings ?? 0) !== finite.length)
      problems.push(
        `usage ${userId}: activeFiniteBookings ${String(usage?.activeFiniteBookings)} != ${String(finite.length)}`,
      );
    if (Number(usage?.activeUnlimitedBookings ?? 0) !== unlimited.length)
      problems.push(
        `usage ${userId}: activeUnlimitedBookings ${String(usage?.activeUnlimitedBookings)} != ${String(unlimited.length)}`,
      );
    if ([...finiteSlots].sort().join() !== [...finite].sort().join())
      problems.push(`usage ${userId}: finite slots differ from active Bookings`);
    if ([...unlimitedSlots].sort().join() !== [...unlimited].sort().join())
      problems.push(`usage ${userId}: unlimited slots differ from active Bookings`);
  }

  for (const booking of bookings) {
    const key = await firestore
      .collection(bookingCollections.activeKeys)
      .doc(activeBookingKeyId(String(booking.userId), String(booking.occurrenceId)))
      .get();
    const holds = key.exists && key.get('bookingId') === booking.id;
    if (booking.state === 'confirmed' && !holds)
      problems.push(`active Booking ${String(booking.id)} has no active key`);
    if (booking.state !== 'confirmed' && holds)
      problems.push(`cancelled Booking ${String(booking.id)} still holds its active key`);
  }

  const outbox = await firestore.collection(bookingCollections.outbox).get();
  const outboxIds = new Set(outbox.docs.map((document) => document.id));
  for (const booking of bookings) {
    for (let revision = 1; revision <= Number(booking.revision); revision += 1)
      if (!outboxIds.has(`${String(booking.id)}__r${String(revision)}`))
        problems.push(`Booking ${String(booking.id)} r${String(revision)} has no outbox record`);
    const extra = [...outboxIds].filter(
      (id) =>
        id.startsWith(`${String(booking.id)}__r`) &&
        Number(id.slice(String(booking.id).length + 3)) > Number(booking.revision),
    );
    if (extra.length > 0)
      problems.push(`Booking ${String(booking.id)} has outbox beyond its revision`);
  }

  const items = (await firestore.collection(notificationCollections.inboxItems).get()).docs.map(
    (document) => document.data(),
  );
  const byReceipt = new Map<string, number>();
  const bySource = new Map<string, number>();
  for (const item of items) {
    byReceipt.set(String(item.receiptId), (byReceipt.get(String(item.receiptId)) ?? 0) + 1);
    const source = item.sourceRef as { id: string; revision: number } | undefined;
    const sourceKey = `${String(source?.id)}#${String(source?.revision)}`;
    bySource.set(sourceKey, (bySource.get(sourceKey) ?? 0) + 1);
  }
  for (const [receipt, count] of byReceipt)
    if (count > 1) problems.push(`inbox: ${String(count)} records for receipt ${receipt}`);
  for (const [source, count] of bySource)
    if (count > 1) problems.push(`inbox: ${String(count)} records for Booking revision ${source}`);
  return problems;
}
