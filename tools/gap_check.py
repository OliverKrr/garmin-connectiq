# /// script
# dependencies = ["garmin-fit-sdk", "numpy"]
# ///
"""Score Run Cockpit's grade-adjusted pace against Garmin's own lap GAP in real FIT files.

Replays GradeModel over each file's recorded distance and altitude, applies GapModel.factor per
second, and compares every lap with the watch's lap avg_grade_adjusted_speed. The constants are read
from GradeModel.mc and GapModel.mc, so this checks the code as it is. With --fit it also prints the
quadratic (1 + a i + b i^2) that best matches the files, to re-tune GapModel's A and B.

Usage:  just gap-check <fit files or dirs> [--fit]
FIT files: Garmin Connect -> activity -> gear icon -> Export Original (unzip it).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
from garmin_fit_sdk import Decoder, Stream

METRICS = Path(__file__).resolve().parents[1] / "apps/run-cockpit/source/metrics"


def consts(mc: str) -> dict[str, float]:
    text = (METRICS / mc).read_text()
    return {k: float(v) for k, v in re.findall(r"const (\w+) = (-?[\d.]+);", text)}


GRADE = consts("GradeModel.mc")
GAP = consts("GapModel.mc")


def factor(g: np.ndarray, a: float = GAP["A"], b: float = GAP["B"]) -> np.ndarray:
    i = np.clip(g, -GAP["CLAMP"], GAP["CLAMP"]) / 100.0
    return 1.0 + a * i + b * i * i


def replay_grade(dist: np.ndarray, alt: np.ndarray) -> np.ndarray:
    """GradeModel.update, one call per record."""
    ds: list[float] = []
    als: list[float] = []
    alt_ema: float | None = None
    grade, out = 0.0, np.zeros(len(dist))
    for n, (d, a) in enumerate(zip(dist, alt)):
        if np.isfinite(a):
            alt_ema = a if alt_ema is None else alt_ema + GRADE["ALT_A"] * (a - alt_ema)
            ds.append(d)
            als.append(alt_ema)
            while len(ds) > 2 and d - ds[1] >= GRADE["WIN_M"]:
                ds.pop(0)
                als.pop(0)
            span = d - ds[0]
            if span >= GRADE["MIN_M"]:
                g = max(
                    -GRADE["CLAMP"],
                    min(GRADE["CLAMP"], (als[-1] - als[0]) / span * 100.0),
                )
                grade += GRADE["GRADE_A"] * (g - grade)
        out[n] = grade
    return out


def _altitude(rec: dict) -> float:
    a = rec.get("enhanced_altitude", rec.get("altitude"))
    return np.nan if a is None else a


def laps(path: Path) -> list[tuple[np.ndarray, np.ndarray, float, float]]:
    """(distance deltas, grades, lap speed, Garmin lap GAP) for each usable lap."""
    msgs, _ = Decoder(Stream.from_file(str(path))).read(
        convert_datetimes_to_dates=False
    )
    recs = [r for r in msgs.get("record_mesgs", []) if r.get("distance") is not None]
    if not recs:
        return []
    ts = np.array([r["timestamp"] for r in recs], float)
    dist = np.array([r["distance"] for r in recs], float)
    alt = np.array([_altitude(r) for r in recs], float)
    grade = replay_grade(dist, alt)
    dd = np.clip(np.diff(dist, prepend=dist[0]), 0, None)
    out = []
    for lap in msgs.get("lap_mesgs", []):
        gap, t, d = (
            lap.get("avg_grade_adjusted_speed"),
            lap.get("total_timer_time"),
            lap.get("total_distance"),
        )
        if not gap or not t or not d or t < 60 or d < 200:
            continue
        # lap.timestamp is not reliably the lap end; start_time + total_elapsed_time is.
        m = (ts > lap["start_time"]) & (
            ts <= lap["start_time"] + lap["total_elapsed_time"]
        )
        if dd[m].sum() >= 150:
            out.append((dd[m], grade[m], d / t, gap))
    return out


def pace_err(segs, f) -> np.ndarray:
    """Model GAP pace minus Garmin GAP pace per lap, s/km (+ = model slower)."""
    return np.array(
        [
            1000 / (v * np.sum(dd * f(g)) / np.sum(dd)) - 1000 / ref
            for dd, g, v, ref in segs
        ]
    )


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    files = [
        p
        for a in args
        for p in (sorted(Path(a).rglob("*.fit")) if Path(a).is_dir() else [Path(a)])
    ]
    segs = [s for p in files for s in laps(p)]
    if not segs:
        sys.exit("no laps with Garmin GAP (lap avg_grade_adjusted_speed) found")
    hilly = [
        s
        for s in segs
        if np.sum(s[0] * np.abs(s[1])) / np.sum(s[0]) >= 4.0
        or abs(np.sum(s[0] * s[1]) / np.sum(s[0])) >= 2.0
    ]
    print(f"{len(files)} files, {len(segs)} laps with Garmin GAP, {len(hilly)} hilly")
    print(f"GapModel: A={GAP['A']} B={GAP['B']} clamp=+/-{GAP['CLAMP']} %")
    for name, f in (("raw pace", np.ones_like), ("GapModel", factor)):
        for label, s in (("all", segs), ("hilly", hilly)):
            if s:
                e = pace_err(s, f)
                print(
                    f"  {name:<9}{label:<6} mean abs {np.abs(e).mean():5.1f} s/km   bias {e.mean():+5.1f}   p90 {np.percentile(np.abs(e), 90):5.1f}"
                )
    if "--fit" in sys.argv:
        X = np.array(
            [
                [
                    np.sum(dd * (np.clip(g, -GAP["CLAMP"], GAP["CLAMP"]) / 100) ** k)
                    / np.sum(dd)
                    for k in (1, 2)
                ]
                for dd, g, _, _ in segs
            ]
        )
        y = np.array([ref / v - 1.0 for _, _, v, ref in segs])
        a, b = np.linalg.lstsq(X, y, rcond=None)[0]
        e = pace_err(hilly or segs, lambda g: factor(g, a, b))
        print(
            f"best fit: A={a:.2f} B={b:.2f}  (hilly mean abs {np.abs(e).mean():.1f} s/km, in-sample)"
        )


if __name__ == "__main__":
    main()
