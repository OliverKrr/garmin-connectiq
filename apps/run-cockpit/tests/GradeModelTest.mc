import Toybox.Lang;
import Toybox.Test;

(:test)
function gradeModel_flat(l as Logger) as Boolean {
    var g = new GradeModel();
    for (var d = 0; d <= 200; d += 5) { g.update(d.toFloat(), 100.0); }
    return g.grade() > -0.5 && g.grade() < 0.5;
}

(:test)
function gradeModel_climb(l as Logger) as Boolean {
    var g = new GradeModel();
    for (var d = 0; d <= 300; d += 5) { g.update(d.toFloat(), 100.0 + d * 0.03); }
    return g.grade() > 2.5 && g.grade() < 3.5;
}

(:test)
function gradeModel_downhill(l as Logger) as Boolean {
    var g = new GradeModel();
    for (var d = 0; d <= 300; d += 5) { g.update(d.toFloat(), 100.0 - d * 0.05); }
    return g.grade() < -3.0;
}

(:test)
function gradeModel_holdsWhenNoDistance(l as Logger) as Boolean {
    var g = new GradeModel();
    g.update(0.0, 100.0); g.update(2.0, 101.0);
    return g.grade() == 0.0;
}

// A placeholder altitude of 0 before the real 640 m (as the simulator reports before playback)
// must not read as a 40 % climb.
(:test)
function gradeModel_altitudeJumpReanchors(l as Logger) as Boolean {
    var g = new GradeModel();
    g.update(0.0, 0.0);
    var peak = 0.0;
    for (var d = 3; d <= 300; d += 3) {
        g.update(d.toFloat(), 640.0);
        if (g.grade().abs() > peak) { peak = g.grade().abs(); }
    }
    return peak < 0.5;
}
