#!/bin/bash
# Renders Pixel Window Seat's documented screenshots (the airliner's and the orbit's, as ../pixel-window-seat.md
# lists them, and three more with other windows) into a folder, one PNG each, so that a change which must leave
# them alone can be checked byte for byte:
#
#     docs/pixel-window-seat/shots.sh /tmp/before     # at the commit before
#     docs/pixel-window-seat/shots.sh /tmp/after      # with the change
#     for f in /tmp/before/*.png; do cmp "$f" "/tmp/after/$(basename "$f")"; done
#
# Two runs of one build come out the same files, on the same day: the airliner's pictures are of today at their
# hour, so the Sun and the Moon stand elsewhere tomorrow, and a folder kept overnight differs in a dozen of them.
# Nothing opens on screen.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?a folder for the pictures}"; mkdir -p "$OUT"; TMP=$(mktemp -d)
swift build --package-path "$ROOT" -c release -Xswiftc -enable-testing --build-tests 2>&1 | tail -1
shot() { # name seconds VAR=value…
  local name="$1" secs="$2"; shift 2
  env "$@" SNAPSHOT_SECONDS="$secs" SNAPSHOT_SCENE="Pixel Window Seat" SNAPSHOT_DIR="$TMP" \
    swift test --package-path "$ROOT" -c release -Xswiftc -enable-testing --skip-build --filter everySceneRenders 2>&1 |
    grep -E 'per frame|error|failed' | sed -e "s/^/$name: /" -e 's/ →.*//'
  mv "$TMP/Pixel Window Seat.png" "$OUT/$name.png" 2>/dev/null || echo "$name: no picture"
}
air() { shot "$1" "${5:-5}" SEAT_AT="$2" SNAPSHOT_DEFAULTS="seat.previewTime=1,seat.previewHour=$3${4:+,$4}"; } # name km hour settings seconds
orb() { shot "$1" 5 ORBIT_OVER="$2" ORBIT_DATE="2026-10-10T$3:00Z" SNAPSHOT_DEFAULTS="seat.orbit=1${4:+,$4}"; }     # name place time settings
air seat 30500 10.5
air sunset 15500 18.2 seat.looking=7
air night 27000 21.5
air countryside 6100 15
air clouds 5200 16
air city 27000 13
air coast-night 30500 23
air ahead 1000 8 seat.wing=1
air mountains 26000 8 seat.scenery=4,seat.clouds=1
air desert 12300 16.5
air snow 3300 11
air canyon 12000 18.1 seat.scenery=4,seat.clouds=1,seat.looking=7
air storm 529 22.5 "" 8.02
air view 15500 18.2 seat.looking=7,seat.window=3
air medium 30500 10.5 seat.window=1
orb orbit 22,-80,up,gold 17:00
orb orbit-dawn 25,75,down 00:40
orb orbit-night 30,-82,up 04:00
orb orbit-himalaya 25,75,down 07:00
orb orbit-ahead 34,4,up,gold 11:00 seat.orbitLooking=1
orb orbit-down 30.5,32,up 10:00 seat.orbitLooking=2
orb cupola-day 34,4,up 11:00 seat.orbitLooking=4
orb cupola-night 30,-82,up 04:00 seat.orbitLooking=4
orb cupola-into 30.5,32,up 10:00 seat.orbitLooking=3
orb orbit-none 22,-80,up 17:00 seat.window=3,seat.array=1
rm -rf "$TMP"
