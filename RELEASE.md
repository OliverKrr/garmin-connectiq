# Releasing Run Field

Two Connect IQ Store listings share one codebase:

| Track | App id | Name | Visibility | Artifact |
|---|---|---|---|---|
| Public | `024f8072155f4e17a0d6fed0b18d682e` | Run Field | Public | `bin/run-field.iq` |
| Beta | `2aa9eff51b0642519e6214de6db52342` | Run Field (Beta) | Private / unlisted | `bin/run-field-beta.iq` |

There is **no Garmin upload API** — the upload is a manual web step. The pipeline prepares
everything; you click submit.

## Steps
1. `just release X.Y.Z` (bumps the version, builds `bin/run-field.iq`). Edit `CHANGELOG.md`.
2. For beta: `just package-beta` -> `bin/run-field-beta.iq`.
3. `just publish-assist` — opens the dashboard and prints the version + "What's New" + checklist.
4. In the dashboard (apps.garmin.com -> developer): upload the `.iq`, wait for binary validation,
   paste the "What's New", add screenshots, set visibility (Beta = private, Public = public), submit.
5. On a `vX.Y.Z` git tag, CI also attaches the signed `.iq` to a GitHub Release for download.

> Claude prepares the `.iq` and notes; it does **not** upload. Never report an app as "published" —
> hand the artifact to the human for the final submit.
