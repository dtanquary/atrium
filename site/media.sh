#!/bin/sh
# Renders the works on atrium.show with the app's own renderer (the snapshot test), so the site shows exactly what
# the app draws. Each work gets a seamless 30 fps loop and a poster, for desktop (2560 wide) and for phones (a 3:4
# portrait slab around the work's focal point, from the design handoff). AV1 for Chrome, Firefox and newer Safari;
# HEVC for Safari on M1 and M2, plus a small landscape copy for the laptop on portrait phones. Output goes to
# site/public/media, which is gitignored: this script is the source.
#   site/media.sh               # all of them
#   site/media.sh nebula pixel-city # just these
#   site/media.sh cards         # just the cards for every wallpaper, cut from the README's screenshots
#   site/media.sh previews      # just the 1280-wide loops the cards open (or preview-aurora … for some)
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
pixel-city|Pixel City|36|4|SNAPSHOT_DEFAULTS=city.place=1,city.previewTime=1,city.previewHour=18.5
murmuration|Murmuration|44|20|SNAPSHOT_DEFAULTS=murmuration.light=5,murmuration.ground=0 MURMURATION_SEED=3
fish-tank|Fish Tank|42|4|SNAPSHOT_APPEARANCE=light'

# Every wallpaper in the app, as the loop its card opens, in about the card's look:
# slug|scene|seconds in before recording|extra environment
PREVIEWS='aurora|Aurora|8|SNAPSHOT_DEFAULTS=aurora.palette=Purple,aurora.speed=2
dappled-light|Dappled Light|4|SNAPSHOT_DEFAULTS=dappled.previewTime=1,dappled.previewHour=17.5,dappled.weather=1
deep-space-tour|Deep Space Tour|4|SNAPSHOT_DEFAULTS=deep.photo=deep-pillars-webb.heic
earth-from-orbit|Earth from Orbit|4|SNAPSHOT_DEFAULTS=latitude=25,longitude=78,earth.previewStorm=1
fireflies|Fireflies|8|
fish-tank|Fish Tank|4|SNAPSHOT_APPEARANCE=light
flowing-gradient|Flowing Gradient|4|SNAPSHOT_DEFAULTS=gradient.palette=Midnight,gradient.ribbonsOn=1
galaxy|Galaxy|4|SNAPSHOT_DEFAULTS=galaxy.kind=Whirlpool,galaxy.rotation=4
game-of-life|Game of Life|30|
lava-lamp|Lava Lamp|40|LAVA_SEED=11
live-sky|Live Sky|4|SNAPSHOT_DEFAULTS=sky.previewTime=1,sky.previewHour=20.5,sky.landscape=1,sky.ground=0
murmuration|Murmuration|20|SNAPSHOT_DEFAULTS=murmuration.light=5,murmuration.ground=0 MURMURATION_SEED=3
nebula|Nebula|4|SNAPSHOT_DEFAULTS=nebula.palette=Hubble
pixel-city|Pixel City|30|SNAPSHOT_DEFAULTS=city.place=0,city.previewTime=1,city.previewHour=19
pixel-spaceport|Pixel Spaceport|19|SNAPSHOT_DEFAULTS=spaceport.previewTime=1,spaceport.previewHour=18.3
rain-on-glass|Rain on Glass|4|SNAPSHOT_DEFAULTS=rain.palette=Hamburg SNAPSHOT_APPEARANCE=dark
schlieren|Schlieren|14|SNAPSHOT_DEFAULTS=schlieren.palette=Candlelight,schlieren.filter=0,schlieren.source=0
solar-system-tour|Solar System Tour|4|SNAPSHOT_DEFAULTS=solar.photo=solar-jupiter-marble.heic
turing-patterns|Turing Patterns|40|SNAPSHOT_DEFAULTS=turing.pattern=4,turing.palette=Lagoon
weather|Weather|4|SNAPSHOT_DEFAULTS=weather.lock=2,weather.previewTime=1,weather.previewHour=18.7
wind|Wind|4|SNAPSHOT_DEFAULTS=wind.zoom=2,wind.map=2'

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
# Renders LOOP + FADE seconds of a scene into $1/master.mp4, with the last FADE seconds crossfaded into the first
# FADE, so the loop's end runs straight into its start. Args: dir scene seconds-in extra-environment.
render() {
    dir=$1
    rm -rf "$dir" && mkdir -p "$dir"
    echo "== $2: rendering $((LOOP + FADE)) s"
    # shellcheck disable=SC2086 # $4 is a list of NAME=value words
    env SNAPSHOT_SCENE="$2" SNAPSHOT_DIR="$dir" SNAPSHOT_SECONDS="$3" SNAPSHOT_MOVIE=$((LOOP + FADE)) \
        SNAPSHOT_MOVIE_FPS=30 $4 swift test -c release -Xswiftc -enable-testing --filter everySceneRenders </dev/null >"$dir/test.log" 2>&1 ||
        { tail -20 "$dir/test.log"; exit 1; }
    echo "== $2: looping and encoding"
    ffmpeg -nostdin -loglevel error -y -framerate 30 -start_number 1 -i "$dir/$2-%03d.png" -filter_complex \
        "[0]split[a][b];[a]trim=start=$FADE,setpts=PTS-STARTPTS[main];[b]trim=end=$FADE,setpts=PTS-STARTPTS[head];[main][head]xfade=transition=fade:duration=$FADE:offset=$((LOOP - FADE)),format=yuv420p" \
        -c:v libx264 -crf 10 -preset fast "$dir/master.mp4"
    rm -f "$dir"/*.png # about 2 GB a work; the master is enough to re-encode from
}

# Encodes $1 through the filter $2 as $3.av1.mp4, $3.hevc.mp4 and a poster of its first frame, $3.jpg.
encode() {
    ffmpeg -nostdin -loglevel error -y -i "$1" -vf "$2" -an -pix_fmt yuv420p -g 150 -movflags +faststart \
        -c:v libsvtav1 -preset 5 -crf 36 -svtav1-params tune=0 "$3.av1.mp4"
    ffmpeg -nostdin -loglevel error -y -i "$1" -vf "$2" -an -pix_fmt yuv420p -g 150 -movflags +faststart \
        -c:v libx265 -crf 26 -preset slow -tag:v hvc1 -x265-params log-level=error "$3.hevc.mp4"
    ffmpeg -nostdin -loglevel error -y -i "$1" -vf "$2" -frames:v 1 -q:v 4 "$3.jpg"
}

echo "$WORKS" | while IFS='|' read -r slug scene focal seconds extra; do
    [ $# -gt 0 ] && ! echo " $* " | grep -q " $slug " && continue
    dir="$TMP/$slug"
    render "$dir" "$scene" "$seconds" "$extra"
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
        encode "$dir/master.mp4" "$vf" "$OUT/$slug-$size"
    done
    ls -lh "$OUT/$slug"-* | awk '{print "   " $5 "\t" $9}'
done
echo "$PREVIEWS" | while IFS='|' read -r slug scene seconds extra; do
    [ $# -gt 0 ] && ! echo " $* " | grep -qE " (previews|preview-$slug) " && continue
    render "$TMP/preview-$slug" "$scene" "$seconds" "$extra"
    encode "$TMP/preview-$slug/master.mp4" "scale=1280:-2:flags=lanczos" "$OUT/preview-$slug"
    ls -lh "$OUT/preview-$slug".* | awk '{print "   " $5 "\t" $9}'
done
