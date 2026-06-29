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
    return m.color(300) == Graphics.COLOR_GREEN && m.color(240) == Graphics.COLOR_RED;
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
