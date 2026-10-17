import Toybox.Lang;

// Grade-adjusted pace: factor = flat-equivalent speed / actual speed, so GAP pace = pace / factor.
// F = 1 + 2.5 i + 14 i^2 with i = grade / 100, grade clamped to +/-30 %. Fitted to Garmin's on-watch
// lap GAP (FIT lap avg_grade_adjusted_speed) through GradeModel's smoothing; `tools/gap_check.py`
// re-scores it against your own FIT files. Downhill it follows Strava's 2017 curve (cheapest near
// -9 %, back to 1 near -18 %); uphill it is gentler than Strava's. Pure; unit-tested.
module GapModel {
    const CLAMP = 30.0;
    const A = 2.5;
    const B = 14.0;

    function factor(gradePct as Float) as Float {
        var g = gradePct;
        if (g > CLAMP) { g = CLAMP; }
        if (g < -CLAMP) { g = -CLAMP; }
        var i = g / 100.0;
        return 1.0 + A * i + B * i * i;
    }
}

// Cumulative flat-equivalent distance: each sample adds its distance delta times the GAP factor.
// Rolling, lap and average GAP are this distance over the matching time span. Ignores the first
// sample and any distance that does not grow.
class GapDistance {
    private var _prev as Float or Null = null;
    private var _flat as Float = 0.0;

    function add(distM as Float, factor as Float) as Void {
        var p = _prev;
        if (p != null && distM > p) {
            _flat += (distM - p) * factor;
        }
        _prev = distM;
    }

    function flatM() as Float { return _flat; }

    function reset() as Void {
        _prev = null;
        _flat = 0.0;
    }
}
