#!/usr/bin/env python3
"""Generate a short synthetic running FIT for the Connect IQ simulator.

Load it in the simulator via Simulation -> Activity Data -> bin/run-sim.fit, then press play.
Pace steps through every 80/20 zone (threshold 3:41 -> boundaries 291,254,238,221,217,192 s/km),
including the narrow X (245) and Y (219) "avoid" zones; heart rate and cadence ramp; distance
accumulates. ~30 seconds so a review is quick.

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

# (seconds, pace sec/km) plateaus -> 80/20 zones 1, 2, X, 3, Y, 4, 5
SEGMENTS = [
    (4, 320),   # zone 1
    (4, 270),   # zone 2
    (5, 245),   # X  (avoid)
    (4, 230),   # zone 3
    (5, 219),   # Y  (avoid)
    (4, 205),   # zone 4
    (4, 188),   # zone 5 (fastest)
]

builder = FitFileBuilder(auto_define=True)

fid = FileIdMessage()
fid.type = FileType.ACTIVITY
fid.manufacturer = Manufacturer.DEVELOPMENT.value
fid.product = 0
fid.serial_number = 4242
fid.time_created = BASE_MS
builder.add(fid)

# The simulator derives distance/speed (and thus the field's pace) from the GPS track, not the
# distance record field — so we lay down a straight eastward track. Cadence is stored as strides/min
# (the watch doubles it to steps/min), so halve the target spm.
LAT0 = 48.0                 # start latitude (deg)
LON0 = 8.0                  # start longitude (deg)
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

dist = 0.0
t = 0
total = sum(s for s, _ in SEGMENTS)
for dur, pace in SEGMENTS:
    for _ in range(dur):
        speed = 1000.0 / pace  # m/s
        dist += speed
        frac = t / float(total)
        rec = RecordMessage()
        rec.timestamp = BASE_MS + t * 1000
        rec.position_lat = LAT0
        rec.position_long = LON0 + dist / M_PER_DEG_LON
        rec.distance = dist
        rec.speed = speed
        rec.heart_rate = int(118 + 62 * frac)         # 118 -> 180 bpm
        rec.cadence = int((170 + 20 * frac) / 2)       # strides/min -> ~170..190 spm on the watch
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
builder.add(ses)

act = ActivityMessage()
act.timestamp = BASE_MS + t * 1000
act.total_timer_time = float(t)
act.num_sessions = 1
builder.add(act)

builder.build().to_file(OUT)
print(f"wrote {OUT}  ({t} records, {dist / 1000:.2f} km)")
