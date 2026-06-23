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

## Development

See the Development Setup section (added during setup) — requires the Connect IQ SDK and `just`.

## License

MIT — see [LICENSE](LICENSE).
