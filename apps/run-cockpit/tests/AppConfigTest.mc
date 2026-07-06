import Toybox.Test;
import Toybox.Lang;

function _arrEq(a as Array<Number> or Null, b as Array<Number>) as Boolean {
    if (a == null || a.size() != b.size()) { return false; }
    for (var i = 0; i < b.size(); i++) {
        if (a[i] != b[i]) { return false; }
    }
    return true;
}

(:test)
function appConfig_parseValid(logger as Test.Logger) as Boolean {
    var z = AppConfig.parsePaceZones("360,320,280,250");
    return z != null && z[0] == 360 && z[1] == 320 && z[2] == 280 && z[3] == 250;
}

(:test)
function appConfig_parseToleratesSpaces(logger as Test.Logger) as Boolean {
    var z = AppConfig.parsePaceZones("360, 320, 280, 250");
    return z != null && z[3] == 250;
}

(:test)
function appConfig_parseRejectsBadInput(logger as Test.Logger) as Boolean {
    return AppConfig.parsePaceZones("") == null
        && AppConfig.parsePaceZones("360,320,280") == null
        && AppConfig.parsePaceZones("a,b,c,d") == null
        && AppConfig.parsePaceZones("250,280,320,360") == null;
}

(:test)
function appConfig_parseClock(logger as Test.Logger) as Boolean {
    return AppConfig.parseClock("3:41") == 221
        && AppConfig.parseClock("") == null
        && AppConfig.parseClock("3:75") == null
        && AppConfig.parseClock("abc") == null;
}

(:test)
function appConfig_derive8020(logger as Logger) as Boolean {
    return _arrEq(AppConfig.derivePaceBoundaries(221, 1), [291, 254, 238, 221, 217, 192]);
}

(:test)
function appConfig_deriveFriel(logger as Logger) as Boolean {
    return _arrEq(AppConfig.derivePaceBoundaries(221, 2), [285, 252, 234, 221, 214, 198]);
}

(:test)
function appConfig_deriveCts(logger as Logger) as Boolean {
    return _arrEq(AppConfig.derivePaceBoundaries(221, 3), [307, 243, 228, 217]);
}

(:test)
function appConfig_deriveMyProCoach(logger as Logger) as Boolean {
    return _arrEq(AppConfig.derivePaceBoundaries(221, 4), [276, 246, 233, 221]);
}

(:test)
function appConfig_deriveUnknownIsEighty20(logger as Logger) as Boolean {
    return _arrEq(AppConfig.derivePaceBoundaries(221, 9), [291, 254, 238, 221, 217, 192]);
}

(:test)
function appConfig_parsePace6(logger as Logger) as Boolean {
    var b = AppConfig.parsePaceZones("360,330,300,270,250,230");
    return b != null && _arrEq(b, [360, 330, 300, 270, 250, 230]);
}

(:test)
function appConfig_parsePace4(logger as Logger) as Boolean {
    var b = AppConfig.parsePaceZones("360,320,280,250");
    return b != null && _arrEq(b, [360, 320, 280, 250]);
}

(:test)
function appConfig_parsePaceRejectsLen5(logger as Logger) as Boolean {
    return AppConfig.parsePaceZones("360,330,300,270,250") == null;
}

(:test)
function appConfig_parsePaceRejectsNonDecreasing(logger as Logger) as Boolean {
    return AppConfig.parsePaceZones("300,320,280,250") == null;
}

(:test)
function appConfig_paceVsPowerDefault(logger as Logger) as Boolean {
    return AppConfig.paceVsPower() == 0;
}

(:test)
function appConfig_gradeThresholdDefault(logger as Logger) as Boolean {
    return AppConfig.gradeThreshold() == 3;
}
