import Toybox.Lang;
import Toybox.Math;

// Per-phase accumulator: duration, heart-rate min/avg/max, time at or above the "sauna effect"
// heart rate, first/last/peak watch temperature, HRV (RMSSD over beat-to-beat intervals) and, for
// a cool-down phase, the HR drop over its first 60 s (heart-rate recovery, HRR60).
// Fed once per second by SessionModel.tick() and with beat intervals by addBeats(); pure, so it
// is unit-tested.
class PhaseStats {
    var seconds as Number = 0;
    var minHr as Number or Null = null;
    var maxHr as Number or Null = null;
    // Seconds with HR at or above the effect threshold given to the constructor.
    var aboveSec as Number = 0;
    var firstTemp as Float or Null = null;
    var lastTemp as Float or Null = null;
    var maxTemp as Float or Null = null;
    // HR at the phase's first valid sample, and the drop 60 s later (null until then).
    var startHr as Number or Null = null;
    var hrr60 as Number or Null = null;
    private var _effHr as Number;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;
    // RMSSD state: previous accepted interval, sum of squared successive differences, count.
    private var _prevIv as Number or Null = null;
    private var _sqSum as Float = 0.0;
    private var _diffs as Number = 0;

    // Fewer successive differences than this give no HRV value (about 20 s of clean beats).
    const MIN_DIFFS = 20;

    function initialize(effHr as Number) {
        _effHr = effHr;
    }

    // One second of the phase. hr/temp are null when the sensor has no reading.
    function add(hr as Number or Null, temp as Float or Null) as Void {
        seconds++;
        if (hr != null && hr > 0) {
            if (startHr == null) { startHr = hr; }
            if (minHr == null || hr < minHr) { minHr = hr; }
            if (maxHr == null || hr > maxHr) { maxHr = hr; }
            if (_effHr > 0 && hr >= _effHr) { aboveSec++; }
            _hrSum += hr;
            _hrCount++;
            if (seconds == 61 && startHr != null) { hrr60 = startHr - hr; }
        }
        if (temp != null) {
            if (firstTemp == null) { firstTemp = temp; }
            lastTemp = temp;
            if (maxTemp == null || temp > maxTemp) { maxTemp = temp; }
        }
    }

    // Beat-to-beat intervals in ms. Intervals outside 300-2000 ms (200-30 bpm) break the chain,
    // and a jump of more than 20 % from the previous beat is treated as a missed or extra beat.
    function addBeats(ivs as Array<Number>) as Void {
        for (var i = 0; i < ivs.size(); i++) {
            var iv = ivs[i];
            if (iv < 300 || iv > 2000) {
                _prevIv = null;
                continue;
            }
            if (_prevIv != null) {
                var d = iv - (_prevIv as Number);
                if (d * 5 <= (_prevIv as Number) && -d * 5 <= (_prevIv as Number)) {
                    _sqSum += (d * d).toFloat();
                    _diffs++;
                }
            }
            _prevIv = iv;
        }
    }

    // Integer (truncated) mean; null without samples.
    function avgHr() as Number or Null {
        return _hrCount == 0 ? null : _hrSum / _hrCount;
    }

    // RMSSD in ms, rounded; null until MIN_DIFFS clean successive differences.
    function rmssd() as Number or Null {
        return _diffs < MIN_DIFFS ? null : Math.round(Math.sqrt(_sqSum / _diffs)).toNumber();
    }
}
