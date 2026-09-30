# Releasing Run Cockpit

Two Connect IQ Store listings share one codebase and **one version number**. `just release`
builds both signed `.iq` files at that version, so the listings never drift.

| Track | App id | Name | Visibility | Artifact | Status |
|---|---|---|---|---|---|
| Beta | `2aa9eff51b0642519e6214de6db52342` | Run Cockpit (Beta) | Private / unlisted | `bin/run-cockpit-beta.iq` | [dashboard](https://apps-developer.garmin.com/apps/6eef6c69-8051-43f7-b2e2-db88d8d5d76c) |
| Public | `5f713bad3e2544559f1ba1cff9e59aa3` | Run Cockpit | Public | `bin/run-cockpit.iq` | [dashboard](https://apps-developer.garmin.com/apps/5f713bad-3e25-4455-9f1b-a1cff9e59aa3) |

Both listings exist. An `.iq` only uploads to the listing registered with the app id it carries;
otherwise the dashboard rejects it with "The app ID within the manifest file deviates from the one
originally registered for this app." **The dashboard URL id is not always the app id:** it matches
for Public, but the Beta listing's URL id is `6eef6c69…` while its registered app id is `2aa9eff5…`
(tried and rejected 2026-09-30). Never change an app id to match a URL. `public_app_id` in `justfile`
must match the `id="…"` in `apps/run-cockpit/manifest.xml`; `beta_app_id` lives only in `justfile`
(`just package` writes it into the generated beta manifest).

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

1. *(done 2026-06-29)* **Create the listing** in the developer dashboard and copy the app id Garmin assigns. Replace the
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
4. **Tag the source** — after the upload is accepted, `just tag` creates the annotated, app-scoped tag
   `run-cockpit-vX.Y.Z` at the shipped commit (local only), then push it: `git push origin
   run-cockpit-vX.Y.Z`. This is the only durable link from a Store version to its exact source, since CI
   cannot rebuild the binary (Garmin's MFA blocks headless SDK logins). Tag **every** shipped version.
5. **GitHub Release (public milestones only)** — `just github-release X.Y.Z` pushes the tag and
   publishes a GitHub Release carrying that version's folded public note (its section of
   `store-assets/whats-new-public.txt`) with the built `.iq` attached, so the repo the Store links to
   shows a real release history. Betas get **no** GitHub Release. Note the `.iq` is the Store bundle
   (archival) — sideloaders build a per-device `.prg` with `just build`, not from the `.iq`.

> Claude prepares the `.iq`, notes, and local tag; it does **not** upload, push, or publish a release.
> Those outward-facing steps (`git push`, `just github-release`, the dashboard submit) are yours.
> Never report an app as "published" — hand the artifact to the human for the final submit.
