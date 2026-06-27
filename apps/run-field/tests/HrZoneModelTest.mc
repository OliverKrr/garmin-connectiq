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
