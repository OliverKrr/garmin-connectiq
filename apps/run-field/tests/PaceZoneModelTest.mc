import Toybox.Test;
import Toybox.Lang;
import Toybox.Graphics;

(:test)
function paceZone_zoneBoundaries(logger as Test.Logger) as Boolean {
    var m = new PaceZoneModel([360, 320, 280, 250]);
    return m.zone(400) == 1 && m.zone(360) == 2 && m.zone(300) == 3
        && m.zone(260) == 4 && m.zone(240) == 5 && m.zone(null) == 0;
}

(:test)
function paceZone_color(logger as Test.Logger) as Boolean {
    var m = new PaceZoneModel([360, 320, 280, 250]);
    return m.color(300, true) == ZoneColor.of(3, true) && m.color(240, true) == ZoneColor.of(5, true)
        && m.color(300, false) == ZoneColor.of(3, false) && m.color(240, false) == ZoneColor.of(5, false);
}

(:test)
function paceZone_fractional(logger as Test.Logger) as Boolean {
    var m = new PaceZoneModel([360, 320, 280, 250]);
    return m.fractionalZone(360) == 2.0
        && (m.fractionalZone(340) - 2.5).abs() < 0.01
        && (m.fractionalZone(300) - 3.5).abs() < 0.01
        && m.fractionalZone(400) == 1.0
        && m.fractionalZone(240) == 5.0;
}

(:test)
function paceZone_sevenZones(logger as Test.Logger) as Boolean {
    var m = new PaceZoneModel([291, 254, 238, 221, 217, 192]);
    return m.zone(300) == 1 && m.zone(225) == 4 && m.zone(218) == 5
        && m.zone(200) == 6 && m.zone(180) == 7 && m.zone(null) == 0;
}

(:test)
function paceZone_sevenColours(logger as Test.Logger) as Boolean {
    var seen = {};
    for (var z = 1; z <= 7; z++) { seen[ZoneColor.of7(z, true)] = true; }
    return seen.size() == 7;
}
