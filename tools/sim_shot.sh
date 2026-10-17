#!/usr/bin/env bash
# Helpers to drive the Connect IQ simulator for Store screenshots (macOS).
# Requires: simulator running with the field loaded, Accessibility access for the
# calling terminal, and (for scrub/pos) a FIT loaded with `arm`. See
# docs/store-screenshots.md for the full procedure.
set -u

# Open Simulation > Activity Data, choose "FIT/GPX Playable File" and load the FIT
# at the absolute path $1 (through the Open panel's Go to Folder field).
arm() {
  osascript - "$1" <<'EOF'
-- One step on the Activity Data dialog. Window indexes shift whenever focus moves or
-- a menu opens, so every step finds the dialog again.
on dialogStep(what)
  tell application "System Events" to tell process "simulator"
    repeat with w in windows
      try
        if exists button "Load File" of w then
          if what is "find" then return true
          if what is "source" then
            if value of pop up button 1 of w is "FIT/GPX Playable File" then return false
            click pop up button 1 of w
          else if what is "pick" then
            click menu item "FIT/GPX Playable File" of menu 1 of pop up button 1 of w
          else if what is "load" then
            click button "Load File" of w
          end if
          return true
        end if
      end try
    end repeat
  end tell
  if what is "find" then return false
  error "Activity Data dialog not found (" & what & ")"
end dialogStep

on run argv
  tell application "System Events" to tell process "simulator"
    set frontmost to true
    delay 1
    if not my dialogStep("find") then
      click menu item "Activity Data" of menu 1 of menu bar item "Simulation" of menu bar 1
      delay 1.5
    end if
    if my dialogStep("source") then
      delay 0.6
      my dialogStep("pick")
      delay 0.8
    end if
    my dialogStep("load")
    delay 1.5
    keystroke "g" using {command down, shift down}
    delay 1
    keystroke (item 1 of argv)
    delay 0.8
    keystroke return
    delay 1.2
    keystroke return
    delay 2
  end tell
end run
EOF
  echo "armed $1: $(pos)"
}

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
