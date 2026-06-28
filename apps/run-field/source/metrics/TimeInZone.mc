import Toybox.Lang;

// Seconds spent in each of the 5 HR zones across the activity. Call addSecond()
// once per second with the current zone; zone 0/>5 is clamped to 1..5.
class TimeInZone {
    private var _secs as Array<Number>;

    function initialize() {
        _secs = [0, 0, 0, 0, 0];
    }

    function addSecond(zone as Number) as Void {
        var z = zone;
        if (z < 1) {
            z = 1;
        } else if (z > 5) {
            z = 5;
        }
        _secs[z - 1] += 1;
    }

    // Returns the internal array by reference for efficiency — read only, do not mutate.
    function counts() as Array<Number> {
        return _secs;
    }

    function maxCount() as Number {
        var m = 0;
        for (var i = 0; i < 5; i++) {
            if (_secs[i] > m) {
                m = _secs[i];
            }
        }
        return m;
    }

    // Total seconds across all zones (for proportion-of-total bar heights).
    function total() as Number {
        var t = 0;
        for (var i = 0; i < 5; i++) {
            t += _secs[i];
        }
        return t;
    }

    function reset() as Void {
        _secs = [0, 0, 0, 0, 0];
    }
}
