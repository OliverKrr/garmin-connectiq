import Toybox.Lang;

// Running mean of sampled integer values (e.g. lap HR, lap power). reset() at lap.
class RunningAverage {
    private var _sum as Number = 0;
    private var _count as Number = 0;

    function initialize() {
    }

    function add(value as Number) as Void {
        _sum += value;
        _count++;
    }

    // Integer (truncated) mean — HR/power are displayed as whole numbers.
    function average() as Number or Null {
        if (_count == 0) {
            return null;
        }
        return _sum / _count;
    }

    function count() as Number {
        return _count;
    }

    function reset() as Void {
        _sum = 0;
        _count = 0;
    }
}
