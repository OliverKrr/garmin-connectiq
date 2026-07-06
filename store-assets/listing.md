<!--
Connect IQ Store description — the BODY BELOW THE MARKER is pasted VERBATIM into the
dashboard's Description field. The Store renders PLAIN TEXT only (no Markdown/HTML):
every line = one paragraph, one blank line between sections, leading indentation
collapses, URLs auto-link on the web store only. Only the first ~400 characters are
visible before the "…More" fold — keep the pitch + repo link inside them. Never use
the characters < or > (the Store rejects the whole description). Limit: 4000 chars.
Verify a live listing's stored text via:
https://apps.garmin.com/api/appsLibraryExternalServices/api/asw/apps/APP_ID
-->
<!-- STORE DESCRIPTION BELOW — paste everything after this line -->
Every running metric that matters, on one screen: current, lap, and average pace or power — coloured by training zone — heart rate with zone numbers, a live heart-rate time-in-zone chart, distance, duration, and average power. On climbs it switches from pace to power automatically, and back on the flat.

Source, documentation and support: https://github.com/OliverKrr/garmin-connectiq

FEATURES:
• Pace or power as current / lap / average, coloured by training zone.
• Terrain-adaptive: on climbs the current and lap cells switch from pace to power, and back to pace on the flat (or force pace or power).
• Heart rate as current / lap / average, coloured by HR zone with a fractional zone number.
• Heart-rate time-in-zone bar chart; each bar grows with the time spent in that zone, drawn in that zone's colour.
• Distance, duration, and average power always on screen (useful on hilly runs, where average pace alone misleads).
• Pace zones derived from your threshold pace using a training model you choose: 80/20 Run, Joe Friel Run, CTS Run, MyProCoach Run, or your own custom boundaries.
• Large, bold numbers and high-contrast zone colours tuned for the sunlight (MIP) display, with a brighter palette on dark/AMOLED backgrounds.

SETUP:
1. Add the field to a running activity as a full-screen data field (1-field layout).
2. Open Garmin Connect, then Activity and App Settings, then this data field, and set your threshold pace. Pace colouring stays off until it is set.
3. HR zones come from your watch user profile (running zones).

SETTINGS (the watch does not show setting descriptions, so they are documented here):
• Current-pace window (s): 0 (default) uses Garmin's native current pace; a value above 0 averages the current pace over that many seconds (smoother, but laggier).
• Pace / power: how the current and lap cells choose pace vs power. Auto (by grade) shows pace on the flat and downhill and switches to power on climbs; or force Always pace / Always power. Average pace and average power are always shown regardless.
• Grade to show power (%): in Auto, the grade at which the current and lap cells switch to power (default 3). Needs running power (native wrist power or a power sensor).
• Pace zone model: how pace zones are defined. Off disables pace colouring. The presets (80/20 Run, Joe Friel Run, CTS Run, MyProCoach Run) derive zones from your threshold pace. Custom uses your own boundaries. The 80/20 Run model labels its seven zones 1, 2, X, 3, Y, 4, 5 — X and Y are the easy "avoid" zones and are shown in grey.
• Threshold pace (m:ss per km): your threshold running pace, e.g. 3:41. The chosen preset scales its zones from this. Example: threshold pace 4:00 with 80/20 Run puts your threshold at the zone 4/5 edge, zone 1 slower than 5:16/km, and zone 7 faster than 3:29/km.
• Custom pace boundaries (s/km): only used when the model is Custom. Enter 4 paces (for 5 zones) or 6 paces (for 7 zones) in seconds per km, slow to fast. Example: 360,320,280,250 gives five zones with edges at 6:00, 5:20, 4:40, and 4:10 per km.

Found a bug or missing a feature? Open an issue: https://github.com/OliverKrr/garmin-connectiq/issues
