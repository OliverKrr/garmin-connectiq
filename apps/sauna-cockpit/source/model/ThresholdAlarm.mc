import Toybox.Lang;

// Fires once when a value reaches its limit, then stays quiet until the value has dropped
// `hysteresis` below the limit again, so a reading hovering at the edge does not buzz every
// second. A limit of 0 or less disables it. Pure, so it is unit-tested.
class ThresholdAlarm {
    private var _limit as Float;
    private var _hysteresis as Float;
    private var _armed as Boolean = true;

    function initialize(limit as Numeric, hysteresis as Numeric) {
        _limit = limit.toFloat();
        _hysteresis = hysteresis.toFloat();
    }

    // True on the sample that should alert.
    function check(value as Numeric or Null) as Boolean {
        if (_limit <= 0.0 || value == null) { return false; }
        var v = value.toFloat();
        if (_armed && v >= _limit) {
            _armed = false;
            return true;
        }
        if (!_armed && v < _limit - _hysteresis) { _armed = true; }
        return false;
    }

    // Whether the value is at or over the limit (for colouring, independent of the latch).
    function exceeded(value as Numeric or Null) as Boolean {
        return _limit > 0.0 && value != null && value.toFloat() >= _limit;
    }
}
