import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

// N4a (owner 2026-11-13: "Образ переносить по digest без пересборки"): copies one
// image manifest and its blobs between two Artifact Registry repositories over
// the Docker Registry v2 API, byte for byte. Every blob and the manifest are
// re-hashed; the destination ends with the same digest or the copy stops.
// Nothing is deleted; existing blobs are reused. The access token comes from
// the environment and is never printed.

const manifestTypes = [
  "application/vnd.oci.image.manifest.v1+json",
  "application/vnd.docker.distribution.manifest.v2+json",
  "application/vnd.oci.image.index.v1+json",
  "application/vnd.docker.distribution.manifest.list.v2+json",
].join(", ");
const digestPattern = /^sha256:[0-9a-f]{64}$/u;
const sha = (bytes) =>
  `sha256:${createHash("sha256").update(bytes).digest("hex")}`;

/** `europe-west1-docker.pkg.dev/<project>/<repo>/<image>` → host and path. */
export function parseRepository(repository) {
  const match =
    /^([a-z0-9-]+-docker\.pkg\.dev)\/([a-z0-9-]+\/[a-z0-9-]+\/[a-z0-9-]+)$/u.exec(
      repository ?? "",
    );
  if (!match)
    throw new Error(
      "repository must be <region>-docker.pkg.dev/<project>/<repo>/<image>",
    );
  return { host: match[1], path: match[2] };
}

export async function copyImageByDigest({
  source,
  destination,
  digest,
  token,
  fetchImpl = fetch,
}) {
  if (!digestPattern.test(digest ?? ""))
    throw new Error("digest must be sha256:<64 hex>");
  const from = parseRepository(source);
  const to = parseRepository(destination);
  if (from.host !== to.host)
    throw new Error("source and destination must share the registry host");
  const auth = { Authorization: `Bearer ${token}` };
  const url = (repo, suffix) =>
    `https://${repo.host}/v2/${repo.path}/${suffix}`;
  const stats = { blobsCopied: 0, blobsReused: 0, bytes: 0 };

  async function getBytes(target, accept) {
    const response = await fetchImpl(target, {
      headers: { ...auth, ...(accept ? { Accept: accept } : {}) },
    });
    if (response.status !== 200) throw new Error(`GET ${response.status}`);
    return {
      bytes: Buffer.from(await response.arrayBuffer()),
      type: response.headers.get("content-type"),
    };
  }

  async function copyBlob(blob) {
    if (!digestPattern.test(blob)) throw new Error("blob digest invalid");
    const head = await fetchImpl(url(to, `blobs/${blob}`), {
      method: "HEAD",
      headers: auth,
    });
    if (head.status === 200) {
      stats.blobsReused += 1;
      return;
    }
    const { bytes } = await getBytes(url(from, `blobs/${blob}`));
    if (sha(bytes) !== blob)
      throw new Error("blob content does not match its digest");
    const start = await fetchImpl(url(to, "blobs/uploads/"), {
      method: "POST",
      headers: auth,
    });
    const location = start.headers.get("location");
    if (start.status !== 202 || !location)
      throw new Error(`upload start ${start.status}`);
    const target = new URL(location, `https://${to.host}`);
    target.searchParams.set("digest", blob);
    const put = await fetchImpl(target.href, {
      method: "PUT",
      headers: {
        ...auth,
        "Content-Type": "application/octet-stream",
        "Content-Length": String(bytes.length),
      },
      body: bytes,
    });
    if (put.status !== 201) throw new Error(`blob upload ${put.status}`);
    stats.blobsCopied += 1;
    stats.bytes += bytes.length;
  }

  async function copyManifest(ref) {
    const { bytes, type } = await getBytes(
      url(from, `manifests/${ref}`),
      manifestTypes,
    );
    if (sha(bytes) !== ref)
      throw new Error("manifest content does not match its digest");
    const manifest = JSON.parse(bytes.toString("utf8"));
    if (Array.isArray(manifest.manifests)) {
      for (const child of manifest.manifests) await copyManifest(child.digest);
    } else {
      await copyBlob(manifest.config?.digest);
      for (const layer of manifest.layers ?? []) await copyBlob(layer.digest);
    }
    const put = await fetchImpl(url(to, `manifests/${ref}`), {
      method: "PUT",
      headers: { ...auth, "Content-Type": type ?? manifest.mediaType },
      body: bytes,
    });
    if (put.status !== 201) throw new Error(`manifest upload ${put.status}`);
    const echoed = put.headers.get("docker-content-digest");
    if (echoed !== null && echoed !== ref)
      throw new Error("registry stored a different digest");
  }

  await copyManifest(digest);
  const check = await getBytes(url(to, `manifests/${digest}`), manifestTypes);
  if (sha(check.bytes) !== digest)
    throw new Error("destination digest differs");
  return { digest, ...stats };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [source, destination, digest] = process.argv.slice(2);
  const token = process.env.REGISTRY_ACCESS_TOKEN ?? "";
  copyImageByDigest({ source, destination, digest, token })
    .then((result) => process.stdout.write(`${JSON.stringify(result)}\n`))
    .catch((error) => {
      process.stderr.write(`image copy stopped: ${error.message}\n`);
      process.exitCode = 1;
    });
}
