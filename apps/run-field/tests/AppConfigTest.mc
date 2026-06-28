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
