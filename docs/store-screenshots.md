# Store screenshots from the simulator

Repeatable procedure for producing real Connect IQ Store screenshots of the run-cockpit
data field, with realistic ("faked") activity values. Screenshots are captured from the
simulator's own **File → Save Screen Capture**, which writes the device screen at native
resolution (280×280 on the Enduro 3) — pixel-perfect, no window chrome, and it needs
no macOS screen-recording permission. All GUI automation is AppleScript (System Events),
so the **calling terminal needs Accessibility access** (System Settings → Privacy &
Security → Accessibility). The recipes default to the fēnix 9 Pro 51 mm; prefix them with
`CIQ_DEVICE=enduro3` to match the existing 280×280 Store set.

**`just shoot` runs the whole procedure below** (patches, build, FIT, arming, choreography)
inside the local macOS VM ([simulator-vm.md](simulator-vm.md)), so its keystrokes and save panels
never reach the desktop and the patches never touch the working tree. The PNGs land in
`bin/vm/`. For a single look at an app's screen, `just screenshot <app>` is enough. The manual
procedure below, with the `*-local` recipes, is the fallback on a machine without the VM, and
only on a desktop nobody is using.

## Ingredients

| Piece | Purpose |
|---|---|
| `tools/gen_store_fit.py` | Generates `bin/store-run.fit`: a ~13-min synthetic run (Z2 warm-up → zone-3 steady → 8 % climb → fast descent) whose paces/HR/power are designed for photogenic zone colours |
| `tools/sim_shot.sh` | Low-level helpers: `arm <fit>`, `scrub <s>`, `pos`, `bg White\|Black`, `shot <name>` |
| `tools/store_shoot.sh` | The full choreography: one clean playback pass, Lap presses at segment boundaries, white+black captures at flat / climb / descent moments → `bin/s{1,2,3}-*.png` |
| Two **temporary source patches** (below) | Fake the settings/zones the sim cannot provide |

## Temporary "fake" patches (NEVER commit)

The sim cannot supply everything the field needs for colourful shots:

1. **Threshold pace** — app-settings defaults only apply on first install, and the sim's
   App Settings editor does not see monkeydo-loaded apps. Patch the default:
   in `apps/run-cockpit/resources/settings/properties.xml` set the `thresholdPace`
   property value to `4:00`.
2. **HR + power zones** — the simulator's user-profile HR zones are internal defaults
   (the User Profile Editor's zone widget is display-only, not scriptable) and it has
   no running power zones at all. Pin both in `RunCockpitView.reloadSettings()`:
   - make the HR-zone fallback unconditional: `if (z == null || z.size() < 6) {` → `if (true) {`
   - after `var pz = UserProfile.getPowerZones(Activity.SPORT_RUNNING);` add
     `pz = [155, 210, 250, 300, 355, 420];`

Revert both when done: `git checkout apps/run-cockpit/`.

## Procedure

```sh
# 1. apply the two patches above, then:
just build
just dev-local                             # sim up + field loaded
uv run --with fit-tool python3 tools/gen_store_fit.py

# 2. if the app ran before with different settings: File → Reset All App Data
#    in the simulator, then re-run `just dev-local` (the sim persists old app settings,
#    which override patched defaults!)

# 3. arm playback: Simulation → Activity Data → Data Source "FIT/GPX Playable File"
#    → Load File → bin/store-run.fit (store_shoot.sh then presses Start and ▶)
tools/sim_shot.sh arm "$PWD/bin/store-run.fit"

# 4. the choreography (runs ~13 min; don't type into the sim while it runs):
tools/store_shoot.sh

# 5. review bin/s*-*.png, copy keepers to store-assets/screenshots/, then:
git checkout apps/run-cockpit/               # drop the fake patches
just build                                 # rebuild clean
```

## Simulator gotchas (hard-won)

- **Persisted app settings override new defaults.** The sim stores
  Application.Properties across app loads; after changing `properties.xml` defaults you
  must File → Reset All App Data, or the old values win.
- **The playback slider is a position scrubber, not a speed control.** Scrubbing jumps
  `elapsedDistance`/timer inconsistently, which makes lap/avg pace physically impossible
  (e.g. 2:47/km) — scrubbing is fine for building time-in-zone history quickly, but
  **final captures need an un-scrubbed pass**.
- **On a Mac, FIT records are consumed ~1.47× faster than wall time** (measured 1.455–1.47,
  SDK 9.2.0) while the field's timer ticks wall seconds. Current pace reads the record's
  `speed` field (correct), but `elapsedDistance` follows the records — uncompensated,
  DIST/lap/avg pace inflate by that factor. `gen_store_fit.py` compensates with `K`
  (`CIQ_FIT_K`, default 1.47): distance/altitude deltas ÷ K, record counts × K. The playback
  position `sim_shot.sh pos` reports is the FIT's own time, so it also runs at K× wall time,
  and `store_shoot.sh` waits for position K × each design wall second. Give both the same
  `CIQ_FIT_K`. If lap/avg pace look superhuman or sluggish in captures, re-measure K: the
  position's advance over a minute of wall time while it plays (cross-check: two captures,
  ΔDIST/ΔTIME against the design speed).
- **In the VM, FIT records play at wall speed:** K = 1.00 (2026-10-17: position and DIST
  both advanced 1.00× wall time over 10 min). `just shoot` sets `CIQ_FIT_K=1.0`, so its
  captures show the design values, lap pace 4:10/km on the flat. Should another VM measure
  differently, pass its rate: `CIQ_FIT_K=<k> just shoot`.
- **There is no capture without the simulator's GUI** (SDK 9.2, checked 2026-10-18). The SDK's
  `shell` tool talks to the simulator on port 1234 but offers only file and app commands
  (`push`, `pull`, `NFM_*`, `ciq`). Its `fit_parse <file>` starts FIT playback without the
  Activity Data dialog, but the data field receives no values from it, even with the timer
  started and timer/lap events in the FIT. `monkeydo` only loads apps and runs tests. So
  loading the FIT, Start, Lap and Save Screen Capture all go through the GUI, inside the VM.
- **The simulator quits silently at launch** when its single-instance lock `~/Sim-<user>`
  holds the PID of a simulator killed before a reboot, a PID another process owns by now.
  Delete the file; `tools/ciq-vm.sh` does so in the VM before each launch.
- **The field timer (Start) runs on wall clock, independent of FIT playback.** Start
  them together and don't pause one without the other, or TIME and DIST drift apart.
- The FIT playback ends silently at the file's last record; the timer keeps running.
- **Save Screen Capture panel:** remembers its last folder (first save decides — put it
  in `bin/`); a name collision opens a Replace sheet that silently cancels scripted
  saves, so always use fresh file names; type the file name only after a ~0.4 s delay
  (first keystrokes can be swallowed).
- The User Profile Editor's HR-zone widget and the App Settings editor are not
  reachable via AppleScript/AX for monkeydo-loaded apps — hence the source patches.
- `Data Fields → Background Color → White|Black` switches the MIP (day) vs AMOLED
  (dark) palette live; capture both variants of each scene.

## Store image requirements (dashboard)

- Screenshots: PNG at the device's native resolution is fine (280×280 for Enduro 3);
  up to 5 per listing.
- The listing screenshots live in `store-assets/screenshots/` (on-watch captures from
  real runs; the simulator pipeline above is the fallback when a scene cannot be caught on a run).
- Also maintained in `store-assets/`: `cover.png` 500×500, `hero.png` 1440×720
  (regenerate from the SVGs with `just store-assets`).
