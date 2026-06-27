import Toybox.Test;
import Toybox.Lang;
import Toybox.Graphics;

(:test)
function hrZone_zoneBoundaries(logger as Test.Logger) as Boolean {
    var m = new HrZoneModel([100, 120, 140, 160, 180, 200]);
    return m.zone(90) == 0 && m.zone(110) == 1 && m.zone(130) == 2
        && m.zone(200) == 5 && m.zone(210) == 5;
}

(:test)
function hrZone_fractional(logger as Test.Logger) as Boolean {
    var m = new HrZoneModel([100, 120, 140, 160, 180, 200]);
    return (m.fractionalZone(126) - 2.3).abs() < 0.01
        && (m.fractionalZone(130) - 2.5).abs() < 0.01
        && m.fractionalZone(95) == 1.0
        && m.fractionalZone(205) == 5.0;
}

(:test)
function hrZone_colors(logger as Test.Logger) as Boolean {
    var m = new HrZoneModel([100, 120, 140, 160, 180, 200]);
    return m.color(3) == Graphics.COLOR_GREEN && m.color(5) == Graphics.COLOR_RED;
}

(:test)
function hrZone_equalAdjacentThresholds(logger as Test.Logger) as Boolean {
    // Duplicate thresholds must not crash; zero-width band collapses sensibly.
    var m = new HrZoneModel([100, 120, 120, 160, 180, 200]);
    var f = m.fractionalZone(150); // lands in zone 3 band [120,160] -> 3 + 30/40 = 3.75
    return (f - 3.75).abs() < 0.01;
}

(:test)
function hrZone_boundaryIsZoneFloor(logger as Test.Logger) as Boolean {
    var m = new HrZoneModel([100, 120, 140, 160, 180, 200]);
    return (m.fractionalZone(120) - 2.0).abs() < 0.01; // exactly at maxZ1/minZ2
}
