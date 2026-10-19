#!/usr/bin/env bash
# Run the Connect IQ simulator, its unit tests and its GUI automation inside a local macOS VM
# (Tart, Apple Virtualization), so simulator windows, AppleScript keystrokes and save panels
# never reach the host desktop. Setup and use: docs/simulator-vm.md.
#
#   tools/ciq-vm.sh create            clone the base image into the VM (once)
#   tools/ciq-vm.sh provision         boot it, SSH key, SDK + devices from the host, just/uv/Java
#   tools/ciq-vm.sh check | screen    can SSH script System Events? / Screen Sharing to the VM
#   tools/ciq-vm.sh test [app]        unit tests in the VM's simulator (`just test`)
#   tools/ciq-vm.sh dev [app]         build and load the app into the VM's simulator (`just dev`)
#   tools/ciq-vm.sh screenshot [app]  dev, then save the device screen to bin/vm/<app>.png
#   tools/ciq-vm.sh shoot             the Store screenshot choreography (`just shoot`)
#   tools/ciq-vm.sh record [app]      record an activity with the data field (`just record`)
#   tools/ciq-vm.sh just <args>       run any recipe in the VM
#   tools/ciq-vm.sh peek              save the VM's whole screen to bin/vm/screen.png
#   tools/ciq-vm.sh ssh [cmd]         shell (or one command) in the VM's copy of the repo
#   tools/ciq-vm.sh start | stop      boot headless / shut down
#
# test, dev, screenshot, shoot, record and just first sync the working tree into the VM; inside
# the VM (CIQ_IN_VM is set there) the same commands run on its own simulator. Everything the VM
# wrote to its bin/ comes back to bin/vm/, never bin/: the VM signs with a throwaway key.
# CIQ_DEVICE and CIQ_FIT_K are passed through.
set -euo pipefail
cd "$(dirname "$0")/.."

VM=${CIQ_VM:-ciq-sim}
IMAGE=${CIQ_VM_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-base:latest}
VM_USER=${CIQ_VM_USER:-admin}
VM_PASS=${CIQ_VM_PASS:-admin} # the base image's default login
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/ciq-vm
KEY=$STATE/id_ed25519
CIQ_HOME="Library/Application Support/Garmin/ConnectIQ" # under $HOME, on host and guest alike
REPO=garmin-connectiq                                    # the guest's copy, under its $HOME
GUEST_ENV="export PATH=/opt/homebrew/opt/openjdk/bin:/opt/homebrew/bin:\$HOME/.local/bin:\$PATH"
GUEST_ENV+=" CIQ_IN_VM=1 CIQ_KEY=\$HOME/.ciq-vm-key.der${CIQ_DEVICE:+ CIQ_DEVICE=$CIQ_DEVICE}"
GUEST_ENV+="${CIQ_FIT_K:+ CIQ_FIT_K=$CIQ_FIT_K};"

die() { echo "ciq-vm: $*" >&2; exit 1; }

# ---- host side ---------------------------------------------------------------------------

need_tart() { command -v tart >/dev/null || die "tart missing (docs/simulator-vm.md, Requirements)"; }
exists() { tart list --source local --quiet | grep -qx "$VM"; }
running() { tart list --source local | awk -v vm="$VM" '$2 == vm { s = $NF } END { exit s != "running" }'; }
# The DHCP lease answers at once, but after hours of uptime it can be gone ("no IP address found")
# while the VM still runs. The guest agent (in the Cirrus images) still answers then, and so does
# the host's ARP table, except to children of Homebrew's bash, which have read it empty. Only a
# VM that is still booting is worth the 120 s wait.
ip() {
  local r
  for r in dhcp agent arp; do
    tart ip --resolver "$r" "$VM" 2>/dev/null && return 0
  done
  tart ip "$VM" --wait 120
}

# IdentityAgent=none keeps the host's SSH agent (and any approval prompt it raises) out of
# this; the VM's address changes between boots, so its host key is not pinned.
SSH_OPTS=(-o IdentityAgent=none -o IdentitiesOnly=yes -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -o ServerAliveInterval=30)
vssh() { ssh "${SSH_OPTS[@]}" -i "$KEY" "$VM_USER@$(ip)" "$@"; }
vrsync() { rsync -az -e "ssh ${SSH_OPTS[*]} -i '$KEY'" "$@"; }
remote() { vssh "$GUEST_ENV cd ~/$REPO && $*"; }

boot() {
  need_tart
  exists || die "no VM $VM; run 'tools/ciq-vm.sh create' first"
  running && return 0
  mkdir -p "$STATE"
  nohup tart run --no-graphics "$VM" >"$STATE/run.log" 2>&1 &
  echo "booting $VM headless (log: $STATE/run.log)"
}

start() {
  boot
  [ -f "$KEY" ] || die "no SSH key yet; run 'tools/ciq-vm.sh provision' once"
  for _ in $(seq 60); do
    vssh true 2>/dev/null && return 0
    sleep 3
  done
  die "no SSH to $VM after 3 min"
}

install_key() {
  [ -f "$KEY" ] || { mkdir -p "$STATE" && ssh-keygen -q -t ed25519 -N '' -C ciq-vm -f "$KEY"; }
  local askpass="$STATE/askpass"
  printf '#!/bin/sh\necho %q\n' "$VM_PASS" >"$askpass"
  chmod 700 "$askpass"
  for _ in $(seq 60); do
    vssh true 2>/dev/null && { rm -f "$askpass"; return 0; }
    SSH_ASKPASS=$askpass SSH_ASKPASS_REQUIRE=force ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no \
      "$VM_USER@$(ip)" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys' \
      <"$KEY.pub" 2>/dev/null || sleep 3
  done
  rm -f "$askpass"
  die "could not install the SSH key in $VM"
}

provision() {
  boot
  install_key
  local sdk
  sdk=$(basename "$(cat "$HOME/$CIQ_HOME/current-sdk.cfg" 2>/dev/null)")
  [ -n "$sdk" ] || die "no Connect IQ SDK on the host; install one with the SDK Manager first"
  # The SDK, device definitions and fonts the SDK Manager downloaded: no Garmin login in the VM.
  # (openrsync hands the remote path to the guest's shell unquoted, hence the inner quotes)
  vssh "mkdir -p ~/'$CIQ_HOME'"
  vrsync --delete "$HOME/$CIQ_HOME/Sdks" "$HOME/$CIQ_HOME/Devices" "$HOME/$CIQ_HOME/Fonts" \
    "$VM_USER@$(ip):'$CIQ_HOME/'"
  vssh "printf '%s' \"\$HOME/$CIQ_HOME/Sdks/$sdk/\" > ~/'$CIQ_HOME/current-sdk.cfg'"
  vssh "$GUEST_ENV brew list just uv openjdk >/dev/null 2>&1 || brew install just uv openjdk"
  vssh '[ -f ~/.ciq-vm-key.der ] || openssl genrsa 4096 2>/dev/null |
    openssl pkcs8 -topk8 -outform DER -nocrypt -out ~/.ciq-vm-key.der'
  echo "provisioned $VM; next: 'tools/ciq-vm.sh check' (docs/simulator-vm.md, One-time setup)"
}

sync_tree() {
  vssh "mkdir -p ~/$REPO"
  # The guest's bin/ is its own; signing keys never leave the host.
  vrsync --delete --exclude .git/ --exclude /bin/ --exclude .ruff_cache/ \
    --exclude '*.der' --exclude '*.pem' ./ "$VM_USER@$(ip):$REPO/"
}

pull_bin() {
  mkdir -p bin/vm
  vrsync --exclude gen/ --exclude '*mir/' "$VM_USER@$(ip):$REPO/bin/" bin/vm/ &&
    echo "guest bin/ copied to bin/vm/"
}

# Run "$@" in the guest repo, copy its bin/ back whatever the outcome, keep the exit code.
guest() {
  local rc=0
  remote "$@" || rc=$?
  pull_bin || true
  return "$rc"
}

# ---- guest side (run inside the VM by the host commands above) ------------------------------

sdk_bin() { echo "$(cat "$HOME/$CIQ_HOME/current-sdk.cfg")bin"; }

# Start the simulator in the guest's logged-in desktop session if it is not running.
sim_up() {
  pgrep -xq simulator && return 0
  # The simulator's single-instance lock holds its PID. One killed by a VM shutdown leaves the
  # lock behind, that PID belongs to another process after the reboot, and every launch quits.
  rm -f "$HOME/Sim-$(id -un)"
  # Right after a boot SSH answers before the auto-login desktop exists, and `open` then fails
  # (launchd error 125); wait for the Dock, then retry the launch.
  for _ in $(seq 60); do
    pgrep -xq Dock && break
    sleep 1
  done
  for _ in $(seq 30); do
    pgrep -xq simulator && { sleep 6; return 0; }
    open -a "$(sdk_bin)/ConnectIQ.app" 2>/dev/null || true
    sleep 2
  done
  die "simulator did not start"
}

# Replace a literal string that must occur exactly once in a file.
patch_once() {
  OLD=$2 NEW=$3 perl -0pi -e '$n = () = /\Q$ENV{OLD}\E/g;
    die "patch: expected 1 match in $ARGV, got $n\n" unless $n == 1; s/\Q$ENV{OLD}\E/$ENV{NEW}/' "$1"
}

# Load bin/$1.prg into the running simulator, replacing whatever app it shows.
load_app() {
  pkill -f monkeydo || true
  # monkeydo stays attached to the app; detach it so the SSH session can end
  nohup "$(sdk_bin)/monkeydo" "bin/$1.prg" "${CIQ_DEVICE:-fenix9pro51mm}" >bin/monkeydo.log 2>&1 &
  sleep 8
}

guest_test() {
  sim_up
  just test-local "${1:-run-cockpit}"
}

guest_dev() {
  local app=${1:-run-cockpit}
  just build "$app"
  sim_up
  load_app "$app"
  echo "$app is running in the VM's simulator; watch it with 'just vm screen'"
}

guest_screenshot() {
  local app=${1:-run-cockpit}
  guest_dev "$app"
  # The save panel starts in bin/, and a name that exists opens a Replace sheet that cancels it.
  defaults write com.garmin.connectiq.simulator NSNavLastRootDirectory -string "$PWD/bin"
  rm -f "bin/$app.png"
  tools/sim_shot.sh shot "$app"
}

# Quit the simulator and drop its persisted app settings (File > Reset All App Data).
reset_app_data() {
  pkill -x simulator || true
  pkill -f monkeydo || true
  rm -rf "$(getconf DARWIN_USER_TEMP_DIR)com.garmin.connectiq"
}

guest_shoot() {
  # The two temporary patches from docs/store-screenshots.md, applied to this copy only; the
  # next sync from the host overwrites them.
  patch_once apps/run-cockpit/resources/settings/properties.xml \
    '<property id="thresholdPace" type="string"></property>' \
    '<property id="thresholdPace" type="string">4:00</property>'
  patch_once apps/run-cockpit/source/RunCockpitView.mc \
    'if (z == null || z.size() < 6) {' 'if (true) {'
  patch_once apps/run-cockpit/source/RunCockpitView.mc \
    'var pz = UserProfile.getPowerZones(Activity.SPORT_RUNNING);' \
    'var pz = UserProfile.getPowerZones(Activity.SPORT_RUNNING); pz = [155, 210, 250, 300, 355, 420];'
  # A fresh simulator with no persisted app settings, whose save panel starts in bin/.
  reset_app_data
  rm -f bin/s[0-9]-*.png
  mkdir -p bin
  defaults write com.garmin.connectiq.simulator NSNavLastRootDirectory -string "$PWD/bin"
  just build
  # The VM's simulator plays FIT records at wall speed, not a Mac host's 1.47 per second; the FIT
  # and store_shoot.sh's capture positions both scale with it (docs/store-screenshots.md).
  export CIQ_FIT_K=${CIQ_FIT_K:-1.0}
  uv run --with fit-tool python3 tools/gen_store_fit.py
  sim_up
  load_app run-cockpit
  tools/sim_shot.sh bg White
  tools/sim_shot.sh arm "$PWD/bin/store-run.fit"
  local rc=0
  tools/store_shoot.sh || rc=$?
  # The patched defaults persist in the simulator and would fail the next `just test`'s
  # default-value tests, so leave no app settings behind.
  reset_app_data
  return "$rc"
}

# Click a named button of the Activity Data dialog (Start, Stop, Lap, Save, Discard), or toggle
# its unnamed play/pause button with "play".
sim_dialog() {
  osascript - "$1" <<'EOF'
on run argv
  set what to item 1 of argv
  tell application "System Events" to tell process "simulator"
    repeat with w in windows
      try
        if exists button "Load File" of w then
          if what is not "play" then
            if exists button what of w then
              click button what of w
              return "clicked " & what
            end if
            return "no " & what
          end if
          repeat with b in (every button of w)
            if name of b is missing value then
              set d to ""
              try
                set d to description of b as string
              end try
              if d does not contain "close" and d does not contain "zoom" and d does not contain "minimize" then
                click b
                return "toggled play"
              end if
            end if
          end repeat
        end if
      end try
    end repeat
    return "no dialog"
  end tell
end run
EOF
}

# FIT playback position in seconds, or -1 while there is none.
play_pos() {
  local p h m s
  p=$(tools/sim_shot.sh pos 2>/dev/null | awk '{print $1}')
  [[ "$p" =~ ^[0-9]+:[0-9]+:[0-9]+$ ]] || { echo -1; return; }
  IFS=: read -r h m s <<<"$p"
  echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

# Wait until playback reaches position $1, giving up at $SECONDS = $2.
wait_play() {
  while [ "$(play_pos)" -lt "$1" ]; do
    [ "$SECONDS" -lt "$2" ] || die "playback stuck at $(tools/sim_shot.sh pos)"
    sleep 3
  done
}

# The newest activity in the simulator's Activities folder $1, or nothing. Start opens one named
# after its start time (2026-10-18-20-42-36.fit); FILE.FIT beside it is the playback input.
last_activity() {
  local f last=
  for f in "$1"/[0-9]*.fit; do
    [ -e "$f" ] && last=$f
  done
  echo "$last"
}

# record's FIT: 90 s flat, 120 s at 6 %, 60 s at -4 % (secs,pace,grade,power,hr_from,hr_to).
RECORD_SEGMENTS="90,300,0,250,130,140;120,380,6,330,150,165;60,270,-4,220,155,150"

guest_record() {
  local app=${1:-run-cockpit}
  grep -q 'type="datafield"' "apps/$app/manifest.xml" ||
    die "record drives a data field; $app is not one"
  local act k lap_at stop_at p1 p2 deadline saved
  act="$(getconf DARWIN_USER_TEMP_DIR)com.garmin.connectiq/GARMIN/Activities"
  # Lap mid-climb and Stop just before the FIT ends, at wall seconds 150 and 262; the playback
  # position runs K times faster (docs/store-screenshots.md, gotchas).
  k=${CIQ_FIT_K:-1.0}
  lap_at=$(awk -v k="$k" 'BEGIN { printf "%d", 150 * k + 0.5 }')
  stop_at=$(awk -v k="$k" 'BEGIN { printf "%d", 262 * k + 0.5 }')
  just build "$app"
  # A fresh simulator: default app settings and no earlier activities.
  reset_app_data
  sim_up
  load_app "$app"
  # Start keeps only playback records dated after it, so the FIT starts 45 s from now; arming it
  # and pressing Start take about 15 s.
  mkdir -p bin
  CIQ_FIT_K=$k CIQ_FIT_BASE_MS=$(($(date +%s) * 1000 + 45000)) CIQ_FIT_SEGMENTS=$RECORD_SEGMENTS \
    CIQ_FIT_OUT=bin/record-run.fit uv run -q --with fit-tool python3 tools/gen_store_fit.py
  tools/sim_shot.sh arm "$PWD/bin/record-run.fit"
  tools/sim_shot.sh scrub 0 >/dev/null
  sim_dialog Start
  sleep 0.6
  sim_dialog play
  sleep 6
  p1=$(play_pos)
  sleep 5
  p2=$(play_pos)
  if [ "$p2" -le "$p1" ]; then
    # The play button is a toggle: a frozen position means this click paused it. Play again and
    # restart the timer with it.
    echo "playback frozen at ${p2}s; toggling play and restarting the timer"
    sim_dialog play
    sleep 2
    sim_dialog Stop
    sleep 0.6
    sim_dialog Discard
    sleep 0.6
    sim_dialog Start
    sleep 2
  fi
  [ -n "$(last_activity "$act")" ] || die "Start opened no activity in $act"
  echo "recording: $(tools/sim_shot.sh pos)"
  deadline=$((SECONDS + 420))
  wait_play "$lap_at" "$deadline"
  echo "lap at $(tools/sim_shot.sh pos): $(sim_dialog Lap)"
  wait_play "$stop_at" "$deadline"
  echo "stop at $(tools/sim_shot.sh pos): $(sim_dialog Stop)"
  sleep 2
  sim_dialog Save
  sleep 4
  saved=$(last_activity "$act")
  cp "$saved" "bin/$app-activity.fit"
  echo "saved $(basename "$saved") -> bin/$app-activity.fit"
}

# ---- dispatch ---------------------------------------------------------------------------------

cmd=${1:-}
shift || true
case "$cmd" in
  create) need_tart && { exists && echo "$VM exists" || tart clone "$IMAGE" "$VM"; } ;;
  provision) provision ;;
  start) start && echo "$VM up at $(ip)" ;;
  stop) need_tart && { running && tart stop "$VM" || echo "$VM is not running"; } ;;
  screen) start && open "vnc://$VM_USER@$(ip)" ;;
  check)
    start
    vssh "osascript -e 'tell application \"System Events\" to count windows of process \"Finder\"'" >/dev/null &&
      echo "ok: the VM's SSH session can script System Events" ||
      die "no UI scripting over SSH yet; grant it once (docs/simulator-vm.md, One-time setup)"
    ;;
  ssh) start && if [ $# -gt 0 ]; then remote "$@"; else vssh -t "$GUEST_ENV cd ~/$REPO 2>/dev/null; exec zsh -l"; fi ;;
  just) start && sync_tree && guest just "$@" ;;
  test | dev | screenshot | shoot | record)
    if [ -n "${CIQ_IN_VM:-}" ]; then
      "guest_$cmd" "$@"
    else
      start && sync_tree && guest tools/ciq-vm.sh "$cmd" "$@"
    fi
    ;;
  peek) start && vssh 'screencapture -x /tmp/ciq-vm-screen.png' && mkdir -p bin/vm &&
    vrsync "$VM_USER@$(ip):/tmp/ciq-vm-screen.png" bin/vm/screen.png && echo "bin/vm/screen.png" ;;
  *) sed -n '6,22p' "$0" | sed 's/^# \{0,1\}//'; [ -z "$cmd" ] || exit 1 ;;
esac
