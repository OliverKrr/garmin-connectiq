# Run Field

A full-screen running data field that puts your key metrics on one page: current, lap, and average
pace (or power), heart rate coloured by zone, distance, duration, time of day, and a time-in-zone bar
chart. Optimised for the Enduro 3 and other modern Garmin watches.

## Features

- Pace (or power) shown as current / lap / average, coloured by training zone.
- Heart rate as current / lap / average, coloured by HR zone with a fractional zone number.
- Heart-rate time-in-zone bar chart; each bar grows with the time spent in that zone and is drawn in that zone's colour.
- Distance, cadence, elapsed time, and clock.
- Pace zones derived from your threshold pace using a training model you choose.
- Large, bold numbers and high-contrast zone colours tuned for the sunlight (MIP) display, with a brighter palette on dark/AMOLED backgrounds.

## Settings

Configure these in Garmin Connect (Activity and App Settings, then this data field). The watch itself
does not show the settings descriptions, so they are documented here.

- Current-pace window (s): how many seconds the current-pace value averages over. Default 12 for a
  responsive reading; a larger value (e.g. 25) is smoother but laggier, smaller (e.g. 8) reacts faster.
- Show power instead of pace: replaces the pace triad with running power (needs a power source).
- Auto pace/power switch (s): if greater than 0, the triad alternates between pace and power every N
  seconds. Example: 6 swaps roughly every 6 seconds. 0 turns it off.
- Pace zone model: how pace zones are defined. Off disables pace colouring. The presets (80/20 Run,
  Joe Friel Run, CTS Run, MyProCoach Run) derive zones from your threshold pace. Custom uses your own
  boundaries. The 80/20 Run model labels its seven zones 1, 2, X, 3, Y, 4, 5 — X and Y are the easy
  "avoid" zones and are shown in grey.
- Threshold pace (m:ss per km): your threshold running pace, e.g. 3:41. The chosen preset scales its
  zones from this. Example: Threshold pace 4:00 with 80/20 Run puts your threshold at the Zone 4/5
  edge, Zone 1 slower than 5:16/km, and Zone 7 faster than 3:29/km.
- Custom pace boundaries (s/km): only used when the model is Custom. Enter 4 paces (for 5 zones) or 6
  paces (for 7 zones) in seconds per km, slow to fast. Example: 360,320,280,250 gives five zones with
  edges at 6:00, 5:20, 4:40, and 4:10 per km.

## Source and documentation

Source code, issues, and the latest documentation: https://github.com/OliverKrr/garmin-connectiq
