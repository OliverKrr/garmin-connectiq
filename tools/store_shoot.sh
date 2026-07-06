#!/usr/bin/env bash
# One clean, un-scrubbed pass over bin/store-run.fit, pressing Lap at segment
# boundaries and capturing Store screenshots (white + black background) at the
# flat, climb, and descent moments. Run AFTER tools/sim_shot.sh's prerequisites
# are in place (sim running, screenshot build loaded, FIT loaded and playing —
# see docs/store-screenshots.md).
set -u
cd "$(dirname "$0")/.."
S=tools/sim_shot.sh

pos_s() { # playback position in seconds, or -1
  local p
  p=$("$S" pos 2>/dev/null | awk '{print $1}')
  [[ "$p" =~ ^[0-9:]+$ ]] || { echo -1; return; }
  IFS=: read -r h m s <<<"$p"
  echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

lap() {
  osascript -e '
tell application "System Events"
  tell process "simulator"
    repeat with w in windows
      try
        if exists button "Lap" of w then
          click button "Lap" of w
          return "lap"
        end if
      end try
    end repeat
  end tell
end tell'
}

wait_pos() { # wait until playback reaches $1 seconds
  while true; do
    local p
    p=$(pos_s)
    if [ "$p" -ge "$1" ] 2>/dev/null; then break; fi
    sleep 5
  done
}

# restart from the top: stop+discard the timer, rewind, start, play
restart() {
  osascript -e '
tell application "System Events"
  tell process "simulator"
    set frontmost to true
    repeat with w in windows
      try
        if exists button "Load File" of w then
          try
            click button "Stop" of w
          end try
          delay 0.6
          try
            click button "Discard" of w
          end try
          delay 0.6
          set value of slider 1 of w to 0
          delay 0.6
          click button "Start" of w
          delay 0.6
          repeat with b in (every button of w)
            if name of b is missing value then
              set d to ""
              try
                set d to description of b as string
              end try
              if d does not contain "close" and d does not contain "zoom" and d does not contain "minimize" then
                click b
                exit repeat
              end if
            end if
          end repeat
          return "restarted"
        end if
      end try
    end repeat
    return "ERR no dialog"
  end tell
end tell'
}

echo "== restart playback =="
restart
sleep 6
p1=$(pos_s)
sleep 6
p2=$(pos_s)
if [ "$p2" -le "$p1" ]; then
  # the unnamed button is a play/pause TOGGLE — if position froze we paused it; toggle again
  echo "playback frozen at ${p2}s — toggling play again"
  osascript -e '
tell application "System Events"
  tell process "simulator"
    set frontmost to true
    repeat with w in windows
      try
        if exists button "Load File" of w then
          repeat with b in (every button of w)
            if name of b is missing value then
              set d to ""
              try
                set d to description of b as string
              end try
              if d does not contain "close" and d does not contain "zoom" and d does not contain "minimize" then
                click b
                exit repeat
              end if
            end if
          end repeat
        end if
      end try
    end repeat
  end tell
end tell' >/dev/null
  # timer ran while playback was frozen — restart it clean (Stop/Discard/Start only)
  sleep 3
  osascript -e '
tell application "System Events"
  tell process "simulator"
    repeat with w in windows
      try
        if exists button "Load File" of w then
          try
            click button "Stop" of w
          end try
          delay 0.6
          try
            click button "Discard" of w
          end try
          delay 0.6
          click button "Start" of w
          return "timer restarted"
        end if
      end try
    end repeat
  end tell
end tell'
fi
echo "pos: $("$S" pos)"

# The field timer must actually be running (button reads "Stop" while it runs) —
# a silent Start failure produces TIME 0:00 shots with frozen accumulators.
for i in 1 2 3; do
  state=$(osascript -e '
tell application "System Events"
  tell process "simulator"
    repeat with w in windows
      try
        if exists button "Load File" of w then
          if exists button "Stop" of w then return "running"
          if exists button "Start" of w then
            click button "Start" of w
            return "clicked-start"
          end if
        end if
      end try
    end repeat
    return "unknown"
  end tell
end tell')
  echo "timer check: $state"
  [ "$state" = "running" ] && break
  sleep 2
done

echo "== waiting for lap point 1 (180s) =="
wait_pos 180
lap
echo "== waiting for flat capture (295s) =="
wait_pos 295
"$S" shot s1-flat-white
sleep 2
"$S" bg Black
sleep 3
"$S" shot s1-flat-black
sleep 2
"$S" bg White

echo "== waiting for climb lap (562s) =="
wait_pos 562
lap
echo "== waiting for climb capture (640s) =="
wait_pos 640
"$S" shot s2-climb-white
sleep 2
"$S" bg Black
sleep 3
"$S" shot s2-climb-black
sleep 2
"$S" bg White

echo "== waiting for descent lap (684s) =="
wait_pos 684
lap
echo "== waiting for descent capture (740s) =="
wait_pos 740
"$S" shot s3-descent-white
sleep 2
"$S" bg Black
sleep 3
"$S" shot s3-descent-black
sleep 2
"$S" bg White

echo "== done: bin/s*-{white,black}.png =="
ls -la bin/s1-* bin/s2-* bin/s3-* 2>/dev/null
