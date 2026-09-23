import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const functionsRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "functions",
);
const npmEntry = process.env.npm_execpath;
if (npmEntry === undefined)
  throw new Error("Security/privacy contract gate requires npm_execpath");
for (const command of ["build", "test:security-privacy:contract"]) {
  const result = spawnSync(
    process.execPath,
    [npmEntry, "run", command, "--silent"],
    { cwd: functionsRoot, stdio: "inherit", shell: false },
  );
  if (result.error !== undefined) throw result.error;
  if (result.status !== 0)
    throw new Error(`Security/privacy contract gate failed: ${command}`);
}
process.stdout.write("Security/privacy schema and fixture parity passed.\n");
