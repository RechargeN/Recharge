#!/bin/sh
# N3b entry of the one media-tools image. RECHARGE_TOOLS_MODE picks the role:
#   scanner    newest mirror set -> clamd on 127.0.0.1 -> host on $PORT
#   processor  host on $PORT (sharp worker)
#   mirror     freshclam (official mirror, CVD signatures checked) -> publish
# Nothing here deletes or overwrites cloud data (D-07).
set -eu

NODE=/opt/node/bin/node
APP=/app/dist/media-tools-runtime/src
CLAMAV=/opt/clamav
. "$CLAMAV/env.sh"

case "${RECHARGE_TOOLS_MODE:-}" in
  scanner)
    DB=/tmp/clamdb
    mkdir -p "$DB" /tmp/clamtmp
    if "$NODE" "$APP/scanner_prepare.js" fetch "$DB"; then
      cat > /tmp/clamd.conf <<CONF
TCPSocket ${RECHARGE_TOOLS_CLAMD_PORT:-3310}
TCPAddr 127.0.0.1
Foreground yes
DatabaseDirectory $DB
TemporaryDirectory /tmp/clamtmp
LogFile /dev/stderr
LogFileUnlock yes
LogTime yes
MaxThreads 2
MaxQueue 4
MaxConnectionQueueLength 4
ReadTimeout 10
CommandReadTimeout 5
SendBufTimeout 500
IdleTimeout 30
StreamMaxLength 2M
MaxScanSize 8M
MaxFileSize 4M
MaxRecursion 8
MaxFiles 100
MaxScanTime 10000
AlertExceedsMax yes
AlertBrokenMedia yes
AlertEncrypted yes
Bytecode yes
SelfCheck 0
ConcurrentDatabaseReload no
CVDCertsDirectory $CVD_CERTS_DIR
CONF
      "$CLAMD" --config-file=/tmp/clamd.conf &
      # Up to 200 s of the 240 s startup probe; afterwards the host starts
      # anyway and every scan is inconclusive until clamd answers.
      "$NODE" "$APP/scanner_prepare.js" await-clamd "${RECHARGE_TOOLS_CLAMD_PORT:-3310}" 200 || true
    fi
    exec "$NODE" "$APP/cloud_tools_host.js"
    ;;
  processor)
    exec "$NODE" "$APP/cloud_tools_host.js"
    ;;
  mirror)
    FRESH=/tmp/fresh
    mkdir -p "$FRESH"
    cat > /tmp/freshclam.conf <<CONF
DatabaseDirectory $FRESH
DatabaseMirror database.clamav.net
DNSDatabaseInfo current.cvd.clamav.net
ScriptedUpdates no
TestDatabases yes
Foreground yes
CVDCertsDirectory $CVD_CERTS_DIR
CONF
    "$FRESHCLAM" --config-file=/tmp/freshclam.conf --stdout
    exec "$NODE" "$APP/publish_databases.js" "$FRESH"
    ;;
  *)
    echo '{"kind":"media-tools-start-refused","reason":"RECHARGE_TOOLS_MODE"}'
    exit 64
    ;;
esac
