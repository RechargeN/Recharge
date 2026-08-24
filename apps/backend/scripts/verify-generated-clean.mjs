import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const libRoot = path.join(backendRoot, "functions", "lib");
const normalizedBackendRoot = backendRoot.replaceAll("\\", "/").toLowerCase();

async function collectFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(child)));
    } else {
      files.push(child);
    }
  }
  return files;
}

const files = await collectFiles(libRoot);
if (files.length === 0) {
  throw new Error("functions/lib is empty; build evidence is absent");
}

for (const file of files) {
  if (!file.endsWith(".js") && !file.endsWith(".js.map")) {
    throw new Error(
      `unexpected generated file type: ${path.relative(libRoot, file)}`,
    );
  }
  const content = (await readFile(file, "utf8"))
    .replaceAll("\\", "/")
    .toLowerCase();
  if (content.includes(normalizedBackendRoot)) {
    throw new Error(
      `generated output contains an absolute workspace path: ${path.basename(file)}`,
    );
  }
}

process.stdout.write(
  `Generated-output gate passed for ${files.length} files.\n`,
);
