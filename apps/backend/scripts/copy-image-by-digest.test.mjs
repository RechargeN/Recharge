import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

import { copyImageByDigest, parseRepository } from "./copy-image-by-digest.mjs";

const sha = (bytes) =>
  `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
const source =
  "europe-west1-docker.pkg.dev/recharge-dev-n2a01/media-tools/media-tools";
const destination =
  "europe-west1-docker.pkg.dev/recharge-staging-y9y2y/media-tools/media-tools";

function registry({ corruptBlob = false } = {}) {
  const config = Buffer.from('{"architecture":"amd64"}');
  const layer = Buffer.from("layer-bytes");
  const manifest = Buffer.from(
    JSON.stringify({
      schemaVersion: 2,
      mediaType: "application/vnd.oci.image.manifest.v1+json",
      config: { digest: sha(config) },
      layers: [{ digest: sha(layer) }],
    }),
  );
  const store = {
    src: new Map([
      [sha(config), corruptBlob ? Buffer.from("x") : config],
      [sha(layer), layer],
    ]),
    dst: new Map(),
    manifests: new Map(),
  };
  const calls = [];
  const response = (status, body = Buffer.alloc(0), headers = {}) => ({
    status,
    headers: { get: (name) => headers[name.toLowerCase()] ?? null },
    arrayBuffer: async () => body,
  });
  const fetchImpl = async (url, init = {}) => {
    const method = init.method ?? "GET";
    calls.push(`${method} ${url}`);
    assert.match(init.headers.Authorization, /^Bearer /u);
    const u = new URL(url);
    const dst = u.pathname.includes("recharge-staging-y9y2y");
    const blob = /\/blobs\/(sha256:[0-9a-f]{64})$/u.exec(u.pathname)?.[1];
    const ref = /\/manifests\/(sha256:[0-9a-f]{64})$/u.exec(u.pathname)?.[1];
    if (method === "HEAD") return response(store.dst.has(blob) ? 200 : 404);
    if (method === "GET" && blob) return response(200, store.src.get(blob));
    if (method === "GET" && ref) {
      const bytes = dst ? store.manifests.get(ref) : manifest;
      return bytes
        ? response(200, bytes, {
            "content-type": "application/vnd.oci.image.manifest.v1+json",
          })
        : response(404);
    }
    if (method === "POST")
      return response(202, undefined, { location: "/v2/upload/abc?state=1" });
    if (method === "PUT" && u.pathname.startsWith("/v2/upload/")) {
      store.dst.set(u.searchParams.get("digest"), init.body);
      return response(201);
    }
    if (method === "PUT" && ref) {
      store.manifests.set(ref, init.body);
      return response(201, undefined, { "docker-content-digest": ref });
    }
    return response(500);
  };
  return { fetchImpl, calls, digest: sha(manifest), store };
}

test("copies a manifest and its blobs byte for byte, same digest", async () => {
  const r = registry();
  const result = await copyImageByDigest({
    source,
    destination,
    digest: r.digest,
    token: "t",
    fetchImpl: r.fetchImpl,
  });
  assert.equal(result.digest, r.digest);
  assert.equal(result.blobsCopied, 2);
  assert.ok(!r.calls.some((c) => c.startsWith("DELETE")));
  // A second run reuses every blob.
  const again = await copyImageByDigest({
    source,
    destination,
    digest: r.digest,
    token: "t",
    fetchImpl: r.fetchImpl,
  });
  assert.equal(again.blobsReused, 2);
});

test("a blob that does not match its digest stops the copy", async () => {
  const r = registry({ corruptBlob: true });
  await assert.rejects(
    copyImageByDigest({
      source,
      destination,
      digest: r.digest,
      token: "t",
      fetchImpl: r.fetchImpl,
    }),
    /does not match its digest/u,
  );
});

test("only Artifact Registry repositories on one host, only sha256 digests", async () => {
  assert.throws(() => parseRepository("docker.io/library/node"));
  await assert.rejects(
    copyImageByDigest({ source, destination, digest: "latest", token: "t" }),
    /sha256/u,
  );
  await assert.rejects(
    copyImageByDigest({
      source,
      destination:
        "us-docker.pkg.dev/recharge-staging-y9y2y/media-tools/media-tools",
      digest: `sha256:${"a".repeat(64)}`,
      token: "t",
    }),
    /share the registry host/u,
  );
});
