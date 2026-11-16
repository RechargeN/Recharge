import { createHash, randomBytes } from "node:crypto";
import { writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// N4c operator tool (owner choice 2026-11-16: synthetic participants and
// synthetic events). Staging only. Writes, with the operator's own credentials:
//   - synthetic Booking actors (account, Session, access snapshot) n4cloadNNNN;
//   - synthetic Event projections occ_n4cload_* through the ordinary Event
//     outbox delivery, the same path the Emulator tests use.
// Nothing is deleted. The Session handles go to a private file, never to Git.
export const stagingProject = "recharge-staging-y9y2y";
export const actorId = (index) => `n4cload${String(index).padStart(4, "0")}`;

export function actorRecords(index, handle, now) {
  const uid = actorId(index);
  const sessionId = `n4cload-session-${String(index).padStart(4, "0")}`;
  const installationId = `n4cload-install-${String(index).padStart(4, "0")}`;
  const issuedAtUtc = now.toISOString();
  return {
    uid,
    sessionContext: { sessionId, sessionHandle: handle, installationId },
    account: {
      schemaVersion: 1,
      userId: uid,
      status: "active",
      revision: 1,
      securityRevision: 1,
      revokeBeforeSecurityRevision: 0,
      createdAtUtc: issuedAtUtc,
      updatedAtUtc: issuedAtUtc,
    },
    session: {
      schemaVersion: 1,
      sessionId,
      userId: uid,
      status: "active",
      revision: 1,
      authzRevision: 1,
      firebaseUid: uid,
      installationId,
      handleHash: createHash("sha256").update(handle, "utf8").digest("hex"),
      issuedAtUtc,
      lastSeenAtUtc: issuedAtUtc,
      idleExpiresAtUtc: new Date(now.getTime() + 2 * 86_400_000).toISOString(),
    },
    accessSnapshot: {
      schemaVersion: 1,
      userId: uid,
      sessionId,
      accountRevision: 1,
      sessionRevision: 1,
      authzRevision: 1,
      capabilityPolicyRevision: 1,
      capabilityIds: ["booking.self_service"],
      evaluatedAtUtc: issuedAtUtc,
      // A load run is hours, not the interactive 60 minutes.
      expiresAtUtc: new Date(now.getTime() + 8 * 3_600_000).toISOString(),
    },
  };
}

export function syntheticEvent(runId, name, totalCapacity, now) {
  const day = 86_400_000;
  return {
    schemaVersion: 1,
    eventId: `evt_n4cload_${runId}_${name}`,
    occurrenceId: `occ_n4cload_${runId}_${name}`,
    marketId: "LV",
    publisherRef: { type: "page", id: "page_n4cload_synthetic" },
    materialRevision: 1,
    occurrenceStartsAt: new Date(now.getTime() + 3 * day).toISOString(),
    occurrenceEndsAt: new Date(
      now.getTime() + 3 * day + 3_600_000,
    ).toISOString(),
    lifecycle: "published",
    bookingEnabled: true,
    registrationMode: "internal",
    pricingMode: "free",
    paymentCollectionMode: "none",
    confirmationMode: "instant",
    inventoryAuthority: "internal",
    inventoryShape: "general",
    capacityMode: "finite",
    totalCapacity,
    poolId: `pool_n4cload_${name}`,
    channel: "onsite",
    registrationWindow: {
      opensAt: new Date(now.getTime() - day).toISOString(),
      closesAt: new Date(now.getTime() + 2 * day).toISOString(),
    },
    cancellationDeadline: new Date(now.getTime() + 2 * day).toISOString(),
    guestPolicy: { mode: "partyWithoutNames", maximumParticipantUnits: 21 },
    eligibilityMode: "open",
  };
}

async function main() {
  const [runId, actorsArg, poolRoundsArg, outFile] = process.argv.slice(2);
  const actors = Number(actorsArg);
  const poolRounds = Number(poolRoundsArg);
  if (
    !/^[a-z0-9]{4,20}$/u.test(runId ?? "") ||
    !Number.isSafeInteger(actors) ||
    actors < 1 ||
    actors > 400 ||
    !Number.isSafeInteger(poolRounds) ||
    poolRounds < 0 ||
    poolRounds > 20 ||
    !outFile
  )
    throw new Error(
      "usage: node n4c-load-seed.mjs <runId> <actors 1..400> <poolRounds 0..20> <private-out.json>",
    );
  if (
    process.env.GCLOUD_PROJECT !== stagingProject ||
    process.env.FIRESTORE_EMULATOR_HOST !== undefined
  )
    throw new Error("staging only: set GCLOUD_PROJECT to the staging project");
  const backend = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "..",
  );
  const lib = (rel) =>
    import(pathToFileURL(path.join(backend, "functions", "lib", rel)).href);
  const require = createRequire(
    path.join(backend, "functions", "package.json"),
  );
  const { initializeApp, applicationDefault } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const { seedEventBookingOutbox } = await lib(
    "test/support/event_outbox_seed.js",
  );
  const { deliverEventBookingProjection } = await lib(
    "src/booking/event_projection_delivery.js",
  );
  const firestore = getFirestore(
    initializeApp(
      { projectId: stagingProject, credential: applicationDefault() },
      "n4c-load-seed",
    ),
  );
  const now = new Date();
  const contexts = [];
  for (let start = 1; start <= actors; start += 100) {
    const batch = firestore.batch();
    for (let i = start; i < Math.min(start + 100, actors + 1); i += 1) {
      const record = actorRecords(
        i,
        randomBytes(32).toString("base64url"),
        now,
      );
      batch.set(
        firestore.collection("identityAccounts").doc(record.uid),
        record.account,
      );
      batch.set(
        firestore
          .collection("identitySessions")
          .doc(record.sessionContext.sessionId),
        record.session,
      );
      batch.set(
        firestore
          .collection("identityAccessSnapshots")
          .doc(record.sessionContext.sessionId),
        record.accessSnapshot,
      );
      contexts.push({ uid: record.uid, sessionContext: record.sessionContext });
    }
    await batch.commit();
  }
  const events = [
    syntheticEvent(runId, "open", 100_000, now),
    ...Array.from({ length: poolRounds }, (_, round) =>
      syntheticEvent(runId, `pool${String(round).padStart(2, "0")}`, 10, now),
    ),
  ];
  for (const event of events) {
    const outboxId = createHash("sha256")
      .update(
        `n4c-load-seed-v1|${event.eventId}|${event.occurrenceId}|${event.materialRevision}`,
      )
      .digest("hex");
    const enqueued = await seedEventBookingOutbox(firestore, {
      outboxId,
      event: {
        kind: "EventRevisionPublished",
        eventId: event.eventId,
        occurrenceId: event.occurrenceId,
        publicationRevision: event.materialRevision,
        materialRevision: event.materialRevision,
        occurredAt: now.toISOString(),
        projection: event,
      },
    });
    if (enqueued === "conflict")
      throw new Error(`event ${event.occurrenceId} exists with other content`);
    const delivered = await deliverEventBookingProjection(
      firestore,
      outboxId,
      new Date().toISOString(),
    );
    if (delivered !== "delivered" && delivered !== "replayed")
      throw new Error(`event ${event.occurrenceId} delivery: ${delivered}`);
  }
  writeFileSync(
    outFile,
    JSON.stringify(
      {
        schemaVersion: 1,
        projectId: stagingProject,
        runId,
        seededAtUtc: now.toISOString(),
        actors: contexts,
        events: events.map((e) => ({
          eventId: e.eventId,
          occurrenceId: e.occurrenceId,
          poolId: e.poolId,
          totalCapacity: e.totalCapacity,
          materialRevision: e.materialRevision,
        })),
      },
      null,
      2,
    ) + "\n",
  );
  process.stdout.write(
    `seeded ${contexts.length} synthetic actors and ${events.length} synthetic events (run ${runId})\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href)
  main().catch((error) => {
    process.stderr.write(`n4c-load-seed: ${error.message}\n`);
    process.exitCode = 1;
  });
