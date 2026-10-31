#!/bin/bash
# v0.9 updater end-to-end test on Linux (docs/UPDATER.md). Exports the Linux build and serves a fake releases list
# with a "v9.9.9" whose Linux asset is a tiny script. It then runs the real game with --update-selftest:
# check -> download -> SHA-256 verify -> helper swaps the binary -> relaunch (the new "binary" writes a marker).
# A second run uses a wrong checksum and must refuse the update.
set -u
G=${G:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d /tmp/mera_upd.XXXX)
PORT=${PORT:-8765}
mkdir -p "$W/game" "$W/srv"
"$G" --headless --path "$ROOT" --export-release "Linux" "$W/game/Mera_Playable.x86_64" >/dev/null 2>&1 || { echo "export failed"; exit 1; }
NEW="$W/srv/Mera_Playable_v9.9.9_Linux.x86_64"
printf '#!/bin/sh\necho UPDATED > "%s/marker"\n' "$W" > "$NEW"
make_srv() {  # $1 = sha to publish
  ( cd "$W/srv" && printf '%s  Mera_Playable_v9.9.9_Linux.x86_64\n' "$1" > SHA256SUMS.txt )
  SIZE=$(stat -c %s "$NEW")
  cat > "$W/srv/releases.json" <<JSON
[{"tag_name":"v9.9.9-playable","name":"test","draft":false,"prerelease":true,"html_url":"http://127.0.0.1:$PORT/",
  "assets":[{"name":"Mera_Playable_v9.9.9_Linux.x86_64","size":$SIZE,"browser_download_url":"http://127.0.0.1:$PORT/Mera_Playable_v9.9.9_Linux.x86_64"},
            {"name":"SHA256SUMS.txt","size":1,"browser_download_url":"http://127.0.0.1:$PORT/SHA256SUMS.txt"}]},
 {"tag_name":"v0.8.2-playable","name":"old","draft":false,"assets":[]}]
JSON
}
( cd "$W/srv" && exec python3 -m http.server $PORT --bind 127.0.0.1 >/dev/null 2>&1 ) &
SRV=$!
sleep 1
fail=0
# 1) bad checksum: must refuse, keep the old binary
make_srv "$(printf '0%.0s' $(seq 64))"
OLD_SUM=$(sha256sum "$W/game/Mera_Playable.x86_64" | cut -d' ' -f1)
MERA_UPDATE_API="http://127.0.0.1:$PORT/releases.json" timeout 60 "$W/game/Mera_Playable.x86_64" --headless -- --update-selftest > "$W/bad.log" 2>&1
grep "UPDATE-SELFTEST" "$W/bad.log"
if grep -q "download: error" "$W/bad.log" && [ "$(sha256sum "$W/game/Mera_Playable.x86_64" | cut -d' ' -f1)" = "$OLD_SUM" ] && [ ! -e "$W/game/Mera_Playable_v9.9.9_Linux.x86_64.new" ]; then echo "PASS bad checksum refused, old binary kept, download deleted"; else echo "FAIL bad checksum"; fail=1; fi
# 2) good checksum: swap + relaunch
make_srv "$(sha256sum "$NEW" | cut -d' ' -f1)"
MERA_UPDATE_API="http://127.0.0.1:$PORT/releases.json" timeout 60 "$W/game/Mera_Playable.x86_64" --headless -- --update-selftest > "$W/good.log" 2>&1
grep "UPDATE-SELFTEST" "$W/good.log"
for i in $(seq 1 40); do [ -e "$W/marker" ] && break; sleep 0.25; done
if [ -e "$W/marker" ] && cmp -s "$NEW" "$W/game/Mera_Playable.x86_64" && [ ! -e "$W/game/mera_update.sh" ]; then echo "PASS verified download swapped in after exit, relaunched, helper removed"; else echo "FAIL swap/relaunch"; fail=1; fi
# 3) offline: graceful
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
"$G" --headless --path "$ROOT" --export-release "Linux" "$W/game/Mera_Playable.x86_64" >/dev/null 2>&1
MERA_UPDATE_API="http://127.0.0.1:$PORT/releases.json" timeout 60 "$W/game/Mera_Playable.x86_64" --headless -- --update-selftest > "$W/off.log" 2>&1
grep "UPDATE-SELFTEST" "$W/off.log"
if grep -q "check: error" "$W/off.log"; then echo "PASS offline -> graceful error"; else echo "FAIL offline"; fail=1; fi
rm -rf "$W"
exit $fail
