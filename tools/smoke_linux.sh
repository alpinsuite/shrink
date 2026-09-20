#!/usr/bin/env bash
#
# Starts the built application on a real X server, with a folder of images on
# the command line, and checks that it is still there a few seconds later with
# a window on the screen. Leaves a screenshot behind for a person to look at.
#
#   xvfb-run -a -s "-screen 0 1600x1000x24 -noreset" bash tools/smoke_linux.sh
#
# What this catches is the class of failure no unit test can: a missing shared
# library, a plugin that throws on registration, a window that never maps. What
# it cannot judge is whether the window looks right, which is why the
# screenshot is kept.
#
# Needs imagemagick, x11-utils and x11-apps.

set -euo pipefail
cd "$(dirname "$0")/.."

BINARY="${1:-build/linux/x64/release/bundle/shrink}"
OUT="${SMOKE_OUT:-build/smoke}"
mkdir -p "$OUT/photos"

# Something real for the queue to walk: three formats, and a file that is not
# an image, which has to be ignored rather than choked on.
convert -size 2400x1600 gradient:'#336699-#f2c14e' "$OUT/photos/landscape.jpg"
convert -size 1200x1800 plasma:fractal "$OUT/photos/portrait.png"
convert -size 800x800 xc:'#c0392b' "$OUT/photos/square.bmp"
echo "not an image" > "$OUT/photos/notes.txt"

"$BINARY" "$OUT/photos" > "$OUT/stdout.log" 2> "$OUT/stderr.log" &
APP=$!

# Long enough for the first frame and for three images to be probed.
for _ in $(seq 1 20); do
  sleep 1
  if ! kill -0 "$APP" 2> /dev/null; then
    echo "::error::shrink exited within seconds of starting"
    cat "$OUT/stderr.log"
    exit 1
  fi
  if xwininfo -root -tree | grep -qi '"shrink"'; then
    WINDOW_SEEN=1
  fi
done

xwd -root -silent | convert xwd:- "$OUT/screen.png"
xwininfo -root -tree > "$OUT/windows.txt"

kill "$APP" 2> /dev/null || true
wait "$APP" 2> /dev/null || true

if [[ "${WINDOW_SEEN:-0}" != "1" ]]; then
  echo "::error::shrink ran but never put a window on the screen"
  cat "$OUT/windows.txt"
  exit 1
fi

# A window that mapped but painted nothing is a single flat colour. The
# interface, whatever it looks like, is not.
COLOURS="$(convert "$OUT/screen.png" -format '%k' info:)"
echo "window mapped; the screenshot has $COLOURS distinct colours"
if (( COLOURS < 50 )); then
  echo "::error::the screen is nearly one colour: the window mapped and drew nothing"
  exit 1
fi

if grep -iE "exception|error" "$OUT/stderr.log" | grep -viE "libEGL|MESA|dri3|Gdk-Message|Gtk-Message"; then
  echo "::error::the application logged errors while starting; see above"
  exit 1
fi
echo "ok"
