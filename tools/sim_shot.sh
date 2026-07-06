#!/usr/bin/env bash
# Helpers to drive the Connect IQ simulator for Store screenshots (macOS).
# Requires: simulator running with the field loaded, Activity Data dialog open,
# a FIT loaded as "FIT/GPX Playable File", and Accessibility access for the
# calling terminal. See docs/store-screenshots.md for the full procedure.
set -u

# Scrub FIT playback to POSITION seconds (the slider is a position scrubber).
scrub() {
  osascript -e "
tell application \"System Events\"
  tell process \"simulator\"
    repeat with w in windows
      try
        if exists button \"Load File\" of w then
          set value of slider 1 of w to $1
          return \"scrubbed to $1\"
        end if
      end try
    end repeat
  end tell
end tell"
}

# Current playback position, e.g. "00:09:21 / 00:13:00".
pos() {
  osascript -e '
tell application "System Events"
  tell process "simulator"
    repeat with w in windows
      try
        if exists button "Load File" of w then
          repeat with tx in (every static text of w)
            set v to value of tx as string
            if v contains " / " then return v
          end repeat
        end if
      end try
    end repeat
  end tell
end tell'
}

# Set the data-field background: bg White | bg Black
bg() {
  osascript -e "
tell application \"System Events\"
  tell process \"simulator\"
    set frontmost to true
    click menu item \"$1\" of menu 1 of menu item \"Background Color\" of menu 1 of menu bar item \"Data Fields\" of menu bar 1
  end tell
end tell"
}

# Save the device screen to bin/NAME.png via File > Save Screen Capture.
# (The save dialog remembers its last folder; first use may land elsewhere —
# it is bin/ after the first manual save there.)
shot() {
  osascript -e "
tell application \"System Events\"
  tell process \"simulator\"
    set frontmost to true
    delay 0.4
    click menu item \"Save Screen Capture\" of menu 1 of menu bar item \"File\" of menu bar 1
    delay 1.4
    keystroke \"a\" using {command down}
    delay 0.4
    keystroke \"$1\"
    delay 0.4
    keystroke return
    delay 1.0
  end tell
end tell" >/dev/null
  echo "saved $1.png"
}

"$@"
