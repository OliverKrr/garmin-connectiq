import Toybox.Lang;

// Heart rate over one phase for the cockpit graph, in at most CAP points of memory. Each point
// averages `step` seconds; when the points run out, neighbours merge pairwise and `step` doubles,
// so a phase of any length fits and always spans the graph's full width. Fed once per second by
// SessionModel.tick(); pure, so it is unit-tested.
class HrTrace {
    const CAP = 60;
    // Averages of the closed points (bpm; 0 where a point had no reading).
    var points as Array<Number> = [] as Array<Number>;
    // Seconds per point.
    var step as Number = 1;
    var minHr as Number or Null = null;
    var maxHr as Number or Null = null;
    // The point being filled: seconds so far, and the sum and count of its readings.
    private var _secs as Number = 0;
    private var _sum as Number = 0;
    private var _n as Number = 0;

    function initialize() {
    }

    // One second; hr is null without a reading.
    function add(hr as Number or Null) as Void {
        if (hr != null && hr > 0) {
            _sum += hr;
            _n++;
            if (minHr == null || hr < minHr) { minHr = hr; }
            if (maxHr == null || hr > maxHr) { maxHr = hr; }
        }
        _secs++;
        if (_secs < step) { return; }
        points.add(_n == 0 ? 0 : _sum / _n);
        _secs = 0;
        _sum = 0;
        _n = 0;
        if (points.size() >= CAP) { halve(); }
    }

    // Pairs of points become one (a gap counts only when both were gaps), step doubles.
    private function halve() as Void {
        var out = [] as Array<Number>;
        for (var i = 0; i + 1 < points.size(); i += 2) {
            var a = points[i];
            var b = points[i + 1];
            out.add(a == 0 ? b : (b == 0 ? a : (a + b) / 2));
        }
        if (points.size() % 2 == 1) { out.add(points[points.size() - 1]); }
        points = out;
        step *= 2;
    }

    // The points to draw: the closed ones plus the one being filled, if it has a reading.
    function values() as Array<Number> {
        var v = points.slice(0, null);
        if (_n > 0) { v.add(_sum / _n); }
        return v;
    }

    // Appends a trace that followed this one (an undone phase switch), point by point at its
    // own resolution.
    function merge(o as HrTrace) as Void {
        var v = o.values();
        for (var i = 0; i < v.size(); i++) {
            for (var s = 0; s < o.step; s++) { add(v[i] == 0 ? null : v[i]); }
        }
    }
}
