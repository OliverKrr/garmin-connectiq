import Toybox.Lang;

// Smoothed running pace over a trailing time window. Fed one cumulative
// (timerMs, distanceM) sample per second from compute(). Fixed-size ring buffer
// so it never allocates after construction.
class RollingPace {
    private var _windowMs as Number;
    private var _cap as Number;
    private var _times as Array<Number>;
    private var _dists as Array<Float>;
    private var _size as Number = 0;
    private var _head as Number = 0; // index of oldest sample

    function initialize(windowSec as Number) {
        _windowMs = windowSec * 1000;
        _cap = windowSec + 5;
        _times = new [_cap];
        _dists = new [_cap];
    }

    function add(timerMs as Number, distanceM as Float) as Void {
        var tail = (_head + _size) % _cap;
        _times[tail] = timerMs;
        _dists[tail] = distanceM;
        if (_size < _cap) {
            _size++;
        } else {
            _head = (_head + 1) % _cap;
        }
        while (_size > 1 && (timerMs - _times[_head]) > _windowMs) {
            _head = (_head + 1) % _cap;
            _size--;
        }
    }

    function paceSecPerKm() as Float or Null {
        if (_size < 2) {
            return null;
        }
        var newest = (_head + _size - 1) % _cap;
        var dtMs = _times[newest] - _times[_head];
        var dDist = _dists[newest] - _dists[_head];
        if (dtMs <= 0 || dDist <= 0.0) {
            return null;
        }
        var speedMps = dDist / (dtMs / 1000.0);
        return 1000.0 / speedMps;
    }

    function reset() as Void {
        _size = 0;
        _head = 0;
    }
}
