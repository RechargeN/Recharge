# N3b media-tools image: one image, three roles (scanner, processor, mirror job),
# selected by RECHARGE_TOOLS_MODE. Built only by Cloud Build with the dedicated
# build service account (D-12). Base pinned by digest (multi-arch index of
# debian:bookworm-slim read 2026-11-06); Node, ClamAV and sharp pinned by
# apps/backend/media-tools.lock.json and verified in fetch-verify.sh.
ARG BASE=debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc

FROM ${BASE} AS fetch
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg xz-utils openssl \
 && rm -rf /var/lib/apt/lists/*
COPY tools.lock.env npm.list fetch-verify.sh /build/
RUN sh /build/fetch-verify.sh

FROM ${BASE}
# ca-certificates: freshclam's HTTPS to the official mirror. The libraries are the
# usual runtime set of the Talos .deb; the build fails below if any is missing.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libssl3 libcurl4 libxml2 \
      libjson-c5 libbz2-1.0 libpcre2-8-0 zlib1g libncurses6 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --no-create-home --home-dir /tmp --shell /usr/sbin/nologin tools
COPY --from=fetch /opt/node /opt/node
COPY --from=fetch /opt/clamav /opt/clamav
COPY --from=fetch /opt/app/node_modules /app/node_modules
COPY app/ /app/
COPY start.sh /app/start.sh

# Build-time proof: no missing shared library, clamd 1.5.4 answers, sharp loads its
# native linux-x64 binding with the D1 loader restrictions.
RUN set -eu; . /opt/clamav/env.sh; \
    if ldd "$CLAMD" "$FRESHCLAM" | grep 'not found'; then exit 1; fi; \
    printf 'TCPSocket 3310\nTCPAddr 127.0.0.1\nDatabaseDirectory /tmp\n' > /tmp/probe.conf; \
    "$CLAMD" --config-file=/tmp/probe.conf --version | grep -q '^ClamAV 1\.5\.4'; \
    rm /tmp/probe.conf; \
    /opt/node/bin/node -e "import('/app/dist/functions/src/modules/media/infrastructure/image_pipeline.js').then((m) => { const r = m.configurePipeline(); if (!r.native) process.exit(1); console.log(r.toolRevision); })"; \
    chmod 0555 /app/start.sh

USER 10001
ENV NODE_ENV=production
ENTRYPOINT ["/app/start.sh"]
