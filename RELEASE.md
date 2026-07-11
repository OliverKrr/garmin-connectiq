# Releasing Run Cockpit

Two Connect IQ Store listings share one codebase and **one version number**. `just release`
builds both signed `.iq` files at that version, so the listings never drift.

| Track | App id | Name | Visibility | Artifact | Status |
|---|---|---|---|---|---|
| Beta | `2aa9eff51b0642519e6214de6db52342` | Run Cockpit (Beta) | Private / unlisted | `bin/run-cockpit-beta.iq` | **live** |
| Public | `5f713bad3e2544559f1ba1cff9e59aa3` | Run Cockpit | Public | `bin/run-cockpit.iq` | pending listing |

The **Beta** listing is the one currently registered in Garmin — `run-cockpit-beta.iq` is what
uploads successfully. The **Public** app id is a placeholder: that listing does not exist yet, so
`run-cockpit.iq` cannot be uploaded until it is created. To create it: add a new app in the Garmin
developer dashboard, copy the app id Garmin assigns, and replace `public_app_id` in `justfile`
**and** the `id="…"` in `apps/run-cockpit/manifest.xml` with it (keep the two in sync).

There is **no Garmin upload API** — the upload is a manual web step. The pipeline prepares
everything; you click submit.

## Versioning

One shared SemVer number lives in `apps/run-cockpit/manifest.xml`. Bump **patch** for fixes, **minor**
for features. Both `.iq` carry that same version. You upload the Beta `.iq` on every iteration and
the Public `.iq` only at milestones — the two listings have independent version histories in Garmin,
which only requires each new upload to a listing to be greater than that listing's last.

## Changelog: two tracks

Each listing shows its own "What's New", so they don't carry the same text:

- **Beta** — the granular per-iteration log. `CHANGELOG.md` is the source; `just validate-store-text`
  regenerates the paste file `store-assets/whats-new.txt` from it. Paste that into the Beta listing.
- **Public** — a *folded* log: one hand-authored entry per public milestone, in
  `store-assets/whats-new-public.txt` (authored, not generated). Each entry collapses all the betas
  since the previous public release into feature themes, so store visitors don't see beta churn
  (renames, build-only bumps, fixes to features they never saw broken). Paste that into the Public
  listing. When you cut a public milestone, add its entry here by hand and re-run
  `just validate-store-text`.

## First public launch (one-time)

The public listing is a first-time submit, not just an upload, so it needs more than the beta:

1. **Create the listing** in the developer dashboard and copy the app id Garmin assigns. Replace the
   placeholder `public_app_id` in `justfile` **and** the `id="…"` in `apps/run-cockpit/manifest.xml`
   with it (keep the two in sync), then re-run `just package` so `bin/run-cockpit.iq` binds to it.
   Until this is done, `run-cockpit.iq` cannot be uploaded.
2. **Version** — bump to `1.0.0` for the public launch (`just release 1.0.0`); conventional signal for
   "stable / public". The mechanics work at any version, but the public history starts clean here.
3. **Keywords / search tags + category** — this is what makes it discoverable. Category: running data
   field. Suggested keywords: running, pace, power, training zones, 80/20, threshold, terrain.
4. **Screenshots** — matter far more for a public listing than beta; on-watch captures from a real run
   are best (Settings -> System -> Hot Keys -> Screenshot; files land in `GARMIN/SCRNSHOT`).
5. **Permissions** — the install screen shows what the app requests; keep the manifest minimal so
   nothing looks alarming.
6. **Review** — public apps go through Garmin's manual review (unlisted beta usually skips it). Expect a
   turnaround and test on a couple of the listed device simulators before submitting.

## Steps
1. `just release X.Y.Z` — bumps the version, then builds **both** `bin/run-cockpit.iq` and
   `bin/run-cockpit-beta.iq`. Edit `CHANGELOG.md` for the version.
2. `just publish-assist` — prints the version + "What's New" + checklist + dashboard URL (no upload).
3. In the dashboard (apps.garmin.com -> developer): upload the matching `.iq`, wait for binary
   validation, paste the description + the listing's own "What's New", add screenshots, set
   visibility, submit.
   - Beta: upload `bin/run-cockpit-beta.iq` to the Beta listing (keep it private/unlisted);
     paste `store-assets/description.txt` + `store-assets/whats-new.txt`.
   - Public: upload `bin/run-cockpit.iq` to the Public listing (once it exists);
     paste `store-assets/description.txt` + `store-assets/whats-new-public.txt`.
4. (Optional) Tag `vX.Y.Z` and attach the locally built `.iq` to a GitHub Release by hand —
   CI cannot build (Garmin's MFA blocks headless SDK logins) and has no release job.

> Claude prepares the `.iq` and notes; it does **not** upload. Never report an app as "published" —
> hand the artifact to the human for the final submit.
