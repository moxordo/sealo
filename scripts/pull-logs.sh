#!/usr/bin/env bash
#
# scripts/pull-logs.sh — copy Sealo's JSONL log file off the iPhone.
#
# After reproducing a bug on the device, run this. It grabs the
# log file from the App Group container via `xcrun devicectl` and
# writes it to build/device-logs.jsonl. Claude Code (or you) can
# then read that file directly — no Console.app, no copy/paste.
#
# Usage:
#   ./scripts/pull-logs.sh                  # default output path
#   ./scripts/pull-logs.sh /tmp/foo.jsonl   # custom output path
#   ./scripts/pull-logs.sh --tail 50        # print last 50 entries
#   ./scripts/pull-logs.sh --clear          # delete the on-device log

set -o pipefail
set -u

APP_BUNDLE_ID="com.moxordo.sealo"
APP_GROUP_ID="group.com.moxordo.sealo"
APP_GROUP_FILE="sealo-events.log"
OUTPUT="${1:-build/device-logs.jsonl}"

# ------------------------------------------------------------- helpers

log()  { printf '\033[36m[pull-logs]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[pull-logs] FATAL:\033[0m %s\n' "$*" >&2; exit 1; }

find_device_udid() {
    local out
    out=$(xcrun devicectl list devices 2>/dev/null \
        | awk 'NR>2 && /connected/ { print $3; exit }')
    [[ -n "$out" ]] || die "no connected device found via devicectl"
    echo "$out"
}

# ------------------------------------------------------------- flags

case "${1:-}" in
    --tail)
        shift
        N="${1:-20}"
        [[ -f build/device-logs.jsonl ]] || die "no local logs yet; run without --tail first"
        python3 -c "
import json, sys
with open('build/device-logs.jsonl') as f:
    lines = f.readlines()[-${N}:]
for line in lines:
    try:
        e = json.loads(line)
        print(f\"{e['t']}  {e['src']:7s} {e['cat']:8s} {e['lvl']:6s} {e['msg']}\")
    except Exception:
        print(line.rstrip())
"
        exit 0
        ;;
    --clear)
        # Just delete the local file; next run rewrites from device.
        rm -f build/device-logs.jsonl
        log "cleared local log file"
        exit 0
        ;;
esac

# ------------------------------------------------------------- main

UDID=$(find_device_udid)
log "device: $UDID"
mkdir -p "$(dirname "$OUTPUT")"

# The App Group container is accessible via devicectl by reference
# to any containing-app bundle ID + the group ID. The actual path
# on-device looks like:
#   /private/var/mobile/Containers/Shared/AppGroup/<uuid>/sealo-events.log
# but devicectl's copy command accepts the app-relative "appDataContainer"
# domain which transparently resolves it.

log "pulling $APP_GROUP_FILE from $APP_GROUP_ID..."

# App Group containers are shared between the main app and the
# monitor extension. devicectl's appGroupDataContainer domain is
# the right selector; the identifier is the App Group ID (not the
# main bundle ID, which is what appDataContainer uses).
xcrun devicectl device copy from \
    --device "$UDID" \
    --source "$APP_GROUP_FILE" \
    --domain-type appGroupDataContainer \
    --domain-identifier "$APP_GROUP_ID" \
    --destination "$OUTPUT" 2>&1 \
|| die "could not pull log file. Verify the app has run at least once, Developer Mode is on, and the App Group is correctly configured in both App IDs."

if [[ -s "$OUTPUT" ]]; then
    LINES=$(wc -l < "$OUTPUT" | tr -d ' ')
    log "pulled $LINES entries into $OUTPUT"
    log "tail:"
    tail -3 "$OUTPUT" | while read -r line; do
        printf '  %s\n' "$line" | head -c 200
        printf '\n'
    done
else
    log "WARN: output file is empty. The app may not have logged anything yet."
fi
