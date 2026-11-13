#!/bin/sh
# Build stage only. Fetches the pinned artifacts of apps/backend/media-tools.lock.json
# (rendered into tools.lock.env / npm.list by the stage script) and refuses any
# byte that does not match: SHA-256 for Node and the ClamAV .deb, GPG signature by
# the Cisco Talos key (itself pinned by SHA-256 and fingerprint), npm SRI sha512.
set -eu
. /build/tools.lock.env

fetch() { curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --max-time 600 -o "$2" "$1"; }
sha() { echo "$2  $1" | sha256sum -c - >/dev/null || { echo "SHA-256 mismatch: $1" >&2; exit 1; }; }

mkdir -p /fetch /opt/node /opt/clamav /opt/app/node_modules
cd /fetch

# Node.js
fetch "$NODE_URL" node.tar.xz
sha node.tar.xz "$NODE_SHA256"
tar -xJf node.tar.xz -C /opt/node --strip-components=1
/opt/node/bin/node --version | grep -qx "$NODE_VERSION"

# ClamAV .deb: SHA-256, then GPG by the pinned Talos key; extracted, never installed.
fetch "$CLAMAV_DEB_URL" clamav.deb
sha clamav.deb "$CLAMAV_DEB_SHA256"
fetch "$CLAMAV_SIG_URL" clamav.deb.sig
sha clamav.deb.sig "$CLAMAV_SIG_SHA256"
fetch "$TALOS_KEY_URL" talos.gpg
sha talos.gpg "$TALOS_KEY_SHA256"
export GNUPGHOME=/fetch/gnupg
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import talos.gpg
gpg --batch --status-fd 1 --verify clamav.deb.sig clamav.deb > gpg.status
grep -q "^\[GNUPG:\] VALIDSIG $TALOS_FINGERPRINT " gpg.status || { echo "GPG: not signed by $TALOS_FINGERPRINT" >&2; exit 1; }
dpkg-deb -x clamav.deb /opt/clamav/root

CLAMD=$(find /opt/clamav/root -type f -name clamd | head -n 1)
FRESHCLAM=$(find /opt/clamav/root -type f -name freshclam | head -n 1)
CERTS=/opt/clamav/root/usr/local/etc/certs
test -n "$CLAMD" && test -n "$FRESHCLAM" && test -s "$CERTS/clamav.crt"
LIBS=$(find /opt/clamav/root -type f -name 'libclamav.so*' -exec dirname {} \; | sort -u | tr '\n' ':')
cat > /opt/clamav/env.sh <<ENV
CLAMD=$CLAMD
FRESHCLAM=$FRESHCLAM
CVD_CERTS_DIR=$CERTS
LD_LIBRARY_PATH=${LIBS%:}
export CLAMD FRESHCLAM CVD_CERTS_DIR LD_LIBRARY_PATH
ENV

# sharp and its closure for linux-x64 glibc, by npm SRI (sha512).
while IFS='|' read -r name url integrity; do
  [ -n "$name" ] || continue
  fetch "$url" pkg.tgz
  got="sha512-$(openssl dgst -sha512 -binary pkg.tgz | base64 -w0)"
  [ "$got" = "$integrity" ] || { echo "SRI mismatch: $name" >&2; exit 1; }
  mkdir -p "/opt/app/node_modules/$name"
  tar -xzf pkg.tgz -C "/opt/app/node_modules/$name" --strip-components=1 --no-same-owner
  rm pkg.tgz
done < /build/npm.list
