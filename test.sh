#!/bin/sh
# Runs tests, one run at a time: every worktree of this repo queues on one lock, since test runs share one settings
# store, the GPU and the screen, and two at once flake or crash. Use it wherever a doc says `swift test`, with the
# same arguments; never run `swift test` directly. CLAUDE.md, Testing, says which of these a change needs.
#
#   SNAPSHOT_SCENE="Aurora" ./test.sh Aurora   one wallpaper: the tests in Tests/AtriumTests/Aurora*.swift, and its render
#   ./test.sh Train WindowSeat                 several files' tests
#   ./test.sh shared                           the checks that cover every wallpaper (tests named every…)
#   ./test.sh all                              the whole suite: at a gate only
#   ./test.sh --filter liveCost -c release     arguments from the first that begins with a dash go to `swift test` as they are
#
# TEST_WAIT is how long it queues before giving up, in seconds (1800); TEST_LIMIT how long the run may take (2700).
set -e
cd "$(dirname "$0")"
queue=${TEST_WAIT:-1800} limit=${TEST_LIMIT:-2700}

# Queue: run this script again holding the lock, which the system frees if the run dies.
if [ -z "$ATRIUM_TEST_QUEUED" ]; then
    [ $# -gt 0 ] || { sed -n '2,/^set -e/p' "./$(basename "$0")" | sed '$d; s/^# \{0,1\}//'; exit 64; }
    status=0
    ATRIUM_TEST_QUEUED=1 lockf -ks -t "$queue" "$(git rev-parse --git-common-dir)/atrium-test.lock" "./$(basename "$0")" "$@" || status=$?
    [ $status -ne 75 ] || echo "test.sh: another run held the queue for $queue s; nothing was run" >&2
    exit $status
fi

# A run started any other way, or left behind by one that was stopped, has to finish first. Found by the process's
# own name, never its whole command line: a shell that only mentions these names, as a session's own waiting loop
# does, would be waited on for good.
end=$(( $(date +%s) + queue ))
while pgrep -x xctest >/dev/null || pgrep -x swift-test >/dev/null || pgrep '^swiftpm-testing' >/dev/null; do
    [ "$(date +%s)" -lt "$end" ] || { echo "test.sh: a run outside the queue didn't finish in $queue s; nothing was run" >&2; exit 74; }
    sleep 5
done

# The tests declared in the files given: each `func` that follows an `@Test`.
names() {
    awk '/@Test/ { test = 1 } test && match($0, /func [A-Za-z0-9_]+/) { print substr($0, RSTART + 5, RLENGTH - 5); test = 0 }' "$@"
}

filter=
case "$1" in
all) shift ;;
shared) shift; filter='every' ;;
-*) ;;
*)
    tests=
    while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
        found=$(names Tests/AtriumTests/"$1"*.swift 2>/dev/null) || true
        [ -n "$found" ] || { echo "test.sh: no tests in Tests/AtriumTests/$1*.swift" >&2; exit 64; }
        tests="$tests $found"
        shift
    done
    [ -z "$SNAPSHOT_SCENE" ] || tests="$tests everySceneRenders"
    filter="($(echo $tests | tr ' ' '|'))\\(" ;;
esac
[ -z "$filter" ] || set -- --filter "(^|[./])$filter" "$@"

# The run, stopped if it outlasts its limit, so a hung one can't hold the queue.
swift test "$@" &
run=$!
( sleep "$limit" && { echo "test.sh: stopped after $limit s" >&3; pkill -P "$run"; kill "$run"; } ) 3>&2 2>/dev/null &
watch=$!
status=0
wait "$run" || status=$?
pkill -P "$watch" 2>/dev/null || true
kill "$watch" 2>/dev/null || true
exit $status
