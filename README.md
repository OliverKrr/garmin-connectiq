# garmin-connectiq

Open-source [Garmin Connect IQ](https://developer.garmin.com/connect-iq/) apps.
A monorepo structured to host multiple apps and shared barrels.

## Apps

| App | Type | Status |
|---|---|---|
| [`apps/run-field`](apps/run-field) | Data field | Running data field — full-screen stats page (in development) |

## Layout

- `apps/` — Connect IQ applications (one dir per app)
- `barrels/` — Shared Monkey C code (Connect IQ "barrels")
- `bin/` — Build output (gitignored)

## Development Setup

### Prerequisites
- macOS (or Linux/WSL) with [`just`](https://github.com/casey/just) and `openssl`.
- The **Connect IQ SDK**, via either:
  - GUI: `brew install --cask connectiq-sdk-manager`, sign in, download the latest SDK
    (Set as current) and the **Enduro 3** device + simulator; or
  - CLI: [`connect-iq-sdk-manager`](https://github.com/lindell/connect-iq-sdk-manager-cli)
    (`login`, `sdk set <ver>`, `device download --manifest=apps/run-field/manifest.xml`).
- A developer signing key: `just key` (gitignored; never commit it).

### Everyday loop

```sh
just doctor     # confirm SDK / device / key
just build      # compile -> bin/run-field.prg   (override device: CIQ_DEVICE=<id> just build)
just sim        # launch the simulator (GUI)
just run        # build + run in the simulator
just sideload   # copy the .prg to a USB-mounted watch
```

The simulator opens blank — `just run` pushes the app into it. To advance the activity timer,
use **Simulation → Activity Data** in the simulator menu.

### Sideloading on macOS
Newer Garmin watches (incl. the Enduro 3) use **MTP**, which macOS does not mount as a disk
(`/Volumes/GARMIN` will be absent). Google's Android File Transfer is deprecated and unreliable
on recent macOS — use **[OpenMTP](https://openmtp.ganeshrvel.com/)** instead
(`brew install --cask openmtp`): connect the watch, then copy `bin/run-field.prg` into
`GARMIN/APPS/` on the device and restart it.

### VS Code
The official **Monkey C** extension reads `apps/run-field/manifest.xml` and `monkey.jungle`
directly — open the repo and build/debug from the extension if you prefer a GUI workflow.

## License

MIT — see [LICENSE](LICENSE).
