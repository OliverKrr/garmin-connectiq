import Toybox.Test;
import Toybox.Lang;

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
function appConfig_derive5(logger as Test.Logger) as Boolean {
    var b = AppConfig.derivePaceBoundaries(221, 5);
    return b.size() == 4 && b[0] == 283 && b[1] == 251 && b[2] == 233 && b[3] == 221;
}

(:test)
function appConfig_derive7(logger as Test.Logger) as Boolean {
    var b = AppConfig.derivePaceBoundaries(221, 7);
    return b.size() == 6 && b[0] == 291 && b[1] == 254 && b[2] == 238
        && b[3] == 221 && b[4] == 217 && b[5] == 192;
}
