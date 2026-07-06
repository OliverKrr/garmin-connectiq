#!/usr/bin/env python3
"""Generate bin/store-run.fit — a synthetic run crafted for Store screenshots.

Unlike run-sim.fit (35 s smoke test), this is a ~13-minute run designed so that,
played back in the simulator (Simulation -> Activity Data -> FIT/GPX Playable File,
speed slider up), the field shows photogenic values at two capture points:

  CAPTURE A (~72% in, flat):  current pace green (zone 3 of the 80/20 model with
              threshold 4:00), HR orange (zone 4), avg power populated, and a
              time-in-zone chart with a spread across zones 2-4.
  CAPTURE B (~88% in, climb): grade 8% > threshold -> Current/Lap switch to POWER.

Segments (threshold pace 4:00/km -> 80/20 boundaries 5:16 / 4:36 / 4:18 / 4:00 / 3:55 / 3:29):
  warm-up   Z2 pace, HR ramps zone 2->3
  steady    zone-3 pace (4:10), HR zone 3->4
  climb     8% grade, power 345 W, HR zone 4
  descent   -4%, fast pace, HR drops

Requires: pip install fit-tool.  Run: python3 tools/gen_store_fit.py
"""
import math
import sys

try:
    from fit_tool.fit_file_builder import FitFileBuilder
    from fit_tool.profile.messages.file_id_message import FileIdMessage
    from fit_tool.profile.messages.record_message import RecordMessage
    from fit_tool.profile.messages.lap_message import LapMessage
    from fit_tool.profile.messages.session_message import SessionMessage
    from fit_tool.profile.messages.activity_message import ActivityMessage
    from fit_tool.profile.profile_type import FileType, Manufacturer, Sport, SubSport
except ImportError:
    sys.exit("fit-tool not installed. Run: pip install fit-tool")

BASE_MS = 1735689600000  # fixed base (2025-01-01 UTC) so output is reproducible
OUT = "bin/store-run.fit"

# (seconds, pace s/km, grade %, power W, hr_from, hr_to)
SEGMENTS = [
    (180, 290, 0.0, 235, 128, 142),   # warm-up: Z2 blue pace, HR z2->z3
    (380, 250, 0.0, 285, 150, 161),   # steady: zone-3 (green) pace, HR z3->z4
    (120, 335, 8.0, 345, 162, 170),   # climb: 8% -> POWER cells, HR z4
    (100, 232, -4.0, 215, 158, 152),  # descent: fast pace, HR eases
]

# The simulator's FIT playback consumes records ~1.47x faster than wall time, while
# the data field's timer ticks wall seconds (measured 1.455-1.47 across runs, SDK 9.2.0).
# Current pace reads the record's speed field (unaffected), but elapsedDistance follows
# the records — so lap/avg pace and DIST inflate by K unless compensated: shrink the
# per-record distance/altitude deltas by K and stretch each segment's record count by K.
# Wall-clock segment boundaries and displayed values then match the design table above.
K = 1.47

# Track position is cosmetic — elapsedDistance follows the records' distance field,
# not the GPS geometry (verified: the K inflation was identical at lat 48 and lat 0).
LAT0 = 0.0
LON0 = 8.0
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

builder = FitFileBuilder(auto_define=True)

fid = FileIdMessage()
fid.type = FileType.ACTIVITY
fid.manufacturer = Manufacturer.DEVELOPMENT.value
fid.product = 0
fid.serial_number = 4243
fid.time_created = BASE_MS
builder.add(fid)

dist = 0.0
alt = 640.0
t = 0
psum = 0
for dur, pace, grade, power, hr0, hr1 in SEGMENTS:
    n = int(dur * K)  # stretched record count: consumed at K rec/s -> `dur` wall seconds
    for i in range(n):
        speed = 1000.0 / pace
        step = speed / K  # shrunken per-record delta: dist accrues at `speed` per wall second
        dist += step
        alt += (grade / 100.0) * step
        psum += power
        rec = RecordMessage()
        rec.timestamp = BASE_MS + t * 1000
        rec.position_lat = LAT0
        rec.position_long = LON0 + dist / M_PER_DEG_LON
        rec.distance = dist
        rec.altitude = alt
        rec.speed = speed
        rec.power = power
        rec.heart_rate = int(hr0 + (hr1 - hr0) * (i / float(n)))
        rec.cadence = 88  # strides/min -> 176 spm
        builder.add(rec)
        t += 1

lap = LapMessage()
lap.timestamp = BASE_MS + t * 1000
lap.start_time = BASE_MS
lap.total_elapsed_time = float(t)
lap.total_timer_time = float(t)
lap.total_distance = dist
builder.add(lap)

ses = SessionMessage()
ses.timestamp = BASE_MS + t * 1000
ses.start_time = BASE_MS
ses.total_elapsed_time = float(t)
ses.total_timer_time = float(t)
ses.total_distance = dist
ses.sport = Sport.RUNNING
ses.sub_sport = SubSport.GENERIC
ses.num_laps = 1
ses.avg_power = int(psum / t)
builder.add(ses)

act = ActivityMessage()
act.timestamp = BASE_MS + t * 1000
act.total_timer_time = float(t)
act.num_sessions = 1
builder.add(act)

wall = int(t / K)
builder.build().to_file(OUT)
print(f"wrote {OUT}  ({t} records ≈ {wall} wall-s, {dist / 1000:.2f} km)")
