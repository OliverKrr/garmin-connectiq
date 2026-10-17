import Toybox.Lang;

// Per-phase accumulator: duration, heart-rate min/avg/max, peak watch temperature and,
// for a cool-down phase, the HR drop over its first 60 s (heart-rate recovery, HRR60).
// Fed once per second by SessionModel.tick(); pure, so it is unit-tested.
class PhaseStats {
    var seconds as Number = 0;
    var minHr as Number or Null = null;
    var maxHr as Number or Null = null;
    var maxTemp as Float or Null = null;
    // HR at the phase's first valid sample, and the drop 60 s later (null until then).
    var startHr as Number or Null = null;
    var hrr60 as Number or Null = null;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;

    function initialize() {
    }

    // One second of the phase. hr/temp are null when the sensor has no reading.
    function add(hr as Number or Null, temp as Float or Null) as Void {
        seconds++;
        if (hr != null && hr > 0) {
            if (startHr == null) { startHr = hr; }
            if (minHr == null || hr < minHr) { minHr = hr; }
            if (maxHr == null || hr > maxHr) { maxHr = hr; }
            _hrSum += hr;
            _hrCount++;
            if (seconds == 61 && startHr != null) { hrr60 = startHr - hr; }
        }
        if (temp != null && (maxTemp == null || temp > maxTemp)) { maxTemp = temp; }
    }

    // Integer (truncated) mean; null without samples.
    function avgHr() as Number or Null {
        return _hrCount == 0 ? null : _hrSum / _hrCount;
    }
}
