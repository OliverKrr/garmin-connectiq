# CLAUDE.md — garmin-connectiq

Guidance for Claude Code when working in this repository.

## What this is

An open-source monorepo of Garmin Connect IQ apps (Monkey C). It is **self-contained**:
do not reference sibling repositories by local path; link public repos by URL only.

| Path | Purpose |
|---|---|
| `apps/run-field/` | Full-screen running **data field** (the first app) |
| `barrels/` | Shared Monkey C code (Connect IQ barrels) — empty until needed |
| `bin/` | Build output (`.prg` / `.iq`) — gitignored |

## Toolchain

- Connect IQ SDK installed locally (GUI **SDK Manager** or the headless
  `connect-iq-sdk-manager` CLI). The active SDK path lives in
  `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`.
- Build/run/deploy via `just` (run `just --list`). The VS Code Monkey C extension works too
  (it reads `manifest.xml` + `monkey.jungle`).
- A per-developer signing key (`developer_key.der`) is required by `monkeyc` and is
  **gitignored** — generate your own with `just key`.

## Commands

- `just doctor` — check SDK / device / key are in place
- `just key` — generate a developer signing key (one-time)
- `just build` — compile apps/run-field to bin/run-field.prg
- `just sim` — launch the Connect IQ simulator
- `just run` — build + run in the simulator (sim must be running)
- `just dev` — build + auto-launch the sim if needed + load the field (self-serve start; re-run to reload)
- `just kill` — clear crashed/stale simulator + monkeydo instances, then `just dev` again
- `just sim-fit` — generate `bin/run-sim.fit` test data (needs `pip install fit-tool`); load via Simulation → Activity Data
- `just sideload` — copy the .prg to a USB-mounted watch

## Develop / release workflow

- **Inner loop (fast):** `just run` (simulator) · `just sideload` or OpenMTP (watch). Unit tests:
  `just sim` then `just test`.
- **Cut a release:** `just release X.Y.Z` bumps the one shared version and builds **both** signed
  `.iq` (Public + Beta) so the listings never drift; then edit `CHANGELOG.md` for the version.
- **Always keep the Store description current:** `store-assets/listing.md` IS the maintained Store
  description (uploaded alongside each version). Update it in the SAME change whenever settings,
  features, or defaults change — its per-setting docs and examples must match what ships. Treat a
  release with stale `listing.md` as incomplete. Keep it plain and free of `<`/`>` (the Store rejects them).
- **Store screenshots** are real simulator captures — the repeatable procedure (scenario FIT,
  AppleScript capture pipeline, temporary zone/threshold patches, sim gotchas) is in
  `docs/store-screenshots.md`.
- **Publish (manual):** `just publish-assist` prints the version + "What's New" + checklist +
  dashboard URL (it does not open a browser or upload). The **Beta** listing (`bin/run-field-beta.iq`,
  app id `2aa9eff5…`) is the live one; the **Public** listing (`bin/run-field.iq`, `5f713bad…`) is a
  placeholder until that listing is created. See `RELEASE.md` for app ids/steps.
- **CI:** SDK-free sanity checks only (XML well-formedness). Garmin's MFA blocks headless SDK
  logins, so compiles/tests/releases all run locally — there is no CI build or tag-release job.

**Guardrail:** packaging (`just package`, which builds both `.iq`) is safe and automatable.
**Uploading to the Connect IQ Store is manual and outward-facing** — there is no API. Prepare the
`.iq` and hand it to the user; never run an uploader and never claim the app as "published".

## Conventions

- Override target device with `CIQ_DEVICE=<id> just build` (default `enduro3`).
- A data field is a full-screen `WatchUi.DataField`; geometry is computed once in
  `onLayout(dc)` and cached. Do not allocate in `onUpdate(dc)` — it is the draw loop.
- Generated/vendored code is never hand-edited.
