import Toybox.Test;
import Toybox.Lang;

(:test)
function pace_fromSpeed(logger as Test.Logger) as Boolean {
    var p = Pace.secPerKmFromSpeed(2.5);
    return p != null && (p - 400.0).abs() < 0.1;
}

(:test)
function pace_fromSpeedZeroOrNull(logger as Test.Logger) as Boolean {
    return Pace.secPerKmFromSpeed(0.0) == null && Pace.secPerKmFromSpeed(null) == null;
}

(:test)
function pace_fromDelta(logger as Test.Logger) as Boolean {
    var p = Pace.secPerKmFromDelta(200.0, 60000);
    return p != null && (p - 300.0).abs() < 0.5;
}

(:test)
function pace_fromDeltaInvalid(logger as Test.Logger) as Boolean {
    return Pace.secPerKmFromDelta(0.0, 60000) == null
        && Pace.secPerKmFromDelta(200.0, 0) == null;
}
