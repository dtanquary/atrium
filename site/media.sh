#!/bin/sh
# Renders the works on atrium.show with the app's own renderer (the snapshot test), so the site shows exactly what
# the app draws. Each work gets a seamless 30 fps loop and a poster, for desktop (2560 wide) and for phones (a 3:4
# portrait slab around the work's focal point, from the design handoff). AV1 for Chrome, Firefox and newer Safari;
# HEVC for Safari on M1 and M2, plus a small landscape copy for the laptop on portrait phones. Output goes to
# site/public/media, which is gitignored: this script is the source.
#   site/media.sh               # all of them
#   site/media.sh nebula galaxy # just these
#   site/media.sh cards         # just the cards for every wallpaper, cut from the README's screenshots
# Needs ffmpeg with libsvtav1 and libx265 (Homebrew's has both).
set -e
cd "$(dirname "$0")/.."
OUT=${OUT:-site/public/media} # OUT=/some/dir to try a roll without replacing the current one
TMP=${TMPDIR:-/tmp}/atrium-site-media
LOOP=12 FADE=2 # seconds: the loop, and the crossfade from its tail into its head that hides the seam

# slug|scene|focal x % for the phone crop|seconds in before recording|extra environment
WORKS='nebula|Nebula|54|4|SNAPSHOT_DEFAULTS=nebula.palette=Hubble
flowing-gradient|Flowing Gradient|34|4|SNAPSHOT_DEFAULTS=gradient.palette=Midnight,gradient.ribbonsOn=1
live-sky|Live Sky|72|4|SNAPSHOT_DEFAULTS=sky.previewTime=1,sky.previewHour=23
galaxy|Galaxy|48|4|SNAPSHOT_DEFAULTS=galaxy.kind=Whirlpool
murmuration|Murmuration|44|20|SNAPSHOT_DEFAULTS=murmuration.light=5,murmuration.ground=0 MURMURATION_SEED=3
fish-tank|Fish Tank|42|4|SNAPSHOT_APPEARANCE=light'

# Every wallpaper in the app, as 16:10 stills for the cards on the glass pane: slug|screenshot in docs/images.
CARDS='aurora|aurora-purple
dappled-light|dappled-light-golden
deep-space-tour|deep-space-pillars
earth-from-orbit|earth-from-orbit
fireflies|fireflies
fish-tank|fish-tank-day
flowing-gradient|flowing-gradient
galaxy|galaxy-whirlpool
game-of-life|game-of-life
lava-lamp|lava-lamp
live-sky|live-sky
murmuration|murmuration-blue-hour
nebula|nebula-hubble
pixel-city|pixel-city-dusk
pixel-spaceport|pixel-spaceport
rain-on-glass|rain-on-glass-night
schlieren|schlieren
solar-system-tour|solar-system-jupiter
turing-patterns|turing-patterns
weather|weather-sunset
wind|wind'

mkdir -p "$OUT"
if [ $# -eq 0 ] || echo " $* " | grep -q " cards "; then
    echo "$CARDS" | while IFS='|' read -r slug shot; do
        ffmpeg -nostdin -loglevel error -y -i "docs/images/$shot.jpg" \
            -vf "scale=640:400:force_original_aspect_ratio=increase:flags=lanczos,crop=640:400" -q:v 4 "$OUT/card-$slug.jpg"
    done
    echo "== cards: $(echo "$CARDS" | wc -l | tr -d ' ')"
fi
echo "$WORKS" | while IFS='|' read -r slug scene focal seconds extra; do
    [ $# -gt 0 ] && ! echo " $* " | grep -q " $slug " && continue
    dir="$TMP/$slug"
    rm -rf "$dir" && mkdir -p "$dir"
    echo "== $scene: rendering $((LOOP + FADE)) s"
    # shellcheck disable=SC2086 # $extra is a list of NAME=value words
    env SNAPSHOT_SCENE="$scene" SNAPSHOT_DIR="$dir" SNAPSHOT_SECONDS="$seconds" SNAPSHOT_MOVIE=$((LOOP + FADE)) \
        SNAPSHOT_MOVIE_FPS=30 $extra swift test -c release -Xswiftc -enable-testing --filter everySceneRenders </dev/null >"$dir/test.log" 2>&1 ||
        { tail -20 "$dir/test.log"; exit 1; }

    echo "== $scene: looping and encoding"
    # The last FADE seconds crossfade into the first FADE, so the loop's end runs straight into its start.
    ffmpeg -nostdin -loglevel error -y -framerate 30 -start_number 1 -i "$dir/$scene-%03d.png" -filter_complex \
        "[0]split[a][b];[a]trim=start=$FADE,setpts=PTS-STARTPTS[main];[b]trim=end=$FADE,setpts=PTS-STARTPTS[head];[main][head]xfade=transition=fade:duration=$FADE:offset=$((LOOP - FADE)),format=yuv420p" \
        -c:v libx264 -crf 10 -preset fast "$dir/master.mp4"
    rm -f "$dir"/*.png # about 2 GB a work; the master is enough to re-encode from

    w=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0 "$dir/master.mp4")
    h=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0 "$dir/master.mp4")
    slab=$((h * 3 / 4 / 2 * 2)) x=$((w * focal / 100 - h * 3 / 8))
    [ $x -lt 0 ] && x=0
    [ $x -gt $((w - slab)) ] && x=$((w - slab))
    for size in desktop phone laptop; do
        case $size in
            desktop) vf="scale=2560:-2:flags=lanczos" ;;
            phone) vf="crop=$slab:$h:$x:0,scale=1080:1440:flags=lanczos" ;;
            laptop) vf="scale=960:-2:flags=lanczos" ;; # the small laptop's screen on portrait phones (laptop.js)
        esac
        ffmpeg -nostdin -loglevel error -y -i "$dir/master.mp4" -vf "$vf" -an -pix_fmt yuv420p -g 150 -movflags +faststart \
            -c:v libsvtav1 -preset 5 -crf 36 -svtav1-params tune=0 "$OUT/$slug-$size.av1.mp4"
        ffmpeg -nostdin -loglevel error -y -i "$dir/master.mp4" -vf "$vf" -an -pix_fmt yuv420p -g 150 -movflags +faststart \
            -c:v libx265 -crf 26 -preset slow -tag:v hvc1 -x265-params log-level=error "$OUT/$slug-$size.hevc.mp4"
        ffmpeg -nostdin -loglevel error -y -i "$dir/master.mp4" -vf "$vf" -frames:v 1 -q:v 4 "$OUT/$slug-$size.jpg"
    done
    ls -lh "$OUT/$slug"-* | awk '{print "   " $5 "\t" $9}'
done
