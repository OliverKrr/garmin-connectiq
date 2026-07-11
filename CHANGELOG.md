# Changelog

All notable changes to the Run Cockpit data field (formerly "Run Field"),
versioned by [SemVer](https://semver.org/).

This granular per-iteration log is the **Beta** listing's "What's New": `just validate-store-text`
(run automatically by `just package` / `publish-assist`) regenerates the paste file
`store-assets/whats-new.txt` from the history below. The **Public** listing shows a *folded* log
instead — one hand-authored entry per public milestone in `store-assets/whats-new-public.txt`
(not generated; edit it by hand when you cut a public release), so store visitors see feature
themes rather than beta churn.

Each Store "What's New" field carries the whole released history and allows at most
**4000 plain-ASCII characters** — keep entries short, focused, ASCII-only, and free of `<` and `>`;
compact old entries before adding new ones. `just validate-store-text` fails the build when either
paste file or the Store description exceeds the limit.

## [Unreleased]

## [1.0.0] - 2026-07-11
- First stable release; published to the public Connect IQ Store. No functional changes since 0.6.0.

## [0.6.0] - 2026-07-06
- Renamed to Run Cockpit (formerly Run Field).
- 48 more supported watches: fenix 6 Pro / 7 / 8 / E, epix 2, Enduro 3, Forerunner 165 / 170 / 245 Music / 255 / 265 / 570 / 745 / 945 / 955 / 965 / 970, MARQ 2, Venu 3 / 4, vivoactive 5 / 6.
- Fixed: very wide values (e.g. a 17:29/km hiking lap pace) now shrink to fit their cell instead of spilling into the neighbouring one.
- Grade to show power accepts up to 20 percent (was 15).

## [0.5.0] - 2026-07-04
- Terrain-adaptive display: on climbs the current and lap cells switch from pace to power and back on the flat (Auto by grade, threshold configurable), or force Always pace / Always power.
- Average power is always shown in the bottom row (replacing cadence).
- Current pace defaults to Garmin's native reading; set a window above 0 for a smoothed rolling average.

## [0.4.2] - 2026-07-04 (includes 0.4.1)
- Bigger, bolder numbers sized to fit each cell; higher-contrast zone colours for the sunlight (MIP) display and a brighter palette on dark/AMOLED backgrounds.
- 80/20 zone names 1, 2, X, 3, Y, 4, 5 - the easy X and Y "avoid" zones in grey.
- Time-in-zone chart fills its height; empty bars keep their zone colour.
- Tidier layout: shorter labels, more spacing, cadence in the bottom row, default pace window 12 s.

## [0.3.0] - 2026-06-30
- Pace zone model setting: 80/20 Run, Joe Friel Run, CTS Run, MyProCoach Run, or Custom - presets derive zones from your threshold pace; Off disables pace colouring.
- Custom boundaries accept 4 (5 zones) or 6 (7 zones) paces.

## [0.2.0] - 2026-06-30
- Pace zones derived from a threshold pace (5 or 7 zones) with a manual boundary override; optional timed pace/power rotation. (0.2.1: build tooling only.)

## [0.1.0] - 2026-06-29
- Initial running data field: current / lap / average pace and heart rate coloured by zone with fractional zone numbers, time-in-zone bar chart, distance, duration, and clock.
