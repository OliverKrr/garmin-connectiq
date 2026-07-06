# Releasing Run Field

Two Connect IQ Store listings share one codebase and **one version number**. `just release`
builds both signed `.iq` files at that version, so the listings never drift.

| Track | App id | Name | Visibility | Artifact | Status |
|---|---|---|---|---|---|
| Beta | `2aa9eff51b0642519e6214de6db52342` | Run Field (Beta) | Private / unlisted | `bin/run-field-beta.iq` | **live** |
| Public | `5f713bad3e2544559f1ba1cff9e59aa3` | Run Field | Public | `bin/run-field.iq` | pending listing |

The **Beta** listing is the one currently registered in Garmin — `run-field-beta.iq` is what
uploads successfully. The **Public** app id is a placeholder: that listing does not exist yet, so
`run-field.iq` cannot be uploaded until it is created. To create it: add a new app in the Garmin
developer dashboard, copy the app id Garmin assigns, and replace `public_app_id` in `justfile`
**and** the `id="…"` in `apps/run-field/manifest.xml` with it (keep the two in sync).

There is **no Garmin upload API** — the upload is a manual web step. The pipeline prepares
everything; you click submit.

## Versioning

One shared SemVer number lives in `apps/run-field/manifest.xml`. Bump **patch** for fixes, **minor**
for features. Both `.iq` carry that same version. You upload the Beta `.iq` on every iteration and
the Public `.iq` only at milestones — the two listings have independent version histories in Garmin,
which only requires each new upload to a listing to be greater than that listing's last.

## Steps
1. `just release X.Y.Z` — bumps the version, then builds **both** `bin/run-field.iq` and
   `bin/run-field-beta.iq`. Edit `CHANGELOG.md` for the version.
2. `just publish-assist` — prints the version + "What's New" + checklist + dashboard URL (no upload).
3. In the dashboard (apps.garmin.com -> developer): upload the matching `.iq`, wait for binary
   validation, paste the "What's New", add screenshots, set visibility, submit.
   - Beta: upload `bin/run-field-beta.iq` to the Beta listing (keep it private/unlisted).
   - Public: upload `bin/run-field.iq` to the Public listing (once it exists).
4. (Optional) Tag `vX.Y.Z` and attach the locally built `.iq` to a GitHub Release by hand —
   CI cannot build (Garmin's MFA blocks headless SDK logins) and has no release job.

> Claude prepares the `.iq` and notes; it does **not** upload. Never report an app as "published" —
> hand the artifact to the human for the final submit.
