import Toybox.Test;
import Toybox.Lang;

(:test)
function paceFormat_fiveMinKm(logger as Test.Logger) as Boolean {
    return PaceFormat.paceSecPerKm(300.0).equals("5:00");
}

(:test)
function paceFormat_roundsToWholeSeconds(logger as Test.Logger) as Boolean {
    return PaceFormat.paceSecPerKm(312.6).equals("5:13");
}

(:test)
function paceFormat_nullIsDashes(logger as Test.Logger) as Boolean {
    return PaceFormat.paceSecPerKm(null).equals("--:--");
}

(:test)
function duration_underHour(logger as Test.Logger) as Boolean {
    return PaceFormat.durationMs(125000).equals("2:05");
}

(:test)
function duration_overHour(logger as Test.Logger) as Boolean {
    return PaceFormat.durationMs(3725000).equals("1:02:05");
}
