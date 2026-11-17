import { createHash, randomBytes } from "node:crypto";
import { writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// N4c operator tool (owner choice 2026-11-16: synthetic participants and
// synthetic events). Staging only. Writes, with the operator's own credentials:
//   - synthetic Booking actors (account, Session, access snapshot) n4cloadNNNN;
//   - synthetic Event projections occ_n4cload_* through the ordinary Booking
//     projection consumer (the outbox delivery is contained in the cloud).
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

/**
 * The app's Booking test fixture (`seeded_event_fixture.dart`) as a Booking
 * projection, so the default-off test entry of a dev/stage debug build books
 * against the cloud. Same ids, revision, pool and channel as the app.
 */
export function appFixtureEvent(now) {
  const start = "2035-06-01T16:00:00.000Z";
  return {
    schemaVersion: 1,
    eventId: "evt_01JSTANDEVENTRIGAOPEN001",
    occurrenceId: "occ_01JSTANDOCCURRENCE000001",
    marketId: "LV",
    publisherRef: { type: "page", id: "page_stand_studio_fixture" },
    materialRevision: 1,
    occurrenceStartsAt: start,
    occurrenceEndsAt: "2035-06-01T19:00:00.000Z",
    lifecycle: "published",
    bookingEnabled: true,
    registrationMode: "internal",
    pricingMode: "free",
    paymentCollectionMode: "none",
    confirmationMode: "instant",
    inventoryAuthority: "internal",
    inventoryShape: "general",
    capacityMode: "finite",
    totalCapacity: 20,
    poolId: "pool_general",
    channel: "onsite",
    registrationWindow: {
      opensAt: new Date(now.getTime() - 86_400_000).toISOString(),
      closesAt: "2035-05-31T00:00:00.000Z",
    },
    cancellationDeadline: "2035-05-31T00:00:00.000Z",
    guestPolicy: { mode: "partyWithoutNames", maximumParticipantUnits: 21 },
    eligibilityMode: "open",
  };
}

async function fixture(project) {
  if (
    !["recharge-dev-n2a01", stagingProject].includes(project) ||
    process.env.GCLOUD_PROJECT !== project ||
    process.env.FIRESTORE_EMULATOR_HOST !== undefined
  )
    throw new Error(
      "dev or staging only: GCLOUD_PROJECT must name the project",
    );
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
  const { consumeEventForBookingProjection } = await lib(
    "src/booking/event_projection_consumer.js",
  );
  const firestore = getFirestore(
    initializeApp(
      { projectId: project, credential: applicationDefault() },
      "n4c-fixture",
    ),
  );
  const now = new Date();
  const event = appFixtureEvent(now);
  const result = await consumeEventForBookingProjection(firestore, {
    kind: "EventRevisionPublished",
    eventId: event.eventId,
    occurrenceId: event.occurrenceId,
    publicationRevision: 1,
    materialRevision: 1,
    occurredAt: now.toISOString(),
    projection: event,
  });
  process.stdout.write(`fixture ${project}: ${result.kind}
`);
  if (result.kind !== "applied" && result.kind !== "ignoredDuplicate")
    throw new Error(`fixture projection: ${result.kind}`);
}

async function main() {
  if (process.argv[2] === "--fixture") return fixture(process.argv[3]);
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
  // The outbox delivery is contained outside the Emulator (Operations switches
  // do not run in the cloud), so the operator feeds the same consumer directly.
  const { consumeEventForBookingProjection } = await lib(
    "src/booking/event_projection_consumer.js",
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
    const result = await consumeEventForBookingProjection(firestore, {
      kind: "EventRevisionPublished",
      eventId: event.eventId,
      occurrenceId: event.occurrenceId,
      publicationRevision: event.materialRevision,
      materialRevision: event.materialRevision,
      occurredAt: now.toISOString(),
      projection: event,
    });
    if (result.kind !== "applied" && result.kind !== "ignoredDuplicate")
      throw new Error(
        `event ${event.occurrenceId} projection: ${result.kind} ${result.code ?? ""}`,
      );
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
