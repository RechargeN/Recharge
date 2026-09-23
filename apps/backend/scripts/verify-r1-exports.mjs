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
  "getEventAvailabilityV1",
  "getMyBookingV1",
  "listMyBookingsV1",
  "r0ToolchainProbe",
].sort();
if (JSON.stringify(exports) !== JSON.stringify(expected)) {
  throw new Error(`Unexpected function export surface: ${exports.join(", ")}`);
}
if (/onSchedule|onTaskDispatched|pubsub|platform\/bootstrap/u.test(source)) {
  throw new Error(
    "R1 cannot add workers, schedules or platform callable exports",
  );
}
process.stdout.write(
  "R1 export gate passed: R0 plus five disabled RAW-C callables only.\n",
);
