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
- `just sideload` — copy the .prg to a USB-mounted watch

## Develop / release workflow

- **Inner loop (fast):** `just run` (simulator) · `just sideload` or OpenMTP (watch). Unit tests:
  `just sim` then `just test`.
- **Cut a release:** `just release X.Y.Z` (bumps version + builds `bin/run-field.iq`), edit
  `CHANGELOG.md` for the version, then `just package-beta` for the beta `.iq`.
- **Publish (manual):** `just publish-assist` prints the version + "What's New" + checklist and
  opens the dashboard. Upload `bin/run-field-beta.iq` to the **private Beta** listing first; after
  testing, upload `bin/run-field.iq` to the **Public** listing. See `RELEASE.md` for app ids/steps.
- **CI:** type-checks on push; on a `vX.Y.Z` tag, attaches the signed `.iq` to a GitHub Release.

**Guardrail:** packaging (`package`/`package-beta`) is safe and automatable. **Uploading to the
Connect IQ Store is manual and outward-facing** — there is no API. Prepare the `.iq` and hand it to
the user; never run an uploader and never claim the app as "published".

## Conventions

- Override target device with `CIQ_DEVICE=<id> just build` (default `enduro3`).
- A data field is a full-screen `WatchUi.DataField`; geometry is computed once in
  `onLayout(dc)` and cached. Do not allocate in `onUpdate(dc)` — it is the draw loop.
- Generated/vendored code is never hand-edited.
