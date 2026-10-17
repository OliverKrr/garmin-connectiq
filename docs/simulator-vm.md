# Running the simulator in a macOS VM

The simulator GUI automation (`tools/sim_shot.sh`, `tools/store_shoot.sh`) drives the simulator
with AppleScript: real keystrokes, menu clicks and save panels in the logged-in desktop session.
On a machine someone is using, those keystrokes land in whatever window has focus, and the
person's typing lands in the simulator. `tools/ciq-vm.sh` runs the same SDK, simulator and
scripts inside a local macOS VM ([Tart](https://tart.run), Apple's Virtualization framework). The
VM runs headless, with its own desktop session, so no window or keystroke reaches the host's.

## When to use it

- `just vm-test [app]` instead of `just test` whenever someone is working at the machine: the
  simulator window opens in the VM.
- `just vm-shoot` for the [Store screenshot](store-screenshots.md) choreography. It applies the
  temporary fake patches to the VM's copy only, so they cannot end up in a commit.
- `just build` and `just package` need no simulator and run on the host as before.

## Requirements

- An Apple Silicon Mac with about 35 GB free disk (the image is ~25 GB to download, the VM disk is
  sparse) and 8 GB RAM to spare while the VM runs.
- The Connect IQ SDK and the target devices installed on the host with the SDK Manager. The VM
  copies them, so it never needs a Garmin login.
- Tart: `brew install cirruslabs/cli/tart`, or the notarized `tart.tar.gz` from its
  [GitHub releases](https://github.com/cirruslabs/tart/releases) when the tap does not load.

## One-time setup

```sh
tools/ciq-vm.sh create      # clone ghcr.io/cirruslabs/macos-tahoe-base:latest as ciq-sim
tools/ciq-vm.sh provision   # boot headless, SSH key, SDK + devices + fonts, just/uv/Java, throwaway key
tools/ciq-vm.sh check       # the VM's SSH session may script System Events
```

The Cirrus Labs base images already let the SSH session use AppleScript UI scripting, so `check`
passes without any GUI step. If it fails on another image, a person grants it once: `tools/ciq-vm.sh
screen` opens Screen Sharing to the VM (user and password `admin`); in System Settings → Privacy &
Security → Accessibility add `/usr/libexec/sshd-keygen-wrapper`, run `check` again and click
**Allow** on the Automation prompt it raises in the VM.

`tools/ciq-vm.sh peek` uses `screencapture`, and macOS answers that with a "bypass the system
private window picker" notice in the VM. Capturing works regardless; click **Allow** once over
`screen` to clear the notice.

## Daily use

| Command | What it does |
|---|---|
| `just vm-test [app]` | syncs the working tree into the VM, starts its simulator, runs `just test <app>` there |
| `just vm-shoot` | patches, builds, loads the field, arms FIT playback and runs `tools/store_shoot.sh` in the VM |
| `tools/ciq-vm.sh just <recipe>` | any other recipe in the VM |
| `tools/ciq-vm.sh peek` | saves the VM's screen to `bin/vm/screen.png` |
| `tools/ciq-vm.sh ssh [cmd]` | a shell, or one command, in the VM's copy of the repo |
| `tools/ciq-vm.sh stop` | shuts the VM down |

Every command boots the VM headless when it is not running (about 30 s). Results come back to
`bin/vm/`, never `bin/`: the VM signs with its own throwaway key, so its `.prg` files are for the
simulator only. The sync skips `.git/`, `bin/` and every key file and deletes the rest of the
VM's copy, so the VM always builds the host's working tree, uncommitted edits included. Pass
`CIQ_DEVICE` as usual, e.g. `CIQ_DEVICE=enduro3 just vm-shoot` for the 280×280 Store set.

`CIQ_VM` (default `ciq-sim`), `CIQ_VM_IMAGE`, `CIQ_VM_USER` and `CIQ_VM_PASS` override the
defaults. The VM is reachable from the host only, over Tart's private network.
