#!/usr/bin/env bash
#
# Runs the built application on a real X server the way a person would: a
# folder of images on the command line, then a click on Start. It passes when
# the window drew, the batch ran, and the resized files are on the disk next to
# their untouched originals. Screenshots are left behind for a person to look at.
#
#   xvfb-run -a -s "-screen 0 1600x1000x24 -noreset" bash tools/smoke_linux.sh
#
# What this catches is the class of failure no unit test can: a missing shared
# library, a plugin that throws on registration, a window that never maps, an
# isolate that cannot start in a release build. What it cannot judge is whether
# the window looks right, which is why the screenshots are kept.
#
# Needs imagemagick, x11-utils, x11-apps and xdotool.

set -euo pipefail
cd "$(dirname "$0")/.."

BINARY="${1:-build/linux/x64/release/bundle/shrink}"
OUT="${SMOKE_OUT:-build/smoke}"
rm -rf "$OUT"
mkdir -p "$OUT/photos"

# Something real for the queue to walk: three formats, and a file that is not
# an image, which has to be ignored rather than choked on.
convert -size 2400x1600 gradient:'#336699-#f2c14e' "$OUT/photos/landscape.jpg"
convert -size 1200x1800 plasma:fractal "$OUT/photos/portrait.png"
convert -size 800x800 xc:'#c0392b' "$OUT/photos/square.bmp"
echo "not an image" > "$OUT/photos/notes.txt"
( cd "$OUT/photos" && sha256sum landscape.jpg portrait.png square.bmp ) > "$OUT/originals.sha256"

# A settings directory of its own, so the run starts from the defaults and
# leaves nothing behind in the runner's home.
export XDG_DATA_HOME="$PWD/$OUT/xdg-data"
export XDG_CONFIG_HOME="$PWD/$OUT/xdg-config"

"$BINARY" "$OUT/photos" > "$OUT/stdout.log" 2> "$OUT/stderr.log" &
APP=$!

fail() {
  echo "::error::$1"
  xwd -root -silent | convert xwd:- "$OUT/failure.png" 2> /dev/null || true
  echo "--- stderr"; cat "$OUT/stderr.log" || true
  kill "$APP" 2> /dev/null || true
  exit 1
}

# --- it starts ---------------------------------------------------------------

GEOMETRY=""
for _ in $(seq 1 30); do
  sleep 1
  kill -0 "$APP" 2> /dev/null || fail "shrink exited within seconds of starting"
  GEOMETRY="$(xwininfo -root -tree | sed -n 's/.*"Shrink[^"]*": ([^)]*) *\([0-9]*x[0-9]*+[0-9]*+[0-9]*\) .*/\1/p' | head -1)"
  [[ -n "$GEOMETRY" ]] && break
done
[[ -n "$GEOMETRY" ]] || fail "shrink ran but never put a window on the screen"

# Long enough for the first frame, for three images to be probed and for the
# preview worker to answer.
sleep 8
xwd -root -silent | convert xwd:- "$OUT/1-queued.png"

# A window that mapped but painted nothing is a single flat colour. The
# interface, whatever it looks like, is not.
COLOURS="$(convert "$OUT/1-queued.png" -format '%k' info:)"
echo "window $GEOMETRY mapped; the screenshot has $COLOURS distinct colours"
(( COLOURS >= 50 )) || fail "the window mapped and drew nothing"

# --- it resizes --------------------------------------------------------------

# Start sits in the bottom-right corner of the window. Found from the window's
# own geometry rather than written down, so moving the window does not break
# this; moving the button would, and the screenshot will show it.
IFS='x+' read -r W H X Y <<< "$GEOMETRY"
xdotool mousemove $(( X + W - 52 )) $(( Y + H - 16 ))
sleep 0.5
xdotool click 1

DONE=0
for _ in $(seq 1 60); do
  sleep 1
  kill -0 "$APP" 2> /dev/null || fail "shrink died while running the batch"
  if [[ "$(find "$OUT/photos" -name '*-small.*' | wc -l)" -ge 3 ]]; then
    DONE=1
    break
  fi
done
sleep 2
xwd -root -silent | convert xwd:- "$OUT/2-finished.png"
xwininfo -root -tree > "$OUT/windows.txt"

kill "$APP" 2> /dev/null || true
wait "$APP" 2> /dev/null || true

echo "--- the folder afterwards"
ls -la "$OUT/photos"
[[ "$DONE" == "1" ]] || fail "Start was clicked and a minute later the resized files are not there"

# Every output has to be an image something else can read, and none may be
# larger than the file it came from: that is the one thing an application
# called Shrink cannot do.
for output in "$OUT"/photos/*-small.*; do
  identify -format '%f  %m %wx%h  %b\n' "$output" || fail "$output is not a readable image"
  source="${output/-small/}"
  if (( $(stat -c %s "$output") > $(stat -c %s "$source") )); then
    fail "$(basename "$output") is larger than $(basename "$source")"
  fi
done

# This is a first launch, so the longest edge starts switched on at 1600: the
# two images larger than that come out at 1600, and the one already smaller is
# left at its size — and, being a BMP nothing can squeeze, is the original.
[[ "$(identify -format '%w' "$OUT/photos/landscape-small.jpg")" == "1600" ]] \
  || fail "a first launch did not cap the landscape at 1600 pixels"
[[ "$(identify -format '%h' "$OUT/photos/portrait-small.png")" == "1600" ]] \
  || fail "a first launch did not cap the portrait at 1600 pixels"
[[ "$(identify -format '%wx%h' "$OUT/photos/square-small.bmp")" == "800x800" ]] \
  || fail "an image already under the cap was resized"
cmp -s "$OUT/photos/square.bmp" "$OUT/photos/square-small.bmp" \
  || fail "a file that could not be made smaller was not kept as it is"

# Rule 4 of this project: a source file is never overwritten.
( cd "$OUT/photos" && sha256sum --quiet -c ../originals.sha256 ) \
  || fail "an original changed on disk"
echo "originals untouched"

# Flutter's own way of saying something threw. GTK's chatter about a missing
# accessibility bus or DRI3 in a container is not that, and is left alone.
if grep -E "Unhandled Exception|EXCEPTION CAUGHT BY|\[ERROR:flutter" "$OUT/stderr.log"; then
  fail "the application reported an error while running"
fi
echo "ok"
