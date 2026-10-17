# Sauna Cockpit

A Connect IQ **watch app** for sauna sessions: alternating heat and cool-down phases, a countdown
per phase, live heart rate and watch temperature with alerts, per-round statistics, and an on-watch
history of past sessions. Built for the fēnix 9 Pro, which the popular "Sauna Timer" app does not
support. Status: 0.1.0, sideload only, not on the Connect IQ Store.

## Using it

| Button | Start screen | During a session |
|---|---|---|
| START | Start a session (heat phase, round 1) | Pause, then Resume / Save / Discard |
| BACK | Exit | Switch phase: heat → cool-down → heat (next round). Each switch is a FIT lap |
| UP / DOWN | Open the history | Flip between the cockpit and the round table |
| Touch | ignored | ignored, so wet fingers and towels cannot switch phases |

**Cockpit page.** The bezel ring fills toward the phase target (orange heat, blue cool-down, red
once over). The big number counts down to the target, then counts up as `+m:ss` overtime; without a
target it shows elapsed time. Below it: heart rate in zone colour, the watch temperature (yellow
from the pre-warning, red at the alert), the phase's HR low / average / high, total time and the clock.

**Round table** (live page, post-session summary and history detail): heat time, average and
maximum HR, peak watch temperature, and HRR, the heart-rate drop in the first 60 s of the
following cool-down (a larger drop means faster recovery).

**History.** The last 50 sessions are kept on the watch with their round tables, under 7- and
30-day totals (sessions, rounds, heat minutes). MENU on a session deletes it.

**Recording.** Sessions save as an "Other" activity named Sauna, not Meditation, so Garmin counts
calories and the session stays out of stress and breathwork statistics. GPS is never switched on.
Developer fields: phase and watch temperature per second; round, phase and peak temperature per
lap; rounds and heat time per session.

## Settings (Garmin Connect app)

| Setting | Default | |
|---|---|---|
| Heat phase target | 12 min | Countdown and ring target for heat phases |
| Alert at end of heat phase | on | Off removes the target: the heat phase shows elapsed time |
| Cool-down target | 15 min | |
| Alert at end of cool-down | off | |
| Watch temperature pre-warning | 42 °C | Two buzzes, "cover": shade the watch with your hand. Warns again after the reading drops 1 °C and climbs back. 0 = off |
| Watch temperature alert | 44 °C | Three buzzes, "leave". 0 = off. See below |
| Heart rate alert | 0 (off) | bpm |
| Alert: vibrate / beep / light up the screen | on / off / on | |
| Save as activity in Garmin Connect | on | Off keeps only the on-watch history |

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
