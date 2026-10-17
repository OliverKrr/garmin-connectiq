#!/usr/bin/env bash
# Run the Connect IQ simulator, its unit tests and its GUI automation inside a local macOS VM
# (Tart, Apple Virtualization), so simulator windows, AppleScript keystrokes and save panels
# never reach the host desktop. Setup and use: docs/simulator-vm.md.
#
#   tools/ciq-vm.sh create            clone the base image into the VM (once)
#   tools/ciq-vm.sh provision         boot it, SSH key, SDK + devices from the host, just/uv/Java
#   tools/ciq-vm.sh check | screen    can SSH script System Events? / Screen Sharing to the VM
#   tools/ciq-vm.sh test [app]        sync the tree, start the VM's simulator, `just test <app>`
#   tools/ciq-vm.sh shoot             sync, then the Store screenshot choreography in the VM
#   tools/ciq-vm.sh just <args>       sync, run any recipe in the VM
#   tools/ciq-vm.sh peek              save the VM's screen to bin/vm/screen.png
#   tools/ciq-vm.sh ssh [cmd]         shell (or one command) in the VM's copy of the repo
#   tools/ciq-vm.sh start | stop      boot headless / shut down
#
# Everything the VM wrote to its bin/ comes back to bin/vm/, never bin/: the VM signs with a
# throwaway key. CIQ_DEVICE is passed through.
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
GUEST_ENV+=" CIQ_KEY=\$HOME/.ciq-vm-key.der${CIQ_DEVICE:+ CIQ_DEVICE=$CIQ_DEVICE};"

die() { echo "ciq-vm: $*" >&2; exit 1; }

# ---- host side ---------------------------------------------------------------------------

need_tart() { command -v tart >/dev/null || die "tart missing (docs/simulator-vm.md, Requirements)"; }
exists() { tart list --source local --quiet | grep -qx "$VM"; }
running() { tart list --source local | awk -v vm="$VM" '$2 == vm { s = $NF } END { exit s != "running" }'; }
ip() { tart ip "$VM" --wait 120; }

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
  open -a "$(sdk_bin)/ConnectIQ.app"
  for _ in $(seq 30); do
    pgrep -xq simulator && { sleep 6; return 0; }
    sleep 1
  done
  die "simulator did not start"
}

# Replace a literal string that must occur exactly once in a file.
patch_once() {
  OLD=$2 NEW=$3 perl -0pi -e '$n = () = /\Q$ENV{OLD}\E/g;
    die "patch: expected 1 match in $ARGV, got $n\n" unless $n == 1; s/\Q$ENV{OLD}\E/$ENV{NEW}/' "$1"
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
  # A fresh simulator with no persisted app settings (File > Reset All App Data), whose save
  # panel starts in bin/.
  pkill -x simulator || true
  pkill -f monkeydo || true
  rm -rf "$(getconf DARWIN_USER_TEMP_DIR)com.garmin.connectiq"
  rm -f bin/s[0-9]-*.png
  mkdir -p bin
  defaults write com.garmin.connectiq.simulator NSNavLastRootDirectory -string "$PWD/bin"
  just build
  uv run --with fit-tool python3 tools/gen_store_fit.py
  sim_up
  # monkeydo stays attached to the app; detach it so the SSH session can end
  nohup "$(sdk_bin)/monkeydo" bin/run-cockpit.prg "${CIQ_DEVICE:-fenix9pro51mm}" >bin/monkeydo.log 2>&1 &
  sleep 8
  tools/sim_shot.sh bg White
  tools/sim_shot.sh arm "$PWD/bin/store-run.fit"
  tools/store_shoot.sh
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
  test) start && sync_tree && guest tools/ciq-vm.sh guest-sim-up '&&' just test "${1:-run-cockpit}" ;;
  shoot) start && sync_tree && guest tools/ciq-vm.sh guest-shoot ;;
  peek) start && vssh 'screencapture -x /tmp/ciq-vm-screen.png' && mkdir -p bin/vm &&
    vrsync "$VM_USER@$(ip):/tmp/ciq-vm-screen.png" bin/vm/screen.png && echo "bin/vm/screen.png" ;;
  guest-sim-up) sim_up ;;
  guest-shoot) guest_shoot ;;
  *) sed -n '6,17p' "$0" | sed 's/^# \{0,1\}//'; [ -z "$cmd" ] || exit 1 ;;
esac
