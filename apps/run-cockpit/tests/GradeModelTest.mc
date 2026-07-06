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
