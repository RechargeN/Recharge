import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const functionsRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "functions",
);
const commands = [
  "verify:cloud-context",
  "verify:r1:layout",
  "verify:r1:config",
  "verify:r1:exports",
  "format:check",
  "lint",
  "typecheck",
  "test:unit",
  "test:contract",
  "test:r1:integration",
  "verify:reproducibility",
];
for (const command of commands) {
  const npmEntry = process.env.npm_execpath;
  if (npmEntry === undefined)
    throw new Error("R1 gate runner requires npm_execpath");
  const result = spawnSync(process.execPath, [npmEntry, "run", command], {
    cwd: functionsRoot,
    stdio: "inherit",
    shell: false,
  });
  if (result.error !== undefined) {
    throw new Error(
      `R1 gate could not start: ${command}: ${result.error.message}`,
    );
  }
  if (result.status !== 0) throw new Error(`R1 gate failed: ${command}`);
}
process.stdout.write(
  "All credential-free local R1 gates passed. Emulator remains an explicit separate gate.\n",
);
