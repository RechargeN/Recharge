import { createHash } from "node:crypto";
import { readdir, readFile, rm } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const functionsRoot = path.join(backendRoot, "functions");
const libRoot = path.resolve(functionsRoot, "lib");
const allowedParent = `${path.resolve(functionsRoot)}${path.sep}`;
const require = createRequire(import.meta.url);
const ts = require(
  path.join(
    functionsRoot,
    "node_modules",
    "typescript",
    "lib",
    "typescript.js",
  ),
);

if (!libRoot.startsWith(allowedParent) || path.basename(libRoot) !== "lib") {
  throw new Error("refusing to clean an unresolved generated-output path");
}

async function collect(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collect(child)));
    } else {
      files.push(child);
    }
  }
  return files.sort((left, right) => left.localeCompare(right));
}

async function logicalDigest() {
  const hash = createHash("sha256");
  for (const file of await collect(libRoot)) {
    const relative = path.relative(libRoot, file).replaceAll("\\", "/");
    hash.update(relative);
    hash.update("\0");
    hash.update(await readFile(file));
    hash.update("\0");
  }
  return hash.digest("hex");
}

function build() {
  const configPath = path.join(functionsRoot, "tsconfig.json");
  const configFile = ts.readConfigFile(configPath, ts.sys.readFile);
  if (configFile.error !== undefined) {
    throw new Error(
      ts.formatDiagnosticsWithColorAndContext([configFile.error], {
        getCanonicalFileName: (fileName) => fileName,
        getCurrentDirectory: () => functionsRoot,
        getNewLine: () => ts.sys.newLine,
      }),
    );
  }

  const parsed = ts.parseJsonConfigFileContent(
    configFile.config,
    ts.sys,
    functionsRoot,
    undefined,
    configPath,
  );
  const program = ts.createProgram(parsed.fileNames, parsed.options);
  const emit = program.emit();
  const diagnostics = [
    ...parsed.errors,
    ...ts.getPreEmitDiagnostics(program),
    ...emit.diagnostics,
  ];
  if (emit.emitSkipped || diagnostics.length > 0) {
    process.stderr.write(
      ts.formatDiagnosticsWithColorAndContext(diagnostics, {
        getCanonicalFileName: (fileName) => fileName,
        getCurrentDirectory: () => functionsRoot,
        getNewLine: () => ts.sys.newLine,
      }),
    );
    throw new Error("TypeScript reproducibility build failed");
  }
}

await rm(libRoot, { recursive: true, force: true });
build();
const first = await logicalDigest();
await rm(libRoot, { recursive: true, force: true });
build();
const second = await logicalDigest();

if (first !== second) {
  throw new Error(`logical build digest mismatch: ${first} != ${second}`);
}

process.stdout.write(`Reproducible logical build digest: ${first}\n`);
