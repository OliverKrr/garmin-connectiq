# Sauna Cockpit

A Connect IQ **watch app** for sauna sessions: alternating heat and cool-down phases, a countdown
per phase, live heart rate and watch temperature with alerts, per-round statistics, and an on-watch
history of past sessions. Built for the fēnix 9 Pro, which the popular "Sauna Timer" app does not
support. Status: 0.1.0 in a private beta listing on the Connect IQ Store (see `RELEASE.md`);
a public listing comes later.

## Using it

| Button | Start screen | During a session |
|---|---|---|
| START | Start a session (heat phase, round 1) | Pause, then Resume / Settings / Save / Discard |
| BACK | Exit | Switch phase: heat → cool-down → heat (next round). Again within 10 s: undo the switch |
| UP / DOWN | DOWN opens the history | Cycle the pages: cockpit, heat table, rest table. On a dimmed or dark screen the first press only brightens it |
| MENU (hold UP) | Settings | Settings, while the session keeps running |
| Touch | ignored | only brightens the screen, so wet fingers and towels cannot switch phases |

**Undo.** A phase switch stays undoable for 10 s ("BACK again: undo"): the closed phase reopens
with the seconds since added to it, as if BACK had never been pressed. The FIT lap is written
only when the window closes, so an undone switch leaves no lap behind; the cost is that FIT lap
boundaries sit up to 10 s after the real switch. The on-watch tables use the exact time.

**Screen.** Connect IQ gives watch apps no control over the always-on display (only watch faces
get the low-power hooks), so the app manages its own brightness. Between button presses the
session screen dims during heat (every colour at 40 %) and goes dark during rest (black but for
the progress ring; fully black when the rest has no target). Any button, a touch, or an alert
shows it at full brightness for 10 s. The "Heat screen" and "Rest screen" settings choose
Normal, Dim or Dark per phase. On AMOLED, black pixels are off, so Dark draws no power and no
light.

**Vibration.** A short tap acknowledges a button; three quick taps mean a phase timer ran out;
two long buzzes are the temperature pre-warning; long-short-long is an alarm (watch temperature
"leave", or the HR alert).

**Cockpit page.** The bezel ring fills toward the phase target (orange heat, blue cool-down, red
once over). The big number counts down to the target, then counts up as `+m:ss` overtime; without a
target it shows elapsed time. Below it: heart rate in zone colour, the watch temperature (yellow
from the pre-warning, red at the alert), the phase's HR low / average / high, total time and the clock.

Heart rate is coloured by your own zones: the general zones from your Garmin profile, read when
the app starts.

**Round tables** (live pages, post-session summary and history detail):

- **Heat:** heat time, average and maximum HR, peak watch temperature, and the HR rise: peak HR
  minus the HR when the round started. It replaced 0.1's time above a fixed 120 bpm, which a
  calm sauna-goer with a low resting HR barely reaches; the rise compares rounds and sessions
  whatever the absolute level. Live tables with more than four rounds page through them every 4 s.
- **Rest** (the cool-down after each heat round): rest time, average and lowest HR, HRR (the HR
  drop in the first 60 s; a larger drop means faster recovery) and how far the watch temperature
  fell. The live rest page also shows the current phase's HRV.
- **HRV** (summary only): RMSSD in ms per heat and rest phase, from the optical sensor's
  beat-to-beat intervals. Heat typically pushes it down, and a quick rebound in the rest phase is
  a good sign. Wrist HRV is noisy, so compare sessions with each other, not with chest-strap
  values; a phase with too few clean beats shows `--`.

**Summary** after Save and in the history pages with UP/DOWN through Heat (session HR low / avg
/ high, average HR rise per round, total time, calories), Rest, and Recovery (Body Battery
at start and end, stress before and, when recorded as Meditation, after the session, the HRV
table).

**History.** The last 50 sessions are kept on the watch with their round tables, under 7- and
30-day totals (sessions, rounds, heat minutes). MENU on a session deletes it.

**Recording.** Sessions save as an activity named Sauna, by default of type "Other": Garmin counts
calories and the session stays out of stress and meditation statistics, but Garmin stops measuring
stress during it, so the Recovery page shows only the stress value from before. The "Record as"
setting switches to "Meditation" (what Sauna Timer uses): Garmin keeps measuring stress, the
Recovery page shows stress before and after, but no calories are counted and the sauna's stress
goes into the day's stress and Body Battery. GPS is never switched on.
Developer fields, visible in Garmin Connect and exported in the FIT file:

| Message | Field (id) | Meaning |
|---|---|---|
| record (per second) | `phase` (0), `watch_temp` (1) | 0 heat, 1 cool-down; watch temperature in °C |
| lap | `round` (2), `lap_phase` (3) | round number and the lap's phase |
| lap | `lap_max_temp` (4), `lap_rmssd` (8) | peak watch temperature; HRV (RMSSD, ms) |
| lap (heat) | `lap_hr_rise` (13) | peak HR minus the HR at the lap's start, bpm |
| lap (cool-down) | `lap_hrr60` (14) | HR drop over the first 60 s, bpm |
| session | `rounds` (5), `heat_time` (6) | heat rounds; seconds in heat |
| session | `body_battery_start/end` (9, 10), `stress_start/end` (11, 12) | see Recording |

Field 7 (`lap_effect_time`, 0.1.x) is retired and its id not reused. Body Battery and stress
come from the watch's history: the start values from the newest sample of the 30 minutes
before, the end values only from samples taken during the session (none → empty field), and
stress at the end only in a Meditation recording. Intervals.icu drops developer fields from its
streams; read them from the original FIT (`GET /api/v1/activity/{id}/file`). Beat-to-beat intervals are read
only while a session runs, since they keep the optical sensor in its high-rate mode.

## Settings (watch or Garmin Connect app)

All settings but the two recording ones can also be changed on the watch (MENU, or Settings in
the pause menu), and a running session takes new targets and limits at once. The on-watch menu
offers 1-30 min targets, 36-55 °C temperatures and 120-200 bpm in steps of 5.

| Setting | Default | |
|---|---|---|
| Heat phase target | 12 min | Countdown and ring target for heat phases |
| Alert at end of heat phase | on | Off removes the target: the heat phase shows elapsed time |
| Cool-down target | 15 min | |
| Alert at end of cool-down | off | |
| Watch temperature pre-warning | 42 °C | Two buzzes, "cover": shade the watch with your hand. Warns again after the reading drops 1 °C and climbs back. 0 = off |
| Watch temperature alert | 44 °C | Three buzzes, "leave". 0 = off. See below |
| Heart rate alert | 0 (off) | bpm |
| Heat screen / Rest screen | Dim / Dark | Between button presses: Normal, Dim (40 %) or Dark (black but for the ring) |
| Alert: vibrate / beep / light up the screen | on / off / on | |
| Save as activity in Garmin Connect | on | Off keeps only the on-watch history |
| Record as | Other | Other: calories, no stress during the session. Meditation: stress measured, no calories |

These map the old Sauna Timer settings: Session Time → heat target, Rest Time → cool-down target,
Warn Temperature → watch temperature alert, with the new pre-warning 2 °C below it. There is no flashlight option because Connect IQ has
no API for the LED; the screen lights up instead.

## Heat and the watch

Garmin specifies the fēnix 9 / 9 Pro, fēnix 8 and Enduro 3 for **-20 to 45 °C operating and
storage, 0 to 45 °C charging** ([fēnix 9 manual, Specifications](https://www8.garmin.com/manuals/webhelp/GUID-708A8F4D-9A78-49CF-9528-DE109BBCC472/EN-US/GUID-253A367D-45BE-4ACD-B939-7DC713DE41F8.html)).
A Finnish sauna runs at 80-100 °C. Garmin publishes no sauna guidance beyond that rating, so any
use in a sauna is outside spec, and the Sauna Timer author's own advice is to leave the watch
outside.

**What the temperature reading means.** The sensor sits inside the case next to the battery. The
wrist cools it and the case's thermal mass delays it, so it reads far below the air (users report
about 48 °C in an 85 °C sauna) and lags. It is a poor sauna thermometer but a fair measure of what
the battery and seals experience. The 44 °C alert therefore means "leave now": the inside keeps
warming for a while after the alert. The 42 °C pre-warning gives the headroom: cover the watch
with your other hand, which pulls the reading back down, and leave once the 44 °C alert comes
anyway.

**Titanium.** The case material changes how hot the watch feels on skin, not how hot it gets
inside. Titanium stores roughly 40 % less heat per volume than steel and feels about half as hot
on contact. Over a 10-15 minute round the internals reach about the same temperature whatever
the case is made of. Sapphire conducts heat well and gets hot to the touch.

**Risks that add up.** Li-ion cells age faster when hot (informally ~45 °C for charging, ~60 °C
for discharge). Gaskets age with repeated heat, and steam or a hot-to-cold plunge pulls moisture
in. AMOLED ages faster with heat. Forum reports include fogged lenses and one dead watch after a
steam room. No documented battery swelling, but the evidence is anecdotal either way.

**If you wear it anyway:** keep the 42 / 44 °C alerts, cap rounds at 10-12 min, wear it loosely and
cover it with a towel or your hand, stay off the top bench and away from the löyly. Take it off for
steam rooms and cold plunges, and let it cool to room temperature before charging. Stop wearing
it in the sauna if the lens fogs or the back bulges.

Typical sessions (Laukkanen et al., Mayo Clin Proc 2018): rounds of 5-20 minutes, often 8-15,
two or three per visit, with cool-down and rest in between. Heart rate rises to about 120-150 bpm.
