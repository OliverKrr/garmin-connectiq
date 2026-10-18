import Toybox.Lang;
import Toybox.Math;

// Per-phase accumulator: duration, heart-rate min/avg/max, the HR rise over the phase (peak minus
// the first reading), first/last/peak watch temperature, HRV (RMSSD over beat-to-beat intervals)
// and, for a cool-down phase, the HR drop over its first 60 s (heart-rate recovery, HRR60).
// Fed once per second by SessionModel.tick() and with beat intervals by addBeats(); pure, so it
// is unit-tested.
class PhaseStats {
    var seconds as Number = 0;
    var minHr as Number or Null = null;
    var maxHr as Number or Null = null;
    var firstTemp as Float or Null = null;
    var lastTemp as Float or Null = null;
    var maxTemp as Float or Null = null;
    // HR at the phase's first valid sample, and the drop 60 s later (null until then).
    var startHr as Number or Null = null;
    var hrr60 as Number or Null = null;
    // Running sums, public only so merge() can read another instance's.
    var hrSum as Number = 0;
    var hrCount as Number = 0;
    // RMSSD state: previous accepted interval, sum of squared successive differences, count.
    var prevIv as Number or Null = null;
    var sqSum as Float = 0.0;
    var diffs as Number = 0;

    // Fewer successive differences than this give no HRV value (about 20 s of clean beats).
    const MIN_DIFFS = 20;

    function initialize() {
    }

    // One second of the phase. hr/temp are null when the sensor has no reading.
    function add(hr as Number or Null, temp as Float or Null) as Void {
        seconds++;
        if (hr != null && hr > 0) {
            if (startHr == null) { startHr = hr; }
            if (minHr == null || hr < minHr) { minHr = hr; }
            if (maxHr == null || hr > maxHr) { maxHr = hr; }
            hrSum += hr;
            hrCount++;
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
                prevIv = null;
                continue;
            }
            if (prevIv != null) {
                var d = iv - (prevIv as Number);
                if (d * 5 <= (prevIv as Number) && -d * 5 <= (prevIv as Number)) {
                    sqSum += (d * d).toFloat();
                    diffs++;
                }
            }
            prevIv = iv;
        }
    }

    // Appends a phase that followed this one, as if it had never been split off (an undone phase
    // switch). An HRR60 whose 61st second fell inside `o` stays unknown.
    function merge(o as PhaseStats) as Void {
        seconds += o.seconds;
        if (startHr == null) { startHr = o.startHr; }
        if (o.minHr != null && (minHr == null || (o.minHr as Number) < (minHr as Number))) { minHr = o.minHr; }
        if (o.maxHr != null && (maxHr == null || (o.maxHr as Number) > (maxHr as Number))) { maxHr = o.maxHr; }
        hrSum += o.hrSum;
        hrCount += o.hrCount;
        if (firstTemp == null) { firstTemp = o.firstTemp; }
        if (o.lastTemp != null) { lastTemp = o.lastTemp; }
        if (o.maxTemp != null && (maxTemp == null || (o.maxTemp as Float) > (maxTemp as Float))) { maxTemp = o.maxTemp; }
        sqSum += o.sqSum;
        diffs += o.diffs;
        prevIv = o.prevIv;
    }

    // Integer (truncated) mean; null without samples.
    function avgHr() as Number or Null {
        return hrCount == 0 ? null : hrSum / hrCount;
    }

    // Peak HR minus the HR at the phase's start: how far a heat round pushed the heart rate,
    // independent of any fixed threshold. Null without HR.
    function rise() as Number or Null {
        return (maxHr == null || startHr == null) ? null : (maxHr as Number) - (startHr as Number);
    }

    // RMSSD in ms, rounded; null until MIN_DIFFS clean successive differences.
    function rmssd() as Number or Null {
        return diffs < MIN_DIFFS ? null : Math.round(Math.sqrt(sqSum / diffs)).toNumber();
    }
}
