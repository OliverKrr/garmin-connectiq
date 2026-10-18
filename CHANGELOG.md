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

## [1.3.2] - 2026-10-18
- GAP is the default climb metric (power stays one setting away), and Climb metric is the first setting.
- Current pace (and current GAP) is a 10-second rolling pace; the Current-pace window setting is gone. Before the start and while paused it shows Garmin's own reading.
- Settings renamed: Pace / power is now Show climb metric (Auto, Never, Always).

## [1.3.1] - 2026-10-18
- GAP is now a climb metric instead of its own mode: the new Climb metric setting picks Power or GAP. With GAP, Auto switches current and lap from pace to GAP on climbs (labels GP, GL, with pace-zone numbers), and the bottom row shows average GAP instead of average power.

## [1.3.0] - 2026-10-18
- Grade-adjusted pace (GAP): new Pace / power option that shows current, lap and average GAP (labels GP, GL, GA), coloured by pace zones. Calibrated to Garmin's own lap GAP: within about 4 s/km on hilly laps.

## [1.2.0] - 2026-10-15
- 12 more supported watches (95 in total): fenix 9 43 / 47 mm, fenix 9 Pro 43 / 47 / 51 mm
  (incl. inReach), fenix 9 Pro Solar 47 / 51 mm, D2 Delta / Delta PX / Delta S, Descent Mk1,
  Forerunner 645 Music.

## [1.1.0] - 2026-09-30
- 34 more supported watches (83 in total): Forerunner 70, Venu X1, Venu 2 / 2S / 2 Plus,
  Venu Sq 2 (+ Music), Instinct 3 AMOLED 45 / 50 mm, Instinct Crossover AMOLED,
  D2 Air X10 / Mach 1 / Mach 2 / Mach 2 Pro, Descent G2 / Mk2 / Mk2 S / Mk3 43 mm / Mk3i 51 mm,
  Approach S50 / S70 42 mm / S70 47 mm, fenix 5 Plus / 5S Plus / 5X / 5X Plus, MARQ gen 1 (8 models).
- Rectangular screens (Venu Sq 2, Venu X1) now use the full screen width. The round-screen
  layout rule left the clock band 22 px wide on a 320x360 display; round watches are unchanged.

## [1.0.0] - 2026-07-11
- First stable release; published to the public Connect IQ Store. No functional changes since 0.6.0.

## [0.6.0] - 2026-07-06
- Renamed to Run Cockpit (formerly Run Field); 48 more supported watches (fenix 6 Pro to 8, epix 2, Enduro 3, Forerunner 165 to 970, MARQ 2, Venu 3 / 4, vivoactive 5 / 6).
- Very wide values now shrink to fit their cell; grade to show power up to 20 percent.

## [0.5.0] - 2026-07-04
- Terrain-adaptive display: on climbs current and lap switch from pace to power (Auto by grade, or Always pace / Always power); average power in the bottom row.

## [0.4.2] - 2026-07-04 (includes 0.4.1)
- Bigger, bolder numbers; higher-contrast zone colours for MIP and AMOLED; 80/20 zone names 1, 2, X, 3, Y, 4, 5 with X and Y in grey; tidier layout.

## [0.3.0] - 2026-06-30
- Pace zone models: 80/20 Run, Joe Friel Run, CTS Run, MyProCoach Run or Custom (4 or 6 boundaries), derived from your threshold pace.

## [0.2.0] - 2026-06-30
- Pace zones from a threshold pace (5 or 7 zones). (0.2.1: build tooling only.)

## [0.1.0] - 2026-06-29
- Initial running data field: current / lap / average pace and heart rate coloured by zone, time-in-zone chart, distance, duration, and clock.
