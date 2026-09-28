import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const source = readFileSync(
  path.join(backendRoot, "functions", "src", "index.ts"),
  "utf8",
);
const exports = [
  ...source.matchAll(/export\s+const\s+([A-Za-z0-9_]+)/gu),
  ...source.matchAll(/export\s*\{\s*([A-Za-z0-9_]+)\s*\}/gu),
]
  .map((match) => match[1])
  .sort();
const expected = [
  "cancelInternalBookingV1",
  "createInternalBookingV1",
  "reconfirmInternalBookingV1",
  "getEventAvailabilityV1",
  "getMyBookingV1",
  "establishIdentitySessionV1",
  "refreshIdentitySessionV1",
  "recoverIdentitySessionsV1",
  "consumeEventBookingOutboxV1",
  "retryEventBookingProjectionDeliveriesV1",
  "listMyBookingsV1",
  "r0ToolchainProbe",
].sort();
if (JSON.stringify(exports) !== JSON.stringify(expected)) {
  throw new Error(`Unexpected function export surface: ${exports.join(", ")}`);
}
const schedules = [
  ...source.matchAll(/export\s+const\s+([A-Za-z0-9_]+)\s*=\s*onSchedule/gu),
].map((match) => match[1]);
if (
  JSON.stringify(schedules.sort()) !==
  JSON.stringify(["retryEventBookingProjectionDeliveriesV1"])
) {
  throw new Error(
    `Only the approved disabled Event retry schedule is allowed: ${schedules.join(", ")}`,
  );
}
process.stdout.write(
  "R1 export gate passed: bounded Booking, Session lifecycle and disabled Event delivery surface.\n",
);
