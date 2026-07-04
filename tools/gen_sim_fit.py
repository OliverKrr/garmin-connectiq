#!/usr/bin/env python3
"""Generate a short synthetic running FIT for the Connect IQ simulator.

Load it via Simulation -> Activity Data -> "FIT/GPX Playable File" -> bin/run-sim.fit -> play.
It exercises the terrain-adaptive display: a flat section (Current/Lap show PACE), then a climb
(grade > threshold -> Current/Lap switch to POWER), then a descent (back to PACE). Distance/pace come
from a GPS track; altitude drives grade; power, heart rate and cadence are included. ~35 seconds.

Requires the fit-tool package:  pip install fit-tool
Run via:  just sim-fit   (or: python3 tools/gen_sim_fit.py)
"""
import sys
import math

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
OUT = "bin/run-sim.fit"

# (seconds, pace sec/km, grade %, power W) — flat -> climb -> descent to show the pace/power switch.
SEGMENTS = [
    (10, 300, 0.0, 235),    # flat: grade ~0 -> PACE
    (13, 330, 7.0, 330),    # climb: grade 7% (> 3% threshold) -> Current/Lap switch to POWER
    (12, 270, -3.0, 205),   # descent: grade -3% -> back to PACE
]

# The simulator derives distance/speed (and the field's pace) from the GPS track; altitude drives the
# app's computed grade. Cadence is stored as strides/min (the watch doubles it to steps/min).
LAT0 = 48.0
LON0 = 8.0
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

builder = FitFileBuilder(auto_define=True)

fid = FileIdMessage()
fid.type = FileType.ACTIVITY
fid.manufacturer = Manufacturer.DEVELOPMENT.value
fid.product = 0
fid.serial_number = 4242
fid.time_created = BASE_MS
builder.add(fid)

dist = 0.0
alt = 100.0
t = 0
total = sum(s for s, _, _, _ in SEGMENTS)
psum = 0
for dur, pace, grade, power in SEGMENTS:
    for _ in range(dur):
        speed = 1000.0 / pace  # m/s
        dist += speed
        alt += (grade / 100.0) * speed  # rise/fall this second
        frac = t / float(total)
        psum += power
        rec = RecordMessage()
        rec.timestamp = BASE_MS + t * 1000
        rec.position_lat = LAT0
        rec.position_long = LON0 + dist / M_PER_DEG_LON
        rec.distance = dist
        rec.altitude = alt
        rec.speed = speed
        rec.power = power
        rec.heart_rate = int(118 + 62 * frac)     # 118 -> 180 bpm
        rec.cadence = int((170 + 20 * frac) / 2)   # strides/min -> ~170..190 spm on the watch
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

builder.build().to_file(OUT)
print(f"wrote {OUT}  ({t} records, {dist / 1000:.2f} km, alt {100.0:.0f}->{alt:.0f} m)")
