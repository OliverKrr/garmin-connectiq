# The simulator VM

The Connect IQ simulator is a GUI app, and its automation (`tools/sim_shot.sh`,
`tools/store_shoot.sh`) drives it with AppleScript: real keystrokes, menu clicks and save panels in
the logged-in desktop session. On a machine someone is using, those keystrokes land in whatever
window has focus, and the person's typing lands in the simulator. `tools/ciq-vm.sh` therefore runs
the SDK, the simulator and the scripts inside a local macOS VM ([Tart](https://tart.run), Apple's
Virtualization framework). The VM runs headless with its own desktop session, so no window or
keystroke reaches the host's, and the host needs no simulator running at all.

## Recipes

| Command | What it does |
|---|---|
| `just test [app]` | builds the app with its unit tests and runs them in the VM's simulator |
| `just screenshot [app]` | loads the app into the VM's simulator and saves its screen to `bin/vm/<app>.png` |
| `just dev [app]` | loads the app into the VM's simulator and leaves it running; re-run to reload |
| `just shoot` | the [Store screenshot](store-screenshots.md) choreography, fake patches included |
| `just vm screen` | opens Screen Sharing to the VM (user and password `admin`), to watch or click |
| `just vm peek` | saves the VM's whole screen to `bin/vm/screen.png` |
| `just vm ssh [cmd]` | a shell, or one command, in the VM's copy of the repo |
| `just vm stop` | shuts the VM down |

Each recipe boots the VM headless when it is not running (about 30 s), syncs the working tree
into it and copies the VM's `bin/` back to `bin/vm/`, never `bin/`: the VM signs with its own
throwaway key, so its `.prg` files are for the simulator only, and the release key never leaves
the host. The sync skips `.git/`, `bin/` and every key file and deletes the rest of the VM's
copy, so the VM always builds the host's working tree, uncommitted edits included. Inside the VM
the same recipes run on its own simulator. Pass `CIQ_DEVICE` as usual, e.g.
`CIQ_DEVICE=enduro3 just shoot` for the 280×280 Store set. `just build` and `just package` need no
simulator and run on the host.

The `*-local` recipes (`test-local`, `dev-local`, `run-local`, `sim-local`) still drive the
host's own simulator, for a machine without the VM.

## Requirements

- An Apple Silicon Mac with about 35 GB free disk (the image is ~25 GB to download, the VM disk is
  sparse) and 8 GB RAM to spare while the VM runs.
- The Connect IQ SDK and the target devices installed on the host with the SDK Manager. The VM
  copies them, so it never needs a Garmin login.
- Tart: `brew install cirruslabs/cli/tart`, or the notarized `tart.tar.gz` from its
  [GitHub releases](https://github.com/cirruslabs/tart/releases) when the tap does not load.

## One-time setup

```sh
just vm create      # clone ghcr.io/cirruslabs/macos-tahoe-base:latest as ciq-sim
just vm provision   # boot headless, SSH key, SDK + devices + fonts, just/uv/Java, throwaway key
just vm check       # the VM's SSH session may script System Events
```

Re-run `just vm provision` after the SDK Manager installs a new SDK or device.

The Cirrus Labs base images already let the SSH session use AppleScript UI scripting, so `check`
passes without any GUI step. If it fails on another image, a person grants it once: `just vm
screen`, then in the VM's System Settings → Privacy & Security → Accessibility add
`/usr/libexec/sshd-keygen-wrapper`, run `check` again and click **Allow** on the Automation prompt
it raises in the VM.

`just vm peek` uses `screencapture`, and macOS answers that with a "bypass the system private
window picker" notice in the VM. Capturing works regardless; click **Allow** once over `screen` to
clear the notice.

`CIQ_VM` (default `ciq-sim`), `CIQ_VM_IMAGE`, `CIQ_VM_USER` and `CIQ_VM_PASS` override the
defaults. The VM is reachable from the host only, over Tart's private network.
