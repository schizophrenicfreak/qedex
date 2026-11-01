#!/usr/bin/env bash
command -v jq >/dev/null || { echo '{"call":"INSTALL JQ","type":"-","reg":"-","alt":"-","spd":"-","hdg":"-","dist":"-","brg":"-","when":"ERROR"}'; exit 0; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/config.json"
LAT=$(jq -r '.location.lat' "$CFG"); LON=$(jq -r '.location.lon' "$CFG")
R=$(jq -r '.plane_radius_nm // 250' "$CFG")
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-edex-plane.json"
mkdir -p "$(dirname "$CACHE")"
NOW=$(date +%s)
fetch() { curl -s -m 8 -A quickshell-edex "$1/v2/point/$LAT/$LON/$R"; }
J=$(fetch https://api.adsb.lol)
LIVE=$(echo "$J" | jq -c --argjson la $LAT --argjson lo $LON --argjson now $NOW '
  [(.ac // [])[] | select(.lat != null and .lon != null)
   | ((.lon-$lo) * (($la*0.0174533)|cos)) as $dx
   | (.lat-$la) as $dy
   | ((.flight // "") | gsub("\\s+";"")) as $f
   | {call: (if $f == "" then (.r // .hex // "?") else $f end),
      type: (.t // "-"), reg: (.r // "-"),
      alt: (if .alt_baro == "ground" then "GND" elif .alt_baro then "\(.alt_baro) ft" else "-" end),
      spd: (if .gs then "\(.gs|round) kt" else "-" end),
      hdg: (if .track then "\(.track|round)°" else "-" end),
      d: (60*(($dx*$dx+$dy*$dy)|sqrt)),
      b: (((atan2($dx;$dy)*57.29578)+360)%360|floor)}]
  | sort_by(.d) | .[0] | select(. != null)
  | .dist = "\(.d|round) nm" | .brg = "\(.b)°" | del(.d,.b) | . + {ts: $now}' 2>/dev/null)
if [ -n "$LIVE" ]; then
  echo "$LIVE" > "$CACHE"
  echo "$LIVE" | jq -c '. + {when: "LIVE"}'
elif [ -s "$CACHE" ]; then
  jq -c --argjson now $NOW '(($now - .ts)) as $a | . + {when: (if $a < 3600 then "SEEN \($a/60|floor)m AGO" elif $a < 86400 then "SEEN \($a/3600|floor)h AGO" else "SEEN \($a/86400|floor)d AGO" end)}' "$CACHE"
else
  echo '{"call":"NONE YET","type":"-","reg":"-","alt":"-","spd":"-","hdg":"-","dist":"-","brg":"-","when":"WAITING"}'
fi
