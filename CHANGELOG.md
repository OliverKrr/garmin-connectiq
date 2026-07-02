# Changelog

All notable changes to the Run Field data field. Format: [Keep a Changelog](https://keepachangelog.com/),
versioning: [SemVer](https://semver.org/). The top released section's body is pasted as the Store
"What's New" text via `just publish-assist` — keep it plain text: the Store rejects `<` and `>`.

## [Unreleased]

## [0.4.1] - 2026-07-02
### Changed
- Bigger, bolder numbers: pace and heart rate now use the large Bionic number font, sized to fit.
- Higher-contrast zone colours tuned for the sunlight (MIP) display, with a brighter palette on dark/AMOLED backgrounds.
- The 80/20 model shows its native zone names 1, 2, X, 3, Y, 4, 5, with the easy X and Y "avoid" zones in grey.
- The heart-rate time-in-zone chart fills its height (the busiest zone reaches the top) in a taller band, and empty bars use their zone colour.
- Value rows sit higher with more spacing so the larger numbers do not crowd each other.
- Default current-pace averaging window is now 12 seconds (was 25) for a more responsive readout.

## [0.3.0] - 2026-06-30
### Added
- Pace zone model setting: pick 80/20 Run, Joe Friel Run, CTS Run, MyProCoach Run, or Custom; preset zones derive from your threshold pace.
- Maintained Store description (store-assets/listing.md) documenting every setting with examples.
### Changed
- The pace zone model dropdown replaces the separate 5/7 count and the colour-by-zone toggle; pick Off to disable pace colouring.
- Custom boundaries are now an explicit choice and accept 4 (5 zones) or 6 (7 zones) values.
- Corrected the 7-zone label: it is the 80/20 model, not intervals.icu.

## [0.2.1] - 2026-06-30
### Changed
- Build tooling: both Store listings now build together from one shared version. No user-facing changes since 0.2.0.

## [0.2.0] - 2026-06-30
### Added
- Pace zones derived from a threshold pace (intervals.icu style), with a choice of 5 or 7 zones.
- Manual pace-zone boundary override (comma-separated paces) that takes precedence over the threshold.
- Optional auto-toggle that alternates the pace and power triad every N seconds.
### Changed
- Colour pace by zone is now on by default.
- Empty time-in-zone bars use the foreground colour instead of grey.

## [0.1.0] - 2026-06-29
### Added
- Full-screen running data field: pace/HR triads, distance, duration, clock.
- HR (and optionally pace/power) coloured by zone with a fractional zone number.
- Time-in-zone bar chart (share of total time).
- Settings: rolling-pace window, pace/power toggle, pace-zone thresholds.
