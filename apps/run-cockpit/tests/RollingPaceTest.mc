import Toybox.Test;
import Toybox.Lang;

(:test)
function rollingPace_constantSpeed(logger as Test.Logger) as Boolean {
    var rp = new RollingPace(25);
    for (var t = 0; t <= 30; t++) {
        rp.add(t * 1000, t.toFloat());
    }
    var p = rp.paceSecPerKm();
    return p != null && (p - 1000.0).abs() < 1.0;
}

(:test)
function rollingPace_needsTwoSamples(logger as Test.Logger) as Boolean {
    var rp = new RollingPace(25);
    rp.add(0, 0.0);
    return rp.paceSecPerKm() == null;
}

(:test)
function rollingPace_windowExcludesOld(logger as Test.Logger) as Boolean {
    var rp = new RollingPace(10);
    for (var t = 0; t <= 10; t++) { rp.add(t * 1000, t.toFloat()); }
    var d = 10.0;
    for (var t = 11; t <= 30; t++) { d += 4.0; rp.add(t * 1000, d); }
    var p = rp.paceSecPerKm();
    return p != null && (p - 250.0).abs() < 20.0;
}
